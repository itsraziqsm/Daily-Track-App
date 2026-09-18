import 'package:intl/intl.dart';

/// Zona waktu Indonesia. Ketiganya offset tetap terhadap UTC dan Indonesia
/// tidak menerapkan DST, jadi cukup penjumlahan offset — tidak perlu basis
/// data zona waktu IANA.
enum AppTimeZone { wib, wita, wit }

extension AppTimeZoneInfo on AppTimeZone {
  Duration get offset => switch (this) {
        AppTimeZone.wib => const Duration(hours: 7),
        AppTimeZone.wita => const Duration(hours: 8),
        AppTimeZone.wit => const Duration(hours: 9),
      };

  String get code => switch (this) {
        AppTimeZone.wib => 'WIB',
        AppTimeZone.wita => 'WITA',
        AppTimeZone.wit => 'WIT',
      };

  String get label => switch (this) {
        AppTimeZone.wib => 'Waktu Indonesia Barat',
        AppTimeZone.wita => 'Waktu Indonesia Tengah',
        AppTimeZone.wit => 'Waktu Indonesia Timur',
      };

  String get sample => switch (this) {
        AppTimeZone.wib => 'UTC+7 · Jakarta, Medan, Pontianak',
        AppTimeZone.wita => 'UTC+8 · Makassar, Denpasar, Balikpapan',
        AppTimeZone.wit => 'UTC+9 · Jayapura, Ambon, Ternate',
      };

  static AppTimeZone fromName(String? name) {
    return AppTimeZone.values.firstWhere(
      (z) => z.name == name,
      orElse: () => AppTimeZone.wib,
    );
  }
}

/// Sumber tunggal waktu aplikasi. Semua perhitungan jadwal memakai zona yang
/// dipilih pengguna, bukan zona waktu perangkat.
class AppTime {
  AppTime._();

  static AppTimeZone zone = AppTimeZone.wib;

  static DateTime now() => DateTime.now().toUtc().add(zone.offset);

  static String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// Menit ke-berapa dalam sehari menurut zona aktif (0–1439).
  static int minutesOfDay() {
    final n = now();
    return n.hour * 60 + n.minute;
  }
}
