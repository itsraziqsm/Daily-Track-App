/// Jenis target.
///
/// - [streak]: dihitung otomatis dari log harian — berapa hari berturut-turut
///   semua kegiatan selesai (terlambat tetap dihitung) tanpa pembatalan.
/// - [value]: angka yang dicatat manual menuju sebuah nilai, mis. berat badan
///   80 → 72 kg atau bench press 60 → 100 kg. Bisa naik atau turun.
/// - [count]: hitungan yang ditambah manual, mis. 12 buku setahun atau gym
///   3× seminggu; bisa direset per minggu/bulan/tahun.
enum TargetKind { streak, value, count }

extension TargetKindInfo on TargetKind {
  String get label => switch (this) {
        TargetKind.streak => 'Streak',
        TargetKind.value => 'Angka',
        TargetKind.count => 'Hitungan',
      };

  String get description => switch (this) {
        TargetKind.streak => 'Hari beruntun semua kegiatan selesai, dihitung otomatis',
        TargetKind.value => 'Catat angka menuju target, mis. berat badan atau beban gym',
        TargetKind.count => 'Tambah hitungan, mis. buku yang dibaca atau sesi gym',
      };
}

/// Rentang hitungan untuk target [TargetKind.count].
enum TargetPeriod { total, week, month, year }

extension TargetPeriodInfo on TargetPeriod {
  String get label => switch (this) {
        TargetPeriod.total => 'Total',
        TargetPeriod.week => 'Per minggu',
        TargetPeriod.month => 'Per bulan',
        TargetPeriod.year => 'Per tahun',
      };

  /// Akhiran untuk keterangan, mis. "3 sesi per minggu".
  String get suffix => switch (this) {
        TargetPeriod.total => '',
        TargetPeriod.week => ' per minggu',
        TargetPeriod.month => ' per bulan',
        TargetPeriod.year => ' per tahun',
      };

  /// Awal periode yang memuat [day]. Minggu dimulai hari Senin.
  DateTime startOf(DateTime day, DateTime createdAt) {
    final d = DateTime(day.year, day.month, day.day);
    return switch (this) {
      TargetPeriod.total => DateTime(createdAt.year, createdAt.month, createdAt.day),
      TargetPeriod.week => d.subtract(Duration(days: d.weekday - DateTime.monday)),
      TargetPeriod.month => DateTime(d.year, d.month),
      TargetPeriod.year => DateTime(d.year),
    };
  }

  /// Awal periode sesudah periode yang dimulai pada [start]; null untuk
  /// [total] yang tidak pernah berakhir.
  DateTime? nextStart(DateTime start) => switch (this) {
        TargetPeriod.total => null,
        TargetPeriod.week => DateTime(start.year, start.month, start.day + 7),
        TargetPeriod.month => DateTime(start.year, start.month + 1),
        TargetPeriod.year => DateTime(start.year + 1),
      };

  /// Awal periode sebelum periode yang dimulai pada [start].
  DateTime previousStart(DateTime start) => switch (this) {
        TargetPeriod.total => start,
        TargetPeriod.week => DateTime(start.year, start.month, start.day - 7),
        TargetPeriod.month => DateTime(start.year, start.month - 1),
        TargetPeriod.year => DateTime(start.year - 1),
      };
}

class Target {
  final int id;
  final TargetKind kind;
  final String title;

  /// Satuan untuk angka/hitungan, mis. "kg" atau "buku".
  final String? unit;

  /// Nilai awal target [TargetKind.value]; arah target (naik/turun) dibaca dari
  /// perbandingannya dengan [targetValue].
  final double? startValue;

  /// Angka yang dituju: nilai akhir, jumlah hitungan, atau panjang streak.
  final double targetValue;
  final TargetPeriod period;
  final DateTime? deadline;
  final DateTime createdAt;
  final bool archived;

  Target({
    this.id = 0,
    required this.kind,
    required this.title,
    this.unit,
    this.startValue,
    required this.targetValue,
    this.period = TargetPeriod.total,
    this.deadline,
    required this.createdAt,
    this.archived = false,
  });

  bool get isDecreasing => kind == TargetKind.value && (startValue ?? 0) > targetValue;

  Target copyWith({bool? archived}) => Target(
        id: id,
        kind: kind,
        title: title,
        unit: unit,
        startValue: startValue,
        targetValue: targetValue,
        period: period,
        deadline: deadline,
        createdAt: createdAt,
        archived: archived ?? this.archived,
      );

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'unit': unit,
        'startValue': startValue,
        'targetValue': targetValue,
        'period': period.name,
        'deadline': deadline == null ? null : _key(deadline!),
        'createdAt': _key(createdAt),
        'archived': archived ? 1 : 0,
      };

  factory Target.fromMap(Map<String, Object?> map) => Target(
        id: map['id'] as int,
        kind: TargetKind.values.byName(map['kind'] as String),
        title: map['title'] as String,
        unit: map['unit'] as String?,
        startValue: (map['startValue'] as num?)?.toDouble(),
        targetValue: (map['targetValue'] as num).toDouble(),
        period: TargetPeriod.values.byName(map['period'] as String),
        deadline: map['deadline'] == null ? null : DateTime.parse(map['deadline'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String),
        archived: (map['archived'] as int) == 1,
      );
}

/// Satu catatan manual: nilai terukur untuk target angka, atau tambahan
/// hitungan untuk target hitungan.
class TargetEntry {
  final int id;
  final int targetId;
  final DateTime date;
  final double value;
  final String? note;

  TargetEntry({this.id = 0, required this.targetId, required DateTime date, required this.value, this.note})
      : date = DateTime(date.year, date.month, date.day);

  Map<String, Object?> toMap() => {
        'id': id,
        'targetId': targetId,
        'date': Target._key(date),
        'value': value,
        'note': note,
      };

  factory TargetEntry.fromMap(Map<String, Object?> map) => TargetEntry(
        id: map['id'] as int,
        targetId: map['targetId'] as int,
        date: DateTime.parse(map['date'] as String),
        value: (map['value'] as num).toDouble(),
        note: map['note'] as String?,
      );
}
