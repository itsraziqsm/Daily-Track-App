import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tab "Keuangan" — pendapatan, pengeluaran bulanan, dan proyeksi tabungan.
class FinanceTab extends StatelessWidget {
  const FinanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
      children: [
        Text(
          'EXPENSES',
          style: TextStyle(fontFamily: AppFonts.subtitle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.inkMuted),
        ),
        const SizedBox(height: 5),
        Text(
          'Keuangan',
          style: TextStyle(fontFamily: AppFonts.title, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.ink),
        ),
      ],
    );
  }
}
