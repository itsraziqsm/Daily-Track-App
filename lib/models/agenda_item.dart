import 'activity.dart';

/// Pola pengulangan sebuah agenda.
enum AgendaRepeat { none, daily, weekly, monthly, yearly }

extension AgendaRepeatInfo on AgendaRepeat {
  String get label => switch (this) {
        AgendaRepeat.none => 'Sekali',
        AgendaRepeat.daily => 'Harian',
        AgendaRepeat.weekly => 'Mingguan',
        AgendaRepeat.monthly => 'Bulanan',
        AgendaRepeat.yearly => 'Tahunan',
      };

  static AgendaRepeat fromName(String? name) =>
      AgendaRepeat.values.firstWhere((r) => r.name == name, orElse: () => AgendaRepeat.none);
}

/// Status satu kemunculan agenda pada tanggal tertentu. Agenda berulang
/// menyimpannya per tanggal, jadi menandai selesai hari ini tidak ikut
/// menandai minggu depan.
enum AgendaOccurrenceState { done, skipped }

/// Acara atau rencana di tanggal tertentu, di luar rutinitas template.
///
/// Jam disimpan dalam format "HH.mm" seperti [Activity]; [startTime] null
/// berarti agenda sepanjang hari. Semua tanggal dan jam dibaca pada zona waktu
/// aplikasi (lihat `AppTime`).
class AgendaItem {
  final int id;
  final String title;
  final String? note;

  /// Tanggal pertama (atau satu-satunya) agenda ini, tanpa komponen jam.
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final AgendaRepeat repeat;

  /// Hari dalam seminggu untuk [AgendaRepeat.weekly], mengikuti
  /// `DateTime.weekday` (1 = Senin … 7 = Minggu).
  final List<int> repeatDays;

  /// Tanggal terakhir pengulangan (inklusif); null berarti tanpa akhir.
  final DateTime? repeatUntil;

  /// Pengingat sekian menit sebelum jam mulai. Untuk agenda sepanjang hari,
  /// dihitung dari pukul 00.00 — jadi -360 berarti pukul 06.00 pada harinya.
  /// Null berarti tanpa pengingat.
  final int? reminderMinutes;

  AgendaItem({
    this.id = 0,
    required this.title,
    this.note,
    required DateTime date,
    this.startTime,
    this.endTime,
    this.repeat = AgendaRepeat.none,
    this.repeatDays = const [],
    DateTime? repeatUntil,
    this.reminderMinutes,
  })  : date = _dateOnly(date),
        repeatUntil = repeatUntil == null ? null : _dateOnly(repeatUntil);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get isAllDay => startTime == null;
  bool get isRepeating => repeat != AgendaRepeat.none;

  /// Menit sejak tengah malam untuk jam mulai; 0 bila sepanjang hari.
  int get startMinutes => startTime == null ? 0 : Activity.parseMinutes(startTime!);

  String get timeLabel {
    if (startTime == null) return 'Seharian';
    return endTime == null ? startTime! : '$startTime–$endTime';
  }

  /// Apakah agenda ini muncul pada [day] (komponen jam diabaikan).
  bool occursOn(DateTime day) {
    final d = _dateOnly(day);
    if (d.isBefore(date)) return false;
    if (repeatUntil != null && d.isAfter(repeatUntil!)) return false;
    return switch (repeat) {
      AgendaRepeat.none => d == date,
      AgendaRepeat.daily => true,
      AgendaRepeat.weekly => repeatDays.contains(d.weekday),
      // Tanggal yang tidak ada di bulan itu (mis. 31) dilewati, bukan digeser
      // ke akhir bulan; begitu juga 29 Februari di tahun biasa.
      AgendaRepeat.monthly => d.day == date.day,
      AgendaRepeat.yearly => d.month == date.month && d.day == date.day,
    };
  }

  /// Keterangan pengulangan yang ringkas, mis. "Tiap Sen, Rab" atau
  /// "Tiap tanggal 5".
  String get repeatLabel {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return switch (repeat) {
      AgendaRepeat.none => 'Sekali',
      AgendaRepeat.daily => 'Tiap hari',
      AgendaRepeat.weekly => repeatDays.length == 7 ? 'Tiap hari' : 'Tiap ${([...repeatDays]..sort()).map((d) => days[d - 1]).join(', ')}',
      AgendaRepeat.monthly => 'Tiap tanggal ${date.day}',
      AgendaRepeat.yearly => 'Tiap ${date.day} ${months[date.month - 1]}',
    };
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'note': note,
        'date': _key(date),
        'startTime': startTime,
        'endTime': endTime,
        'repeat': repeat.name,
        'repeatDays': repeatDays.join(','),
        'repeatUntil': repeatUntil == null ? null : _key(repeatUntil!),
        'reminderMinutes': reminderMinutes,
      };

  factory AgendaItem.fromMap(Map<String, Object?> map) {
    final days = (map['repeatDays'] as String?) ?? '';
    return AgendaItem(
      id: map['id'] as int,
      title: map['title'] as String,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      startTime: map['startTime'] as String?,
      endTime: map['endTime'] as String?,
      repeat: AgendaRepeatInfo.fromName(map['repeat'] as String?),
      repeatDays: days.isEmpty ? const [] : days.split(',').map(int.parse).toList(),
      repeatUntil: map['repeatUntil'] == null ? null : DateTime.parse(map['repeatUntil'] as String),
      reminderMinutes: map['reminderMinutes'] as int?,
    );
  }
}
