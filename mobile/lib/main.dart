import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'models/models.dart';
import 'services/local_relay.dart';
import 'services/network_audit.dart';
import 'services/platform_bridge.dart';
import 'services/proxy_engine.dart';
import 'services/settings_store.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AiProxyLauncherApp());
}

class AiProxyLauncherApp extends StatefulWidget {
  const AiProxyLauncherApp({
    super.key,
    this.bridgeOverride,
    this.engineOverride,
    this.settingsStoreOverride,
    this.initialSettings,
    this.autoRunOnInit = true,
  });

  final PlatformBridge? bridgeOverride;
  final MobileProxyEngine? engineOverride;
  final SettingsStore? settingsStoreOverride;
  final AppSettings? initialSettings;
  final bool autoRunOnInit;

  @override
  State<AiProxyLauncherApp> createState() => _AiProxyLauncherAppState();
}

class _AiProxyLauncherAppState extends State<AiProxyLauncherApp> {
  late final PlatformBridge _bridge;
  late final MobileProxyEngine _engine;
  late final SettingsStore _store;
  final NetworkAuditService _audit = const NetworkAuditService();
  final LocalProxyRelay _relay = LocalProxyRelay();
  late AppSettings _settings;
  late bool _loaded;

  @override
  void initState() {
    super.initState();
    _bridge = widget.bridgeOverride ?? MethodChannelPlatformBridge();
    _engine = widget.engineOverride ?? MobileProxyEngine(bridge: _bridge);
    _store = widget.settingsStoreOverride ?? SettingsStore(_bridge);
    if (widget.initialSettings != null) {
      _settings = widget.initialSettings!;
      _loaded = true;
    } else {
      _settings = const AppSettings();
      _loaded = false;
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final loaded = await _store.load();
    if (!mounted) return;
    setState(() {
      _settings = loaded;
      _loaded = true;
    });
  }

  void _updateSettings(AppSettings next) {
    setState(() => _settings = next);
    unawaited(_store.save(next));
  }

  @override
  void dispose() {
    unawaited(_relay.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        _settings.darkMode ? AppPalette.darkPalette : AppPalette.lightPalette;
    return MaterialApp(
      title: 'AI 代理启动器',
      debugShowCheckedModeBanner: false,
      theme: palette.toThemeData(),
      home: _loaded
          ? HomeScreen(
              bridge: _bridge,
              engine: _engine,
              auditService: _audit,
              settingsStore: _store,
              relay: _relay,
              settings: _settings,
              onSettingsChanged: _updateSettings,
              autoRunOnInit: widget.autoRunOnInit,
            )
          : Scaffold(
              backgroundColor: palette.heroBg,
              body: const Center(
                child: CircularProgressIndicator(color: AppPalette.teal),
              ),
            ),
    );
  }
}

