import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reintentar tras fallar useTemplate aplica la plantilla sin recargar otra cosa', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final bank = await AccountsService(db).createAccount(
      const CreateAccountDraft(
        name: 'Banco',
        type: AccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
    final templates = ManualTemplateService(db);
    final id = await templates.save('Alquiler', {
      'type': 'expense',
      'amountMinor': 500000,
      'from': bank,
      'merchant': 'Casero',
    });
    final key = '${ManualTemplateService.prefix}$id';
    final valid = await (db.select(
      db.appSettings,
    )..where((t) => t.key.equals(key))).getSingle().then((row) => row.value);

    Future<void> setRaw(String value) =>
        (db.update(db.appSettings)..where((t) => t.key.equals(key))).write(
          AppSettingsCompanion(value: Value(value)),
        );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final a = (
      initialType: TransactionType.expense,
      template: null,
      cloneId: null,
      editId: null,
      toAccountId: null,
      savedTemplateId: null,
      editTemplate: false,
    );
    final provider = transactionFormProvider(a);
    container.listen(provider, (_, _) {});
    container.listen(accountsProvider, (_, _) {});
    container.listen(categoriesProvider, (_, _) {});
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }

    await settle();
    // La plantilla está dañada cuando se intenta usar: la carga falla.
    await setRaw('{');
    final notifier = container.read(provider.notifier);
    await notifier.useTemplate(id);
    await settle();
    expect(container.read(provider).loadError, isNotNull);

    // Se repara el dato y se reintenta: se aplica la plantilla.
    await setRaw(valid);
    await notifier.retryLoad();
    await settle();

    final state = container.read(provider);
    expect(state.loadError, isNull);
    expect(state.amountText, '500.000');
    expect(state.merchantText, 'Casero');
    expect(state.loading, isFalse);
  });
}
