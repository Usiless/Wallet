import '../database/app_database.dart';

final class SettingsRepository {
  SettingsRepository(this.database);

  final AppDatabase database;

  Future<String?> read(String key) async {
    final row = await (database.select(
      database.appSettings,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watch(String key) {
    return (database.select(database.appSettings)
          ..where((table) => table.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<void> write(String key, String value) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<bool> readBool(String key, {bool fallback = false}) async {
    final value = await read(key);
    if (value == null) return fallback;
    return value == 'true';
  }
}
