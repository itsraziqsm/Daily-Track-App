import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Penanda kecil untuk fitur yang belum selesai dibangun.
class InDevelopmentBadge extends StatelessWidget {
  const InDevelopmentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(
        color: c.orangeChipBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.hammer, size: 11, color: c.orangeChipInk),
          const SizedBox(width: 5),
          Text(
            'IN DEVELOPMENT',
            style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.orangeChipInk),
          ),
        ],
      ),
    );
  }
}

/// Kartu penjelasan untuk fitur yang belum selesai: apa yang akan datang.
class InDevelopmentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const InDevelopmentCard({super.key, required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.lineSoft, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.yellowChipBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 19, color: c.yellowInk2),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: c.ink)),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
