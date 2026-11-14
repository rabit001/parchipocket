import 'dart:convert';

import '../domain/update_release.dart';
import 'update_http.dart';

class UpdatePaginationException implements Exception {
  const UpdatePaginationException();
}

class GithubBetaReleaseRepository {
  GithubBetaReleaseRepository(this._transport);

  static const int releasePageSize = 20;
  static const int maximumReleasePages = 10;
  static final Uri releasesUri = releasesUriForPage(1);

  static Uri releasesUriForPage(int page) => Uri.https(
    'api.github.com',
    '/repos/rabit001/parchipocket/releases',
    <String, String>{'per_page': '$releasePageSize', 'page': '$page'},
  );

  final UpdateHttpTransport _transport;

  Future<BetaRelease?> latestBeta() async {
    BetaRelease? highestVersion;
    for (var page = 1; page <= maximumReleasePages; page++) {
      final response = await _transport
          .get(releasesUriForPage(page), followRedirects: false)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        final message =
            response.statusCode == 403 || response.statusCode == 429
                ? 'GitHub is temporarily limiting update checks. Try again later.'
                : 'Could not check GitHub releases (HTTP ${response.statusCode}).';
        throw UpdateHttpException(response.statusCode, message);
      }
      final listBytes = await readUpdateResponse(
        response,
        maxBytes: 5 * 1024 * 1024,
      );
      final decoded = jsonDecode(utf8.decode(listBytes));
      if (decoded is! List<dynamic> || decoded.length > releasePageSize) {
        throw const FormatException('GitHub returned an invalid release page.');
      }

      for (final candidate in decoded.whereType<Map<String, dynamic>>()) {
        if (!_isPublishedBeta(candidate)) continue;
        try {
          final parsed = await _parseRelease(candidate);
          if (parsed != null &&
              (highestVersion == null ||
                  parsed.versionCode > highestVersion.versionCode)) {
            highestVersion = parsed;
          }
        } on FormatException {
          continue;
        }
      }
      if (decoded.length < releasePageSize) return highestVersion;
    }
    throw const UpdatePaginationException();
  }

  bool _isPublishedBeta(Map<String, dynamic> release) {
    final tag = release['tag_name'];
    return release['draft'] == false &&
        release['prerelease'] == true &&
        tag is String &&
        RegExp(betaReleaseTagPattern).hasMatch(tag);
  }

  Future<BetaRelease?> _parseRelease(Map<String, dynamic> release) async {
    final tag = release['tag_name']! as String;
    final publishedAtValue = release['published_at'];
    final publishedAt =
        publishedAtValue is String ? DateTime.tryParse(publishedAtValue) : null;
    if (publishedAt == null) {
      throw const FormatException('Invalid release date.');
    }
    final assets = release['assets'];
    if (assets is! List<dynamic>) {
      throw const FormatException('Missing release assets.');
    }
    final parsedAssets = assets.whereType<Map<String, dynamic>>().toList();
    final manifestAsset = _asset(parsedAssets, 'app-update-manifest.json');
    if (manifestAsset == null) return null;
    final manifestUri = _validatedAssetUri(
      manifestAsset['browser_download_url'],
      tag,
      'app-update-manifest.json',
    );
    if (manifestUri == null) return null;

    final manifestResponse = await getFollowingGithubRedirects(
      _transport,
      manifestUri,
    );
    if (manifestResponse.statusCode != 200) {
      if (manifestResponse.statusCode == 403 ||
          manifestResponse.statusCode == 429) {
        throw UpdateHttpException(
          manifestResponse.statusCode,
          'GitHub is temporarily limiting update checks. Try again later.',
        );
      }
      return null;
    }
    final manifestBytes = await readUpdateResponse(
      manifestResponse,
      maxBytes: 256 * 1024,
    );
    final manifest = BetaRelease.decodeManifest(manifestBytes);
    final apkName = manifest['apkAssetName'];
    if (apkName is! String) {
      throw const FormatException('Missing APK asset name.');
    }
    final apkAsset = _asset(parsedAssets, apkName);
    if (apkAsset == null) return null;
    final apkUri = _validatedAssetUri(
      apkAsset['browser_download_url'],
      tag,
      apkName,
    );
    if (apkUri == null) return null;
    return BetaRelease.fromManifest(
      manifest: manifest,
      tagName: tag,
      releasePublishedAt: publishedAt,
      apkDownloadUrl: apkUri,
      apkAssetName: apkName,
    );
  }

  Map<String, dynamic>? _asset(List<Map<String, dynamic>> assets, String name) {
    for (final asset in assets) {
      if (asset['name'] == name) return asset;
    }
    return null;
  }

  Uri? _validatedAssetUri(Object? value, String tag, String assetName) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final expectedPath =
        '/rabit001/parchipocket/releases/download/$tag/$assetName';
    return uri.path == expectedPath ? uri : null;
  }
}
