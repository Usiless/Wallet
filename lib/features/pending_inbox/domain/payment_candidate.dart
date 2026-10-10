final class PaymentCandidate {
  const PaymentCandidate({
    required this.amountMinor,
    required this.currencyCode,
    required this.rawMerchant,
    required this.normalizedMerchant,
    required this.occurredAt,
    required this.source,
    required this.amountConfidence,
    required this.merchantConfidence,
    required this.accountConfidence,
    required this.overallConfidence,
    required this.reason,
    required this.fingerprint,
    this.suggestedAccountId,
    this.detectedAlias,
    this.transactionType = 'expense',
    this.suggestedFromAccountId,
    this.suggestedToAccountId,
    this.requiresCounterparty = false,
  });

  final int? amountMinor;
  final String? currencyCode;
  final String? rawMerchant;
  final String? normalizedMerchant;
  final String? suggestedAccountId;
  final String? detectedAlias;
  final String transactionType;
  final String? suggestedFromAccountId;
  final String? suggestedToAccountId;
  final bool requiresCounterparty;
  final DateTime occurredAt;
  final String source;
  final double amountConfidence;
  final double merchantConfidence;
  final double accountConfidence;
  final double overallConfidence;
  final String reason;
  final String fingerprint;

  bool get hasMinimumFields => amountMinor != null && currencyCode != null;
}

enum DedupAction { create, updateExisting, exactDuplicate }

final class DedupResult {
  const DedupResult(this.action, this.reason);

  final DedupAction action;
  final String reason;
}
