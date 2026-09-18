enum LogStatus { done, skipped }

extension LogStatusValue on LogStatus {
  String get value => this == LogStatus.done ? 'done' : 'skipped';

  static LogStatus fromValue(String value) {
    return value == 'done' ? LogStatus.done : LogStatus.skipped;
  }
}

/// Catatan status harian sebuah [Activity] pada tanggal tertentu.
class DailyLog {
  final int? id;
  final int activityId;
  final String date; // format "yyyy-MM-dd"
  final LogStatus status;
  final String? reason;
  final DateTime timestamp;

  const DailyLog({
    this.id,
    required this.activityId,
    required this.date,
    required this.status,
    this.reason,
    required this.timestamp,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'activityId': activityId,
      'date': date,
      'status': status.value,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DailyLog.fromMap(Map<String, Object?> map) {
    return DailyLog(
      id: map['id'] as int?,
      activityId: map['activityId'] as int,
      date: map['date'] as String,
      status: LogStatusValue.fromValue(map['status'] as String),
      reason: map['reason'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  DailyLog copyWith({
    int? id,
    int? activityId,
    String? date,
    LogStatus? status,
    String? reason,
    DateTime? timestamp,
  }) {
    return DailyLog(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      date: date ?? this.date,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
