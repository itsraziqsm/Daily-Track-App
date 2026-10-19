import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_time.dart';
import '../widgets/discipline_ring.dart';

const _dayInitials = ['M', 'S', 'S', 'R', 'K', 'J', 'S'];

/// Tab "Statistik" — ring disiplin mingguan, grafik per hari, dan peringkat alasan.
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final provider = context.watch<ScheduleProvider>();
    final week = provider.last7DaysCompletion;
    final weekPct = provider.weekDisciplinePct;
    final ranking = provider.reasonRanking;
    final topRankCount = ranking.isEmpty ? 1 : ranking.first.value;
    final rangeLabel =
        '${DateFormat('d', 'id_ID').format(week.first.key)} – ${DateFormat('d MMMM', 'id_ID').format(week.last.key)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      children: [
        Text(
          rangeLabel,
          style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.inkMuted),
        ),
        const SizedBox(height: 5),
        Text(
          'Statistik',
          style: TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.ink),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: c.yellowBg,
            border: Border.all(color: c.yellowBorder),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DisciplineRing(pct: weekPct),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('HARI SEMPURNA', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: c.yellowInk3)),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${provider.perfectStreak}', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: c.ink)),
                        const SizedBox(width: 6),
                        Text('beruntun', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('MINGGU INI', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: c.yellowInk3)),
                    const SizedBox(height: 3),
                    Text(
                      '${(weekPct * 100).round()}% rata-rata selesai',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PER HARI', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted)),
            Text('% kegiatan selesai', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 10.5, fontWeight: FontWeight.w600, color: c.inkMuted2)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 112,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in week)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.5),
                    child: _DayBar(pct: entry.value, dayLabel: _dayInitials[entry.key.weekday % 7], isToday: _isToday(entry.key)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Text('ALASAN PALING SERING', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted)),
        const SizedBox(height: 12),
        if (ranking.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Belum ada data pembatalan.', style: TextStyle(color: c.inkMuted, fontSize: 13)),
          )
        else
          for (final r in ranking) _ReasonBar(label: r.key, count: r.value, maxCount: topRankCount),
        if (provider.mostCancelledActivityTitle != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
            decoration: BoxDecoration(
              color: c.cardWarm,
              border: Border.all(color: c.yellowBorder2, width: 1.5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CATATAN', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: c.yellowInk2)),
                const SizedBox(height: 6),
                Text(
                  '"${provider.mostCancelledActivityTitle}" paling sering dibatalkan, biasanya dengan alasan "${provider.mostCommonReason}". Coba lihat kembali jadwalnya.',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.yellowInk, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static bool _isToday(DateTime d) {
    final now = AppTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _DayBar extends StatelessWidget {
  final double pct;
  final String dayLabel;
  final bool isToday;
  const _DayBar({required this.pct, required this.dayLabel, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = pct >= 0.95 ? c.yellow : (pct >= 0.7 ? c.yellowBorder2 : c.orange);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('${(pct * 100).round()}%', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c.inkMuted2)),
        const SizedBox(height: 7),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: pct.clamp(0.03, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8), bottomLeft: Radius.circular(3), bottomRight: Radius.circular(3)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(dayLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isToday ? c.ink : c.inkMuted2)),
      ],
    );
  }
}

class _ReasonBar extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;
  const _ReasonBar({required this.label, required this.count, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final w = maxCount == 0 ? 0.0 : count / maxCount;
    final fill = count >= maxCount ? c.orange : c.yellow;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.ink),
                ),
              ),
              Text('${count}×', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.inkMuted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: c.lineSoft2),
                  FractionallySizedBox(widthFactor: w.clamp(0.02, 1.0), child: Container(color: fill)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
