import 'package:intl/intl.dart';

/// Seluruh perhitungan waktu aplikasi memakai Waktu Indonesia Barat (UTC+7),
/// terlepas dari zona waktu perangkat.
const Duration wibOffset = Duration(hours: 7);

DateTime wibNow() => DateTime.now().toUtc().add(wibOffset);

String wibDateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Menit ke-berapa dalam sehari menurut WIB (0–1439).
int wibMinutesOfDay() {
  final now = wibNow();
  return now.hour * 60 + now.minute;
}
