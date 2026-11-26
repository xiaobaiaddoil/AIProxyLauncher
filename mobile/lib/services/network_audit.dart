import 'dart:io';

import '../models/models.dart';

typedef DnsResolverFn = Future<Map<String, List<String>>> Function(List<String> hosts);
typedef Ipv6DetectorFn = Future<String> Function();

class NetworkAuditService {
  const NetworkAuditService();

  static Future<Map<String, List<String>>> defaultDnsResolver(
    List<String> hosts,
  ) async {
    final result = <String, List<String>>{};
    for (final host in hosts) {
      try {
        final addrs = await InternetAddress.lookup(
          host,
          type: InternetAddressType.IPv4,
        ).timeout(const Duration(seconds: 2));
        result[host] = addrs.map((e) => e.address).toSet().toList();
      } catch (_) {
        result[host] = const [];
      }
    }
    return result;
  }

  static Future<String> defaultGlobalIpv6Detector() async {
    try {
      final ifaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv6,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          final lower = addr.address.toLowerCase();
          if (lower == '::1' ||
              lower == '::' ||
              lower.startsWith('fe80:') ||
              lower.startsWith('fc') ||
              lower.startsWith('fd')) {
            continue;
          }
          return addr.address;
        }
      }
    } catch (_) {}
    return '';
  }

  Future<List<HealthFinding>> diagnoseNetworkHealth({
    required NativeNetworkState networkState,
    DnsResolverFn? dnsResolver,
    Ipv6DetectorFn? ipv6Detector,
  }) async {
    final findings = <HealthFinding>[];
    final resolve = dnsResolver ?? defaultDnsResolver;
    final detectV6 = ipv6Detector ?? defaultGlobalIpv6Detector;

    // 1. Mobile VPN & System Proxy Status
    if (networkState.vpnActive) {
      final ifaceText = networkState.vpnInterfaces.isNotEmpty
          ? '（${networkState.vpnInterfaces.take(2).join(', ')}）'
          : '';
      findings.add(HealthFinding(
        category: 'VPN',
        status: 'ok',
        title: '系统 VPN / 虚拟网卡已激活',
        detail: '当前设备处于 VPN 接管状态$ifaceText，手机原生 AI App 将自动走代理线路。',
      ));
    } else if (networkState.httpProxyPort != null) {
      findings.add(HealthFinding(
        category: 'VPN',
        status: 'warn',
        title: '仅检测到 Wi-Fi 系统代理（未开 VPN）',
        detail:
            '当前配置了 Wi-Fi 代理 ${networkState.httpProxyHost}:${networkState.httpProxyPort}；部分原生 App 可能忽略 Wi-Fi 代理，建议开启代理软件的 VPN 模式。',
      ));
    } else {
      findings.add(const HealthFinding(
        category: 'VPN',
        status: 'warn',
        title: '未检测到本机 VPN 网卡',
        detail: '若未使用路由器 / 旁路由透明代理，请先打开代理 App 并连接非受限地区节点。',
      ));
    }

    // 2. DNS Fake-IP / Poisoning Check
    const hosts = ['chatgpt.com', 'claude.ai', 'accounts.google.com'];
    final resolved = await resolve(hosts);
    final allIps = [for (final list in resolved.values) ...list];
    final fakeIps = allIps
        .where((ip) => ip.startsWith('198.18.') || ip.startsWith('198.19.'))
        .toList();
    final bogonIps = allIps
        .where((ip) =>
            ip.startsWith('127.') ||
            ip.startsWith('0.') ||
            ip.startsWith('169.254.'))
        .toList();

    if (bogonIps.isNotEmpty) {
      findings.add(HealthFinding(
        category: 'DNS',
        status: 'error',
        title: '检测到异常 / 环回 DNS 解析',
        detail:
            '部分 AI 域名解析到了异常地址（${bogonIps.toSet().join(', ')}），请检查代理软件 DNS 设置或私有 DNS。',
      ));
    } else if (fakeIps.isNotEmpty) {
      findings.add(HealthFinding(
        category: 'DNS',
        status: 'ok',
        title: 'Fake-IP DNS 接管正常',
        detail: 'AI 域名已由代理 Fake-IP 接管（示例 ${fakeIps.first}），可有效防止移动网络 DNS 污染。',
      ));
    } else if (allIps.isEmpty) {
      findings.add(const HealthFinding(
        category: 'DNS',
        status: 'warn',
        title: '系统 DNS 暂时无法解析 AI 域名',
        detail: '若已开启代理端口可正常使用，原生 App 建议在代理软件开启 Fake-IP 或加密 DNS（DoH）。',
      ));
    } else {
      final firstIps = [
        for (final list in resolved.values)
          if (list.isNotEmpty) list.first,
      ];
      if (firstIps.length >= 3 && firstIps.toSet().length == 1) {
        findings.add(HealthFinding(
          category: 'DNS',
          status: 'error',
          title: 'DNS 疑似存在污染',
          detail:
              '多个不同 AI 域名均解析到同一 IP（${firstIps.first}），请在代理 App 中开启 Fake-IP 或加密 DNS。',
        ));
      } else if (networkState.vpnActive) {
        findings.add(HealthFinding(
          category: 'DNS',
          status: 'warn',
          title: 'VPN 已开但未检测到 Fake-IP',
          detail: '当前解析为真实 IP（如 ${firstIps.first}）；若 App 加载缓慢或超时，建议开启 Fake-IP。',
        ));
      } else {
        findings.add(const HealthFinding(
          category: 'DNS',
          status: 'ok',
          title: '系统 DNS 解析可用',
          detail: '未发现环回或明显污染特征。',
        ));
      }
    }

    // 3. Global IPv6 Leak Check (privacy-masked)
    final globalV6 = await detectV6();
    if (globalV6.isNotEmpty) {
      final segs = globalV6.split(':');
      final masked = '${segs.take(3).join(':')}::…';
      findings.add(HealthFinding(
        category: 'IPv6',
        status: 'warn',
        title: '检测到公网 IPv6（注意潜在泄漏 / 超时）',
        detail:
            '当前移动网络/Wi-Fi 存在公网 IPv6（$masked）。若 AI App 在 VPN 下卡顿或地区漂移，请在代理软件开启 IPv6 接管或关闭 IPv6 路由。',
      ));
    } else {
      findings.add(const HealthFinding(
        category: 'IPv6',
        status: 'ok',
        title: '无公网 IPv6 泄漏风险',
        detail: '当前未检测到公网 IPv6 地址。',
      ));
    }

    return findings;
  }

  /// Generates a sanitized plain-text report safe for sharing (strips secrets & sensitive IPs).
  String buildDiagnosticReport({
    required NativeNetworkState networkState,
    required List<ProxyReport> reports,
    required List<MobileProxyApp> detectedProxyApps,
    required List<HealthFinding> findings,
    required String proxyMode,
    int? relayPort,
  }) {
    final buf = StringBuffer()
      ..writeln('=== AI 代理启动器 (Mobile) · 脱敏诊断报告 ===')
      ..writeln('系统: ${networkState.platform.toUpperCase()} · ${networkState.osVersion}')
      ..writeln(
        'VPN 状态: ${networkState.vpnActive ? "已激活" : "未开启"}'
        '${networkState.vpnInterfaces.isNotEmpty ? " (${networkState.vpnInterfaces.join(", ")})" : ""}',
      )
      ..writeln(
        '代理模式: $proxyMode | 检测到本机代理 App: '
        '${detectedProxyApps.isEmpty ? "无" : detectedProxyApps.map((e) => e.name).join("、")}',
      )
      ..writeln(
        '统一本地中继: ${relayPort != null ? "已开启 127.0.0.1:$relayPort" : "未开启"}',
      )
      ..writeln()
      ..writeln('[活跃代理与服务探针]');

    if (reports.isEmpty) {
      buf.writeln('- 无可用代理');
    } else {
      for (final rep in reports) {
        if (rep.issue.isNotEmpty) {
          buf.writeln('- ${rep.provider}: 错误 - ${rep.issue}');
          continue;
        }
        final portStr = rep.port > 0 ? ' :${rep.port}' : ' (系统路由)';
        final regStr = rep.region.isNotEmpty ? ' ${rep.region}' : '';
        final latStr = rep.latencyMs != null ? ' ${rep.latencyMs}ms' : '';
        buf.writeln(
          '- ${rep.provider}$portStr | scheme=${rep.scheme} | mode=${rep.mode} | '
          'tun=${rep.tun} | api=${rep.endpoint != null}$regStr$latStr',
        );
        for (final pr in rep.probes.values) {
          final node = pr.node.isNotEmpty ? ' | node=${pr.node}' : '';
          final ms = pr.latencyMs != null ? ' | ${pr.latencyMs}ms' : '';
          buf.writeln(
            '    * ${pr.host}: ok=${pr.connected} route=${pr.route}$node$ms (${pr.detail})',
          );
        }
      }
    }

    buf
      ..writeln()
      ..writeln('[网络底层体检 (VPN / DNS / IPv6)]');
    for (final f in findings) {
      buf.writeln('- [${f.status.toUpperCase()}] ${f.category} - ${f.title}: ${f.detail}');
    }
    return buf.toString().trimRight();
  }
}

