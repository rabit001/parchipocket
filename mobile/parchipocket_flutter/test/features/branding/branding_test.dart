import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/features/auth/presentation/auth_screens.dart';
import 'package:parchipocket/features/customer/presentation/customer_screens.dart';
import 'package:parchipocket/shared/theme/theme.dart';

const _logoKey = ValueKey<String>('parchipocket-brand-logo');
const _lightLogo = 'assets/branding/parchipocket_logo_horizontal.png';
const _darkLogo = 'assets/branding/parchipocket_logo_horizontal_dark.png';

Image _brandImage(WidgetTester tester) =>
    tester.widget<Image>(find.byKey(_logoKey));

void main() {
  testWidgets('login chooses the horizontal logo for the active theme', (
    tester,
  ) async {
    final state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPpTheme(),
        darkTheme: buildPpDarkTheme(),
        themeMode: ThemeMode.light,
        home: LoginScreen(state: state),
      ),
    );
    expect((_brandImage(tester).image as AssetImage).assetName, _lightLogo);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPpTheme(),
        home: Theme(data: buildPpDarkTheme(), child: LoginScreen(state: state)),
      ),
    );
    expect(
      Theme.of(tester.element(find.byKey(_logoKey))).brightness,
      Brightness.dark,
    );
    expect((_brandImage(tester).image as AssetImage).assetName, _darkLogo);
  });

  testWidgets('splash and authentication loading screens show the logo', (
    tester,
  ) async {
    final state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(theme: buildPpTheme(), home: SplashScreen(state: state)),
    );
    expect(find.byKey(_logoKey), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPpTheme(),
        home: AuthSessionLoadingScreen(state: state),
      ),
    );
    expect(find.byKey(_logoKey), findsOneWidget);
  });

  testWidgets('dashboard branding fits a narrow phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 2, 568 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);

    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPpTheme(),
        home: CustomerHomeScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_logoKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'all registered branding assets load from the Flutter asset bundle',
    () async {
      for (final path in <String>[
        _lightLogo,
        _darkLogo,
        'assets/branding/parchipocket_app_icon_1024.png',
      ]) {
        expect(
          (await rootBundle.load(path)).lengthInBytes,
          greaterThan(0),
          reason: path,
        );
      }
    },
  );

  test('Android launcher declares standard and round icon resources', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml')
            .readAsStringSync()
            .replaceAll('\r\n', '\n');

    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));

    // Both application and main launcher activity declare the icon resources
    expect(
      manifest,
      contains(
        '<activity\n'
        '            android:name=".MainActivity"\n'
        '            android:exported="true"\n'
        '            android:launchMode="singleTop"\n'
        '            android:icon="@mipmap/ic_launcher"\n'
        '            android:roundIcon="@mipmap/ic_launcher_round"',
      ),
    );

    // Verify adaptive icon XML definitions
    final anyDpiLauncher =
        File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
            .readAsStringSync();
    expect(anyDpiLauncher, contains('<adaptive-icon'));
    expect(anyDpiLauncher, contains('@color/ic_launcher_background'));
    expect(anyDpiLauncher, contains('@drawable/ic_launcher_foreground_inset'));

    final anyDpiRound =
        File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml')
            .readAsStringSync();
    expect(anyDpiRound, contains('<adaptive-icon'));
    expect(anyDpiRound, contains('@color/ic_launcher_background'));
    expect(anyDpiRound, contains('@drawable/ic_launcher_foreground_inset'));

    // Verify foreground inset drawable
    final foregroundInset =
        File('android/app/src/main/res/drawable/ic_launcher_foreground_inset.xml')
            .readAsStringSync();
    expect(foregroundInset, contains('<inset'));
    expect(foregroundInset, contains('@drawable/ic_launcher_foreground'));
    expect(foregroundInset, contains('android:inset="16%"'));

    // Verify density resources exist and are non-empty for standard and round icons
    const densities = <String>[
      'mipmap-mdpi',
      'mipmap-hdpi',
      'mipmap-xhdpi',
      'mipmap-xxhdpi',
      'mipmap-xxxhdpi',
    ];

    for (final d in densities) {
      final std = File('android/app/src/main/res/$d/ic_launcher.png');
      final round = File('android/app/src/main/res/$d/ic_launcher_round.png');
      expect(std.existsSync(), isTrue, reason: '$d/ic_launcher.png exists');
      expect(std.lengthSync(), greaterThan(1000), reason: '$d/ic_launcher.png non-trivial');
      expect(round.existsSync(), isTrue, reason: '$d/ic_launcher_round.png exists');
      expect(round.lengthSync(), equals(std.lengthSync()), reason: '$d/ic_launcher_round matches standard size');
    }

    const foregroundDensities = <String>[
      'drawable-mdpi',
      'drawable-hdpi',
      'drawable-xhdpi',
      'drawable-xxhdpi',
      'drawable-xxxhdpi',
    ];

    for (final d in foregroundDensities) {
      final fg = File('android/app/src/main/res/$d/ic_launcher_foreground.png');
      expect(fg.existsSync(), isTrue, reason: '$d/ic_launcher_foreground.png exists');
      expect(fg.lengthSync(), greaterThan(1000), reason: '$d/ic_launcher_foreground.png non-trivial');
    }
  });
}
