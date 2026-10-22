import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final List<int> enabledThresholds;
  final Duration appListCacheTtl;
  final bool showSystemApps;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.enabledThresholds = const [50, 70, 90, 100],
    this.appListCacheTtl = const Duration(seconds: 30),
    this.showSystemApps = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    List<int>? enabledThresholds,
    Duration? appListCacheTtl,
    bool? showSystemApps,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      enabledThresholds: enabledThresholds ?? this.enabledThresholds,
      appListCacheTtl: appListCacheTtl ?? this.appListCacheTtl,
      showSystemApps: showSystemApps ?? this.showSystemApps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.name,
      'notificationsEnabled': notificationsEnabled,
      'enabledThresholds': enabledThresholds,
      'appListCacheTtlSeconds': appListCacheTtl.inSeconds,
      'showSystemApps': showSystemApps,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final themeStr = json['themeMode'] as String?;
    final theme = ThemeMode.values.firstWhere(
      (e) => e.name == themeStr,
      orElse: () => ThemeMode.system,
    );

    final rawThresholds = json['enabledThresholds'] as List?;
    final thresholds = rawThresholds != null
        ? rawThresholds.map((e) => (e as num).toInt()).toList()
        : const [50, 70, 90, 100];

    final ttlSeconds = (json['appListCacheTtlSeconds'] as num?)?.toInt() ?? 30;

    return AppSettings(
      themeMode: theme,
      notificationsEnabled: (json['notificationsEnabled'] as bool?) ?? true,
      enabledThresholds: thresholds,
      appListCacheTtl: Duration(seconds: ttlSeconds),
      showSystemApps: (json['showSystemApps'] as bool?) ?? false,
    );
  }
}
