import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Label bagian dan teks petunjuk untuk layar-layar Keuangan.

class SectionLabel extends StatelessWidget {
  final String text;
  final String? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Expanded(child: Text(text, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.inkMuted))),
          if (trailing != null) Text(trailing!, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, color: c.inkMuted2)),
        ],
      ),
    );
  }
}


class SectionHint extends StatelessWidget {
  final String text;
  const SectionHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 12.5, fontWeight: FontWeight.w600, color: c.inkMuted)),
    );
  }
}
