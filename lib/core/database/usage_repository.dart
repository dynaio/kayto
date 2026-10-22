import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../native/models/network_source.dart';
import '../../native/models/usage_record.dart';
import 'database_helper.dart';

class EventLogEntry {
  final int? id;
  final DateTime timestamp;
  final String packageName;
  final String appLabel;
  final NetworkSource source;
  final String eventType; // 'WARNING_50', 'WARNING_70', 'WARNING_90', 'ENFORCED_BLOCK'
  final String message;

  const EventLogEntry({
    this.id,
    required this.timestamp,
    required this.packageName,
    required this.appLabel,
    required this.source,
    required this.eventType,
    required this.message,
  });

  factory EventLogEntry.fromMap(Map<String, dynamic> map) {
    return EventLogEntry(
      id: map['id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      packageName: map['package_name'] as String,
      appLabel: map['app_label'] as String,
      source: NetworkSource.fromCode(map['source'] as String),
      eventType: map['event_type'] as String,
      message: map['message'] as String,
    );
  }
}

class UsageRepository {
  final DatabaseHelper _dbHelper;

  UsageRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  String _getTodayString() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> saveUsageSnapshots(List<UsageRecord> records) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    final today = _getTodayString();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final r in records) {
      if (r.wifiBytes > 0) {
        batch.insert(
          'usage_snapshots',
          {
            'package_name': r.packageName,
            'source': NetworkSource.wifi.code,
            'date': today,
            'bytes_used': r.wifiBytes,
            'last_updated': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (r.sim1Bytes > 0) {
        batch.insert(
          'usage_snapshots',
          {
            'package_name': r.packageName,
            'source': NetworkSource.sim1.code,
            'date': today,
            'bytes_used': r.sim1Bytes,
            'last_updated': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (r.sim2Bytes > 0) {
        batch.insert(
          'usage_snapshots',
          {
            'package_name': r.packageName,
            'source': NetworkSource.sim2.code,
            'date': today,
            'bytes_used': r.sim2Bytes,
            'last_updated': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    await batch.commit(noResult: true);
  }

  Future<void> logEvent({
    required String packageName,
    required String appLabel,
    required NetworkSource source,
    required String eventType,
    required String message,
  }) async {
    final db = await _dbHelper.database;
    await db.insert('event_logs', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'package_name': packageName,
      'app_label': appLabel,
      'source': source.code,
      'event_type': eventType,
      'message': message,
    });
  }

  Future<List<EventLogEntry>> getRecentEventLogs({int limit = 50}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'event_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(EventLogEntry.fromMap).toList();
  }

  Future<List<EventLogEntry>> getEventLogsForPackage(
    String packageName, {
    int limit = 50,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'event_logs',
      where: 'package_name = ?',
      whereArgs: [packageName],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(EventLogEntry.fromMap).toList();
  }
}
