import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../data/seed_activities.dart';
import '../models/activity.dart';
import '../models/daily_log.dart';
import '../models/template.dart';

/// Penyimpanan lokal (sqflite): catatan harian, template kegiatan beserta
/// penugasannya per hari, dan setelan aplikasi.
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
      version: 3,
      onCreate: (db, version) async {
        await db.execute(_createLogs);
        await db.execute(_createSettings);
        await db.execute(_createTemplates);
        await db.execute(_createTemplateActivities);
        await db.execute(_createDayAssignments);
        await _seedDefaultTemplate(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await db.execute(_createSettings);
        if (oldVersion < 3) {
          await db.execute(_createTemplates);
          await db.execute(_createTemplateActivities);
          await db.execute(_createDayAssignments);
          // Kegiatan lama memakai id 1..23 yang sama dengan seed, jadi log yang
          // sudah tercatat tetap menunjuk ke kegiatan yang benar.
          await _seedDefaultTemplate(db);
        }
      },
    );
  }

  static const _createLogs = '''
    CREATE TABLE daily_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      activityId INTEGER NOT NULL,
      date TEXT NOT NULL,
      status TEXT NOT NULL,
      reason TEXT,
      timestamp TEXT NOT NULL,
      UNIQUE(activityId, date)
    )
  ''';

  static const _createSettings = '''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const _createTemplates = '''
    CREATE TABLE templates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
    )
  ''';

  static const _createTemplateActivities = '''
    CREATE TABLE template_activities (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      templateId INTEGER NOT NULL,
      startTime TEXT NOT NULL,
      endTime TEXT NOT NULL,
      title TEXT NOT NULL,
      category TEXT NOT NULL,
      sortOrder INTEGER NOT NULL
    )
  ''';

  /// weekday mengikuti `DateTime.weekday` (1 = Senin … 7 = Minggu).
  static const _createDayAssignments = '''
    CREATE TABLE day_assignments (
      weekday INTEGER PRIMARY KEY,
      templateId INTEGER NOT NULL
    )
  ''';

  Future<void> _seedDefaultTemplate(Database db) async {
    await db.insert('templates', {'id': 1, 'name': defaultTemplateName});
    final batch = db.batch();
    for (final a in seedActivities) {
      batch.insert('template_activities', a.toMap());
    }
    for (var weekday = 1; weekday <= 7; weekday++) {
      batch.insert('day_assignments', {'weekday': weekday, 'templateId': 1});
    }
    await batch.commit(noResult: true);
  }

  // ---- Setelan ----

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

  // ---- Template ----

  Future<List<Template>> allTemplates() async {
    final db = await database;
    final rows = await db.query('templates', orderBy: 'id');
    final acts = await db.query('template_activities', orderBy: 'sortOrder, id');
    final byTemplate = <int, List<Activity>>{};
    for (final r in acts) {
      final a = Activity.fromMap(r);
      byTemplate.putIfAbsent(a.templateId, () => []).add(a);
    }
    return rows
        .map((r) => Template(
              id: r['id'] as int,
              name: r['name'] as String,
              activities: byTemplate[r['id'] as int] ?? const [],
            ))
        .toList();
  }

  Future<Map<int, int>> dayAssignments() async {
    final db = await database;
    final rows = await db.query('day_assignments');
    return {for (final r in rows) r['weekday'] as int: r['templateId'] as int};
  }

  Future<void> assignDay(int weekday, int templateId) async {
    final db = await database;
    await db.insert(
      'day_assignments',
      {'weekday': weekday, 'templateId': templateId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> createTemplate(String name, List<Activity> activities) async {
    final db = await database;
    final id = await db.insert('templates', {'name': name});
    await _writeActivities(db, id, activities);
    return id;
  }

  /// Menyimpan nama dan seluruh isi template. Kegiatan ditulis ulang, jadi
  /// kegiatan yang dihapus di editor ikut hilang di sini.
  Future<void> updateTemplate(int templateId, String name, List<Activity> activities) async {
    final db = await database;
    await db.update('templates', {'name': name}, where: 'id = ?', whereArgs: [templateId]);
    await db.delete('template_activities', where: 'templateId = ?', whereArgs: [templateId]);
    await _writeActivities(db, templateId, activities);
  }

  Future<void> _writeActivities(Database db, int templateId, List<Activity> activities) async {
    final batch = db.batch();
    for (var i = 0; i < activities.length; i++) {
      final map = activities[i].toMap()
        ..remove('id')
        ..['templateId'] = templateId
        ..['sortOrder'] = i;
      batch.insert('template_activities', map);
    }
    await batch.commit(noResult: true);
  }

  /// Menghapus template, memindahkan hari yang memakainya ke [fallbackId].
  Future<void> deleteTemplate(int templateId, int fallbackId) async {
    final db = await database;
    await db.update(
      'day_assignments',
      {'templateId': fallbackId},
      where: 'templateId = ?',
      whereArgs: [templateId],
    );
    await db.delete('template_activities', where: 'templateId = ?', whereArgs: [templateId]);
    await db.delete('templates', where: 'id = ?', whereArgs: [templateId]);
  }

  // ---- Catatan harian ----

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
