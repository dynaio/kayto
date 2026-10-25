import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../native/channels/native_channel.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  PackageInfo? _packageInfo;
  bool _usageAccess = false;
  bool _notificationsPermission = false;
  bool _batteryOptimizationExemption = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPackageInfo();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _packageInfo = info);
    } catch (_) {}
  }

  Future<void> _checkPermissions() async {
    try {
      final usage = await NativeChannel.hasUsageAccess();
      final battery = await NativeChannel.hasBatteryOptimizationExemption();
      final notif = await Permission.notification.isGranted;

      if (mounted) {
        setState(() {
          _usageAccess = usage;
          _batteryOptimizationExemption = battery;
          _notificationsPermission = notif;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsAsync = ref.watch(appSettingsProvider);
    final settings = settingsAsync.value;
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Appearance
                _buildSectionHeader('Appearance'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Theme Mode',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.brightness_auto),
                                label: Text('System'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode),
                                label: Text('Light'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode),
                                label: Text('Dark'),
                              ),
                            ],
                            selected: {settings.themeMode},
                            onSelectionChanged: (set) {
                              notifier.setThemeMode(set.first);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Service Persistence
                _buildSectionHeader('Service'),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.push_pin_outlined),
                        title: const Text(
                          'Keep Kayto running',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Restarts service if app is swiped away from Recents or on reboot',
                        ),
                        value: settings.pinService,
                        onChanged: (val) {
                          notifier.setPinService(val);
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 6),
                  child: Text(
                    'Android may still stop apps you force-stop in system Settings. Kayto cannot override that.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Notifications
                _buildSectionHeader('Notifications'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text(
                          'Enable notifications',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Receive threshold alerts and enforcement status',
                        ),
                        value: settings.notificationsEnabled,
                        onChanged: (val) {
                          notifier.setNotificationsEnabled(val);
                        },
                      ),
                      if (settings.notificationsEnabled) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 12,
                            bottom: 4,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Alert Thresholds (per source)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                        ...[50, 70, 90, 100].map((t) {
                          final isChecked =
                              settings.enabledThresholds.contains(t);
                          return SwitchListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            title: Text(
                              t == 100
                                  ? '100% (Quota exhausted / Hard block)'
                                  : '$t% of daily quota',
                              style: TextStyle(
                                fontWeight: t == 100
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            value: isChecked,
                            onChanged: (val) {
                              if (!val &&
                                  settings.enabledThresholds.length <= 1 &&
                                  isChecked) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'At least one threshold must remain enabled',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }

                              final updated =
                                  List<int>.from(settings.enabledThresholds);
                              if (val) {
                                updated.add(t);
                                updated.sort();
                              } else {
                                updated.remove(t);
                              }
                              notifier.setThresholds(updated);
                            },
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Data & cache
                _buildSectionHeader('Data & cache'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App list refresh interval',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Controls in-memory caching TTL for package discovery',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 15, label: Text('15s')),
                              ButtonSegment(value: 30, label: Text('30s')),
                              ButtonSegment(value: 60, label: Text('1m')),
                              ButtonSegment(value: 300, label: Text('5m')),
                            ],
                            selected: {settings.appListCacheTtl.inSeconds},
                            onSelectionChanged: (set) {
                              notifier.setCacheTtl(Duration(seconds: set.first));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Display
                _buildSectionHeader('Display'),
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.apps_outlined),
                    title: const Text(
                      'Show system apps in the app list',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Display pre-installed OEM and system packages in inventory',
                    ),
                    value: settings.showSystemApps,
                    onChanged: (val) {
                      notifier.setShowSystemApps(val);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Permissions
                _buildSectionHeader('Permissions'),
                Card(
                  child: Column(
                    children: [
                      _buildPermissionTile(
                        icon: Icons.data_usage_outlined,
                        title: 'Usage access (PACKAGE_USAGE_STATS)',
                        subtitle: 'Required to read per-app data consumption',
                        isGranted: _usageAccess,
                        onTap: () async {
                          await NativeChannel.openUsageAccessSettings();
                          await _checkPermissions();
                        },
                      ),
                      const Divider(height: 1),
                      _buildPermissionTile(
                        icon: Icons.notifications_active_outlined,
                        title: 'Notifications',
                        subtitle: 'Required for foreground alerts and quota warnings',
                        isGranted: _notificationsPermission,
                        onTap: () async {
                          final status = await Permission.notification.request();
                          if (status.isPermanentlyDenied) {
                            await openAppSettings();
                          }
                          await _checkPermissions();
                        },
                      ),
                      const Divider(height: 1),
                      _buildPermissionTile(
                        icon: Icons.battery_charging_full_outlined,
                        title: 'Battery optimization exemption',
                        subtitle: 'Ensures background enforcement is not killed',
                        isGranted: _batteryOptimizationExemption,
                        onTap: () async {
                          await NativeChannel.openBatteryOptimizationSettings();
                          await _checkPermissions();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 7. About & Legal
                _buildSectionHeader('About & Legal'),
                Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/kayto_logo.png',
                        width: 36,
                        height: 36,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.info_outline, size: 36),
                      ),
                    ),
                    title: const Text(
                      'About Kayto',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'v${_packageInfo?.version ?? "0.1.0"} • Berassil Abdelkader • Privacy Policy',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      trailing: isGranted
          ? const Chip(
              label: Text('Granted'),
              backgroundColor: Colors.greenAccent,
              padding: EdgeInsets.zero,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            )
          : Chip(
              label: const Text('Missing'),
              backgroundColor: Colors.amberAccent,
              padding: EdgeInsets.zero,
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
      onTap: onTap,
    );
  }
}
