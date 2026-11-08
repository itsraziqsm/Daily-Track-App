import 'package:flutter_test/flutter_test.dart';
import 'package:grou/db/database_helper.dart';
import 'package:grou/models/activity.dart';
import 'package:grou/models/daily_log.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final db = DatabaseHelper.instance;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
  });

  test('menyunting template tidak memutus log dari kegiatannya', () async {
    final template = (await db.allTemplates()).first;
    final [first, second, ...rest] = template.activities;
    await db.upsertLog(DailyLog(
      activityId: first.id,
      date: '2026-11-01',
      status: LogStatus.done,
      timestamp: DateTime(2026, 11, 1),
    ));

    // Ubah judul kegiatan pertama, hapus yang kedua, tambah satu yang baru.
    const added = Activity(id: 0, templateId: 0, startTime: '22.00', endTime: '22.30', title: 'Baca buku', category: 'Kerja/Belajar');
    await db.updateTemplate(template.id, template.name, [first.copyWith(title: 'Bangun pagi'), ...rest, added]);

    final after = (await db.allTemplates()).first.activities;
    final byId = {for (final a in after) a.id: a};
    final log = (await db.logsForDate('2026-11-01')).single;

    expect(byId[log.activityId]?.title, 'Bangun pagi');
    expect(byId.containsKey(second.id), isFalse);
    expect(after.where((a) => a.title == 'Baca buku'), hasLength(1));
    expect(after.length, template.activities.length);
    for (final a in rest) {
      expect(byId[a.id]?.title, a.title, reason: 'kegiatan yang tidak diubah tetap memakai id lamanya');
    }
  });

  test('template baru selalu mendapat kegiatan baru, meski isinya disalin', () async {
    final source = (await db.allTemplates()).first;
    final id = await db.createTemplate('Salinan', source.activities);
    final copy = (await db.allTemplates()).firstWhere((t) => t.id == id);

    expect(copy.activities.length, source.activities.length);
    expect(copy.activities.map((a) => a.id).toSet().intersection(source.activities.map((a) => a.id).toSet()), isEmpty);
  });
}
