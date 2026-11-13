import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grou/db/database_helper.dart';
import 'package:grou/models/finance.dart';
import 'package:grou/models/target.dart';
import 'package:grou/providers/finance_provider.dart';
import 'package:grou/providers/target_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late FinanceProvider finance;
  late TargetProvider targets;
  // Saldo awal Juli 10 jt, sisa 3 jt per bulan → 16 jt pada pertengahan September.
  final today = DateTime(2026, 9, 15);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    DatabaseHelper.pathOverride = inMemoryDatabasePath;
    await DatabaseHelper.instance.resetForTest();
    final db = DatabaseHelper.instance;
    await db.setSalary(const Month(2026, 7), 5000000);
    await db.setSetting('savings.opening', '10000000');
    await db.setSetting('savings.openingMonth', '2026-07');
    await db.saveRecurringExpense(const RecurringExpense(title: 'Kos', category: 'Tempat tinggal', amount: 2000000, from: Month(2026, 7)));
    finance = FinanceProvider()..clock = () => today;
    await finance.load();
    targets = TargetProvider()..finance = finance;
    await targets.load();
  });

  test('database v6 naik ke v7 tanpa kehilangan target lama', () async {
    // Database seperti yang terpasang sebelum target finansial ada.
    final path = '${Directory.systemTemp.createTempSync('grou_v6').path}/jadwal_harian.db';
    final old = await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(version: 6, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE targets (
          id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, title TEXT NOT NULL, unit TEXT,
          startValue REAL, targetValue REAL NOT NULL, period TEXT NOT NULL, deadline TEXT,
          createdAt TEXT NOT NULL, archived INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.insert('targets', {'kind': 'count', 'title': 'Baca buku', 'targetValue': 12, 'period': 'year', 'createdAt': '2026-01-01', 'archived': 0});
    }));
    await old.close();

    await DatabaseHelper.instance.resetForTest();
    DatabaseHelper.pathOverride = path;
    final migrated = await DatabaseHelper.instance.allTargets();
    expect(migrated.single.title, 'Baca buku');
    expect(migrated.single.isPurchased, isFalse);

    await DatabaseHelper.instance.saveTarget(migrated.single.copyWith(purchasedAt: DateTime(2026, 9, 1), purchaseEntryId: 7));
    expect((await DatabaseHelper.instance.allTargets()).single.purchaseEntryId, 7);
    await DatabaseHelper.instance.resetForTest();
  });

  Target finance_(double price, {DateTime? deadline}) =>
      Target(kind: TargetKind.finance, title: 'Laptop', targetValue: price, deadline: deadline, createdAt: DateTime(2026, 9, 1));

  test('saldo dibaca dari Keuangan', () {
    expect(finance.balance, 16000000);
    expect(targets.progressOf(finance_(8000000), today: today).current, 16000000);
  });

  test('dana sangat mencukupi bila sisa setelah beli ≥ 80% saldo, cukup bila di bawahnya', () {
    // 16 jt − 3,2 jt = 12,8 jt = tepat 80%.
    expect(targets.progressOf(finance_(3200000), today: today).status, TargetStatus.fundsAmple);
    expect(targets.progressOf(finance_(3300000), today: today).status, TargetStatus.fundsEnough);
    expect(targets.progressOf(finance_(16000000), today: today).status, TargetStatus.fundsEnough, reason: 'pas sama dengan saldo');
  });

  test('belum cukup: progres, perkiraan bulan, dan laju terhadap tenggat', () {
    final p = targets.progressOf(finance_(25000000), today: today);
    expect(p.fraction, closeTo(16 / 25, 1e-9));
    expect(p.monthsToGo, 3, reason: 'kurang 9 jt dengan sisa 3 jt per bulan');
    expect(p.status, TargetStatus.ongoing, reason: 'tanpa tenggat');

    expect(targets.progressOf(finance_(25000000, deadline: DateTime(2026, 12, 31)), today: today).status, TargetStatus.onTrack);
    expect(targets.progressOf(finance_(25000000, deadline: DateTime(2026, 11, 30)), today: today).status, TargetStatus.behind);
    expect(targets.progressOf(finance_(25000000, deadline: DateTime(2026, 9, 1)), today: today).status, TargetStatus.missed);
  });

  test('sudah dibeli: saldo berkurang lewat penarikan, target diarsipkan; bisa dibatalkan', () async {
    await targets.save(finance_(6000000));
    final laptop = targets.active.single;

    await targets.markPurchased(laptop);
    final bought = targets.archived.single;
    expect(bought.isPurchased, isTrue);
    expect(targets.progressOf(bought, today: today).status, TargetStatus.purchased);
    expect(finance.balance, 10000000);
    expect(finance.average.expense, 2000000, reason: 'pembelian tidak masuk rata-rata pengeluaran bulanan');
    expect(finance.entriesIn(const Month(2026, 9), kind: FinanceEntryKind.withdrawal).single.note, 'Laptop');

    await targets.undoPurchase(bought);
    expect(targets.active.single.isPurchased, isFalse);
    expect(finance.balance, 16000000);
    expect(finance.entriesIn(const Month(2026, 9), kind: FinanceEntryKind.withdrawal), isEmpty);
  });
}
