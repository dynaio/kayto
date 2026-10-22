import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/settings/domain/app_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Future<AppSettings> build() async {
    return await _repo.load();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(themeMode: mode);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(notificationsEnabled: enabled);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setThresholds(List<int> thresholds) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(enabledThresholds: thresholds);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setCacheTtl(Duration ttl) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(appListCacheTtl: ttl);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  Future<void> setShowSystemApps(bool show) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(showSystemApps: show);
    state = AsyncData(updated);
    await _repo.save(updated);
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

final themeModeProvider = Provider<ThemeMode>((ref) {
  final settingsAsync = ref.watch(appSettingsProvider);
  return settingsAsync.value?.themeMode ?? ThemeMode.system;
});
