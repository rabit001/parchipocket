import 'dart:convert';

const String updatePackageName = 'com.parchipocket.app.parchipocket';
const String betaReleaseTagPattern = r'^parchipocket-beta-v\d+\.\d+\.\d+-\d+$';

enum UpdateChannel { beta }

class InstalledAppVersion {
  const InstalledAppVersion({required this.name, required this.code});

  final String name;
  final int code;
}

class BetaRelease {
  const BetaRelease({
    required this.channel,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.apkAssetName,
    required this.sha256,
    required this.releaseNotes,
    required this.publishedAt,
    required this.tagName,
    required this.apkDownloadUrl,
  });

  final UpdateChannel channel;
  final String packageName;
  final String versionName;
  final int versionCode;
  final String apkAssetName;
  final String sha256;
  final String releaseNotes;
  final DateTime publishedAt;
  final String tagName;
  final Uri apkDownloadUrl;

  static BetaRelease fromManifest({
    required Map<String, Object?> manifest,
    required String tagName,
    required DateTime releasePublishedAt,
    required Uri apkDownloadUrl,
    required String apkAssetName,
  }) {
    if (manifest['schemaVersion'] != 1 || manifest['channel'] != 'beta') {
      throw const FormatException('Unsupported update manifest.');
    }
    final packageName = manifest['packageName'];
    final versionName = manifest['versionName'];
    final versionCode = manifest['versionCode'];
    final manifestApkName = manifest['apkAssetName'];
    final hash = manifest['sha256'];
    final notes = manifest['releaseNotes'];
    final publishedAtValue = manifest['publishedAt'];
    if (packageName != updatePackageName ||
        versionName is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(versionName) ||
        versionCode is! int ||
        versionCode <= 0 ||
        manifestApkName is! String ||
        manifestApkName != apkAssetName ||
        !RegExp(r'^[A-Za-z0-9._-]+\.apk$').hasMatch(manifestApkName) ||
        hash is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash) ||
        notes is! String ||
        publishedAtValue is! String) {
      throw const FormatException('Invalid update manifest fields.');
    }
    final hasTimezone = RegExp(
      r'^\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})$',
    ).hasMatch(publishedAtValue);
    final manifestPublishedAt =
        hasTimezone ? DateTime.tryParse(publishedAtValue) : null;
    final expectedTag = 'parchipocket-beta-v$versionName-$versionCode';
    if (manifestPublishedAt == null || tagName != expectedTag) {
      throw const FormatException(
        'Update manifest does not match its release.',
      );
    }

    return BetaRelease(
      channel: UpdateChannel.beta,
      packageName: updatePackageName,
      versionName: versionName,
      versionCode: versionCode,
      apkAssetName: manifestApkName,
      sha256: hash.toLowerCase(),
      releaseNotes: notes,
      publishedAt: releasePublishedAt.toUtc(),
      tagName: tagName,
      apkDownloadUrl: apkDownloadUrl,
    );
  }

  static Map<String, Object?> decodeManifest(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Update manifest must be a JSON object.');
    }
    return Map<String, Object?>.from(decoded);
  }
}

bool shouldOfferUpdate({
  required int installedVersionCode,
  required BetaRelease release,
}) =>
    release.packageName == updatePackageName &&
    release.channel == UpdateChannel.beta &&
    release.versionCode > installedVersionCode;
