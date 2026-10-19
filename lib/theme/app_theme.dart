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

/// Palet aplikasi, dipasang sebagai [ThemeExtension] supaya tiap widget
/// mengambil warnanya dari tema yang sedang aktif lewat [AppColors.of].
///
/// Varian terang diambil persis dari desain "Daily Track" (claude.ai/design
/// handoff). Varian gelap menurunkannya: latar cokelat hangat yang sangat gelap
/// alih-alih hitam netral, kuning dan oranye aksen tetap sama, dan permukaan
/// bernuansa kuning/oranye diganti versi redupnya dengan tinta yang terang.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Brightness brightness;

  final Color bg;
  final Color card;
  final Color ink;
  final Color inkMuted;
  final Color inkMuted2;
  final Color inkMuted3;
  final Color line;
  final Color lineSoft;
  final Color lineSoft2;

  final Color yellow;
  final Color yellowBg;
  final Color yellowBorder;
  final Color yellowBorder2;
  final Color yellowChipBg;
  final Color yellowChipBorder;
  final Color yellowInk;
  final Color yellowInk2;
  final Color yellowInk3;

  /// Tinta di atas tombol kuning penuh.
  final Color onYellow;

  final Color orange;
  final Color orangeChipBg;
  final Color orangeChipInk;

  final Color cancelledDot;
  final Color cancelledDot2;
  final Color rowBg;

  /// Kartu yang sedang disorot: kegiatan berjalan, toggle menyala, catatan.
  final Color cardWarm;

  /// Kartu kegiatan yang dibatalkan, sedikit lebih redup dari [card].
  final Color cardCancelled;

  /// Kotak tersisip di dalam kartu, mis. baris alasan pembatalan.
  final Color inset;

  /// Jalur bar progres dan ring di atas kartu kuning.
  final Color track;

  /// Ikon pudar di lingkaran status yang dibatalkan.
  final Color iconFaint;

  /// Tanggal kalender tanpa catatan.
  final Color dayMuted;

  /// Ikon tab yang tidak aktif.
  final Color navIdle;

  /// Warna dasar bayangan.
  final Color shadow;

  const AppColors({
    required this.brightness,
    required this.bg,
    required this.card,
    required this.ink,
    required this.inkMuted,
    required this.inkMuted2,
    required this.inkMuted3,
    required this.line,
    required this.lineSoft,
    required this.lineSoft2,
    required this.yellow,
    required this.yellowBg,
    required this.yellowBorder,
    required this.yellowBorder2,
    required this.yellowChipBg,
    required this.yellowChipBorder,
    required this.yellowInk,
    required this.yellowInk2,
    required this.yellowInk3,
    required this.onYellow,
    required this.orange,
    required this.orangeChipBg,
    required this.orangeChipInk,
    required this.cancelledDot,
    required this.cancelledDot2,
    required this.rowBg,
    required this.cardWarm,
    required this.cardCancelled,
    required this.inset,
    required this.track,
    required this.iconFaint,
    required this.dayMuted,
    required this.navIdle,
    required this.shadow,
  });

  static const light = AppColors(
    brightness: Brightness.light,
    bg: Color(0xFFF4F2EE),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF2B251E),
    inkMuted: Color(0xFF6F6555),
    inkMuted2: Color(0xFF7D7263),
    inkMuted3: Color(0xFF6B6153),
    line: Color(0xFFF1EBE0),
    lineSoft: Color(0xFFECE5D9),
    lineSoft2: Color(0xFFF4F0E8),
    yellow: Color(0xFFFFC93C),
    yellowBg: Color(0xFFFFFBF0),
    yellowBorder: Color(0xFFFFEDBF),
    yellowBorder2: Color(0xFFFFDE8F),
    yellowChipBg: Color(0xFFFFF4D1),
    yellowChipBorder: Color(0xFFFFE08A),
    yellowInk: Color(0xFF5C4408),
    yellowInk2: Color(0xFF7A5C12),
    yellowInk3: Color(0xFF6D5A2F),
    onYellow: Color(0xFF4A3708),
    orange: Color(0xFFF0871F),
    orangeChipBg: Color(0xFFFFF1E2),
    orangeChipInk: Color(0xFFA2500C),
    cancelledDot: Color(0xFFE4DDD1),
    cancelledDot2: Color(0xFFDCD4C6),
    rowBg: Color(0xFFFDFCF9),
    cardWarm: Color(0xFFFFFCF3),
    cardCancelled: Color(0xFFFAF8F4),
    inset: Color(0xFFF7F4EE),
    track: Color(0xFFF3E6C8),
    iconFaint: Color(0xFFD8CFBE),
    dayMuted: Color(0xFFD0C7B6),
    navIdle: Color(0xFF9C927F),
    shadow: Color(0xFF2B251E),
  );

  static const dark = AppColors(
    brightness: Brightness.dark,
    bg: Color(0xFF16130F),
    card: Color(0xFF221E18),
    ink: Color(0xFFF3EDE3),
    inkMuted: Color(0xFFB2A794),
    inkMuted2: Color(0xFFA09581),
    inkMuted3: Color(0xFFBDB2A0),
    line: Color(0xFF332D24),
    lineSoft: Color(0xFF3E372D),
    lineSoft2: Color(0xFF2C271F),
    yellow: Color(0xFFFFC93C),
    yellowBg: Color(0xFF282012),
    yellowBorder: Color(0xFF4A3B17),
    yellowBorder2: Color(0xFF6A5319),
    yellowChipBg: Color(0xFF3A2E12),
    yellowChipBorder: Color(0xFF6B5419),
    yellowInk: Color(0xFFFFE4A3),
    yellowInk2: Color(0xFFF2CE78),
    yellowInk3: Color(0xFFD8BE85),
    onYellow: Color(0xFF4A3708),
    orange: Color(0xFFF0871F),
    orangeChipBg: Color(0xFF3B2514),
    orangeChipInk: Color(0xFFFFAE6B),
    cancelledDot: Color(0xFF4A4237),
    cancelledDot2: Color(0xFF574E42),
    rowBg: Color(0xFF29241D),
    cardWarm: Color(0xFF2A2215),
    cardCancelled: Color(0xFF1C1914),
    inset: Color(0xFF2B261F),
    track: Color(0xFF41351A),
    iconFaint: Color(0xFF6B6153),
    dayMuted: Color(0xFF5E5549),
    navIdle: Color(0xFF7E7465),
    shadow: Color(0xFF000000),
  );

  bool get isDark => brightness == Brightness.dark;

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  // Peralihan terang↔gelap memudarkan tiap warna, bukan melompat.
  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: c(bg, other.bg),
      card: c(card, other.card),
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      inkMuted2: c(inkMuted2, other.inkMuted2),
      inkMuted3: c(inkMuted3, other.inkMuted3),
      line: c(line, other.line),
      lineSoft: c(lineSoft, other.lineSoft),
      lineSoft2: c(lineSoft2, other.lineSoft2),
      yellow: c(yellow, other.yellow),
      yellowBg: c(yellowBg, other.yellowBg),
      yellowBorder: c(yellowBorder, other.yellowBorder),
      yellowBorder2: c(yellowBorder2, other.yellowBorder2),
      yellowChipBg: c(yellowChipBg, other.yellowChipBg),
      yellowChipBorder: c(yellowChipBorder, other.yellowChipBorder),
      yellowInk: c(yellowInk, other.yellowInk),
      yellowInk2: c(yellowInk2, other.yellowInk2),
      yellowInk3: c(yellowInk3, other.yellowInk3),
      onYellow: c(onYellow, other.onYellow),
      orange: c(orange, other.orange),
      orangeChipBg: c(orangeChipBg, other.orangeChipBg),
      orangeChipInk: c(orangeChipInk, other.orangeChipInk),
      cancelledDot: c(cancelledDot, other.cancelledDot),
      cancelledDot2: c(cancelledDot2, other.cancelledDot2),
      rowBg: c(rowBg, other.rowBg),
      cardWarm: c(cardWarm, other.cardWarm),
      cardCancelled: c(cardCancelled, other.cardCancelled),
      inset: c(inset, other.inset),
      track: c(track, other.track),
      iconFaint: c(iconFaint, other.iconFaint),
      dayMuted: c(dayMuted, other.dayMuted),
      navIdle: c(navIdle, other.navIdle),
      shadow: c(shadow, other.shadow),
    );
  }
}

