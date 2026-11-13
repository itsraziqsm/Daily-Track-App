import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/target.dart';
import '../providers/target_provider.dart';
import '../theme/app_theme.dart';
import '../utils/number_format.dart';

extension TargetIcon on Target {
  IconData get icon => switch (kind) {
        TargetKind.streak => LucideIcons.flame,
        TargetKind.value => isDecreasing ? LucideIcons.trendingDown : LucideIcons.trendingUp,
        TargetKind.count => LucideIcons.listPlus,
        TargetKind.finance => LucideIcons.piggyBank,
      };
}

/// Angka dengan satuannya, mis. "72,5 kg" atau "7 buku".
String withUnit(double value, String? unit) => unit == null ? formatNumber(value) : '${formatNumber(value)} $unit';

/// Keterangan singkat target: rentang, periode, dan tenggat.
String targetSummary(Target t) {
  final parts = <String>[
    switch (t.kind) {
      TargetKind.streak => '${formatNumber(t.targetValue)} hari beruntun',
      TargetKind.value => '${withUnit(t.startValue ?? 0, t.unit)} → ${withUnit(t.targetValue, t.unit)}',
      TargetKind.count => '${withUnit(t.targetValue, t.unit)}${t.period.suffix}',
      TargetKind.finance => 'butuh ${formatRupiah(t.targetValue)}',
    },
    if (t.deadline != null) 'tenggat ${DateFormat('d MMM yyyy', 'id_ID').format(t.deadline!)}',
  ];
  return parts.join(' · ');
}

/// Keterangan target finansial: sisa saldo setelah membeli bila dananya sudah
/// cukup, atau perkiraan kapan cukup dengan sisa rata-rata per bulan.
String financeOutlook(Target t, TargetProgress p, DateTime today) {
  final balance = p.current;
  if (balance >= t.targetValue && balance > 0) {
    final left = balance - t.targetValue;
    return 'Sisa setelah beli ${formatRupiah(left)} (${(left / balance * 100).round()}% saldo)';
  }
  final months = p.monthsToGo;
  if (months == null) return 'Belum terkejar: sisa rata-rata per bulan belum positif';
  final when = DateFormat('MMMM yyyy', 'id_ID').format(DateTime(today.year, today.month + months));
  return 'Perkiraan cukup $months bulan lagi · $when';
}

/// Kartu target untuk tab Target: judul, status, angka saat ini, dan bar
/// progres. [action] tampil di kanan bawah, mis. tombol +1.
class TargetCard extends StatelessWidget {
  final Target target;
  final TargetProgress progress;
  final VoidCallback onTap;
  final Widget? action;

  const TargetCard({super.key, required this.target, required this.progress, required this.onTap, this.action});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = target;
    final (current, of) = switch (t.kind) {
      TargetKind.streak => ('${formatNumber(progress.current)} hari', 'dari ${formatNumber(t.targetValue)}'),
      TargetKind.value => (withUnit(progress.current, t.unit), 'target ${withUnit(t.targetValue, t.unit)}'),
      TargetKind.count => (formatNumber(progress.current), 'dari ${withUnit(t.targetValue, t.unit)}${t.period.suffix}'),
      TargetKind.finance => t.isPurchased
          ? (formatRupiahShort(t.targetValue), 'dibeli ${DateFormat('d MMM yyyy', 'id_ID').format(t.purchasedAt!)}')
          : (formatRupiahShort(progress.current), 'saldo dari ${formatRupiahShort(t.targetValue)}'),
    };
    final highlighted = const {TargetStatus.achieved, TargetStatus.fundsAmple, TargetStatus.fundsEnough}.contains(progress.status);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: highlighted ? c.yellowBg : c.card,
          border: Border.all(color: highlighted ? c.yellowBorder : c.line, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.yellowChipBg, borderRadius: BorderRadius.circular(11)),
                  child: Icon(t.icon, size: 17, color: c.yellowInk2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: c.ink)),
                      const SizedBox(height: 2),
                      Text(
                        targetSummary(t),
                        style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted),
                      ),
                      // Di bawah judul, bukan di sampingnya, supaya status
                      // yang panjang tidak memeras judul.
                      const SizedBox(height: 6),
                      TargetStatusChip(status: progress.status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(current, style: TextStyle(fontFamily: AppFonts.title, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: c.ink, height: 1)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(of, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkMuted)),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 11),
            TargetProgressBar(fraction: t.isPurchased ? 1 : progress.fraction),
            if (t.kind == TargetKind.finance && !t.isPurchased) ...[
              const SizedBox(height: 8),
              Text(
                financeOutlook(t, progress, DateTime.now()),
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted2, height: 1.35),
              ),
            ],
            if (progress.best != null) ...[
              const SizedBox(height: 8),
              Text(
                'Rekor terpanjang ${progress.best} hari',
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TargetProgressBar extends StatelessWidget {
  final double fraction;
  const TargetProgressBar({super.key, required this.fraction});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: c.lineSoft2)),
            TweenAnimationBuilder<double>(
              tween: Tween(end: fraction.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                child: DecoratedBox(decoration: BoxDecoration(color: c.yellow, borderRadius: BorderRadius.circular(99))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status target sebagai label berikon — tidak mengandalkan warna saja.
class TargetStatusChip extends StatelessWidget {
  final TargetStatus status;
  const TargetStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (label, icon, bg, ink) = switch (status) {
      TargetStatus.achieved => ('Tercapai', LucideIcons.check, c.yellowChipBg, c.yellowInk),
      TargetStatus.onTrack => ('Sesuai jalur', LucideIcons.trendingUp, c.rowBg, c.inkMuted3),
      TargetStatus.behind => ('Perlu dikejar', LucideIcons.triangleAlert, c.orangeChipBg, c.orangeChipInk),
      TargetStatus.missed => ('Lewat tenggat', LucideIcons.clock, c.orangeChipBg, c.orangeChipInk),
      TargetStatus.ongoing => ('Berjalan', LucideIcons.circleDot, c.rowBg, c.inkMuted3),
      TargetStatus.fundsAmple => ('Dana sangat mencukupi', LucideIcons.circleCheckBig, c.yellowChipBg, c.yellowInk),
      TargetStatus.fundsEnough => ('Dana cukup', LucideIcons.check, c.yellowChipBg, c.yellowInk2),
      TargetStatus.purchased => ('Sudah dibeli', LucideIcons.shoppingBag, c.rowBg, c.inkMuted3),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ink),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10.5, fontWeight: FontWeight.w700, color: ink)),
        ],
      ),
    );
  }
}
