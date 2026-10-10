import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/notification_envelope.dart';
import 'package:finanzas_locales/core/notifications/notification_ingestion_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/pending_inbox/presentation/candidate_review_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'edición muestra moneda agrupada, valida y devuelve unidades correctas',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      late PaymentCandidateRecord candidate;
      late List<AccountRecord> accounts;
      await tester.runAsync(() async {
        await AccountsService(database).createAccount(
          const CreateAccountDraft(name: 'Mi cuenta', type: AccountType.bank),
        );
        accounts = await database.select(database.accounts).get();
        candidate =
            (await NotificationIngestionService(
              database,
              LedgerService(database),
              settings: SettingsRepository(database),
            ).ingest(
              NotificationEnvelope(
                version: 1,
                packageName: 'com.google.android.gms',
                notificationKey: 'edit',
                id: 1,
                postTime: DateTime(2026, 10, 4),
                title: 'ECOP',
                text: 'PYG79500 with TARJETA ••5962',
              ),
            ))!;
      });
      CandidateReview? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showDialog<CandidateReview>(
                      context: context,
                      builder: (_) => CandidateReviewDialog(
                        candidate: candidate,
                        accounts: accounts,
                        merchants: const [],
                        categories: const [],
                        defaults: const {},
                        initialMerchant: '__new__',
                        fromAccountId: accounts.single.id,
                      ),
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('PYG '), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '79.500',
      );
      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.tap(find.text('Registrar gasto'));
      await tester.pumpAndSettle();
      expect(find.text('El importe debe ser mayor que cero.'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(find.byType(TextFormField).first, '120000');
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '120.000',
      );
      await tester.tap(find.text('Registrar gasto'));
      await tester.pumpAndSettle();
      expect(result!.amount.minorUnits, 120000);
      expect(result!.merchantName, 'ECOP');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(database.close);
    },
  );
}
