import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/daily_log.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';

/// Layar notifikasi — dibangun dari log aktivitas nyata (bukan data statis),
/// mengikuti tampilan feed pada desain.
class NotificationFeedScreen extends StatelessWidget {
  const NotificationFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final items = provider.allLogs.take(20).toList();

    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        title: const Text('Notifikasi', style: TextStyle(fontFamily: AppFonts.title, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.ink)),
        actions: [
          IconButton(icon: const Icon(LucideIcons.x, size: 21, color: AppColors.ink), onPressed: () => Navigator.of(context).pop()),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('Belum ada aktivitas.', style: TextStyle(color: AppColors.inkMuted)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 26),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) => _NotifCard(log: items[index], provider: provider),
            ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final DailyLog log;
  final ScheduleProvider provider;
  const _NotifCard({required this.log, required this.provider});

  @override
  Widget build(BuildContext context) {
    final activity = provider.activityById(log.activityId);
    final title = switch (log.status) {
      LogStatus.done => '${activity?.title ?? 'Kegiatan'} selesai tepat waktu',
      LogStatus.late => '${activity?.title ?? 'Kegiatan'} selesai terlambat',
      LogStatus.cancelled => '${activity?.title ?? 'Kegiatan'} dibatalkan',
    };
    final body = switch (log.status) {
      LogStatus.done => 'Ditandai selesai pada jadwal ${activity?.startTime ?? ''}.',
      LogStatus.late => 'Ditandai lewat jendela toleransi ${ScheduleProvider.toleranceMinutes} menit.',
      LogStatus.cancelled => 'Alasan: ${log.reason ?? '-'}.',
    };
    final dot = switch (log.status) {
      LogStatus.done => AppColors.yellow,
      LogStatus.late => AppColors.orange,
      LogStatus.cancelled => const Color(0xFFDCD4C6),
    };
    final border = log.status == LogStatus.late ? AppColors.yellowBorder2 : AppColors.line;
    final bg = log.status == LogStatus.late ? const Color(0xFFFFFCF3) : Colors.white;
    final atLabel = DateFormat('d MMM · HH:mm', 'id_ID').format(log.timestamp);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink))),
                    Text(atLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted2)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkMuted3, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
