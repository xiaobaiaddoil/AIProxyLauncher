import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const int defaultRelayPort = 17890;

class UpstreamSpec {
  const UpstreamSpec({
    required this.scheme, // "http" or "socks5"
    required this.host,
    required this.port,
  });

  final String scheme;
  final String host;
  final int port;

  bool get valid =>
      (scheme == 'http' || scheme == 'socks5') &&
      host.isNotEmpty &&
      port >= 1 &&
      port <= 65535;

  String get label =>
      scheme == 'socks5' ? 'socks5://$host:$port' : '$host:$port';

  @override
  bool operator ==(Object other) =>
      other is UpstreamSpec &&
      other.scheme == scheme &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(scheme, host, port);
}

class _SocketReader {
  _SocketReader(Socket socket) : _iterator = StreamIterator<Uint8List>(socket);

  final StreamIterator<Uint8List> _iterator;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  bool _eof = false;

  Future<bool> _fill(Duration timeout) async {
    if (_eof) return false;
    final hasNext = await _iterator.moveNext().timeout(timeout);
    if (!hasNext) {
      _eof = true;
      return false;
    }
    _buffer.add(_iterator.current);
    return true;
  }

  Future<Uint8List> readExact(int count, Duration timeout) async {
    while (_buffer.length < count) {
      if (!await _fill(timeout)) {
        throw const SocketException('Unexpected EOF during SOCKS5 handshake');
      }
    }
    final all = _buffer.takeBytes();
    if (all.length > count) {
      _buffer.add(all.sublist(count));
    }
    return Uint8List.sublistView(all, 0, count);
  }

  Future<(Uint8List, Uint8List)> readUntilHeaderEnd(
    Duration timeout, {
    int maxBytes = 65536,
  }) async {
    while (true) {
      final current = _buffer.toBytes();
      final idx = _indexOfCrlfCrlf(current);
      if (idx >= 0) {
        final split = idx + 4;
        _buffer.clear();
        return (
          Uint8List.sublistView(current, 0, split),
          Uint8List.sublistView(current, split),
        );
      }
      if (current.length > maxBytes) {
        throw const SocketException('HTTP request header too large');
      }
      if (!await _fill(timeout)) {
        throw const SocketException('Connection closed before HTTP header end');
      }
    }
  }

  Uint8List takeBuffered() => _buffer.takeBytes();

  Stream<Uint8List> remainingStream() async* {
    final leftover = _buffer.takeBytes();
    if (leftover.isNotEmpty) {
      yield leftover;
    }
    while (!_eof && await _iterator.moveNext()) {
      yield _iterator.current;
    }
  }

  Future<void> cancel() async {
    try {
      await _iterator.cancel();
    } catch (_) {}
  }

