import 'package:intl/intl.dart';

final _format = NumberFormat('#,##0.##', 'id_ID');

/// Angka gaya Indonesia tanpa nol berlebih, mis. 72,5 atau 1.250.
String formatNumber(double value) => _format.format(value);

/// Membaca angka ketikan pengguna. Koma maupun titik diterima sebagai
/// pemisah desimal ("72,5" dan "72.5" sama-sama 72.5).
double? parseNumber(String text) {
  final cleaned = text.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

/// Rupiah tanpa desimal, mis. "Rp4.500.000"; negatif ditulis "-Rp250.000".
String formatRupiah(double value) => _rupiah.format(value);

/// Rupiah ringkas untuk angka besar, mis. "Rp45,2 jt" atau "Rp1,3 M".
String formatRupiahShort(double value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs >= 1e9) return '${sign}Rp${formatNumber(double.parse((abs / 1e9).toStringAsFixed(1)))} M';
  if (abs >= 1e6) return '${sign}Rp${formatNumber(double.parse((abs / 1e6).toStringAsFixed(1)))} jt';
  return formatRupiah(value);
}

/// Membaca jumlah rupiah yang diketik: hanya angka yang dihitung, jadi
/// "4.500.000", "4500000", dan "Rp 4.500.000" sama-sama 4.500.000.
double? parseRupiah(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : double.parse(digits);
}
