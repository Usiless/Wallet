import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:finanzas_locales/core/errors/app_exception.dart';
import 'package:finanzas_locales/features/updater/data/update_service.dart';
import 'package:finanzas_locales/features/updater/domain/release_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final apkBytes = List<int>.generate(64, (i) => i * 3 % 256);
final apkHash = sha256.convert(apkBytes).toString();

Map<String, Object?> apkAsset({int size = 64}) => {
  'name': 'app-release.apk',
  'browser_download_url': 'https://example.com/app-release.apk',
  'size': size,
};

Map<String, Object?> sha256Asset() => {
  'name': 'app-release.apk.sha256',
  'browser_download_url': 'https://example.com/app-release.apk.sha256',
  'size': 90,
};

Map<String, Object?> releaseJson({
  String tag = 'v1.3.0',
  List<Map<String, Object?>>? assets,
}) => {
  'tag_name': tag,
  'body': 'Notas de prueba',
  'assets': assets ?? [apkAsset(), sha256Asset()],
};

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

void main() {
  late Directory tempDir;
  late Directory downloadDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('updater_test');
    downloadDir = Directory('${tempDir.path}/updates');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  UpdateService service(http.Client client, {String installed = '1.2.0'}) =>
      UpdateService(
        client: client,
        installedVersion: () async => installed,
        downloadDirectory: () async => downloadDir,
      );

  group('checkForUpdate', () {
    test('returns the release when a newer version exists', () async {
      final client = MockClient((_) async => jsonResponse(releaseJson()));
      final release = await service(client).checkForUpdate();
      expect(release?.tag, 'v1.3.0');
    });

    test('returns null when the installed version is newer', () async {
      final client = MockClient(
        (_) async => jsonResponse(releaseJson(tag: 'v1.9.0')),
      );
      expect(
        await service(client, installed: '1.10.0').checkForUpdate(),
        isNull,
      );
    });

    test('returns null for the same version', () async {
      final client = MockClient(
        (_) async => jsonResponse(releaseJson(tag: 'v1.2.0')),
      );
      expect(await service(client).checkForUpdate(), isNull);
    });

    test('queries GitHub on every check', () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return jsonResponse(releaseJson());
      });
      final updates = service(client);
      await updates.checkForUpdate();
      await updates.checkForUpdate();
      expect(requests, 2);
    });

    test('404 returns null', () async {
      final client = MockClient((_) async => http.Response('{}', 404));
      expect(await service(client).checkForUpdate(), isNull);
    });

    for (final status in [403, 429]) {
      test('HTTP $status throws rateLimited', () async {
        final client = MockClient((_) async => http.Response('', status));
        await expectLater(
          service(client).checkForUpdate(),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.failure,
              'failure',
              UpdateFailure.rateLimited,
            ),
          ),
        );
      });
    }

    test('socket error and timeout throw offline', () async {
      for (final error in [
        const SocketException('sin red'),
        TimeoutException('lento'),
      ]) {
        final client = MockClient((_) async => throw error);
        await expectLater(
          service(client).checkForUpdate(),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.failure,
              'failure',
              UpdateFailure.offline,
            ),
          ),
        );
      }
    });

    test('other status codes and invalid JSON throw server', () async {
      final bad = [
        MockClient((_) async => http.Response('', 500)),
        MockClient((_) async => http.Response('no es json', 200)),
      ];
      for (final client in bad) {
        await expectLater(
          service(client).checkForUpdate(),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.failure,
              'failure',
              UpdateFailure.server,
            ),
          ),
        );
      }
    });
  });

  group('download', () {
    ReleaseInfo release({bool withChecksum = true}) {
      return ReleaseInfo.fromGitHubJson({
        'tag_name': 'v1.3.0',
        'body': '',
        'assets': [
          apkAsset(size: apkBytes.length),
          if (withChecksum) sha256Asset(),
        ],
      })!;
    }

    MockClient fileClient({String? hashText, List<int>? bytes}) =>
        MockClient.streaming((request, _) async {
          final isChecksum = request.url.path.endsWith('.sha256');
          final body = isChecksum
              ? utf8.encode(hashText ?? '$apkHash  app-release.apk\n')
              : (bytes ?? apkBytes);
          return http.StreamedResponse(
            Stream.fromIterable([
              body.sublist(0, body.length ~/ 2),
              body.sublist(body.length ~/ 2),
            ]),
            200,
            contentLength: body.length,
          );
        });

    test('downloads, reports progress and verifies the hash', () async {
      await downloadDir.create(recursive: true);
      await File('${downloadDir.path}/viejo.apk').writeAsBytes([1]);
      final progress = <DownloadProgress>[];
      final file = await service(fileClient())
          .download(release(), onProgress: progress.add);

      expect(file.path, '${downloadDir.path}/app-release.apk');
      expect(await file.readAsBytes(), apkBytes);
      expect(await File('${file.path}.part').exists(), isFalse);
      expect(await File('${downloadDir.path}/viejo.apk').exists(), isFalse);
      expect(progress, isNotEmpty);
      expect(progress.last.received, apkBytes.length);
      expect(progress.last.fraction, 1.0);
    });

    test('a hash mismatch deletes the file and throws integrity', () async {
      await expectLater(
        service(fileClient(hashText: '${'0' * 64}  app-release.apk'))
            .download(release()),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.integrity,
          ),
        ),
      );
      expect(
        await File('${downloadDir.path}/app-release.apk').exists(),
        isFalse,
      );
      expect(
        await File('${downloadDir.path}/app-release.apk.part').exists(),
        isFalse,
      );
    });

    test('without a .sha256 asset the download still succeeds', () async {
      final file = await service(fileClient())
          .download(release(withChecksum: false));
      expect(await file.readAsBytes(), apkBytes);
    });

    test('cancellation throws cancelled and leaves no partial file', () async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);
      final cancel = Completer<void>();
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(controller.stream, 200),
      );
      controller.add(apkBytes.sublist(0, 10));

      final future = service(client).download(
        release(withChecksum: false),
        onProgress: (_) {
          if (!cancel.isCompleted) cancel.complete();
        },
        cancel: cancel.future,
      );

      await expectLater(
        future,
        throwsA(
          isA<UpdateException>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.cancelled,
          ),
        ),
      );
      expect(
        await File('${downloadDir.path}/app-release.apk.part').exists(),
        isFalse,
      );
      expect(
        await File('${downloadDir.path}/app-release.apk').exists(),
        isFalse,
      );
    });

    test('size mismatch throws download and leaves no partial file', () async {
      final bad = ReleaseInfo.fromGitHubJson({
        'tag_name': 'v1.3.0',
        'assets': [apkAsset(size: apkBytes.length + 1)],
      })!;
      await expectLater(
        service(fileClient()).download(bad),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.download,
          ),
        ),
      );
      expect(
        await File('${downloadDir.path}/app-release.apk.part').exists(),
        isFalse,
      );
      expect(
        await File('${downloadDir.path}/app-release.apk').exists(),
        isFalse,
      );
    });

    test('a 404 for the .sha256 throws download', () async {
      final client = MockClient.streaming((request, _) async {
        final isChecksum = request.url.path.endsWith('.sha256');
        return http.StreamedResponse(
          Stream.value(isChecksum ? <int>[] : apkBytes),
          isChecksum ? 404 : 200,
        );
      });
      await expectLater(
        service(client).download(release()),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.download,
          ),
        ),
      );
    });

    test('a BOM and extra lines in the .sha256 are tolerated', () async {
      final file = await service(
        fileClient(hashText: '\uFEFF$apkHash  app-release.apk\nOTRO  x\n'),
      ).download(release());
      expect(await file.readAsBytes(), apkBytes);
    });

    test('cancel while downloading the .sha256 throws cancelled', () async {
      final cancel = Completer<void>();
      final never = Completer<http.Response>();
      final client = MockClient((_) async {
        cancel.complete();
        return never.future;
      });
      await expectLater(
        service(client).download(release(), cancel: cancel.future),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.cancelled,
          ),
        ),
      );
    });

    test('cancel while waiting for headers throws cancelled', () async {
      final cancel = Completer<void>();
      final client = MockClient.streaming((_, _) async {
        cancel.complete();
        return Completer<http.StreamedResponse>().future;
      });
      await expectLater(
        service(client)
            .download(release(withChecksum: false), cancel: cancel.future),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.cancelled,
          ),
        ),
      );
    });

    test('a non-200 apk response throws download', () async {
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(Stream.value(<int>[1, 2]), 500),
      );
      await expectLater(
        service(client).download(release(withChecksum: false)),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.download,
          ),
        ),
      );
      expect(
        await File('${downloadDir.path}/app-release.apk.part').exists(),
        isFalse,
      );
    });

    test('cancel during the last chunk leaves no apk behind', () async {
      final cancel = Completer<void>();
      final file = service(fileClient()).download(
        release(withChecksum: false),
        onProgress: (progress) {
          if (progress.received == apkBytes.length && !cancel.isCompleted) {
            cancel.complete();
          }
        },
        cancel: cancel.future,
      );
      await expectLater(
        file,
        throwsA(
          isA<UpdateException>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.cancelled,
          ),
        ),
      );
      expect(
        await File('${downloadDir.path}/app-release.apk').exists(),
        isFalse,
      );
      expect(
        await File('${downloadDir.path}/app-release.apk.part').exists(),
        isFalse,
      );
    });

    test('an error in onProgress does not abort the download', () async {
      final file = await service(fileClient()).download(
        release(withChecksum: false),
        onProgress: (_) => throw StateError('ui'),
      );
      expect(await file.readAsBytes(), apkBytes);
    });
  });

  test('close does not close an injected client', () async {
    final client = MockClient((_) async => jsonResponse(releaseJson()));
    service(client).close();
    final response = await client.get(
      Uri.parse('https://api.github.com/repos/Usiless/Wallet/releases/latest'),
    );
    expect(response.statusCode, 200);
  });
}
