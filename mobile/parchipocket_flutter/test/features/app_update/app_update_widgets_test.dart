import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/core/state/app_state.dart';
import 'package:parchipocket/features/app_update/data/apk_update_downloader.dart';
import 'package:parchipocket/features/app_update/domain/update_release.dart';
import 'package:parchipocket/features/app_update/presentation/app_update_manager.dart';
import 'package:parchipocket/features/app_update/presentation/app_update_screen.dart';
import 'package:parchipocket/shared/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_test_fakes.dart';

void main() {
  late Directory directory;
  late AppState appState;
  late AppUpdateManager manager;
  late FakeReleaseRepository repository;
  late FakeApkDownloader downloader;
  late FakeUpdatePlatform platform;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    directory = await Directory.systemTemp.createTemp(
      'parchipocket-update-ui-',
    );
    appState = AppState(prefs: await SharedPreferences.getInstance());
    repository =
        FakeReleaseRepository()
          ..release = BetaRelease(
            channel: UpdateChannel.beta,
            packageName: updatePackageName,
            versionName: '0.1.3',
            versionCode: 3,
            apkAssetName: 'parchipocket-release.apk',
            sha256: List<String>.filled(64, 'b').join(),
            releaseNotes: 'Improved household expense tracking.',
            publishedAt: DateTime.utc(2026, 11, 1),
            tagName: 'parchipocket-beta-v0.1.3-3',
            apkDownloadUrl: Uri.parse(
              'https://github.com/rabit001/parchipocket/releases/download/parchipocket-beta-v0.1.3-3/parchipocket-release.apk',
            ),
          );
    downloader =
        FakeApkDownloader()..file = File('${directory.path}/verified.apk');
    platform = FakeUpdatePlatform(directory);
    manager = AppUpdateManager(
      releaseRepository: repository,
      downloader: downloader,
      platform: platform,
      preferences: await SharedPreferences.getInstance(),
      isAndroid: true,
    );
  });

  tearDown(() async {
    manager.dispose();
    appState.dispose();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  testWidgets('update screen shows release details in the light theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPpTheme(),
        home: AppUpdateScreen(state: appState, manager: manager),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 0.1.3 is available'), findsOneWidget);
    expect(find.text('Improved household expense tracking.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('update screen remains readable in the dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPpDarkTheme(),
        themeMode: ThemeMode.dark,
        home: AppUpdateScreen(state: appState, manager: manager),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 0.1.3 is available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('download progress is visible while a download is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPpTheme(),
        home: AppUpdateScreen(state: appState, manager: manager),
      ),
    );
    await tester.pumpAndSettle();
    manager.status = AppUpdateStatus.downloading;
    manager.downloadProgress = const UpdateDownloadProgress(5, 10);
    manager.notifyListeners();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('update-download-progress')),
      findsOneWidget,
    );
    expect(find.textContaining('Downloaded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network errors show a retry action', (tester) async {
    repository.error = const SocketException('offline');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPpTheme(),
        home: AppUpdateScreen(state: appState, manager: manager),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your connection'), findsOneWidget);

    repository.error = null;
    await tester.tap(find.text('Retry check'));
    await tester.pumpAndSettle();
    expect(find.text('Version 0.1.3 is available'), findsOneWidget);
  });

  testWidgets('installer failures explain certificate mismatch data risk', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPpTheme(),
        home: AppUpdateScreen(state: appState, manager: manager),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(manager.downloadAndInstall);
    await tester.pumpAndSettle();
    expect(manager.status, AppUpdateStatus.waitingForInstaller);

    await manager.onAppResumed();
    await tester.pumpAndSettle();
    expect(manager.status, AppUpdateStatus.installationIncomplete);
    expect(manager.errorMessage, contains('signing-certificate mismatch'));

    expect(find.textContaining('signing-certificate mismatch'), findsOneWidget);
    expect(
      find.textContaining('Uninstalling removes local app data'),
      findsOneWidget,
    );
    expect(find.text('Try installation again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup prompt waits for navigation and Later defers it for the current launch', (
    tester,
  ) async {
    var ready = false;
    var openUpdates = 0;
    Widget buildHost({AppUpdateManager? hostManager}) => MaterialApp(
      home: AppUpdatePromptHost(
        manager: hostManager ?? manager,
        navigationReady: ready,
        onOpenUpdates: () => openUpdates++,
        child: const Scaffold(body: Text('First screen')),
      ),
    );

    await tester.pumpWidget(buildHost());
    await tester.pumpAndSettle();
    expect(find.text('Download & Install'), findsNothing);

    // Navigation becomes ready: dialog displays all required elements
    ready = true;
    await tester.pumpWidget(buildHost());
    await tester.pumpAndSettle();
    expect(find.text('ParchiPocket 0.1.3 is available'), findsOneWidget);
    expect(find.text('Improved household expense tracking.'), findsOneWidget);
    expect(find.text('Download & Install'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    // Tapping Later dismisses dialog
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(openUpdates, 0);
    expect(manager.isPromptDismissedForSession, isTrue);
    expect(await manager.shouldShowAutomaticPrompt(), isFalse);
    expect(find.text('Download & Install'), findsNothing);

    // Returning from background during the same launch does not reopen prompt
    await manager.onAppResumed();
    await tester.pumpWidget(buildHost());
    await tester.pumpAndSettle();
    expect(find.text('Download & Install'), findsNothing);

    // Next fresh app launch with same available update displays prompt again
    final freshManager = AppUpdateManager(
      releaseRepository: repository,
      downloader: downloader,
      platform: platform,
      preferences: await SharedPreferences.getInstance(),
      isAndroid: true,
    );
    addTearDown(freshManager.dispose);

    await freshManager.checkAutomatically();
    await tester.pumpWidget(
      MaterialApp(
        home: AppUpdatePromptHost(
          key: const ValueKey<String>('fresh-launch-host'),
          manager: freshManager,
          navigationReady: true,
          onOpenUpdates: () => openUpdates++,
          child: const Scaffold(body: Text('Second launch screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Download & Install'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets(
    'no update available opens app normally without any update prompt',
    (tester) async {
      repository.release = null; // Up-to-date
      await tester.pumpWidget(
        MaterialApp(
          home: AppUpdatePromptHost(
            manager: manager,
            navigationReady: true,
            onOpenUpdates: () {},
            child: const Scaffold(body: Text('Main app screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Main app screen'), findsOneWidget);
      expect(find.text('Download & Install'), findsNothing);
      expect(find.text('Later'), findsNothing);
    },
  );

  testWidgets(
    'network failure during update check does not block normal app usage',
    (tester) async {
      repository.error = const SocketException('No route to host');
      await tester.pumpWidget(
        MaterialApp(
          home: AppUpdatePromptHost(
            manager: manager,
            navigationReady: true,
            onOpenUpdates: () {},
            child: const Scaffold(body: Text('Offline usable screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Offline usable screen'), findsOneWidget);
      expect(find.text('Download & Install'), findsNothing);
      expect(manager.status, AppUpdateStatus.error);
    },
  );

  testWidgets(
    'download prompt opens the update screen only after explicit choice',
    (tester) async {
      var openUpdates = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AppUpdatePromptHost(
            manager: manager,
            navigationReady: true,
            onOpenUpdates: () => openUpdates++,
            child: const Scaffold(body: Text('First screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download & Install'));
      await tester.pumpAndSettle();

      expect(openUpdates, 1);
    },
  );
}
