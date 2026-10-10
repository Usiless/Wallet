import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_models.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:finanzas_locales/features/installments/domain/installment_service.dart';
import 'package:finanzas_locales/features/templates/save_template_dialog.dart';
import 'package:finanzas_locales/features/transactions/data/category_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reglas del formulario que no dependen de la interfaz.
void main() {
  late AppDatabase db;
  late List<AccountRecord> accounts;
  late List<CategoryRecord> categories;
  late String bank, cash, card, food, salary, both;

  final today = DateTime(2026, 10, 5, 12);
  TransactionFormState blank({
    TransactionType type = TransactionType.expense,
    bool isEdit = false,
    bool isTemplateEdit = false,
  }) => TransactionFormState(
    type: type,
    occurredAt: today,
    isEdit: isEdit,
    isTemplateEdit: isTemplateEdit,
  );

  TransactionFormState normalize(
    TransactionFormState state, {
    bool loading = false,
  }) => state.normalized(
    accounts: accounts,
    categories: categories,
    categoriesLoading: loading,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final service = AccountsService(db);
    bank = await service.createAccount(
      const CreateAccountDraft(
        name: 'Banco',
        type: AccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
    cash = await service.createAccount(
      const CreateAccountDraft(name: 'Efectivo', type: AccountType.cash),
    );
    card = await service.createAccount(
      const CreateAccountDraft(
        name: 'Tarjeta',
        type: AccountType.creditCard,
        creditLimitMinor: 5000000,
      ),
    );
    final catalog = CategoryService(db);
    food = await catalog.create('Comida', kind: 'expense');
    salary = await catalog.create('Sueldo', kind: 'income');
    both = await catalog.create('Otros', kind: 'both');
    accounts = await db.select(db.accounts).get();
    categories = await db.select(db.categories).get();
  });
  tearDown(() => db.close());

  group('normalización', () {
    test('quita cuentas que ya no existen y un destino igual al origen', () {
      final state = normalize(
        blank(type: TransactionType.transfer).copyWith(from: bank, to: bank),
      );
      expect(state.from, bank);
      expect(state.to, isNull);

      final gone = normalize(
        blank().copyWith(from: 'borrada', to: 'tambien-borrada'),
      );
      expect((gone.from, gone.to), (null, null));
    });

    test('descarta la categoría que no corresponde al tipo, salvo «ambas»', () {
      expect(normalize(blank().copyWith(category: salary)).category, isNull);
      expect(normalize(blank().copyWith(category: food)).category, food);
      expect(normalize(blank().copyWith(category: both)).category, both);
      expect(
        normalize(blank(type: TransactionType.income).copyWith(category: food))
            .category,
        isNull,
      );
    });

    test('espera a una categoría recién creada y la suelta cuando aparece', () {
      final waiting = normalize(
        blank().copyWith(category: 'nueva', awaitingCategory: 'nueva'),
      );
      expect(waiting.category, 'nueva');
      expect(waiting.awaitingCategory, 'nueva');

      final arrived = normalize(
        blank().copyWith(category: food, awaitingCategory: food),
      );
      expect(arrived.category, food);
      expect(arrived.awaitingCategory, isNull);
    });

    test('mientras cargan las categorías no descarta ninguna elección', () {
      final state = normalize(
        blank().copyWith(
          category: 'aun-no-cargada',
          splits: [(id: 0, categoryId: 'otra', amountText: '1')],
        ),
        loading: true,
      );
      expect(state.category, 'aun-no-cargada');
      expect(state.splits.single.categoryId, 'otra');
    });

    test(
      'limpia la categoría de una división inválida y conserva su importe',
      () {
        final state = normalize(
          blank().copyWith(
            splits: [
              (id: 0, categoryId: food, amountText: '60.000'),
              (id: 1, categoryId: salary, amountText: '40.000'),
            ],
          ),
        );
        expect(state.splits[0].categoryId, food);
        expect(state.splits[1].categoryId, isNull);
        expect(state.splits[1].amountText, '40.000');
      },
    );

    test('ajusta el canal a lo permitido para el tipo y las cuentas', () {
      expect(
        normalize(blank().copyWith(from: bank, channel: PaymentChannel.cash))
            .channel,
        PaymentChannel.physicalCard,
      );
      expect(
        normalize(blank().copyWith(from: cash, channel: PaymentChannel.cash))
            .channel,
        PaymentChannel.cash,
      );
      expect(
        normalize(
          blank().copyWith(from: card, channel: PaymentChannel.bankTransfer),
        ).channel,
        PaymentChannel.physicalCard,
      );
      expect(
        normalize(
          blank().copyWith(from: bank, channel: PaymentChannel.debitCard),
        ).channel,
        PaymentChannel.physicalCard,
        reason: 'los canales antiguos se normalizan',
      );
      expect(normalize(blank()).channel, PaymentChannel.other);
    });

    test('no crea otro estado si no hay nada que corregir', () {
      final state = normalize(blank().copyWith(from: bank, category: food));
      expect(identical(normalize(state), state), isTrue);
    });
  });

  group('derivados', () {
    test('tarjeta de crédito, pagar después y cuotas', () {
      final onCard = blank().copyWith(from: card, installments: true);
      expect(onCard.isCreditExpense(accounts), isTrue);
      expect(onCard.pendingOn(accounts), isFalse);
      expect(onCard.installmentsOn(accounts), isTrue);

      final later = blank().copyWith(from: bank, payLater: true);
      expect(later.pendingOn(accounts), isTrue);
      expect(later.installmentsOn(accounts), isFalse);
      expect(
        later.copyWith(installments: true).installmentsOn(accounts),
        isTrue,
      );

      final income = blank(type: TransactionType.income)
          .copyWith(from: bank, payLater: true, installments: true);
      expect(income.pendingOn(accounts), isFalse);
      expect(income.installmentsOn(accounts), isFalse);
    });

    test('al editar no se puede pasar a pagar después', () {
      final editing = blank(isEdit: true)
          .copyWith(from: bank, payLater: true, installments: true);
      expect(editing.pendingOn(accounts), isFalse);
      expect(editing.installmentsOn(accounts), isFalse);
    });

    test('qué cuentas hacen falta según el tipo', () {
      expect((blank().needsFrom, blank().needsTo), (true, false));
      expect(
        (
          blank(type: TransactionType.income).needsFrom,
          blank(type: TransactionType.income).needsTo,
        ),
        (false, true),
      );
      expect(
        (
          blank(type: TransactionType.transfer).needsFrom,
          blank(type: TransactionType.transfer).needsTo,
        ),
        (true, true),
      );
    });

    test(
      'al editar suma las cuentas y categorías archivadas del movimiento',
      () {
        final archived = accounts.firstWhere((a) => a.id == cash);
        final active = accounts.where((a) => a.id != cash).toList();
        final editing = blank(isEdit: true)
            .copyWith(editingAccounts: [archived]);
        expect(editing.accountsFrom(active).map((a) => a.id), contains(cash));
        expect(
          blank().copyWith(editingAccounts: [archived]).accountsFrom(active),
          hasLength(active.length),
        );
      },
    );
  });

  group('cambios sin guardar', () {
    test('un estado sin foto previa nunca está sucio', () {
      expect(blank().copyWith(amountText: '1').isDirty, isFalse);
    });

    test('detecta lo escrito y vuelve a limpio al marcarlo', () {
      final clean = blank().markClean();
      expect(clean.isDirty, isFalse);

      final typed = clean.copyWith(amountText: '10.000');
      expect(typed.isDirty, isTrue);
      expect(typed.markClean().isDirty, isFalse);
      expect(typed.copyWith(amountText: '').isDirty, isFalse);
    });

    test('las preferencias de la pantalla no cuentan como cambios', () {
      final clean = blank().markClean();
      expect(
        clean.copyWith(advanced: true, saveAnother: true, saving: true).isDirty,
        isFalse,
      );
      expect(clean.copyWith(from: bank).isDirty, isTrue);
      expect(
        clean
            .copyWith(splits: [(id: 0, categoryId: food, amountText: '1')])
            .isDirty,
        isTrue,
      );
    });
  });

  group('cargar un movimiento', () {
    late String movementId;
    setUp(() async {
      final merchant = await db
          .into(db.merchants)
          .insertReturning(
            MerchantsCompanion.insert(
              id: 'm1',
              name: 'Ecop',
              normalizedName: 'ecop',
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      movementId = await LedgerService(db).create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(100000),
          occurredAt: DateTime(2026, 9, 10),
          fromAccountId: bank,
          merchantId: merchant.id,
          description: 'Mercado',
          note: 'semanal',
          splits: [
            SplitDraft(categoryId: food, amountMinor: 60000),
            SplitDraft(categoryId: both, amountMinor: 40000),
          ],
        ),
      );
    });

    test(
      'editar conserva fecha, comercio original y la marca de edición',
      () async {
        final source = await LedgerRepository(db).loadForForm(movementId);
        final state = blank(isEdit: true).withMovement(source);

        expect(state.amountText, '100.000');
        expect(state.merchantText, 'Ecop');
        expect(state.originalMerchantId, 'm1');
        expect(state.noteText, 'semanal');
        expect(state.from, bank);
        expect(state.occurredAt, DateTime(2026, 9, 10).toLocal());
        expect(state.editingUpdatedAt, isNotNull);
        expect(state.splitEnabled, isTrue);
        expect(state.splits.map((s) => (s.categoryId, s.amountText)), [
          (food, '60.000'),
          (both, '40.000'),
        ]);
        expect(state.splits.map((s) => s.id).toSet(), hasLength(2));
        expect(state.advanced, isTrue);
        expect(state.isDirty, isFalse);
        expect(state.textRevision, 1);
      },
    );

    test(
      'clonar usa la fecha de hoy y no recuerda el comercio original',
      () async {
        final source = await LedgerRepository(db).loadForForm(movementId);
        final state = blank().withMovement(source);

        expect(state.originalMerchantId, isNull);
        expect(
          state.occurredAt.difference(DateTime.now()).inMinutes.abs(),
          lessThan(2),
        );
        expect(state.firstInstallmentDate, isNull);
        expect(state.isDirty, isFalse);
      },
    );

    test('una compra con una sola categoría usa la categoría simple', () async {
      final id = await LedgerService(db).create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(5000),
          occurredAt: DateTime(2026, 9, 11),
          fromAccountId: bank,
          splits: [SplitDraft(categoryId: food, amountMinor: 5000)],
        ),
      );
      final state = blank().withMovement(
        await LedgerRepository(db).loadForForm(id),
      );

      expect(state.splitEnabled, isFalse);
      expect(state.category, food);
      expect(state.splits, isEmpty);
    });
  });

  group('cargar una plantilla', () {
    Future<ManualTemplate> template(Map<String, dynamic> fields) async {
      final service = ManualTemplateService(db);
      final id = await service.save('Alquiler', {
        'type': 'expense',
        'from': bank,
        ...fields,
      });
      return (await service.read(id))!;
    }

    test('aplica importe, cuenta, canal y detalles; solo editar conserva la programación', () async {
      final saved = await template({
        'amountMinor': 500000,
        'merchant': 'Casero',
        'note': 'mensual',
        'channel': 'bankTransfer',
        'schedule': {
          'enabled': true,
          'frequency': 'monthly',
          'nextDate': '2026-11-05',
          'anchorDay': 5,
          'anchorMonth': 11,
        },
      });

      final used = blank().withTemplate(saved, null, markClean: false);
      expect(used.amountText, '500.000');
      expect(used.from, bank);
      expect(used.merchantText, 'Casero');
      expect(used.channel, PaymentChannel.bankTransfer);
      expect(used.templateName, 'Alquiler');
      expect(used.templateSchedule, isNull);
      expect(used.advanced, isTrue);

      final edited = blank(isTemplateEdit: true)
          .withTemplate(saved, null, markClean: true);
      expect(edited.templateSchedule!['nextDate'], '2026-11-05');
      expect(edited.isDirty, isFalse);
    });

    test(
      'suma las divisiones a las que ya hubiera y respeta un importe vacío',
      () async {
        final saved = await template({
          'splitEnabled': true,
          'splits': [
            {'category': food, 'amountMinor': 300},
            {'category': both, 'amountMinor': null},
          ],
        });
        final base = blank().copyWith(
          splits: [(id: 7, categoryId: food, amountText: '9')],
          nextSplitId: 8,
        );

        final state = base.withTemplate(saved, null, markClean: false);
        expect(state.amountText, '');
        expect(state.splits.map((s) => (s.id, s.amountText)), [
          (7, '9'),
          (8, '300'),
          (9, ''),
        ]);
        expect(state.nextSplitId, 10);
      },
    );

    test('un comercio archivado no se asocia', () async {
      final saved = await template({'merchant': 'Casero'});
      final archived = await db
          .into(db.merchants)
          .insertReturning(
            MerchantsCompanion.insert(
              id: 'm2',
              name: 'Casero',
              normalizedName: 'casero',
              isArchived: const Value(true),
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final state = blank().withTemplate(saved, archived, markClean: false);
      expect(state.selectedMerchant, isNull);
      expect(state.merchantText, 'Casero');
    });
  });

  group('plantilla a guardar', () {
    SaveTemplateChoice choice({
      bool includeAmount = true,
      bool automatic = true,
      String frequency = 'monthly',
      DateTime? nextDate,
      bool choseDate = false,
    }) => SaveTemplateChoice(
      name: 'Gimnasio',
      includeAmount: includeAmount,
      automatic: automatic,
      frequency: frequency,
      nextDate: nextDate ?? DateTime(2026, 11, 5),
      choseDate: choseDate,
      reminders: const PaymentReminderSettings(),
    );

    final base = blank().copyWith(
      amountText: '80.000',
      from: 'banco-1',
      merchantText: ' Gimnasio ',
      noteText: ' nota ',
      category: 'cat-1',
    );

    test('al registrar el movimiento el día de la compra es el ancla', () {
      final fields = base
          .templateFrom(
            choice(),
            afterRegistration: true,
            originalNextDate: DateTime(2026, 11, 5),
            originalFrequency: 'monthly',
          )
          .fields;
      final schedule = fields['schedule'] as Map;
      expect(schedule['anchorDay'], 5);
      expect(schedule['anchorMonth'], 10);
      expect(schedule['nextDate'], '2026-11-05');
      expect(fields['amountMinor'], 80000);
      expect(fields['merchant'], 'Gimnasio');
      expect(fields['note'], 'nota');
      expect(fields['from'], 'banco-1');
      expect(fields['to'], isNull);
    });

    test('una fecha elegida a mano pasa a ser el ancla', () {
      final schedule =
          base
                  .templateFrom(
                    choice(nextDate: DateTime(2026, 12, 20), choseDate: true),
                    afterRegistration: true,
                    originalNextDate: DateTime(2026, 11, 5),
                    originalFrequency: 'monthly',
                  )
                  .fields['schedule']
              as Map;
      expect((schedule['anchorDay'], schedule['anchorMonth']), (20, 12));
    });

    test(
      'sin cambios de fecha ni frecuencia conserva los anclajes guardados',
      () {
        final editing = base.copyWith(
          templateSchedule: {
            'enabled': true,
            'frequency': 'monthly',
            'nextDate': '2026-11-31',
            'anchorDay': 31,
            'anchorMonth': 1,
          },
        );
        final schedule =
            editing
                    .templateFrom(
                      choice(nextDate: DateTime(2026, 11, 30)),
                      afterRegistration: false,
                      originalNextDate: DateTime(2026, 11, 30),
                      originalFrequency: 'monthly',
                    )
                    .fields['schedule']
                as Map;
        expect((schedule['anchorDay'], schedule['anchorMonth']), (31, 1));
      },
    );

    test('desactivar una programación activa la deja pausada', () {
      final editing = base.copyWith(
        templateSchedule: {'enabled': true, 'frequency': 'monthly'},
      );
      final schedule =
          editing
                  .templateFrom(
                    choice(automatic: false),
                    afterRegistration: false,
                    originalNextDate: DateTime(2026, 11, 5),
                    originalFrequency: 'monthly',
                  )
                  .fields['schedule']
              as Map;
      expect((schedule['enabled'], schedule['paused']), (false, true));
    });

    test('sin recordar el importe se omiten el importe y las divisiones', () {
      final withSplits = base.copyWith(
        splitEnabled: true,
        splits: [(id: 0, categoryId: 'c', amountText: '1.000')],
      );
      final fields = withSplits
          .templateFrom(
            choice(includeAmount: false, automatic: false),
            afterRegistration: false,
            originalNextDate: DateTime(2026, 11, 5),
            originalFrequency: 'monthly',
          )
          .fields;
      expect(fields['amountMinor'], isNull);
      expect(fields['splitEnabled'], isFalse);
      expect(fields['splits'], isEmpty);

      final remembered = withSplits
          .templateFrom(
            choice(),
            afterRegistration: false,
            originalNextDate: DateTime(2026, 11, 5),
            originalFrequency: 'monthly',
          )
          .fields;
      expect(remembered['splits'], [
        {'category': 'c', 'amountMinor': 1000},
      ]);
    });

    test('rechaza un importe no válido', () {
      for (final text in ['', '0', 'abc']) {
        expect(
          () => base
              .copyWith(amountText: text)
              .templateFrom(
                choice(),
                afterRegistration: false,
                originalNextDate: DateTime(2026, 11, 5),
                originalFrequency: 'monthly',
              ),
          throwsFormatException,
          reason: 'importe «$text»',
        );
      }
    });

    test('el comercio solo se asocia si el texto no cambió', () {
      final merchant = MerchantRecord(
        id: 'm1',
        name: 'Gimnasio',
        normalizedName: 'gimnasio',
        isArchived: false,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      Map<String, dynamic> fieldsFor(String text) => base
          .copyWith(selectedMerchant: merchant, merchantText: text)
          .templateFrom(
            choice(),
            afterRegistration: false,
            originalNextDate: DateTime(2026, 11, 5),
            originalFrequency: 'monthly',
          )
          .fields;
      expect(fieldsFor('Gimnasio')['merchantId'], 'm1');
      expect(fieldsFor('Otro')['merchantId'], isNull);
    });
  });

  group('valores para guardar', () {
    test('marca el plan pendiente y las cuotas según las cuentas', () {
      final values = blank()
          .copyWith(
            from: bank,
            amountText: '1.000',
            payLater: true,
            installments: true,
            installmentCount: 3,
          )
          .toValues(accounts: accounts, bookGeneration: 4, editId: null);

      expect(values.pendingPlan, isTrue);
      expect(values.installments, isTrue);
      expect(values.installmentCount, 3);
      expect(values.bookGeneration, 4);
      expect(values.editId, isNull);
    });
  });
  group('plan de cuotas y valores iniciales de la plantilla', () {
    test(
      'editar una compra en cuotas conserva la cantidad y la primera cuota',
      () async {
        final id = await LedgerService(db).create(
          TransactionDraft(
            type: TransactionType.expense,
            amount: const Money(90000),
            occurredAt: DateTime(2026, 9, 10),
            fromAccountId: card,
          ),
        );
        await InstallmentService(db).attachPlan(
          transactionId: id,
          count: 3,
          firstPeriod: DateTime(2026, 10, 15),
        );
        final source = await LedgerRepository(db).loadForForm(id);

        final edited = blank(isEdit: true).withMovement(source);
        expect(edited.installments, isTrue);
        expect(edited.installmentCount, 3);
        expect(edited.firstInstallmentDate, DateTime.utc(2026, 10, 15, 12));

        final cloned = blank().withMovement(source);
        expect(cloned.installments, isTrue);
        expect(cloned.firstInstallmentDate, isNull);
      },
    );

    test('una plantilla con recordatorios los conserva', () async {
      final service = ManualTemplateService(db);
      final id = await service.save('Con aviso', {
        'type': 'expense',
        'from': bank,
        'reminders': const PaymentReminderSettings(
          enabled: false,
          daysBefore: 7,
        ).toJson(),
      });

      final state = blank().withTemplate(
        (await service.read(id))!,
        null,
        markClean: false,
      );

      expect(state.reminders.enabled, isFalse);
      expect(state.reminders.daysBefore, 7);
    });

    test('al registrar, cambiar la frecuencia propone otra próxima fecha', () {
      final defaults = blank().templateDefaults(afterRegistration: true);
      expect(defaults.frequency, 'monthly');
      expect(defaults.nextDate, DateTime(2026, 11, 5));

      final yearly = defaults.nextDateForFrequency!('yearly');
      expect(yearly, DateTime(2027, 10, 5));
      expect(
        blank().templateDefaults(afterRegistration: false).nextDateForFrequency,
        isNull,
      );
      expect(
        blank()
            .copyWith(templateSchedule: {'frequency': 'monthly'})
            .templateDefaults(afterRegistration: true)
            .nextDateForFrequency,
        isNull,
        reason: 'una plantilla ya programada no recalcula la fecha',
      );
    });
  });
}
