import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:finanzas_locales/core/backup/backup_codec.dart';
import 'package:finanzas_locales/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PBKDF2 conserva compatibilidad con contraseñas Unicode', () async {
    final bytes = await deriveBackupKeyInBackground(
      'clave de prueba ñ',
      List.generate(16, (i) => i),
    );
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(
      hex,
      '9ccec593ebf0e695fae2aa0500862625bed63952d993769ac7f430008c5e2558',
    );
  });

  final database = Uint8List.fromList([
    ...utf8.encode('SQLite format 3\u0000'),
    ...List<int>.generate(1024, (index) => index % 251),
  ]);
  final summary = BackupSummary(
    createdAt: _fixedDate,
    schemaVersion: 1,
    accountCount: 4,
    transactionCount: 20,
    currencyCodes: ['PYG'],
  );

  test('cifra, inspecciona y restaura exactamente', () async {
    final codec = BackupCodec(random: Random(1));
    final encrypted = await codec.encode(
      databaseBytes: database,
      password: 'clave-segura',
      summary: summary,
    );
    expect(encrypted, isNot(contains(database)));
    expect(codec.inspect(encrypted).transactionCount, 20);
    final restored = await codec.decode(encrypted, password: 'clave-segura');
    expect(restored.databaseBytes, database);
  });

  test('contraseña incorrecta no entrega datos', () async {
    final codec = BackupCodec(random: Random(2));
    final encrypted = await codec.encode(
      databaseBytes: database,
      password: 'clave-correcta',
      summary: summary,
    );
    await expectLater(
      codec.decode(encrypted, password: 'clave-erronea'),
      throwsA(isA<BackupException>()),
    );
  });

  test('archivo corrupto falla antes de modificar ninguna base', () {
    final codec = BackupCodec();
    expect(
      () => codec.inspect(Uint8List.fromList(utf8.encode('{corrupto'))),
      throwsA(isA<BackupException>()),
    );
  });
}

final _fixedDate = DateTime.utc(2026, 7, 19, 12);
