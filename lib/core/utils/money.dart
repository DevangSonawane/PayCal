import 'package:intl/intl.dart';

enum MoneyDirection { owed, owe, settled }

class Money {
  const Money(this.minorUnits, this.currency);
  final int minorUnits;
  final String currency;

  static String format(int minorUnits, String currency) {
    final symbol = _symbol(currency);
    final value = minorUnits / 100.0;
    final f = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return f.format(value);
  }

  static String _symbol(String code) {
    switch (code.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '$code ';
    }
  }

  /// Parses "250.50" -> 25050 minor units. Returns null on invalid.
  static int? tryParseToMinor(String input) {
    final cleaned = input.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final parts = cleaned.split('.');
    if (parts.length > 2) return null;
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;
    var frac = 0;
    if (parts.length == 2) {
      var f = parts[1];
      if (f.length > 2 || int.tryParse(f) == null) return null;
      if (f.length == 1) f = '${f}0';
      if (f.isEmpty) f = '00';
      frac = int.parse(f);
    }
    return whole * 100 + (whole >= 0 ? frac : -frac);
  }
}
