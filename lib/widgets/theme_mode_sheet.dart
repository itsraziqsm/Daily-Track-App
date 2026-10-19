import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
        ThemeMode.system => 'Ikuti sistem',
        ThemeMode.light => 'Terang',
        ThemeMode.dark => 'Gelap',
      };

  String get description => switch (this) {
        ThemeMode.system => 'Berganti otomatis mengikuti pengaturan perangkat',
        ThemeMode.light => 'Latar krem terang, seperti desain asli',
        ThemeMode.dark => 'Latar cokelat gelap, nyaman untuk malam hari',
      };

  IconData get icon => switch (this) {
        ThemeMode.system => LucideIcons.smartphone,
        ThemeMode.light => LucideIcons.sun,
        ThemeMode.dark => LucideIcons.moon,
      };
}

/// Modal pemilih tema. Mengembalikan mode terpilih, atau null bila ditutup
/// tanpa memilih.
Future<ThemeMode?> showThemeModeSheet(BuildContext context, ThemeMode current) {
  return showModalBottomSheet<ThemeMode>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _ThemeModeSheet(current: current),
  );
}

class _ThemeModeSheet extends StatelessWidget {
  final ThemeMode current;
  const _ThemeModeSheet({required this.current});

  @override
  Widget build(BuildContext context) {
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
                  decoration: BoxDecoration(
                    color: c.lineSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                'Tampilan',
                style: TextStyle(fontFamily: AppFonts.title, fontSize: 18, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.4),
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih mode terang, gelap, atau ikuti perangkat',
                style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted),
              ),
              const SizedBox(height: 16),
              for (final mode in ThemeMode.values) ...[
                _ModeRow(mode: mode, selected: mode == current),
                if (mode != ThemeMode.values.last) const SizedBox(height: 9),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  final ThemeMode mode;
  final bool selected;

  const _ModeRow({required this.mode, required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(mode),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? c.rowBg : c.card,
          border: Border.all(color: selected ? c.ink : c.line, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(mode.icon, size: 19, color: selected ? c.ink : c.inkMuted2),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: c.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.description,
                    style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? c.ink : c.lineSoft, width: 2),
              ),
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.ink),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
