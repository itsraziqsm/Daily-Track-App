import 'package:flutter/services.dart';

import 'number_format.dart';

/// Memformat isian rupiah dengan pemisah ribuan saat diketik, mis. 4500000
/// menjadi 4.500.000.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final value = parseRupiah(newValue.text);
    if (value == null) return const TextEditingValue();
    final text = formatNumber(value);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
