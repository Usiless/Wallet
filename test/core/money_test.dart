import 'package:finanzas_locales/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money PYG', () {
    test('normaliza formatos paraguayos sin double', () {
      expect(Money.parse('PYG 145,500').minorUnits, 145500);
      expect(Money.parse('145.500').minorUnits, 145500);
      expect(Money.parse('145500').minorUnits, 145500);
      expect(Money.parse('75,000.00').minorUnits, 75000);
    });

    test('opera solo monedas iguales', () {
      expect(const Money(100) + const Money(25), const Money(125));
      expect(
        () => const Money(100) + const Money(25, currencyCode: 'USD'),
        throwsArgumentError,
      );
    });

    test('rechaza texto y ambigüedad no numérica', () {
      expect(() => Money.parse('1e9'), throwsFormatException);
      expect(() => Money.parse(''), throwsFormatException);
    });
  });
}
