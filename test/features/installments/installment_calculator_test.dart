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
}
