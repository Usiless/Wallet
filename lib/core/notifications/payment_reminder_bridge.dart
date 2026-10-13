import 'package:flutter/services.dart';

final class PaymentReminderRequest {
  const PaymentReminderRequest({
    required this.id,
    required this.obligationId,
    required this.title,
    required this.body,
    required this.localDateTime,
    this.revision,
    this.channel,
  });
  final String id, obligationId, title, body;
  final DateTime localDateTime;
  final int? revision;

  /// Android channel; absent means payment reminders.
  final String? channel;
  Map<String, Object> toMap() {
    if (id.isEmpty || obligationId.isEmpty || localDateTime.isUtc) {
      throw ArgumentError('El recordatorio requiere identidad y hora local.');
    }
    return {
      'id': id,
      'obligationId': obligationId,
      'title': title,
      'body': body,
      'localDateTime': localDateTime.toIso8601String(),
      'revision': ?revision,
      'channel': ?channel,
    };
  }
}

final class PaymentReminderBridge {
  const PaymentReminderBridge({
    this.channel = const MethodChannel('finanzas_locales/payment_reminders'),
  });
  final MethodChannel channel;
  Future<bool> permission() async =>
      await channel.invokeMethod<bool>('permission') ?? false;
  Future<bool> requestPermission() async =>
      await channel.invokeMethod<bool>('requestPermission') ?? false;

  /// Replaces the entire agenda, including while permission is denied.
  Future<bool> reconcile(List<PaymentReminderRequest> requests) async =>
      await channel.invokeMethod<bool>('replaceSchedule', {
        'requests': requests.map((r) => r.toMap()).toList(),
      }) ??
      false;
  Future<String?> consumeOpenAction() =>
      channel.invokeMethod<String>('consumeOpenAction');
}
