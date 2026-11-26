import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_proxy_launcher/services/local_relay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocalProxyRelay bridges HTTP CONNECT and plain HTTP over RFC 1928 SOCKS5',
      () async {
    final echoServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final echoSub = echoServer.listen((client) {
      client.listen((data) {
        final text = latin1.decode(data);
        if (text.startsWith('GET ')) {
          final resp =
              'HTTP/1.1 200 OK\r\nContent-Length: ${data.length}\r\nConnection: close\r\n\r\n$text';
          client.add(latin1.encode(resp));
        } else {
          client.add(ascii.encode('ECHO:'));
          client.add(data);
        }
        client.flush().then((_) => client.close());
      });
    });

    final seenTargets = <(String, int)>[];
    final socksServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final socksSub = socksServer.listen((client) async {
      final iter = StreamIterator<Uint8List>(client);
      final buf = <int>[];
      Future<List<int>> readN(int n) async {
        while (buf.length < n) {
          if (!await iter.moveNext()) throw const SocketException('EOF');
          buf.addAll(iter.current);
        }
        final out = buf.sublist(0, n);
        buf.removeRange(0, n);
        return out;
      }

      try {
        final head = await readN(2);
        expect(head[0], 5);
        await readN(head[1]);
        client.add(const [0x05, 0x00]);
        await client.flush();

        final req = await readN(4);
        expect(req[1], 1);
        expect(req[3], 3);
        final alen = (await readN(1))[0];
        final dom = utf8.decode(await readN(alen));
        final portBytes = await readN(2);
        final dport = (portBytes[0] << 8) | portBytes[1];
        seenTargets.add((dom, dport));

        final upstream = await Socket.connect(
          InternetAddress.loopbackIPv4,
          echoServer.port,
        );
        client.add(const [0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0, 0]);
        await client.flush();

        final upDone = upstream.listen(
          client.add,
          onDone: () => client.close(),
        ).asFuture<void>();

        if (buf.isNotEmpty) {
          upstream.add(Uint8List.fromList(buf));
          buf.clear();
        }
        while (await iter.moveNext()) {
          upstream.add(iter.current);
        }
        await upstream.flush();
        await upstream.close();
        await upDone;
      } catch (_) {
        client.destroy();
      } finally {
        await iter.cancel();
      }
    });

    final relay = LocalProxyRelay(preferredPort: 0);
    try {
      final rport = await relay.start();
      relay.updateRoutes(
        defaultUpstream: UpstreamSpec(
          scheme: 'socks5',
          host: '127.0.0.1',
          port: socksServer.port,
        ),
      );

      // 1. HTTPS CONNECT via HTTP relay -> SOCKS5 upstream
      final c1 = await Socket.connect('127.0.0.1', rport);
      final iter1 = StreamIterator<Uint8List>(c1);
      c1.add(ascii.encode(
        'CONNECT chatgpt.com:443 HTTP/1.1\r\nHost: chatgpt.com:443\r\n\r\n',
      ));
      await c1.flush();
      final statusBuf = <int>[];
      while (!latin1.decode(statusBuf).contains('\r\n\r\n')) {
        expect(await iter1.moveNext(), isTrue);
        statusBuf.addAll(iter1.current);
      }
      expect(latin1.decode(statusBuf), contains('200 Connection Established'));
      c1.add(ascii.encode('PING_MOBILE_SOCKS5'));
      await c1.flush();
      final echoBuf = <int>[];
      while (await iter1.moveNext()) {
        echoBuf.addAll(iter1.current);
      }
      expect(ascii.decode(echoBuf), 'ECHO:PING_MOBILE_SOCKS5');
      await iter1.cancel();
      c1.destroy();

      // 2. Plain HTTP absolute-URI request rewritten for SOCKS5 upstream
      final c2 = await Socket.connect('127.0.0.1', rport);
      c2.add(ascii.encode(
        'GET http://plain.example/check?v=2 HTTP/1.1\r\n'
        'Host: plain.example\r\nProxy-Connection: keep-alive\r\n\r\n',
      ));
      await c2.flush();
      final resp2 = await utf8.decoder.bind(c2).join();
      c2.destroy();
      expect(resp2, contains('HTTP/1.1 200 OK'));
      expect(resp2, contains('GET /check?v=2 HTTP/1.1'));
      expect(resp2, isNot(contains('Proxy-Connection')));

      expect(seenTargets, contains(('chatgpt.com', 443)));
      expect(seenTargets, contains(('plain.example', 80)));
    } finally {
      await relay.stop();
      await socksSub.cancel();
      await socksServer.close();
      await echoSub.cancel();
      await echoServer.close();
    }
  });

  test('LocalProxyRelay strictly returns HTTP 502 with zero direct leak when no upstream',
      () async {
    final relay = LocalProxyRelay(preferredPort: 0);
    try {
      final port = await relay.start();
      relay.updateRoutes(); // no upstreams
      final sock = await Socket.connect('127.0.0.1', port);
      sock.add(ascii.encode(
        'CONNECT chatgpt.com:443 HTTP/1.1\r\nHost: chatgpt.com:443\r\n\r\n',
      ));
      await sock.flush();
      final resp = await utf8.decoder.bind(sock).join();
      sock.destroy();
      expect(resp, contains('502 Bad Gateway'));
    } finally {
      await relay.stop();
    }
  });
}

