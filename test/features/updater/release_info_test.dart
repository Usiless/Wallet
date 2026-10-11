import 'package:finanzas_locales/features/updater/domain/app_version.dart';
import 'package:finanzas_locales/features/updater/domain/release_info.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> asset(String name, {int size = 10}) => {
  'name': name,
  'browser_download_url': 'https://example.com/$name',
  'size': size,
};

void main() {
  test('picks the apk and its matching sha256 asset', () {
    final release = ReleaseInfo.fromGitHubJson({
      'tag_name': 'v1.3.0',
      'body': 'Notas',
      'assets': [
        asset('otro.sha256'),
        asset('app-release.apk', size: 99),
        asset('app-release.apk.sha256'),
        asset('notas.txt'),
      ],
    })!;
    expect(release.tag, 'v1.3.0');
    expect(release.version, const AppVersion(1, 3, 0));
    expect(release.notes, 'Notas');
    expect(release.apk.name, 'app-release.apk');
    expect(release.apk.size, 99);
    expect(
      release.apk.downloadUrl.toString(),
      'https://example.com/app-release.apk',
    );
    expect(release.checksum?.name, 'app-release.apk.sha256');
  });

  test('uses the only sha256 asset when there is no matching one', () {
    final release = ReleaseInfo.fromGitHubJson({
      'tag_name': '1.3.0',
      'body': null,
      'assets': [asset('app.apk'), asset('sums.sha256')],
    })!;
    expect(release.notes, '');
    expect(release.checksum?.name, 'sums.sha256');
  });

  test('has no checksum when there are several unmatched sha256 assets', () {
    final release = ReleaseInfo.fromGitHubJson({
      'tag_name': 'v1.3.0',
      'assets': [asset('app.apk'), asset('a.sha256'), asset('b.sha256')],
    })!;
    expect(release.checksum, isNull);
  });

  test('returns null without apk or with an invalid tag', () {
    expect(
      ReleaseInfo.fromGitHubJson({
        'tag_name': 'v1.3.0',
        'assets': [asset('app.aab')],
      }),
      isNull,
    );
    expect(
      ReleaseInfo.fromGitHubJson({
        'tag_name': 'latest',
        'assets': [asset('app.apk')],
      }),
      isNull,
    );
    expect(ReleaseInfo.fromGitHubJson({'tag_name': 'v1.3.0'}), isNull);
  });

  test('toJson and fromJson round-trip', () {
    final release = ReleaseInfo.fromGitHubJson({
      'tag_name': 'v1.3.0',
      'body': 'Notas',
      'assets': [asset('app.apk', size: 42), asset('app.apk.sha256')],
    })!;
    final restored = ReleaseInfo.fromJson(release.toJson())!;
    expect(restored.tag, release.tag);
    expect(restored.version, release.version);
    expect(restored.notes, release.notes);
    expect(restored.apk.name, 'app.apk');
    expect(restored.apk.size, 42);
    expect(restored.apk.downloadUrl, release.apk.downloadUrl);
    expect(restored.checksum?.name, 'app.apk.sha256');
  });

  test('fromJson rejects malformed cache entries', () {
    expect(ReleaseInfo.fromJson({'tag': 'v1.3.0'}), isNull);
    expect(
      ReleaseInfo.fromJson({
        'tag': 'nope',
        'notes': '',
        'apk': {'name': 'a.apk', 'url': 'https://e.com/a.apk', 'size': 1},
        'checksum': null,
      }),
      isNull,
    );
  });

  test('ignores assets with unsafe names or non-https urls', () {
    Map<String, dynamic> raw(String name, String url) => {
      'name': name,
      'browser_download_url': url,
      'size': 1,
    };
    const url = 'https://example.com/app.apk';
    for (final unsafe in ['../evil.apk', 'sub/app.apk', 'a\\b.apk', '..', '']) {
      expect(
        ReleaseInfo.fromGitHubJson({
          'tag_name': 'v1.3.0',
          'assets': [raw(unsafe, url)],
        }),
        isNull,
        reason: unsafe,
      );
    }
    expect(
      ReleaseInfo.fromGitHubJson({
        'tag_name': 'v1.3.0',
        'assets': [raw('app.apk', 'http://example.com/app.apk')],
      }),
      isNull,
    );
    final release = ReleaseInfo.fromGitHubJson({
      'tag_name': 'v1.3.0',
      'assets': [raw('../evil.apk', url), raw('app.apk', url)],
    })!;
    expect(release.apk.name, 'app.apk');
  });

  test('fromJson rejects unsafe cached assets', () {
    Map<String, Object?> cached(String name, String url) => {
      'tag': 'v1.3.0',
      'notes': '',
      'apk': {'name': name, 'url': url, 'size': 1},
      'checksum': null,
    };
    expect(
      ReleaseInfo.fromJson(cached('../a.apk', 'https://e.com/a.apk')),
      isNull,
    );
    expect(ReleaseInfo.fromJson(cached('a.apk', 'http://e.com/a.apk')), isNull);
    expect(
      ReleaseInfo.fromJson(cached('a.apk', 'https://e.com/a.apk')),
      isNotNull,
    );
  });

  test('download progress fraction is bounded and null when unknown', () {
    expect(const DownloadProgress(5, 10).fraction, 0.5);
    expect(const DownloadProgress(20, 10).fraction, 1.0);
    expect(const DownloadProgress(5, null).fraction, isNull);
    expect(const DownloadProgress(5, 0).fraction, isNull);
  });
}
