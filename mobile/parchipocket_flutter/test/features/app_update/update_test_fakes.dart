import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:parchipocket/features/app_update/data/android_update_platform.dart';
import 'package:parchipocket/features/app_update/data/apk_update_downloader.dart';
import 'package:parchipocket/features/app_update/data/github_beta_release_repository.dart';
import 'package:parchipocket/features/app_update/data/update_http.dart';
import 'package:parchipocket/features/app_update/domain/update_release.dart';

UpdateHttpResponse response(
  int statusCode,
  Object body, {
  Map<String, String> headers = const <String, String>{},
}) => UpdateHttpResponse(
  statusCode: statusCode,
  headers: headers,
  body: Stream<List<int>>.value(
    body is String ? utf8.encode(body) : utf8.encode(jsonEncode(body)),
  ),
);

class FakeUpdateHttpTransport implements UpdateHttpTransport {
  final Map<String, UpdateHttpResponse> responses =
      <String, UpdateHttpResponse>{};
  final Map<String, Completer<UpdateHttpResponse>> pending =
      <String, Completer<UpdateHttpResponse>>{};
  final List<Uri> requests = <Uri>[];
  final Completer<Uri> requestStarted = Completer<Uri>();
  bool closed = false;

  @override
  Future<UpdateHttpResponse> get(Uri uri, {required bool followRedirects}) {
    requests.add(uri);
    if (!requestStarted.isCompleted) requestStarted.complete(uri);
    final waiter = pending[uri.toString()];
    if (waiter != null) return waiter.future;
    final result = responses[uri.toString()];
    if (result == null) {
      return Future<UpdateHttpResponse>.error(
        StateError('No fake response configured for $uri'),
      );
    }
    return Future<UpdateHttpResponse>.value(result);
  }

  @override
  void close() => closed = true;
}

class FakeReleaseRepository implements GithubBetaReleaseRepository {
  BetaRelease? release;
  Object? error;
  int calls = 0;
  Completer<void>? gate;
  final Completer<void> callStarted = Completer<void>();

  @override
  Future<BetaRelease?> latestBeta() async {
    calls++;
    if (!callStarted.isCompleted) callStarted.complete();
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return release;
  }
}

class FakeApkDownloader implements ApkUpdateDownloader {
  int calls = 0;
  File? file;
  Object? error;
  Completer<void>? gate;
  final Completer<void> callStarted = Completer<void>();

  @override
  Future<VerifiedApk> download(
    BetaRelease release, {
    required int? availableStorageBytes,
    void Function(UpdateDownloadProgress progress)? onProgress,
  }) async {
    calls++;
    if (!callStarted.isCompleted) callStarted.complete();
    onProgress?.call(const UpdateDownloadProgress(5, 10));
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    final target = file!;
    await target.parent.create(recursive: true);
    await target.writeAsBytes(<int>[0x50, 0x4b, 1]);
    return VerifiedApk(file: target, sha256: release.sha256);
  }
}

class FakeUpdatePlatform implements UpdatePlatform {
  FakeUpdatePlatform(this.directory);

  final Directory directory;
  InstalledAppVersion version = const InstalledAppVersion(
    name: '0.1.2',
    code: 2,
  );
  bool mayInstall = true;
  int settingsOpens = 0;
  int installLaunches = 0;
  int availableStorage = 1024 * 1024;
  String? installedApkPath;
  Object? installError;

  @override
  Future<int> availableStorageBytes() async => availableStorage;

  @override
  Future<bool> canRequestPackageInstalls() async => mayInstall;

  @override
  Future<InstalledAppVersion> installedVersion() async => version;

  @override
  Future<void> installVerifiedApk(String path) async {
    if (path.isEmpty) throw StateError('Missing verified APK path.');
    if (installError != null) throw installError!;
    installLaunches++;
    installedApkPath = path;
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    settingsOpens++;
  }

  @override
  Future<Directory> updateDirectory() async => directory;
}
