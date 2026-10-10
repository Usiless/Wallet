import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

String sqlString(String value) => value.replaceAll("'", "''");

void requireCipher(Database database) {
  if (database.select('PRAGMA cipher').isEmpty) {
    throw StateError('El motor de almacenamiento no tiene cifrado habilitado.');
  }
}

bool isPlaintextDatabase(File file) {
  if (!file.existsSync() || file.lengthSync() < 16) return false;
  final handle = file.openSync();
  try {
    return String.fromCharCodes(handle.readSync(16)) == 'SQLite format 3\u0000';
  } finally {
    handle.closeSync();
  }
}

/// Work runs in the database isolate. Preserve the original until the encrypted
/// copy has passed integrity validation; recover a crash between the two renames.
void migratePlaintextDatabase(String path, String key) {
  final active = File(path);
  final original = File('$path.migration-original');
  final temporary = File('$path.migration-encrypted');
  if (!active.existsSync() && original.existsSync()) original.renameSync(path);
  if (isPlaintextDatabase(active)) {
    if (temporary.existsSync()) temporary.deleteSync();
    final plain = sqlite3.open(path);
    try {
      requireCipher(plain);
      plain.execute("VACUUM INTO '${sqlString(temporary.path)}'");
    } finally {
      plain.close();
    }
    final encrypted = sqlite3.open(temporary.path);
    try {
      requireCipher(encrypted);
      encrypted.execute("PRAGMA rekey = '${sqlString(key)}'");
      if (encrypted.select('PRAGMA integrity_check').single.values.single !=
          'ok') {
        throw StateError(
          'No se pudo verificar la migración del almacenamiento.',
        );
      }
    } finally {
      encrypted.close();
    }
    if (original.existsSync()) original.deleteSync();
    active.renameSync(original.path);
    try {
      temporary.renameSync(path);
    } catch (_) {
      original.renameSync(path);
      rethrow;
    }
    for (final suffix in ['-wal', '-shm']) {
      final sidecar = File('$path$suffix');
      if (sidecar.existsSync()) sidecar.deleteSync();
    }
  }
  if (original.existsSync() && active.existsSync()) {
    for (final suffix in ['-wal', '-shm']) {
      final sidecar = File('$path$suffix');
      if (sidecar.existsSync()) sidecar.deleteSync();
    }
    final check = sqlite3.open(path);
    try {
      requireCipher(check);
      check.execute("PRAGMA key = '${sqlString(key)}'");
      if (check.select('PRAGMA integrity_check').single.values.single != 'ok') {
        throw StateError('El almacenamiento migrado no pasó la validación.');
      }
    } finally {
      check.close();
    }
    original.deleteSync();
  }
}

/// A VACUUM snapshot may inherit the active key. Convert only the temporary
/// portable backup copy to SQLite plaintext before password encryption.
void makePortableSnapshot(String path, String key) {
  if (isPlaintextDatabase(File(path))) return;
  final snapshot = sqlite3.open(path);
  try {
    requireCipher(snapshot);
    snapshot.execute("PRAGMA key = '${sqlString(key)}'");
    snapshot.execute("PRAGMA rekey = ''");
  } finally {
    snapshot.close();
  }
}
