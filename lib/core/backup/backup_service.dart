import 'dart:io';
import 'dart:convert';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../database/encrypted_storage.dart';
import '../security/device_crypto.dart';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../errors/app_exception.dart';
import 'backup_codec.dart';
import '../../features/transactions/domain/ledger_models.dart';

final class BackupService {
  BackupService(
    this.database, {
    BackupCodec? codec,
    Uuid? uuid,
    this.directory,
    this.encryptionKey,
  }) : codec = codec ?? BackupCodec(),
       uuid = uuid ?? const Uuid();

  final Directory? directory;
  final Future<String> Function()? encryptionKey;
  final AppDatabase database;
  final BackupCodec codec;
  final Uuid uuid;

  Future<Uint8List> createBytes(String password) async {
    final tempDirectory = directory ?? await getTemporaryDirectory();
    final snapshot = File(
      p.join(tempDirectory.path, 'backup-${uuid.v4()}.sqlite'),
    );
    try {
      final escapedPath = snapshot.path.replaceAll("'", "''");
      await database.customStatement("VACUUM INTO '$escapedPath'");
      final accountCountExpression = database.accounts.id.count();
      final accountCountQuery = database.selectOnly(database.accounts)
        ..addColumns([accountCountExpression]);
      final accounts = await accountCountQuery
          .map((row) => row.read(accountCountExpression) ?? 0)
          .getSingle();
      final transactionCountExpression = database.ledgerTransactions.id.count();
      final transactionCountQuery = database.selectOnly(
        database.ledgerTransactions,
      )..addColumns([transactionCountExpression]);
      final transactions = await transactionCountQuery
          .map((row) => row.read(transactionCountExpression) ?? 0)
          .getSingle();
      final currencies =
          await (database.selectOnly(database.accounts, distinct: true)
                ..addColumns([database.accounts.currencyCode]))
              .map((row) => row.read(database.accounts.currencyCode)!)
              .get();
      if (!isPlaintextDatabase(snapshot)) {
        final key = await (encryptionKey?.call() ?? DeviceCrypto.databaseKey());
        final path = snapshot.path;
        await portableSnapshotInBackground(path, key);
      }
      return await codec.encode(
        databaseBytes: await snapshot.readAsBytes(),
        password: password,
        summary: BackupSummary(
          createdAt: DateTime.now().toUtc(),
          schemaVersion: database.schemaVersion,
          accountCount: accounts,
          transactionCount: transactions,
          currencyCodes: currencies,
        ),
      );
    } finally {
      if (await snapshot.exists()) await snapshot.delete();
    }
  }

  Future<bool> createWithPicker(String password) async {
    final bytes = await createBytes(password);
    final now = DateTime.now();
    final name =
        'finanzas-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.finbackup';
    final path = await FilePicker.saveFile(
      dialogTitle: 'Guardar backup cifrado',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['finbackup'],
      bytes: bytes,
    );
    return path != null;
  }

  Future<(Uint8List, BackupSummary)?> pickForRestore() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['finbackup'],
    );
    if (result == null) return null;
    final Uint8List data;
    try {
      data = await result.readAsBytes();
    } catch (_) {
      throw const BackupException('No se pudo leer el archivo elegido.');
    }
    return (data, codec.inspect(data));
  }

  Future<void> restore(
    Uint8List encrypted,
    String password, {
    void Function(String)? onProgress,
  }) async {
    onProgress?.call('Descifrando backup…');
    final decoded = await codec.decode(encrypted, password: password);
    if (decoded.summary.schemaVersion != database.schemaVersion) {
      throw const BackupException(
        'La versión de la base del backup no es compatible.',
      );
    }
    final tempDirectory = directory ?? await getTemporaryDirectory();
    final candidate = File(
      p.join(tempDirectory.path, 'restore-${uuid.v4()}.sqlite'),
    );
    try {
      onProgress?.call('Validando datos…');
      await candidate.writeAsBytes(decoded.databaseBytes, flush: true);
      final expected = <String, List<String>>{};
      for (final table in database.allTables) {
        expected[table.actualTableName] = table.$columns
            .map((column) => column.$name)
            .toList();
      }
      final path = candidate.path;
      final version = database.schemaVersion;
      final rows = await validateSnapshotInBackground(path, version, expected);
      onProgress?.call('Guardando copia de seguridad…');
      final safetyDirectory =
          directory ?? await getApplicationSupportDirectory();
      final safety = File(
        p.join(safetyDirectory.path, 'before-restore-${uuid.v4()}.finbackup'),
      );
      await safety.writeAsBytes(await createBytes(password), flush: true);
      onProgress?.call('Restaurando datos…');
      await database.transaction(() async {
        database.restoreGeneration++;
        await database.customStatement('PRAGMA defer_foreign_keys = ON');
        for (final table in expected.keys) {
          await database.customStatement('DELETE FROM "$table"');
        }
        for (final entry in rows.entries) {
          final columns = expected[entry.key]!;
          final names = columns.map((name) => '"$name"').join(',');
          final placeholders = List.filled(columns.length, '?').join(',');
          for (final row in entry.value) {
            await database.customStatement(
              'INSERT INTO "${entry.key}" ($names) VALUES ($placeholders)',
              columns.map((column) => row[column]).toList(),
            );
          }
        }
        if ((await database.customSelect('PRAGMA foreign_key_check').get())
            .isNotEmpty) {
          throw const BackupException(
            'El backup contiene referencias de datos inválidas.',
          );
        }
      });
      database.notifyUpdates({
        for (final table in database.allTables)
          TableUpdate(table.actualTableName),
      });
      onProgress?.call('Restauración completada');
    } finally {
      if (await candidate.exists()) await candidate.delete();
    }
  }
}

