// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/clash_api.dart';
import '../services/region_utils.dart';
import 'theme.dart';

Future<void> showUserGuideSheet({
  required BuildContext context,
  required AppPalette palette,
  required bool initialDontShowAgain,
  required ValueChanged<bool> onComplete,
}) async {
  bool dontShowAgain = initialDontShowAgain;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: palette.tealPale,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            color: AppPalette.teal,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI 代理启动器 · 手机版使用指南',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: palette.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '兼容 Android & iOS · 全协议代理检测与一键 AI 唤起',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _guideStep(
                      palette,
                      '1',
                      '先连接手机代理或旁路由',
                      '支持 FlClash、Clash Meta、v2rayNG、Hiddify、sing-box、Stash、Shadowrocket、Surge、Loon，也支持路由器/旁路由透明代理，无需白名单。',
                    ),
                    _guideStep(
                      palette,
                      '2',
                      '一键验证 12+ AI 服务与真实出口地区',
                      '自动检测 Google OAuth / Antigravity / Gemini / Claude / ChatGPT / Codex WS / Grok / Perplexity 连通性、延迟与出口地区，遇到香港/受限地区自动标黄提醒。',
                    ),
                    _guideStep(
                      palette,
                      '3',
                      '内置切节点、SOCKS5 自动桥接与网络体检',
                      '连上本机或局域网 Clash 控制接口可直接测速换节点；遇纯 SOCKS5 代理自动开启 127.0.0.1:17890 HTTP 桥接；「网络体检」排查 DNS 污染与 IPv6 泄漏并生成脱敏报告。',
                    ),
                    _guideStep(
                      palette,
                      '4',
                      '一键唤起手机 AI App 或网页版',
                      '点击任意卡片的「打开」即可直达对应手机 App（未安装自动打开官方网页版）；本指南收起在右上角「?」按钮，随时可重阅。',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: dontShowAgain,
                          activeColor: AppPalette.teal,
                          onChanged: (v) =>
                              setModalState(() => dontShowAgain = v ?? false),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(
                              () => dontShowAgain = !dontShowAgain,
                            ),
                            child: Text(
                              '下次启动不再自动弹出（右上角「?」随时查看）',
                              style: TextStyle(fontSize: 13, color: palette.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onComplete(dontShowAgain);
                        },
                        child: const Text(
                          '我已阅读，进入启动器',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _guideStep(AppPalette p, String numText, String title, String desc) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: p.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: p.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppPalette.teal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            numText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: TextStyle(fontSize: 12, color: p.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> showNodeSwitcherSheet({
  required BuildContext context,
  required AppPalette palette,
  required ControllerEndpoint endpoint,
  required ClashApiClient clashApi,
  required VoidCallback onSwitched,
}) async {
  List<SelectorGroup> groups = [];
  int selectedIdx = 0;
  bool loading = true;
  bool testing = false;
  String statusMsg = '正在读取分流组与节点列表…';
  Map<String, int?> liveDelays = {};

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> loadGroups() async {
            final res = await clashApi.listSelectorGroups(endpoint);
            if (!ctx.mounted) return;
            setModalState(() {
              groups = res;
              loading = false;
              if (res.isEmpty) {
                statusMsg = '未能从 ${endpoint.address} 读取到可切换的 Selector 分流组。';
              } else {
                selectedIdx = selectedIdx.clamp(0, res.length - 1);
                liveDelays = Map<String, int?>.from(res[selectedIdx].delays);
                statusMsg = '当前分组：${res[selectedIdx].name}（当前：${res[selectedIdx].current}）';
              }
            });
          }

          if (loading) {
            Future.microtask(loadGroups);
          }

          Future<void> runDelayTests() async {
            if (groups.isEmpty || testing) return;
            final grp = groups[selectedIdx];
            setModalState(() {
              testing = true;
              statusMsg = '正在并发测速 ${grp.nodes.take(20).length} 个节点…';
            });
            final nodes = grp.nodes.take(20).toList();
            final pairs = await Future.wait(
              nodes.map((n) async => (n, await clashApi.testNodeDelay(endpoint, n))),
            );
            if (!ctx.mounted) return;
            setModalState(() {
              for (final (n, ms) in pairs) {
                liveDelays[n] = ms;
              }
              testing = false;
              final okCount = pairs.where((e) => e.$2 != null).length;
              statusMsg = '测速完成：$okCount / ${nodes.length} 个节点响应正常';
            });
          }

          Future<void> autoPickBest() async {
            if (groups.isEmpty || testing) return;
            setModalState(() {
              testing = true;
              statusMsg = '正在自动测速并优选非受限 AI 地区节点…';
            });
            final picked = await clashApi.autoPickBestNonRestrictedNode(
              endpoint,
              preferredGroup: groups[selectedIdx].name,
            );
            if (!ctx.mounted) return;
            if (picked != null) {
              onSwitched();
              setModalState(() {
                testing = false;
                statusMsg = '已自动切换至「${picked.$2}」（${picked.$3}ms）';
              });
              await loadGroups();
            } else {
              setModalState(() {
                testing = false;
                statusMsg = '未能找到可用的非受限地区节点，请手动选择。';
              });
            }
          }

          final currentGroup = groups.isNotEmpty ? groups[selectedIdx] : null;

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            maxChildSize: 0.92,
            minChildSize: 0.5,
            builder: (ctx, scrollController) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: palette.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '快捷切换节点 · ${endpoint.name}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: palette.ink,
                                ),
                              ),
                              Text(
                                statusMsg,
                                style: TextStyle(fontSize: 12, color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '测速',
                          onPressed: testing ? null : runDelayTests,
                          icon: const Icon(Icons.speed_rounded, color: AppPalette.teal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: testing ? null : runDelayTests,
                            icon: const Icon(Icons.bolt_rounded, size: 16),
                            label: const Text('并发测速'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.teal,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: testing ? null : autoPickBest,
                            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                            label: const Text('自动避开受限'),
                          ),
                        ),
                      ],
                    ),
                    if (groups.length > 1) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: groups.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final active = i == selectedIdx;
                            return ChoiceChip(
                              label: Text(groups[i].name),
                              selected: active,
                              selectedColor: palette.tealPale,
                              onSelected: (_) {
                                setModalState(() {
                                  selectedIdx = i;
                                  liveDelays = Map<String, int?>.from(groups[i].delays);
                                  statusMsg =
                                      '当前分组：${groups[i].name}（当前：${groups[i].current}）';
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : currentGroup == null
                              ? Center(
                                  child: Text(
                                    statusMsg,
                                    style: TextStyle(color: palette.muted),
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: currentGroup.nodes.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (_, i) {
                                    final node = currentGroup.nodes[i];
                                    final isCurrent = node == currentGroup.current;
                                    final restricted = nodeLooksRestricted(node);
                                    final delay = liveDelays[node];
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        final ok = await clashApi.switchNode(
                                          endpoint,
                                          currentGroup.name,
                                          node,
                                        );
                                        if (!ctx.mounted) return;
                                        if (ok) {
                                          onSwitched();
                                          setModalState(() {
                                            statusMsg = '已切换到：$node';
                                          });
                                          await loadGroups();
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCurrent
                                              ? palette.tealPale
                                              : palette.surfaceAlt,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isCurrent
                                                ? AppPalette.teal
                                                : palette.border,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isCurrent
                                                  ? Icons.check_circle_rounded
                                                  : Icons.radio_button_unchecked,
                                              size: 18,
                                              color: isCurrent
                                                  ? AppPalette.teal
                                                  : palette.muted,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                node,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isCurrent
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: palette.ink,
                                                ),
                                              ),
                                            ),
                                            if (restricted)
                                              Container(
                                                margin: const EdgeInsets.only(right: 6),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: palette.amberPale,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '受限',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: palette.amberInk,
                                                  ),
                                                ),
                                              ),
                                            Text(
                                              delay != null ? '${delay}ms' : '—',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: delay == null
                                                    ? palette.muted
                                                    : (delay < 250
                                                        ? AppPalette.emerald
                                                        : (delay < 600
                                                            ? AppPalette.amber
                                                            : AppPalette.rose)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

Future<void> showNetworkAuditSheet({
  required BuildContext context,
  required AppPalette palette,
  required List<HealthFinding> findings,
  required String diagnosticReport,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '深度网络体检（VPN / DNS / IPv6）',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '排查「节点亮绿但 AI App 打不开」的常见底层原因',
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
                const SizedBox(height: 14),
                for (final f in findings)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: f.status == 'error'
                            ? AppPalette.rose
                            : (f.status == 'warn'
                                ? AppPalette.amber
                                : palette.border),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: f.status == 'ok'
                                ? palette.tealPale
                                : (f.status == 'warn'
                                    ? palette.amberPale
                                    : palette.rosePale),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            f.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: f.status == 'ok'
                                  ? palette.tealInk
                                  : (f.status == 'warn'
                                      ? palette.amberInk
                                      : palette.roseInk),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: palette.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                f.detail,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: diagnosticReport));
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制脱敏诊断报告（不含密钥与敏感 IP）'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('一键复制脱敏诊断报告'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showControllerConfigSheet({
  required BuildContext context,
  required AppPalette palette,
  required AppSettings currentSettings,
  required String currentSecret,
  required void Function(AppSettings updated, String newSecret) onSave,
}) async {
  String mode = currentSettings.proxyMode;
  final manualHostCtrl = TextEditingController(text: currentSettings.manualHost);
  final manualPortCtrl = TextEditingController(text: currentSettings.manualPort);
  final apiHostCtrl = TextEditingController(text: currentSettings.controllerHost);
  final apiPortCtrl = TextEditingController(text: currentSettings.controllerPort);
  final secretCtrl = TextEditingController(text: currentSecret);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '代理模式与控制接口设置',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '支持本机 127.0.0.1 或局域网电脑 / 旁路由 IP；控制密钥仅存内存不落盘。',
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: autoMode, label: Text('自动检测')),
                      ButtonSegment(value: manualMode, label: Text('手动指定端口')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) =>
                        setModalState(() => mode = v.first),
                  ),
                  if (mode == manualMode) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: manualHostCtrl,
                            decoration: const InputDecoration(
                              labelText: '代理地址（本机或局域网 IP）',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: manualPortCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '端口',
                              hintText: '7890',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Clash / Mihomo / Stash / Sing-box 控制接口（可选）',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: apiHostCtrl,
                          decoration: const InputDecoration(
                            labelText: '控制接口地址',
                            hintText: '127.0.0.1',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: apiPortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '端口',
                            hintText: '9090',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: secretCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '控制密钥 Secret（仅驻留当前会话内存）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        final updated = currentSettings.copyWith(
                          proxyMode: mode,
                          manualHost: manualHostCtrl.text.trim().isEmpty
                              ? '127.0.0.1'
                              : manualHostCtrl.text.trim(),
                          manualPort: manualPortCtrl.text.trim(),
                          controllerHost: apiHostCtrl.text.trim().isEmpty
                              ? '127.0.0.1'
                              : apiHostCtrl.text.trim(),
                          controllerPort: apiPortCtrl.text.trim(),
                        );
                        Navigator.of(ctx).pop();
                        onSave(updated, secretCtrl.text.trim());
                      },
                      child: const Text('保存并立即复测'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> showManageTargetsSheet({
  required BuildContext context,
  required AppPalette palette,
  required AppSettings currentSettings,
  required ValueChanged<AppSettings> onUpdate,
}) async {
  final enabled = Set<String>.from(currentSettings.enabledPresets);
  final customList = List<AiTarget>.from(currentSettings.customTargets);
  final nameCtrl = TextEditingController();
  final urlCtrl = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '管理扩展 AI 服务与自定义网址',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final preset in presetMobileTargets)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(preset.name, style: TextStyle(color: palette.ink)),
                      subtitle: Text(
                        preset.description,
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                      value: enabled.contains(preset.id),
                      onChanged: (v) {
                        setModalState(() {
                          if (v) {
                            enabled.add(preset.id);
                          } else {
                            enabled.remove(preset.id);
                          }
                        });
                        onUpdate(currentSettings.copyWith(
                          enabledPresets: enabled.toList(),
                          customTargets: customList,
                        ));
                      },
                    ),
                  const Divider(),
                  Text(
                    '添加自定义 AI 网页 / 接口',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '名称（如 DeepSeek / Poe）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: '网址（如 https://poe.com/）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final rawName = nameCtrl.text.trim();
                        final rawUrl = urlCtrl.text.trim();
                        final uri = Uri.tryParse(
                          rawUrl.contains('://') ? rawUrl : 'https://$rawUrl',
                        );
                        if (rawName.isEmpty || uri == null || uri.host.isEmpty) {
                          return;
                        }
                        final item = AiTarget(
                          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          name: rawName,
                          category: 'web',
                          hosts: [uri.host],
                          description: uri.toString(),
                          webUrl: uri.toString(),
                          custom: true,
                        );
                        setModalState(() {
                          customList.add(item);
                          nameCtrl.clear();
                          urlCtrl.clear();
                        });
                        onUpdate(currentSettings.copyWith(
                          enabledPresets: enabled.toList(),
                          customTargets: customList,
                        ));
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('添加到检测列表'),
                    ),
                  ),
                  if (customList.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final item in List<AiTarget>.from(customList))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name, style: TextStyle(color: palette.ink)),
                        subtitle: Text(
                          item.webUrl,
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppPalette.rose),
                          onPressed: () {
                            setModalState(() => customList.remove(item));
                            onUpdate(currentSettings.copyWith(
                              enabledPresets: enabled.toList(),
                              customTargets: customList,
                            ));
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
