import 'dart:async';

import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/accounts/presentation/accounts_screen.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/shared/widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <String, Stream<List<AccountBalance>> Function()>{
    'cargando': () => StreamController<List<AccountBalance>>().stream,
    'con error': () => Stream.error(Exception('falla')),
  };
  for (final entry in cases.entries) {
    testWidgets(
      'tarjeta sin saldo inicial mientras los saldos están ${entry.key}',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await tester.runAsync(
          () => AccountsService(db).createAccount(
            const CreateAccountDraft(
              name: 'Banco',
              type: AccountType.bank,
              initialBalanceMinor: 777000,
            ),
          ),
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            accountBalancesProvider.overrideWith((ref) => entry.value()),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: AccountsScreen()),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump();
        }
        expect(find.text('Banco'), findsOneWidget);
        expect(find.byType(MoneyText), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    required AppDatabase db,
    required String accountId,
    required Stream<List<AccountBalance>> Function() balances,
  }) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        accountBalancesProvider.overrideWith((ref) => balances()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: AccountsScreen(accountId: accountId)),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    });
  }

  testWidgets('detalle con saldos en carga no muestra el saldo inicial', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await tester.runAsync(
      () => AccountsService(db).createAccount(
        const CreateAccountDraft(
          name: 'Banco',
          type: AccountType.bank,
          initialBalanceMinor: 777000,
        ),
      ),
    );
    await pumpDetail(
      tester,
      db: db,
      accountId: id!,
      balances: () => StreamController<List<AccountBalance>>().stream,
    );
    expect(find.text('Saldo registrado'), findsOneWidget);
    expect(find.byType(MoneyText), findsNothing);
  });

  testWidgets(
    'cuenta archivada sin fila de saldo muestra guion, no el saldo inicial',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await tester.runAsync(() async {
        final service = AccountsService(db);
        final accountId = await service.createAccount(
          const CreateAccountDraft(
            name: 'Vieja',
            type: AccountType.bank,
            initialBalanceMinor: 777000,
          ),
        );
        await service.setArchived(accountId, true);
        return accountId;
      });
      await pumpDetail(
        tester,
        db: db,
        accountId: id!,
        balances: () => Stream.value(const <AccountBalance>[]),
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.byType(MoneyText), findsNothing);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Saldo no disponible'), findsOneWidget);
      semantics.dispose();
    },
  );
}
