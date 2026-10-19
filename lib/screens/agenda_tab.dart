import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/daily_log.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/in_development.dart';
import '../utils/app_time.dart';

const _dowLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// Tab "Agenda" — masih dalam pengembangan. Grid bulanannya dipertahankan
/// sebagai kerangka tampilan; log pembatalan yang dulu ada di sini pindah ke
/// Pengaturan → Lainnya.
class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key});

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  late DateTime _month = DateTime(AppTime.now().year, AppTime.now().month);

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 26),
      children: [
        _calendarBlock(provider, AppTime.now()),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: InDevelopmentCard(
            icon: LucideIcons.calendarClock,
            title: 'Agenda segera hadir',
            body: 'Nantinya kamu bisa mencatat rencana dan acara di tanggal tertentu, '
                'lalu melihatnya berdampingan dengan jadwal harian.',
          ),
        ),
      ],
    );
  }

  Widget _calendarBlock(ScheduleProvider provider, DateTime today) {
    final byDate = provider.logsByDate;
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_month);
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlank = (firstOfMonth.weekday - DateTime.monday) % 7;
    final c = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AGENDA',
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.inkMuted),
              ),
              const SizedBox(width: 8),
              const InDevelopmentBadge(),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  monthLabel[0].toUpperCase() + monthLabel.substring(1),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.ink),
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.chevronLeft, size: 20, color: c.orange),
                onPressed: () => _shiftMonth(-1),
              ),
              IconButton(
                icon: Icon(LucideIcons.chevronRight, size: 20, color: c.orange),
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: c.inkMuted2),
                  ),
                ),
              for (var i = 0; i < leadingBlank; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                _DayCell(date: DateTime(_month.year, _month.month, day), logs: byDate, today: today),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendDot(color: c.yellow, label: 'Hari sempurna'),
              _LegendDot(color: c.orange, label: 'Ada terlambat'),
              _LegendDot(color: c.cancelledDot2, label: 'Ada pembatalan'),
            ],
          ),
        ],
      ),
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
    final c = AppColors.of(context);
    final key = AppTime.dateKey(date);
    final dayLogs = logs[key];
    final isToday = key == AppTime.dateKey(today);

    Color dot = Colors.transparent;
    if (dayLogs != null && dayLogs.isNotEmpty) {
      final hasLate = dayLogs.any((l) => l.status == LogStatus.late);
      final hasCancelled = dayLogs.any((l) => l.status == LogStatus.cancelled);
      dot = hasLate ? c.orange : (hasCancelled ? c.cancelledDot2 : c.yellow);
    }

    return Container(
      decoration: BoxDecoration(
        color: isToday ? c.yellowChipBg : (dayLogs != null ? c.rowBg : c.card),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isToday ? c.yellow : c.lineSoft2, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: dayLogs != null || isToday ? c.ink : c.dayMuted,
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
