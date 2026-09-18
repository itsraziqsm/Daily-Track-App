import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tiga famili huruf, semuanya dibundel lokal di `assets/fonts/`.
class AppFonts {
  /// Judul layar dan angka display.
  static const title = 'BricolageGrotesque';

  /// Label bagian, eyebrow, dan baris keterangan di bawah judul.
  static const subtitle = 'SchibstedGrotesk';

  /// Sisanya — huruf dasar seluruh aplikasi.
  static const body = 'Onest';
}

/// Palet diambil persis dari desain "Daily Track" (claude.ai/design handoff).
class AppColors {
  static const bg = Color(0xFFF4F2EE);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2B251E);
  static const inkMuted = Color(0xFF6F6555);
  static const inkMuted2 = Color(0xFF7D7263);
  static const inkMuted3 = Color(0xFF6B6153);
  static const line = Color(0xFFF1EBE0);
  static const lineSoft = Color(0xFFECE5D9);
  static const lineSoft2 = Color(0xFFF4F0E8);

  static const yellow = Color(0xFFFFC93C);
  static const yellowBg = Color(0xFFFFFBF0);
  static const yellowBorder = Color(0xFFFFEDBF);
  static const yellowBorder2 = Color(0xFFFFDE8F);
  static const yellowChipBg = Color(0xFFFFF4D1);
  static const yellowChipBorder = Color(0xFFFFE08A);
  static const yellowInk = Color(0xFF5C4408);
  static const yellowInk2 = Color(0xFF7A5C12);
  static const yellowInk3 = Color(0xFF6D5A2F);

  static const orange = Color(0xFFF0871F);
  static const orangeHover = Color(0xFFD2700F);
  static const orangeChipBg = Color(0xFFFFF1E2);
  static const orangeChipInk = Color(0xFFA2500C);

  static const cancelledDot = Color(0xFFE4DDD1);
  static const cancelledDot2 = Color(0xFFDCD4C6);
  static const rowBg = Color(0xFFFDFCF9);
}

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return ThemeData(
    useMaterial3: true,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.orange,
      secondary: AppColors.yellow,
      surface: AppColors.card,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: AppFonts.body,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      // Sewarna dengan latar utama. surfaceTint & scrolledUnderElevation
      // dimatikan supaya Material 3 tidak menaburkan warna elevasi saat konten
      // digulung ke belakang app bar.
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      foregroundColor: AppColors.ink,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    dividerColor: AppColors.line,
  );
}
