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
}
