import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/usage_repository.dart';
import '../../../core/providers/app_providers.dart';
import '../../../native/models/app_info.dart';
import '../../../native/models/sim_info.dart';
import '../../../native/models/usage_record.dart';

class UsageDetailScreen extends ConsumerStatefulWidget {
  final AppInfo? app;

  const UsageDetailScreen({super.key, this.app});

  @override
  ConsumerState<UsageDetailScreen> createState() => _UsageDetailScreenState();
}

class _UsageDetailScreenState extends ConsumerState<UsageDetailScreen> {
  late Future<List<EventLogEntry>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    final repo = ref.read(usageRepositoryProvider);
    _logsFuture = widget.app != null
        ? repo.getEventLogsForPackage(widget.app!.packageName)
        : repo.getRecentEventLogs();
  }

  @override
  Widget build(BuildContext context) {
    final usageState = ref.watch(usageProvider);
    final simsAsync = ref.watch(simCardsProvider);
    final sims = simsAsync.value ?? const <SimInfo>[];
    final sim1 = sims.where((s) => s.slotIndex == 0).firstOrNull;
    final sim2 = sims.where((s) => s.slotIndex == 1).firstOrNull;

    final UsageRecord usage;
    if (widget.app != null) {
      usage = usageState.usageMap[widget.app!.packageName] ??
          UsageRecord(packageName: widget.app!.packageName);
    } else {
      // Aggregate across all apps
      int totalWifi = 0;
      int totalSim1 = 0;
      int totalSim2 = 0;
      bool isAttributed = false;
      for (final r in usageState.usageMap.values) {
        totalWifi += r.wifiBytes.toInt();
        totalSim1 += r.sim1Bytes.toInt();
        totalSim2 += r.sim2Bytes.toInt();
        if (r.isAttributed) isAttributed = true;
      }
      usage = UsageRecord(
        packageName: 'Device Total',
        wifiBytes: totalWifi,
        sim1Bytes: totalSim1,
        sim2Bytes: totalSim2,
        isAttributed: isAttributed,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app?.label ?? 'Data Usage Breakdown'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(usageProvider.notifier).refreshUsage();
              setState(() => _loadLogs());
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header info
          if (widget.app != null) ...[
            Row(
              children: [
                widget.app!.icon != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(widget.app!.icon!, width: 48, height: 48),
                      )
                    : const Icon(Icons.android, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.app!.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.app!.packageName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Total today card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's Total Consumption",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${usage.totalMb.toStringAsFixed(1)} MB',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (usage.isAttributed) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Mobile data is attributed to the active SIM (Android 10+ hybrid measurement)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Per-source breakdown cards
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Wi-Fi',
                  subtitle: 'Wireless',
                  bytesMb: usage.wifiMb,
                  color: Colors.blue,
                  icon: Icons.wifi,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'SIM 1',
                  subtitle: sim1?.carrierName ?? 'Cellular',
                  bytesMb: usage.sim1Mb,
                  color: Colors.teal,
                  icon: Icons.sim_card_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'SIM 2',
                  subtitle: sim2?.carrierName ?? 'Cellular',
                  bytesMb: usage.sim2Mb,
                  color: Colors.deepOrange,
                  icon: Icons.sim_card,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Events and Enforcement Log
          const Text(
            'Threshold & Enforcement Log',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          FutureBuilder<List<EventLogEntry>>(
            future: _logsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No threshold alerts or enforcement events logged today',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final log = logs[i];
                  final isBlock = log.eventType.contains('BLOCK');
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isBlock
                          ? Colors.red.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15),
                      child: Icon(
                        isBlock ? Icons.block : Icons.warning_amber,
                        color: isBlock ? Colors.red : Colors.amber.shade800,
                      ),
                    ),
                    title: Text(log.message),
                    subtitle: Text(
                      '${log.source.displayName} • ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String subtitle,
    required double bytesMb,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${bytesMb.toStringAsFixed(1)} MB',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
