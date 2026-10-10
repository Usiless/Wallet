import 'dart:io';

import 'package:finanzas_locales/core/database/encrypted_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  const key =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'wallet-encryption-test-',
    );
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('migración cifra una copia temporal y conserva todos los datos', () {
    final path = '${directory.path}/test.sqlite';
    final plain = sqlite3.open(path);
    plain.execute(
      'CREATE TABLE example (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
    );
    plain.execute('INSERT INTO example VALUES (1, ?)', [
      'Datos de prueba descartables',
    ]);
    plain.close();
    expect(isPlaintextDatabase(File(path)), isTrue);
    migratePlaintextDatabase(path, key);
    expect(isPlaintextDatabase(File(path)), isFalse);
    final encrypted = sqlite3.open(path);
    encrypted.execute("PRAGMA key = '$key'");
    expect(
      encrypted.select('SELECT value FROM example').single['value'],
      'Datos de prueba descartables',
    );
    expect(
      encrypted.select('PRAGMA integrity_check').single.values.single,
      'ok',
    );
    encrypted.close();
    expect(File('$path.migration-original').existsSync(), isFalse);
    migratePlaintextDatabase(path, key);
    final unavailable = sqlite3.open(path);
    expect(
      () => unavailable.select('SELECT * FROM example'),
      throwsA(isA<SqliteException>()),
    );
    unavailable.close();
  });
  test('recupera interrupción entre renombrar original e instalar copia', () {
    final path = '${directory.path}/test.sqlite';
    final original = sqlite3.open('$path.migration-original');
    original.execute('CREATE TABLE example (value TEXT)');
    original.execute("INSERT INTO example VALUES ('conservado')");
    original.close();
    migratePlaintextDatabase(path, key);
    final recovered = sqlite3.open(path);
    recovered.execute("PRAGMA key = '$key'");
    expect(
      recovered.select('SELECT value FROM example').single['value'],
      'conservado',
    );
    recovered.close();
  });
  test(
    'WAL y copia portátil no conservan texto financiero en la base cifrada',
    () {
      final path = '${directory.path}/wal.sqlite';
      final database = sqlite3.open(path);
      requireCipher(database);
      database.execute("PRAGMA key = '$key'");
      database.execute('PRAGMA journal_mode = WAL');
      database.execute('CREATE TABLE example (value TEXT)');
      database.execute(
        "INSERT INTO example VALUES ('dato financiero identificable')",
      );
      expect(
        String.fromCharCodes(File('$path-wal').readAsBytesSync())
            .contains('dato financiero identificable'),
        isFalse,
      );
      final snapshot = '${directory.path}/snapshot.sqlite';
      database.execute("VACUUM INTO '$snapshot'");
      database.close();
      makePortableSnapshot(snapshot, key);
      expect(isPlaintextDatabase(File(snapshot)), isTrue);
      final portable = sqlite3.open(snapshot);
      expect(
        portable.select('SELECT value FROM example').single['value'],
        'dato financiero identificable',
      );
      portable.close();
    },
  );
}
