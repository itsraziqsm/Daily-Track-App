import 'package:flutter_test/flutter_test.dart';
import 'package:grou/db/database_helper.dart';
import 'package:grou/models/daily_log.dart';
import 'package:grou/models/target.dart';
import 'package:grou/providers/schedule_provider.dart';
import 'package:grou/providers/target_provider.dart';
import 'package:grou/utils/app_time.dart';
import 'package:grou/utils/number_format.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
  });

  group('TargetPeriod', () {
    final created = DateTime(2026, 1, 1);

    test('minggu dimulai Senin', () {
      // 8 November 2026 adalah hari Minggu.
      expect(TargetPeriod.week.startOf(DateTime(2026, 11, 8), created), DateTime(2026, 11, 2));
      expect(TargetPeriod.week.startOf(DateTime(2026, 11, 9), created), DateTime(2026, 11, 9));
      expect(TargetPeriod.week.nextStart(DateTime(2026, 11, 2)), DateTime(2026, 11, 9));
      expect(TargetPeriod.week.previousStart(DateTime(2026, 11, 2)), DateTime(2026, 10, 26));
    });

    test('bulan, tahun, dan total', () {
      expect(TargetPeriod.month.startOf(DateTime(2026, 11, 8), created), DateTime(2026, 11));
      expect(TargetPeriod.month.nextStart(DateTime(2026, 12)), DateTime(2027, 1));
      expect(TargetPeriod.year.startOf(DateTime(2026, 11, 8), created), DateTime(2026));
      expect(TargetPeriod.total.startOf(DateTime(2026, 11, 8), created), created);
      expect(TargetPeriod.total.nextStart(created), isNull);
    });
  });

  test('angka diketik dengan koma atau titik', () {
    expect(parseNumber('72,5'), 72.5);
    expect(parseNumber(' 72.5 '), 72.5);
    expect(parseNumber(''), isNull);
    expect(parseNumber('abc'), isNull);
    expect(formatNumber(72.5), '72,5');
    expect(formatNumber(1250), '1.250');
  });

  group('TargetProvider', () {
    late TargetProvider targets;
    final created = DateTime(2026, 11, 1);

    setUp(() async {
      targets = TargetProvider();
      await targets.load();
      for (final t in [...targets.active, ...targets.archived]) {
        await targets.delete(t);
      }
    });

    Future<Target> add(Target t) async {
      await targets.save(t);
      return targets.active.last;
    }

    Future<void> entry(Target t, DateTime date, double value) =>
        targets.addEntry(TargetEntry(targetId: t.id, date: date, value: value));

    test('angka turun: progres dari nilai awal, tercapai saat melewati target', () async {
      final weight = await add(Target(kind: TargetKind.value, title: 'Berat badan', unit: 'kg', startValue: 80, targetValue: 72, createdAt: created));
      final today = DateTime(2026, 11, 10);

      var p = targets.progressOf(weight, today: today);
      expect(p.current, 80);
      expect(p.fraction, 0);
      expect(p.status, TargetStatus.ongoing, reason: 'tanpa tenggat');

      await entry(weight, DateTime(2026, 11, 3), 78);
      await entry(weight, DateTime(2026, 11, 8), 76);
      p = targets.progressOf(weight, today: today);
      expect(p.current, 76, reason: 'nilai terbaru yang dipakai');
      expect(p.fraction, closeTo(0.5, 1e-9));

      await entry(weight, DateTime(2026, 11, 9), 71.5);
      expect(targets.progressOf(weight, today: today).status, TargetStatus.achieved);
    });

    test('angka naik dengan tenggat: sesuai jalur, tertinggal, lalu lewat tenggat', () async {
      final bench = await add(Target(
        kind: TargetKind.value,
        title: 'Bench press',
        unit: 'kg',
        startValue: 60,
        targetValue: 100,
        deadline: DateTime(2026, 11, 30),
        createdAt: created,
      ));
      await entry(bench, DateTime(2026, 11, 5), 70); // 25%

      expect(targets.progressOf(bench, today: DateTime(2026, 11, 5)).status, TargetStatus.onTrack);
      expect(targets.progressOf(bench, today: DateTime(2026, 11, 25)).status, TargetStatus.behind);
      expect(targets.progressOf(bench, today: DateTime(2026, 12, 1)).status, TargetStatus.missed);
    });

    test('hitungan mingguan hanya menjumlah minggu berjalan', () async {
      final gym = await add(Target(kind: TargetKind.count, title: 'Gym', unit: 'sesi', targetValue: 3, period: TargetPeriod.week, createdAt: created));
      await entry(gym, DateTime(2026, 11, 1), 1); // minggu lalu (Minggu 1 Nov)

      final monday = DateTime(2026, 11, 2), sunday = DateTime(2026, 11, 8);
      expect(targets.progressOf(gym, today: monday).current, 0, reason: 'catatan minggu lalu tidak ikut');
      expect(targets.progressOf(gym, today: monday).status, TargetStatus.onTrack, reason: 'minggu baru dimulai');

      await entry(gym, DateTime(2026, 11, 3), 1);
      expect(targets.progressOf(gym, today: sunday).current, 1);
      expect(targets.progressOf(gym, today: sunday).status, TargetStatus.behind);

      await entry(gym, DateTime(2026, 11, 5), 2);
      expect(targets.progressOf(gym, today: sunday).status, TargetStatus.achieved);

      final history = targets.periodHistory(gym, today: DateTime(2026, 11, 10));
      expect(history.map((p) => p.start), [DateTime(2026, 10, 26), DateTime(2026, 11, 2), DateTime(2026, 11, 9)],
          reason: 'tidak mundur melewati minggu tempat target dibuat');
      expect(history.map((p) => p.total), [1, 3, 0]);
    });

    test('menghapus target ikut menghapus catatannya', () async {
      final books = await add(Target(kind: TargetKind.count, title: 'Baca buku', targetValue: 12, createdAt: created));
      await entry(books, created, 1);
      await targets.delete(books);
      expect(await DatabaseHelper.instance.allTargetEntries(), isEmpty);
    });
  });

  group('streak hari lengkap', () {
    test('terlambat dihitung, pembatalan memutus, hari ini yang belum lengkap tidak memutus', () async {
      AppTime.zone = AppTimeZone.wib;
      final schedule = ScheduleProvider();
      addTearDown(schedule.dispose);
      await schedule.load();
      final db = DatabaseHelper.instance;
      final now = AppTime.now();
      final today = DateTime(now.year, now.month, now.day);

      Future<void> fill(DateTime day, {LogStatus last = LogStatus.done}) async {
        final activities = schedule.templateForWeekday(day.weekday)!.activities;
        for (final (i, a) in activities.indexed) {
          await db.upsertLog(DailyLog(
            activityId: a.id,
            date: AppTime.dateKey(day),
            status: i == activities.length - 1 ? last : (i.isEven ? LogStatus.done : LogStatus.late),
            timestamp: day,
          ));
        }
      }

      // 6 hari lalu dibatalkan, lalu 5 hari lengkap berturut-turut sampai kemarin.
      await fill(today.subtract(const Duration(days: 6)), last: LogStatus.cancelled);
      for (var d = 5; d >= 1; d--) {
        await fill(today.subtract(Duration(days: d)));
      }
      await fill(today.subtract(const Duration(days: 9)));
      await fill(today.subtract(const Duration(days: 8)));
      await schedule.load();

      expect(schedule.completedStreak, 5, reason: 'hari ini belum dicentang, streak tetap sampai kemarin');
      expect(schedule.bestCompletedStreak, 5);

      await fill(today);
      await schedule.load();
      expect(schedule.completedStreak, 6);

      final targets = TargetProvider()..schedule = schedule;
      final t = Target(kind: TargetKind.streak, title: '2 minggu', targetValue: 14, createdAt: today);
      final p = targets.progressOf(t);
      expect(p.current, 6);
      expect(p.best, 6);
      expect(p.fraction, closeTo(6 / 14, 1e-9));
    });
  });
}
