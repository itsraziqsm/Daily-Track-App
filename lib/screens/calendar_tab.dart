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
    final c = AppColors.of(context);

    return Container(
      key: _calendarKey,
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RIWAYAT',
            style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.inkMuted),
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

  Widget _logPanel({
    required ScrollController scrollController,
    required ScheduleProvider provider,
    required DateTime today,
    required Map<String, List<DailyLog>> cancelledByDate,
    required List<String> recentDays,
  }) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: c.line, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: c.isDark ? 0.4 : 0.10),
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
              decoration: BoxDecoration(color: c.lineSoft, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Text(
            'LOG PEMBATALAN TERAKHIR',
            style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted),
          ),
          const SizedBox(height: 14),
          if (recentDays.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Belum ada kegiatan yang dibatalkan.', style: TextStyle(color: c.inkMuted, fontSize: 13)),
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
    final c = AppColors.of(context);
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
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.line)),
              ),
              child: Row(
                children: [
                  Text(dateLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.ink)),
                  const SizedBox(width: 8),
                  Text(dowLabel, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted)),
                  const Spacer(),
                  Text('${sorted.length} dibatalkan', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.inkMuted2)),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(LucideIcons.chevronDown, size: 16, color: c.inkMuted2),
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
    final c = AppColors.of(context);
    final activity = provider.activityById(log.activityId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: c.rowBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.lineSoft2),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                activity?.startTime ?? '-',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.inkMuted),
              ),
            ),
            Expanded(
              child: Text(
                activity?.title ?? '-',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.ink),
              ),
            ),
            const SizedBox(width: 8),
            // Nama kegiatan yang diutamakan; alasan panjang dipangkas agar
            // barisnya tidak meluber.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 108),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: c.orangeChipBg, borderRadius: BorderRadius.circular(9)),
                child: Text(
                  log.reason ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.orangeChipInk),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
