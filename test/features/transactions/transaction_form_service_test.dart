import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/installments/domain/installment_service.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:finanzas_locales/features/templates/scheduled_template_service.dart';
import 'package:finanzas_locales/features/transactions/data/category_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/data/transaction_form_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reglas de guardado del formulario, sin pasar por la interfaz.
void main() {
  late AppDatabase db;
  late TransactionFormService service;
  late String bank, card, food;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = TransactionFormService(
      database: db,
      ledger: LedgerService(db),
      installmentService: InstallmentService(db),
      merchants: MerchantService(db),
      categories: CategoryService(db),
      pendingPayments: PendingPaymentService(db),
      templates: ManualTemplateService(db),
      scheduledTemplates: ScheduledTemplateService(db),
      settings: SettingsRepository(db),
    );
    final accounts = AccountsService(db);
    bank = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Banco',
        type: AccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
    card = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Tarjeta',
        type: AccountType.creditCard,
        creditLimitMinor: 5000000,
      ),
    );
    food = await CategoryService(db).create('Alimentación', kind: 'expense');
  });
  tearDown(() => db.close());

  TransactionFormValues values({
    String amountText = '100.000',
    String? from,
    String merchantText = 'Ecop',
    MerchantRecord? selectedMerchant,
    String? originalMerchantId,
    String? category,
    bool splitEnabled = false,
    List<({String? categoryId, String amountText})> splits = const [],
    bool pendingPlan = false,
    bool installments = false,
    int installmentCount = 2,
    String? repeat,
    PaymentReminderSettings reminders = const PaymentReminderSettings(),
    String? editId,
    int? bookGeneration,
    TemplateToSave? template,
  }) => TransactionFormValues(
    type: TransactionType.expense,
    amountText: amountText,
    occurredAt: DateTime(2026, 10, 5, 12),
    from: from ?? bank,
    merchantText: merchantText,
    selectedMerchant: selectedMerchant,
    originalMerchantId: originalMerchantId,
    note: 'nota',
    channel: PaymentChannel.other,
    category: category,
    splitEnabled: splitEnabled,
    splits: splits,
    pendingPlan: pendingPlan,
    installments: installments,
    installmentCount: installmentCount,
    repeat: repeat,
    reminders: reminders,
    editId: editId,
    bookGeneration: bookGeneration ?? db.restoreGeneration,
    template: template,
  );

  Future<int> ledgerCount() async =>
      (await db.select(db.ledgerTransactions).get()).length;

  group('gasto', () {
    test(
      'crea el movimiento con comercio nuevo y recuerda su categoría',
      () async {
        final result = await service.submit(values(category: food));

        final movement = await db.select(db.ledgerTransactions).getSingle();
        expect(movement.amountMinor, 100000);
        expect(movement.merchantId, isNotNull);
        expect(
          await MerchantService(db).defaultCategory(movement.merchantId!),
          food,
        );
        expect(await LedgerService(db).balance(bank), 900000);
        expect(result.requestReminderPermission, isFalse);
      },
    );

    test('una categoría archivada no se recuerda para el comercio', () async {
      final old = await CategoryService(db).create('Antigua', kind: 'expense');
      await CategoryService(db).setArchived(old, true);

      await service.submit(values(category: old));

      final movement = await db.select(db.ledgerTransactions).getSingle();
      expect(
        await MerchantService(db).defaultCategory(movement.merchantId!),
        isNull,
      );
    });

    test('rechaza importes o cuotas inválidos sin escribir nada', () async {
      for (final (amount, count) in [
        ('100.000', 1),
        ('100.000', 121),
        ('1', 2),
      ]) {
        await expectLater(
          service.submit(
            values(
              from: card,
              amountText: amount,
              installments: true,
              installmentCount: count,
            ),
          ),
          throwsFormatException,
        );
      }
      expect(await ledgerCount(), 0);
    });

    test(
      'una división con categoría sin elegir deshace también el comercio nuevo',
      () async {
        await expectLater(
          service.submit(
            values(
              splitEnabled: true,
              splits: [
                (categoryId: food, amountText: '60.000'),
                (categoryId: null, amountText: '40.000'),
              ],
            ),
          ),
          throwsFormatException,
        );

        expect(await ledgerCount(), 0);
        expect(await db.select(db.merchants).get(), isEmpty);
      },
    );

    test('tras restaurar la base rechaza el formulario viejo', () async {
      final stale = db.restoreGeneration;
      db.restoreGeneration++;

      await expectLater(
        service.submit(values(bookGeneration: stale)),
        throwsStateError,
      );
      expect(await ledgerCount(), 0);
    });

    test(
      'un comercio archivado solo se acepta si ya era el del movimiento',
      () async {
        final merchants = MerchantService(db);
        final id = await merchants.findOrCreate('Ecop');
        await merchants.setArchived(id, true);
        final archived = await merchants.byId(id);

        await expectLater(
          service.submit(values(selectedMerchant: archived)),
          throwsStateError,
        );
        expect(await ledgerCount(), 0);

        await service.submit(
          values(selectedMerchant: archived, originalMerchantId: id),
        );
        expect(
          (await db.select(db.ledgerTransactions).getSingle()).merchantId,
          id,
        );
      },
    );

    test('editar actualiza el mismo movimiento en vez de crear otro', () async {
      await service.submit(values(category: food));
      final original = await db.select(db.ledgerTransactions).getSingle();

      await service.submit(
        values(amountText: '80.000', category: food, editId: original.id),
      );

      final edited = await db.select(db.ledgerTransactions).getSingle();
      expect(edited.id, original.id);
      expect(edited.amountMinor, 80000);
      expect(await LedgerService(db).balance(bank), 920000);
    });

    test(
      'recuerda las últimas cuentas usadas por tipo de movimiento',
      () async {
        await service.rememberLastAccounts(
          type: TransactionType.expense,
          from: bank,
        );

        final settings = SettingsRepository(db);
        expect(await settings.read('last_from_expense'), bank);
        expect(await settings.read('last_to_expense'), isNull);
      },
    );
  });

  group('pagar después', () {
    test('exige una descripción y no escribe nada sin ella', () async {
      await expectLater(
        service.submit(values(pendingPlan: true, merchantText: '  ')),
        throwsFormatException,
      );
      expect(await PendingPaymentService(db).list(), isEmpty);
    });

    test(
      'crea los pendientes sin tocar el libro y pide el permiso de avisos',
      () async {
        final result = await service.submit(
          values(pendingPlan: true, installments: true, installmentCount: 3),
        );

        expect(await PendingPaymentService(db).list(), hasLength(3));
        expect(await ledgerCount(), 0);
        expect(await LedgerService(db).balance(bank), 1000000);
        expect(result.requestReminderPermission, isTrue);
      },
    );

    test('con los recordatorios apagados no pide el permiso', () async {
      final result = await service.submit(
        values(
          pendingPlan: true,
          reminders: const PaymentReminderSettings(enabled: false),
        ),
      );

      expect(result.requestReminderPermission, isFalse);
    });

    test(
      'repetir guarda una plantilla programada y prepara el primer pendiente',
      () async {
        await service.submit(values(pendingPlan: true, repeat: 'monthly'));

        final templates = await ManualTemplateService(db).list();
        expect(templates, hasLength(1));
        final schedule = templates.single.fields['schedule'] as Map;
        expect(schedule['frequency'], 'monthly');
        expect(schedule['anchorDay'], 5);
        expect(templates.single.fields['payLater'], isTrue);
        expect(await ledgerCount(), 0);
        expect(await PendingPaymentService(db).list(), isNotEmpty);
      },
    );
  });
}
