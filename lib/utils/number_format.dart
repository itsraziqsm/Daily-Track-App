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
