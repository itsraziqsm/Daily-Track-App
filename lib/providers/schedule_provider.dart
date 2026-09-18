import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/seed_activities.dart';
import '../db/database_helper.dart';
import '../models/activity.dart';
import '../models/daily_log.dart';

class ScheduleProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<Activity> activities = seedActivities;

  /// activityId -> DailyLog untuk tanggal berjalan.
  Map<int, DailyLog> _todayLogs = {};
  List<DailyLog> _skippedLogs = [];

  String get todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Map<int, DailyLog> get todayLogs => _todayLogs;
  List<DailyLog> get skippedLogs => _skippedLogs;

  int get doneCount => _todayLogs.values.where((l) => l.status == LogStatus.done).length;
  int get totalCount => activities.length;

  Future<void> loadToday() async {
    final logs = await _db.logsForDate(todayKey);
    _todayLogs = {for (final l in logs) l.activityId: l};
    notifyListeners();
  }

  Future<void> loadHistory() async {
    _skippedLogs = await _db.skippedLogs();
    notifyListeners();
  }

  Future<void> markDone(Activity activity) async {
    final log = DailyLog(
      activityId: activity.id,
      date: todayKey,
      status: LogStatus.done,
      timestamp: DateTime.now(),
    );
    await _db.upsertLog(log);
    _todayLogs[activity.id] = log;
    notifyListeners();
  }

  Future<void> markSkipped(Activity activity, String reason) async {
    final log = DailyLog(
      activityId: activity.id,
      date: todayKey,
      status: LogStatus.skipped,
      reason: reason,
      timestamp: DateTime.now(),
    );
    await _db.upsertLog(log);
    _todayLogs[activity.id] = log;
    notifyListeners();
    await loadHistory();
  }

  Future<void> clearStatus(Activity activity) async {
    await _db.deleteLogForActivityOnDate(activity.id, todayKey);
    _todayLogs.remove(activity.id);
    notifyListeners();
    await loadHistory();
  }

  Activity? activityById(int id) {
    for (final a in activities) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Kegiatan yang paling sering dibatalkan.
  String? get mostSkippedActivityTitle {
    if (_skippedLogs.isEmpty) return null;
    final counts = <int, int>{};
    for (final l in _skippedLogs) {
      counts[l.activityId] = (counts[l.activityId] ?? 0) + 1;
    }
    final topId = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return activityById(topId)?.title;
  }

  /// Alasan yang paling sering dipakai.
  String? get mostCommonReason {
    if (_skippedLogs.isEmpty) return null;
    final counts = <String, int>{};
    for (final l in _skippedLogs) {
      final r = l.reason ?? 'Lainnya';
      counts[r] = (counts[r] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
