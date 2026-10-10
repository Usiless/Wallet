import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/settings/settings_repository.dart';
import '../../accounts/data/accounts_service.dart';
import '../domain/onboarding_config.dart';

final class OnboardingService {
  OnboardingService(this.database, this.accounts, this.settings);

  final AppDatabase database;
  final AccountsService accounts;
  final SettingsRepository settings;

  Future<void> ensureSystemData() async {
    final count = database.categories.id.count();
    final exists =
        await (database.selectOnly(database.categories)..addColumns([count]))
            .map((row) => row.read(count)!)
            .getSingle();
    if (exists > 0) return;
    final now = DateTime.now().toUtc();
    const defaults = [
      ('sys-food', 'Alimentación', 'expense', 'restaurant', 0xFFB85C38),
      ('sys-transport', 'Transporte', 'expense', 'directions_car', 0xFF386FA4),
      ('sys-home', 'Hogar', 'expense', 'home', 0xFF7A5C9E),
      ('sys-health', 'Salud', 'expense', 'medical_services', 0xFFB34255),
      ('sys-leisure', 'Ocio', 'expense', 'celebration', 0xFF9A6D15),
      ('sys-services', 'Servicios', 'expense', 'receipt_long', 0xFF4C6B75),
      ('sys-salary', 'Salario', 'income', 'payments', 0xFF217A55),
      ('sys-other-expense', 'Otros gastos', 'expense', 'category', 0xFF6E6E6E),
      ('sys-other-income', 'Otros ingresos', 'income', 'add_card', 0xFF39796B),
    ];
    await database.batch((batch) {
      batch.insertAll(database.categories, [
        for (var index = 0; index < defaults.length; index++)
          CategoriesCompanion.insert(
            id: defaults[index].$1,
            name: defaults[index].$2,
            kind: defaults[index].$3,
            icon: Value(defaults[index].$4),
            color: Value(defaults[index].$5),
            isSystem: const Value(true),
            sortOrder: Value(index),
            createdAt: now,
            updatedAt: now,
          ),
      ]);
    });
    await settings.write('default_currency', 'PYG');
    await settings.write('notification_listener_enabled', 'false');
    await settings.write(
      'notification_packages',
      '["com.google.android.gms","com.google.android.apps.walletnfcrel"]',
    );
    await settings.write('sms_notifications_enabled', 'false');
    await settings.write('diagnostic_mode', 'false');
  }

  Future<void> complete(OnboardingConfig config) async {
    await database.transaction(() async {
      for (final draft in config.accounts) {
        await accounts.createAccount(draft);
      }
      await settings.write('default_currency', config.currencyCode);
      await settings.write('app_lock_enabled', config.enableAppLock.toString());
      await settings.write('onboarding_complete', 'true');
    });
  }
}
