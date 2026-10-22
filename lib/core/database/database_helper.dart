import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kayto.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE monitored_apps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT UNIQUE NOT NULL,
        app_label TEXT NOT NULL,
        is_monitored INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE app_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        source TEXT NOT NULL,
        limit_mb INTEGER,
        schedule_mode TEXT NOT NULL DEFAULT 'DAILY',
        custom_days_bitmask INTEGER NOT NULL DEFAULT 127,
        notify_at TEXT NOT NULL DEFAULT '[50, 70, 90, 100]',
        is_enforced INTEGER NOT NULL DEFAULT 1,
        UNIQUE(package_name, source)
      )
    ''');

    await db.execute('''
      CREATE TABLE usage_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        source TEXT NOT NULL,
        date TEXT NOT NULL,
        bytes_used INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE event_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        package_name TEXT NOT NULL,
        app_label TEXT NOT NULL,
        source TEXT NOT NULL,
        event_type TEXT NOT NULL,
        message TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
