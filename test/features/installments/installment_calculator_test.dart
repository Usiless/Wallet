import 'package:finanzas_locales/features/installments/domain/installment_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = InstallmentCalculator();

  test('reparte enteros y ajusta solamente la última cuota', () {
    final schedule = calculator.schedule(
      totalMinor: 100,
      count: 3,
      firstPeriod: DateTime.utc(2026, 12, 10),
    );
    expect(schedule.map((entry) => entry.amountMinor), [33, 33, 34]);
    expect(schedule.map((entry) => entry.periodStart), [
      DateTime.utc(2026, 12, 10, 12),
      DateTime.utc(2027, 1, 10, 12),
      DateTime.utc(2027, 2, 10, 12),
    ]);
    expect(schedule.fold<int>(0, (sum, entry) => sum + entry.amountMinor), 100);
  });

  test('reparto entero exacto con el resto en la última', () {
    expect(evenInstallmentAmounts(101, 2), [50, 51]);
    expect(evenInstallmentAmounts(100, 3), [33, 33, 34]);
    expect(evenInstallmentAmounts(500, 1), [500]);
    for (final total in [1000000, 99999, 7]) {
      expect(
        evenInstallmentAmounts(total, 7).fold<int>(0, (a, b) => a + b),
        total,
      );
    }
  });

  test('día ancla sin deriva en meses cortos y cruce de año', () {
    final first = DateTime(2026, 10, 31);
    final days = [for (var i = 0; i < 5; i++) monthlyAnchorDate(first, i)];
    expect(days.map((d) => '${d.year}-${d.month}-${d.day}'), [
      '2026-10-31',
      '2026-11-30',
      '2026-12-31',
      '2027-1-31',
      '2027-2-28',
    ]);
  });
}
