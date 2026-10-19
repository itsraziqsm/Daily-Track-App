import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../widgets/in_development.dart';

/// Tab "Target" — masih dalam pengembangan. Statistik yang dulu ada di tab ini
/// pindah ke Pengaturan → Lainnya.
class TargetTab extends StatelessWidget {
  const TargetTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      children: [
        Row(
          children: [
            Text(
              'SASARAN',
              style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.inkMuted),
            ),
            const SizedBox(width: 8),
            const InDevelopmentBadge(),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Target',
          style: TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.ink),
        ),
        const SizedBox(height: 18),
        const InDevelopmentCard(
          icon: LucideIcons.target,
          title: 'Target segera hadir',
          body: 'Nantinya kamu bisa menetapkan target, misalnya 5 hari sempurna minggu ini '
              'atau olahraga 3 kali seminggu, dan memantau kemajuannya dari jadwal harian.',
        ),
        const SizedBox(height: 12),
        Text(
          'Statistik kedisiplinan sekarang ada di Pengaturan → Lainnya.',
          style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkMuted2),
        ),
      ],
    );
  }
}
