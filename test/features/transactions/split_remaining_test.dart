import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TransactionFormState form({
    required String amount,
    required List<SplitEntry> splits,
  }) => TransactionFormState(
    type: TransactionType.expense,
    occurredAt: DateTime(2026, 10, 5, 12),
    splitEnabled: true,
    amountText: amount,
    splits: splits,
  );

  test('restante es importe menos divisiones', () {
    final state = form(
      amount: '100.000',
      splits: const [
        (id: 0, categoryId: 'a', amountText: '30.000'),
        (id: 1, categoryId: 'b', amountText: '20.000'),
      ],
    );
    expect(state.splitRemainingMinor, 50000);
  });

  test('excedente es negativo cuando las divisiones superan el importe', () {
    final state = form(
      amount: '100.000',
      splits: const [
        (id: 0, categoryId: 'a', amountText: '80.000'),
        (id: 1, categoryId: 'b', amountText: '30.000'),
      ],
    );
    expect(state.splitRemainingMinor, -10000);
  });

  test('divisiones vacías o inválidas cuentan como cero', () {
    final state = form(
      amount: '100.000',
      splits: const [
        (id: 0, categoryId: 'a', amountText: ''),
        (id: 1, categoryId: 'b', amountText: 'abc'),
        (id: 2, categoryId: 'c', amountText: '10.000'),
      ],
    );
    expect(state.splitRemainingMinor, 90000);
  });

  test('sin importe válido no hay restante', () {
    final state = form(
      amount: '',
      splits: const [(id: 0, categoryId: 'a', amountText: '10.000')],
    );
    expect(state.splitRemainingMinor, isNull);
  });
}
