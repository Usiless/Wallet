import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:finanzas_locales/app/app.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/router.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Reads extends QueryInterceptor {
  int pendingLists = 0;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('FROM "app_settings"') &&
        args.contains('pending_payment:v1:%')) {
      pendingLists++;
    }
    return executor.runSelect(statement, args);
  }
}

void main() {
  testWidgets('unrelated settings do not replace the unchanged native agenda', (
    tester,
  ) async {
    final reads = _Reads();
    final database = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(reads),
    );
    final settings = SettingsRepository(database);
    await settings.write('diagnostic_mode', 'false');
    await settings.write('sms_notifications_enabled', 'false');
    final account = await AccountsService(database).createAccount(
      const CreateAccountDraft(name: 'Bank', type: AccountType.bank),
    );
    final service = PendingPaymentService(database);
    final dues = await service.createPlan(
      amountMinor: 10000,
      installmentCount: 1,
      firstDueDate: DateTime(2030, 1, 20),
      accountId: account,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Ready')),
        ),
      ],
    );
    var replacements = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const reminders = MethodChannel('finanzas_locales/payment_reminders');
    const captures = MethodChannel('finanzas_locales/notification_listener');
    messenger.setMockMethodCallHandler(reminders, (call) async {
      if (call.method == 'replaceSchedule') {
        replacements++;
        return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(captures, (call) async {
      if (call.method == 'queuedEnvelopes') return <Object>[];
      return null;
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(reminders, null);
      messenger.setMockMethodCallHandler(captures, null);
      router.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          routerProvider.overrideWithValue(router),
        ],
        child: const FinanzasApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    expect(replacements, greaterThan(0));
    replacements = 0;
    reads.pendingLists = 0;
    await settings.write('unrelated_preference', 'changed');
    await tester.pumpAndSettle();
    expect(reads.pendingLists, 1, reason: 'reuse the hydrated provider value');
    expect(replacements, 0, reason: 'the reminder payload did not change');

    await service.updateReminders(
      dues.single.id,
      expectedRevision: dues.single.revision,
      settings: const PaymentReminderSettings(hour: 10),
    );
    await tester.pumpAndSettle();
    expect(
      replacements,
      1,
      reason: 'an actual reminder edit must reach Android',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
