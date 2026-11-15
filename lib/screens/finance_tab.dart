import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/finance.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/number_format.dart';
import '../widgets/finance_sheets.dart';
import '../services/app_lock.dart';
import '../widgets/lock_screen.dart';
import '../widgets/section_parts.dart';
import 'wallet_screen.dart';

/// Tab "Keuangan" — pendapatan dan pengeluaran per bulan, rata-rata
/// historisnya, saldo tabungan, dan proyeksi tabungan per tahun.
class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  Month? _month;

  bool _walletButton = false;

  void _reveal() {
    HapticFeedback.mediumImpact();
    setState(() => _walletButton = true);
  }

  Future<void> _openWallet(Month month) async {
    if (!await ensureUnlocked(context, LockArea.wallet) || !mounted) return;
    setState(() => _walletButton = false);
    // Tetap dibungkus: bila aplikasi terkunci lagi saat halaman ini terbuka,
    // isinya ikut tertutup.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LockedArea(area: LockArea.wallet, page: true, child: WalletScreen(month: month)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final finance = context.watch<FinanceProvider>();
    final current = finance.currentMonth;
    final month = _month ?? current;
    final isCurrent = month == current;
    final summary = finance.summaryOf(month);
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
        // Tombol Dompet Saya muncul di atas dompet setelah dompet ditarik.
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          alignment: Alignment.topCenter,
          child: _walletButton
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WalletButton(onTap: () => _openWallet(month)),
                )
              : const SizedBox(width: double.infinity),
        ),
        // Dompet dan semua isi di bawahnya dalam satu kolom yang menggambar
        // dompet paling akhir: saat ditarik turun, dompet menimpa isi itu.
        _FrontFirstColumn(
          children: [
          _PullableWallet(
            onPulled: _reveal,
            child: _SummaryCard(
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
          ),
          if (!_walletButton)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.chevronsDown, size: 13, color: c.inkMuted2),
                  const SizedBox(width: 4),
                  Text(
                    'Tarik dompet ke bawah untuk Dompet Saya',
                    style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted2),
                  ),
                ],
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
          SectionLabel('PENGELUARAN TETAP', trailing: fixed.isEmpty ? null : formatRupiah(summary.fixedExpense)),
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
            const SectionHint('Tidak ada pengeluaran tetap di bulan ini.'),
          const SizedBox(height: 22),
          SectionLabel('TRANSAKSI', trailing: entries.isEmpty ? null : '${entries.length} catatan'),
          if (entries.isEmpty) const SectionHint('Belum ada transaksi di bulan ini.'),
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
          ],
        ),
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
            // Bulan berjalan: perkiraan sisa akhir bulan dari yang sudah
            // tercatat; bulan yang sudah lewat: sisa sebenarnya.
            isCurrent ? 'PROYEKSI $monthLabel'.toUpperCase() : 'SISA $monthLabel'.toUpperCase(),
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

class _WalletButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WalletButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.yellow, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.wallet, size: 18, color: c.yellowInk2),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dompet Saya', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.ink)),
                  Text(
                    'Tabungan, proyeksi, per kategori, rata-rata',
                    style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: c.inkMuted2),
          ],
        ),
      ),
    );
  }
}

/// Pengenal seret vertikal yang hanya mengklaim tarikan ke bawah. Bila jari
/// lebih dulu bergerak ke atas, ia mundur dari arena sehingga daftar di
/// belakangnya tetap bisa digulir seperti biasa.
class _DownwardDragRecognizer extends VerticalDragGestureRecognizer {
  _DownwardDragRecognizer({super.debugOwner});

  double _dy = 0;
  bool _decided = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _dy = 0;
    _decided = false;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_decided && event is PointerMoveEvent) {
      _dy += event.delta.dy;
      if (_dy < -1) {
        _decided = true;
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }
      if (_dy > 1) _decided = true;
    }
    super.handleEvent(event);
  }
}

/// Dompet yang bisa ditarik ke bawah seperti ketapel. Hanya kartunya yang
/// bergerak, dan selama ditarik ia digambar di lapisan atas sehingga menimpa
/// isi di bawahnya. Dilepas setelah melewati ambang memanggil [onPulled];
/// kartu lalu memantul kembali ke tempatnya.
class _PullableWallet extends StatefulWidget {
  final Widget child;
  final VoidCallback onPulled;
  const _PullableWallet({required this.child, required this.onPulled});

  @override
  State<_PullableWallet> createState() => _PullableWalletState();
}

class _PullableWalletState extends State<_PullableWallet> with SingleTickerProviderStateMixin {
  /// Geseran kartu yang harus dicapai agar tarikan dihitung.
  static const threshold = 64.0;

