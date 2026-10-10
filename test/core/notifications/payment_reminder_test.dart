import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_locales/core/notifications/payment_reminder_bridge.dart';
import 'package:finanzas_locales/core/notifications/payment_reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'defaults plan local dates before and due, disabled and elapsed omitted',
    () {
      final result = const PaymentReminderScheduler().schedule([
        PaymentReminderInput(
          id: 'a',
          title: 'Servicio',
          dueDate: DateTime(2026, 11, 1),
        ),
        PaymentReminderInput(
          id: 'b',
          title: 'Otro',
          dueDate: DateTime(2026, 11, 1),
          enabled: false,
        ),
      ], now: DateTime(2026, 10, 1));
      expect(result.map((r) => r.localDateTime), [
        DateTime(2026, 10, 29, 9),
        DateTime(2026, 11, 1, 9),
      ]);
      expect(result.map((r) => r.id).toSet().length, 2);
      expect(
        const PaymentReminderScheduler().schedule([
          PaymentReminderInput(
            id: 'a',
            title: 'x',
            dueDate: DateTime(2026, 1, 1),
          ),
        ], now: DateTime(2026, 10, 1)),
        isEmpty,
      );
    },
  );
  test(
    'due day toggle omits due notice while zero days remains one notice',
    () {
      final scheduler = const PaymentReminderScheduler();
      final before = scheduler.schedule([
        PaymentReminderInput(
          id: 'a',
          title: 'x',
          dueDate: DateTime(2026, 11, 1),
          onDueDate: false,
        ),
      ], now: DateTime(2026, 10, 1));
      expect(before.single.localDateTime, DateTime(2026, 10, 29, 9));
      expect(
        scheduler.schedule([
          PaymentReminderInput(
            id: 'a',
            title: 'x',
            dueDate: DateTime(2026, 11, 1),
            daysBefore: 0,
            onDueDate: false,
          ),
        ], now: DateTime(2026, 10, 1)).length,
        1,
      );
      expect(
        () => scheduler.schedule([
          PaymentReminderInput(
            id: 'a',
            title: 'x',
            dueDate: DateTime(2026, 11, 1),
            daysBefore: 61,
          ),
        ], now: DateTime(2026, 10, 1)),
        throwsArgumentError,
      );
    },
  );
  test('custom zero days emits once and invalid configuration fails', () {
    final scheduler = const PaymentReminderScheduler();
    expect(
      scheduler
          .schedule([
            PaymentReminderInput(
              id: 'a',
              title: 'x',
              dueDate: DateTime(2026, 11, 1),
              daysBefore: 0,
              hour: 14,
              minute: 30,
            ),
          ], now: DateTime(2026, 10, 1))
          .single
          .localDateTime,
      DateTime(2026, 11, 1, 14, 30),
    );
    expect(
      () => scheduler.schedule([
        PaymentReminderInput(
          id: 'a',
          title: 'x',
          dueDate: DateTime(2026, 11, 1),
          hour: 24,
        ),
      ], now: DateTime(2026, 10, 1)),
      throwsArgumentError,
    );
  });
  test(
    'bridge replaces even empty schedules and preserves local wall clock',
    () async {
      const channel = MethodChannel('test/reminders');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'consumeOpenAction' ? 'obligation' : false;
          });
      const bridge = PaymentReminderBridge(channel: channel);
      expect(await bridge.permission(), false);
      expect(await bridge.requestPermission(), false);
      expect(
        await bridge.reconcile([
          PaymentReminderRequest(
            id: 'r',
            obligationId: 'o',
            title: 't',
            body: 'b',
            localDateTime: DateTime(2026, 11, 1, 9),
          ),
        ]),
        false,
      );
      expect((calls.last.arguments as Map)['requests'], [
        {
          'id': 'r',
          'obligationId': 'o',
          'title': 't',
          'body': 'b',
          'localDateTime': '2026-11-01T09:00:00.000',
        },
      ]);
      await bridge.reconcile([]);
      expect((calls.last.arguments as Map)['requests'], isEmpty);
      expect(await bridge.consumeOpenAction(), 'obligation');
    },
  );
}
