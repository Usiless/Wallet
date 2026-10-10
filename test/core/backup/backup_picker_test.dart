import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:finanzas_locales/core/backup/backup_codec.dart';
import 'package:finanzas_locales/core/backup/backup_service.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late _Picker picker;
  late FilePickerPlatform previous;
  late Uint8List backup;

  setUpAll(() async {
    backup = await BackupCodec().encode(
      databaseBytes: Uint8List.fromList([
        ...utf8.encode('SQLite format 3\u0000'),
        ...List<int>.filled(1024, 0),
      ]),
      password: 'clave-de-prueba',
      summary: BackupSummary(
        createdAt: DateTime.utc(2026, 10, 4),
        schemaVersion: 1,
        accountCount: 2,
        transactionCount: 3,
        currencyCodes: ['PYG'],
      ),
    );
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    previous = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
  });
  tearDown(() async {
    FilePickerPlatform.instance = previous;
    await database.close();
  });

  test('cancelar selección de backup no modifica la base', () async {
    expect(await BackupService(database).pickForRestore(), isNull);
    expect(await database.select(database.accounts).get(), isEmpty);
    expect(picker.extensions, ['finbackup']);
  });

  test('lee un backup por bytes sin depender de una ruta local', () async {
    picker.selected = _SelectedFile('copia.finbackup', backup);
    final selected = await BackupService(database).pickForRestore();
    expect(selected!.$1, backup);
    expect(selected.$2.accountCount, 2);
    expect(selected.$2.transactionCount, 3);
    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
  });

  test('un archivo ilegible produce un error comprensible', () async {
    picker.selected = _SelectedFile('copia.finbackup', null);
    await expectLater(
      BackupService(database).pickForRestore(),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'mensaje',
          'No se pudo leer el archivo elegido.',
        ),
      ),
    );
  });
}

final class _SelectedFile extends PlatformFile {
  _SelectedFile(this.name, this.data);
  @override
  final String name;
  final Uint8List? data;
  @override
  Future<Uint8List> readAsBytes() async {
    if (data == null) throw StateError('Archivo no disponible');
    return data!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker extends FilePickerPlatform {
  PlatformFile? selected;
  List<String>? extensions;
  Uri? saveResult;
  Uint8List? savedBytes;
  String? savedName;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    extensions = allowedExtensions;
    return selected;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    savedName = fileName;
    savedBytes = bytes;
    return saveResult;
  }
}
