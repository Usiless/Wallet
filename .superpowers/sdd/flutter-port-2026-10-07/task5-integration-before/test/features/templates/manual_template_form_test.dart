import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:finanzas_locales/features/templates/scheduled_template_service.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Plantilla programada edita recordatorios antes de guardar', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await tester.runAsync(
      () => ManualTemplateService(db).save('Servicio', {
        'type': 'expense',
        'amountMinor': 10000,
        'channel': 'other',
        'schedule': {
          'enabled': false,
          'frequency': 'monthly',
          'nextDate': '2030-11-04',
        },
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountsProvider.overrideWith((ref) => Stream.value([])),
          categoriesProvider.overrideWith((ref) => Stream.value([])),
          merchantsProvider.overrideWith((ref) => Stream.value([])),
          merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          home: TransactionFormScreen(savedTemplateId: id!, editTemplate: true),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar plantilla'));
    await tester.tap(find.text('Guardar plantilla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preparar pagos pendientes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Recordatorios'));
    await tester.tap(find.text('Recordatorios'));
    await tester.pumpAndSettle();
    expect(find.text('Días antes'), findsNothing);
    expect(find.textContaining('Registra al abrir'), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => ManualTemplateService(db).read(id)))!
          .fields['reminders'],
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  for (final automatic in [false, true]) {
    testWidgets(
      'usar y guardar plantilla con movimiento, automática=$automatic',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        const reminderChannel = MethodChannel(
          'finanzas_locales/payment_reminders',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          reminderChannel,
          (_) async => false,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            reminderChannel,
            null,
          ),
        );
        late String merchantId;
        late List<AccountRecord> accounts;
        await tester.runAsync(() async {
          final account = await AccountsService(db).createAccount(
            const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
          );
          accounts = await db.select(db.accounts).get();
          merchantId = await MerchantService(db).findOrCreate('Alquiler');
          await ManualTemplateService(db).save('A ingreso', {
            'type': 'income',
            'amountMinor': 100,
            'to': account,
          });
          await ManualTemplateService(db).save('Alquiler', {
            'type': 'expense',
            'amountMinor': 120000,
            'from': account,
            'merchant': 'Nombre anterior',
            'merchantId': merchantId,
            'channel': 'bankTransfer',
            if (automatic)
              'schedule': {
                'enabled': true,
                'frequency': 'monthly',
                'nextDate': '2030-11-04',
              },
          });
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              accountsProvider.overrideWith((ref) => Stream.value(accounts)),
              categoriesProvider.overrideWith((ref) => Stream.value([])),
              merchantsProvider.overrideWith((ref) => Stream.value([])),
              merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: const MaterialApp(home: TransactionFormScreen()),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Usar plantilla'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        expect(
          find.text('Administrar plantillas y registros programados'),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.text('Alquiler')).dy,
          lessThan(tester.getTopLeft(find.text('A ingreso')).dy),
        );
        expect(find.text('Ingreso · Abrir y revisar'), findsOneWidget);
        if (automatic) {
          expect(
            find.textContaining('Mensual · Próximo registro:'),
            findsOneWidget,
          );
        }
        await tester.tap(find.text('Alquiler'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          '120.000',
        );
        expect(find.text('Banco'), findsOneWidget);
        await tester.runAsync(() async {
          expect(await db.select(db.ledgerTransactions).get(), isEmpty);
        });
        await tester.scrollUntilVisible(
          find.text('Guardar también como plantilla'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Guardar también como plantilla'));
        await tester.scrollUntilVisible(
          find.text('Guardar y crear otro'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Guardar y crear otro'));
        await tester.scrollUntilVisible(
          find.text('Guardar movimiento'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Guardar movimiento'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre de la plantilla'),
          automatic ? 'Netflix automático' : 'Alquiler variable',
        );
        if (automatic) {
          await tester.tap(find.text('Preparar pagos pendientes'));
          await tester.pumpAndSettle();
          expect(find.text('Mensual'), findsOneWidget);
          expect(find.text('Próxima fecha'), findsOneWidget);
        } else {
          await tester.tap(find.text('Recordar importe'));
        }
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final templates = await ManualTemplateService(db).list();
          expect(templates, hasLength(3));
          final saved = templates.firstWhere(
            (t) =>
                t.name ==
                (automatic ? 'Netflix automático' : 'Alquiler variable'),
          );
          expect(saved.fields['merchantId'], merchantId);
          expect(saved.fields['amountMinor'], automatic ? 120000 : null);
          expect((saved.fields['schedule'] as Map)['enabled'], automatic);
          expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
          if (automatic) {
            final result = await ScheduledTemplateService(db).processDue();
            expect(result.registered, ['Netflix automático']);
            final future = await PendingPaymentService(db).list();
            expect(future, hasLength(1));
            expect(future.single.amountMinor, 120000);
            expect(future.single.paidMinor, 0);
            expect(
              future.single.sourceReference,
              startsWith('scheduled:${saved.id}:'),
            );
            expect(
              (await ScheduledTemplateService(db).processDue()).registered,
              isEmpty,
            );
            expect(result.pending, isEmpty);
            expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
          }
        });
        if (automatic)
          expect(
            find.text('Guardado. Recordatorios sin permiso.'),
            findsOneWidget,
          );
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(db.close);
      },
    );
  }
}
