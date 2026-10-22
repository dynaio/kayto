import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../native/models/app_info.dart';
import '../../../native/models/app_rule.dart';
import '../../../native/models/network_source.dart';
import '../../../native/models/sim_info.dart';
import '../../../native/models/usage_record.dart';

class RuleEditorScreen extends ConsumerStatefulWidget {
  final AppInfo app;

  const RuleEditorScreen({super.key, required this.app});

  @override
  ConsumerState<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends ConsumerState<RuleEditorScreen> {
  late bool _isMonitored;

  // Wi-Fi state
  int? _wifiLimitMb;
  String _wifiScheduleMode = 'DAILY';
  int _wifiCustomDays = 127;

  // SIM 1 state
  int? _sim1LimitMb = 100;
  String _sim1ScheduleMode = 'DAILY';
  int _sim1CustomDays = 127;

  // SIM 2 state
  int? _sim2LimitMb = 100;
  String _sim2ScheduleMode = 'DAILY';
  int _sim2CustomDays = 127;

  // Notification and Enforcement
  List<int> _notifyAt = [50, 70, 90, 100];
  bool _isEnforced = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isMonitored = widget.app.isMonitored;
    _initExistingRules();
  }

  void _initExistingRules() {
    final rulesRepo = ref.read(rulesRepositoryProvider);
    rulesRepo.getRulesForPackage(widget.app.packageName).then((rules) {
      if (!mounted || rules.isEmpty) return;

      setState(() {
        for (final rule in rules) {
          switch (rule.source) {
            case NetworkSource.wifi:
              _wifiLimitMb = rule.limitMb;
              _wifiScheduleMode = rule.scheduleMode;
              _wifiCustomDays = rule.customDaysBitmask;
              break;
            case NetworkSource.sim1:
              _sim1LimitMb = rule.limitMb;
              _sim1ScheduleMode = rule.scheduleMode;
              _sim1CustomDays = rule.customDaysBitmask;
              break;
            case NetworkSource.sim2:
              _sim2LimitMb = rule.limitMb;
              _sim2ScheduleMode = rule.scheduleMode;
              _sim2CustomDays = rule.customDaysBitmask;
              break;
          }
          _notifyAt = List.from(rule.notifyAt);
          _isEnforced = rule.isEnforced;
        }
      });
    });
  }

