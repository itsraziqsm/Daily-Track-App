import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/daily_log.dart';

/// Penyimpanan lokal (sqflite) untuk catatan harian [DailyLog].
///
/// Satu kegiatan hanya punya satu status per tanggal (unique activityId+date):
/// menandai ulang sebuah kegiatan pada hari yang sama menimpa catatan sebelumnya.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'jadwal_harian.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE daily_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            activityId INTEGER NOT NULL,
            date TEXT NOT NULL,
            status TEXT NOT NULL,
            reason TEXT,
            timestamp TEXT NOT NULL,
            UNIQUE(activityId, date)
          )
        ''');
        await db.execute(_createSettings);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await db.execute(_createSettings);
      },
    );
  }

  static const _createSettings = '''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertLog(DailyLog log) async {
    final db = await database;
    await db.insert(
      'daily_logs',
      log.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLogForActivityOnDate(int activityId, String date) async {
    final db = await database;
    await db.delete(
      'daily_logs',
      where: 'activityId = ? AND date = ?',
      whereArgs: [activityId, date],
    );
  }

  Future<List<DailyLog>> logsForDate(String date) async {
    final db = await database;
    final rows = await db.query('daily_logs', where: 'date = ?', whereArgs: [date]);
    return rows.map(DailyLog.fromMap).toList();
  }

  Future<List<DailyLog>> cancelledLogs() async {
    final db = await database;
    final rows = await db.query(
      'daily_logs',
      where: 'status = ?',
      whereArgs: [LogStatus.cancelled.value],
      orderBy: 'date DESC, timestamp DESC',
    );
    return rows.map(DailyLog.fromMap).toList();
  }

  /// Seluruh log, terbaru dulu. Dipakai untuk kalender, statistik, dan streak.
  Future<List<DailyLog>> allLogs() async {
    final db = await database;
    final rows = await db.query('daily_logs', orderBy: 'date DESC, timestamp DESC');
    return rows.map(DailyLog.fromMap).toList();
  }
}
