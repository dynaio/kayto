import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../native/channels/native_channel.dart';
import '../../native/models/app_rule.dart';
import '../../native/models/network_source.dart';
import 'database_helper.dart';

class RulesRepository {
  final DatabaseHelper _dbHelper;

  RulesRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<AppRule>> getAllRules() async {
    final db = await _dbHelper.database;
    final rows = await db.query('app_rules');
    return rows.map((r) {
      return AppRule(
        id: r['id'] as int?,
        packageName: r['package_name'] as String,
        source: NetworkSource.fromCode(r['source'] as String),
        limitMb: r['limit_mb'] as int?,
        scheduleMode: r['schedule_mode'] as String,
        customDaysBitmask: r['custom_days_bitmask'] as int,
        notifyAt: (jsonDecode(r['notify_at'] as String) as List)
            .map((e) => (e as num).toInt())
            .toList(),
        isEnforced: (r['is_enforced'] as int) == 1,
        isMonitored: true,
      );
    }).toList();
  }

  Future<List<AppRule>> getRulesForPackage(String packageName) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'app_rules',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );

    return rows.map((r) {
      return AppRule(
        id: r['id'] as int?,
        packageName: r['package_name'] as String,
        source: NetworkSource.fromCode(r['source'] as String),
        limitMb: r['limit_mb'] as int?,
        scheduleMode: r['schedule_mode'] as String,
        customDaysBitmask: r['custom_days_bitmask'] as int,
        notifyAt: (jsonDecode(r['notify_at'] as String) as List)
            .map((e) => (e as num).toInt())
            .toList(),
        isEnforced: (r['is_enforced'] as int) == 1,
        isMonitored: true,
      );
    }).toList();
  }

  Future<Set<String>> getMonitoredPackageNames() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'monitored_apps',
      columns: ['package_name'],
      where: 'is_monitored = 1',
    );
    return rows.map((r) => r['package_name'] as String).toSet();
  }

  Future<void> setAppMonitoring(
    String packageName,
    String appLabel,
    bool isMonitored,
  ) async {
    final db = await _dbHelper.database;
    await db.insert(
      'monitored_apps',
      {
        'package_name': packageName,
        'app_label': appLabel,
        'is_monitored': isMonitored ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (!isMonitored) {
      // Remove or inactivate rules
      await db.delete(
        'app_rules',
        where: 'package_name = ?',
        whereArgs: [packageName],
      );
    }

    await syncRulesToNative();
  }

  Future<void> saveRulesForPackage(
    String packageName,
    String appLabel,
    List<AppRule> rules,
  ) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // Ensure app is in monitored_apps
    batch.insert(
      'monitored_apps',
      {
        'package_name': packageName,
        'app_label': appLabel,
        'is_monitored': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    for (final rule in rules) {
      batch.insert(
        'app_rules',
        {
          'package_name': rule.packageName,
          'source': rule.source.code,
          'limit_mb': rule.limitMb,
          'schedule_mode': rule.scheduleMode,
          'custom_days_bitmask': rule.customDaysBitmask,
          'notify_at': jsonEncode(rule.notifyAt),
          'is_enforced': rule.isEnforced ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await syncRulesToNative();
  }

  Future<void> syncRulesToNative() async {
    final allRules = await getAllRules();
    await NativeChannel.syncRules(allRules);
  }
}
