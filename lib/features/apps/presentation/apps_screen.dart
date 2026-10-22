import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../native/models/app_info.dart';
import '../../../native/models/network_source.dart';
import '../../rules/presentation/rule_editor_screen.dart';
import '../domain/apps_provider.dart';

class AppsScreen extends ConsumerStatefulWidget {
  const AppsScreen({super.key});

  @override
  ConsumerState<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends ConsumerState<AppsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(appsSearchQueryProvider.notifier).setQuery(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final enrichedAppsAsync = ref.watch(enrichedAppsProvider);
    final isMonitoredOnly = ref.watch(appsShowMonitoredOnlyProvider);
    final iconCache = ref.watch(decodedIconCacheProvider);
    final rulesMap = ref.watch(appsProvider).rulesMap;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh apps inventory',
            onPressed: () {
              ref.invalidate(installedAppsFutureProvider);
              ref.read(appsProvider.notifier).loadApps();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Debounced Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search applications...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(appsSearchQueryProvider.notifier)
                              .setQuery('');
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) {
                setState(() {});
                _onSearchChanged(val);
              },
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Apps'),
                  selected: !isMonitoredOnly,
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(appsShowMonitoredOnlyProvider.notifier)
                          .setMonitoredOnly(false);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Monitored Only'),
                  selected: isMonitoredOnly,
                  onSelected: (selected) {
                    ref
                        .read(appsShowMonitoredOnlyProvider.notifier)
                        .setMonitoredOnly(selected);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Optimized ListView
          Expanded(
            child: enrichedAppsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading apps: $err')),
              data: (apps) {
                if (apps.isEmpty) {
                  return Center(
                    child: Text(
                      isMonitoredOnly
                          ? 'No apps currently monitored'
                          : 'No applications found',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: apps.length,
                  itemExtent: 72.0, // Fixed height for 60fps scrolling
                  itemBuilder: (context, i) {
                    final app = apps[i];
                    final cachedIcon = iconCache[app.packageName];
                    final rules = rulesMap[app.packageName];

                    return RepaintBoundary(
                      key: ValueKey(app.packageName),
                      child: _buildAppTile(app, cachedIcon, rules),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTile(
    AppInfo app,
    dynamic iconBytes,
    List<dynamic>? rules,
  ) {
    String ruleSummary = 'Not monitored';
    if (app.isMonitored && rules != null && rules.isNotEmpty) {
      final parts = <String>[];
      for (final r in rules) {
        final src = r.source as NetworkSource;
        final lim = r.limitMb != null ? '${r.limitMb} MB' : '∞';
        parts.add('${src.displayName}: $lim');
      }
      ruleSummary = parts.join(' · ');
    }

    return ListTile(
      leading: iconBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                iconBytes,
                width: 44,
                height: 44,
                cacheWidth: 88, // 48x48 icon rendered crisp
                filterQuality: FilterQuality.low,
              ),
            )
          : const Icon(Icons.android, size: 44),
      title: Text(
        app.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            app.packageName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ruleSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: app.isMonitored
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RuleEditorScreen(app: app),
          ),
        );
      },
    );
  }
}
