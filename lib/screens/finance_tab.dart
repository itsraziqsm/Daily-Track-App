import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/finance.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/number_format.dart';
import '../widgets/finance_sheets.dart';
import '../widgets/target_card.dart' show TargetProgressBar;

/// Tab "Keuangan" — pendapatan dan pengeluaran per bulan, rata-rata
/// historisnya, saldo tabungan, dan proyeksi tabungan per tahun.
class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  Month? _month;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final finance = context.watch<FinanceProvider>();
    final current = finance.currentMonth;
    final month = _month ?? current;
    final isCurrent = month == current;
    final summary = finance.summaryOf(month);
    final avg = finance.average;
    final categories = finance.byCategory(month).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final entries = [
      ...finance.entriesIn(month, kind: FinanceEntryKind.expense),
      ...finance.entriesIn(month, kind: FinanceEntryKind.income),
      ...finance.entriesIn(month, kind: FinanceEntryKind.withdrawal),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final fixed = finance.recurringIn(month);
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(month.start);
    // Tanggal bawaan untuk catatan baru: hari ini di bulan berjalan, atau
    // tanggal 1 bulan yang sedang dilihat.
    final now = finance.today;
    final newEntryDate = isCurrent ? now : month.start;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      children: [
        Text('EXPENSES', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.inkMuted)),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text('Keuangan', style: TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.ink)),
            ),
            IconButton(
              tooltip: 'Bulan sebelumnya',
              icon: Icon(LucideIcons.chevronLeft, size: 20, color: c.orange),
              onPressed: () => setState(() => _month = month.plus(-1)),
            ),
            IconButton(
              tooltip: 'Bulan berikutnya',
              icon: Icon(LucideIcons.chevronRight, size: 20, color: isCurrent ? c.lineSoft : c.orange),
              onPressed: isCurrent ? null : () => setState(() => _month = month.plus(1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          monthLabel: monthLabel[0].toUpperCase() + monthLabel.substring(1),
          summary: summary,
          isCurrent: isCurrent,
          salary: finance.currentSalary,
          onEditSalary: () => showAmountSheet(
            context,
            title: 'Gaji bulanan',
            subtitle: 'Berlaku mulai bulan ini sampai diubah lagi. Bulan-bulan sebelumnya tetap memakai gaji lama.',
            initial: finance.currentSalary,
            onSave: finance.setSalary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: LucideIcons.minus,
                label: 'Pengeluaran',
                primary: true,
                onTap: () => showFinanceEntrySheet(context, kind: FinanceEntryKind.expense, date: newEntryDate),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: LucideIcons.plus,
                label: 'Pemasukan lain',
                onTap: () => showFinanceEntrySheet(context, kind: FinanceEntryKind.income, date: newEntryDate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        _Section('PER KATEGORI', trailing: avg.months > 0 ? 'vs rata-rata' : null),
        if (categories.isEmpty) const _Hint('Belum ada pengeluaran di bulan ini.'),
        for (final e in categories)
          _CategoryRow(
            category: e.key,
            amount: e.value,
            max: categories.first.value,
            average: avg.byCategory[e.key] ?? 0,
          ),
        const SizedBox(height: 22),
        _Section('PENGELUARAN TETAP', trailing: fixed.isEmpty ? null : formatRupiah(summary.fixedExpense)),
        for (final r in fixed)
          _Row(
            leading: r.category,
            title: r.title,
            amount: formatRupiah(r.amount),
            onTap: isCurrent ? () => showRecurringSheet(context, expense: r) : null,
          ),
        if (isCurrent)
          _AddRow(label: 'Tambah pengeluaran tetap', onTap: () => showRecurringSheet(context))
        else if (fixed.isEmpty)
          const _Hint('Tidak ada pengeluaran tetap di bulan ini.'),
        const SizedBox(height: 22),
        _Section('TRANSAKSI', trailing: entries.isEmpty ? null : '${entries.length} catatan'),
        if (entries.isEmpty) const _Hint('Belum ada transaksi di bulan ini.'),
        for (final e in entries)
          _Row(
            leading: DateFormat('d MMM', 'id_ID').format(e.date),
            title: switch (e.kind) {
              FinanceEntryKind.expense => e.note ?? e.category ?? 'Pengeluaran',
              FinanceEntryKind.income => e.note ?? 'Pemasukan lain',
              FinanceEntryKind.withdrawal => e.note ?? 'Penarikan tabungan',
            },
            subtitle: switch (e.kind) {
              FinanceEntryKind.expense => e.note == null ? null : e.category,
              FinanceEntryKind.income => 'Pemasukan',
              FinanceEntryKind.withdrawal => 'Dari tabungan',
            },
            amount: '${e.kind == FinanceEntryKind.income ? '+' : '−'}${formatRupiah(e.amount)}',
            positive: e.kind == FinanceEntryKind.income,
            onTap: e.kind == FinanceEntryKind.withdrawal ? null : () => showFinanceEntrySheet(context, kind: e.kind, date: e.date, entry: e),
          ),
        const SizedBox(height: 22),
        const _Section('RATA-RATA BULANAN'),
        _AverageCard(average: avg),
        const SizedBox(height: 22),
        const _Section('TABUNGAN'),
        _SavingsCard(finance: finance),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String monthLabel;
  final MonthSummary summary;
  final bool isCurrent;
  final double salary;
  final VoidCallback onEditSalary;

  const _SummaryCard({required this.monthLabel, required this.summary, required this.isCurrent, required this.salary, required this.onEditSalary});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = summary;
    final negative = s.surplus < 0;
    // Bagian pendapatan yang terpakai: tetap lalu tidak tetap, sisanya jalur.
    final base = s.income > 0 ? s.income : (s.expense > 0 ? s.expense : 1);
    final fixedPart = (s.fixedExpense / base).clamp(0.0, 1.0);
    final variablePart = (s.variableExpense / base).clamp(0.0, 1.0 - fixedPart);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: c.yellowBg,
        border: Border.all(color: c.yellowBorder, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCurrent ? 'SISA $monthLabel (BERJALAN)'.toUpperCase() : 'SISA $monthLabel'.toUpperCase(),
            style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: c.yellowInk3),
          ),
          const SizedBox(height: 4),
          Text(
            formatRupiah(s.surplus),
            style: TextStyle(fontFamily: AppFonts.title, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: negative ? c.orangeChipInk : c.ink),
          ),
          if (negative)
            Text('Pengeluaran melebihi pendapatan', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w700, color: c.orangeChipInk)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Figure(label: 'Pendapatan', value: formatRupiah(s.income), sub: s.extraIncome > 0 ? 'termasuk tambahan ${formatRupiahShort(s.extraIncome)}' : null)),
              Expanded(child: _Figure(label: 'Pengeluaran', value: formatRupiah(s.expense))),
            ],
          ),
          const SizedBox(height: 12),
          // Bar bertumpuk: tetap, celah 2px, tidak tetap, lalu sisa.
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 9,
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: c.track)),
                    Positioned(left: 0, top: 0, bottom: 0, width: box.maxWidth * fixedPart, child: ColoredBox(color: c.orange)),
                    if (variablePart > 0)
                      Positioned(
                        left: box.maxWidth * fixedPart + (fixedPart > 0 ? 2 : 0),
                        top: 0,
                        bottom: 0,
                        width: (box.maxWidth * variablePart - (fixedPart > 0 ? 2 : 0)).clamp(0.0, box.maxWidth),
                        child: ColoredBox(color: c.yellow),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Legend(color: c.orange, label: 'Tetap ${formatRupiahShort(s.fixedExpense)}'),
              _Legend(color: c.yellow, label: 'Tidak tetap ${formatRupiahShort(s.variableExpense)}'),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onEditSalary,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(LucideIcons.briefcase, size: 14, color: c.yellowInk2),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    salary > 0 ? 'Gaji ${formatRupiah(salary)} / bulan' : 'Isi gaji bulanan',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.yellowInk),
                  ),
                ),
                Text('Ubah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.orangeChipInk)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const _Figure({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, color: c.yellowInk3)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.ink)),
        if (sub != null) Text(sub!, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10.5, fontWeight: FontWeight.w600, color: c.yellowInk3)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.yellowInk3)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: primary ? c.orange : c.card,
          border: primary ? null : Border.all(color: c.line, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: primary ? Colors.white : c.inkMuted3),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primary ? Colors.white : c.inkMuted3)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  final String? trailing;
  const _Section(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Expanded(child: Text(text, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted))),
          if (trailing != null) Text(trailing!, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, color: c.inkMuted2)),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.inkMuted)),
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

class _Row extends StatelessWidget {
  final String leading;
  final String title;
  final String? subtitle;
  final String amount;
  final bool positive;
  final VoidCallback? onTap;

  const _Row({required this.leading, required this.title, this.subtitle, required this.amount, this.positive = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.lineSoft2),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Text(leading, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, color: c.inkMuted)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.ink)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(amount, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: positive ? c.yellowInk2 : c.ink)),
          ],
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.lineSoft, width: 1.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.plus, size: 15, color: c.inkMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.inkMuted)),
          ],
        ),
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
