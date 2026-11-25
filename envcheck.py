"""Audit and repair stale proxy settings in user environment and dev tool configs."""
from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import re
import socket
import sys
import tempfile

if sys.platform == "win32":
    import ctypes
    import winreg


HOME = Path.home()
LOOPBACK_PROXY = re.compile(
    r"^(?:https?://|socks5h?://)?(?:127\.0\.0\.1|localhost|\[::1\]):([0-9]{1,5})/?$",
    re.I,
)


@dataclass(frozen=True)
class EnvConflict:
    id: str
    source: str
    key: str
    current_value: str
    reason: str
    action: str  # "sync" or "clear"
    target_port: int | None = None
    path: Path | None = None


def _extract_local_port(value: str) -> int | None:
    match = LOOPBACK_PROXY.fullmatch(value.strip().strip('"').strip("'"))
    if match and 1 <= int(match[1]) <= 65535:
        return int(match[1])
    return None


def port_listening(port: int, timeout: float = 0.25) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=timeout):
            return True
    except OSError:
        return False


def _backup_and_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_name(path.name + ".ai-proxy-launcher.bak")
        if not backup.exists():
            try:
                backup.write_bytes(path.read_bytes())
            except OSError:
                pass
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False, newline="") as out:
        tmp = Path(out.name)
        try:
            out.write(text)
            out.close()
            os.replace(tmp, path)
        finally:
            tmp.unlink(missing_ok=True)


def _read_windows_user_env() -> dict[str, str]:
    if sys.platform != "win32":
        return {}
    result: dict[str, str] = {}
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment", 0, winreg.KEY_READ) as key:
            count = winreg.QueryInfoKey(key)[1]
            for i in range(count):
                name, value, _kind = winreg.EnumValue(key, i)
                if isinstance(name, str) and isinstance(value, str):
                    result[name] = value
    except OSError:
        pass
    return result


def _broadcast_env_change() -> None:
    if sys.platform != "win32":
        return
    try:
        HWND_BROADCAST = 0xFFFF
        WM_SETTINGCHANGE = 0x001A
        SMTO_ABORTIFHUNG = 0x0002
        ctypes.windll.user32.SendMessageTimeoutW(
            HWND_BROADCAST, WM_SETTINGCHANGE, 0, "Environment", SMTO_ABORTIFHUNG, 1000, None
        )
    except Exception:
        pass