  Future<void> _saveRules() async {
    setState(() => _isSaving = true);

    try {
      if (!_isMonitored) {
        await ref.read(appsProvider.notifier).updateAppMonitoring(
              widget.app.packageName,
              widget.app.label,
              false,
            );
      } else {
        final rules = [
          AppRule(
            packageName: widget.app.packageName,
            source: NetworkSource.wifi,
            limitMb: _wifiLimitMb,
            scheduleMode: _wifiScheduleMode,
            customDaysBitmask: _wifiCustomDays,
            notifyAt: _notifyAt,
            isEnforced: _isEnforced,
            isMonitored: true,
          ),
          AppRule(
            packageName: widget.app.packageName,
            source: NetworkSource.sim1,
            limitMb: _sim1LimitMb,
            scheduleMode: _sim1ScheduleMode,
            customDaysBitmask: _sim1CustomDays,
            notifyAt: _notifyAt,
            isEnforced: _isEnforced,
            isMonitored: true,
          ),
          AppRule(
            packageName: widget.app.packageName,
            source: NetworkSource.sim2,
            limitMb: _sim2LimitMb,
            scheduleMode: _sim2ScheduleMode,
            customDaysBitmask: _sim2CustomDays,
            notifyAt: _notifyAt,
            isEnforced: _isEnforced,
            isMonitored: true,
          ),
        ];

        await ref.read(appsProvider.notifier).saveRules(
              widget.app.packageName,
              widget.app.label,
              rules,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rules saved & synced successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save rules: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showCustomLimitDialog({
    required String title,
    required int? currentVal,
    required ValueChanged<int?> onSelected,
  }) {
    final controller = TextEditingController(
      text: currentVal != null ? currentVal.toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Custom limit for $title'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quota in Megabytes (MB)',
            hintText: 'e.g. 350',
            suffixText: 'MB',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                onSelected(val);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Set Limit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final simsAsync = ref.watch(simCardsProvider);
    final usageState = ref.watch(usageProvider);
    final usageRecord = usageState.usageMap[widget.app.packageName] ??
        UsageRecord(packageName: widget.app.packageName);

    final sims = simsAsync.value ?? const <SimInfo>[];
    final sim1Info = sims.where((s) => s.slotIndex == 0).firstOrNull;
    final sim2Info = sims.where((s) => s.slotIndex == 1).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rule Editor'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveRules,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Header
          _buildAppHeader(),
          const SizedBox(height: 16),

          if (_isMonitored) ...[
            // Wi-Fi Rule Section
            _buildSourceCard(
              title: 'Wi-Fi Network',
              subtitle: 'Local Wireless Access',
              icon: Icons.wifi,
              color: Colors.blue,
              usedMb: usageRecord.wifiMb,
              limitMb: _wifiLimitMb,
              scheduleMode: _wifiScheduleMode,
              customDays: _wifiCustomDays,
              onLimitChanged: (val) => setState(() => _wifiLimitMb = val),
              onScheduleChanged: (mode) =>
                  setState(() => _wifiScheduleMode = mode),
              onDayToggled: (day) => setState(
                () => _wifiCustomDays = _wifiCustomDays ^ (1 << day),
              ),
              onCustomTap: () => _showCustomLimitDialog(
                title: 'Wi-Fi',
                currentVal: _wifiLimitMb,
                onSelected: (val) => setState(() => _wifiLimitMb = val),
              ),
            ),
            const SizedBox(height: 16),

            // SIM 1 Rule Section
            _buildSourceCard(
              title: 'SIM 1 Cellular',
              subtitle: sim1Info != null
                  ? '${sim1Info.carrierName} ${sim1Info.isDefaultData ? "• Primary Data" : ""}'
                  : 'Cellular SIM 1 Slot',
              icon: Icons.sim_card_outlined,
              color: Colors.teal,
              usedMb: usageRecord.sim1Mb,
              limitMb: _sim1LimitMb,
              scheduleMode: _sim1ScheduleMode,
              customDays: _sim1CustomDays,
              onLimitChanged: (val) => setState(() => _sim1LimitMb = val),
              onScheduleChanged: (mode) =>
                  setState(() => _sim1ScheduleMode = mode),
              onDayToggled: (day) => setState(
                () => _sim1CustomDays = _sim1CustomDays ^ (1 << day),
              ),
              onCustomTap: () => _showCustomLimitDialog(
                title: 'SIM 1',
                currentVal: _sim1LimitMb,
                onSelected: (val) => setState(() => _sim1LimitMb = val),
              ),
            ),
            const SizedBox(height: 16),

            // SIM 2 Rule Section
            _buildSourceCard(
              title: 'SIM 2 Cellular',
              subtitle: sim2Info != null
                  ? '${sim2Info.carrierName} ${sim2Info.isDefaultData ? "• Primary Data" : ""}'
                  : 'Secondary SIM Slot',
              icon: Icons.sim_card,
              color: Colors.deepOrange,
              usedMb: usageRecord.sim2Mb,
              limitMb: _sim2LimitMb,
              scheduleMode: _sim2ScheduleMode,
              customDays: _sim2CustomDays,
              onLimitChanged: (val) => setState(() => _sim2LimitMb = val),
              onScheduleChanged: (mode) =>
                  setState(() => _sim2ScheduleMode = mode),
              onDayToggled: (day) => setState(
                () => _sim2CustomDays = _sim2CustomDays ^ (1 << day),
              ),
              onCustomTap: () => _showCustomLimitDialog(
                title: 'SIM 2',
                currentVal: _sim2LimitMb,
                onSelected: (val) => setState(() => _sim2LimitMb = val),
              ),
            ),
            const SizedBox(height: 16),

            // Thresholds and Enforcement
            _buildThresholdsCard(),
            const SizedBox(height: 16),

            _buildEnforcementCard(),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isSaving ? null : _saveRules,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save & Enforce Rules'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            widget.app.icon != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(widget.app.icon!, width: 56, height: 56),
                  )
                : const Icon(Icons.android, size: 56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.app.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.app.packageName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch(
              value: _isMonitored,
              onChanged: (val) => setState(() => _isMonitored = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double usedMb,
    required int? limitMb,
    required String scheduleMode,
    required int customDays,
    required ValueChanged<int?> onLimitChanged,
    required ValueChanged<String> onScheduleChanged,
    required ValueChanged<int> onDayToggled,
    required VoidCallback onCustomTap,
  }) {
    final hasLimit = limitMb != null;
    final progress = hasLimit && limitMb > 0 ? (usedMb / limitMb).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  hasLimit ? '$limitMb MB' : 'Infinite (∞)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            LinearProgressIndicator(
              value: progress,
              color: progress >= 0.9 ? Colors.red : color,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${usedMb.toStringAsFixed(1)} MB used today',
                  style: const TextStyle(fontSize: 12),
                ),
                if (hasLimit)
                  Text(
                    '${(limitMb - usedMb).clamp(0, double.infinity).toStringAsFixed(1)} MB remaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),

            const Text(
              'Daily Limit Preset',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildPresetChip(
                  label: 'Infinite',
                  isSelected: limitMb == null,
                  onSelected: () => onLimitChanged(null),
                ),
                _buildPresetChip(
                  label: '100 MB',
                  isSelected: limitMb == 100,
                  onSelected: () => onLimitChanged(100),
                ),
                _buildPresetChip(
                  label: '200 MB',
                  isSelected: limitMb == 200,
                  onSelected: () => onLimitChanged(200),
                ),
                _buildPresetChip(
                  label: '500 MB',
                  isSelected: limitMb == 500,
                  onSelected: () => onLimitChanged(500),
                ),
                ActionChip(
                  label: Text(
                    limitMb != null &&
                            !AppConstants.limitPresets.contains(limitMb)
                        ? '$limitMb MB'
                        : 'Custom',
                  ),
                  avatar: const Icon(Icons.edit, size: 16),
                  onPressed: onCustomTap,
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Schedule',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'DAILY', label: Text('Every day')),
                ButtonSegment(value: 'CUSTOM_DAYS', label: Text('Custom days')),
              ],
              selected: {scheduleMode},
              onSelectionChanged: (set) => onScheduleChanged(set.first),
            ),

            if (scheduleMode == 'CUSTOM_DAYS') ...[
              const SizedBox(height: 12),
              _buildDayPicker(customDays, onDayToggled),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildDayPicker(int bitmask, ValueChanged<int> onDayToggled) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final isActive = ((bitmask >> i) & 1) == 1;
        return FilterChip(
          label: Text(days[i][0]),
          selected: isActive,
          onSelected: (_) => onDayToggled(i),
        );
      }),
    );
  }

  Widget _buildThresholdsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Tiered Warnings & Notifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Alerts are triggered per source when consumption reaches:',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [50, 70, 90, 100].map((threshold) {
                final isChecked = _notifyAt.contains(threshold);
                return FilterChip(
                  label: Text('$threshold%'),
                  selected: isChecked,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _notifyAt.add(threshold);
                        _notifyAt.sort();
                      } else {
                        _notifyAt.remove(threshold);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnforcementCard() {
    return Card(
      child: SwitchListTile(
        secondary: const CircleAvatar(
          backgroundColor: Colors.redAccent,
          child: Icon(Icons.block, color: Colors.white),
        ),
        title: const Text(
          'Hard Enforcement at 100%',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Cut internet traffic for the exhausted source only; other sources remain untouched.',
        ),
        value: _isEnforced,
        onChanged: (val) => setState(() => _isEnforced = val),
      ),
    );
  }
}
