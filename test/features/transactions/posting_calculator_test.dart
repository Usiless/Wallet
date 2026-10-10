import 'package:finanzas_locales/core/errors/app_exception.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/domain/posting_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = PostingCalculator();
  const bank = AccountSnapshot(
    id: 'bank',
    type: AccountType.bank,
    currencyCode: 'PYG',
  );
  const savings = AccountSnapshot(
    id: 'savings',
    type: AccountType.savings,
    currencyCode: 'PYG',
  );
  const cash = AccountSnapshot(
    id: 'cash',
    type: AccountType.cash,
    currencyCode: 'PYG',
  );
  const card = AccountSnapshot(
    id: 'card',
    type: AccountType.creditCard,
    currencyCode: 'PYG',
  );
  final now = DateTime.utc(2026, 7, 19);

  TransactionDraft draft(
    TransactionType type, {
    String? from,
    String? to,
    List<SplitDraft> splits = const [],
  }) => TransactionDraft(
    type: type,
    amount: const Money(100000),
    occurredAt: now,
    fromAccountId: from,
    toAccountId: to,
    splits: splits,
  );

  test('gasto bancario disminuye el activo', () {
    final postings = calculator.calculate(
      draft(TransactionType.expense, from: bank.id),
      from: bank,
    );
    expect(postings.single.deltaMinor, -100000);
  });

  test('compra con tarjeta aumenta deuda y no toca banco', () {
    final postings = calculator.calculate(
      draft(TransactionType.expense, from: card.id),
      from: card,
    );
    expect(postings, hasLength(1));
    expect(postings.single.accountId, card.id);
    expect(postings.single.deltaMinor, 100000);
  });

  test(
    'pago parcial o total de tarjeta es transferencia con dos deltas negativos',
    () {
      final postings = calculator.calculate(
        draft(TransactionType.transfer, from: bank.id, to: card.id),
        from: bank,
        to: card,
      );
      expect(postings.map((posting) => posting.deltaMinor), [-100000, -100000]);
    },
  );

  test('transferir a ahorro no crea gasto', () {
    final postings = calculator.calculate(
      draft(TransactionType.transfer, from: bank.id, to: savings.id),
      from: bank,
      to: savings,
    );
    expect(postings.map((posting) => posting.deltaMinor), [-100000, 100000]);
  });

  test('retiro y gasto de efectivo no duplican consumo', () {
    final withdrawal = calculator.calculate(
      draft(TransactionType.transfer, from: bank.id, to: cash.id),
      from: bank,
      to: cash,
    );
    final purchase = calculator.calculate(
      draft(TransactionType.expense, from: cash.id),
      from: cash,
    );
    expect(withdrawal.map((posting) => posting.deltaMinor), [-100000, 100000]);
    expect(purchase.single.deltaMinor, -100000);
  });

  test('reembolso revierte activo o deuda de tarjeta', () {
    final bankRefund = calculator.calculate(
      draft(TransactionType.refund, to: bank.id),
      to: bank,
    );
    final cardRefund = calculator.calculate(
      draft(TransactionType.refund, to: card.id),
      to: card,
    );
    expect(bankRefund.single.deltaMinor, 100000);
    expect(cardRefund.single.deltaMinor, -100000);
  });

  test('divisiones deben sumar exactamente', () {
    expect(
      () => calculator.calculate(
        draft(
          TransactionType.expense,
          from: bank.id,
          splits: const [
            SplitDraft(categoryId: 'a', amountMinor: 40000),
            SplitDraft(categoryId: 'b', amountMinor: 50000),
          ],
        ),
        from: bank,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      calculator.calculate(
        draft(
          TransactionType.expense,
          from: bank.id,
          splits: const [
            SplitDraft(categoryId: 'a', amountMinor: 40000),
            SplitDraft(categoryId: 'b', amountMinor: 60000),
          ],
        ),
        from: bank,
      ),
      hasLength(1),
    );
  });

  test('un pendiente no afecta saldos', () {
    final pending = TransactionDraft(
      type: TransactionType.expense,
      amount: const Money(100000),
      occurredAt: now,
      status: TransactionStatus.pending,
      fromAccountId: bank.id,
    );
    expect(calculator.calculate(pending, from: bank), isEmpty);
  });
}
