import 'package:flutter/material.dart';

import '../models/daily_log.dart';
import '../theme/app_theme.dart';

// Penanda riwayat harian (sempurna / ada terlambat / ada pembatalan) yang
// dulu tampil di kalender. Agenda tidak lagi memakainya, tapi disimpan untuk
// tampilan riwayat berikutnya.

/// Warna titik status sebuah hari dari log-nya: oranye bila ada yang
/// terlambat, abu bila ada pembatalan, kuning bila semuanya selesai. Null bila
/// hari itu belum punya log.
Color? historyDotColor(AppColors c, List<DailyLog>? logs) {
  if (logs == null || logs.isEmpty) return null;
  if (logs.any((l) => l.status == LogStatus.late)) return c.orange;
  if (logs.any((l) => l.status == LogStatus.cancelled)) return c.cancelledDot2;
  return c.yellow;
}

/// Titik status satu hari; kosong (transparan) bila belum ada log.
class HistoryStatusDot extends StatelessWidget {
  final List<DailyLog>? logs;
  final double size;

  const HistoryStatusDot({super.key, required this.logs, this.size = 5});

  @override
  Widget build(BuildContext context) {
    final color = historyDotColor(AppColors.of(context), logs) ?? Colors.transparent;
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}

/// Legenda ketiga warna titik status.
class HistoryStatusLegend extends StatelessWidget {
  const HistoryStatusLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        LegendDot(color: c.yellow, label: 'Hari sempurna'),
        LegendDot(color: c.orange, label: 'Ada terlambat'),
        LegendDot(color: c.cancelledDot2, label: 'Ada pembatalan'),
      ],
    );
  }
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.inkMuted3)),
      ],
    );
  }
}
