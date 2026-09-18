import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/seed_activities.dart';
import '../db/database_helper.dart';
import '../models/activity.dart';
import '../models/daily_log.dart';
import '../utils/app_time.dart';

class ScheduleProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<Activity> activities = seedActivities;

  /// Kegiatan yang dicentang lebih dari sekian menit setelah rentang waktunya
  /// usai dihitung terlambat.
  static const int toleranceMinutes = 35;

  /// Jendela kegiatan aktif bergeser mengikuti jam, jadi tampilan perlu
  /// menyegarkan diri tanpa interaksi pengguna.
  Timer? _ticker;

  ScheduleProvider() {
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Map<int, DailyLog> _todayLogs = {};
  List<DailyLog> _allLogs = [];

  final Map<String, bool> notificationPrefs = {
    'each': true,
    'morning': true,
    'night': false,
  };

  String get todayKey => AppTime.dateKey(AppTime.now());

  Map<int, DailyLog> get todayLogs => _todayLogs;
  List<DailyLog> get allLogs => _allLogs;
  List<DailyLog> get cancelledLogs =>
      _allLogs.where((l) => l.status == LogStatus.cancelled).toList();

  int get doneCount =>
      _todayLogs.values.where((l) => l.status != LogStatus.cancelled).length;
  int get lateCount =>
      _todayLogs.values.where((l) => l.status == LogStatus.late).length;
  int get onTimeCount =>
      _todayLogs.values.where((l) => l.status == LogStatus.done).length;
  int get cancelledTodayCount =>
      _todayLogs.values.where((l) => l.status == LogStatus.cancelled).length;
  int get totalCount => activities.length;

  AppTimeZone get timeZone => AppTime.zone;

  /// Mengganti zona waktu: tersimpan, lalu log hari ini dimuat ulang karena
  /// batas "hari ini" bisa ikut bergeser.
  Future<void> setTimeZone(AppTimeZone zone) async {
    if (zone == AppTime.zone) return;
    AppTime.zone = zone;
    await _db.setSetting(_timeZoneKey, zone.name);
    await load();
  }

  static const _timeZoneKey = 'timeZone';

  Future<void> load() async {
    AppTime.zone = AppTimeZoneInfo.fromName(await _db.getSetting(_timeZoneKey));
    final logs = await _db.logsForDate(todayKey);
    _todayLogs = {for (final l in logs) l.activityId: l};
    _allLogs = await _db.allLogs();
    notifyListeners();
  }

  /// Kegiatan sedang berlangsung: jam sekarang (menurut zona aktif) berada di
  /// dalam rentang mulai–selesai. Hanya kegiatan inilah yang menampilkan aksi.
  bool isRunning(Activity activity) {
    final now = AppTime.minutesOfDay();
    final start = activity.startMinutes;
    final end = activity.endMinutes;
    if (end > start) return now >= start && now < end;
    // Rentang melewati tengah malam, mis. Tidur 22.00–04.30.
    return now >= start || now < end;
  }

  /// Menit berlalu sejak rentang kegiatan usai. Negatif berarti rentangnya
  /// belum selesai (atau belum dimulai) hari ini.
  int minutesSinceEnd(Activity activity) => AppTime.minutesOfDay() - activity.endMinutes;

  /// Rentang kegiatan sudah usai lebih dari jendela toleransi. Kegiatan yang
  /// masih berlangsung tidak pernah termasuk — ini sekaligus menjaga kegiatan
  /// lintas tengah malam (mis. Tidur 22.00–04.30), yang jam usainya secara
  /// angka berada di belakang jam sekarang.
  bool isPastGrace(Activity activity) =>
      !isRunning(activity) && minutesSinceEnd(activity) > toleranceMinutes;

  /// Kegiatan yang sudah ditandai dan sudah lewat masa toleransi tidak bisa
  /// diubah lagi — catatannya dianggap final.
  bool isLocked(Activity activity) =>
      _todayLogs.containsKey(activity.id) && isPastGrace(activity);

  /// Tandai kegiatan: otomatis "selesai" atau "terlambat" berdasarkan jendela toleransi.
  Future<void> toggle(Activity activity) async {
    if (isLocked(activity)) return;
    final existing = _todayLogs[activity.id];
    if (existing != null) {
      await _db.deleteLogForActivityOnDate(activity.id, todayKey);
      _todayLogs.remove(activity.id);
      _allLogs.removeWhere((l) => l.activityId == activity.id && l.date == todayKey);
      notifyListeners();
      return;
    }
    final late = isPastGrace(activity);
    final log = DailyLog(
      activityId: activity.id,
      date: todayKey,
      status: late ? LogStatus.late : LogStatus.done,
      timestamp: AppTime.now(),
    );
    await _db.upsertLog(log);
    _todayLogs[activity.id] = log;
    _allLogs.insert(0, log);
    notifyListeners();
  }

  Future<void> markCancelled(Activity activity, String reason) async {
    final log = DailyLog(
      activityId: activity.id,
      date: todayKey,
      status: LogStatus.cancelled,
      reason: reason,
      timestamp: AppTime.now(),
    );
    await _db.upsertLog(log);
    _todayLogs[activity.id] = log;
    _allLogs.insert(0, log);
    notifyListeners();
  }

  Activity? activityById(int id) {
    for (final a in activities) {
      if (a.id == id) return a;
    }
    return null;
  }

  void toggleNotification(String key) {
    notificationPrefs[key] = !(notificationPrefs[key] ?? false);
    notifyListeners();
  }

  // ---- Statistik & kalender ----

  Map<String, List<DailyLog>> get logsByDate {
    final map = <String, List<DailyLog>>{};
    for (final l in _allLogs) {
      map.putIfAbsent(l.date, () => []).add(l);
    }
    return map;
  }

  /// Hari "sempurna": semua kegiatan tercatat pada hari itu selesai tepat waktu (tanpa terlambat/batal).
  bool _isPerfectDay(List<DailyLog> logs) {
    if (logs.isEmpty) return false;
    return logs.every((l) => l.status == LogStatus.done) && logs.length >= totalCount;
  }

  bool dayHasLate(List<DailyLog> logs) => logs.any((l) => l.status == LogStatus.late);
  bool dayHasCancelled(List<DailyLog> logs) => logs.any((l) => l.status == LogStatus.cancelled);

  /// Jumlah hari sempurna berturut-turut, dihitung mundur dari kemarin.
  int get perfectStreak {
    final byDate = logsByDate;
    var streak = 0;
    var day = AppTime.now().subtract(const Duration(days: 1));
    while (true) {
      final key = AppTime.dateKey(day);
      final logs = byDate[key];
      if (logs == null || !_isPerfectDay(logs)) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Persentase kegiatan selesai (termasuk terlambat) untuk 7 hari terakhir termasuk hari ini.
  List<MapEntry<DateTime, double>> get last7DaysCompletion {
    final byDate = logsByDate;
    final out = <MapEntry<DateTime, double>>[];
    for (var i = 6; i >= 0; i--) {
      final day = AppTime.now().subtract(Duration(days: i));
      final logs = byDate[AppTime.dateKey(day)] ?? [];
      final completed = logs.where((l) => l.status != LogStatus.cancelled).length;
      final pct = totalCount == 0 ? 0.0 : completed / totalCount;
      out.add(MapEntry(day, pct));
    }
    return out;
  }

  double get weekDisciplinePct {
    final days = last7DaysCompletion;
    if (days.isEmpty) return 0;
    final sum = days.fold<double>(0, (a, b) => a + b.value);
    return sum / days.length;
  }

  String? get mostCancelledActivityTitle {
    final cancelled = cancelledLogs;
    if (cancelled.isEmpty) return null;
    final counts = <int, int>{};
    for (final l in cancelled) {
      counts[l.activityId] = (counts[l.activityId] ?? 0) + 1;
    }
    final topId = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return activityById(topId)?.title;
  }

  List<MapEntry<String, int>> get reasonRanking {
    final counts = <String, int>{};
    for (final l in cancelledLogs) {
      final r = l.reason ?? 'Lainnya';
      counts[r] = (counts[r] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  String? get mostCommonReason => reasonRanking.isEmpty ? null : reasonRanking.first.key;
}
