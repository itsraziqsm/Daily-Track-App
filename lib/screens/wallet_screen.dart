import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/finance.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/number_format.dart';
import '../widgets/finance_sheets.dart';
import '../widgets/section_parts.dart';
import '../widgets/target_card.dart' show TargetProgressBar;

/// Halaman "Dompet Saya", dibuka dari tab Keuangan dengan menarik kartu
/// dompet: tabungan nyata dan proyeksinya, pengeluaran per kategori bulan
/// [month], serta rata-rata bulanan.
class WalletScreen extends StatelessWidget {
  final Month month;
  const WalletScreen({super.key, required this.month});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final finance = context.watch<FinanceProvider>();
    final avg = finance.average;
    final categories = finance.byCategory(month).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(month.start);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Dompet Saya',
          style: TextStyle(fontFamily: AppFonts.title, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: c.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
        children: [
          const SectionLabel('TABUNGAN'),
          _SavingsCard(finance: finance),
          const SizedBox(height: 22),
          SectionLabel('PER KATEGORI · ${monthLabel.toUpperCase()}', trailing: avg.months > 0 ? 'vs rata-rata' : null),
          if (categories.isEmpty) const SectionHint('Belum ada pengeluaran di bulan ini.'),
          for (final e in categories)
            _CategoryRow(
              category: e.key,
              amount: e.value,
              max: categories.first.value,
              average: avg.byCategory[e.key] ?? 0,
            ),
          const SizedBox(height: 22),
          const SectionLabel('RATA-RATA BULANAN'),
          _AverageCard(average: avg),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String category;
  final double amount;
  final double max;
  final double average;
  const _CategoryRow({required this.category, required this.amount, required this.max, required this.average});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(category, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.ink))),
              Text(formatRupiah(amount), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.ink)),
            ],
          ),
          const SizedBox(height: 5),
          TargetProgressBar(fraction: max <= 0 ? 0 : amount / max),
          const SizedBox(height: 3),
          Text(
            average > 0 ? 'Rata-rata ${formatRupiah(average)} / bulan' : 'Belum ada rata-rata',
            style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10.5, fontWeight: FontWeight.w600, color: c.inkMuted2),
          ),
        ],
      ),
    );
  }
}


class _AverageCard extends StatelessWidget {
  final MonthlyAverage average;
  const _AverageCard({required this.average});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = average;
    Widget line(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: strong ? FontWeight.w800 : FontWeight.w600, color: strong ? c.ink : c.inkMuted3))),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.ink)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line, width: 1.5), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a.provisional ? 'Perkiraan dari bulan berjalan — belum ada bulan yang selesai' : 'Dari ${a.months} bulan yang sudah selesai',
            style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted2),
          ),
          const SizedBox(height: 6),
          line('Pendapatan', formatRupiah(a.income)),
          line('Pengeluaran tetap', '−${formatRupiah(a.fixedExpense)}'),
          line('Pengeluaran tidak tetap', '−${formatRupiah(a.variableExpense)}'),
          Divider(height: 14, color: c.line),
          line('Sisa per bulan', formatRupiah(a.surplus), strong: true),
        ],
      ),
    );
  }
}


class _SavingsCard extends StatelessWidget {
  final FinanceProvider finance;
  const _SavingsCard({required this.finance});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final balance = finance.balance;
    final running = finance.summaryOf(finance.currentMonth).surplus;
    final projection = finance.projection();
    final perMonth = finance.average.surplus;
    final maxBalance = projection.map((p) => p.balance).fold(balance, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line, width: 1.5), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo saat ini', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, color: c.inkMuted)),
                    const SizedBox(height: 2),
                    Text(formatRupiah(balance), style: TextStyle(fontFamily: AppFonts.title, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: c.ink)),
                    Text(
                      'S.d. akhir bulan lalu · bulan ini ${running >= 0 ? '+' : ''}${formatRupiah(running)} berjalan',
                      style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted2),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => showAmountSheet(
                  context,
                  title: 'Saldo tabungan',
                  subtitle: 'Isi saldo tabungan nyata saat ini. Sisa tiap bulan berikutnya akan ditambahkan otomatis.',
                  initial: balance,
                  onSave: finance.setBalance,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(color: c.rowBg, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(11)),
                  child: Text('Atur saldo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.ink)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'PROYEKSI AKHIR TAHUN',
            style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: c.inkMuted),
          ),
          const SizedBox(height: 3),
          Text(
            perMonth > 0
                ? 'Bila sisa tetap ${formatRupiah(perMonth)} per bulan seperti rata-rata selama ini'
                : 'Dengan rata-rata saat ini sisa per bulan ${formatRupiah(perMonth)}, jadi tabungan tidak bertambah',
            style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted2, height: 1.35),
          ),
          const SizedBox(height: 10),
          for (final p in projection)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 44, child: Text('${p.year}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.ink))),
                  Expanded(child: TargetProgressBar(fraction: maxBalance <= 0 ? 0 : p.balance / maxBalance)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 86,
                    child: Text(formatRupiahShort(p.balance), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.ink)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
