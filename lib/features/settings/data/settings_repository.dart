import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';

class SettingsRepository {
  static const _keySettings = 'kayto_app_settings';

  AppSettings? _cachedSettings;

  AppSettings? get cachedSettings => _cachedSettings;

  Future<AppSettings> load() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keySettings);
    if (jsonString == null) {
      _cachedSettings = const AppSettings();
    } else {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        _cachedSettings = AppSettings.fromJson(map);
      } catch (_) {
        _cachedSettings = const AppSettings();
      }
    }

    return _cachedSettings!;
  }

  Future<void> save(AppSettings settings) async {
    _cachedSettings = settings;
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_keySettings, jsonString);
  }
}
