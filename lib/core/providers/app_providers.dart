import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../native/channels/native_channel.dart';
import '../../native/models/app_info.dart';
import '../../native/models/app_rule.dart';
import '../../native/models/enforcement_stats.dart';
import '../../native/models/permission_status.dart';
import '../../native/models/sim_info.dart';
import '../../native/models/usage_record.dart';
import '../database/rules_repository.dart';
import '../database/usage_repository.dart';

// Repositories
final rulesRepositoryProvider = Provider<RulesRepository>((ref) {
  return RulesRepository();
});

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  return UsageRepository();
});

// SIM Information
final simCardsProvider = FutureProvider<List<SimInfo>>((ref) async {
  return await NativeChannel.getSimCards();
});

// Permissions Health
class PermissionHealthNotifier extends AsyncNotifier<PermissionHealth> {
  @override
  Future<PermissionHealth> build() async {
    return await NativeChannel.checkPermissions();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => NativeChannel.checkPermissions());
  }

  Future<void> requestUsageAccess() async {
    await NativeChannel.requestUsageAccess();
    await refresh();
  }

  Future<void> requestBatteryExemption() async {
    await NativeChannel.requestBatteryOptimizationExemption();
    await refresh();
  }
}

final permissionHealthProvider =
    AsyncNotifierProvider<PermissionHealthNotifier, PermissionHealth>(() {
  return PermissionHealthNotifier();
});

// VPN Enforcement State
class VpnState {
  final bool isRunning;
  final EnforcementStats stats;
  final String activeNetwork;
  final bool isPreparing;

  const VpnState({
    this.isRunning = false,
    this.stats = const EnforcementStats(),
    this.activeNetwork = 'NONE',
    this.isPreparing = false,
  });

  VpnState copyWith({
    bool? isRunning,
    EnforcementStats? stats,
    String? activeNetwork,
    bool? isPreparing,
  }) {
    return VpnState(
      isRunning: isRunning ?? this.isRunning,
      stats: stats ?? this.stats,
      activeNetwork: activeNetwork ?? this.activeNetwork,
      isPreparing: isPreparing ?? this.isPreparing,
    );
  }
}

class VpnNotifier extends Notifier<VpnState> {
  Timer? _pollingTimer;

  @override
  VpnState build() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      refresh();
    });
    ref.onDispose(() {
      _pollingTimer?.cancel();
    });

    Future.microtask(() => refresh());
    return const VpnState();
  }

  Future<void> refresh() async {
    try {
      final isRunning = await NativeChannel.isVpnRunning();
      final stats = await NativeChannel.getEnforcementStats();
      final net = await NativeChannel.getActiveNetwork();

      if (state.isRunning != isRunning ||
          state.stats.blockedPackets != stats.blockedPackets ||
          state.stats.blockedBytes != stats.blockedBytes ||
          state.activeNetwork != net) {
        state = state.copyWith(
          isRunning: isRunning,
          stats: stats,
          activeNetwork: net,
        );
      }
    } catch (_) {}
  }

  Future<bool> toggleVpn() async {
    if (state.isRunning) {
      final success = await NativeChannel.stopVpn();
      await refresh();
      return success;
    } else {
      state = state.copyWith(isPreparing: true);
      final success = await NativeChannel.startVpn();
      state = state.copyWith(isPreparing: false);
      await refresh();
      return success;
    }
  }
}

final vpnStateProvider =
    NotifierProvider<VpnNotifier, VpnState>(VpnNotifier.new);

// Installed Apps & Search / Filter
class AppsState {
  final List<AppInfo> allApps;
  final Set<String> monitoredPackages;
  final Map<String, List<AppRule>> rulesMap;
  final String searchQuery;
  final bool showMonitoredOnly;
  final bool isLoading;

  const AppsState({
    this.allApps = const [],
    this.monitoredPackages = const {},
    this.rulesMap = const {},
    this.searchQuery = '',
    this.showMonitoredOnly = false,
    this.isLoading = true,
  });