ThemeData buildAppTheme(AppColors colors) {
  final isDark = colors.isDark;
  final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  return ThemeData(
    useMaterial3: true,
    brightness: colors.brightness,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: colors.bg,
    extensions: [colors],
    colorScheme: base.colorScheme.copyWith(
      primary: colors.orange,
      onPrimary: Colors.white,
      secondary: colors.yellow,
      onSecondary: colors.onYellow,
      surface: colors.card,
      onSurface: colors.ink,
      onSurfaceVariant: colors.inkMuted,
      outline: colors.lineSoft,
      outlineVariant: colors.line,
      surfaceContainerHighest: colors.rowBg,
      // Snackbar memakai warna kebalikan permukaan.
      inverseSurface: isDark ? colors.lineSoft : colors.ink,
      onInverseSurface: isDark ? colors.ink : colors.bg,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: AppFonts.body,
      bodyColor: colors.ink,
      displayColor: colors.ink,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.orange,
      selectionColor: colors.yellow.withValues(alpha: 0.4),
      selectionHandleColor: colors.orange,
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: colors.inkMuted2, fontWeight: FontWeight.w600),
    ),
    dialogTheme: DialogThemeData(backgroundColor: colors.card, surfaceTintColor: Colors.transparent),
    timePickerTheme: TimePickerThemeData(backgroundColor: colors.card),
    appBarTheme: AppBarTheme(
      // Sewarna dengan latar utama. surfaceTint & scrolledUnderElevation
      // dimatikan supaya Material 3 tidak menaburkan warna elevasi saat konten
      // digulung ke belakang app bar.
      backgroundColor: colors.bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      foregroundColor: colors.ink,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    ),
    dividerColor: colors.line,
  );
}
