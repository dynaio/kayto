import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../models/app_rule.dart';
import '../models/enforcement_stats.dart';
import '../models/permission_status.dart';
import '../models/sim_info.dart';
import '../models/usage_record.dart';

class NativeChannel {
  static const MethodChannel _channel = MethodChannel('com.kayto/native');
  static const EventChannel _events = EventChannel('com.kayto/events');

  static Future<List<AppInfo>> listInstalledApps() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('listInstalledApps');
    return (result ?? const <dynamic>[])
        .cast<Map<dynamic, dynamic>>()
        .map((e) => AppInfo.fromMap(e.cast<String, dynamic>()))
        .toList();
  }

  static Future<List<AppInfo>> listInstalledAppsLite() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('listInstalledAppsLite');
    return (result ?? const <dynamic>[])
        .cast<Map<dynamic, dynamic>>()
        .map((e) => AppInfo.fromMap(e.cast<String, dynamic>()))
        .toList();
  }

  static Future<Uint8List?> getAppIcon(String packageName) async {
    final result = await _channel.invokeMethod<Uint8List>(
      'getAppIcon',
      {'packageName': packageName},
    );
    return result;
  }

  static Future<bool> hasUsageAccess() async {
    final result = await _channel.invokeMethod<bool>('hasUsageAccess');
    return result ?? false;
  }

  static Future<bool> hasBatteryOptimizationExemption() async {
    final result =
        await _channel.invokeMethod<bool>('hasBatteryOptimizationExemption');
    return result ?? false;
  }

  static Future<void> openUsageAccessSettings() async {
    await _channel.invokeMethod<void>('openUsageAccessSettings');
  }

  static Future<void> openBatteryOptimizationSettings() async {
    await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
  }

  static Future<List<SimInfo>> getSimCards() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getSimCards');
    return (result ?? const <dynamic>[])
        .cast<Map<dynamic, dynamic>>()
        .map((e) => SimInfo.fromMap(e.cast<String, dynamic>()))
        .toList();
  }

  static Future<UsageRecord?> getUsageForPackage(String packageName) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getNetworkUsage',
      {'packageName': packageName},
    );
    if (result == null) return null;
    return UsageRecord.fromMap(result.cast<String, dynamic>());
  }

  static Future<List<UsageRecord>> getAllAppsUsage() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('getNetworkUsage');
    return (result ?? const <dynamic>[])
        .cast<Map<dynamic, dynamic>>()
        .map((e) => UsageRecord.fromMap(e.cast<String, dynamic>()))
        .toList();
  }

  static Future<String> getActiveNetwork() async {
    final result = await _channel.invokeMethod<String>('getActiveNetwork');
    return result ?? 'NONE';
  }

  static Future<bool> prepareVpn() async {
    final result = await _channel.invokeMethod<bool>('prepareVpn');
    return result ?? false;
  }

  static Future<bool> startVpn() async {
    final result = await _channel.invokeMethod<bool>('startVpn');
    return result ?? false;
  }

  static Future<bool> stopVpn() async {
    final result = await _channel.invokeMethod<bool>('stopVpn');
    return result ?? false;
  }

  static Future<bool> isVpnRunning() async {
    final result = await _channel.invokeMethod<bool>('isVpnRunning');
    return result ?? false;
  }

  static Future<bool> syncRules(List<AppRule> rules) async {
    final rulesPayload = rules.map((r) => r.toMap()).toList();
    final result = await _channel.invokeMethod<bool>(
      'syncRules',
      {'rules': rulesPayload},
    );
    return result ?? false;
  }

  static Future<EnforcementStats> getEnforcementStats() async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('getEnforcementStats');
    if (result == null) return const EnforcementStats();
    return EnforcementStats.fromMap(result.cast<String, dynamic>());
  }

  static Future<PermissionHealth> checkPermissions() async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('checkPermissions');
    if (result == null) return const PermissionHealth();
    return PermissionHealth.fromMap(result.cast<String, dynamic>());
  }

  static Future<bool> requestUsageAccess() async {
    final result = await _channel.invokeMethod<bool>('requestUsageAccess');
    return result ?? false;
  }

  static Future<bool> requestBatteryOptimizationExemption() async {
    final result = await _channel.invokeMethod<bool>(
      'requestBatteryOptimizationExemption',
    );
    return result ?? false;
  }

  static Stream<Map<String, dynamic>> eventsStream() =>
      _events.receiveBroadcastStream().map(
            (e) => (e as Map).cast<String, dynamic>(),
          );
}
