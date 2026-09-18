import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../utils/wib.dart';
import '../widgets/activity_tile.dart';
import '../widgets/skip_reason_dialog.dart';

/// Tab "Hari Ini" — timeline jadwal harian, progres, dan status tiap kegiatan.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final todayLabel = DateFormat('EEEE, d MMMM', 'id_ID').format(wibNow());
    final activities = provider.activities;
    final pctDone = provider.totalCount == 0 ? 0.0 : provider.onTimeCount / provider.totalCount;
    final pctLate = provider.totalCount == 0 ? 0.0 : provider.lateCount / provider.totalCount;
    final allSet = activities.every((a) => provider.todayLogs.containsKey(a.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todayLabel[0].toUpperCase() + todayLabel.substring(1),
                    style: const TextStyle(
                      fontFamily: AppFonts.subtitle,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Hari Ini',
                    style: TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(9, 7, 11, 7),
              decoration: BoxDecoration(
                color: AppColors.yellowChipBg,
                border: Border.all(color: AppColors.yellowChipBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.yellow),
                    child: Text(
                      '${provider.perfectStreak}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.yellowInk),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'hari\nberuntun',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.yellowInk2, height: 1.1),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.yellowBg,
            border: Border.all(color: AppColors.yellowBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PROGRES HARI INI',
                    style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: AppColors.yellowInk3),
                  ),
                  Text(
                    '${provider.doneCount}/${provider.totalCount} selesai',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 9,
                  child: Row(
                    children: [
                      Expanded(flex: (pctDone * 1000).round().clamp(0, 1000), child: Container(color: AppColors.yellow)),
                      Expanded(flex: (pctLate * 1000).round().clamp(0, 1000), child: Container(color: AppColors.orange)),
                      Expanded(
                        flex: (1000 - (pctDone * 1000).round() - (pctLate * 1000).round()).clamp(0, 1000),
                        child: Container(color: const Color(0xFFF3E6C8)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: const [
                  _Legend(color: AppColors.yellow, label: 'Selesai'),
                  _Legend(color: AppColors.orange, label: 'Terlambat'),
                  _Legend(color: Color(0xFFE4DDD1), label: 'Dibatalkan'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < activities.length; i++)
          ActivityTile(
            activity: activities[i],
            log: provider.todayLogs[activities[i].id],
            isRunning: provider.isRunning(activities[i]),
            isLast: i == activities.length - 1,
            onCheck: () => provider.toggle(activities[i]),
            onCancel: () async {
              final reason = await showSkipReasonDialog(
                context,
                '${activities[i].startTime} · ${activities[i].title}',
              );
              if (reason != null) {
                await provider.markCancelled(activities[i], reason);
              }
            },
          ),
        if (allSet)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: AppColors.lineSoft, width: 1.5),
            ),
            child: Text(
              'Selesai. Besok mulai ${activities.first.startTime}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkMuted2),
            ),
          ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.yellowInk3)),
      ],
    );
  }
}
