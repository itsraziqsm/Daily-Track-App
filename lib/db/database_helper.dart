import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../data/seed_activities.dart';
import '../models/activity.dart';
import '../models/agenda_item.dart';
import '../models/daily_log.dart';
import '../models/target.dart';
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

  /// Lokasi database pengganti untuk test (mis. [inMemoryDatabasePath]),
  /// supaya file test yang berjalan paralel tidak berbagi satu berkas.
  @visibleForTesting
  static String? pathOverride;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = pathOverride ?? join(await getDatabasesPath(), 'jadwal_harian.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute(_createLogs);
        await db.execute(_createSettings);
        await db.execute(_createTemplates);
        await db.execute(_createTemplateActivities);
        await db.execute(_createDayAssignments);
        await db.execute(_createAgendaItems);
        await db.execute(_createAgendaOccurrences);
        await db.execute(_createTargets);
        await db.execute(_createTargetEntries);
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
        if (oldVersion < 4) {
          await db.execute(_createAgendaItems);
          await db.execute(_createAgendaOccurrences);
        }
        if (oldVersion < 5) {
          await db.execute(_createTargets);
          await db.execute(_createTargetEntries);
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

  static const _createAgendaItems = '''
    CREATE TABLE agenda_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      note TEXT,
      date TEXT NOT NULL,
      startTime TEXT,
      endTime TEXT,
      repeat TEXT NOT NULL,
      repeatDays TEXT NOT NULL,
      repeatUntil TEXT,
      reminderMinutes INTEGER
    )
  ''';

  /// Status per tanggal untuk agenda (selesai, atau dilewati khusus tanggal
  /// itu). Tanggal tanpa baris berarti agenda biasa yang belum selesai.
  static const _createAgendaOccurrences = '''
    CREATE TABLE agenda_occurrences (
      itemId INTEGER NOT NULL,
      date TEXT NOT NULL,
      state TEXT NOT NULL,
      PRIMARY KEY (itemId, date)
    )
  ''';

  static const _createTargets = '''
    CREATE TABLE targets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kind TEXT NOT NULL,
      title TEXT NOT NULL,
      unit TEXT,
      startValue REAL,
      targetValue REAL NOT NULL,
      period TEXT NOT NULL,
      deadline TEXT,
      createdAt TEXT NOT NULL,
      archived INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const _createTargetEntries = '''
    CREATE TABLE target_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      targetId INTEGER NOT NULL,
      date TEXT NOT NULL,
      value REAL NOT NULL,
      note TEXT
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
    // Template baru selalu mendapat baris kegiatan baru.
    await _writeActivities(db, id, [for (final a in activities) a.copyWith(id: 0)]);
    return id;
  }

  /// Menyimpan nama dan seluruh isi template. Kegiatan yang sudah ada
  /// diperbarui di tempat supaya id-nya tetap — log harian menunjuk ke id itu,
  /// jadi menulis ulang semuanya akan memutus log lama dari kegiatannya.
  /// Kegiatan baru (id 0) ditambahkan, yang dihapus di editor ikut dihapus.
  Future<void> updateTemplate(int templateId, String name, List<Activity> activities) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('templates', {'name': name}, where: 'id = ?', whereArgs: [templateId]);
      final kept = [for (final a in activities) if (a.id > 0) a.id];
      await txn.delete(
        'template_activities',
        where: kept.isEmpty ? 'templateId = ?' : 'templateId = ? AND id NOT IN (${List.filled(kept.length, '?').join(', ')})',
        whereArgs: [templateId, ...kept],
      );
      await _writeActivities(txn, templateId, activities);
    });
  }

  Future<void> _writeActivities(DatabaseExecutor db, int templateId, List<Activity> activities) async {
    final batch = db.batch();
    for (var i = 0; i < activities.length; i++) {
      final a = activities[i];
      final map = a.toMap()
        ..remove('id')
        ..['templateId'] = templateId
        ..['sortOrder'] = i;
      if (a.id > 0) {
        batch.update('template_activities', map, where: 'id = ? AND templateId = ?', whereArgs: [a.id, templateId]);
      } else {
        batch.insert('template_activities', map);
      }
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

  // ---- Agenda ----

  Future<List<AgendaItem>> allAgendaItems() async {
    final db = await database;
    final rows = await db.query('agenda_items', orderBy: 'date, startTime, id');
    return rows.map(AgendaItem.fromMap).toList();
  }

  /// Menyimpan agenda: id 0 berarti baru. Mengembalikan id-nya.
  Future<int> saveAgendaItem(AgendaItem item) async {
    final db = await database;
    final map = item.toMap()..remove('id');
    if (item.id == 0) return db.insert('agenda_items', map);
    await db.update('agenda_items', map, where: 'id = ?', whereArgs: [item.id]);
    return item.id;
  }

  Future<void> deleteAgendaItem(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('agenda_occurrences', where: 'itemId = ?', whereArgs: [id]);
      await txn.delete('agenda_items', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Status per tanggal, dengan kunci `"itemId|yyyy-MM-dd"`.
  Future<Map<String, AgendaOccurrenceState>> agendaOccurrences() async {
    final db = await database;
    final rows = await db.query('agenda_occurrences');
    return {
      for (final r in rows)
        '${r['itemId']}|${r['date']}':
            AgendaOccurrenceState.values.byName(r['state'] as String),
    };
  }

  /// Mengisi atau menghapus (bila [state] null) status satu kemunculan.
  Future<void> setAgendaOccurrence(int itemId, String date, AgendaOccurrenceState? state) async {
    final db = await database;
    if (state == null) {
      await db.delete('agenda_occurrences', where: 'itemId = ? AND date = ?', whereArgs: [itemId, date]);
    } else {
      await db.insert(
        'agenda_occurrences',
        {'itemId': itemId, 'date': date, 'state': state.name},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ---- Target ----

  Future<List<Target>> allTargets() async {
    final db = await database;
    final rows = await db.query('targets', orderBy: 'id');
    return rows.map(Target.fromMap).toList();
  }

  Future<int> saveTarget(Target target) async {
    final db = await database;
    final map = target.toMap()..remove('id');
    if (target.id == 0) return db.insert('targets', map);
    await db.update('targets', map, where: 'id = ?', whereArgs: [target.id]);
    return target.id;
  }

  Future<void> deleteTarget(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('target_entries', where: 'targetId = ?', whereArgs: [id]);
      await txn.delete('targets', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Semua catatan, urut tanggal lalu urutan pencatatan.
  Future<List<TargetEntry>> allTargetEntries() async {
    final db = await database;
    final rows = await db.query('target_entries', orderBy: 'date, id');
    return rows.map(TargetEntry.fromMap).toList();
  }

  Future<int> addTargetEntry(TargetEntry entry) async {
    final db = await database;
    return db.insert('target_entries', entry.toMap()..remove('id'));
  }

  Future<void> deleteTargetEntry(int id) async {
    final db = await database;
    await db.delete('target_entries', where: 'id = ?', whereArgs: [id]);
  }
}
