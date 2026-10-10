import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saving the same setting preserves its stored revision timestamp',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = SettingsRepository(database);
      await settings.write('notification_listener_enabled', 'true');
      final before = await database.select(database.appSettings).getSingle();
      // Use a known previous timestamp; no wall-clock delay or flaky threshold.
      await database.customStatement(
        'UPDATE app_settings SET updated_at = ? WHERE key = ?',
        [123456789, before.key],
      );
      final stored = await database.select(database.appSettings).getSingle();
      await settings.write('notification_listener_enabled', 'true');
      final unchanged = await database.select(database.appSettings).getSingle();
      expect(unchanged.value, 'true');
      expect(unchanged.updatedAt, stored.updatedAt);
      await settings.write('notification_listener_enabled', 'false');
      final changed = await database.select(database.appSettings).getSingle();
      expect(changed.value, 'false');
      expect(changed.updatedAt, isNot(stored.updatedAt));
    },
  );
}
