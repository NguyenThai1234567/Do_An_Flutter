import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  static final _numberFormat = NumberFormat('#,###', 'vi_VN');
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('HH:mm dd/MM/yyyy');

  static String formatVND(num? value) {
    if (value == null) return '0 ₫';
    return _currencyFormat.format(value).trim();
  }

  /// VND Safe-Zone formatter (Prevents RenderFlex overflow on tight mobile screens)
  static String formatVndSafe(num? value, {bool compact = false}) {
    if (value == null) return '0 ₫';
    final abs = value.abs();
    if (compact) {
      if (abs >= 1000000000) {
        final billions = value / 1000000000;
        return '${billions.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')} Tỷ ₫';
      } else if (abs >= 10000000) {
        final millions = value / 1000000;
        return '${millions.toStringAsFixed(1).replaceAll(RegExp(r'\.?0+$'), '')} Tr ₫';
      }
    }
    return _currencyFormat.format(value).trim();
  }

  static String formatNumber(num? value) {
    if (value == null) return '0';
    return _numberFormat.format(value);
  }

  static double parseNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 0.0;
    final clean = value.replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  static int parseInt(String? value) {
    if (value == null || value.trim().isEmpty) return 0;
    final clean = value.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(clean) ?? 0;
  }

  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return _dateTimeFormat.format(dateTime);
  }
}

/// Custom TextInputFormatter that dynamically formats numerical input with dot (.) thousands separators (e.g. 1.000.000).
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final cleanDigits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Limit to 15 digits to avoid 64-bit integer overflow
    final limitedDigits = cleanDigits.length > 15 ? cleanDigits.substring(0, 15) : cleanDigits;

    final number = int.tryParse(limitedDigits);
    if (number == null) {
      return oldValue;
    }

    final newFormattedString = _formatter.format(number);

    // Count how many digits existed before the cursor in newValue
    int digitsBeforeCursor = 0;
    for (int i = 0; i < newValue.selection.end && i < newValue.text.length; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    if (digitsBeforeCursor > limitedDigits.length) {
      digitsBeforeCursor = limitedDigits.length;
    }

    // Map to position in newFormattedString
    int newCursorPos = 0;
    int digitsCounted = 0;
    for (int i = 0; i < newFormattedString.length; i++) {
      if (digitsCounted >= digitsBeforeCursor) {
        break;
      }
      if (RegExp(r'\d').hasMatch(newFormattedString[i])) {
        digitsCounted++;
      }
      newCursorPos = i + 1;
    }

    return TextEditingValue(
      text: newFormattedString,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }
}
