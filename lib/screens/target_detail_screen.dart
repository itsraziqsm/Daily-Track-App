import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/target.dart';
import '../providers/schedule_provider.dart';
import '../providers/target_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_time.dart';
import '../utils/number_format.dart';
import '../widgets/progress_line_chart.dart';
import '../widgets/sheet_parts.dart';
import '../widgets/target_card.dart';
import '../widgets/target_sheets.dart';

/// Halaman detail satu target: ringkasan, grafik atau riwayat per periode,
/// dan daftar catatannya.
class TargetDetailScreen extends StatelessWidget {
  final int targetId;
  const TargetDetailScreen({super.key, required this.targetId});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final targets = context.watch<TargetProvider>();
    final schedule = context.watch<ScheduleProvider>();
    final target = targets.byId(targetId);

    if (target == null) return Scaffold(backgroundColor: c.bg, appBar: AppBar());

    final progress = targets.progressOf(target);
    final entries = targets.entriesOf(target).reversed.toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          target.title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: AppFonts.title, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: c.ink),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit target',
            icon: Icon(LucideIcons.pencil, size: 19, color: c.ink),
            onPressed: () async {
              final deleted = await showTargetSheet(context, target: target);
              if (deleted == true && context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
        children: [
          TargetCard(
            target: target,
            progress: progress,
            onTap: () {},
            action: target.kind == TargetKind.streak ? null : TargetEntryButton(target: target),
          ),
          const SizedBox(height: 24),
          ...switch (target.kind) {
            TargetKind.value => [
                const _SectionLabel('RIWAYAT'),
                if (entries.isEmpty)
                  const _Hint('Belum ada catatan. Ketuk "Catat" untuk menambah angka pertama.')
                else
                  ProgressLineChart(
                    points: [
                      ChartPoint(target.createdAt, target.startValue ?? 0),
                      for (final e in entries.reversed) ChartPoint(e.date, e.value),
                    ],
                    target: target.targetValue,
                    unit: target.unit,
                  ),
              ],
            TargetKind.count when target.period != TargetPeriod.total => [
                _SectionLabel(target.period.label.toUpperCase()),
                for (final p in targets.periodHistory(target).reversed) _PeriodRow(target: target, period: p),
              ],
            TargetKind.count => const <Widget>[],
            TargetKind.streak => [
                const _SectionLabel('28 HARI TERAKHIR'),
                _StreakGrid(schedule: schedule),
              ],
          },
          if (target.kind != TargetKind.streak) ...[
            if (!(target.kind == TargetKind.count && target.period == TargetPeriod.total)) const SizedBox(height: 24),
            const _SectionLabel('CATATAN'),
            if (entries.isEmpty && target.kind == TargetKind.count) const _Hint('Belum ada catatan.'),
            for (final e in entries) _EntryRow(target: target, entry: e),
          ],
        ],
      ),
    );
  }
}

/// Tombol kecil di kartu target: "Catat" untuk angka, "+1" untuk hitungan
/// (tahan untuk mengisi jumlah lain).
class TargetEntryButton extends StatelessWidget {
  final Target target;
  const TargetEntryButton({super.key, required this.target});

  Future<void> _quickAdd(BuildContext context) async {
    final targets = context.read<TargetProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final now = AppTime.now();
    final entry = await targets.addEntry(TargetEntry(targetId: target.id, date: DateTime(now.year, now.month, now.day), value: 1));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('+1 ${target.unit ?? ''} · ${target.title}'),
        action: SnackBarAction(label: 'Batalkan', onPressed: () => targets.deleteEntry(entry)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isCount = target.kind == TargetKind.count;
    return GestureDetector(
      onTap: () => isCount ? _quickAdd(context) : showTargetEntrySheet(context, target),
      onLongPress: isCount ? () => showTargetEntrySheet(context, target) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(color: c.orange, borderRadius: BorderRadius.circular(11)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isCount ? LucideIcons.plus : LucideIcons.pencil, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(isCount ? '1' : 'Catat', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Text(text, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted)),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(text, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.inkMuted, height: 1.4));
  }
}

class _PeriodRow extends StatelessWidget {
  final Target target;
  final PeriodTotal period;
  const _PeriodRow({required this.target, required this.period});

  String _label() {
    final s = period.start;
    return switch (target.period) {
      TargetPeriod.week => () {
          final end = s.add(const Duration(days: 6));
          return s.month == end.month
              ? '${s.day}–${DateFormat('d MMM', 'id_ID').format(end)}'
              : '${DateFormat('d MMM', 'id_ID').format(s)} – ${DateFormat('d MMM', 'id_ID').format(end)}';
        }(),
      TargetPeriod.month => DateFormat('MMMM yyyy', 'id_ID').format(s),
      TargetPeriod.year => '${s.year}',
      TargetPeriod.total => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final reached = period.total >= target.targetValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(_label(), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink)),
          ),
          Expanded(child: TargetProgressBar(fraction: target.targetValue <= 0 ? 1 : period.total / target.targetValue)),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              '${formatNumber(period.total)}/${formatNumber(target.targetValue)}',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.ink),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 16,
            child: reached ? Icon(LucideIcons.check, size: 15, color: c.yellowInk2, semanticLabel: 'Tercapai') : null,
          ),
        ],
      ),
    );
  }
}

/// Kisi 4 × 7 hari terakhir: kuning untuk hari lengkap, abu untuk yang belum.
class _StreakGrid extends StatelessWidget {
  final ScheduleProvider schedule;
  const _StreakGrid({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final now = AppTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDate = schedule.logsByDate;
    final days = [for (var i = 27; i >= 0; i--) today.subtract(Duration(days: i))];
    const dow = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          children: [
            for (final d in days)
              Builder(builder: (context) {
                final done = schedule.isCompletedDay(d, byDate);
                final isToday = d == today;
                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? c.yellow : c.lineSoft2,
                    borderRadius: BorderRadius.circular(9),
                    border: isToday ? Border.all(color: c.ink, width: 2) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${d.day}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: done ? c.onYellow : c.inkMuted)),
                      Text(dow[d.weekday - 1], style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: done ? c.onYellow : c.inkMuted2)),
                    ],
                  ),
                );
              }),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Swatch(color: c.yellow, label: 'Semua selesai'),
            const SizedBox(width: 14),
            _Swatch(color: c.lineSoft2, label: 'Belum lengkap'),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final String label;
  const _Swatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), border: Border.all(color: c.lineSoft))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.inkMuted3)),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  final Target target;
  final TargetEntry entry;
  const _EntryRow({required this.target, required this.entry});

  Future<void> _delete(BuildContext context) async {
    final targets = context.read<TargetProvider>();
    final choice = await showConfirmDialog(
      context,
      title: 'Hapus catatan ini?',
      message: '${withUnit(entry.value, target.unit)} pada ${DateFormat('d MMMM yyyy', 'id_ID').format(entry.date)} akan dihapus.',
      actions: const {'delete': 'Hapus'},
    );
    if (choice != null) await targets.deleteEntry(entry);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final value = withUnit(entry.value, target.unit);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.lineSoft2),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(DateFormat('d MMM', 'id_ID').format(entry.date), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.inkMuted)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(target.kind == TargetKind.count ? '+$value' : value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.ink)),
                  if (entry.note != null)
                    Text(entry.note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted3)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Hapus catatan',
              visualDensity: VisualDensity.compact,
              icon: Icon(LucideIcons.trash2, size: 16, color: c.inkMuted2),
              onPressed: () => _delete(context),
            ),
          ],
        ),
      ),
    );
  }
}
