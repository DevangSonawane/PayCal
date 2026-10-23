import 'package:flutter_test/flutter_test.dart';
import 'package:paycal/core/utils/money.dart';

void main() {
  group('tryParseToMinor', () {
    test('parses positive amounts', () {
      expect(Money.tryParseToMinor('250'), 25000);
      expect(Money.tryParseToMinor('250.50'), 25050);
      expect(Money.tryParseToMinor('250.5'), 25050);
      expect(Money.tryParseToMinor('0.50'), 50);
      expect(Money.tryParseToMinor('0.05'), 5);
      expect(Money.tryParseToMinor('+12.34'), 1234);
      expect(Money.tryParseToMinor(' 12.34 '), 1234);
      expect(Money.tryParseToMinor('1,234.56'), 123456);
      expect(Money.tryParseToMinor('007.50'), 750);
    });

    test('parses negative amounts with the sign attached to the whole part', () {
      expect(Money.tryParseToMinor('-250'), -25000);
      expect(Money.tryParseToMinor('-250.50'), -25050);
      expect(Money.tryParseToMinor('-250.5'), -25050);
      expect(Money.tryParseToMinor('-1.50'), -150);
      expect(Money.tryParseToMinor('-0.05'), -5);
    });

    test('a negative sub-unit amount never becomes a positive amount', () {
      // Regression: the sign used to be taken from the parsed whole part, so
      // "-0.50" parsed as +50 and turned a charge into income.
      expect(Money.tryParseToMinor('-0.50'), -50);
      expect(Money.tryParseToMinor('-0.5'), -50);
      expect(Money.tryParseToMinor('-0.01'), -1);
      expect(Money.tryParseToMinor('-0.00'), 0);
      expect(Money.tryParseToMinor('-0'), 0);
      for (final input in ['-0.50', '-0.5', '-0.01', '-0.99']) {
        expect(
          Money.tryParseToMinor(input),
          isNot(greaterThan(0)),
          reason: '$input must not parse to a positive amount',
        );
      }
    });

    test('parses zero', () {
      expect(Money.tryParseToMinor('0'), 0);
      expect(Money.tryParseToMinor('0.00'), 0);
      expect(Money.tryParseToMinor('0.0'), 0);
    });

    test('handles decimal boundaries', () {
      expect(Money.tryParseToMinor('0.01'), 1);
      expect(Money.tryParseToMinor('0.99'), 99);
      expect(Money.tryParseToMinor('1.01'), 101);
      expect(Money.tryParseToMinor('9999999999999.99'), 999999999999999);
      expect(
        Money.tryParseToMinor('${Money.maxMinorUnits ~/ 100}.91'),
        Money.maxMinorUnits,
      );
    });

    test('rejects invalid input', () {
      for (final input in [
        '',
        '   ',
        '-',
        '+',
        '--5',
        '++5',
        'abc',
        '1.2.3',
        '1.234',
        '1.2a',
        'a.5',
        '.50',
        '1.',
        '1..2',
        '1 2',
        '5-',
        '1e3',
        '₹100',
      ]) {
        expect(
          Money.tryParseToMinor(input),
          isNull,
          reason: '"$input" must not parse',
        );
      }
    });

    test('rejects amounts that would overflow', () {
      expect(Money.tryParseToMinor('90071992547409.92'), isNull);
      expect(Money.tryParseToMinor('90071992547410.00'), isNull);
      expect(Money.tryParseToMinor('-90071992547409.92'), isNull);
      expect(Money.tryParseToMinor('99999999999999999999'), isNull);
      expect(
        Money.tryParseToMinor('9223372036854775807'),
        isNull,
        reason: 'multiplying by 100 must not silently wrap around',
      );
    });
  });

  group('format', () {
    test('formats minor units exactly, without a float round trip', () {
      expect(Money.format(25050, 'INR'), '₹250.50');
      expect(Money.format(0, 'INR'), '₹0.00');
      expect(Money.format(5, 'INR'), '₹0.05');
      expect(Money.format(123456, 'INR'), '₹1,234.56');
      expect(Money.format(-123450, 'INR'), '-₹1,234.50');
      expect(Money.format(-50, 'INR'), '-₹0.50');
    });

    test('keeps every digit of a large amount', () {
      expect(
        Money.format(9007199254740991, 'INR'),
        '₹90,071,992,547,409.91',
      );
      expect(Money.format(4503599627370495, 'INR'), '₹45,035,996,273,704.95');
    });

    test('uses the currency symbol and drops the padded fallback', () {
      expect(Money.format(100, 'USD'), '\$1.00');
      expect(Money.format(100, 'EUR'), '€1.00');
      expect(Money.format(100, 'GBP'), '£1.00');
      expect(Money.format(100, 'JPY'), 'JPY1.00');
    });

    test('parsing and formatting agree on sign and minor units', () {
      for (final input in ['250.50', '-250.50', '0', '-0.01', '0.05']) {
        final minor = Money.tryParseToMinor(input);
        expect(minor, isNotNull);
        final formatted = Money.format(minor!, 'INR');
        final withoutSymbol = formatted.replaceAll('₹', '');
        final reparsed = Money.tryParseToMinor(withoutSymbol);
        expect(
          reparsed,
          minor,
          reason: '$input must round trip through format',
        );
      }
    });
  });
}
