import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../native/channels/native_channel.dart';
import '../../../native/models/app_info.dart';

/// Loads the installed app inventory once and caches it in memory
final installedAppsFutureProvider =
    FutureProvider<List<AppInfo>>((ref) async {
  final apps = await NativeChannel.listInstalledApps();
  return apps;
});

/// In-memory cache of decoded icon bytes per package name
final decodedIconCacheProvider =
    Provider<Map<String, Uint8List>>((ref) {
  final appsAsync = ref.watch(installedAppsFutureProvider);
  final map = <String, Uint8List>{};
  final apps = appsAsync.value ?? const <AppInfo>[];
  for (final app in apps) {
    if (app.icon != null) {
      map[app.packageName] = app.icon!;
    }
  }
  return map;
});

/// Search query provider for apps screen
class AppsSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final appsSearchQueryProvider =
    NotifierProvider<AppsSearchQueryNotifier, String>(
  AppsSearchQueryNotifier.new,
);

/// Monitored only filter provider
class AppsShowMonitoredOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setMonitoredOnly(bool val) => state = val;
}

final appsShowMonitoredOnlyProvider =
    NotifierProvider<AppsShowMonitoredOnlyNotifier, bool>(
  AppsShowMonitoredOnlyNotifier.new,
);

/// Combined filtered and enriched apps list
final enrichedAppsProvider = Provider<AsyncValue<List<AppInfo>>>((ref) {
  final appsAsync = ref.watch(installedAppsFutureProvider);
  final settingsAsync = ref.watch(appSettingsProvider);
  final searchQuery = ref.watch(appsSearchQueryProvider).trim().toLowerCase();
  final showMonitoredOnly = ref.watch(appsShowMonitoredOnlyProvider);

  return appsAsync.whenData((apps) {
    final showSystem = settingsAsync.value?.showSystemApps ?? false;
    final cachedMonitored = ref.watch(appsProvider).monitoredPackages;

    return apps.where((app) {
      // 1. System app filter
      if (!showSystem && app.isSystemApp) {
        return false;
      }

      // 2. Monitored filter
      final isMonitored = cachedMonitored.contains(app.packageName);
      if (showMonitoredOnly && !isMonitored) {
        return false;
      }

      // 3. Search query filter
      if (searchQuery.isNotEmpty) {
        final matchesLabel = app.label.toLowerCase().contains(searchQuery);
        final matchesPkg = app.packageName.toLowerCase().contains(searchQuery);
        if (!matchesLabel && !matchesPkg) {
          return false;
        }
      }

      return true;
    }).map((app) {
      final isMonitored = cachedMonitored.contains(app.packageName);
      return app.copyWith(isMonitored: isMonitored);
    }).toList();
  });
});
