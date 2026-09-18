/// Kegiatan tetap dalam template jadwal harian (di-seed statis, tidak diedit lewat UI).
class Activity {
  final int id;
  final String startTime; // format "HH.mm", mis. "04.30"
  final String endTime;
  final String title;
  final String category;

  const Activity({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.category,
  });

  String get timeRange => '$startTime - $endTime';

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split('.');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
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
}
