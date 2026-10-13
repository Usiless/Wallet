import 'dart:math' as math;

import 'package:path/path.dart' as p;

import 'app_version.dart';

final class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final Uri downloadUrl;
  final int size;
}

final class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.notes,
    required this.apk,
    this.checksum,
  });

  final String tag;
  final AppVersion version;
  final String notes;
  final ReleaseAsset apk;
  final ReleaseAsset? checksum;

  /// null si el tag no es una versión válida o si no hay asset .apk.
  static ReleaseInfo? fromGitHubJson(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    if (tag is! String) return null;
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;

    final assets = <ReleaseAsset>[];
    final rawAssets = json['assets'];
    if (rawAssets is List) {
      for (final raw in rawAssets) {
        if (raw is! Map<String, dynamic>) continue;
        final asset = _assetFromGitHub(raw);
        if (asset != null) assets.add(asset);
      }
    }

    final apk = assets
        .where((asset) => asset.name.endsWith('.apk'))
        .firstOrNull;
    if (apk == null) return null;

    final checksums = assets
        .where((asset) => asset.name.endsWith('.sha256'))
        .toList();
    final checksum =
        checksums
            .where((asset) => asset.name == '${apk.name}.sha256')
            .firstOrNull ??
        (checksums.length == 1 ? checksums.single : null);

    final body = json['body'];
    return ReleaseInfo(
      tag: tag,
      version: version,
      notes: body is String ? body : '',
      apk: apk,
      checksum: checksum,
    );
  }
}

ReleaseAsset? _assetFromGitHub(Map<String, dynamic> json) {
  final name = json['name'];
  final url = json['browser_download_url'];
  final size = json['size'];
  if (name is! String || url is! String || size is! int) return null;
  if (!_isPlainFileName(name)) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return null;
  return ReleaseAsset(name: name, downloadUrl: uri, size: size);
}

bool _isPlainFileName(String name) =>
    name.isNotEmpty &&
    name != '.' &&
    name != '..' &&
    !name.contains('\\') &&
    p.basename(name) == name;

final class DownloadProgress {
  const DownloadProgress(this.received, this.total);

  final int received;
  final int? total;

  double? get fraction {
    final total = this.total;
    if (total == null || total <= 0) return null;
    return math.min(1.0, math.max(0.0, received / total));
  }
}
