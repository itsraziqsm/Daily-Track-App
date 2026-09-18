import 'package:flutter/material.dart';

import '../data/seed_activities.dart';

/// Palet minimalis terinspirasi kertas agenda: krem, tinta, dan aksen lembut.
class AppColors {
  static const paper = Color(0xFFFBF7EF);
  static const ink = Color(0xFF2E2A24);
  static const inkMuted = Color(0xFF7A7266);
  static const line = Color(0xFFE0D8C8);
  static const accent = Color(0xFFB05C3B);
}

Color categoryColor(String category) {
  switch (category) {
    case Categories.ibadahDiri:
      return const Color(0xFF6B8E6B);
    case Categories.istirahatOlahraga:
      return const Color(0xFF4A7A96);
    case Categories.kerjaBelajar:
      return const Color(0xFFB08A3E);
    case Categories.tidur:
      return const Color(0xFF7C6A9C);
    default:
      return AppColors.inkMuted;
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      surface: AppColors.paper,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        fontFamily: 'Georgia',
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    dividerColor: AppColors.line,
    useMaterial3: true,
  );
}
