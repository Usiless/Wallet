import '../../../core/errors/app_exception.dart';
import 'ledger_models.dart';

abstract final class PaymentChannelPolicy {
  static PaymentChannel canonical(PaymentChannel channel) => switch (channel) {
    PaymentChannel.debitCard ||
    PaymentChannel.physicalCreditCard => PaymentChannel.physicalCard,
    _ => channel,
  };

  static List<PaymentChannel> allowed(
    TransactionType type, {
    AccountType? from,
    AccountType? to,
  }) {
    if (type == TransactionType.transfer) {
      if (from == null || to == null) return [PaymentChannel.other];
      return [
        if (from == AccountType.cash && to == AccountType.cash)
          PaymentChannel.cash
        else
          PaymentChannel.bankTransfer,
        PaymentChannel.other,
      ];
    }
    final account = type == TransactionType.expense ? from : to ?? from;
    if (account == null) return [PaymentChannel.other];
    if (account == AccountType.cash) {
      return [PaymentChannel.cash, PaymentChannel.other];
    }
    return [
      PaymentChannel.physicalCard,
      PaymentChannel.googleWalletContactless,
      PaymentChannel.onlineCard,
      if (account != AccountType.creditCard) PaymentChannel.bankTransfer,
      PaymentChannel.other,
    ];
  }

  static void validate(
    TransactionDraft draft, {
    AccountSnapshot? from,
    AccountSnapshot? to,
  }) {
    if (!allowed(
      draft.type,
      from: from?.type,
      to: to?.type,
    ).contains(canonical(draft.paymentChannel))) {
      throw const ValidationException(
        'El canal no es compatible con las cuentas elegidas.',
      );
    }
  }
}
