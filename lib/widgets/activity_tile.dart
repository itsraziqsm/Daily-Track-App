import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/daily_log.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';

/// Satu baris kegiatan dalam timeline vertikal, mengikuti tata letak desain
/// "Daily Track": kolom jam, garis+titik, dan kartu kegiatan.
class ActivityTile extends StatelessWidget {
  final Activity activity;
  final DailyLog? log;

  /// Jam WIB sekarang berada di dalam rentang kegiatan ini.
  final bool isRunning;
  final bool isLast;
  final VoidCallback onCheck;
  final VoidCallback onCancel;

  const ActivityTile({
    super.key,
    required this.activity,
    required this.log,
    required this.isRunning,
    required this.isLast,
    required this.onCheck,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = log?.status == LogStatus.done;
    final isLate = log?.status == LogStatus.late;
    final isCancelled = log?.status == LogStatus.cancelled;
    final hasStatus = log != null;

    final accent = isLate
        ? AppColors.orange
        : isDone
            ? AppColors.yellow
            : AppColors.cancelledDot;
    final dotColor = isCancelled
        ? AppColors.cancelledDot
        : isLate
            ? AppColors.orange
            : isDone
                ? AppColors.yellow
                : isRunning
                    ? AppColors.orange
                    : AppColors.cancelledDot;
    final dotHalo = isRunning && !hasStatus ? AppColors.orange.withValues(alpha: 0.16) : Colors.white;

    final showActions = isRunning && !hasStatus;
    final cardBorder = showActions
        ? AppColors.yellowBorder2
        : isCancelled
            ? AppColors.lineSoft2
            : AppColors.line;
    final cardBg = showActions
        ? const Color(0xFFFFFCF3)
        : isCancelled
            ? const Color(0xFFFAF8F4)
            : AppColors.card;

    final checkBg = (isDone || isLate) ? accent : Colors.white;
    final checkInk = (isDone || isLate) ? Colors.white : const Color(0xFFD8CFBE);
    final checkMark = isDone ? '✓' : isLate ? '!' : isCancelled ? '✕' : '';

    final metaText = isLate
        ? 'Selesai di luar toleransi ${ScheduleProvider.toleranceMinutes} mnt'
        : isDone
            ? 'Selesai tepat waktu'
            : isCancelled
                ? 'Dibatalkan'
                : showActions
                    ? 'Sedang berlangsung'
                    : activity.category;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 15, right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    activity.startTime,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: hasStatus ? AppColors.inkMuted : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    activity.durationLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted2),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: Border.all(color: dotHalo, width: 3),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.line, constraints: const BoxConstraints(minHeight: 12)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: cardBorder, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.title,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: isCancelled ? AppColors.inkMuted : AppColors.ink,
                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                metaText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isLate ? AppColors.orange : AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 11),
                        GestureDetector(
                          onTap: onCheck,
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: checkBg,
                              border: Border.all(color: accent, width: 2),
                            ),
                            child: Text(
                              checkMark,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: checkInk),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showActions) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 11),
                        child: Divider(height: 1, color: AppColors.line),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: onCancel,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(color: AppColors.lineSoft, width: 1.5),
                                ),
                                child: const Text(
                                  'Batalkan',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: onCheck,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.yellow,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(color: AppColors.yellow, width: 1.5),
                                ),
                                child: const Text(
                                  'Tandai selesai',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4A3708)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isCancelled && log?.reason != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F4EE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.inkMuted2),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Alasan: ${log!.reason}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkMuted3),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
