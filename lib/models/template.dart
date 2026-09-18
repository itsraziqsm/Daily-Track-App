import 'activity.dart';

/// Satu template jadwal: sekumpulan kegiatan yang bisa ditugaskan ke hari-hari
/// tertentu dalam seminggu.
class Template {
  final int id;
  final String name;
  final List<Activity> activities;

  const Template({required this.id, required this.name, this.activities = const []});

  Template copyWith({int? id, String? name, List<Activity>? activities}) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      activities: activities ?? this.activities,
    );
  }

  /// Rentang jam template, mis. "04.30–22.00". Kosong bila belum ada kegiatan.
  String get rangeLabel {
    if (activities.isEmpty) return '-';
    return '${activities.first.startTime}–${activities.last.endTime}';
  }
}

/// Nama hari untuk penugasan template. Indeksnya mengikuti `DateTime.weekday`
/// (1 = Senin … 7 = Minggu).
const List<String> weekdayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

String weekdayName(int weekday) => weekdayNames[weekday - 1];

String weekdayShort(int weekday) => weekdayName(weekday).substring(0, 3);
