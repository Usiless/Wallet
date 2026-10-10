import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/notification_envelope.dart';
import 'package:finanzas_locales/core/notifications/notification_ingestion_service.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late NotificationIngestionService service;
  late SettingsRepository settings;
  late String account;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(db);
    await settings.write('notification_listener_enabled', 'true');
    service = NotificationIngestionService(
      db,
      LedgerService(db),
      settings: settings,
    );
    account = await AccountsService(db).createAccount(
      const CreateAccountDraft(
        name: 'Mi tarjeta',
        type: AccountType.creditCard,
        aliases: ['1234'],
        creditLimitMinor: 1000000,
      ),
    );
  });
  tearDown(() => db.close());
  NotificationEnvelope event(
    String key, {
    String merchant = 'ECOP OBLIGADO',
    String alias = '1234',
    int amount = 15000,
    bool update = false,
  }) => NotificationEnvelope(
    version: 1,
    packageName: 'com.google.android.apps.walletnfcrel',
    notificationKey: key,
    id: key.hashCode,
    postTime: DateTime.utc(2026, 10, 4, 12),
    title: merchant,
    text: 'PYG $amount · ••$alias',
    isUpdate: update,
  );

  test(
    'confirmar recuerda categoría; la próxima compra automática la usa',
    () async {
      final now = DateTime.now().toUtc();
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'fuel',
              name: 'Combustible',
              kind: 'expense',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final first = (await service.process(event('learn-category')))!;
      await service.confirm(
        first,
        fromAccountId: account,
        categoryId: 'fuel',
        rememberCategory: true,
      );
      final merchant = await db.select(db.merchants).getSingle();
      expect(await MerchantService(db).defaultCategory(merchant.id), 'fuel');
      await settings.write('wallet_auto_register', 'true');
      expect(
        (await service.process(event('use-category', amount: 19000)))!.status,
        'confirmed',
      );
      final splits = await db.select(db.transactionSplits).get();
      expect(splits.map((s) => s.categoryId), everyElement('fuel'));
      expect(splits.map((s) => s.amountMinor), containsAll([15000, 19000]));
      await MerchantService(db).rememberCategory(merchant.id, null);
      expect(await MerchantService(db).defaultCategory(merchant.id), isNull);
      expect(
        (await service.process(event('no-category', amount: 21000)))!.status,
        'confirmed',
      );
      expect(await db.select(db.transactionSplits).get(), hasLength(2));
    },
  );

  test(
    'categoría archivada no bloquea ni categoriza próximas compras',
    () async {
      final now = DateTime.now().toUtc();
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'fuel',
              name: 'Combustible',
              kind: 'expense',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final merchant = await MerchantService(db).findOrCreate('ECOP OBLIGADO');
      await MerchantService(db).rememberCategory(merchant, 'fuel');
      await (db.update(db.categories)..where((c) => c.id.equals('fuel'))).write(
        const CategoriesCompanion(isArchived: Value(true)),
      );
      await settings.write('wallet_auto_register', 'true');
      expect(
        (await service.process(event('archived-category')))!.status,
        'confirmed',
      );
      expect(await db.select(db.transactionSplits).get(), isEmpty);
    },
  );

  test('apagado por defecto; confirmar aprende comercio y próximas compras se registran', () async {
    final first = (await service.process(event('first')))!;
    expect(first.status, 'pending');
    expect(await db.select(db.merchants).get(), isEmpty);
    await service.confirm(first, fromAccountId: account);
    final merchant = await db.select(db.merchants).getSingle();
    expect(
      (await db.select(db.ledgerTransactions).getSingle()).merchantId,
      merchant.id,
    );
    expect(
      (await service.process(event('off', amount: 16000)))!.status,
      'pending',
    );
    await settings.write('wallet_auto_register', 'true');
    final known = (await service.process(event('known', amount: 17000)))!;
    expect(known.status, 'confirmed');
    expect(
      (await db.select(db.ledgerTransactions).get()).where(
        (r) => r.note == 'Registrado automáticamente',
      ),
      hasLength(1),
    );
    expect(await service.process(event('known', amount: 17000)), isNull);
  });
  test(
    'comercio o cuenta nuevos requieren revisión; asociaciones independientes',
    () async {
      await settings.write('wallet_auto_register', 'true');
      await MerchantService(db).findOrCreate('ECOP OBLIGADO');
      expect(
        (await service.process(event('new-account', alias: '9999')))!.status,
        'pending',
      );
      expect(
        (await service.process(event('new-merchant', merchant: 'Shell')))!
            .status,
        'pending',
      );
      final second = await AccountsService(db).createAccount(
        const CreateAccountDraft(
          name: 'Otra tarjeta',
          type: AccountType.creditCard,
          aliases: ['5678'],
          creditLimitMinor: 1000000,
        ),
      );
      expect(
        (await service.process(event('new-combination', alias: '5678')))!
            .status,
        'confirmed',
      );
      expect(
        (await db.select(db.ledgerTransactions).getSingle()).fromAccountId,
        second,
      );
    },
  );
  test('conflicto de cuentas, actualizaciones y posible duplicado no se automatizan', () async {
    await settings.write('wallet_auto_register', 'true');
    await MerchantService(db).findOrCreate('ECOP OBLIGADO');
    expect((await service.process(event('first')))!.status, 'confirmed');
    expect((await service.process(event('duplicate')))!.status, 'pending');
    expect(
      (await service.process(event('updated', update: true, amount: 16000)))!
          .status,
      'pending',
    );
    await AccountsService(db).createAccount(
      const CreateAccountDraft(
        name: 'Alias duplicado',
        type: AccountType.bank,
        aliases: ['1234'],
      ),
    );
    expect(
      (await service.process(event('ambiguous', amount: 17000)))!.status,
      'pending',
    );
    expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
  });
  test(
    'nombres parecidos no se unen; alias elegido enlaza un comercio existente',
    () async {
      final merchant = await MerchantService(db).findOrCreate('Ecop');
      expect(await MerchantService(db).matches('ECOP OBLIGADO'), isEmpty);
      final candidate = (await service.process(event('first')))!;
      await service.confirm(
        candidate,
        fromAccountId: account,
        merchantId: merchant,
      );
      expect(
        (await MerchantService(db).matches('ecop obligado')).single.id,
        merchant,
      );
      expect(await db.select(db.merchants).get(), hasLength(1));
    },
  );
}
