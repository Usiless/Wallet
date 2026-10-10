import 'package:finanzas_locales/features/budgets/domain/budget_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = BudgetCalculator();

  test('calcula consumo neto y umbrales', () {
    final progress = calculator.progress(
      targetMinor: 1000000,
      expenseAmounts: const [500000, 350000],
      refundAmounts: const [50000],
    );
    expect(progress.consumedMinor, 800000);
    expect(progress.remainingMinor, 200000);
    expect(progress.triggeredThresholds, [50, 80]);
  });
}
