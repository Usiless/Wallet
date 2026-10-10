import 'package:flutter/services.dart';

import 'money.dart';

/// Keeps PYG amounts grouped while preserving the cursor's position in digits.
final class PygInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    if (!RegExp(r'^[0-9.\s]*$').hasMatch(newValue.text)) return oldValue;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final amount = int.tryParse(digits);
    if (amount == null) return oldValue;
    final formatted = Money(amount).format(withCode: false).trim();
    int position(int offset) {
      final safe = offset.clamp(0, newValue.text.length);
      final rightDigits = newValue.text
          .substring(safe)
          .replaceAll(RegExp(r'\D'), '')
          .length;
      var remaining = rightDigits;
      var cursor = formatted.length;
      while (cursor > 0 && remaining > 0) {
        cursor--;
        if (RegExp(r'\d').hasMatch(formatted[cursor])) remaining--;
      }
      if (safe > 0 && RegExp(r'\d').hasMatch(newValue.text[safe - 1])) {
        while (cursor > 0 && !RegExp(r'\d').hasMatch(formatted[cursor - 1])) {
          cursor--;
        }
      }
      return cursor;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: position(newValue.selection.baseOffset),
        extentOffset: position(newValue.selection.extentOffset),
      ),
    );
  }
}
