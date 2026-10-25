import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../native/models/app_info.dart';
import '../../../native/models/app_rule.dart';
import '../../../native/models/enforcement_stats.dart';
import '../../../native/models/network_source.dart';
import '../../../native/models/sim_info.dart';
import '../../../native/models/usage_record.dart';
import '../../apps/presentation/apps_screen.dart';
import '../../rules/presentation/rule_editor_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../usage/domain/per_app_usage_provider.dart';
import '../../usage/domain/realtime_speed_provider.dart';
import '../../usage/presentation/usage_detail_screen.dart';
import '../../../core/utils/bytes.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Realtime speed & usage snapshot providers
    final speedAsync = ref.watch(realtimeSpeedProvider);
    final perAppUsageAsync = ref.watch(perAppUsageSnapshotProvider);

    // Selective watching to prevent unnecessary re-renders
    final isRunning = ref.watch(vpnStateProvider.select((s) => s.isRunning));
    final stats = ref.watch(vpnStateProvider.select((s) => s.stats));
    final activeNetwork =
        ref.watch(vpnStateProvider.select((s) => s.activeNetwork));
    final isPreparing =
        ref.watch(vpnStateProvider.select((s) => s.isPreparing));

    final monitoredPackages =
        ref.watch(appsProvider.select((s) => s.monitoredPackages));
    final rulesMap = ref.watch(appsProvider.select((s) => s.rulesMap));
    final allApps = ref.watch(appsProvider.select((s) => s.allApps));

    final topConsumers =
        ref.watch(usageProvider.select((s) => s.topConsumers));
    final usageMap = ref.watch(usageProvider.select((s) => s.usageMap));

    final permissionsAsync = ref.watch(permissionHealthProvider);
    final simsAsync = ref.watch(simCardsProvider);

    final monitoredCount = monitoredPackages.length;
    final blockedPackets = stats.blockedPackets;

    // Calculate how many apps are close to or have reached their limit
    int limitsReachedCount = 0;
    for (final pkg in monitoredPackages) {
      final usage = usageMap[pkg];
      final rules = rulesMap[pkg] ?? [];
      if (usage == null) continue;

      for (final r in rules) {
        if (r.limitMb == null) continue;
        final limitBytes = r.limitMb! * 1024 * 1024;
        final used = (r.source == NetworkSource.wifi)
            ? usage.wifiBytes
            : (r.source == NetworkSource.sim1)
                ? usage.sim1Bytes
                : usage.sim2Bytes;
        if (used >= limitBytes) {
          limitsReachedCount++;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Usage Details',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UsageDetailScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: 'Applications',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AppsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(vpnStateProvider.notifier).refresh();
          await ref.read(appsProvider.notifier).loadApps();
          await ref.read(usageProvider.notifier).refreshUsage();
          await ref.read(permissionHealthProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Master Enforcement Engine Card
            _buildVpnToggleCard(
              context,
              ref,
              isRunning: isRunning,
              stats: stats,
              activeNetwork: activeNetwork,
              isPreparing: isPreparing,
            ),
            const SizedBox(height: 16),

            // 2. Summary Status Pill Row
            _buildSummaryRow(
              context,
              monitoredCount: monitoredCount,
              limitsReached: limitsReachedCount,
              blockedSources: blockedPackets > 0 ? 1 : 0,
            ),
            const SizedBox(height: 16),

            // 3. Real-Time Network Speed & Top Monitored Apps Card
            _buildRealtimeUsageCard(
              context,
              speedAsync: speedAsync,
              perAppUsageAsync: perAppUsageAsync,
              allApps: allApps,
              rulesMap: rulesMap,
              activeNetwork: activeNetwork,
            ),
            const SizedBox(height: 16),

            // 4. Permission Health Card
            permissionsAsync.when(
              data: (health) => _buildPermissionHealthCard(context, ref, health),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // 4. SIM Awareness Banner
            simsAsync.when(
              data: (sims) =>
                  _buildSimStatusCard(context, sims, activeNetwork),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // 5. Today's Top Data Consumers
            _buildTopConsumersSection(
              context,
              ref,
              topConsumers: topConsumers,
              allApps: allApps,
              monitoredPackages: monitoredPackages,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVpnToggleCard(
    BuildContext context,
    WidgetRef ref, {
    required bool isRunning,
    required EnforcementStats stats,
    required String activeNetwork,
    required bool isPreparing,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isRunning
              ? Colors.green.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isRunning
                      ? Colors.green.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    isRunning ? Icons.shield : Icons.shield_outlined,
                    color: isRunning ? Colors.green : theme.colorScheme.outline,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enforcement Engine',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRunning
                            ? 'Active — Blocking exhausted sources'
                            : 'Inactive — Tap toggle to start',
                        style: TextStyle(
                          fontSize: 12,
                          color: isRunning ? Colors.green : theme.colorScheme.outline,
                          fontWeight: isRunning ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                isPreparing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: isRunning,
                        onChanged: (_) {
                          ref.read(vpnStateProvider.notifier).toggleVpn();
                        },
                      ),
              ],
            ),
            if (isRunning) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildVpnStat(
                    context,
                    label: 'Packets Blocked',
                    value: '${stats.blockedPackets}',
                  ),
                  _buildVpnStat(
                    context,
                    label: 'Data Blocked',
                    value: '${stats.blockedMb.toStringAsFixed(2)} MB',
                  ),
                  _buildVpnStat(
                    context,
                    label: 'Active Link',
                    value: activeNetwork,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVpnStat(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required int monitoredCount,
    required int limitsReached,
    required int blockedSources,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            icon: Icons.checklist,
            count: '$monitoredCount',
            label: 'Apps Monitored',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            icon: Icons.warning_amber_rounded,
            count: '$limitsReached',
            label: 'Limits Reached',
            color: limitsReached > 0 ? Colors.amber.shade800 : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            icon: Icons.block,
            count: '$blockedSources',
            label: 'Blocked Links',
            color: blockedSources > 0 ? Colors.red : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required String count,
    required String label,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              count,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionHealthCard(
    BuildContext context,
    WidgetRef ref,
    dynamic health,
  ) {
    final isFullyConfigured = health.isFullyConfigured as bool;
    if (isFullyConfigured) return const SizedBox.shrink();

    return Card(
      color: Colors.orange.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_moon_outlined, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Permission Setup Required',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Kayto requires Usage Access and Battery Exemption to accurately track app limits and ensure background enforcement.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!health.usageAccess)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Grant Usage Access'),
                    onPressed: () {
                      ref
                          .read(permissionHealthProvider.notifier)
                          .requestUsageAccess();
                    },
                  ),
                if (!health.batteryOptimization)
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.battery_saver, size: 16),
                    label: const Text('Exempt Battery Saver'),
                    onPressed: () {
                      ref
                          .read(permissionHealthProvider.notifier)
                          .requestBatteryExemption();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimStatusCard(
    BuildContext context,
    List<SimInfo> sims,
    String activeNetwork,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cell_tower, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Dual-SIM & Connection Status',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active: $activeNetwork',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sims.isEmpty)
              const Text(
                'No physical SIM cards detected. Wi-Fi control remains fully active.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              Row(
                children: sims.map((sim) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'SIM ${sim.slotIndex + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              if (sim.isDefaultData) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.green,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            sim.carrierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopConsumersSection(
    BuildContext context,
    WidgetRef ref, {
    required List<UsageRecord> topConsumers,
    required List<AppInfo> allApps,
    required Set<String> monitoredPackages,
  }) {
    final topApps = topConsumers.take(6).toList();
    final appsMap = {for (final a in allApps) a.packageName: a};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Top Data Consumers",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AppsScreen(),
                  ),
                );
              },
              child: const Text('Manage Apps'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (topApps.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No internet usage recorded yet today',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          )
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topApps.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final usage = topApps[i];
                final app = appsMap[usage.packageName] ??
                    AppInfo(
                      packageName: usage.packageName,
                      label: usage.packageName,
                    );

                final isMonitored =
                    monitoredPackages.contains(app.packageName);

                return ListTile(
                  leading: app.icon != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            app.icon!,
                            width: 40,
                            height: 40,
                            cacheWidth: 80,
                          ),
                        )
                      : const Icon(Icons.android, size: 40),
                  title: Text(
                    app.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Wi-Fi: ${usage.wifiMb.toStringAsFixed(1)} MB · SIM 1: ${usage.sim1Mb.toStringAsFixed(1)} MB · SIM 2: ${usage.sim2Mb.toStringAsFixed(1)} MB',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${usage.totalMb.toStringAsFixed(1)} MB',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            isMonitored ? 'Monitored' : 'Unmonitored',
                            style: TextStyle(
                              fontSize: 10,
                              color: isMonitored
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RuleEditorScreen(app: app),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRealtimeUsageCard(
    BuildContext context, {
    required AsyncValue<NetworkSpeed> speedAsync,
    required AsyncValue<List<UsageRecord>> perAppUsageAsync,
    required List<AppInfo> allApps,
    required Map<String, List<AppRule>> rulesMap,
    required String activeNetwork,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final speed = speedAsync.value ?? const NetworkSpeed();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with LIVE badge
            Row(
              children: [
                Icon(Icons.speed, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Real-Time Internet Speed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Live Speeds
            if (speed.unsupported)
              Text(
                'Real-time speed unavailable on this device kernel',
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            color: Colors.blue.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatSpeed(speed.rxBps),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Download',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            color: Colors.purple.shade300,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatSpeed(speed.txBps),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Upload',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Top monitored apps usage & cutoff badges
            Text(
              'Active Monitored Apps (Today)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.outline,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),

            perAppUsageAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No monitored apps with activity yet today.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                  );
                }

                // Sort by totalBytes descending and take top 3
                final sorted = List<UsageRecord>.from(records)
                  ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
                final top3 = sorted.take(3).toList();

                return Column(
                  children: top3.map((record) {
                    final appInfo = allApps.firstWhere(
                      (a) => a.packageName == record.packageName,
                      orElse: () => AppInfo(
                        packageName: record.packageName,
                        label: record.packageName.split('.').last,
                      ),
                    );

                    final rules = rulesMap[record.packageName] ?? [];
                    final List<String> cutoffs = [];
                    int? activeLimitBytes;
                    int activeUsedBytes = 0;

                    for (final r in rules) {
                      if (r.limitMb == null) continue;
                      final lim = r.limitMb! * 1024 * 1024;
                      final used = (r.source == NetworkSource.wifi)
                          ? record.wifiBytes
                          : (r.source == NetworkSource.sim1)
                              ? record.sim1Bytes
                              : record.sim2Bytes;
                      if (used >= lim) {
                        cutoffs.add('CUT OFF (${r.source.displayName})');
                      }
                      if ((activeNetwork.contains('WIFI') &&
                              r.source == NetworkSource.wifi) ||
                          (activeNetwork.contains('SIM_1') &&
                              r.source == NetworkSource.sim1) ||
                          (activeNetwork.contains('SIM_2') &&
                              r.source == NetworkSource.sim2)) {
                        activeLimitBytes = lim;
                        activeUsedBytes = used;
                      }
                    }

                    final progress =
                        (activeLimitBytes != null && activeLimitBytes > 0)
                            ? (activeUsedBytes / activeLimitBytes).clamp(0.0, 1.0)
                            : null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: appInfo.icon != null
                                    ? Image.memory(
                                        appInfo.icon!,
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.android, size: 28),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appInfo.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${formatBytes(record.totalBytes)} used today',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (cutoffs.isNotEmpty)
                                Wrap(
                                  spacing: 4,
                                  children: cutoffs.map((badge) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.red.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Text(
                                        badge,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                )
                              else if (activeLimitBytes != null)
                                Text(
                                  '${formatBytes(activeUsedBytes)} / ${formatBytes(activeLimitBytes)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (progress != null) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                color: progress >= 1.0
                                    ? Colors.red
                                    : progress >= 0.8
                                        ? Colors.amber
                                        : colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, __) => Text(
                'Could not read app usage snapshot',
                style: TextStyle(fontSize: 11, color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
