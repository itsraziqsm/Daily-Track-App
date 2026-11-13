import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/finance.dart';
import '../utils/app_time.dart';

/// Ringkasan satu bulan.
class MonthSummary {
  final Month month;
  final double salary;
  final double extraIncome;
  final double fixedExpense;
  final double variableExpense;

  const MonthSummary({required this.month, required this.salary, required this.extraIncome, required this.fixedExpense, required this.variableExpense});

  double get income => salary + extraIncome;
  double get expense => fixedExpense + variableExpense;

  /// Sisa bulan itu; negatif berarti pengeluaran melebihi pendapatan.
  double get surplus => income - expense;
}

/// Rata-rata bulanan dari bulan-bulan yang sudah selesai.
class MonthlyAverage {
  /// Berapa bulan yang dirata-ratakan.
  final int months;

  /// True bila belum ada bulan yang selesai, sehingga rata-ratanya memakai
  /// bulan berjalan sebagai perkiraan sementara.
  final bool provisional;
  final double income;
  final double fixedExpense;
  final double variableExpense;
  final Map<String, double> byCategory;

  const MonthlyAverage({
    required this.months,
    required this.provisional,
    required this.income,
    required this.fixedExpense,
    required this.variableExpense,
    required this.byCategory,
  });

  double get expense => fixedExpense + variableExpense;
  double get surplus => income - expense;
}

/// Perkiraan saldo tabungan pada akhir suatu tahun.
class SavingsProjection {
  final int year;
  final double balance;
  const SavingsProjection(this.year, this.balance);
}

