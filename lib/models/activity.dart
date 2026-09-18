/// Satu kegiatan di dalam sebuah template jadwal.
class Activity {
  final int id;
  final int templateId;
  final String startTime; // format "HH.mm", mis. "04.30"
  final String endTime;
  final String title;
  final String category;
  final int sortOrder;

  const Activity({
    required this.id,
    required this.templateId,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.category,
    this.sortOrder = 0,
  });

  String get timeRange => '$startTime - $endTime';

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(RegExp(r'[.:]'));
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String formatMinutes(int minutes) {
    final m = minutes % (24 * 60);
    return '${(m ~/ 60).toString().padLeft(2, '0')}.${(m % 60).toString().padLeft(2, '0')}';
  }

  int get startMinutes => _toMinutes(startTime);
  int get endMinutes => _toMinutes(endTime);

  /// Durasi kegiatan dalam menit (menangani kegiatan yang melewati tengah malam, mis. Tidur).
  int get durationMinutes {
    final diff = endMinutes - startMinutes;
    return diff >= 0 ? diff : diff + 24 * 60;
  }

  String get durationLabel {
    final m = durationMinutes;
    if (m < 60) return '$m mnt';
    final h = m ~/ 60;
    final rest = m % 60;
    return rest == 0 ? '$h jam' : '$h jam $rest mnt';
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'templateId': templateId,
        'startTime': startTime,
        'endTime': endTime,
        'title': title,
        'category': category,
        'sortOrder': sortOrder,
      };

  factory Activity.fromMap(Map<String, Object?> map) => Activity(
        id: map['id'] as int,
        templateId: map['templateId'] as int,
        startTime: map['startTime'] as String,
        endTime: map['endTime'] as String,
        title: map['title'] as String,
        category: map['category'] as String,
        sortOrder: (map['sortOrder'] as int?) ?? 0,
      );

  Activity copyWith({
    int? id,
    int? templateId,
    String? startTime,
    String? endTime,
    String? title,
    String? category,
    int? sortOrder,
  }) {
    return Activity(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      category: category ?? this.category,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
