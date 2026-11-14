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
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher"'));
  });
}
