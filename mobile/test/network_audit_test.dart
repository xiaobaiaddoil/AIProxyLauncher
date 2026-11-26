import 'package:ai_proxy_launcher/models/models.dart';
import 'package:ai_proxy_launcher/services/network_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const audit = NetworkAuditService();

  test('diagnoseNetworkHealth detects Fake-IP, DNS poisoning, and masks IPv6',
      () async {
    const vpnState = NativeNetworkState(
      platform: 'android',
      osVersion: 'Android 15',
      vpnActive: true,
      vpnInterfaces: ['tun0'],
    );

    final okFindings = await audit.diagnoseNetworkHealth(
      networkState: vpnState,
      dnsResolver: (_) async => {
        'chatgpt.com': ['198.18.0.12'],
        'claude.ai': ['198.18.0.13'],
        'accounts.google.com': ['198.18.0.14'],
      },
      ipv6Detector: () async => '',
    );
    expect(okFindings.every((f) => f.status == 'ok'), isTrue);

    final badFindings = await audit.diagnoseNetworkHealth(
      networkState: vpnState,
      dnsResolver: (_) async => {
        'chatgpt.com': ['31.13.66.1'],
        'claude.ai': ['31.13.66.1'],
        'accounts.google.com': ['31.13.66.1'],
      },
      ipv6Detector: () async => '240e:3b4:1234:5678:abcd:ef01:2345:6789',
    );
    final dns = badFindings.firstWhere((f) => f.category == 'DNS');
    final v6 = badFindings.firstWhere((f) => f.category == 'IPv6');
    expect(dns.status, 'error');
    expect(dns.title, contains('污染'));
    expect(v6.status, 'warn');
    expect(v6.detail, contains('240e:3b4:1234::…'));
    expect(v6.detail, isNot(contains('6789')));
  });

  test('buildDiagnosticReport never leaks controller secrets', () {
    const ep = ControllerEndpoint(
      host: '127.0.0.1',
      port: 9090,
      secret: 'SUPER_SECRET_DO_NOT_LEAK',
      name: 'FlClash',
    );
    const report = ProxyReport(
      provider: 'FlClash',
      mode: 'rule',
      host: '127.0.0.1',
      port: 7890,
      tun: true,
      endpoint: ep,
      region: 'US',
      latencyMs: 112,
      probes: {
        'chatgpt.com': ProbeResult(
          host: 'chatgpt.com',
          connected: true,
          detail: '网站有响应（HTTP 200）',
          route: 'proxy',
          latencyMs: 112,
          node: 'US-01',
          region: 'US',
        ),
      },
    );

    final text = audit.buildDiagnosticReport(
      networkState: const NativeNetworkState(
        platform: 'ios',
        osVersion: 'iOS 18.2',
        vpnActive: true,
        vpnInterfaces: ['utun4'],
      ),
      reports: const [report],
      detectedProxyApps: [knownMobileProxyApps.first],
      findings: const [
        HealthFinding(
          category: 'DNS',
          status: 'ok',
          title: 'Fake-IP DNS 接管正常',
          detail: 'OK',
        ),
      ],
      proxyMode: autoMode,
      relayPort: 17890,
    );

    expect(text, contains('AI 代理启动器 (Mobile)'));
    expect(text, contains('FlClash :7890'));
    expect(text, contains('127.0.0.1:17890'));
    expect(text, isNot(contains('SUPER_SECRET_DO_NOT_LEAK')));
  });
}
