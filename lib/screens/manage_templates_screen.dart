import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/template.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import 'template_editor_screen.dart';

/// Layar "Kelola Template": daftar template, pembuatan template baru, dan
/// penugasan template untuk tiap hari dalam seminggu.
class ManageTemplatesScreen extends StatelessWidget {
  const ManageTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final provider = context.watch<ScheduleProvider>();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Kelola Template',
          style: TextStyle(fontFamily: AppFonts.title, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: c.ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
        children: [
          Text('DAFTAR TEMPLATE', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted)),
          const SizedBox(height: 11),
          for (final template in provider.templates) ...[
            _TemplateCard(
              template: template,
              weekdays: provider.weekdaysUsing(template.id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TemplateEditorScreen(template: template)),
              ),
            ),
            const SizedBox(height: 9),
          ],
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TemplateEditorScreen()),
            ),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.lineSoft, width: 1.5, style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 17, color: c.inkMuted),
                  const SizedBox(width: 8),
                  Text('Buat template baru', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.inkMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('TEMPLATE PER HARI', style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted)),
          const SizedBox(height: 4),
          Text(
            'Menentukan template mana yang dipakai pada hari apa',
            style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkMuted2),
          ),
          const SizedBox(height: 11),
          for (var weekday = 1; weekday <= 7; weekday++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DayRow(
                weekday: weekday,
                template: provider.templateForWeekday(weekday),
                onTap: () async {
                  final picked = await _pickTemplate(context, provider);
                  if (picked != null) await provider.assignDay(weekday, picked.id);
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<Template?> _pickTemplate(BuildContext context, ScheduleProvider provider) {
    return showModalBottomSheet<Template>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final c = AppColors.of(context);
        return Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: c.lineSoft, borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                  Text(
                    'Pilih template',
                    style: TextStyle(fontFamily: AppFonts.title, fontSize: 18, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 16),
                  for (final t in provider.templates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(t),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: c.line, width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(t.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.ink)),
                              ),
                              Text(
                                '${t.activities.length} kegiatan',
                                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Template template;
  final List<int> weekdays;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.weekdays, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dayLabel = weekdays.isEmpty
        ? 'Belum dipakai hari apa pun'
        : weekdays.map(weekdayShort).join(' · ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.line, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: c.ink)),
                  const SizedBox(height: 3),
                  Text(
                    '${template.activities.length} kegiatan · ${template.rangeLabel}',
                    style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkMuted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dayLabel,
                    style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, color: c.orangeChipInk),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: c.inkMuted2),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final int weekday;
  final Template? template;
  final VoidCallback onTap;

  const _DayRow({required this.weekday, required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.line, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 68,
              child: Text(weekdayName(weekday), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.ink)),
            ),
            Expanded(
              child: Text(
                template?.name ?? '-',
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.inkMuted),
              ),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronRight, size: 17, color: c.inkMuted2),
          ],
        ),
      ),
    );
  }
}
