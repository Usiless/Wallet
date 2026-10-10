import 'package:finanzas_locales/core/notifications/payment_reminder_bridge.dart';
import 'package:finanzas_locales/core/notifications/payment_reminder_coordinator.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/payment_reminders');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  PendingPayment payment(String id, {bool cancelled = false, int paid = 0}) =>
      PendingPayment({
        'id': id,
        'description': 'Servicio',
        'dueDate': '2026-10-10T00:00:00.000',
        'amountMinor': 100000,
        'cancelled': cancelled,
        'revision': 0,
        'payments': paid == 0
            ? <Map<String, dynamic>>[]
            : [
                {'amountMinor': paid},
              ],
        'reminders': const PaymentReminderSettings().toJson(),
      });
  test(
    'conserva identidad de avisos transcurridos al cambiar otro pago',
    () async {
      final bridge = PaymentReminderBridge(channel: channel);
      await synchronizePaymentReminders(bridge, [
        payment('active'),
        payment('other'),
      ], now: DateTime(2026, 10, 6));
      final initial = ((calls.last.arguments as Map)['requests'] as List)
          .where((r) => (r as Map)['obligationId'] == 'active')
          .toList();
      await synchronizePaymentReminders(bridge, [
        payment('active'),
        payment('other', paid: 100000),
      ], now: DateTime(2026, 10, 11));
      expect((calls.last.arguments as Map)['requests'], initial);
      await synchronizePaymentReminders(bridge, [
        payment('active', paid: 100000),
      ], now: DateTime(2026, 10, 11));
      expect((calls.last.arguments as Map)['requests'], isEmpty);
    },
  );
  test(
    'configuración antigua inválida no retiene agenda de pagos saldados',
    () async {
      final bridge = PaymentReminderBridge(channel: channel);
      final invalid = payment('legacy');
      invalid.data['reminders'] = const PaymentReminderSettings(daysBefore: 61)
          .toJson();
      expect(
        await synchronizePaymentReminders(bridge, [
          invalid,
          payment('valid'),
          payment('paid', paid: 100000),
        ], now: DateTime(2026, 10, 6)),
        false,
      );
      final requests = (calls.single.arguments as Map)['requests'] as List;
      expect(requests.length, 2);
      expect(
        requests.every((r) => (r as Map)['obligationId'] == 'valid'),
        isTrue,
      );
    },
  );
  test(
    'agenda solo pendiente y reemplaza con vacío tras saldar o restaurar',
    () async {
      final bridge = PaymentReminderBridge(channel: channel);
      await synchronizePaymentReminders(bridge, [
        payment('active'),
        payment('paid', paid: 100000),
        payment('cancelled', cancelled: true),
      ], now: DateTime(2026, 10, 6));
      final requests = (calls.single.arguments as Map)['requests'] as List;
      expect(requests.length, 2);
      expect(
        requests.every((r) => (r as Map)['obligationId'] == 'active'),
        isTrue,
      );
      expect(requests.map((r) => (r as Map)['localDateTime']), [
        '2026-10-07T09:00:00.000',
        '2026-10-10T09:00:00.000',
      ]);
      calls.clear();
      await synchronizePaymentReminders(bridge, [], now: DateTime(2026, 10, 6));
      expect((calls.single.arguments as Map)['requests'], isEmpty);
    },
  );
}