  static int _indexOfCrlfCrlf(Uint8List data) {
    for (int i = 0; i + 3 < data.length; i++) {
      if (data[i] == 13 &&
          data[i + 1] == 10 &&
          data[i + 2] == 13 &&
          data[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }
}

class Socks5Connection {
  Socks5Connection._(this.socket, this._reader);

  final Socket socket;
  final _SocketReader _reader;

  Uint8List takeBuffered() => _reader.takeBuffered();
  Stream<Uint8List> remainingStream() => _reader.remainingStream();

  Future<void> close() async {
    await _reader.cancel();
    try {
      socket.destroy();
    } catch (_) {}
  }
}

/// Pure Dart RFC 1928 SOCKS5 upstream dialer (anonymous auth, ATYP=3 domain connect).
Future<Socks5Connection> dialSocks5Upstream(
  String proxyHost,
  int proxyPort,
  String targetHost,
  int targetPort, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  final connectTimeout =
      timeout < const Duration(milliseconds: 500) ? timeout : const Duration(milliseconds: 500);
  final socket = await Socket.connect(proxyHost, proxyPort, timeout: connectTimeout);
  final reader = _SocketReader(socket);
  try {
    socket.add(const [0x05, 0x01, 0x00]);
    await socket.flush().timeout(timeout);
    final greeting = await reader.readExact(2, timeout);
    if (greeting[0] != 0x05 || greeting[1] != 0x00) {
      throw const SocketException('SOCKS5 handshake rejected');
    }

    final hostBytes = utf8.encode(targetHost);
    if (hostBytes.isEmpty || hostBytes.length > 255) {
      throw const SocketException('Invalid SOCKS5 target host');
    }
    final req = BytesBuilder()
      ..add(const [0x05, 0x01, 0x00, 0x03])
      ..addByte(hostBytes.length)
      ..add(hostBytes)
      ..addByte((targetPort >> 8) & 0xFF)
      ..addByte(targetPort & 0xFF);
    socket.add(req.takeBytes());
    await socket.flush().timeout(timeout);

    final reply = await reader.readExact(4, timeout);
    if (reply[0] != 0x05 || reply[1] != 0x00) {
      throw SocketException('SOCKS5 connect failed (rep=${reply[1]})');
    }
    final atyp = reply[3];
    if (atyp == 0x01) {
      await reader.readExact(6, timeout);
    } else if (atyp == 0x03) {
      final alen = (await reader.readExact(1, timeout))[0];
      await reader.readExact(alen + 2, timeout);
    } else if (atyp == 0x04) {
      await reader.readExact(18, timeout);
    } else {
      throw const SocketException('Unsupported SOCKS5 address type');
    }
    return Socks5Connection._(socket, reader);
  } catch (_) {
    await reader.cancel();
    socket.destroy();
    rethrow;
  }
}

/// Lightweight loopback-only HTTP/CONNECT relay supporting both HTTP and SOCKS5 upstreams,
/// per-domain routing, 350ms dead-upstream failover, and strict HTTP 502 (never direct leaks).
class LocalProxyRelay {
  LocalProxyRelay({this.preferredPort = defaultRelayPort});

  final int preferredPort;
  ServerSocket? _server;
  int? _port;
  UpstreamSpec? _defaultUpstream;
  Map<String, UpstreamSpec> _hostUpstreams = const {};
  List<UpstreamSpec> _fallbacks = const [];
  int _activeConns = 0;
  int _totalRequests = 0;

  int? get port => _port;
  bool get running => _server != null;
  int get activeConnections => _activeConns;
  int get totalRequests => _totalRequests;
  UpstreamSpec? get defaultUpstream => _defaultUpstream;

  void updateRoutes({
    UpstreamSpec? defaultUpstream,
    Map<String, UpstreamSpec> hostUpstreams = const {},
    List<UpstreamSpec> fallbacks = const [],
  }) {
    _defaultUpstream = _sanitize(defaultUpstream);
    final cleaned = <String, UpstreamSpec>{};
    for (final entry in hostUpstreams.entries) {
      final host = entry.key.split('/').first.trim().toLowerCase().replaceAll(RegExp(r'\.$'), '');
      final up = _sanitize(entry.value);
      if (host.isNotEmpty && up != null) {
        cleaned[host] = up;
      }
    }
    _hostUpstreams = cleaned;
    final fb = <UpstreamSpec>[];
    for (final item in fallbacks) {
      final up = _sanitize(item);
      if (up != null && up != _defaultUpstream && !fb.contains(up)) {
        fb.add(up);
      }
    }
    _fallbacks = fb;
  }

  UpstreamSpec? _sanitize(UpstreamSpec? spec) {
    if (spec == null || !spec.valid) return null;
    if (_port != null &&
        (spec.host == '127.0.0.1' || spec.host.toLowerCase() == 'localhost') &&
        spec.port == _port) {
      return null;
    }
    return spec;
  }

  Future<int> start() async {
    if (_server != null && _port != null) return _port!;
    final candidates = preferredPort > 0
        ? [preferredPort, preferredPort + 1, preferredPort + 2, 0]
        : [0];
    ServerSocket? bound;
    for (final p in candidates) {
      try {
        bound = await ServerSocket.bind(InternetAddress.loopbackIPv4, p);
        break;
      } catch (_) {
        continue;
      }
    }
    if (bound == null) {
      throw const SocketException('无法在 127.0.0.1 上启动本地中继端口');
    }
    _server = bound;
    _port = bound.port;
    bound.listen(
      (client) {
        unawaited(_handleClient(client));
      },
      onError: (_) {},
    );
    return _port!;
  }

  Future<void> stop() async {
    final srv = _server;
    _server = null;
    _port = null;
    if (srv != null) {
      try {
        await srv.close();
      } catch (_) {}
    }
  }

  List<UpstreamSpec> _candidatesFor(String host) {
    final order = <UpstreamSpec>[];
    final lower = host.toLowerCase().replaceAll(RegExp(r'\.$'), '');
    final exact = _hostUpstreams[lower];
    if (exact != null) order.add(exact);
    if (_defaultUpstream != null && !order.contains(_defaultUpstream)) {
      order.add(_defaultUpstream!);
    }
    for (final fb in _fallbacks) {
      if (!order.contains(fb)) order.add(fb);
    }
    return order;
  }

  Future<void> _handleClient(Socket client) async {
    _activeConns++;
    _totalRequests++;
    final clientReader = _SocketReader(client);
    try {
      final (headBytes, leftover) =
          await clientReader.readUntilHeaderEnd(const Duration(seconds: 5));
      final headText = latin1.decode(headBytes);
      final lines = headText.split('\r\n');
      if (lines.isEmpty) {
        await _send502(client, 'Malformed proxy request');
        return;
      }
      final parts = lines.first.split(' ');
      if (parts.length < 3) {
        await _send502(client, 'Malformed proxy request line');
        return;
      }
      final method = parts[0].toUpperCase();
      final target = parts[1];
      final version = parts[2];

      final (targetHost, targetPort) = _extractTarget(method, target, lines);
      if (targetHost.isEmpty || targetPort <= 0) {
        await _send502(client, 'Unable to determine target host');
        return;
      }

      final candidates = _candidatesFor(targetHost);
      if (candidates.isEmpty) {
        await _send502(client, 'No upstream proxy configured');
        return;
      }

      for (final up in candidates) {
        if (up.scheme == 'http') {
          Socket? upstream;
          try {
            upstream = await Socket.connect(
              up.host,
              up.port,
              timeout: const Duration(milliseconds: 350),
            );
          } catch (_) {
            continue;
          }
          try {
            upstream.add(headBytes);
            if (leftover.isNotEmpty) upstream.add(leftover);
            await _pipeBidirectional(
              client,
              clientReader.remainingStream(),
              upstream,
              upstream,
            );
            return;
          } finally {
            upstream.destroy();
          }
        } else if (up.scheme == 'socks5') {
          Socks5Connection? s5;
          try {
            s5 = await dialSocks5Upstream(
              up.host,
              up.port,
              targetHost,
              targetPort,
              timeout: const Duration(seconds: 3),
            );
          } catch (_) {
            continue;
          }
          try {
            if (method == 'CONNECT') {
              client.add(ascii.encode('HTTP/1.1 200 Connection Established\r\n\r\n'));
              await client.flush();
              if (leftover.isNotEmpty) s5.socket.add(leftover);
            } else {
              final rewritten = _rewritePlainHttpRequest(method, target, version, lines);
              s5.socket.add(rewritten);
              if (leftover.isNotEmpty) s5.socket.add(leftover);
            }
            await _pipeBidirectional(
              client,
              clientReader.remainingStream(),
              s5.socket,
              s5.remainingStream(),
            );
            return;
          } finally {
            await s5.close();
          }
        }
      }

      await _send502(client, 'All local upstream proxies unavailable');
    } catch (_) {
      try {
        await _send502(client, 'Relay error');
      } catch (_) {}
    } finally {
      _activeConns--;
      await clientReader.cancel();
      try {
        client.destroy();
      } catch (_) {}
    }
  }

  static (String, int) _extractTarget(
    String method,
    String target,
    List<String> lines,
  ) {
    if (method == 'CONNECT') {
      final idx = target.lastIndexOf(':');
      if (idx > 0) {
        final h = target.substring(0, idx).replaceAll('[', '').replaceAll(']', '');
        final p = int.tryParse(target.substring(idx + 1)) ?? 443;
        return (h, p);
      }
      return (target, 443);
    }
    if (target.startsWith('http://') || target.startsWith('https://')) {
      final uri = Uri.tryParse(target);
      if (uri != null && uri.host.isNotEmpty) {
        final p = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
        return (uri.host, p);
      }
    }
    for (final line in lines.skip(1)) {
      if (line.toLowerCase().startsWith('host:')) {
        final val = line.substring(5).trim();
        final idx = val.lastIndexOf(':');
        if (idx > 0) {
          final h = val.substring(0, idx).replaceAll('[', '').replaceAll(']', '');
          final p = int.tryParse(val.substring(idx + 1)) ?? 80;
          return (h, p);
        }
        return (val, 80);
      }
    }
    return ('', 0);
  }

  static Uint8List _rewritePlainHttpRequest(
    String method,
    String target,
    String version,
    List<String> lines,
  ) {
    String originTarget = target;
    if (target.startsWith('http://') || target.startsWith('https://')) {
      final uri = Uri.tryParse(target);
      if (uri != null) {
        final path = uri.path.isEmpty ? '/' : uri.path;
        originTarget = uri.hasQuery ? '$path?${uri.query}' : path;
      }
    }
    final out = StringBuffer()..write('$method $originTarget $version\r\n');
    for (final line in lines.skip(1)) {
      if (line.isEmpty) continue;
      if (line.toLowerCase().startsWith('proxy-connection:')) continue;
      out.write('$line\r\n');
    }
    out.write('\r\n');
    return Uint8List.fromList(latin1.encode(out.toString()));
  }

  static Future<void> _pipeBidirectional(
    Socket client,
    Stream<Uint8List> clientIn,
    Socket upstream,
    Stream<Uint8List> upstreamIn,
  ) async {
    final c2u = () async {
      try {
        await for (final chunk in clientIn) {
          upstream.add(chunk);
        }
      } catch (_) {}
      try {
        await upstream.flush();
      } catch (_) {}
      try {
        upstream.close();
      } catch (_) {}
    }();

    final u2c = () async {
      try {
        await for (final chunk in upstreamIn) {
          client.add(chunk);
        }
      } catch (_) {}
      try {
        await client.flush();
      } catch (_) {}
      try {
        client.close();
      } catch (_) {}
    }();

    await Future.wait([c2u, u2c]);
  }

  static Future<void> _send502(Socket client, String message) async {
    try {
      final body = utf8.encode(message);
      final header =
          'HTTP/1.1 502 Bad Gateway\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: ${body.length}\r\nConnection: close\r\n\r\n';
      client.add(ascii.encode(header));
      client.add(body);
      await client.flush();
    } catch (_) {}
  }
}

