import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/installments/domain/installment_service.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/transactions/data/category_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lecturas que las pantallas piden a los servicios en lugar de consultar Drift.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('cuentas', () {
    test('lista las cuentas activas o todas, en orden de creación', () async {
      final service = AccountsService(db);
      await service.createAccount(
        const CreateAccountDraft(name: 'Primera', type: AccountType.bank),
      );
      final second = await service.createAccount(
        const CreateAccountDraft(name: 'Segunda', type: AccountType.cash),
      );
      await service.createAccount(
        const CreateAccountDraft(name: 'Tercera', type: AccountType.bank),
      );
      await service.setArchived(second, true);

      expect((await service.getAccounts()).map((a) => a.name), [
        'Primera',
        'Tercera',
      ]);
      expect(
        (await service.getAccounts(includeArchived: true)).map((a) => a.name),
        ['Primera', 'Segunda', 'Tercera'],
      );
    });

    test('devuelve el perfil de tarjeta solo para tarjetas', () async {
      final service = AccountsService(db);
      final bank = await service.createAccount(
        const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
      );
      final card = await service.createAccount(
        const CreateAccountDraft(
          name: 'Tarjeta',
          type: AccountType.creditCard,
          creditLimitMinor: 2000000,
          closingDay: 20,
          dueDay: 5,
        ),
      );

      expect(await service.creditCardProfile(bank), isNull);
      final profile = (await service.creditCardProfile(card))!;
      expect(profile.creditLimitMinor, 2000000);
      expect((profile.closingDay, profile.dueDay), (20, 5));
    });

    test('lista y elimina alias de una cuenta sin tocar los de otra', () async {
      final service = AccountsService(db);
      final first = await service.createAccount(
        const CreateAccountDraft(
          name: 'Banco',
          type: AccountType.bank,
          aliases: ['1234', '5678'],
        ),
      );
      final other = await service.createAccount(
        const CreateAccountDraft(
          name: 'Otra',
          type: AccountType.bank,
          aliases: ['9999'],
        ),
      );

      final aliases = await service.aliasesOf(first);
      expect(aliases.map((a) => a.alias), unorderedEquals(['1234', '5678']));
      await service.removeAlias(aliases.first.id);

      expect(await service.aliasesOf(first), hasLength(1));
      expect(await service.aliasesOf(other), hasLength(1));
      expect(await service.watchAliases().first, hasLength(2));
    });
  });

  group('comercios', () {
    test(
      'lista activos o todos y quita un alias sin borrar el comercio',
      () async {
        final service = MerchantService(db);
        final ecop = await service.findOrCreate('Ecop');
        final copaco = await service.findOrCreate('Copaco');
        await service.assignAlias('ECOP SA', ecop);
        await service.setArchived(copaco, true);

        expect((await service.listMerchants()).map((m) => m.id), [ecop]);
        expect(
          (await service.listMerchants(includeArchived: true)).map((m) => m.id),
          [ecop, copaco],
        );
        expect(
          (await service.watchMerchants(includeArchived: true).first).map(
            (m) => m.name,
          ),
          ['Copaco', 'Ecop'],
        );
        expect(await service.watchMerchants().first, hasLength(1));

        final alias = (await service.watchAliases().first).firstWhere(
          (a) => a.alias == 'ECOP SA',
        );
        await service.removeAlias(alias.id);
        expect(
          (await service.watchAliases().first).map((a) => a.alias),
          isNot(contains('ECOP SA')),
        );
        expect(await service.listMerchants(), hasLength(1));
      },
    );
  });

  group('categorías', () {
    test('lista activas o todas y busca por id', () async {
      final service = CategoryService(db);
      final food = await service.create('Alimentación', kind: 'expense');
      final old = await service.create('Antigua', kind: 'expense');
      await service.setArchived(old, true);

      expect((await service.list()).map((c) => c.id), [food]);
      expect((await service.list(includeArchived: true)).map((c) => c.id), [
        food,
        old,
      ]);
      expect((await service.find(old))!.name, 'Antigua');
      expect(await service.find('no-existe'), isNull);
    });
  });

  group('libro mayor', () {
    test(
      'devuelve el plan con sus cuotas en orden, o nada si no hay plan',
      () async {
        final bank = await AccountsService(db).createAccount(
          const CreateAccountDraft(
            name: 'Banco',
            type: AccountType.bank,
            initialBalanceMinor: 100,
          ),
        );
        final card = await AccountsService(db).createAccount(
          const CreateAccountDraft(
            name: 'Tarjeta',
            type: AccountType.creditCard,
            creditLimitMinor: 5000000,
          ),
        );
        final ledger = LedgerService(db);
        final plain = await ledger.create(
          TransactionDraft(
            type: TransactionType.expense,
            amount: const Money(50),
            occurredAt: DateTime(2026, 9, 1),
            fromAccountId: bank,
          ),
        );
        final financed = await ledger.create(
          TransactionDraft(
            type: TransactionType.expense,
            amount: const Money(90000),
            occurredAt: DateTime(2026, 9, 10),
            fromAccountId: card,
          ),
        );
        await InstallmentService(db).attachPlan(
          transactionId: financed,
          count: 3,
          firstPeriod: DateTime(2026, 9, 10),
        );
        final repository = LedgerRepository(db);

        expect(await repository.installmentsOf(plain), isNull);
        final installments = (await repository.installmentsOf(financed))!;
        expect(installments.plan.installmentCount, 3);
        expect(installments.entries.map((e) => e.installmentNumber), [1, 2, 3]);
        expect(installments.entries.map((e) => e.amountMinor), [
          30000,
          30000,
          30000,
        ]);
        expect(await repository.splitsOf(plain), isEmpty);
      },
    );
  });
}
