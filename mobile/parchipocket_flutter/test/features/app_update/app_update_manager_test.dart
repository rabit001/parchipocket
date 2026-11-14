import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/features/app_update/domain/update_release.dart';
import 'package:parchipocket/features/app_update/presentation/app_update_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_test_fakes.dart';

BetaRelease _release({int code = 3, String name = '0.1.3'}) => BetaRelease(
  channel: UpdateChannel.beta,
  packageName: updatePackageName,
  versionName: name,
  versionCode: code,
  apkAssetName: 'parchipocket-release.apk',
  sha256: List<String>.filled(64, 'a').join(),
  releaseNotes: 'Household and update improvements',
  publishedAt: DateTime.utc(2026, 11, 1),
  tagName: 'parchipocket-beta-v$name-$code',
  apkDownloadUrl: Uri.parse(
    'https://github.com/rabit001/parchipocket/releases/download/parchipocket-beta-v$name-$code/parchipocket-release.apk',
  ),
);

void main() {
  late Directory directory;
  late FakeReleaseRepository repository;
  late FakeApkDownloader downloader;
  late FakeUpdatePlatform platform;
  late AppUpdateManager manager;
  var now = DateTime.utc(2026, 11, 14);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    directory = await Directory.systemTemp.createTemp('parchipocket-manager-');
    repository = FakeReleaseRepository()..release = _release();
    downloader =
        FakeApkDownloader()..file = File('${directory.path}/verified.apk');
    platform = FakeUpdatePlatform(directory);
    manager = AppUpdateManager(
      releaseRepository: repository,
      downloader: downloader,
      platform: platform,
      preferences: await SharedPreferences.getInstance(),
      clock: () => now,
      isAndroid: true,
    );
  });

  tearDown(() async {
    manager.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('offers only a strictly higher numeric versionCode', () async {
    await manager.checkForUpdates();
    expect(manager.status, AppUpdateStatus.available);

    repository.release = _release(code: 2, name: '99.99.99');
    await manager.checkForUpdates();
    expect(manager.status, AppUpdateStatus.upToDate);
    expect(manager.availableRelease, isNull);

    repository.release = _release(code: 1, name: '100.0.0');
    await manager.checkForUpdates();
    expect(manager.status, AppUpdateStatus.upToDate);
  });

  test(
    'same versionCode is not offered even when versionName differs',
    () async {
      repository.release = _release(code: 2, name: '0.1.3');
      await manager.checkForUpdates();
      expect(manager.status, AppUpdateStatus.upToDate);
    },
  );

  test('automatic checks run on fresh launch even when previous check was recent', () async {
    expect(await manager.checkAutomatically(), isTrue);
    expect(repository.calls, 1);
    expect(
      (await SharedPreferences.getInstance()).getInt(
        'app_update.beta.last_success_ms',
      ),
      now.millisecondsSinceEpoch,
    );

    // Only 10 minutes later (well under 24 hours) - fresh check still queries GitHub
    now = now.add(const Duration(minutes: 10));
    expect(await manager.checkAutomatically(), isTrue);
    expect(repository.calls, 2);
  });

  test(
    'Later dismisses prompt for current launch and does not persist 7-day deferral',
    () async {
      await manager.checkForUpdates();
      expect(await manager.shouldShowAutomaticPrompt(), isTrue);
      expect(manager.isPromptDismissedForSession, isFalse);

      await manager.deferAutomaticPrompt();
      expect(manager.isPromptDismissedForSession, isTrue);
      expect(await manager.shouldShowAutomaticPrompt(), isFalse);

      // Verify no persistent 7-day deferral key remains in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('app_update.beta.deferred_until_ms'), isNull);

      // Returning from background during same session maintains session dismissal
      await manager.onAppResumed();
      expect(manager.isPromptDismissedForSession, isTrue);
      expect(await manager.shouldShowAutomaticPrompt(), isFalse);

      // Next fresh launch (new AppUpdateManager instance) re-prompts for the available update
      final nextLaunchManager = AppUpdateManager(
        releaseRepository: repository,
        downloader: downloader,
        platform: platform,
        preferences: prefs,
        clock: () => now,
        isAndroid: true,
      );
      addTearDown(nextLaunchManager.dispose);

      await nextLaunchManager.checkForUpdates();
      expect(nextLaunchManager.status, AppUpdateStatus.available);
      expect(nextLaunchManager.isPromptDismissedForSession, isFalse);
      expect(await nextLaunchManager.shouldShowAutomaticPrompt(), isTrue);
    },
  );

  test('coalesces concurrent release checks', () async {
    repository.gate = Completer<void>();
    final first = manager.checkForUpdates();
    final second = manager.checkForUpdates();
    await repository.callStarted.future;
    expect(repository.calls, 1);
    repository.gate!.complete();
    await Future.wait<void>(<Future<void>>[first, second]);
    expect(manager.status, AppUpdateStatus.available);
  });

  test('opens Android source settings when permission is missing', () async {
    platform.mayInstall = false;
    await manager.checkForUpdates();
    await manager.downloadAndInstall();

    expect(manager.status, AppUpdateStatus.permissionRequired);
    expect(platform.settingsOpens, 0);
    expect(platform.installLaunches, 0);
    expect(manager.verifiedApk, isNotNull);
    await manager.openInstallPermissionSettings();
    expect(platform.settingsOpens, 1);
  });

  test(
    'rechecks permission on resume and only launches a verified APK',
    () async {
      platform.mayInstall = false;
      await manager.checkForUpdates();
      await manager.downloadAndInstall();
      platform.mayInstall = true;
      await manager.onAppResumed();

      expect(platform.installLaunches, 1);
      expect(manager.status, AppUpdateStatus.waitingForInstaller);
      expect(manager.installedVersion?.code, 2);
      expect(platform.installedApkPath, downloader.file!.path);
      expect(await File(platform.installedApkPath!).exists(), isTrue);
    },
  );

  test(
    'does not claim installation before Android reports the new version',
    () async {
      await manager.checkForUpdates();
      await manager.downloadAndInstall();
      expect(manager.status, AppUpdateStatus.waitingForInstaller);

      await manager.onAppResumed();
      expect(manager.status, AppUpdateStatus.installationIncomplete);
      expect(manager.verifiedApk, isNotNull);
      expect(manager.installedVersion?.code, 2);
    },
  );

  test(
    'confirms installation and clears the cached APK only after version changes',
    () async {
      await manager.checkForUpdates();
      await manager.downloadAndInstall();
      final apk = downloader.file!;
      expect(await apk.exists(), isTrue);

      platform.version = const InstalledAppVersion(name: '0.1.3', code: 3);
      await manager.onAppResumed();

      expect(manager.status, AppUpdateStatus.installed);
      expect(await apk.exists(), isFalse);
    },
  );

  test('coalesces repeated download actions', () async {
    await manager.checkForUpdates();
    downloader.gate = Completer<void>();
    final first = manager.downloadAndInstall();
    final second = manager.downloadAndInstall();
    await downloader.callStarted.future;
    expect(downloader.calls, 1);
    downloader.gate!.complete();
    await Future.wait<void>(<Future<void>>[first, second]);
    expect(platform.installLaunches, 1);
  });

  test(
    'surfaces network errors without changing the installed version',
    () async {
      repository.error = const SocketException('offline');
      await manager.checkForUpdates();
      expect(manager.status, AppUpdateStatus.error);
      expect(manager.errorMessage, contains('connection'));
      expect(manager.installedVersion?.code, 2);
    },
  );

  test(
    'surfaces installer failure and keeps a verified APK available for retry',
    () async {
      platform.installError = const FileSystemException('installer unavailable');
      await manager.checkForUpdates();
      await manager.downloadAndInstall();

      expect(manager.status, AppUpdateStatus.error);
      expect(manager.verifiedApk, isNotNull);
      expect(await manager.verifiedApk!.file.exists(), isTrue);

      platform.installError = null;
      await manager.installVerifiedUpdate();
      expect(manager.status, AppUpdateStatus.waitingForInstaller);
      expect(platform.installLaunches, 1);
    },
  );
}
