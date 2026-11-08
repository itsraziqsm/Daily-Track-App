import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/agenda_item.dart';
import '../services/notification_service.dart';
import '../utils/app_time.dart';

/// State tab Agenda: daftar agenda, status per tanggal, dan pengingatnya.
class AgendaProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final NotificationService _notifications = NotificationService.instance;

  /// Pengingat agenda dijadwalkan sebagai notifikasi sekali-jalan untuk
  /// rentang ini, lalu diperbarui setiap kali aplikasi dibuka atau agenda
  /// berubah. Agenda berulang tanpa akhir tidak bisa dijadwalkan sekaligus,
  /// dan status selesai/dilewati per tanggal perlu ikut diperhitungkan.
  static const reminderWindowDays = 30;
  static const maxReminders = 60;

  List<AgendaItem> _items = [];
  Map<String, AgendaOccurrenceState> _occurrences = {};
  AppTimeZone? _zone;

  List<AgendaItem> get items => _items;

  Future<void> load() async {
    _items = await _db.allAgendaItems();
    _occurrences = await _db.agendaOccurrences();
    _zone = AppTime.zone;
    notifyListeners();
    await _syncReminders();
  }

  /// Dipanggil saat zona waktu aplikasi berubah: jam agenda tetap, tapi
  /// instan UTC pengingatnya bergeser.
  void onTimeZone(AppTimeZone zone) {
    if (_zone == null || zone == _zone) return;
    _zone = zone;
    _syncReminders();
  }

  static String _occurrenceKey(int itemId, DateTime day) => '$itemId|${AppTime.dateKey(day)}';

  AgendaOccurrenceState? stateOn(AgendaItem item, DateTime day) => _occurrences[_occurrenceKey(item.id, day)];

  bool isDoneOn(AgendaItem item, DateTime day) => stateOn(item, day) == AgendaOccurrenceState.done;

  /// Agenda yang muncul pada [day], tidak termasuk yang dilewati khusus
  /// tanggal itu. Yang sepanjang hari lebih dulu, lalu urut jam mulai.
  List<AgendaItem> itemsOn(DateTime day) {
    final list = _items
        .where((i) => i.occursOn(day) && stateOn(i, day) != AgendaOccurrenceState.skipped)
        .toList();
    list.sort((a, b) {
      if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
      return a.startMinutes.compareTo(b.startMinutes);
    });
    return list;
  }

  Future<void> save(AgendaItem item) async {
    await _db.saveAgendaItem(item);
    await load();
  }

  /// Menghapus agenda beserta seluruh pengulangannya.
  Future<void> delete(AgendaItem item) async {
    await _db.deleteAgendaItem(item.id);
    await load();
  }

  /// Menghapus satu kemunculan agenda berulang tanpa menyentuh tanggal lain.
  Future<void> skipOn(AgendaItem item, DateTime day) async {
    await _db.setAgendaOccurrence(item.id, AppTime.dateKey(day), AgendaOccurrenceState.skipped);
    await load();
  }

  Future<void> toggleDone(AgendaItem item, DateTime day) async {
    final done = isDoneOn(item, day);
    await _db.setAgendaOccurrence(item.id, AppTime.dateKey(day), done ? null : AgendaOccurrenceState.done);
    await load();
  }

  /// Meminta izin notifikasi sebelum menyimpan agenda berpengingat.
  /// Mengembalikan false bila izinnya ditolak.
  Future<bool> ensureReminderPermission() async {
    if (await _notifications.hasPermission()) return true;
    return _notifications.requestPermission();
  }

  Future<void> _syncReminders() => _notifications.setAgendaReminders(upcomingReminders(DateTime.now().toUtc()));

  /// Pengingat yang jatuh setelah [nowUtc], dalam [reminderWindowDays] hari ke
  /// depan menurut zona aplikasi, paling banyak [maxReminders] yang terdekat.
  /// Kemunculan yang sudah selesai atau dilewati tidak diingatkan.
  @visibleForTesting
  List<AgendaReminder> upcomingReminders(DateTime nowUtc) {
    final offset = AppTime.zone.offset;
    final todayLocal = nowUtc.add(offset);
    final out = <AgendaReminder>[];
    // Mulai dari kemarin: pengingat agenda sepanjang hari bisa jatuh pada
    // malam sebelumnya.
    for (var d = -1; d <= reminderWindowDays; d++) {
      final day = DateTime(todayLocal.year, todayLocal.month, todayLocal.day + d);
      for (final item in itemsOn(day)) {
        final before = item.reminderMinutes;
        if (before == null || isDoneOn(item, day)) continue;
        final at = DateTime.utc(day.year, day.month, day.day)
            .add(Duration(minutes: item.startMinutes - before))
            .subtract(offset);
        if (!at.isAfter(nowUtc)) continue;
        out.add(AgendaReminder(title: item.title, body: _reminderBody(item, before), at: at));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out.take(maxReminders).toList();
  }

  static String _reminderBody(AgendaItem item, int before) {
    if (item.isAllDay) return before > 0 ? 'Besok · sepanjang hari' : 'Hari ini · sepanjang hari';
    if (before == 0) return 'Mulai sekarang · ${item.timeLabel}';
    final lead = before % 60 == 0 ? '${before ~/ 60} jam' : '$before menit';
    return 'Mulai ${item.startTime} · $lead lagi';
  }
}
