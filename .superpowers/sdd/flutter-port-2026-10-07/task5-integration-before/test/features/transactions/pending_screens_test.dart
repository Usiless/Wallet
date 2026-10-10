import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/payments/presentation/payments_screen.dart';
import 'package:flutter/material.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Listado vacío no ofrece confirmar pagos inexistentes', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          pendingPaymentsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: PaymentsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin pagos pendientes'), findsOneWidget);
    expect(find.text('Confirmar pago'), findsNothing);
  });
  testWidgets(
    'Pago parcial conserva saldo pendiente y no ofrece traslado en última cuota',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = await tester.runAsync(
        () => AccountsService(db).createAccount(
          const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
        ),
      );
      final service = PendingPaymentService(db);
      final payment = (await tester.runAsync(
        () => service.createPlan(
          amountMinor: 100000,
          installmentCount: 1,
          firstDueDate: DateTime(2026, 10, 8),
          accountId: account!,
          description: 'Servicio',
        ),
      ))!.single;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(home: PaymentDetailScreen(paymentId: payment.id)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trasladar resto a la siguiente cuota'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('paid-amount')),
        '40000',
      );
      await tester.ensureVisible(find.text('Confirmar pago'));
      await tester.tap(find.text('Confirmar pago'));
      await tester.pumpAndSettle();
      expect((await service.read(payment.id))!.remainingMinor, 60000);
      expect(
        (await db.select(db.ledgerTransactions).get()).single.amountMinor,
        40000,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Cancelación exige confirmación y no registra gasto, 320px texto 2x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = await tester.runAsync(
        () => AccountsService(db).createAccount(
          const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
        ),
      );
      final service = PendingPaymentService(db);
      final payment = (await tester.runAsync(
        () => service.createPlan(
          amountMinor: 100000,
          installmentCount: 2,
          firstDueDate: DateTime(2026, 10, 8),
          accountId: account!,
          description: 'Servicio',
        ),
      ))!.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: PaymentDetailScreen(paymentId: payment.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancelar pendiente'));
      await tester.tap(find.text('Cancelar pendiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect((await service.read(payment.id))!.cancelled, false);
      await tester.ensureVisible(find.text('Cancelar pendiente'));
      await tester.tap(find.text('Cancelar pendiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar cancelación'));
      await tester.pumpAndSettle();
      expect((await service.read(payment.id))!.cancelled, true);
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Pago parcial traslada resto a cuota existente y rechaza importe inválido',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = await tester.runAsync(
        () => AccountsService(db).createAccount(
          const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
        ),
      );
      final service = PendingPaymentService(db);
      final payments = (await tester.runAsync(
        () => service.createPlan(
          amountMinor: 100000,
          installmentCount: 2,
          firstDueDate: DateTime(2026, 10, 8),
          accountId: account!,
          description: 'Servicio',
        ),
      ))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: PaymentDetailScreen(paymentId: payments.first.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('paid-amount')), '0');
      await tester.ensureVisible(find.text('Confirmar pago'));
      await tester.tap(find.text('Confirmar pago'));
      await tester.pumpAndSettle();
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
      expect(find.textContaining('Importe inválido'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('paid-amount')),
        '20000',
      );
      await tester.ensureVisible(
        find.text('Trasladar resto a la siguiente cuota'),
      );
      await tester.tap(find.text('Trasladar resto a la siguiente cuota'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirmar pago'));
      await tester.tap(find.text('Confirmar pago'));
      await tester.pumpAndSettle();
      expect((await service.read(payments.first.id))!.remainingMinor, 0);
      expect((await service.read(payments.last.id))!.remainingMinor, 80000);
      expect(
        (await db.select(db.ledgerTransactions).get()).single.amountMinor,
        20000,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Edición futura y recordatorios se conservan sin registrar pagos',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = await tester.runAsync(
        () => AccountsService(db).createAccount(
          const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
        ),
      );
      final service = PendingPaymentService(db);
      final payments = (await tester.runAsync(
        () => service.createPlan(
          amountMinor: 100000,
          installmentCount: 2,
          firstDueDate: DateTime(2026, 10, 8),
          accountId: account!,
          description: 'Servicio',
        ),
      ))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: PaymentDetailScreen(paymentId: payments.first.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Editar pendiente'));
      await tester.tap(find.text('Editar pendiente'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Importe previsto'),
        '60000',
      );
      await tester.tap(find.text('Esta cuota y las siguientes'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect((await service.read(payments.last.id))!.amountMinor, 60000);
      await tester.ensureVisible(find.text('Recordatorios'));
      await tester.tap(find.text('Recordatorios'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Recordatorios'),
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect((await service.read(payments.last.id))!.reminders.enabled, false);
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Filtros muestran cuotas parcialmente pagadas y canceladas como prototipo',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = await tester.runAsync(
        () => AccountsService(db).createAccount(
          const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
        ),
      );
      final service = PendingPaymentService(db);
      await tester.runAsync(() async {
        final p = (await service.createPlan(
          amountMinor: 100000,
          installmentCount: 1,
          firstDueDate: DateTime(2026, 10, 8),
          accountId: account!,
          description: 'Parcial',
        )).single;
        await service.pay(
          id: p.id,
          expectedRevision: 0,
          amountMinor: 20000,
          paidAt: DateTime(2026, 10, 8),
          accountId: account,
        );
        final c = (await service.createPlan(
          amountMinor: 100000,
          installmentCount: 1,
          firstDueDate: DateTime(2026, 10, 8),
          accountId: account,
          description: 'Cancelado',
        )).single;
        await service.cancel(c.id, expectedRevision: 0);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: PaymentsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Parcial'), findsOneWidget);
      expect(find.text('Cancelado'), findsNothing);
      await tester.tap(find.text('Con pagos'));
      await tester.pumpAndSettle();
      expect(find.text('Parcial'), findsOneWidget);
      expect(find.text('Cancelado'), findsNothing);
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      expect(find.text('Parcial'), findsOneWidget);
      expect(find.text('Cancelado'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  for (final archived in [false, true]) {
    testWidgets(
      'La próxima cuota propone cuenta del último pago activo, archivada=$archived',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final service = PendingPaymentService(db);
        late String bank, cash;
        late String nextId;
        await tester.runAsync(() async {
          bank = await AccountsService(db).createAccount(
            const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
          );
          cash = await AccountsService(db).createAccount(
            const CreateAccountDraft(name: 'Efectivo', type: AccountType.cash),
          );
          final payments = await service.createPlan(
            amountMinor: 100000,
            installmentCount: 2,
            firstDueDate: DateTime(2026, 10, 8),
            accountId: bank,
          );
          await service.pay(
            id: payments.first.id,
            expectedRevision: 0,
            amountMinor: 50000,
            paidAt: DateTime(2026, 10, 8),
            accountId: cash,
          );
          nextId = payments.last.id;
          if (archived)
            await db.customStatement(
              'UPDATE accounts SET is_archived = 1 WHERE id = ?',
              [cash],
            );
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(home: PaymentDetailScreen(paymentId: nextId)),
          ),
        );
        await tester.pumpAndSettle();
        final field = tester.widget<DropdownButtonFormField<String>>(
          find.widgetWithText(DropdownButtonFormField<String>, 'Cuenta'),
        );
        expect(field.initialValue, archived ? bank : cash);
        if (!archived) {
          await tester.tap(
            find.widgetWithText(DropdownButtonFormField<String>, 'Cuenta'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Banco').last);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<DropdownButtonFormField<String>>(
                  find.widgetWithText(
                    DropdownButtonFormField<String>,
                    'Cuenta',
                  ),
                )
                .initialValue,
            bank,
          );
        }
        expect(
          (await tester.runAsync(() => service.read(nextId)))!.accountId,
          bank,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
