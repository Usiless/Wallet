import 'package:finanzas_locales/core/notifications/payment_reminder_bridge.dart';
import 'package:finanzas_locales/core/notifications/payment_reminder_coordinator.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/reminder_cache');
  const bridge = PaymentReminderBridge(channel: channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final now = DateTime(2030, 1, 1);
  List<PendingPayment> payments() => [
    PendingPayment({
      'id': 'service',
      'description': 'Service',
      'dueDate': '2030-01-20T00:00:00.000',
      'amountMinor': 10000,
      'revision': 0,
      'cancelled': false,
      'payments': <Object>[],
      'reminders': const PaymentReminderSettings().toJson(),
    }),
  ];
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'identical foreground data skips replacement but resume refreshes it',
    () async {
      var replacements = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        replacements++;
        return true;
      });
      final coordinator = PaymentReminderCoordinator();
      expect(await coordinator.synchronize(bridge, payments(), now: now), true);
      expect(await coordinator.synchronize(bridge, payments(), now: now), true);
      expect(replacements, 1);
      // Android permissions/time/window may change while the app is away.
      expect(
        await coordinator.synchronize(
          bridge,
          payments(),
          now: now,
          force: true,
        ),
        true,
      );
      expect(replacements, 2);
      expect(await coordinator.synchronize(bridge, [], now: now), true);
      expect(
        replacements,
        3,
        reason: 'restore/payment removal must clear the native agenda',
      );
    },
  );

  test('failed storage replacement is retried for identical data', () async {
    var replacements = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      replacements++;
      if (replacements == 1)
        throw PlatformException(code: 'storage_unavailable');
      return true;
    });
    final coordinator = PaymentReminderCoordinator();
    await expectLater(
      coordinator.synchronize(bridge, payments(), now: now),
      throwsA(isA<PlatformException>()),
    );
    expect(await coordinator.synchronize(bridge, payments(), now: now), true);
    expect(replacements, 2);
  });
}
