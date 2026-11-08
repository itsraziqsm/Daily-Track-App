import 'package:flutter_test/flutter_test.dart';
import 'package:grou/db/database_helper.dart';
import 'package:grou/models/agenda_item.dart';
import 'package:grou/providers/agenda_provider.dart';
import 'package:grou/utils/app_time.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('AgendaItem.occursOn', () {
    // 3 November 2026 adalah hari Selasa.
    final start = DateTime(2026, 11, 3);

    test('sekali hanya pada tanggalnya', () {
      final item = AgendaItem(title: 'Ujian', date: start);
      expect(item.occursOn(start), isTrue);
      expect(item.occursOn(DateTime(2026, 11, 3, 23, 59)), isTrue, reason: 'jam diabaikan');
      expect(item.occursOn(DateTime(2026, 11, 4)), isFalse);
    });

    test('harian mulai tanggalnya sampai repeatUntil', () {
      final item = AgendaItem(title: 'Jalan pagi', date: start, repeat: AgendaRepeat.daily, repeatUntil: DateTime(2026, 11, 5));
      expect(item.occursOn(DateTime(2026, 11, 2)), isFalse);
      expect(item.occursOn(DateTime(2026, 11, 5)), isTrue, reason: 'repeatUntil inklusif');
      expect(item.occursOn(DateTime(2026, 11, 6)), isFalse);
    });

    test('mingguan pada hari yang dipilih', () {
      final item = AgendaItem(title: 'Gym', date: start, repeat: AgendaRepeat.weekly, repeatDays: const [2, 4]);
      expect(item.occursOn(DateTime(2026, 11, 5)), isTrue); // Kamis
      expect(item.occursOn(DateTime(2026, 11, 10)), isTrue); // Selasa berikutnya
      expect(item.occursOn(DateTime(2026, 11, 6)), isFalse); // Jumat
      expect(item.repeatLabel, 'Tiap Sel, Kam');
    });

    test('bulanan melewati bulan tanpa tanggal itu', () {
      final item = AgendaItem(title: 'Bayar kos', date: DateTime(2026, 1, 31), repeat: AgendaRepeat.monthly);
      expect(item.occursOn(DateTime(2026, 3, 31)), isTrue);
      expect(item.occursOn(DateTime(2026, 2, 28)), isFalse);
      expect(item.occursOn(DateTime(2026, 4, 30)), isFalse);
    });

    test('tahunan 29 Februari hanya di tahun kabisat', () {
      final item = AgendaItem(title: 'Ulang tahun', date: DateTime(2024, 2, 29), repeat: AgendaRepeat.yearly);
      expect(item.occursOn(DateTime(2028, 2, 29)), isTrue);
      expect(item.occursOn(DateTime(2027, 2, 28)), isFalse);
      expect(item.occursOn(DateTime(2027, 3, 1)), isFalse);
    });

    test('tersimpan dan terbaca ulang tanpa berubah', () {
      final item = AgendaItem(
        id: 7,
        title: 'Gym',
        note: 'Leg day',
        date: start,
        startTime: '18.00',
        endTime: '19.30',
        repeat: AgendaRepeat.weekly,
        repeatDays: const [2, 4],
        repeatUntil: DateTime(2026, 12, 31),
        reminderMinutes: 30,
      );
      expect(AgendaItem.fromMap(item.toMap()).toMap(), item.toMap());
    });
  });

  group('AgendaProvider', () {
    late AgendaProvider agenda;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      DatabaseHelper.pathOverride = inMemoryDatabasePath;
    });

    setUp(() async {
      AppTime.zone = AppTimeZone.wib;
      agenda = AgendaProvider();
      await agenda.load();
      for (final item in agenda.items) {
        await agenda.delete(item);
      }
    });

    test('selesai dan lewati dicatat per tanggal', () async {
      await agenda.save(AgendaItem(title: 'Gym', date: DateTime(2026, 11, 3), startTime: '18.00', repeat: AgendaRepeat.daily));
      final gym = agenda.items.single;
      final tue = DateTime(2026, 11, 3), wed = DateTime(2026, 11, 4);

      await agenda.toggleDone(gym, tue);
      expect(agenda.isDoneOn(gym, tue), isTrue);
      expect(agenda.isDoneOn(gym, wed), isFalse, reason: 'tanggal lain tidak ikut selesai');

      await agenda.skipOn(gym, wed);
      expect(agenda.itemsOn(wed), isEmpty);
      expect(agenda.itemsOn(DateTime(2026, 11, 5)), hasLength(1));

      await agenda.toggleDone(gym, tue);
      expect(agenda.isDoneOn(gym, tue), isFalse);
    });

    test('urutan: sepanjang hari dulu, lalu jam mulai', () async {
      final day = DateTime(2026, 11, 3);
      await agenda.save(AgendaItem(title: 'Rapat', date: day, startTime: '14.00'));
      await agenda.save(AgendaItem(title: 'Libur', date: day));
      await agenda.save(AgendaItem(title: 'Kuliah', date: day, startTime: '08.00'));
      expect(agenda.itemsOn(day).map((i) => i.title), ['Libur', 'Kuliah', 'Rapat']);
    });

    test('pengingat dihitung pada zona aplikasi dan melewati yang selesai', () async {
      AppTime.zone = AppTimeZone.wita; // UTC+8
      await agenda.save(AgendaItem(title: 'Rapat', date: DateTime(2026, 11, 3), startTime: '10.00', reminderMinutes: 15));
      await agenda.save(AgendaItem(title: 'Libur', date: DateTime(2026, 11, 4), reminderMinutes: -360));
      await agenda.save(AgendaItem(title: 'Gym', date: DateTime(2026, 11, 3), startTime: '18.00', repeat: AgendaRepeat.daily, reminderMinutes: 0));
      await agenda.save(AgendaItem(title: 'Tanpa pengingat', date: DateTime(2026, 11, 3), startTime: '12.00'));
      final gym = agenda.items.firstWhere((i) => i.title == 'Gym');
      await agenda.toggleDone(gym, DateTime(2026, 11, 3));

      // 3 November 08.00 WITA.
      final reminders = agenda.upcomingReminders(DateTime.utc(2026, 11, 3, 0));
      String at(String title) => reminders.firstWhere((r) => r.title == title).at.toIso8601String();

      expect(at('Rapat'), '2026-11-03T01:45:00.000Z', reason: '09.45 WITA');
      expect(at('Libur'), '2026-11-03T22:00:00.000Z', reason: '06.00 WITA tanggal 4');
      expect(reminders.where((r) => r.title == 'Gym').first.at, DateTime.utc(2026, 11, 4, 10),
          reason: 'Gym tanggal 3 sudah selesai, jadi yang pertama tanggal 4 pukul 18.00 WITA');
      expect(reminders.any((r) => r.title == 'Tanpa pengingat'), isFalse);
      expect(reminders.length, lessThanOrEqualTo(AgendaProvider.maxReminders));
      expect(reminders.every((r) => r.at.isAfter(DateTime.utc(2026, 11, 3, 0))), isTrue);
      for (var i = 1; i < reminders.length; i++) {
        expect(reminders[i].at.isBefore(reminders[i - 1].at), isFalse, reason: 'urut dari yang terdekat');
      }
    });

    test('pengingat yang sudah lewat tidak dijadwalkan', () async {
      await agenda.save(AgendaItem(title: 'Rapat', date: DateTime(2026, 11, 3), startTime: '10.00', reminderMinutes: 15));
      // 3 November 12.00 WIB, rapatnya sudah lewat.
      expect(agenda.upcomingReminders(DateTime.utc(2026, 11, 3, 5)), isEmpty);
    });

    test('menghapus agenda ikut menghapus status per tanggalnya', () async {
      await agenda.save(AgendaItem(title: 'Gym', date: DateTime(2026, 11, 3), repeat: AgendaRepeat.daily));
      final gym = agenda.items.single;
      await agenda.toggleDone(gym, DateTime(2026, 11, 3));
      await agenda.delete(gym);
      expect(agenda.items, isEmpty);
      expect(await DatabaseHelper.instance.agendaOccurrences(), isEmpty);
    });
  });
}
