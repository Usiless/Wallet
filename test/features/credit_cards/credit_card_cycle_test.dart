import 'package:finanzas_locales/features/credit_cards/domain/credit_card_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = CreditCardCycleCalculator();

  test('calcula cierre y vencimiento cruzando mes', () {
    final dates = calculator.nextDates(
      localDate: DateTime(2026, 7, 25),
      closingDay: 20,
      dueDay: 3,
    );
    expect(dates.nextClosing, DateTime(2026, 8, 20));
    expect(dates.nextDue, DateTime(2026, 9, 3));
  });

  test('limita días inexistentes al final del mes', () {
    final dates = calculator.nextDates(
      localDate: DateTime(2026, 2, 1),
      closingDay: 31,
      dueDay: 31,
    );
    expect(dates.nextClosing, DateTime(2026, 2, 28));
    expect(dates.nextDue, DateTime(2026, 3, 31));
  });
}
