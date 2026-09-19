import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/daily_log.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_time.dart';

const _dowLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// Blur maksimum pada kalender saat panel log ditarik penuh.
const _maxBlur = 7.0;

/// Tab "Kalender" — grid bulanan yang diam, dengan panel log pembatalan yang
/// bisa ditarik naik menutupinya. Kalender di belakangnya mengabur seiring
/// panel naik.
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late DateTime _month = DateTime(AppTime.now().year, AppTime.now().month);

  final _calendarKey = GlobalKey();
  final _blur = ValueNotifier<double>(0);

  /// Tinggi kalender diukur dari widget yang sudah ter-render, bukan ditebak,
  /// karena jumlah baris grid berbeda tiap bulan dan legenda bisa membungkus.
  double _calendarHeight = 320;

  @override
  void dispose() {
    _blur.dispose();
    super.dispose();
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _measureCalendar() {
    final box = _calendarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if ((box.size.height - _calendarHeight).abs() > 0.5) {
      setState(() => _calendarHeight = box.size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final today = AppTime.now();

    final cancelledByDate = <String, List<DailyLog>>{};
    for (final l in provider.cancelledLogs) {
      cancelledByDate.putIfAbsent(l.date, () => []).add(l);
    }
    final recentDays = (cancelledByDate.keys.toList()..sort((a, b) => b.compareTo(a))).take(6).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureCalendar());

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxHeight;
        const maxSize = 0.94;
        final minSize = ((viewport - _calendarHeight) / viewport).clamp(0.18, maxSize);

        return Stack(
          children: [
            // Lapisan tetap: tidak ikut bergulir, hanya mengabur.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<double>(
                valueListenable: _blur,
                builder: (context, sigma, child) => sigma < 0.1
                    ? child!
                    : ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                        child: child!,
                      ),
                child: _calendarBlock(provider, today),
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                final span = maxSize - minSize;
                final t = span <= 0 ? 0.0 : ((n.extent - minSize) / span).clamp(0.0, 1.0);
                _blur.value = t * _maxBlur;
                return false;
              },
              child: DraggableScrollableSheet(
                // Kunci ikut berubah saat tinggi kalender terukur ulang (mis.
                // bulan dengan jumlah baris berbeda), supaya panel kembali
                // bersandar tepat di bawah kalender.
                key: ValueKey(minSize.toStringAsFixed(3)),
                initialChildSize: minSize,
                minChildSize: minSize,
                maxChildSize: maxSize,
                builder: (context, scrollController) => _logPanel(
                  scrollController: scrollController,
                  provider: provider,
                  today: today,
                  cancelledByDate: cancelledByDate,
                  recentDays: recentDays,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _calendarBlock(ScheduleProvider provider, DateTime today) {
    final byDate = provider.logsByDate;
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_month);
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlank = (firstOfMonth.weekday - DateTime.monday) % 7;

    return Container(
      key: _calendarKey,
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
              Expanded(
                child: Text(
                  monthLabel[0].toUpperCase() + monthLabel.substring(1),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: AppColors.ink),
                ),
              ),
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
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.inkMuted2),
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
            children: const [
              _LegendDot(color: AppColors.yellow, label: 'Hari sempurna'),
              _LegendDot(color: AppColors.orange, label: 'Ada terlambat'),
              _LegendDot(color: Color(0xFFDCD4C6), label: 'Ada pembatalan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logPanel({
    required ScrollController scrollController,
    required ScheduleProvider provider,
    required DateTime today,
    required Map<String, List<DailyLog>> cancelledByDate,
    required List<String> recentDays,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: const Border(top: BorderSide(color: AppColors.line, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: AppColors.lineSoft, borderRadius: BorderRadius.circular(99)),
            ),
          ),
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
            for (final dateKey in recentDays)
              _HistoryDay(
                key: ValueKey(dateKey),
                dateKey: dateKey,
                logs: cancelledByDate[dateKey]!,
                provider: provider,
                initiallyExpanded: dateKey == AppTime.dateKey(today),
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

/// Satu hari dalam log pembatalan. Hari ini terbuka, hari sebelumnya terlipat
/// supaya daftarnya tidak memanjang.
class _HistoryDay extends StatefulWidget {
  final String dateKey;
  final List<DailyLog> logs;
  final ScheduleProvider provider;
  final bool initiallyExpanded;

  const _HistoryDay({
    super.key,
    required this.dateKey,
    required this.logs,
    required this.provider,
    required this.initiallyExpanded,
  });

  @override
  State<_HistoryDay> createState() => _HistoryDayState();
}

class _HistoryDayState extends State<_HistoryDay> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final date = DateTime.parse(widget.dateKey);
    final dateLabel = DateFormat('d MMMM', 'id_ID').format(date);
    final dowLabel = DateFormat('EEEE', 'id_ID').format(date);
    final sorted = [...widget.logs]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.only(bottom: 9),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Text(dateLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(width: 8),
                  Text(dowLabel, style: const TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
                  const Spacer(),
                  Text('${sorted.length} dibatalkan', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted2)),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.inkMuted2),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 9),
                      for (final l in sorted)
                        _CancelledRow(log: l, provider: provider),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _CancelledRow extends StatelessWidget {
  final DailyLog log;
  final ScheduleProvider provider;

  const _CancelledRow({required this.log, required this.provider});

  @override
  Widget build(BuildContext context) {
    final activity = provider.activityById(log.activityId);
    return Padding(
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
                activity?.startTime ?? '-',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
              ),
            ),
            Expanded(
              child: Text(
                activity?.title ?? '-',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 8),
            // Nama kegiatan yang diutamakan; alasan panjang dipangkas agar
            // barisnya tidak meluber.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: AppColors.orangeChipBg, borderRadius: BorderRadius.circular(9)),
                child: Text(
                  log.reason ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.orangeChipInk),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