/// State tab Keuangan: gaji, pemasukan lain, pengeluaran tetap dan tidak
/// tetap, saldo tabungan, dan proyeksinya.
class FinanceProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  static const _openingKey = 'savings.opening';
  static const _openingMonthKey = 'savings.openingMonth';

  /// Sumber tanggal hari ini; diganti di test.
  @visibleForTesting
  DateTime Function() clock = () {
    final n = AppTime.now();
    return DateTime(n.year, n.month, n.day);
  };

  /// Hari ini menurut zona aplikasi.
  DateTime get today => clock();

  List<SalaryChange> _salary = [];
  List<FinanceEntry> _entries = [];
  List<RecurringExpense> _recurring = [];
  double _opening = 0;
  Month? _openingMonth;

  Month get currentMonth => Month.of(today);
  List<RecurringExpense> get recurring => _recurring;

  /// Saldo tabungan yang diisi pengguna, beserta bulan berlakunya (saldo pada
  /// awal bulan itu). Null bila belum pernah diisi.
  double get openingBalance => _opening;
  Month? get openingMonth => _openingMonth;

  Future<void> load() async {
    _salary = await _db.salaryChanges();
    _entries = await _db.financeEntries();
    _recurring = await _db.recurringExpenses();
    _opening = double.tryParse(await _db.getSetting(_openingKey) ?? '') ?? 0;
    final m = await _db.getSetting(_openingMonthKey);
    _openingMonth = m == null ? null : Month.parse(m);
    notifyListeners();
  }

  // ---- Perubahan data ----

  /// Gaji baru berlaku mulai bulan ini; bulan-bulan sebelumnya tetap memakai
  /// gaji lama.
  Future<void> setSalary(double amount) async {
    await _db.setSalary(currentMonth, amount);
    await load();
  }

  Future<FinanceEntry> addEntry(FinanceEntry entry) async {
    final id = await _db.addFinanceEntry(entry);
    await load();
    return FinanceEntry(id: id, kind: entry.kind, date: entry.date, amount: entry.amount, category: entry.category, note: entry.note);
  }

  Future<void> updateEntry(FinanceEntry entry) async {
    await _db.updateFinanceEntry(entry);
    await load();
  }

  Future<void> deleteEntry(FinanceEntry entry) async {
    await _db.deleteFinanceEntry(entry.id);
    await load();
  }

  /// Menyimpan pengeluaran tetap. Bila jumlah atau kategorinya berubah
  /// sementara pengeluaran itu sudah berjalan sejak bulan lalu, baris lama
  /// diakhiri bulan lalu dan baris baru dimulai bulan ini — bulan-bulan yang
  /// sudah lewat tetap tercatat dengan angka lamanya.
  Future<void> saveRecurring(RecurringExpense e) async {
    final old = e.id == 0 ? null : _recurring.where((r) => r.id == e.id).firstOrNull;
    final now = currentMonth;
    final changed = old != null && (old.amount != e.amount || old.category != e.category);
    if (old != null && changed && old.from.isBefore(now)) {
      await _db.saveRecurringExpense(old.copyWith(until: now.plus(-1)));
      await _db.saveRecurringExpense(e.copyWith(id: 0, from: now, clearUntil: true));
    } else {
      await _db.saveRecurringExpense(e);
    }
    await load();
  }

  /// Menghentikan pengeluaran tetap mulai bulan ini. Bila baru dimulai bulan
  /// ini, barisnya dihapus saja.
  Future<void> stopRecurring(RecurringExpense e) async {
    final now = currentMonth;
    if (!e.from.isBefore(now)) {
      await _db.deleteRecurringExpense(e.id);
    } else {
      await _db.saveRecurringExpense(e.copyWith(until: now.plus(-1)));
    }
    await load();
  }

  /// Mengisi saldo tabungan nyata saat ini. Dianggap sebagai saldo pada awal
  /// bulan ini, jadi sisa bulan-bulan sebelumnya tidak dijumlahkan lagi.
  Future<void> setBalance(double amount) async {
    await _db.setSetting(_openingKey, '$amount');
    await _db.setSetting(_openingMonthKey, currentMonth.key);
    await load();
  }

  // ---- Perhitungan ----

  double salaryFor(Month m) {
    double amount = 0;
    for (final s in _salary) {
      if (!s.from.isAfter(m)) amount = s.amount;
    }
    return amount;
  }

  double get currentSalary => salaryFor(currentMonth);

  List<FinanceEntry> entriesIn(Month m, {FinanceEntryKind? kind}) =>
      _entries.where((e) => m.contains(e.date) && (kind == null || e.kind == kind)).toList();

  List<RecurringExpense> recurringIn(Month m) => _recurring.where((r) => r.activeIn(m)).toList();

  /// Pengeluaran tetap yang masih berjalan bulan ini.
  List<RecurringExpense> get activeRecurring => recurringIn(currentMonth);

  MonthSummary summaryOf(Month m) {
    double sum(Iterable<double> xs) => xs.fold(0.0, (a, b) => a + b);
    return MonthSummary(
      month: m,
      salary: salaryFor(m),
      extraIncome: sum(entriesIn(m, kind: FinanceEntryKind.income).map((e) => e.amount)),
      fixedExpense: sum(recurringIn(m).map((r) => r.amount)),
      variableExpense: sum(entriesIn(m, kind: FinanceEntryKind.expense).map((e) => e.amount)),
    );
  }

  /// Pengeluaran per kategori pada bulan [m], tetap dan tidak tetap digabung.
  Map<String, double> byCategory(Month m) {
    final out = <String, double>{};
    for (final r in recurringIn(m)) {
      out[r.category] = (out[r.category] ?? 0) + r.amount;
    }
    for (final e in entriesIn(m, kind: FinanceEntryKind.expense)) {
      final c = e.category ?? 'Lainnya';
      out[c] = (out[c] ?? 0) + e.amount;
    }
    return out;
  }

  /// Bulan pertama yang punya data keuangan apa pun; null bila belum ada.
  Month? get firstMonth {
    final months = [
      for (final s in _salary) s.from,
      for (final e in _entries) Month.of(e.date),
      for (final r in _recurring) r.from,
      if (_openingMonth != null) _openingMonth!,
    ];
    if (months.isEmpty) return null;
    return months.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Bulan-bulan yang sudah selesai sejak pencatatan dimulai.
  List<Month> get completedMonths {
    final first = firstMonth;
    if (first == null) return const [];
    final last = currentMonth.plus(-1);
    return [for (var m = first; !m.isAfter(last); m = m.plus(1)) m];
  }

  /// Rata-rata bulanan dari bulan yang sudah selesai; bila belum ada, bulan
  /// berjalan dipakai sebagai perkiraan sementara.
  MonthlyAverage get average {
    final completed = completedMonths;
    final months = completed.isEmpty ? [currentMonth] : completed;
    final n = months.length;
    final summaries = months.map(summaryOf).toList();
    final categories = <String, double>{};
    for (final m in months) {
      byCategory(m).forEach((k, v) => categories[k] = (categories[k] ?? 0) + v / n);
    }
    double avg(double Function(MonthSummary) f) => summaries.fold(0.0, (a, s) => a + f(s)) / n;
    return MonthlyAverage(
      months: n,
      provisional: completed.isEmpty,
      income: avg((s) => s.income),
      fixedExpense: avg((s) => s.fixedExpense),
      variableExpense: avg((s) => s.variableExpense),
      byCategory: categories,
    );
  }

  /// Saldo tabungan sampai akhir bulan lalu: saldo yang diisi, ditambah sisa
  /// tiap bulan yang sudah selesai sejak itu, dikurangi penarikan tabungan.
  double get balance {
    final start = _openingMonth ?? firstMonth;
    if (start == null) return 0;
    var total = _opening;
    for (var m = start; m.isBefore(currentMonth); m = m.plus(1)) {
      total += summaryOf(m).surplus;
    }
    total -= _entries
        .where((e) => e.kind == FinanceEntryKind.withdrawal && !Month.of(e.date).isBefore(start))
        .fold(0.0, (a, e) => a + e.amount);
    return total;
  }

  /// Perkiraan saldo pada akhir tiap tahun, mulai tahun ini sampai [years]
  /// tahun ke depan, bila sisa bulanan tetap seperti rata-rata selama ini.
  /// Bulan berjalan dihitung dengan rata-rata juga, karena belum selesai.
  List<SavingsProjection> projection({int years = 5}) {
    final perMonth = average.surplus;
    final now = currentMonth;
    return [
      for (var y = now.year; y <= now.year + years; y++)
        SavingsProjection(y, balance + perMonth * (Month(y, 12).monthsSince(now) + 1)),
    ];
  }

  /// Berapa bulan lagi sampai saldo mencapai [amount] dengan laju rata-rata;
  /// 0 bila sudah tercapai, null bila sisa bulanan tidak positif.
  int? monthsUntil(double amount) {
    final b = balance;
    if (b >= amount) return 0;
    final perMonth = average.surplus;
    if (perMonth <= 0) return null;
    return ((amount - b) / perMonth).ceil();
  }
}
