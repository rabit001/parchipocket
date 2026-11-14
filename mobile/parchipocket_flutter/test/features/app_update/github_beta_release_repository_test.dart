import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/features/app_update/data/github_beta_release_repository.dart';
import 'package:parchipocket/features/app_update/data/update_http.dart';
import 'package:parchipocket/features/app_update/domain/update_release.dart';

import 'update_test_fakes.dart';

final Uri _api = Uri.parse(
  'https://api.github.com/repos/rabit001/parchipocket/releases?per_page=20&page=1',
);

Uri _apiPage(int page) => Uri.parse(
  'https://api.github.com/repos/rabit001/parchipocket/releases?per_page=20&page=$page',
);

Map<String, Object?> _release({
  String? tag,
  bool prerelease = true,
  bool draft = false,
  String packageName = 'com.parchipocket.app.parchipocket',
  String versionName = '0.1.3',
  int versionCode = 3,
  String sha =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String apkName = 'parchipocket-release.apk',
  bool includeApk = true,
  String? manifestText,
  String? manifestUrl,
  String publishedAt = '2026-11-01T10:00:00Z',
}) {
  final releaseTag = tag ?? 'parchipocket-beta-v$versionName-$versionCode';
  final releasePublishedAt = publishedAt;
  final releaseManifestUrl =
      manifestUrl ??
      'https://github.com/rabit001/parchipocket/releases/download/$releaseTag/app-update-manifest.json';
  return <String, Object?>{
    'tag_name': releaseTag,
    'draft': draft,
    'prerelease': prerelease,
    'published_at': publishedAt,
    'assets': <Map<String, Object?>>[
      <String, Object?>{
        'name': 'app-update-manifest.json',
        'browser_download_url': releaseManifestUrl,
      },
      if (includeApk)
        <String, Object?>{
          'name': apkName,
          'browser_download_url':
              'https://github.com/rabit001/parchipocket/releases/download/$releaseTag/$apkName',
        },
    ],
    '_manifestText':
        manifestText ??
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'channel': 'beta',
          'packageName': packageName,
          'versionName': versionName,
          'versionCode': versionCode,
          'apkAssetName': apkName,
          'sha256': sha,
          'releaseNotes': 'Beta fixes',
          'publishedAt': releasePublishedAt,
        }),
  };
}

void _configure(
  FakeUpdateHttpTransport transport,
  List<Map<String, Object?>> releases, {
  Uri? api,
}) {
  final endpoint = api ?? _api;
  final apiReleases = <Map<String, Object?>>[];
  for (final item in releases) {
    final copy = Map<String, Object?>.from(item)..remove('_manifestText');
    apiReleases.add(copy);
    final assets = copy['assets']! as List<Object?>;
    final manifestAsset = assets.first! as Map<String, Object?>;
    transport.responses[manifestAsset['browser_download_url']!
        as String] = response(200, item['_manifestText']! as String);
  }
  transport.responses[endpoint.toString()] = response(200, apiReleases);
}

