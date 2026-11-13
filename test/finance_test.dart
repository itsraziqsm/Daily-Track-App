import 'package:flutter_test/flutter_test.dart';
import 'package:grou/db/database_helper.dart';
import 'package:grou/models/finance.dart';
import 'package:grou/providers/finance_provider.dart';
import 'package:grou/utils/number_format.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Month: urutan, selisih, dan pergantian tahun', () {
    expect(const Month(2026, 11).plus(2), const Month(2027, 1));
    expect(const Month(2026, 1).plus(-1), const Month(2025, 12));
    expect(const Month(2027, 1).monthsSince(const Month(2026, 11)), 2);
    expect(Month.parse('2026-03').key, '2026-03');
    expect(const Month(2026, 3).isBefore(const Month(2026, 4)), isTrue);
  });

  test('rupiah diketik dan ditampilkan gaya Indonesia', () {
    expect(parseRupiah('4.500.000'), 4500000);
    expect(parseRupiah('Rp 4.500.000'), 4500000);
    expect(parseRupiah(''), isNull);
    expect(formatRupiah(4500000), 'Rp4.500.000');
    expect(formatRupiahShort(45200000), 'Rp45,2 jt');
    expect(formatRupiahShort(1250000000), 'Rp1,3 M');
  });

  group('FinanceProvider', () {
    late FinanceProvider finance;
    var now = DateTime(2026, 9, 15);

    setUp(() async {
      // Database baru per test, supaya hitungan tidak bocor antar test.
      DatabaseHelper.pathOverride = inMemoryDatabasePath;
      await DatabaseHelper.instance.resetForTest();
      finance = FinanceProvider()..clock = () => now;
      await finance.load();
    });

    Future<void> expense(DateTime d, double amount, String category) =>
        finance.addEntry(FinanceEntry(kind: FinanceEntryKind.expense, date: d, amount: amount, category: category));

    test('gaji baru tidak mengubah bulan-bulan sebelumnya', () async {
      now = DateTime(2026, 7, 1);
      await finance.setSalary(5000000);
      now = DateTime(2026, 9, 15);
      await finance.setSalary(6000000);

      expect(finance.salaryFor(const Month(2026, 6)), 0);
      expect(finance.salaryFor(const Month(2026, 8)), 5000000);
      expect(finance.salaryFor(const Month(2026, 9)), 6000000);
      expect(finance.salaryFor(const Month(2027, 1)), 6000000, reason: 'berlaku sampai diubah');
    });

    test('ringkasan bulan: gaji + tambahan − tetap − tidak tetap, per kategori', () async {
      now = DateTime(2026, 9, 1);
      await finance.setSalary(6000000);
      await finance.saveRecurring(const RecurringExpense(title: 'Kos', category: 'Tempat tinggal', amount: 1500000, from: Month(2026, 9)));
      await finance.addEntry(FinanceEntry(kind: FinanceEntryKind.income, date: DateTime(2026, 9, 20), amount: 750000, note: 'Freelance'));
      await expense(DateTime(2026, 9, 3), 40000, 'Makan & minum');
      await expense(DateTime(2026, 9, 4), 60000, 'Makan & minum');
      await expense(DateTime(2026, 10, 1), 999999, 'Belanja'); // bulan lain

      final s = finance.summaryOf(const Month(2026, 9));
      expect(s.income, 6750000);
      expect(s.fixedExpense, 1500000);
      expect(s.variableExpense, 100000);
      expect(s.surplus, 5150000);
      expect(finance.byCategory(const Month(2026, 9)), {'Tempat tinggal': 1500000, 'Makan & minum': 100000});
    });

    test('mengubah pengeluaran tetap yang sudah berjalan tidak mengubah bulan lalu', () async {
      now = DateTime(2026, 7, 1);
      await finance.saveRecurring(const RecurringExpense(title: 'Kos', category: 'Tempat tinggal', amount: 1500000, from: Month(2026, 7)));
      now = DateTime(2026, 9, 10);
      await finance.saveRecurring(finance.recurring.single.copyWith(amount: 1700000));

      expect(finance.summaryOf(const Month(2026, 8)).fixedExpense, 1500000);
      expect(finance.summaryOf(const Month(2026, 9)).fixedExpense, 1700000);
      expect(finance.activeRecurring.single.amount, 1700000);

      // Ganti nama saja: diperbarui di tempat, tanpa baris baru.
      await finance.saveRecurring(finance.activeRecurring.single.copyWith(title: 'Kos Jl. Melati'));
      expect(finance.recurring, hasLength(2));

      await finance.stopRecurring(finance.activeRecurring.single);
      expect(finance.summaryOf(const Month(2026, 9)).fixedExpense, 0, reason: 'baru mulai bulan ini, jadi dihapus');
      expect(finance.summaryOf(const Month(2026, 8)).fixedExpense, 1500000);
    });

    test('rata-rata dari bulan yang sudah selesai saja, termasuk bulan tanpa pengeluaran', () async {
      now = DateTime(2026, 7, 1);
      await finance.setSalary(5000000);
      await expense(DateTime(2026, 7, 5), 1200000, 'Makan & minum');
      await expense(DateTime(2026, 8, 5), 1800000, 'Makan & minum');
      await expense(DateTime(2026, 8, 6), 300000, 'Transportasi');
      now = DateTime(2026, 9, 15);
      await expense(DateTime(2026, 9, 1), 9000000, 'Belanja'); // bulan berjalan, tidak dihitung

      final avg = finance.average;
      expect(avg.months, 2);
      expect(avg.provisional, isFalse);
      expect(avg.income, 5000000);
      expect(avg.variableExpense, 1650000);
      expect(avg.surplus, 3350000);
      expect(avg.byCategory, {'Makan & minum': 1500000, 'Transportasi': 150000});
    });

    test('tanpa bulan selesai, rata-rata memakai bulan berjalan sebagai perkiraan', () async {
      now = DateTime(2026, 9, 15);
      await finance.setSalary(5000000);
      await expense(DateTime(2026, 9, 2), 1000000, 'Makan & minum');
      final avg = finance.average;
      expect(avg.provisional, isTrue);
      expect(avg.months, 1);
      expect(avg.surplus, 4000000);
    });

    test('saldo: saldo awal + sisa bulan selesai − penarikan; proyeksi dan perkiraan waktu', () async {
      now = DateTime(2026, 7, 1);
      await finance.setBalance(10000000); // saldo awal Juli
      await finance.setSalary(5000000);
      await expense(DateTime(2026, 7, 5), 2000000, 'Makan & minum');
      await expense(DateTime(2026, 8, 5), 2000000, 'Makan & minum');
      now = DateTime(2026, 9, 15);
      await expense(DateTime(2026, 9, 5), 4000000, 'Belanja');

      expect(finance.balance, 16000000, reason: 'Juli dan Agustus masing-masing sisa 3 juta; September belum selesai');

      await finance.addEntry(FinanceEntry(kind: FinanceEntryKind.withdrawal, date: DateTime(2026, 9, 10), amount: 6000000, note: 'Laptop'));
      expect(finance.balance, 10000000);
      expect(finance.average.expense, 2000000, reason: 'penarikan tabungan tidak menaikkan rata-rata pengeluaran');

      // Sisa rata-rata 3 juta/bulan; September sampai Desember = 4 bulan.
      final p = finance.projection(years: 1);
      expect(p.map((x) => x.year), [2026, 2027]);
      expect(p.first.balance, 10000000 + 3000000 * 4);
      expect(p.last.balance, 10000000 + 3000000 * 16);

      expect(finance.monthsUntil(5000000), 0);
      expect(finance.monthsUntil(25000000), 5);
    });

    test('mengisi saldo nyata mengganti titik awal hitungan', () async {
      now = DateTime(2026, 7, 1);
      await finance.setSalary(5000000);
      now = DateTime(2026, 9, 15);
      expect(finance.balance, 10000000, reason: 'Juli + Agustus tanpa saldo awal');
      await finance.setBalance(7500000);
      expect(finance.balance, 7500000);
    });
  });
}