  /// Geseran terjauh; makin dekat ke sini, tarikan terasa makin berat.
  static const maxOffset = 150.0;

  late final _spring = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))
    ..addListener(() => setState(() {}));

  double _pulled = 0;
  double _releasedAt = 0;
  bool _dragging = false;
  bool _armed = false;

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  /// Geseran kartu dari jarak jari, dengan hambatan seperti karet.
  double get _dragOffset => maxOffset * (1 - math.exp(-_pulled / maxOffset));

  double get _offset {
    if (_dragging) return _dragOffset;
    if (!_spring.isAnimating) return 0;
    return _releasedAt * (1 - Curves.elasticOut.transform(_spring.value));
  }

  void _start(DragStartDetails _) {
    _spring.stop();
    setState(() {
      _dragging = true;
      _pulled = 0;
      _armed = false;
    });
  }

  void _update(DragUpdateDetails d) {
    if (!_dragging) return;
    setState(() => _pulled = math.max(0, _pulled + d.delta.dy));
    final armed = _dragOffset >= threshold;
    if (armed && !_armed) HapticFeedback.selectionClick();
    if (armed != _armed) setState(() => _armed = armed);
  }

  void _end([DragEndDetails? _]) {
    // onCancel juga datang untuk ketukan biasa yang tidak pernah menjadi
    // tarikan; itu tidak perlu dipantulkan.
    if (!_dragging) return;
    final fire = _armed;
    setState(() {
      _releasedAt = _dragOffset;
      _dragging = false;
      _armed = false;
    });
    _spring.forward(from: 0);
    if (fire) widget.onPulled();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final offset = _offset;
    return RawGestureDetector(
      gestures: {
        _DownwardDragRecognizer: GestureRecognizerFactoryWithHandlers<_DownwardDragRecognizer>(
          () => _DownwardDragRecognizer(debugOwner: this),
          (r) => r
            ..onStart = _start
            ..onUpdate = _update
            ..onEnd = _end
            ..onCancel = _end,
        ),
      },
      // Kartunya sendiri yang bergeser (tanpa salinan di lapisan lain), jadi
      // selalu tergambar; tempat aslinya tetap memegang ukuran.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (offset > 1)
            Positioned(
              left: 0,
              right: 0,
              top: 10,
              child: Opacity(
                opacity: (offset / 40).clamp(0.0, 1.0),
                child: _PullHint(armed: _armed, progress: (offset / threshold).clamp(0.0, 1.0)),
              ),
            ),
          Transform.translate(
            offset: Offset(0, offset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: offset <= 1
                    ? null
                    : [
                        BoxShadow(
                          color: c.shadow.withValues(alpha: (c.isDark ? 0.45 : 0.16) * (offset / maxOffset).clamp(0.0, 1.0)),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
              ),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kolom vertikal yang menggambar anak pertamanya paling akhir (dan
/// mengujinya paling dulu untuk sentuhan), supaya dompet yang digeser turun
/// tampil di atas isi di bawahnya.
class _FrontFirstColumn extends Flex {
  const _FrontFirstColumn({required super.children})
      : super(direction: Axis.vertical, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch);

  @override
  RenderFlex createRenderObject(BuildContext context) => _RenderFrontFirstFlex(
        direction: direction,
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: crossAxisAlignment,
        textDirection: getEffectiveTextDirection(context),
      );
}

class _RenderFrontFirstFlex extends RenderFlex {
  _RenderFrontFirstFlex({super.direction, super.mainAxisSize, super.crossAxisAlignment, super.textDirection});

  @override
  void paint(PaintingContext context, Offset offset) {
    final first = firstChild;
    if (first == null) return;
    var child = childAfter(first);
    while (child != null) {
      context.paintChild(child, (child.parentData! as FlexParentData).offset + offset);
      child = childAfter(child);
    }
    context.paintChild(first, (first.parentData! as FlexParentData).offset + offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final first = firstChild;
    if (first != null) {
      final hit = result.addWithPaintOffset(
        offset: (first.parentData! as FlexParentData).offset,
        position: position,
        hitTest: (result, transformed) => first.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return super.hitTestChildren(result, position: position);
  }
}

/// Petunjuk yang tampak di tempat asli dompet saat kartunya ditarik turun.
class _PullHint extends StatelessWidget {
  final bool armed;
  final double progress;
  const _PullHint({required this.armed, required this.progress});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            color: armed ? c.orange : c.inkMuted2,
            backgroundColor: c.lineSoft,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          armed ? 'Lepaskan untuk Dompet Saya' : 'Tarik untuk Dompet Saya',
          style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w700, color: armed ? c.orangeChipInk : c.inkMuted),
        ),
      ],
    );
  }
}
