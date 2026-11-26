import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'platform_bridge.dart';

class SettingsStore {
  SettingsStore(this._bridge, {Directory? overrideDir})
      : _overrideDir = overrideDir;

  final PlatformBridge _bridge;
  final Directory? _overrideDir;

  Future<File?> _settingsFile() async {
    if (_overrideDir != null) {
      await _overrideDir.create(recursive: true);
      return File('${_overrideDir.path}${Platform.pathSeparator}settings.json');
    }
    final dirPath = await _bridge.getAppDataDir();
    if (dirPath == null || dirPath.isEmpty) return null;
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}settings.json');
  }

  Future<AppSettings> load() async {
    try {
      final file = await _settingsFile();
      if (file == null || !await file.exists()) return const AppSettings();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
    } catch (_) {}
    return const AppSettings();
  }

  /// Persists non-sensitive preferences only (controller secrets stay in memory only).
  Future<void> save(AppSettings settings) async {
    try {
      final file = await _settingsFile();
      if (file == null) return;
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(settings.toJson()), flush: true);
      await tmp.rename(file.path);
    } catch (_) {}
  }
}
