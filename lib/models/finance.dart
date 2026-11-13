/// Bulan kalender, disimpan sebagai "yyyy-MM". Dipakai untuk semua
/// perhitungan keuangan, yang berjalan per bulan.
class Month implements Comparable<Month> {
  final int year;
  final int month;

  const Month(this.year, this.month);

  factory Month.of(DateTime d) => Month(d.year, d.month);

  factory Month.parse(String key) {
    final [y, m] = key.split('-');
    return Month(int.parse(y), int.parse(m));
  }

  /// Bulan ke-[n] sesudah (atau sebelum, bila negatif) bulan ini.
  Month plus(int n) {
    final index = year * 12 + (month - 1) + n;
    return Month(index ~/ 12, index % 12 + 1);
  }

  /// Jumlah bulan dari [other] ke bulan ini.
  int monthsSince(Month other) => (year * 12 + month) - (other.year * 12 + other.month);

  DateTime get start => DateTime(year, month);
  bool contains(DateTime d) => d.year == year && d.month == month;
  bool isBefore(Month other) => compareTo(other) < 0;
  bool isAfter(Month other) => compareTo(other) > 0;

  String get key => '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  @override
  int compareTo(Month other) => monthsSince(other);

  @override
  bool operator ==(Object other) => other is Month && other.year == year && other.month == month;

  @override
  int get hashCode => year * 12 + month;

  @override
  String toString() => key;
}

/// Kategori pengeluaran bawaan.
class ExpenseCategories {
  static const all = [
    'Makan & minum',
    'Transportasi',
    'Tempat tinggal',
    'Tagihan & utilitas',
    'Cicilan & utang',
    'Belanja',
    'Kesehatan',
    'Pendidikan',
    'Hiburan',
    'Keluarga & sosial',
    'Lainnya',
  ];
}

/// Perubahan gaji: [amount] per bulan berlaku mulai [from] sampai ada
/// perubahan berikutnya. Menyimpan riwayatnya membuat rata-rata bulan lalu
/// tidak ikut berubah saat gaji naik.
class SalaryChange {
  final Month from;
  final double amount;
  const SalaryChange(this.from, this.amount);
}

/// Jenis catatan keuangan satuan.
enum FinanceEntryKind {
  /// Pemasukan di luar gaji, mis. bonus atau freelance.
  income,

  /// Pengeluaran tidak tetap, dicatat per transaksi.
  expense,

  /// Penarikan dari tabungan, mis. membeli barang dari target finansial.
  /// Mengurangi saldo tanpa ikut menaikkan rata-rata pengeluaran bulanan.
  withdrawal,
}

class FinanceEntry {
  final int id;
  final FinanceEntryKind kind;
  final DateTime date;
  final double amount;
  final String? category;
  final String? note;

  FinanceEntry({this.id = 0, required this.kind, required DateTime date, required this.amount, this.category, this.note})
      : date = DateTime(date.year, date.month, date.day);

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind.name,
        'date': _key(date),
        'amount': amount,
        'category': category,
        'note': note,
      };

  factory FinanceEntry.fromMap(Map<String, Object?> map) => FinanceEntry(
        id: map['id'] as int,
        kind: FinanceEntryKind.values.byName(map['kind'] as String),
        date: DateTime.parse(map['date'] as String),
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String?,
        note: map['note'] as String?,
      );
}

/// Pengeluaran tetap: dihitung otomatis setiap bulan dari [from] sampai
/// [until] (inklusif; null berarti masih berjalan).
class RecurringExpense {
  final int id;
  final String title;
  final String category;
  final double amount;
  final Month from;
  final Month? until;

  const RecurringExpense({this.id = 0, required this.title, required this.category, required this.amount, required this.from, this.until});

  bool activeIn(Month m) => !m.isBefore(from) && (until == null || !m.isAfter(until!));

  RecurringExpense copyWith({int? id, String? title, String? category, double? amount, Month? from, Month? until, bool clearUntil = false}) =>
      RecurringExpense(
        id: id ?? this.id,
        title: title ?? this.title,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        from: from ?? this.from,
        until: clearUntil ? null : (until ?? this.until),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'fromMonth': from.key,
        'untilMonth': until?.key,
      };

  factory RecurringExpense.fromMap(Map<String, Object?> map) => RecurringExpense(
        id: map['id'] as int,
        title: map['title'] as String,
        category: map['category'] as String,
        amount: (map['amount'] as num).toDouble(),
        from: Month.parse(map['fromMonth'] as String),
        until: map['untilMonth'] == null ? null : Month.parse(map['untilMonth'] as String),
      );
}
