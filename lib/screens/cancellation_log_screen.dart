import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/daily_log.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';

/// Layar "Log pembatalan" (Pengaturan → Lainnya) — semua kegiatan yang
/// dibatalkan, dikelompokkan per hari dari yang terbaru.
class CancellationLogScreen extends StatelessWidget {
  const CancellationLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final provider = context.watch<ScheduleProvider>();

    final byDate = <String, List<DailyLog>>{};
    for (final l in provider.cancelledLogs) {
      byDate.putIfAbsent(l.date, () => []).add(l);
    }
    final days = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Log pembatalan',
          style: TextStyle(fontFamily: AppFonts.title, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: c.ink),
        ),
      ),
      body: days.isEmpty
          ? Center(
              child: Text('Belum ada kegiatan yang dibatalkan.', style: TextStyle(color: c.inkMuted, fontSize: 13)),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
              itemCount: days.length,
              itemBuilder: (context, i) => _HistoryDay(
                key: ValueKey(days[i]),
                dateKey: days[i],
                logs: byDate[days[i]]!,
                provider: provider,
                initiallyExpanded: i == 0,
              ),
            ),
    );
  }
}

/// Satu hari dalam log pembatalan. Hari terbaru terbuka, sisanya terlipat
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
