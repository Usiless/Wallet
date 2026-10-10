import 'package:finanzas_locales/core/money/allocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('allocateCumulative', () {
    test('reparte 100 en 1:1:1 sin perder ni crear guaraníes', () {
      expect(allocateCumulative(100, [1, 1, 1]), [33, 33, 34]);
    });
    test('conserva exactamente el importe con pesos desiguales', () {
      for (final amount in [1, 7, 999, 1000001]) {
        final parts = allocateCumulative(amount, [3, 0, 17, 5]);
        expect(parts.fold<int>(0, (a, b) => a + b), amount);
        expect(parts[1], 0);
      }
    });
    test('sin peso total devuelve ceros', () {
      expect(allocateCumulative(500, [0, 0]), [0, 0]);
      expect(allocateCumulative(500, []), isEmpty);
    });
  });

  group('allocateLastRemainder', () {
    test('cada parte redondea hacia abajo y la última absorbe el resto', () {
      expect(allocateLastRemainder(100, [1, 1, 1]), [33, 33, 34]);
      expect(allocateLastRemainder(10, [1, 2]), [3, 7]);
    });
    test('usa el denominador indicado', () {
      expect(allocateLastRemainder(50, [30, 70], total: 100), [15, 35]);
    });
    test('conserva exactamente el importe', () {
      final parts = allocateLastRemainder(1000001, [5, 11, 13]);
      expect(parts.fold<int>(0, (a, b) => a + b), 1000001);
    });
  });
}
