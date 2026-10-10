import '../../../core/money/money.dart';

enum AccountType { bank, savings, cash, creditCard }

enum TransactionType { income, expense, transfer, adjustment, refund }

enum TransactionStatus { pending, confirmed, ignored, reversed, deleted }

enum TransactionSource {
  manual,
  developerTest,
  googleWalletNotification,
  csv,
  smsNotification,
  recurring,
  adjustment,
}

enum PaymentChannel {
  cash,
  physicalCard,
  debitCard,
  physicalCreditCard,
  googleWalletContactless,
  onlineCard,
  bankTransfer,
  other,
}

final class AccountSnapshot {
  const AccountSnapshot({
    required this.id,
    required this.type,
    required this.currencyCode,
  });

  final String id;
  final AccountType type;
  final String currencyCode;

  bool get isLiability => type == AccountType.creditCard;
}

final class SplitDraft {
  const SplitDraft({
    required this.categoryId,
    required this.amountMinor,
    this.note,
  });

  final String categoryId;
  final int amountMinor;
  final String? note;
}

final class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amount,
    required this.occurredAt,
    this.status = TransactionStatus.confirmed,
    this.source = TransactionSource.manual,
    this.fromAccountId,
    this.toAccountId,
    this.merchantId,
    this.description = '',
    this.note = '',
    this.paymentChannel = PaymentChannel.other,
    this.splits = const [],
    this.externalFingerprint,
    this.sourceReference,
    this.importBatchId,
    this.parentTransactionId,
    this.timeZone = 'America/Asuncion',
  });

  final TransactionType type;
  final Money amount;
  final DateTime occurredAt;
  final TransactionStatus status;
  final TransactionSource source;
  final String? fromAccountId;
  final String? toAccountId;
  final String? merchantId;
  final String description;
  final String note;
  final PaymentChannel paymentChannel;
  final List<SplitDraft> splits;
  final String? externalFingerprint;
  final String? sourceReference;
  final String? importBatchId;
  final String? parentTransactionId;
  final String timeZone;
}

final class PostingDraft {
  const PostingDraft({required this.accountId, required this.deltaMinor});

  final String accountId;
  final int deltaMinor;
}

final class AccountBalance {
  const AccountBalance({
    required this.id,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.balanceMinor,
    required this.includeInAvailableMoney,
    required this.includeInNetWorth,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currencyCode;
  final int balanceMinor;
  final bool includeInAvailableMoney;
  final bool includeInNetWorth;
}
