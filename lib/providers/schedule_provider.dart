import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/seed_activities.dart';
import '../db/database_helper.dart';
import '../models/activity.dart';
import '../models/daily_log.dart';

class ScheduleProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<Activity> activities = seedActivities;

  /// Kegiatan dicentang setelah lewat sekian menit dari jam mulai dihitung terlambat.
  static const int toleranceMinutes = 35;

  Map<int, DailyLog> _todayLogs = {};
  List<DailyLog> _allLogs = [];

  final Map<String, bool> notificationPrefs = {
    'each': true,
    'morning': true,
    'night': false,
  };

  String get todayKey => _dateKey(DateTime.now());
  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  int get _nowMinutes => DateTime.now().hour * 60 + DateTime.now().minute;

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

  Future<void> load() async {
    final logs = await _db.logsForDate(todayKey);
    _todayLogs = {for (final l in logs) l.activityId: l};
    _allLogs = await _db.allLogs();
    notifyListeners();
  }

  bool isActive(Activity activity) {
    if (_todayLogs.containsKey(activity.id)) return false;
    return (_nowMinutes - activity.startMinutes).abs() <= 90;
  }

  /// Tandai kegiatan: otomatis "selesai" atau "terlambat" berdasarkan jendela toleransi.
  Future<void> toggle(Activity activity) async {
    final existing = _todayLogs[activity.id];
    if (existing != null) {
      await _db.deleteLogForActivityOnDate(activity.id, todayKey);
      _todayLogs.remove(activity.id);
      _allLogs.removeWhere((l) => l.activityId == activity.id && l.date == todayKey);
      notifyListeners();
      return;
    }
    final late = _nowMinutes - activity.startMinutes > toleranceMinutes;
    final log = DailyLog(
      activityId: activity.id,
      date: todayKey,
      status: late ? LogStatus.late : LogStatus.done,
      timestamp: DateTime.now(),
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
      timestamp: DateTime.now(),
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
    var day = DateTime.now().subtract(const Duration(days: 1));
    while (true) {
      final key = _dateKey(day);
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
      final day = DateTime.now().subtract(Duration(days: i));
      final logs = byDate[_dateKey(day)] ?? [];
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
