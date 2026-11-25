"""Lightweight local HTTP/CONNECT proxy relay for stable port binding and zero-restart failover."""
from __future__ import annotations

import socket
import threading
from urllib.parse import urlsplit


DEFAULT_RELAY_PORT = 17890


class LocalProxyRelay:
    """Binds strictly on 127.0.0.1 and forwards HTTP/CONNECT requests to hot-swappable local upstreams.

    Never dials remote hosts directly: if no local upstream proxy is reachable, returns HTTP 502.
    """

    def __init__(self, preferred_port: int = DEFAULT_RELAY_PORT):
        self._preferred_port = preferred_port
        self._lock = threading.Lock()
        self._default_upstream: int | None = None
        self._host_upstreams: dict[str, int] = {}
        self._fallbacks: list[int] = []
        self._server: socket.socket | None = None
        self._port: int | None = None
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._active_conns = 0
        self._total_requests = 0

    @property
    def port(self) -> int | None:
        return self._port

    @property
    def running(self) -> bool:
        return self._server is not None and not self._stop.is_set()

    def stats(self) -> tuple[int, int, int | None]:
        with self._lock:
            return self._active_conns, self._total_requests, self._default_upstream

    def update_routes(
        self,
        default_upstream: int | None,
        host_upstreams: dict[str, int] | None = None,
        fallbacks: list[int] | None = None,
    ) -> None:
        with self._lock:
            self._default_upstream = default_upstream if (default_upstream and default_upstream != self._port) else None
            cleaned_hosts: dict[str, int] = {}
            for host, upstream in (host_upstreams or {}).items():
                h = host.split("/", 1)[0].strip().lower().rstrip(".")
                if h and upstream and upstream != self._port:
                    cleaned_hosts[h] = upstream
            self._host_upstreams = cleaned_hosts
            self._fallbacks = [
                p for p in dict.fromkeys(fallbacks or ())
                if p and p != self._port and p != self._default_upstream
            ]

    def start(self) -> int:
        if self.running and self._port:
            return self._port
        self._stop.clear()
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        bound_port = None
        for candidate in (self._preferred_port, self._preferred_port + 1, self._preferred_port + 2, 0):
            try:
                srv.bind(("127.0.0.1", candidate))
                bound_port = srv.getsockname()[1]
                break
            except OSError:
                continue
        if bound_port is None:
            srv.close()
            raise OSError("无法在 127.0.0.1 上启动本地中继端口")
        srv.listen(128)
        srv.settimeout(0.5)
        self._server = srv
        self._port = bound_port
        self._thread = threading.Thread(target=self._accept_loop, daemon=True, name="LocalProxyRelay")
        self._thread.start()
        return bound_port

    def stop(self) -> None:
        self._stop.set()
        if self._server:
            try:
                self._server.close()
            except OSError:
                pass
            self._server = None
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=1.5)
        self._port = None

    def _select_upstreams(self, host: str) -> list[int]:
        h = host.strip().lower().rstrip(".")
        with self._lock:
            ordered: list[int] = []
            if h in self._host_upstreams:
                ordered.append(self._host_upstreams[h])
            else:
                for pattern, port in self._host_upstreams.items():
                    if h.endswith("." + pattern):
                        ordered.append(port)
                        break
            if self._default_upstream:
                ordered.append(self._default_upstream)
            ordered.extend(self._fallbacks)
            return list(dict.fromkeys(p for p in ordered if p and p != self._port))

    def _accept_loop(self) -> None:
        assert self._server is not None
        while not self._stop.is_set():
            try:
                client, _addr = self._server.accept()
            except TimeoutError:
                continue
            except OSError:
                break
            threading.Thread(target=self._handle_client, args=(client,), daemon=True).start()

    def _extract_host(self, first_line: bytes, headers: bytes) -> str:
        try:
            parts = first_line.decode("latin1").split()
            if len(parts) >= 2:
                method, target = parts[0].upper(), parts[1]
                if method == "CONNECT":
                    return target.rsplit(":", 1)[0].strip("[]")
                if "://" in target:
                    parsed = urlsplit(target)
                    if parsed.hostname:
                        return parsed.hostname
        except ValueError:
            pass
        for raw_line in headers.splitlines():
            if raw_line.lower().startswith(b"host:"):
                val = raw_line.split(b":", 1)[1].strip().decode("latin1", errors="ignore")
                return val.rsplit(":", 1)[0].strip("[]")
        return ""

    def _handle_client(self, client: socket.socket) -> None:
        with self._lock:
            self._active_conns += 1
        upstream: socket.socket | None = None
        try:
            client.settimeout(10.0)
            buf = bytearray()
            while b"\r\n\r\n" not in buf and len(buf) < 65536:
                chunk = client.recv(8192)
                if not chunk:
                    return
                buf.extend(chunk)
            sep = buf.find(b"\r\n\r\n")
            if sep < 0:
                client.sendall(b"HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n")
                return
            head = bytes(buf[:sep + 4])
            rest = bytes(buf[sep + 4:])
            first_line, _, header_block = head.partition(b"\r\n")
            host = self._extract_host(first_line, header_block)
            upstreams = self._select_upstreams(host)
            if not upstreams:
                client.sendall(b"HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n")
                return
            with self._lock:
                self._total_requests += 1

            for port in upstreams:
                try:
                    # Loopback TCP connect succeeds in <1ms when alive; short timeout avoids Windows' 2s SYN retry on dead upstreams.
                    upstream = socket.create_connection(("127.0.0.1", port), timeout=0.35)
                    break
                except OSError:
                    upstream = None
            if upstream is None:
                client.sendall(b"HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n")
                return

            upstream.sendall(head)
            if rest:
                upstream.sendall(rest)

            client.settimeout(None)
            upstream.settimeout(None)
            t1 = threading.Thread(target=_pipe_bytes, args=(client, upstream), daemon=True)
            t2 = threading.Thread(target=_pipe_bytes, args=(upstream, client), daemon=True)
            t1.start()
            t2.start()
            t1.join()
            t2.join()
        except OSError:
            pass
        finally:
            for sock in (upstream, client):
                if sock:
                    try:
                        sock.close()
                    except OSError:
                        pass
            with self._lock:
                self._active_conns = max(0, self._active_conns - 1)


def _pipe_bytes(src: socket.socket, dst: socket.socket) -> None:
    try:
        while True:
            data = src.recv(32768)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except OSError:
            pass