Map<String, List<Map<String, Object?>>> readValidatedSnapshot(
  String path,
  int version,
  Map<String, List<String>> expected,
) {
  final source = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
  try {
    if (source.select('PRAGMA integrity_check').single.values.single != 'ok' ||
        source.select('PRAGMA foreign_key_check').isNotEmpty ||
        source.select('PRAGMA user_version').single.values.single != version) {
      throw const BackupException(
        'La base del backup no pasó la validación de integridad.',
      );
    }
    final actual = source
        .select(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .map((row) => row['name'] as String)
        .toSet();
    if (actual.length != expected.length ||
        !actual.containsAll(expected.keys)) {
      throw const BackupException(
        'El esquema del backup no corresponde a esta app.',
      );
    }
    final result = <String, List<Map<String, Object?>>>{};
    for (final entry in expected.entries) {
      final columns = source
          .select('PRAGMA table_info("${entry.key}")')
          .map((row) => row['name'] as String)
          .toSet();
      if (columns.length != entry.value.length ||
          !columns.containsAll(entry.value)) {
        throw const BackupException(
          'El esquema del backup contiene columnas incompatibles.',
        );
      }
      result[entry.key] = source
          .select('SELECT * FROM "${entry.key}"')
          .map((row) => Map<String, Object?>.from(row))
          .toList();
    }
    final accounts = {
      for (final row in result['accounts'] ?? <Map<String, Object?>>[])
        row['id'],
    };
    final merchants = {
      for (final row in result['merchants'] ?? <Map<String, Object?>>[])
        row['id'],
    };
    final categories = {
      for (final row in result['categories'] ?? <Map<String, Object?>>[])
        row['id'],
    };
    final transactions = {
      for (final row in result['transactions'] ?? <Map<String, Object?>>[])
        row['id']: row,
    };
    final pending = <String, Map<String, dynamic>>{};
    final linkedTransactions = <String>{};
    for (final row in result['app_settings'] ?? <Map<String, Object?>>[]) {
      final key = row['key'] as String;
      if (!key.startsWith('pending_payment:')) continue;
      if (!key.startsWith('pending_payment:v1:')) {
        throw const FormatException('Unknown payment version');
      }
      final p = Map<String, dynamic>.from(
        jsonDecode(row['value'] as String) as Map,
      );
      if (p['version'] != 1 ||
          key != 'pending_payment:v1:${p['id']}' ||
          !accounts.contains(p['accountId']) ||
          (p['merchantId'] != null && !merchants.contains(p['merchantId'])) ||
          p['amountMinor'] is! int ||
          (p['amountMinor'] as int) <= 0 ||
          p['revision'] is! int ||
          (p['revision'] as int) < 0 ||
          p['cancelled'] is! bool ||
          p['planId'] is! String ||
          p['description'] is! String ||
          p['note'] is! String ||
          !PaymentChannel.values.any(
            (channel) => channel.name == p['paymentChannel'],
          ) ||
          p['installmentNumber'] is! int ||
          p['installmentCount'] is! int ||
          (p['installmentCount'] as int) < 1 ||
          (p['installmentCount'] as int) > 120 ||
          (p['installmentNumber'] as int) < 1 ||
          (p['installmentNumber'] as int) > (p['installmentCount'] as int)) {
        throw const FormatException('Invalid pending payment');
      }
      DateTime.parse(p['dueDate'] as String);
      var total = 0;
      final splitCategories = <String>{};
      for (final part in p['splits'] as List) {
        if (!categories.contains(part['categoryId']) ||
            !splitCategories.add(part['categoryId'] as String) ||
            part['amountMinor'] is! int ||
            (part['amountMinor'] as int) < 0) {
          throw const FormatException('Invalid split');
        }
        total += part['amountMinor'] as int;
      }
      if ((p['splits'] as List).isNotEmpty && total != p['amountMinor']) {
        throw const FormatException('Invalid split total');
      }
      var paid = 0;
      final seen = <String>{};
      for (final payment in p['payments'] as List) {
        final id = payment['transactionId'] as String;
        final tx = transactions[id];
        if (!seen.add(id) ||
            !linkedTransactions.add(id) ||
            tx == null ||
            tx['type'] != 'expense' ||
            !(tx['external_fingerprint'] as String? ?? '').startsWith(
              'pending:${p['id']}:',
            ) ||
            payment['amountMinor'] is! int ||
            (payment['amountMinor'] as int) <= 0 ||
            !accounts.contains(payment['accountId'])) {
          throw const FormatException('Invalid payment reference');
        }
        if (tx['status'] == 'confirmed') paid += tx['amount_minor'] as int;
      }
      if ((p['carriedMinor'] as int? ?? 0) < 0 ||
          paid + (p['carriedMinor'] as int? ?? 0) > (p['amountMinor'] as int)) {
        throw const FormatException('Overpaid obligation');
      }
      final reminders = p['reminders'] as Map;
      if (reminders['enabled'] is! bool ||
          reminders['onDueDate'] is! bool ||
          (reminders['hour'] as int) < 0 ||
          (reminders['hour'] as int) > 23 ||
          (reminders['minute'] as int) < 0 ||
          (reminders['minute'] as int) > 59 ||
          (reminders['daysBefore'] as int) < 0 ||
          (reminders['daysBefore'] as int) > 60) {
        throw const FormatException('Invalid reminders');
      }
      pending[p['id'] as String] = p;
    }
    for (final p in pending.values) {
      final carriedMinor = p['carriedMinor'] as int? ?? 0;
      final classified = (p['splits'] as List).isNotEmpty;
      Map<String, int> transferParts(Object? raw, int amount) {
        final values = <String, int>{};
        for (final part in raw as List? ?? []) {
          final id = part['categoryId'];
          final value = part['amountMinor'];
          if (id is! String ||
              !categories.contains(id) ||
              value is! int ||
              value < 0 ||
              values.containsKey(id)) {
            throw const FormatException('Invalid carry category');
          }
          values[id] = value;
        }
        final sum = values.values.fold<int>(0, (n, v) => n + v);
        if (classified ? sum != amount : values.isNotEmpty) {
          throw const FormatException('Invalid carry category total');
        }
        values.removeWhere((_, value) => value == 0);
        return values;
      }

      final cumulative = transferParts(p['carriedSplits'], carriedMinor);
      var history = p['carries'] as List?;
      // Old v1 records with a concrete target can be normalized without
      // inventing debt; an orphaned carried amount never qualifies.
      if (carriedMinor > 0 && history == null && p['carriedTo'] != null) {
        history = [
          {
            'to': p['carriedTo'],
            'amountMinor': carriedMinor,
            'splits': p['carriedSplits'] ?? [],
          },
        ];
        p['carries'] = history;
      }
      history ??= [];
      if (carriedMinor == 0) {
        if (history.isNotEmpty ||
            p['carriedTo'] != null ||
            cumulative.isNotEmpty) {
          throw const FormatException('Unexpected carry trace');
        }
        continue;
      }
      if (history.isEmpty || p['carriedTo'] != history.last['to']) {
        throw const FormatException('Missing carry history');
      }
      var total = 0;
      final categoriesTransferred = <String, int>{};
      for (final carry in history) {
        final target = pending[carry['to']];
        final amount = carry['amountMinor'];
        if (target == null ||
            target['planId'] != p['planId'] ||
            target['installmentCount'] != p['installmentCount'] ||
            (target['installmentNumber'] as int) <=
                (p['installmentNumber'] as int) ||
            amount is! int ||
            amount <= 0) {
          throw const FormatException('Invalid carry destination');
        }
        total += amount;
        for (final entry in transferParts(carry['splits'], amount).entries) {
          categoriesTransferred[entry.key] =
              (categoriesTransferred[entry.key] ?? 0) + entry.value;
        }
      }
      if (total != carriedMinor ||
          cumulative.length != categoriesTransferred.length ||
          cumulative.entries.any(
            (entry) => categoriesTransferred[entry.key] != entry.value,
          )) {
        throw const FormatException('Invalid carry history total');
      }
      final sourceCategories = {
        for (final part in p['splits'] as List)
          part['categoryId']: part['amountMinor'] as int,
      };
      if (cumulative.entries.any(
        (entry) => (sourceCategories[entry.key] ?? 0) < entry.value,
      )) {
        throw const FormatException('Carry exceeds source category');
      }
    }
    for (final row in result['app_settings'] ?? <Map<String, Object?>>[]) {
      final payment =
          pending[(row['key'] as String).replaceFirst(
            'pending_payment:v1:',
            '',
          )];
      if (payment != null) row['value'] = jsonEncode(payment);
    }
    return result;
  } on BackupException {
    rethrow;
  } catch (_) {
    throw const BackupException('No se pudo validar la base del backup.');
  } finally {
    source.close();
  }
}

Future<void> portableSnapshotInBackground(String path, String key) =>
    Isolate.run(() => makePortableSnapshot(path, key));
Future<Map<String, List<Map<String, Object?>>>> validateSnapshotInBackground(
  String path,
  int version,
  Map<String, List<String>> expected,
) => Isolate.run(() => readValidatedSnapshot(path, version, expected));

Future<void> cleanupBackupWorkingFiles() async {
  final directory = await getTemporaryDirectory();
  final owned = RegExp(
    r'^(backup|restore)-[0-9a-f-]{36}\.sqlite(?:-(?:wal|shm))?$',
  );
  await for (final entry in directory.list(followLinks: false)) {
    if (entry is File && owned.hasMatch(p.basename(entry.path))) {
      await entry.delete();
    }
  }
}
