import 'package:intl/intl.dart';

enum MoneyDirection { owed, owe, settled }

class Money {
  const Money(this.minorUnits, this.currency);
  final int minorUnits;
  final String currency;

  /// The largest amount PayCal accepts, in minor units.
  ///
  /// 2^53 - 1 is the exact-integer range of an IEEE-754 double. Staying
  /// inside it keeps every amount representable as an exact integer, so
  /// parsing, validation and formatting all agree on the same value.
  static const int maxMinorUnits = 9007199254740991;

  /// Formats minor units as an exact decimal amount.
  ///
  /// The amount is split with truncating integer division, so no float is
  /// involved and no digit is lost for large amounts. The sign is carried by
  /// the whole part, which also keeps the minimum 64-bit integer safe.
  ///
  /// [int.remainder] is used for the fraction because `%` always returns a
  /// non-negative value for a positive divisor, which would turn a negative
  /// amount into a positive one.
  static String format(int minorUnits, String currency) {
    final symbol = _symbol(currency);
    final sign = minorUnits < 0 ? '-' : '';
    final whole = minorUnits ~/ 100;
    final fraction = minorUnits.remainder(100);
    final wholeText = NumberFormat.decimalPattern().format(whole.abs());
    final fractionText = fraction.abs().toString().padLeft(2, '0');
    return '$sign$symbol$wholeText.$fractionText';
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
        return code.toUpperCase();
    }
  }

  /// Parses "250.50" -> 25050 minor units. Returns null on invalid.
  ///
  /// The sign belongs to the whole amount, so "-0.50" is -50 minor units and
  /// never +50. Amounts that cannot be represented exactly as integer minor
  /// units are rejected instead of silently wrapping around.
  static int? tryParseToMinor(String input) {
    final cleaned = input.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    var negative = false;
    var body = cleaned;
    if (body.startsWith('-')) {
      negative = true;
      body = body.substring(1);
    } else if (body.startsWith('+')) {
      body = body.substring(1);
    }
    if (body.isEmpty) return null;
    final parts = body.split('.');
    if (parts.length > 2) return null;
    if (!RegExp(r'^\d+$').hasMatch(parts[0])) return null;
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;
    var fraction = 0;
    if (parts.length == 2) {
      final f = parts[1];
      if (!RegExp(r'^\d{1,2}$').hasMatch(f)) return null;
      fraction = int.parse(f.length == 1 ? '${f}0' : f);
    }
    if (whole > maxMinorUnits ~/ 100) return null;
    final magnitude = whole * 100 + fraction;
    if (magnitude > maxMinorUnits) return null;
    return negative ? -magnitude : magnitude;
  }
}
