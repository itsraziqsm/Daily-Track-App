import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/finance.dart';
import '../models/target.dart';
import '../utils/app_time.dart';
import 'finance_provider.dart';
import 'schedule_provider.dart';

/// Status sebuah target dibanding laju yang dibutuhkan.
enum TargetStatus {
  /// Angkanya sudah mencapai target.
  achieved,

  /// Sejauh ini sesuai laju menuju tenggat atau akhir periode.
  onTrack,

  /// Tertinggal dari laju yang dibutuhkan.
  behind,

  /// Tenggatnya lewat tanpa tercapai.
  missed,

  /// Tanpa tenggat atau periode, jadi tidak ada laju untuk dibandingkan.
  ongoing,

  /// Target finansial: saldo cukup, dan setelah membeli masih tersisa
  /// setidaknya [TargetProvider.ampleShare] dari saldo.
  fundsAmple,

  /// Target finansial: saldo cukup, tapi membeli akan memakan lebih dari
  /// seperlima saldo.
  fundsEnough,

  /// Target finansial yang sudah ditandai dibeli.
  purchased,
}

/// Progres target saat ini.
class TargetProgress {
  /// Nilai sekarang: angka terakhir, jumlah hitungan periode ini, atau
  /// panjang streak.
  final double current;

  /// 0–1, seberapa jauh dari titik awal menuju target.
  final double fraction;
  final TargetStatus status;

  /// Untuk streak: streak terpanjang sepanjang riwayat.
  final int? best;

  /// Untuk target finansial: perkiraan bulan sampai saldo mencukupi dengan
  /// sisa rata-rata per bulan; 0 bila sudah cukup, null bila sisa bulanan
  /// tidak positif sehingga tidak akan tercapai.
  final int? monthsToGo;

  const TargetProgress({required this.current, required this.fraction, required this.status, this.best, this.monthsToGo});
}

/// Jumlah hitungan pada satu periode, untuk riwayat target hitungan.
class PeriodTotal {
  final DateTime start;
  final double total;
  const PeriodTotal(this.start, this.total);
}

