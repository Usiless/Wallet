import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el esquema v1 coincide con el snapshot publicado', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();
    final rows = await database
        .customSelect(
          "SELECT type, name, sql FROM sqlite_master "
          "WHERE name NOT LIKE 'sqlite_%' AND sql IS NOT NULL "
          "ORDER BY type, name",
        )
        .get();
    final objects = [
      for (final row in rows)
        {
          'type': row.read<String>('type'),
          'name': row.read<String>('name'),
          'sql': row.read<String>('sql'),
        },
    ];
    final actual = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': database.schemaVersion,
      'objectNames': [for (final object in objects) object['name']],
      'normalizedSqlSha256': sha256
          .convert(utf8.encode(jsonEncode(objects)))
          .toString(),
    });
    final snapshot = File('drift_schemas/schema_v1.json');
    if (!snapshot.existsSync()) {
      // ignore: avoid_print
      print('SCHEMA_SNAPSHOT_BEGIN\n$actual\nSCHEMA_SNAPSHOT_END');
      fail('Falta drift_schemas/schema_v1.json');
    }
    expect(jsonDecode(actual), jsonDecode(await snapshot.readAsString()));
  });
}
