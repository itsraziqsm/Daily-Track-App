import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/agenda_item.dart';
import '../providers/agenda_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_time.dart';
import '../widgets/agenda_sheet.dart';
import '../widgets/animated_check_circle.dart';

const _dowLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// Tab "Agenda" — kalender bulanan berisi acara dan rencana di luar
/// rutinitas template. Ketuk tanggal untuk melihat agendanya; tombol di bawah
/// daftar menambah agenda pada tanggal yang dipilih.
class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key});

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  late DateTime _month = DateTime(_today.year, _today.month);
  late DateTime _selected = _today;

  static DateTime get _today {
    final n = AppTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final agenda = context.watch<AgendaProvider>();
    final items = agenda.itemsOn(_selected);
    final today = _today;
    final dayLabel = DateFormat('EEEE, d MMMM', 'id_ID').format(_selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      children: [
        _calendar(c, agenda, today),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                _selected == today ? 'Hari ini · $dayLabel' : dayLabel[0].toUpperCase() + dayLabel.substring(1),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: c.ink),
              ),
            ),
            Text(
              items.isEmpty ? '' : '${items.length} agenda',
              style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, color: c.inkMuted2),
            ),
          ],
        ),
        const SizedBox(height: 11),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Belum ada agenda di tanggal ini.',
              style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.inkMuted),
            ),
          ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AgendaCard(
              item: item,
              done: agenda.isDoneOn(item, _selected),
              onTap: () => showAgendaSheet(context, day: _selected, item: item),
              onToggle: () => agenda.toggleDone(item, _selected),
            ),
          ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: () => showAgendaSheet(context, day: _selected),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.lineSoft, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 17, color: c.inkMuted),
                const SizedBox(width: 8),
                Text('Tambah agenda', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.inkMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _calendar(AppColors c, AgendaProvider agenda, DateTime today) {
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_month);
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlank = (firstOfMonth.weekday - DateTime.monday) % 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AGENDA',
          style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.inkMuted),
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                monthLabel[0].toUpperCase() + monthLabel.substring(1),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.ink),
              ),
            ),
            IconButton(
              tooltip: 'Bulan sebelumnya',
              icon: Icon(LucideIcons.chevronLeft, size: 20, color: c.orange),
              onPressed: () => _shiftMonth(-1),
            ),
            IconButton(
              tooltip: 'Bulan berikutnya',
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
              _dayCell(c, agenda, DateTime(_month.year, _month.month, day), today),
          ],
        ),
      ],
    );
  }

  Widget _dayCell(AppColors c, AgendaProvider agenda, DateTime date, DateTime today) {
    final items = agenda.itemsOn(date);
    final pending = items.where((i) => !agenda.isDoneOn(i, date)).length;
    final isToday = date == today;
    final isSelected = date == _selected;

    return GestureDetector(
      onTap: () => setState(() => _selected = date),
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? c.yellowChipBg : (items.isNotEmpty ? c.rowBg : c.card),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? c.ink : (isToday ? c.yellow : c.lineSoft2),
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: items.isNotEmpty || isToday || isSelected ? c.ink : c.dayMuted,
              ),
            ),
            const SizedBox(height: 3),
            // Satu titik per agenda (maks. tiga): oranye bila belum selesai,
            // pudar bila semua di hari itu sudah selesai.
            SizedBox(
              height: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items.length.clamp(0, 3); i++) ...[
                    if (i > 0) const SizedBox(width: 2.5),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: pending > 0 ? c.orange : c.cancelledDot2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final AgendaItem item;
  final bool done;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _AgendaCard({required this.item, required this.done, required this.onTap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final meta = [
      item.timeLabel,
      if (item.isRepeating) item.repeatLabel,
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: done ? c.cardCancelled : c.card,
          border: Border.all(color: done ? c.lineSoft2 : c.line, width: 1.5),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: done ? c.cancelledDot : c.orange,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: done ? c.inkMuted : c.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          meta,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w600, color: c.inkMuted),
                        ),
                      ),
                      if (item.reminderMinutes != null) ...[
                        const SizedBox(width: 6),
                        Icon(LucideIcons.bell, size: 11, color: c.inkMuted2),
                      ],
                      if (item.isRepeating) ...[
                        const SizedBox(width: 5),
                        Icon(LucideIcons.repeat, size: 11, color: c.inkMuted2),
                      ],
                    ],
                  ),
                  if (item.note != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted3, height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onToggle,
              child: SizedBox(
                width: 30,
                height: 30,
                child: AnimatedCheckCircle(
                  checked: done,
                  size: 30,
                  accent: c.yellow,
                  idleBorder: c.cancelledDot,
                  background: c.card,
                  checkColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
