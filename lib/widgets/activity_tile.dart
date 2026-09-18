import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/daily_log.dart';
import '../theme/app_theme.dart';

/// Satu baris kegiatan dalam timeline vertikal ala agenda kertas.
class ActivityTile extends StatelessWidget {
  final Activity activity;
  final DailyLog? log;
  final bool isLast;
  final VoidCallback onMarkDone;
  final VoidCallback onMarkSkipped;
  final VoidCallback onClear;

  const ActivityTile({
    super.key,
    required this.activity,
    required this.log,
    required this.isLast,
    required this.onMarkDone,
    required this.onMarkSkipped,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(activity.category);
    final isDone = log?.status == LogStatus.done;
    final isSkipped = log?.status == LogStatus.skipped;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                activity.startTime,
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? color : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: AppColors.line),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 8),
              child: GestureDetector(
                onTap: onMarkDone,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSkipped ? Colors.black.withValues(alpha: 0.03) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                color: isSkipped ? AppColors.inkMuted : AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    activity.category,
                                    style: TextStyle(fontSize: 11, color: color),
                                  ),
                                ),
                                if (isSkipped && log?.reason != null) ...[
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Dilewati: ${log!.reason}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (log == null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: AppColors.inkMuted),
                          tooltip: 'Tidak dijalankan',
                          onPressed: onMarkSkipped,
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18, color: AppColors.inkMuted),
                          tooltip: 'Reset status',
                          onPressed: onClear,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
