import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/features/app_update/data/apk_update_downloader.dart';
import 'package:parchipocket/features/app_update/data/update_http.dart';
import 'package:parchipocket/features/app_update/domain/update_release.dart';

import 'update_test_fakes.dart';

final Uri _apkUrl = Uri.parse(
  'https://github.com/rabit001/parchipocket/releases/download/parchipocket-beta-v0.1.3-3/parchipocket-release.apk',
);
final List<int> _apkBytes = <int>[0x50, 0x4b, 0x03, 0x04, 1, 2, 3, 4];

BetaRelease _release(List<int> bytes) => BetaRelease(
  channel: UpdateChannel.beta,
  packageName: updatePackageName,
  versionName: '0.1.3',
  versionCode: 3,
  apkAssetName: 'parchipocket-release.apk',
  sha256: sha256.convert(bytes).toString(),
  releaseNotes: 'Fixes',
  publishedAt: DateTime.utc(2026, 11, 1),
  tagName: 'parchipocket-beta-v0.1.3-3',
  apkDownloadUrl: _apkUrl,
);

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('parchipocket-update-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'streams the APK, reports progress and accepts a matching hash',
    () async {
      final transport =
          FakeUpdateHttpTransport()
            ..responses[_apkUrl.toString()] = UpdateHttpResponse(
              statusCode: 200,
              headers: <String, String>{
                'content-length': '${_apkBytes.length}',
              },
              body: Stream<List<int>>.fromIterable(<List<int>>[
                _apkBytes.sublist(0, 4),
                _apkBytes.sublist(4),
              ]),
            );
      final progress = <UpdateDownloadProgress>[];
      final downloader = ApkUpdateDownloader(
        transport: transport,
        updateDirectory: () async => directory,
      );

      final result = await downloader.download(
        _release(_apkBytes),
        availableStorageBytes: 1024,
        onProgress: progress.add,
      );

      expect(await result.file.readAsBytes(), _apkBytes);
      expect(result.sha256, sha256.convert(_apkBytes).toString());
      expect(progress.map((item) => item.receivedBytes), <int>[4, 8]);
      expect(progress.last.fraction, 1);
    },
  );

  test('rejects a hash mismatch and removes the partial APK', () async {
    final transport =
        FakeUpdateHttpTransport()
          ..responses[_apkUrl.toString()] = response(
            200,
            base64.encode(_apkBytes),
          );
    final badRelease = BetaRelease(
      channel: UpdateChannel.beta,
      packageName: updatePackageName,
      versionName: '0.1.3',
      versionCode: 3,
      apkAssetName: 'parchipocket-release.apk',
      sha256: List<String>.filled(64, '0').join(),
      releaseNotes: 'Fixes',
      publishedAt: DateTime.utc(2026, 11, 1),
      tagName: 'parchipocket-beta-v0.1.3-3',
      apkDownloadUrl: _apkUrl,
    );
    final downloader = ApkUpdateDownloader(
      transport: transport,
      updateDirectory: () async => directory,
    );

    await expectLater(
      downloader.download(badRelease, availableStorageBytes: 1024),
      throwsA(isA<FormatException>()),
    );
    expect(directory.listSync(), isEmpty);
  });

  test('removes partial data after an interrupted stream', () async {
    final transport =
        FakeUpdateHttpTransport()
          ..responses[_apkUrl.toString()] = UpdateHttpResponse(
            statusCode: 200,
            headers: const <String, String>{'content-length': '8'},
            body: Stream<List<int>>.error(const SocketException('offline')),
          );
    final downloader = ApkUpdateDownloader(
      transport: transport,
      updateDirectory: () async => directory,
    );

    await expectLater(
      downloader.download(_release(_apkBytes), availableStorageBytes: 1024),
      throwsA(isA<SocketException>()),
    );
    expect(directory.listSync(), isEmpty);
  });

  test('surfaces HTTP failure and cleans the partial file', () async {
    final transport =
        FakeUpdateHttpTransport()
          ..responses[_apkUrl.toString()] = response(503, 'unavailable');
    final downloader = ApkUpdateDownloader(
      transport: transport,
      updateDirectory: () async => directory,
    );

    await expectLater(
      downloader.download(_release(_apkBytes), availableStorageBytes: 1024),
      throwsA(isA<UpdateHttpException>()),
    );
    expect(directory.listSync(), isEmpty);
  });

  test(
    'rejects a short response as incomplete and deletes its partial APK',
    () async {
      final transport =
          FakeUpdateHttpTransport()
            ..responses[_apkUrl.toString()] = UpdateHttpResponse(
              statusCode: 200,
              headers: const <String, String>{'content-length': '8'},
              body: Stream<List<int>>.value(_apkBytes.sublist(0, 5)),
            );
      final downloader = ApkUpdateDownloader(
        transport: transport,
        updateDirectory: () async => directory,
      );

      await expectLater(
        downloader.download(_release(_apkBytes), availableStorageBytes: 1024),
        throwsA(isA<UpdateNetworkException>()),
      );
      expect(directory.listSync(), isEmpty);
    },
  );

  test('rejects insufficient storage before writing an APK', () async {
    final transport =
        FakeUpdateHttpTransport()
          ..responses[_apkUrl.toString()] = UpdateHttpResponse(
            statusCode: 200,
            headers: <String, String>{'content-length': '${_apkBytes.length}'},
            body: Stream<List<int>>.value(_apkBytes),
          );
    final downloader = ApkUpdateDownloader(
      transport: transport,
      updateDirectory: () async => directory,
    );

    await expectLater(
      downloader.download(_release(_apkBytes), availableStorageBytes: 1),
      throwsA(isA<InsufficientUpdateStorageException>()),
    );
    expect(directory.listSync(), isEmpty);
  });

  test('prevents concurrent downloads', () async {
    final transport = FakeUpdateHttpTransport();
    final waiting = Completer<UpdateHttpResponse>();
    transport.pending[_apkUrl.toString()] = waiting;
    final downloader = ApkUpdateDownloader(
      transport: transport,
      updateDirectory: () async => directory,
    );
    final first = downloader.download(
      _release(_apkBytes),
      availableStorageBytes: 1024,
    );
    await transport.requestStarted.future;

    await expectLater(
      downloader.download(_release(_apkBytes), availableStorageBytes: 1024),
      throwsA(isA<ConcurrentUpdateDownloadException>()),
    );
    waiting.complete(
      UpdateHttpResponse(
        statusCode: 200,
        headers: <String, String>{'content-length': '${_apkBytes.length}'},
        body: Stream<List<int>>.value(_apkBytes),
      ),
    );
    await first;
  });
}