void main() {
  group('GitHub Beta release selection', () {
    test('selects the newest valid published beta release', () async {
      final transport = FakeUpdateHttpTransport();
      _configure(transport, <Map<String, Object?>>[
        _release(tag: 'parchipocket-beta-v0.1.3-3'),
        _release(
          tag: 'parchipocket-beta-v0.1.2-2',
          versionName: '0.1.2',
          versionCode: 2,
          publishedAt: '2026-10-30T10:00:00Z',
        ),
      ]);

      final release = await GithubBetaReleaseRepository(transport).latestBeta();

      expect(release?.versionCode, 3);
      expect(release?.channel, UpdateChannel.beta);
      expect(release?.apkAssetName, 'parchipocket-release.apk');
      expect(release?.sha256, List<String>.filled(64, 'a').join());
    });

    test('ignores drafts and stable releases', () async {
      final transport = FakeUpdateHttpTransport();
      _configure(transport, <Map<String, Object?>>[
        _release(draft: true),
        _release(prerelease: false),
      ]);

      expect(await GithubBetaReleaseRepository(transport).latestBeta(), isNull);
      expect(transport.requests, <Uri>[_api]);
    });

    test('rejects a release whose manifest has an invalid schema', () async {
      final transport = FakeUpdateHttpTransport();
      _configure(transport, <Map<String, Object?>>[
        _release(manifestText: '{bad json'),
      ]);

      expect(await GithubBetaReleaseRepository(transport).latestBeta(), isNull);
    });

    test('rejects a package ID mismatch', () async {
      final transport = FakeUpdateHttpTransport();
      _configure(transport, <Map<String, Object?>>[
        _release(packageName: 'com.example.other'),
      ]);

      expect(await GithubBetaReleaseRepository(transport).latestBeta(), isNull);
    });

    test('rejects a missing APK asset', () async {
      final transport = FakeUpdateHttpTransport();
      _configure(transport, <Map<String, Object?>>[
        _release(includeApk: false),
      ]);

      expect(await GithubBetaReleaseRepository(transport).latestBeta(), isNull);
    });

    test('rejects an invalid SHA-256 value', () async {
      final transport = FakeUpdateHttpTransport();
      _configure(transport, <Map<String, Object?>>[_release(sha: '1234')]);

      expect(await GithubBetaReleaseRepository(transport).latestBeta(), isNull);
    });

    test('rejects release asset URLs outside HTTPS GitHub releases', () async {
      final transport = FakeUpdateHttpTransport();
      _configure(transport, <Map<String, Object?>>[
        _release(manifestUrl: 'https://example.invalid/manifest.json'),
      ]);

      expect(await GithubBetaReleaseRepository(transport).latestBeta(), isNull);
    });

    test(
      'ignores arbitrary manifest URLs and resolves the APK from release assets',
      () async {
        final manifest = <String, Object?>{
          'schemaVersion': 1,
          'channel': 'beta',
          'packageName': 'com.parchipocket.app.parchipocket',
          'versionName': '0.1.3',
          'versionCode': 3,
          'apkAssetName': 'parchipocket-release.apk',
          'sha256': List<String>.filled(64, 'a').join(),
          'releaseNotes': 'Beta fixes',
          'publishedAt': '2026-11-01T10:00:00Z',
          'downloadUrl': 'https://attacker.invalid/installer.apk',
        };
        final transport = FakeUpdateHttpTransport();
        _configure(transport, <Map<String, Object?>>[
          _release(manifestText: jsonEncode(manifest)),
        ]);

        final result =
            await GithubBetaReleaseRepository(transport).latestBeta();

        expect(result?.apkDownloadUrl.host, 'github.com');
        expect(result?.apkDownloadUrl.path, contains('/releases/download/'));
      },
    );

    test(
      'reports GitHub rate limits without treating them as no update',
      () async {
        final transport =
            FakeUpdateHttpTransport()
              ..responses[_api.toString()] = response(
                403,
                <String, Object?>{'message': 'API rate limit exceeded'},
                headers: <String, String>{'x-ratelimit-reset': '1793520000'},
              );

        await expectLater(
          GithubBetaReleaseRepository(transport).latestBeta(),
          throwsA(isA<UpdateHttpException>()),
        );
      },
    );

    test('handles malformed release-list JSON safely', () async {
      final transport =
          FakeUpdateHttpTransport()
            ..responses[_api.toString()] = response(200, '{invalid');

      await expectLater(
        GithubBetaReleaseRepository(transport).latestBeta(),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'finds the highest Beta versionCode on a later release page',
      () async {
        final transport = FakeUpdateHttpTransport();
        final firstPage = List<Map<String, Object?>>.generate(
          20,
          (_) => _release(prerelease: false),
        );
        firstPage[0] = _release(versionName: '0.1.4', versionCode: 4);
        _configure(transport, firstPage, api: _apiPage(1));
        _configure(transport, <Map<String, Object?>>[
          _release(versionName: '0.2.0', versionCode: 20),
        ], api: _apiPage(2));

        final result =
            await GithubBetaReleaseRepository(transport).latestBeta();

        expect(result?.versionCode, 20);
        expect(
          transport.requests.where((uri) => uri.host == 'api.github.com'),
          <Uri>[_apiPage(1), _apiPage(2)],
        );
        expect(transport.requests.toSet().length, transport.requests.length);
      },
    );

    test('fails safely when a later release page is rate limited', () async {
      final transport = FakeUpdateHttpTransport();
      _configure(transport, <Map<String, Object?>>[
        _release(versionName: '0.1.4', versionCode: 4),
        ...List<Map<String, Object?>>.generate(
          19,
          (_) => _release(prerelease: false),
        ),
      ], api: _apiPage(1));
      transport.responses[_apiPage(2).toString()] = response(
        429,
        <String, Object?>{'message': 'rate limited'},
      );

      await expectLater(
        GithubBetaReleaseRepository(transport).latestBeta(),
        throwsA(isA<UpdateHttpException>()),
      );
      expect(
        transport.requests.where((uri) => uri.host == 'api.github.com'),
        <Uri>[_apiPage(1), _apiPage(2)],
      );
    });

    test(
      'stops at the configured pagination bound instead of looping',
      () async {
        final transport = FakeUpdateHttpTransport();
        for (var page = 1; page <= 10; page++) {
          _configure(
            transport,
            List<Map<String, Object?>>.generate(
              20,
              (_) => _release(prerelease: false),
            ),
            api: _apiPage(page),
          );
        }

        await expectLater(
          GithubBetaReleaseRepository(transport).latestBeta(),
          throwsA(isA<UpdatePaginationException>()),
        );
        expect(transport.requests, hasLength(10));
        expect(transport.requests.toSet().length, 10);
      },
    );
  });
}
