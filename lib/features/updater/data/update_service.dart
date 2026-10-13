import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/app_version.dart';
import '../domain/release_info.dart';
import 'update_log.dart';

const _userAgent = 'Cabal-updater';
const _requestTimeout = Duration(seconds: 15);
const _downloadIdleTimeout = Duration(seconds: 30);
final _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

Future<String> _packageVersion() async =>
    (await PackageInfo.fromPlatform()).version;

Future<Directory> _defaultDownloadDirectory() async {
  final temporary = await getTemporaryDirectory();
  return Directory(p.join(temporary.path, 'updates'));
}

final class UpdateService {
  UpdateService({
    http.Client? client,
    Future<String> Function()? installedVersion,
    Future<Directory> Function()? downloadDirectory,
    String repository = 'Usiless/Wallet',
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _installedVersion = installedVersion ?? _packageVersion,
       _downloadDirectory = downloadDirectory ?? _defaultDownloadDirectory,
       _repository = repository;

  final http.Client _client;
  final bool _ownsClient;
  final Future<String> Function() _installedVersion;
  final Future<Directory> Function() _downloadDirectory;
  final String _repository;

  /// Release más nueva que la instalada, o null si no hay.
  /// Consulta GitHub en cada llamada: solo se invoca a pedido del usuario.
  /// Lanza UpdateException: offline (SocketException/timeout/ClientException),
  /// rateLimited (403 o 429), server (otro código ≠ 200/404, JSON inválido).
  /// 404 (repo sin releases) → null.
  Future<ReleaseInfo?> checkForUpdate() async {
    final rawInstalled = await _installedVersion();
    final installed = AppVersion.tryParse(rawInstalled);
    if (installed == null) {
      updaterLog('versión instalada no válida', error: rawInstalled);
      throw UpdateException(
        UpdateFailure.server,
        'No se pudo leer la versión de la app.',
        technicalDetail: rawInstalled,
      );
    }
    final release = await _latestRelease();
    if (release == null) return null;
    final newer = release.version > installed;
    updaterLog(
      'instalada $installed, última ${release.version}: '
      '${newer ? 'hay actualización' : 'sin cambios'}',
    );
    return newer ? release : null;
  }

  /// Descarga el APK a downloadDirectory, verifica tamaño y SHA-256 y devuelve el archivo final.
  /// Escribe en `<nombre>.part` y renombra solo tras verificar; borra el parcial en cualquier error.
  /// Borra APKs viejos del directorio antes de empezar.
  /// Si [cancel] completa, aborta y lanza UpdateException(cancelled).
  /// Sin asset .sha256: instala igual y lo registra en el log como advertencia.
  /// Hash distinto: borra el archivo, registra y lanza UpdateException(integrity).
  Future<File> download(
    ReleaseInfo release, {
    void Function(DownloadProgress progress)? onProgress,
    Future<void>? cancel,
  }) async {
    final directory = await _downloadDirectory();
    await directory.create(recursive: true);
    await _deleteStaleFiles(directory);

    final apk = release.apk;
    final target = File(p.join(directory.path, apk.name));
    final part = File('${target.path}.part');

    final checksum = release.checksum;
    final expected = checksum == null
        ? null
        : await _fetchExpectedHash(checksum, cancel);
    if (expected == null) {
      updaterLog(
        'advertencia: la release no incluye .sha256; sin verificar hash',
      );
    }

    updaterLog('descarga inicio ${apk.downloadUrl} (${apk.size} bytes)');
    var cancelled = false;
    unawaited(
      cancel?.then<void>(
        (_) {
          cancelled = true;
        },
        onError: (Object _) {
          cancelled = true;
        },
      ),
    );
    try {
      await _receive(apk, part, onProgress: onProgress, cancel: cancel);
      if (cancelled) throw _cancelled;
      await _verify(apk, part, expected);
      if (cancelled) throw _cancelled;
      await part.rename(target.path);
    } catch (error) {
      updaterLog('descarga fallida', error: error);
      if (await part.exists()) await part.delete();
      rethrow;
    }
    updaterLog('descarga lista ${target.path}');
    return target;
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<ReleaseInfo?> _latestRelease() async {
    final url = Uri.https(
      'api.github.com',
      '/repos/$_repository/releases/latest',
    );
    updaterLog('GET $url');
    final response = await _get(
      url,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': _userAgent,
      },
    );
    updaterLog('HTTP ${response.statusCode}');
    switch (response.statusCode) {
      case 200:
        final release = _parseRelease(response.body);
        if (release == null) {
          throw const UpdateException(
            UpdateFailure.server,
            'GitHub devolvió una respuesta inesperada. Probá más tarde.',
            technicalDetail: 'JSON inválido o release sin APK',
          );
        }
        updaterLog('release ${release.tag} con APK ${release.apk.name}');
        return release;
      case 404:
        updaterLog('sin releases publicadas');
        return null;
      case 403 || 429:
        throw const UpdateException(
          UpdateFailure.rateLimited,
          'GitHub limitó las consultas. Probá más tarde.',
        );
      default:
        throw UpdateException(
          UpdateFailure.server,
          'No se pudo consultar GitHub. Probá más tarde.',
          technicalDetail: 'HTTP ${response.statusCode}',
        );
    }
  }

  ReleaseInfo? _parseRelease(String body) {
    final decoded = _decodeJson(body);
    if (decoded is! Map<String, dynamic>) return null;
    final release = ReleaseInfo.fromGitHubJson(decoded);
    if (release != null &&
        release.checksum == null &&
        _hasChecksumAsset(decoded)) {
      updaterLog(
        'advertencia: la release tiene un .sha256 que no se usó (nombre o URL no válidos, o sin correspondencia)',
      );
    }
    return release;
  }

  bool _hasChecksumAsset(Map<String, dynamic> json) {
    final assets = json['assets'];
    if (assets is! List) return false;
    return assets.any(
      (asset) =>
          asset is Map &&
          asset['name'] is String &&
          (asset['name'] as String).endsWith('.sha256'),
    );
  }

  Object? _decodeJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  Future<String> _fetchExpectedHash(
    ReleaseAsset checksum,
    Future<void>? cancel,
  ) async {
    final response = await _untilCancelled(
      _get(checksum.downloadUrl, headers: const {'User-Agent': _userAgent}),
      cancel,
    );
    if (response.statusCode != 200) {
      throw UpdateException(
        UpdateFailure.download,
        'No se pudo descargar la verificación de la actualización.',
        technicalDetail: 'HTTP ${response.statusCode}',
      );
    }
    final text = utf8
        .decode(response.bodyBytes, allowMalformed: true)
        .replaceFirst('\uFEFF', '');
    final token = text
        .split(RegExp(r'\s+'))
        .where(_sha256Pattern.hasMatch)
        .firstOrNull;
    if (token == null) {
      throw UpdateException(
        UpdateFailure.download,
        'La verificación de la actualización no es válida.',
        technicalDetail: checksum.name,
      );
    }
    return token.toLowerCase();
  }

  Future<void> _receive(
    ReleaseAsset apk,
    File part, {
    void Function(DownloadProgress progress)? onProgress,
    Future<void>? cancel,
  }) async {
    final request = http.Request('GET', apk.downloadUrl)
      ..headers['User-Agent'] = _userAgent;
    final response = await _untilCancelled(
      _network(() => _client.send(request)),
      cancel,
      discard: (response) => response.stream.listen(null).cancel(),
    );
    if (response.statusCode != 200) {
      updaterLog('HTTP ${response.statusCode} al descargar');
      await response.stream.listen(null).cancel();
      throw UpdateException(
        UpdateFailure.download,
        'No se pudo descargar la actualización.',
        technicalDetail: 'HTTP ${response.statusCode}',
      );
    }

    final sink = part.openWrite();
    final done = Completer<void>();
    Timer? idle;
    var received = 0;

    StreamSubscription<List<int>>? subscription;
    void fail(Object error) {
      if (done.isCompleted) return;
      done.completeError(error);
      unawaited(subscription?.cancel());
    }

    void resetIdle() {
      idle?.cancel();
      idle = Timer(_downloadIdleTimeout, () {
        fail(
          const UpdateException(
            UpdateFailure.download,
            'La descarga se detuvo. Probá de nuevo.',
          ),
        );
      });
    }

    resetIdle();
    subscription = response.stream.listen(
      (chunk) {
        resetIdle();
        sink.add(chunk);
        received += chunk.length;
        try {
          onProgress?.call(DownloadProgress(received, apk.size));
        } catch (error) {
          updaterLog('onProgress falló', error: error);
        }
      },
      onError: (Object error, StackTrace _) {
        fail(
          error is SocketException || error is http.ClientException
              ? _offlineFailure(error)
              : UpdateException(
                  UpdateFailure.download,
                  'No se pudo descargar la actualización.',
                  technicalDetail: '$error',
                ),
        );
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    unawaited(
      cancel?.then(
        (_) => fail(_cancelled),
        onError: (Object _) => fail(_cancelled),
      ),
    );

    try {
      await done.future;
    } catch (_) {
      await _closeQuietly(sink);
      rethrow;
    } finally {
      idle?.cancel();
    }
    await sink.close();
  }

  Future<void> _verify(ReleaseAsset apk, File part, String? expected) async {
    final size = await part.length();
    if (size != apk.size) {
      updaterLog('tamaño $size, esperado ${apk.size}');
      throw const UpdateException(
        UpdateFailure.download,
        'La descarga quedó incompleta. Probá de nuevo.',
      );
    }
    if (expected == null) return;

    final actual = (await sha256.bind(part.openRead()).first).toString();
    if (actual == expected) {
      updaterLog('sha256 verificado');
      return;
    }
    updaterLog('sha256 no coincide: esperado $expected, obtenido $actual');
    await part.delete();
    throw const UpdateException(
      UpdateFailure.integrity,
      'La descarga no pasó la verificación de integridad.',
    );
  }

  Future<void> _deleteStaleFiles(Directory directory) async {
    await for (final entity in directory.list()) {
      final name = p.basename(entity.path);
      if (entity is File && (name.endsWith('.apk') || name.endsWith('.part'))) {
        await entity.delete();
      }
    }
  }

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      _network(() => _client.get(url, headers: headers));

  /// Completa con el resultado de [future], o con `cancelled` si [cancel] completa antes.
  /// [discard] libera un resultado que llega después de la cancelación.
  Future<T> _untilCancelled<T>(
    Future<T> future,
    Future<void>? cancel, {
    void Function(T value)? discard,
  }) {
    if (cancel == null) return future;
    final result = Completer<T>();
    future.then(
      (value) {
        if (result.isCompleted) {
          discard?.call(value);
        } else {
          result.complete(value);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    cancel.then(
      (_) {
        if (!result.isCompleted) result.completeError(_cancelled);
      },
      onError: (Object _) {
        if (!result.isCompleted) result.completeError(_cancelled);
      },
    );
    return result.future;
  }

  Future<T> _network<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException catch (error) {
      throw _offlineFailure(error);
    } on SocketException catch (error) {
      throw _offlineFailure(error);
    } on http.ClientException catch (error) {
      throw _offlineFailure(error);
    }
  }

  UpdateException _offlineFailure(Object error) {
    updaterLog('sin conexión', error: error);
    return UpdateException(
      UpdateFailure.offline,
      'No hay conexión.',
      technicalDetail: '$error',
    );
  }

  Future<void> _closeQuietly(IOSink sink) async {
    try {
      await sink.close();
    } catch (_) {}
  }
}

const _cancelled = UpdateException(
  UpdateFailure.cancelled,
  'Descarga cancelada.',
);