/// State tab Target: daftar target, catatannya, dan progresnya.
class TargetProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Selisih pecahan progres dari laju ideal yang masih dianggap sesuai jalur.
  static const paceSlack = 0.15;

  /// Bagian saldo yang masih tersisa setelah membeli agar dana dianggap
  /// "sangat mencukupi".
  static const ampleShare = 0.8;

  /// Sumber log harian untuk target streak; diisi oleh ProxyProvider.
  ScheduleProvider? schedule;

  /// Sumber saldo tabungan untuk target finansial; diisi oleh ProxyProvider.
  FinanceProvider? finance;

  List<Target> _targets = [];
  Map<int, List<TargetEntry>> _entries = {};

  List<Target> get active => _targets.where((t) => !t.archived).toList();
  List<Target> get archived => _targets.where((t) => t.archived).toList();

  Target? byId(int id) {
    for (final t in _targets) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Catatan sebuah target, urut tanggal lalu urutan pencatatan.
  List<TargetEntry> entriesOf(Target target) => _entries[target.id] ?? const [];

  Future<void> load() async {
    _targets = await _db.allTargets();
    final entries = await _db.allTargetEntries();
    _entries = {};
    for (final e in entries) {
      _entries.putIfAbsent(e.targetId, () => []).add(e);
    }
    notifyListeners();
  }

  Future<void> save(Target target) async {
    await _db.saveTarget(target);
    await load();
  }

  Future<void> delete(Target target) async {
    await _db.deleteTarget(target.id);
    await load();
  }

  Future<void> setArchived(Target target, bool archived) => save(target.copyWith(archived: archived));

  /// Menyimpan catatan dan mengembalikannya beserta id barunya, supaya bisa
  /// dibatalkan.
  Future<TargetEntry> addEntry(TargetEntry entry) async {
    final id = await _db.addTargetEntry(entry);
    await load();
    return TargetEntry(id: id, targetId: entry.targetId, date: entry.date, value: entry.value, note: entry.note);
  }

  Future<void> deleteEntry(TargetEntry entry) async {
    await _db.deleteTargetEntry(entry.id);
    await load();
  }

  static DateTime get _today {
    final n = AppTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  TargetProgress progressOf(Target target, {DateTime? today}) {
    final day = today ?? _today;
    switch (target.kind) {
      case TargetKind.streak:
        final current = (schedule?.completedStreak ?? 0).toDouble();
        final fraction = _fraction(current, target.targetValue);
        return TargetProgress(
          current: current,
          fraction: fraction,
          status: fraction >= 1 ? TargetStatus.achieved : _deadlineStatus(target, fraction, day),
          best: schedule?.bestCompletedStreak ?? 0,
        );
      case TargetKind.value:
        final entries = entriesOf(target);
        final start = target.startValue ?? 0;
        final current = entries.isEmpty ? start : entries.last.value;
        final span = target.targetValue - start;
        final fraction = span == 0 ? 1.0 : ((current - start) / span).clamp(0.0, 1.0);
        final reached = target.isDecreasing ? current <= target.targetValue : current >= target.targetValue;
        return TargetProgress(
          current: current,
          fraction: fraction,
          status: reached ? TargetStatus.achieved : _deadlineStatus(target, fraction, day),
        );
      case TargetKind.count:
        final current = totalInPeriodOf(target, day);
        final fraction = _fraction(current, target.targetValue);
        final TargetStatus status;
        if (fraction >= 1) {
          status = TargetStatus.achieved;
        } else if (target.period == TargetPeriod.total) {
          status = _deadlineStatus(target, fraction, day);
        } else {
          final start = target.period.startOf(day, target.createdAt);
          final end = target.period.nextStart(start)!;
          status = _paceStatus(fraction, start, end, day);
        }
        return TargetProgress(current: current, fraction: fraction, status: status);
      case TargetKind.finance:
        return _financeProgress(target, day);
    }
  }

  TargetProgress _financeProgress(Target target, DateTime day) {
    final price = target.targetValue;
    final balance = finance?.balance ?? 0;
    final fraction = _fraction(balance, price);
    final monthsToGo = finance?.monthsUntil(price);
    final TargetStatus status;
    if (target.isPurchased) {
      status = TargetStatus.purchased;
    } else if (balance >= price && balance > 0) {
      status = (balance - price) / balance >= ampleShare ? TargetStatus.fundsAmple : TargetStatus.fundsEnough;
    } else if (target.deadline == null) {
      status = TargetStatus.ongoing;
    } else if (day.isAfter(target.deadline!)) {
      status = TargetStatus.missed;
    } else {
      // Sesuai jalur bila dengan sisa rata-rata, saldo cukup paling lambat
      // di bulan tenggat.
      final monthsLeft = Month.of(target.deadline!).monthsSince(Month.of(day));
      status = monthsToGo != null && monthsToGo <= monthsLeft ? TargetStatus.onTrack : TargetStatus.behind;
    }
    return TargetProgress(current: balance, fraction: fraction, status: status, monthsToGo: monthsToGo);
  }

  /// Menandai target finansial sudah dibeli: harganya dicatat sebagai
  /// penarikan tabungan, lalu target dipindah ke arsip.
  Future<void> markPurchased(Target target) async {
    final now = finance!.today;
    final entry = await finance!.addEntry(FinanceEntry(
      kind: FinanceEntryKind.withdrawal,
      date: now,
      amount: target.targetValue,
      note: target.title,
    ));
    await save(target.copyWith(archived: true, purchasedAt: now, purchaseEntryId: entry.id));
  }

  /// Membatalkan tanda sudah dibeli: penarikannya dihapus dan target aktif
  /// lagi.
  Future<void> undoPurchase(Target target) async {
    if (target.purchaseEntryId != null) await finance!.deleteEntryById(target.purchaseEntryId!);
    await save(target.copyWith(archived: false, clearPurchase: true));
  }

  static double _fraction(double current, double goal) => goal <= 0 ? 1 : (current / goal).clamp(0.0, 1.0);

  TargetStatus _deadlineStatus(Target target, double fraction, DateTime day) {
    final deadline = target.deadline;
    if (deadline == null) return TargetStatus.ongoing;
    if (day.isAfter(deadline)) return TargetStatus.missed;
    final start = DateTime(target.createdAt.year, target.createdAt.month, target.createdAt.day);
    return _paceStatus(fraction, start, DateTime(deadline.year, deadline.month, deadline.day + 1), day);
  }

  /// Membandingkan progres dengan bagian waktu yang sudah lewat dari [start]
  /// sampai [end] (eksklusif). Hari ini dihitung sudah berjalan.
  static TargetStatus _paceStatus(double fraction, DateTime start, DateTime end, DateTime day) {
    final total = end.difference(start).inDays;
    if (total <= 0) return TargetStatus.ongoing;
    final elapsed = (day.difference(start).inDays + 1).clamp(0, total) / total;
    return fraction + paceSlack >= elapsed ? TargetStatus.onTrack : TargetStatus.behind;
  }

  /// Jumlah hitungan pada periode yang memuat [day].
  double totalInPeriodOf(Target target, DateTime day) {
    final start = target.period.startOf(day, target.createdAt);
    final end = target.period.nextStart(start);
    return _sum(target, start, end);
  }

  double _sum(Target target, DateTime start, DateTime? end) => entriesOf(target)
      .where((e) => !e.date.isBefore(start) && (end == null || e.date.isBefore(end)))
      .fold(0.0, (a, e) => a + e.value);

  /// Jumlah per periode untuk [count] periode terakhir, dari yang terlama.
  /// Tidak mundur melewati periode tempat target dibuat.
  List<PeriodTotal> periodHistory(Target target, {int count = 6, DateTime? today}) {
    if (target.period == TargetPeriod.total) return const [];
    final created = target.period.startOf(target.createdAt, target.createdAt);
    var start = target.period.startOf(today ?? _today, target.createdAt);
    final out = <PeriodTotal>[];
    while (out.length < count && !start.isBefore(created)) {
      out.add(PeriodTotal(start, _sum(target, start, target.period.nextStart(start))));
      start = target.period.previousStart(start);
    }
    return out.reversed.toList();
  }
}
