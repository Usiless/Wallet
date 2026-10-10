import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '../security/device_crypto.dart';

import 'dart:math';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

import '../errors/app_exception.dart';

final class BackupSummary {
  const BackupSummary({
    required this.createdAt,
    required this.schemaVersion,
    required this.accountCount,
    required this.transactionCount,
    required this.currencyCodes,
  });

  factory BackupSummary.fromJson(Map<String, Object?> json) => BackupSummary(
    createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
    schemaVersion: json['schemaVersion']! as int,
    accountCount: json['accountCount']! as int,
    transactionCount: json['transactionCount']! as int,
    currencyCodes: (json['currencyCodes']! as List).cast<String>(),
  );

  final DateTime createdAt;
  final int schemaVersion;
  final int accountCount;
  final int transactionCount;
  final List<String> currencyCodes;

  Map<String, Object?> toJson() => {
    'createdAt': createdAt.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
    'accountCount': accountCount,
    'transactionCount': transactionCount,
    'currencyCodes': currencyCodes,
  };
}

final class DecodedBackup {
  const DecodedBackup({required this.summary, required this.databaseBytes});

  final BackupSummary summary;
  final Uint8List databaseBytes;
}

final class BackupCodec {
  BackupCodec({Random? random}) : random = random ?? Random.secure();

  static const magic = 'FINANZAS_LOCALES_BACKUP';
  static const formatVersion = 1;
  static const kdfIterations = 310000;

  final Random random;
  final _cipher = AesGcm.with256bits();

  Future<Uint8List> encode({
    required Uint8List databaseBytes,
    required String password,
    required BackupSummary summary,
  }) async {
    _validatePassword(password);
    final salt = _randomBytes(16);
    final key = await _deriveKey(password, salt);
    final compressed = GZipEncoder().encode(databaseBytes);
    final summaryJson = summary.toJson();
    final databaseSha256 = hashes.sha256.convert(databaseBytes).toString();
    final aad = utf8.encode(
      jsonEncode({
        'magic': magic,
        'formatVersion': formatVersion,
        'summary': summaryJson,
        'databaseSha256': databaseSha256,
      }),
    );
    final box = await _cipher.encrypt(compressed, secretKey: key, aad: aad);
    final envelope = {
      'magic': magic,
      'formatVersion': formatVersion,
      'summary': summaryJson,
      'databaseSha256': databaseSha256,
      'kdf': {
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': kdfIterations,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'name': 'AES-256-GCM',
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  BackupSummary inspect(Uint8List bytes) {
    final envelope = _envelope(bytes);
    return BackupSummary.fromJson(
      (envelope['summary']! as Map).cast<String, Object?>(),
    );
  }

  Future<DecodedBackup> decode(
    Uint8List bytes, {
    required String password,
  }) async {
    final envelope = _envelope(bytes);
    final summary = BackupSummary.fromJson(
      (envelope['summary']! as Map).cast<String, Object?>(),
    );
    final kdf = (envelope['kdf']! as Map).cast<String, Object?>();
    final cipherJson = (envelope['cipher']! as Map).cast<String, Object?>();
    final expectedSha256 = envelope['databaseSha256'];
    if (kdf['name'] != 'PBKDF2-HMAC-SHA256' ||
        cipherJson['name'] != 'AES-256-GCM' ||
        kdf['iterations'] != kdfIterations ||
        expectedSha256 is! String) {
      throw const BackupException(
        'El método criptográfico del backup no es compatible.',
      );
    }
    try {
      final key = await _deriveKey(
        password,
        base64Decode(kdf['salt']! as String),
      );
      final aad = utf8.encode(
        jsonEncode({
          'magic': magic,
          'formatVersion': formatVersion,
          'summary': summary.toJson(),
          'databaseSha256': expectedSha256,
        }),
      );
      final clearCompressed = await _cipher.decrypt(
        SecretBox(
          base64Decode(cipherJson['ciphertext']! as String),
          nonce: base64Decode(cipherJson['nonce']! as String),
          mac: Mac(base64Decode(cipherJson['mac']! as String)),
        ),
        secretKey: key,
        aad: aad,
      );
      final database = GZipDecoder().decodeBytes(clearCompressed);
      final actualSha256 = hashes.sha256.convert(database).toString();
      if (actualSha256 != expectedSha256) {
        throw const BackupException(
          'La suma de verificación del backup no coincide.',
        );
      }
      if (database.length < 16 ||
          utf8.decode(database.take(15).toList(), allowMalformed: true) !=
              'SQLite format 3') {
        throw const BackupException(
          'El backup no contiene una base SQLite válida.',
        );
      }
      return DecodedBackup(
        summary: summary,
        databaseBytes: Uint8List.fromList(database),
      );
    } on SecretBoxAuthenticationError {
      throw const BackupException('Contraseña incorrecta o archivo alterado.');
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException(
        'No se pudo descifrar el backup.',
        technicalDetail: '$error',
      );
    }
  }

  Map<String, Object?> _envelope(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw const FormatException();
      final envelope = decoded.cast<String, Object?>();
      if (envelope['magic'] != magic) {
        throw const BackupException('El archivo no es un backup de Cabal.');
      }
      final version = envelope['formatVersion'];
      if (version is! int || version > formatVersion || version < 1) {
        throw BackupException('Versión de backup no compatible: $version.');
      }
      return envelope;
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException(
        'El archivo de backup está corrupto.',
        technicalDetail: '$error',
      );
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    if (Platform.isAndroid) {
      try {
        final bytes = await DeviceCrypto.channel
            .invokeMethod<Uint8List>('deriveBackupKey', {
              'password': password,
              'salt': Uint8List.fromList(salt),
            })
            .timeout(const Duration(seconds: 30));
        if (bytes == null || bytes.length != 32) {
          throw const BackupException(
            'No se pudo obtener la clave del backup.',
          );
        }
        return SecretKey(bytes);
      } on MissingPluginException {
        /* Older Android: use the compatible Dart implementation. */
      } on PlatformException {
        /* Android providers may not implement SHA256 PBKDF2. */
      }
    }
    return SecretKey(await deriveBackupKeyInBackground(password, salt));
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));

  void _validatePassword(String password) {
    if (password.length < 8) {
      throw const BackupException(
        'La contraseña del backup debe tener al menos 8 caracteres.',
      );
    }
  }
}

Future<Uint8List> deriveBackupKeyInBackground(
  String password,
  List<int> salt,
) => Isolate.run(() async {
  final key = await Pbkdf2.hmacSha256(
    iterations: BackupCodec.kdfIterations,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);
  return Uint8List.fromList(await key.extractBytes());
});
