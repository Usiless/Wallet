import '../../transactions/domain/ledger_models.dart';

final class PaymentReminderSettings {
  const PaymentReminderSettings({
    this.enabled = true,
    this.daysBefore = 3,
    this.hour = 9,
    this.minute = 0,
    this.onDueDate = true,
  });
  final bool enabled, onDueDate;
  final int daysBefore, hour, minute;
  void validate() {
    if (daysBefore < 0 ||
        daysBefore > 60 ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException('Recordatorio inválido.');
    }
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'daysBefore': daysBefore,
    'hour': hour,
    'minute': minute,
    'onDueDate': onDueDate,
  };
  factory PaymentReminderSettings.fromJson(Map j) => PaymentReminderSettings(
    enabled: j['enabled'] as bool,
    daysBefore: j['daysBefore'] as int,
    hour: j['hour'] as int,
    minute: j['minute'] as int,
    onDueDate: j['onDueDate'] as bool,
  );
}

final class PendingPayment {
  PendingPayment(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get planId => data['planId'] as String;
  int get installmentNumber => data['installmentNumber'] as int;
  int get installmentCount => data['installmentCount'] as int;
  int get amountMinor => data['amountMinor'] as int;
  DateTime get dueDate => DateTime.parse(data['dueDate'] as String);
  String get accountId => data['accountId'] as String;
  String? get merchantId => data['merchantId'] as String?;
  String get description => data['description'] as String;
  String get note => data['note'] as String;
  String? get sourceReference => data['sourceReference'] as String?;
  PaymentChannel get paymentChannel =>
      PaymentChannel.values.byName(data['paymentChannel'] as String);
  int get revision => data['revision'] as int;
  bool get cancelled => data['cancelled'] as bool;
  List<Map<String, dynamic>> get payments => (data['payments'] as List)
      .map((p) => Map<String, dynamic>.from(p as Map))
      .toList();
  List<Map<String, dynamic>>? effectivePayments;
  int? effectivePaidMinor;
  int get paidMinor =>
      effectivePaidMinor ??
      payments.fold(0, (n, p) => n + (p['amountMinor'] as int));
  int get remainingMinor => cancelled
      ? 0
      : amountMinor - paidMinor - (data['carriedMinor'] as int? ?? 0);
  List<SplitDraft> get splits => (data['splits'] as List)
      .map(
        (s) => SplitDraft(
          categoryId: s['categoryId'] as String,
          amountMinor: s['amountMinor'] as int,
        ),
      )
      .toList();
  Map<String, int> get remainingSplits {
    final result = <String, int>{
      for (final s in splits) s.categoryId: s.amountMinor,
    };
    for (final payment in effectivePayments ?? payments) {
      for (final part in payment['splits'] as List? ?? []) {
        final id = part['categoryId'] as String;
        result[id] = (result[id] ?? 0) - (part['amountMinor'] as int);
      }
    }
    for (final part in data['carriedSplits'] as List? ?? []) {
      final id = part['categoryId'] as String;
      result[id] = (result[id] ?? 0) - (part['amountMinor'] as int);
    }
    result.removeWhere((_, amount) => amount <= 0);
    final total = result.values.fold<int>(0, (sum, amount) => sum + amount);
    if (total != remainingMinor && total > 0) {
      var allocated = 0;
      final keys = result.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        final amount = i == keys.length - 1
            ? remainingMinor - allocated
            : remainingMinor * result[keys[i]]! ~/ total;
        result[keys[i]] = amount;
        allocated += amount;
      }
      result.removeWhere((_, amount) => amount <= 0);
    }
    return result;
  }

  PaymentReminderSettings get reminders =>
      PaymentReminderSettings.fromJson(data['reminders'] as Map);
}