def audit_environment(
    active_ports: list[int],
    preferred_port: int | None = None,
    *,
    home: Path | None = None,
    codex_env: Path | None = None,
    user_env: dict[str, str] | None = None,
    process_env: dict[str, str] | None = None,
    port_checker=port_listening,
) -> list[EnvConflict]:
    """Inspect user environment variables, .codex/.env, .gitconfig, and .npmrc for stale proxy settings."""
    root = home or HOME
    active_set = {p for p in active_ports if isinstance(p, int) and 1 <= p <= 65535}
    target = preferred_port if preferred_port in active_set else (active_ports[0] if active_ports else None)
    conflicts: list[EnvConflict] = []

    def is_stale(port: int) -> bool:
        if port in active_set:
            return False
        return not port_checker(port)

    # 1. Windows User Environment Variables (registry)
    reg_env = _read_windows_user_env() if user_env is None else user_env
    for name, value in reg_env.items():
        upper = name.upper()
        if upper in {"HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY"}:
            port = _extract_local_port(value)
            if port and is_stale(port):
                conflicts.append(EnvConflict(
                    id=f"winenv:{name}",
                    source="Windows 用户环境变量",
                    key=name,
                    current_value=value,
                    reason=f"指向未监听的旧端口 :{port}" + (f"（当前可用 :{target}）" if target else ""),
                    action="sync" if target else "clear",
                    target_port=target,
                ))
        elif upper == "NO_PROXY" and value.strip() == "*":
            conflicts.append(EnvConflict(
                id=f"winenv:{name}",
                source="Windows 用户环境变量",
                key=name,
                current_value=value,
                reason="NO_PROXY=* 会导致所有应用强制绕过代理直连",
                action="clear",
            ))

    # Also warn about non-persistent current process env NO_PROXY=* if not already in registry
    proc_env = os.environ if process_env is None else process_env
    for name, value in proc_env.items():
        if name.upper() == "NO_PROXY" and value.strip() == "*" and f"winenv:{name}" not in {c.id for c in conflicts}:
            conflicts.append(EnvConflict(
                id=f"procenv:{name}",
                source="当前进程环境变量",
                key=name,
                current_value=value,
                reason="当前会话存在 NO_PROXY=*（请检查系统环境变量或 shell 启动脚本）",
                action="clear",
            ))

    # 2. ~/.codex/.env
    dotenv_path = codex_env or (Path(os.environ.get("CODEX_HOME") or (root / ".codex")) / ".env")
    if dotenv_path.is_file():
        try:
            text = dotenv_path.read_text(encoding="utf-8-sig")
            seen_ports: set[int] = set()
            for line in text.splitlines():
                m = re.match(r"^\s*(?:export\s+)?(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY)\s*=\s*(.+?)\s*$", line, re.I)
                if m:
                    port = _extract_local_port(m[2])
                    if port and port not in seen_ports and (is_stale(port) or (target and port != target)):
                        seen_ports.add(port)
                        status = "端口未监听" if is_stale(port) else f"与当前代理 :{target} 不一致"
                        conflicts.append(EnvConflict(
                            id=f"codex:{port}",
                            source="Codex 配置 (.codex/.env)",
                            key=m[1].upper(),
                            current_value=m[2].strip(),
                            reason=f"旧端口 :{port}（{status}）",
                            action="sync" if target else "clear",
                            target_port=target,
                            path=dotenv_path,
                        ))
        except OSError:
            pass

    # 3. ~/.gitconfig
    gitconfig = root / ".gitconfig"
    if gitconfig.is_file():
        try:
            section = ""
            for line in gitconfig.read_text(encoding="utf-8-sig", errors="replace").splitlines():
                stripped = line.strip()
                if stripped.startswith("[") and stripped.endswith("]"):
                    section = stripped[1:-1].strip().lower()
                    continue
                if section in {"http", "https"}:
                    m = re.match(r"^proxy\s*=\s*(.+?)\s*$", stripped, re.I)
                    if m:
                        port = _extract_local_port(m[1])
                        if port and is_stale(port):
                            conflicts.append(EnvConflict(
                                id=f"git:{section}.proxy",
                                source="Git 配置 (.gitconfig)",
                                key=f"{section}.proxy",
                                current_value=m[1].strip(),
                                reason=f"指向未监听的旧端口 :{port}",
                                action="sync" if target else "clear",
                                target_port=target,
                                path=gitconfig,
                            ))
        except OSError:
            pass

    # 4. ~/.npmrc
    npmrc = root / ".npmrc"
    if npmrc.is_file():
        try:
            for line in npmrc.read_text(encoding="utf-8-sig", errors="replace").splitlines():
                m = re.match(r"^\s*(proxy|https-proxy)\s*=\s*(.+?)\s*$", line, re.I)
                if m:
                    port = _extract_local_port(m[2])
                    if port and is_stale(port):
                        conflicts.append(EnvConflict(
                            id=f"npm:{m[1].lower()}",
                            source="npm 配置 (.npmrc)",
                            key=m[1].lower(),
                            current_value=m[2].strip(),
                            reason=f"指向未监听的旧端口 :{port}",
                            action="sync" if target else "clear",
                            target_port=target,
                            path=npmrc,
                        ))
        except OSError:
            pass

    return conflicts


