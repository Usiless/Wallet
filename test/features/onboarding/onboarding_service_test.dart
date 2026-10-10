import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/onboarding/data/onboarding_service.dart';
import 'package:finanzas_locales/features/onboarding/domain/onboarding_config.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository settings;
  late OnboardingService onboarding;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(database);
    onboarding = OnboardingService(
      database,
      AccountsService(database),
      settings,
    );
  });

  tearDown(() => database.close());

  test(
    'configuración inicial no crea cuentas ni alias automáticamente',
    () async {
      await onboarding.ensureSystemData();
      await onboarding.complete(const OnboardingConfig());

      expect(await database.select(database.accounts).get(), isEmpty);
      expect(await database.select(database.accountAliases).get(), isEmpty);
      expect(await database.select(database.creditCardProfiles).get(), isEmpty);
      expect(await settings.readBool('onboarding_complete'), isTrue);
      expect(await database.select(database.categories).get(), isNotEmpty);
    },
  );

  test(
    'crea únicamente las cuentas y datos ingresados por el usuario',
    () async {
      await onboarding.complete(
        const OnboardingConfig(
          accounts: [
            CreateAccountDraft(
              name: 'Mi banco',
              type: AccountType.bank,
              initialBalanceMinor: 150000,
            ),
            CreateAccountDraft(
              name: 'Mi tarjeta',
              type: AccountType.creditCard,
              aliases: ['••1234'],
              creditLimitMinor: 2000000,
              closingDay: 15,
              dueDay: 25,
              includeInAvailableMoney: false,
            ),
          ],
        ),
      );

      final accounts = await database.select(database.accounts).get();
      expect(accounts.map((account) => account.name), [
        'Mi banco',
        'Mi tarjeta',
      ]);
      expect(accounts.first.initialBalanceMinor, 150000);
      final aliases = await database.select(database.accountAliases).get();
      expect(aliases.single.alias, '••1234');
      final profile = await database
          .select(database.creditCardProfiles)
          .getSingle();
      expect(profile.creditLimitMinor, 2000000);
      expect(profile.closingDay, 15);
      expect(profile.dueDay, 25);
    },
  );

  test('un error no deja cuentas creadas parcialmente', () async {
    await expectLater(
      onboarding.complete(
        const OnboardingConfig(
          accounts: [
            CreateAccountDraft(name: 'Mi cuenta', type: AccountType.bank),
            CreateAccountDraft(name: '', type: AccountType.bank),
          ],
        ),
      ),
      throwsException,
    );
    expect(await database.select(database.accounts).get(), isEmpty);
    expect(await settings.readBool('onboarding_complete'), isFalse);
  });
}
