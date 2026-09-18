import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/daily_log.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_time.dart';

const _dowLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// Tab "Kalender" — grid bulanan disiplin harian + log pembatalan terakhir.
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime _month = DateTime(AppTime.now().year, AppTime.now().month);

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final byDate = provider.logsByDate;
    final today = AppTime.now();
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_month);

    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlank = (firstOfMonth.weekday - DateTime.monday) % 7;

    final cancelledByDate = <String, List<DailyLog>>{};
    for (final l in provider.cancelledLogs) {
      cancelledByDate.putIfAbsent(l.date, () => []).add(l);
    }
    final recentCancelledDates = cancelledByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final recentDays = recentCancelledDates.take(6).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      children: [
        const Text(
          'RIWAYAT',
          style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              monthLabel[0].toUpperCase() + monthLabel.substring(1),
              style: const TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: AppColors.ink),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, size: 20, color: AppColors.orange),
                  onPressed: () => _shiftMonth(-1),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.orange),
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (final d in _dowLabels)
              Center(
                child: Text(
                  d.substring(0, 1),
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.inkMuted2),
                ),
              ),
            for (var i = 0; i < leadingBlank; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++) _DayCell(date: DateTime(_month.year, _month.month, day), logs: byDate, today: today),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: const [
            _LegendDot(color: AppColors.yellow, label: 'Hari sempurna'),
            _LegendDot(color: AppColors.orange, label: 'Ada terlambat'),
            _LegendDot(color: Color(0xFFDCD4C6), label: 'Ada pembatalan'),
          ],
        ),
        const SizedBox(height: 26),
        const Text(
          'LOG PEMBATALAN TERAKHIR',
          style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 14),
        if (recentDays.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Belum ada kegiatan yang dibatalkan.', style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          )
        else
          for (final dateKey in recentDays) _HistoryDay(dateKey: dateKey, logs: cancelledByDate[dateKey]!, provider: provider),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final Map<String, List<DailyLog>> logs;
  final DateTime today;

  const _DayCell({required this.date, required this.logs, required this.today});

  @override
  Widget build(BuildContext context) {
    final key = AppTime.dateKey(date);
    final dayLogs = logs[key];
    final isToday = key == AppTime.dateKey(today);

    Color dot = Colors.transparent;
    if (dayLogs != null && dayLogs.isNotEmpty) {
      final hasLate = dayLogs.any((l) => l.status == LogStatus.late);
      final hasCancelled = dayLogs.any((l) => l.status == LogStatus.cancelled);
      dot = hasLate ? AppColors.orange : (hasCancelled ? const Color(0xFFDCD4C6) : AppColors.yellow);
    }

    return Container(
      decoration: BoxDecoration(
        color: isToday ? AppColors.yellowChipBg : (dayLogs != null ? AppColors.rowBg : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isToday ? AppColors.yellow : const Color(0xFFF4F0E8), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: dayLogs != null || isToday ? AppColors.ink : const Color(0xFFD0C7B6),
            ),
          ),
          const SizedBox(height: 3),
          Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted3)),
      ],
    );
  }
}

class _HistoryDay extends StatelessWidget {
  final String dateKey;
  final List<DailyLog> logs;
  final ScheduleProvider provider;

  const _HistoryDay({required this.dateKey, required this.logs, required this.provider});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(dateKey);
    final dateLabel = DateFormat('d MMMM', 'id_ID').format(date);
    final dowLabel = DateFormat('EEEE', 'id_ID').format(date);
    final sorted = [...logs]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 9),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(dateLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(width: 8),
                Text(dowLabel, style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                const Spacer(),
                Text('${sorted.length} dibatalkan', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted2)),
              ],
            ),
          ),
          const SizedBox(height: 9),
          for (final l in sorted)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.rowBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF4F0E8)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        provider.activityById(l.activityId)?.startTime ?? '-',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        provider.activityById(l.activityId)?.title ?? '-',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.orangeChipBg, borderRadius: BorderRadius.circular(9)),
                      child: Text(
                        l.reason ?? '-',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.orangeChipInk),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