def fix_conflict(conflict: EnvConflict) -> str:
    """Apply a safe repair for a single EnvConflict (with automatic .bak backup for files)."""
    new_url = f"http://127.0.0.1:{conflict.target_port}" if (conflict.action == "sync" and conflict.target_port) else ""

    if conflict.id.startswith("winenv:"):
        if sys.platform != "win32":
            raise OSError("仅 Windows 支持修改注册表用户环境变量")
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment", 0, winreg.KEY_SET_VALUE) as key:
            if new_url:
                winreg.SetValueEx(key, conflict.key, 0, winreg.REG_SZ, new_url)
                os.environ[conflict.key] = new_url
            else:
                try:
                    winreg.DeleteValue(key, conflict.key)
                except FileNotFoundError:
                    pass
                os.environ.pop(conflict.key, None)
        _broadcast_env_change()
        return f"已更新环境变量 {conflict.key}" if new_url else f"已清理失效环境变量 {conflict.key}"

    if conflict.id.startswith("procenv:"):
        os.environ.pop(conflict.key, None)
        return f"已清理当前会话的 {conflict.key}"

    if conflict.id.startswith("codex:") and conflict.path:
        text = conflict.path.read_text(encoding="utf-8-sig")
        newline = "\r\n" if "\r\n" in text else "\n"
        pattern = re.compile(r"^\s*(?:export\s+)?(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY|WS_PROXY|WSS_PROXY)\s*=", re.I)
        kept = [line for line in text.splitlines(keepends=True) if not pattern.match(line)]
        if kept and not kept[-1].endswith(("\n", "\r")):
            kept[-1] += newline
        if new_url:
            kept.extend([
                f"HTTP_PROXY={new_url}{newline}",
                f"HTTPS_PROXY={new_url}{newline}",
                f"ALL_PROXY={new_url}{newline}",
                f"NO_PROXY=localhost,127.0.0.1,::1{newline}",
            ])
        _backup_and_write_text(conflict.path, "".join(kept))
        return f"已同步 Codex 配置端口至 :{conflict.target_port}" if new_url else "已清理 Codex 失效代理配置"

    if conflict.id.startswith("git:") and conflict.path:
        target_sec = conflict.key.split(".", 1)[0].lower()
        text = conflict.path.read_text(encoding="utf-8-sig", errors="replace")
        newline = "\r\n" if "\r\n" in text else "\n"
        section = ""
        out_lines: list[str] = []
        for line in text.splitlines(keepends=True):
            stripped = line.strip()
            if stripped.startswith("[") and stripped.endswith("]"):
                section = stripped[1:-1].strip().lower()
                out_lines.append(line)
                continue
            if section == target_sec and re.match(r"^proxy\s*=", stripped, re.I):
                if new_url:
                    indent = line[:len(line) - len(line.lstrip())]
                    out_lines.append(f"{indent}proxy = {new_url}{newline}")
                continue
            out_lines.append(line)
        _backup_and_write_text(conflict.path, "".join(out_lines))
        return f"已更新 Git {conflict.key} 至 :{conflict.target_port}" if new_url else f"已清理 Git {conflict.key}"

    if conflict.id.startswith("npm:") and conflict.path:
        text = conflict.path.read_text(encoding="utf-8-sig", errors="replace")
        newline = "\r\n" if "\r\n" in text else "\n"
        pattern = re.compile(rf"^\s*{re.escape(conflict.key)}\s*=", re.I)
        out_lines = []
        for line in text.splitlines(keepends=True):
            if pattern.match(line):
                if new_url:
                    out_lines.append(f"{conflict.key}={new_url}{newline}")
                continue
            out_lines.append(line)
        _backup_and_write_text(conflict.path, "".join(out_lines))
        return f"已更新 npm {conflict.key} 至 :{conflict.target_port}" if new_url else f"已清理 npm {conflict.key}"

    raise ValueError("暂不支持自动修复该条目")


@dataclass(frozen=True)
class HealthFinding:
    category: str
    status: str  # "ok", "warn", "error"
    title: str
    detail: str


def _has_global_ipv6() -> str:
    """Return local global-unicast IPv6 address if OS has an active IPv6 default route, else ''."""
    try:
        with socket.socket(socket.AF_INET6, socket.SOCK_DGRAM) as s:
            s.settimeout(0.4)
            s.connect(("2001:4860:4860::8888", 80))
            addr = s.getsockname()[0]
        lower = addr.lower()
        if lower in {"::1", "::"} or lower.startswith(("fe80:", "fc", "fd")):
            return ""
        return addr
    except OSError:
        return ""


def _resolve_ipv4_hosts(hosts: tuple[str, ...]) -> dict[str, list[str]]:
    resolved: dict[str, list[str]] = {}
    for host in hosts:
        try:
            infos = socket.getaddrinfo(host, 443, socket.AF_INET, socket.SOCK_STREAM)
            ips = list(dict.fromkeys(info[4][0] for info in infos))
            resolved[host] = ips
        except OSError:
            resolved[host] = []
    return resolved


