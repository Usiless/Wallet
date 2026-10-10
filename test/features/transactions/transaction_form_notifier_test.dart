import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_models.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:finanzas_locales/features/transactions/data/category_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_notifier.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// El ViewModel del formulario, sin interfaz.
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late String bank, card, cash, food, salary;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
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
    cash = await accounts.createAccount(
      const CreateAccountDraft(name: 'Efectivo', type: AccountType.cash),
    );
    food = await CategoryService(db).create('Comida', kind: 'expense');
    salary = await CategoryService(db).create('Sueldo', kind: 'income');
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  TransactionFormArgs args({
    TransactionType type = TransactionType.expense,
    String? template,
    String? cloneId,
    String? editId,
    String? toAccountId,
    String? savedTemplateId,
    bool editTemplate = false,
  }) => (
    initialType: type,
    template: template,
    cloneId: cloneId,
    editId: editId,
    toAccountId: toAccountId,
    savedTemplateId: savedTemplateId,
    editTemplate: editTemplate,
  );

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  /// Abre el formulario y espera a que carguen cuentas, categorías y datos.
  Future<TransactionFormNotifier> open([TransactionFormArgs? a]) async {
    final provider = transactionFormProvider(a ?? args());
    container.listen(provider, (_, _) {});
    container.listen(accountsProvider, (_, _) {});
    container.listen(categoriesProvider, (_, _) {});
    await settle();
    return container.read(provider.notifier);
  }

  TransactionFormState stateOf(TransactionFormArgs a) =>
      container.read(transactionFormProvider(a));

  group('apertura', () {
    test(
      'un formulario nuevo queda limpio y con el destino indicado',
      () async {
        final a = args(type: TransactionType.income, toAccountId: bank);
        await open(a);
        final state = stateOf(a);

        expect(state.type, TransactionType.income);
        expect(state.to, bank);
        expect(state.loading, isFalse);
        expect(state.baseline, isNotNull);
        expect(state.isDirty, isFalse);
      },
    );

    test('al escribir se ensucia y al guardar vuelve a limpio', () async {
      final a = args();
      final notifier = await open(a);

      notifier.setAmountText('50.000');
      expect(stateOf(a).isDirty, isTrue);
      notifier.finishSave();
      expect(stateOf(a).isDirty, isFalse);
      expect(stateOf(a).saving, isFalse);
    });

    test(
      'pagar una tarjeta propone transferir del banco a esa tarjeta',
      () async {
        final a = args(template: 'cardPayment', toAccountId: card);
        await open(a);
        final state = stateOf(a);

        expect(state.type, TransactionType.transfer);
        expect(state.from, bank);
        expect(state.to, card);
        expect(state.isDirty, isFalse);
      },
    );

    test('sin tarjeta indicada elige la primera tarjeta', () async {
      final a = args(template: 'cardPayment');
      await open(a);

      expect(stateOf(a).to, card);
    });
  });

  group('reglas al elegir', () {
    test('una tarjeta de crédito desactiva pagar después y repetir', () async {
      final a = args();
      final notifier = await open(a);
      notifier.setFrom(bank);
      notifier.setWhen('later');
      notifier.setRepeat('monthly');
      expect(stateOf(a).payLater, isTrue);

      notifier.setFrom(card);

      final state = stateOf(a);
      expect((state.payLater, state.repeat), (false, null));
    });

    test('una cuenta común sin pagar después apaga las cuotas', () async {
      final a = args();
      final notifier = await open(a);
      notifier.setFrom(card);
      notifier.setWhen('installments');
      expect(stateOf(a).installments, isTrue);

      notifier.setFrom(bank);

      expect(stateOf(a).installments, isFalse);
    });

    test('«Cuándo» combina pagar después y cuotas según la cuenta', () async {
      final a = args();
      final notifier = await open(a);
      notifier.setFrom(bank);

      notifier.setWhen('installments');
      expect((stateOf(a).payLater, stateOf(a).installments), (true, true));
      notifier.setWhen('later');
      expect((stateOf(a).payLater, stateOf(a).installments), (true, false));
      notifier.setWhen('now');
      expect((stateOf(a).payLater, stateOf(a).installments), (false, false));

      notifier.setFrom(card);
      notifier.setWhen('installments');
      expect((stateOf(a).payLater, stateOf(a).installments), (false, true));
    });

    test(
      'cambiar el tipo descarta la categoría y el canal incompatibles',
      () async {
        final a = args();
        final notifier = await open(a);
        notifier.setFrom(cash);
        notifier.setChannel(PaymentChannel.cash);
        notifier.setCategory(food);
        expect(stateOf(a).category, food);

        notifier.setType(TransactionType.income);

        final state = stateOf(a);
        expect(state.category, isNull);
        expect(
          state.from,
          cash,
          reason: 'el origen se conserva hasta elegir otro',
        );
        notifier.setCategory(salary);
        expect(stateOf(a).category, salary);
      },
    );

    test('mover el destino al origen en una transferencia lo limpia', () async {
      final a = args(type: TransactionType.transfer);
      final notifier = await open(a);
      notifier.setFrom(bank);
      notifier.setTo(cash);
      expect(stateOf(a).to, cash);

      notifier.setFrom(cash);

      expect(stateOf(a).to, isNull);
    });
  });

  group('fechas', () {
    test(
      'la primera cuota sigue a la fecha de compra solo si coincidían',
      () async {
        final a = args();
        final notifier = await open(a);
        final bought = stateOf(a).occurredAt;
        notifier.setFirstInstallmentDate(bought);
        expect(stateOf(a).firstInstallmentDate, isNotNull);

        final other = DateTime(
          bought.year,
          bought.month,
          bought.day == 15 ? 14 : 15,
        );
        notifier.setOccurredAt(other);
        expect(stateOf(a).occurredAt.day, other.day);
        expect(
          stateOf(a).firstInstallmentDate,
          DateTime.utc(other.year, other.month, other.day, 12),
        );

        // Con otra fecha de primera cuota, cambiar la compra ya no la arrastra.
        final apart = DateTime(other.year, other.month, 25);
        notifier.setFirstInstallmentDate(apart);
        final later = DateTime(
          other.year,
          other.month,
          other.day == 20 ? 21 : 20,
        );
        notifier.setOccurredAt(later);
        expect(
          stateOf(a).firstInstallmentDate,
          DateTime.utc(apart.year, apart.month, 25, 12),
          reason: 'ya no coincidía con la compra',
        );
      },
    );

    test('al cambiar el día se conserva la hora de la compra', () async {
      final a = args();
      final notifier = await open(a);
      final before = stateOf(a).occurredAt;

      notifier.setOccurredAt(DateTime(2026, 1, 2));

      final after = stateOf(a).occurredAt;
      expect((after.year, after.month, after.day), (2026, 1, 2));
      expect((after.hour, after.minute), (before.hour, before.minute));
    });
  });

  group('divisiones', () {
    test('dividir crea dos filas con la categoría actual y alterna', () async {
      final a = args();
      final notifier = await open(a);
      notifier.setCategory(food);

      notifier.toggleSplits();

      var state = stateOf(a);
      expect(state.splitEnabled, isTrue);
      expect(state.splits.map((s) => s.categoryId), [food, null]);
      expect(state.splits.map((s) => s.id).toSet(), hasLength(2));

      notifier.toggleSplits();
      state = stateOf(a);
      expect(state.splitEnabled, isFalse);
      expect(state.splits, hasLength(2), reason: 'se conservan al volver');
    });

    test('agregar, editar y quitar filas por identificador', () async {
      final a = args();
      final notifier = await open(a);
      notifier.toggleSplits();
      notifier.addSplit();
      final ids = stateOf(a).splits.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(3));

      notifier.setSplitAmount(ids[1], '40.000');
      notifier.setSplitCategory(ids[1], food);
      notifier.removeSplit(ids[0]);

      final rows = stateOf(a).splits;
      expect(rows.map((s) => s.id), [ids[1], ids[2]]);
      expect((rows.first.categoryId, rows.first.amountText), (food, '40.000'));

      notifier.addSplit();
      expect(
        stateOf(a).splits.map((s) => s.id).toSet().length,
        3,
        reason: 'un identificador nuevo nunca reutiliza uno quitado',
      );
    });
  });

  group('comercio y categoría', () {
    test('elegir un comercio propone su categoría si nada cambió', () async {
      final merchants = MerchantService(db);
      final id = await merchants.findOrCreate('Ecop');
      await merchants.rememberCategory(id, food);
      final merchant = await merchants.byId(id);
      final a = args();
      final notifier = await open(a);

      notifier.setMerchantText('Ecop');
      await notifier.selectMerchant(merchant);

      expect(stateOf(a).selectedMerchant?.id, id);
      expect(stateOf(a).category, food);
    });

    test('no pisa la categoría si el texto del comercio ya cambió', () async {
      final merchants = MerchantService(db);
      final id = await merchants.findOrCreate('Ecop');
      await merchants.rememberCategory(id, food);
      final merchant = await merchants.byId(id);
      final a = args();
      final notifier = await open(a);

      notifier.setMerchantText('Otro lugar');
      await notifier.selectMerchant(merchant);

      expect(stateOf(a).category, isNull);
    });

    test(
      'crear una categoría la deja elegida aunque la lista aún no la traiga',
      () async {
        final a = args();
        final notifier = await open(a);

        await notifier.createCategory('Mascotas');
        await settle();

        final created = (await db.select(db.categories).get()).firstWhere(
          (c) => c.name == 'Mascotas',
        );
        expect(created.kind, 'expense');
        expect(stateOf(a).category, created.id);
        expect(stateOf(a).awaitingCategory, isNull);
      },
    );
  });

  group('cargas', () {
    late String movementId;
    setUp(() async {
      movementId = await LedgerService(db).create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(100000),
          occurredAt: DateTime(2026, 9, 10),
          fromAccountId: bank,
          description: 'Mercado',
          splits: [
            SplitDraft(categoryId: food, amountMinor: 60000),
            SplitDraft(categoryId: food, amountMinor: 40000),
          ],
        ),
      );
    });

    test('editar carga el movimiento y queda limpio', () async {
      final a = args(editId: movementId);
      await open(a);
      final state = stateOf(a);

      expect(state.loading, isFalse);
      expect(state.isEdit, isTrue);
      expect(state.amountText, '100.000');
      expect(state.splits, hasLength(2));
      expect(state.from, bank);
      expect(state.isDirty, isFalse);
    });

    test('un movimiento que ya no existe deja un error de carga', () async {
      final a = args(cloneId: 'no-existe');
      await open(a);
      final state = stateOf(a);

      expect(state.loading, isFalse);
      expect(state.loadError, contains('ya no está disponible'));
    });

    test('abrir una plantilla guardada queda limpio; usarla desde el formulario no', () async {
      final templates = ManualTemplateService(db);
      final id = await templates.save('Alquiler', {
        'type': 'expense',
        'amountMinor': 500000,
        'from': bank,
        'merchant': 'Casero',
      });
      final opened = args(savedTemplateId: id);
      await open(opened);
      expect(stateOf(opened).amountText, '500.000');
      expect(stateOf(opened).templateName, 'Alquiler');
      expect(stateOf(opened).isDirty, isFalse);

      final blank = args();
      final notifier = await open(blank);
      await notifier.useTemplate(id);
      await settle();
      expect(stateOf(blank).amountText, '500.000');
      expect(stateOf(blank).isDirty, isTrue);
    });

    test('usar una plantilla reinicia divisiones y comercio elegido', () async {
      final id = await ManualTemplateService(
        db,
      ).save('Simple', {'type': 'expense', 'amountMinor': 1000, 'from': bank});
      final a = args();
      final notifier = await open(a);
      notifier.toggleSplits();
      notifier.setAlsoSaveTemplate(true);

      await notifier.useTemplate(id);
      await settle();

      final state = stateOf(a);
      expect(state.splits, isEmpty);
      expect(state.alsoSaveTemplate, isFalse);
      expect(state.selectedMerchant, isNull);
    });
  });

  group('guardado', () {
    test('guarda el gasto con lo que hay en el estado', () async {
      final a = args();
      final notifier = await open(a);
      notifier.setFrom(bank);
      notifier.setAmountText('100.000');
      notifier.setMerchantText('Ecop');
      notifier.setCategory(food);

      final result = await notifier.submit(null);

      expect(result.requestReminderPermission, isFalse);
      final saved = await db.select(db.ledgerTransactions).getSingle();
      expect(saved.amountMinor, 100000);
      expect(await LedgerService(db).balance(bank), 900000);
    });

    test('un valor inválido no guarda nada', () async {
      final a = args();
      final notifier = await open(a);
      notifier.setFrom(bank);
      notifier.setAmountText('');

      await expectLater(notifier.submit(null), throwsFormatException);
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
    });

    test(
      '«guardar y crear otro» limpia los textos y avisa a la vista',
      () async {
        final a = args();
        final notifier = await open(a);
        notifier.setAmountText('1.000');
        notifier.setMerchantText('Ecop');
        notifier.setNoteText('nota');
        notifier.setSaving(true);
        final revision = stateOf(a).textRevision;

        notifier.resetForAnother();

        final state = stateOf(a);
        expect(
          (state.amountText, state.merchantText, state.noteText),
          ('', '', ''),
        );
        expect(state.saving, isFalse);
        expect(state.textRevision, revision + 1);
        expect(state.isDirty, isFalse);
      },
    );

    test('tras restaurar la base ya no se puede guardar', () async {
      final a = args();
      final notifier = await open(a);
      notifier.setFrom(bank);
      notifier.setAmountText('1.000');
      db.restoreGeneration++;

      await expectLater(notifier.submit(null), throwsStateError);
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
    });
  });
  group('ajustes simples y plantillas', () {
    test('guarda la cantidad de cuotas y los recordatorios elegidos', () async {
      final a = args();
      final notifier = await open(a);

      notifier.setInstallmentCount(12);
      notifier.setReminders(
        const PaymentReminderSettings(enabled: false, daysBefore: 5),
      );

      expect(stateOf(a).installmentCount, 12);
      expect(stateOf(a).reminders.enabled, isFalse);
      expect(stateOf(a).reminders.daysBefore, 5);
    });

    test(
      'una plantilla que ya no existe deja el error y termina de cargar',
      () async {
        final a = args();
        final notifier = await open(a);

        await notifier.loadTemplate('no-existe', markClean: false);

        expect(stateOf(a).loadError, contains('La plantilla ya no existe'));
        expect(stateOf(a).loading, isFalse);
      },
    );

    test(
      'el selector lista primero las plantillas del tipo actual, por nombre',
      () async {
        final templates = ManualTemplateService(db);
        await templates.save('Zeta gasto', {'type': 'expense', 'from': bank});
        await templates.save('beta ingreso', {'type': 'income', 'to': bank});
        await templates.save('Alfa gasto', {'type': 'expense', 'from': bank});
        final a = args();
        final notifier = await open(a);

        expect((await notifier.templatesForPicker()).map((t) => t.name), [
          'Alfa gasto',
          'Zeta gasto',
          'beta ingreso',
        ]);
        notifier.setType(TransactionType.income);
        expect(
          (await notifier.templatesForPicker()).first.name,
          'beta ingreso',
        );
      },
    );
  });
}