  List<AppInfo> get filteredApps {
    return allApps.where((app) {
      final matchesSearch = app.label
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (showMonitoredOnly) {
        return monitoredPackages.contains(app.packageName);
      }
      return true;
    }).toList();
  }

  AppsState copyWith({
    List<AppInfo>? allApps,
    Set<String>? monitoredPackages,
    Map<String, List<AppRule>>? rulesMap,
    String? searchQuery,
    bool? showMonitoredOnly,
    bool? isLoading,
  }) {
    return AppsState(
      allApps: allApps ?? this.allApps,
      monitoredPackages: monitoredPackages ?? this.monitoredPackages,
      rulesMap: rulesMap ?? this.rulesMap,
      searchQuery: searchQuery ?? this.searchQuery,
      showMonitoredOnly: showMonitoredOnly ?? this.showMonitoredOnly,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AppsNotifier extends Notifier<AppsState> {
  RulesRepository get _rulesRepository => ref.read(rulesRepositoryProvider);

  @override
  AppsState build() {
    Future.microtask(() => loadApps());
    return const AppsState();
  }

  Future<void> loadApps() async {
    state = state.copyWith(isLoading: true);
    try {
      final apps = await NativeChannel.listInstalledApps();
      final monitored = await _rulesRepository.getMonitoredPackageNames();
      final allRules = await _rulesRepository.getAllRules();

      final rulesMap = <String, List<AppRule>>{};
      for (final rule in allRules) {
        rulesMap.putIfAbsent(rule.packageName, () => []).add(rule);
      }

      final enrichedApps = apps.map((a) {
        return a.copyWith(isMonitored: monitored.contains(a.packageName));
      }).toList();

      state = state.copyWith(
        allApps: enrichedApps,
        monitoredPackages: monitored,
        rulesMap: rulesMap,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleFilterMonitored(bool monitoredOnly) {
    state = state.copyWith(showMonitoredOnly: monitoredOnly);
  }

  Future<void> updateAppMonitoring(
    String packageName,
    String label,
    bool isMonitored,
  ) async {
    await _rulesRepository.setAppMonitoring(packageName, label, isMonitored);
    final monitored = await _rulesRepository.getMonitoredPackageNames();
    final updatedApps = state.allApps.map((a) {
      if (a.packageName == packageName) {
        return a.copyWith(isMonitored: isMonitored);
      }
      return a;
    }).toList();

    state = state.copyWith(
      allApps: updatedApps,
      monitoredPackages: monitored,
    );
  }

  Future<void> saveRules(
    String packageName,
    String label,
    List<AppRule> rules,
  ) async {
    await _rulesRepository.saveRulesForPackage(packageName, label, rules);
    await loadApps();
  }
}

final appsProvider =
    NotifierProvider<AppsNotifier, AppsState>(AppsNotifier.new);

// Network Usage State & Top Consumers
class UsageState {
  final Map<String, UsageRecord> usageMap;
  final bool isLoading;

  const UsageState({
    this.usageMap = const {},
    this.isLoading = true,
  });

  List<UsageRecord> get topConsumers {
    final list = usageMap.values.toList();
    list.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    return list;
  }
}

class UsageNotifier extends Notifier<UsageState> {
  UsageRepository get _usageRepository => ref.read(usageRepositoryProvider);
  Timer? _refreshTimer;

  @override
  UsageState build() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshUsage();
    });
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });

    Future.microtask(() => refreshUsage());
    return const UsageState();
  }

  Future<void> refreshUsage() async {
    try {
      final records = await NativeChannel.getAllAppsUsage();
      final map = <String, UsageRecord>{};
      for (final r in records) {
        map[r.packageName] = r;
      }
      state = UsageState(usageMap: map, isLoading: false);
      await _usageRepository.saveUsageSnapshots(records);
    } catch (_) {
      state = UsageState(usageMap: state.usageMap, isLoading: false);
    }
  }
}

final usageProvider =
    NotifierProvider<UsageNotifier, UsageState>(UsageNotifier.new);