def diagnose_network_health(
    tun_active: bool,
    *,
    resolver=_resolve_ipv4_hosts,
    ipv6_detector=_has_global_ipv6,
) -> list[HealthFinding]:
    """Check hidden root causes of 'green probe but broken app': DNS poisoning/Fake-IP & IPv6 leak."""
    findings: list[HealthFinding] = []
    hosts = ("chatgpt.com", "claude.ai", "accounts.google.com")
    resolved = resolver(hosts)

    all_ips = [ip for ips in resolved.values() for ip in ips]
    fake_ips = [ip for ip in all_ips if ip.startswith(("198.18.", "198.19."))]
    bogon_ips = [ip for ip in all_ips if ip.startswith(("127.", "0.", "169.254."))]

    if bogon_ips:
        findings.append(HealthFinding(
            "DNS", "error", "检测到异常/环回 DNS 解析",
            f"部分 AI 域名解析到了异常地址（{', '.join(sorted(set(bogon_ips)))}），请检查 hosts 文件或代理 DNS 设置。",
        ))
    elif fake_ips:
        findings.append(HealthFinding(
            "DNS", "ok", "Fake-IP DNS 接管正常",
            f"AI 域名已由代理 Fake-IP 接管（示例 {fake_ips[0]}），可有效防止本地 DNS 污染。",
        ))
    elif not all_ips:
        findings.append(HealthFinding(
            "DNS", "warn", "系统 DNS 暂时无法解析 AI 域名",
            "若使用浏览器/代理端口一般不受影响；桌面客户端依赖 TUN 时建议开启代理软件的 DNS 劫持 / Fake-IP。",
        ))
    else:
        # Check if multiple unrelated AI domains resolved to the exact same non-Fake-IP (classic DNS poisoning sign)
        first_ips = [ips[0] for ips in resolved.values() if ips]
        if len(first_ips) >= 3 and len(set(first_ips)) == 1:
            findings.append(HealthFinding(
                "DNS", "error", "DNS 疑似存在污染",
                f"多个不同 AI 域名均解析到同一 IP（{first_ips[0]}），建议在代理软件开启 Fake-IP 或加密 DNS。",
            ))
        elif tun_active:
            findings.append(HealthFinding(
                "DNS", "warn", "TUN 已开但未检测到 Fake-IP",
                f"当前解析为真实 IP（如 {first_ips[0]}）；若桌面端仍超时，建议在代理软件启用 Fake-IP / DNS 劫持。",
            ))
        else:
            findings.append(HealthFinding(
                "DNS", "ok", "系统 DNS 解析可用",
                "未发现环回或明显冲突解析（桌面端走 TUN 时建议配合 Fake-IP 使用）。",
            ))

    global_v6 = ipv6_detector()
    if global_v6:
        # Mask last segments for privacy
        masked_v6 = ":".join(global_v6.split(":")[:3]) + "::…"
        findings.append(HealthFinding(
            "IPv6", "warn", "检测到公网 IPv6（注意潜在泄漏/超时）",
            f"本机存在公网 IPv6 出口（{masked_v6}）。若桌面客户端在 TUN 下加载缓慢，请在代理软件开启 IPv6 接管或关闭网卡 IPv6。",
        ))
    else:
        findings.append(HealthFinding(
            "IPv6", "ok", "无公网 IPv6 泄漏风险",
            "当前未检测到公网 IPv6 默认路由。",
        ))

    return findings


def build_diagnostic_report(
    reports: list,
    detected: tuple[str, ...],
    findings: list[HealthFinding],
    conflicts: list[EnvConflict],
    *,
    relay_port: int | None = None,
    provider_mode: str = "",
) -> str:
    """Build a sanitized plain-text diagnostic summary safe to paste into issues or support chats."""
    import platform
    lines = [
        "=== AI 代理启动器 · 脱敏诊断报告 ===",
        f"系统: {platform.system()} {platform.release()} ({platform.machine()}) / Python {platform.python_version()}",
        f"代理模式: {provider_mode or '自动检测'} | 检测到客户端: {'、'.join(detected) or '无'}",
        f"统一本地中继: {'已开启 127.0.0.1:' + str(relay_port) if relay_port else '未开启'}",
        "",
        "[活跃代理与服务探针]",
    ]
    if not reports:
        lines.append("- 无可用代理")
    for rep in reports:
        if getattr(rep, "issue", ""):
            lines.append(f"- {rep.provider}: 错误 - {rep.issue}")
            continue
        reg = f" {rep.region}" if getattr(rep, "region", "") else ""
        lat = f" {rep.latency_ms}ms" if getattr(rep, "latency_ms", None) is not None else ""
        lines.append(f"- {rep.provider} :{rep.port} | mode={rep.mode} | tun={rep.tun} | api={rep.endpoint is not None}{reg}{lat}")
        for host, pr in (rep.probes or {}).items():
            node = f" | node={pr.node}" if getattr(pr, "node", "") else ""
            plat = f" | {pr.latency_ms}ms" if getattr(pr, "latency_ms", None) is not None else ""
            lines.append(f"    * {host}: ok={pr.connected} route={pr.route}{node}{plat} ({pr.detail})")
    lines.append("")
    lines.append("[网络底层体检 (DNS / IPv6)]")
    for f in findings:
        lines.append(f"- [{f.status.upper()}] {f.category} - {f.title}: {f.detail}")
    lines.append("")
    lines.append("[本机环境配置体检]")
    if not conflicts:
        lines.append("- 无冲突项")
    else:
        for c in conflicts:
            lines.append(f"- {c.source} | {c.key}={c.current_value} ({c.reason})")
    return "\n".join(lines)


