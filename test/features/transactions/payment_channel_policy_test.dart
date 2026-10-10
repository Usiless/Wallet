import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/domain/payment_channel_policy.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'efectivo admite efectivo y otro; excluye tarjetas, Wallet y pago online',
    () {
      expect(
        PaymentChannelPolicy.allowed(
          TransactionType.expense,
          from: AccountType.cash,
        ),
        [PaymentChannel.cash, PaymentChannel.other],
      );
      for (final type in [
        AccountType.bank,
        AccountType.savings,
        AccountType.creditCard,
      ]) {
        final allowed = PaymentChannelPolicy.allowed(
          TransactionType.expense,
          from: type,
        );
        expect(allowed, isNot(contains(PaymentChannel.cash)));
        expect(
          allowed,
          containsAll([
            PaymentChannel.physicalCard,
            PaymentChannel.googleWalletContactless,
            PaymentChannel.onlineCard,
          ]),
        );
      }
    },
  );
  test(
    'transferencias dependen de ambas cuentas y no admiten compras con tarjeta',
    () {
      expect(
        PaymentChannelPolicy.allowed(
          TransactionType.transfer,
          from: AccountType.cash,
          to: AccountType.cash,
        ),
        [PaymentChannel.cash, PaymentChannel.other],
      );
      expect(
        PaymentChannelPolicy.allowed(
          TransactionType.transfer,
          from: AccountType.bank,
          to: AccountType.creditCard,
        ),
        [PaymentChannel.bankTransfer, PaymentChannel.other],
      );
    },
  );
  test(
    'validación central rechaza Wallet con efectivo y acepta canales antiguos',
    () {
      const cash = AccountSnapshot(
        id: 'cash',
        type: AccountType.cash,
        currencyCode: 'PYG',
      );
      final invalid = TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(10000),
        occurredAt: DateTime.now(),
        fromAccountId: cash.id,
        paymentChannel: PaymentChannel.googleWalletContactless,
      );
      expect(
        () => PaymentChannelPolicy.validate(invalid, from: cash),
        throwsException,
      );
      expect(
        PaymentChannelPolicy.canonical(PaymentChannel.debitCard),
        PaymentChannel.physicalCard,
      );
      expect(
        PaymentChannelPolicy.canonical(PaymentChannel.physicalCreditCard),
        PaymentChannel.physicalCard,
      );
    },
  );
}
