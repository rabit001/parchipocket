import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/shared/widgets/ui.dart';

void main() {
  group('AppState navigation history', () {
    test('back returns to the prior nested screen', () {
      final state = AppState()..page = 'customerHome';
      addTearDown(state.dispose);

      state.go('customerProfile');
      state.go('editProfile');
      expect(state.page, 'editProfile');
      expect(state.popPage(), isTrue);
      expect(state.page, 'customerProfile');
      expect(state.popPage(), isTrue);
      expect(state.page, 'customerHome');
      expect(state.popPage(), isFalse);
    });

    test('selecting a bottom tab does not add a nested route', () {
      final state = AppState()..page = 'customerHome';
      addTearDown(state.dispose);

      state.selectTab('insights');
      state.go('appUpdates');
      expect(state.popPage(), isTrue);
      expect(state.page, 'insights');
      expect(state.popPage(), isFalse);
    });

    testWidgets('bottom navigation updates the selected root tab', (
      tester,
    ) async {
      final state = AppState()..page = 'customerHome';
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PpScaffold(
            state: state,
            title: 'Home',
            body: const Text('Home content'),
            bottomNav: true,
            bottomTab: 'customerHome',
          ),
        ),
      );

      await tester.tap(find.text('Insights'));
      await tester.pump();
      expect(state.page, 'insights');
      expect(state.canPopPage, isFalse);
    });

    test('authentication roots clear stale navigation history', () {
      final state = AppState()..page = 'customerHome';
      addTearDown(state.dispose);

      state.go('customerProfile');
      state.setRootPage('login');
      expect(state.page, 'login');
      expect(state.popPage(), isFalse);
    });
  });

  testWidgets(
    'Android back returns from Edit Profile through its route stack',
    (tester) async {
      final state = AppState()..page = 'customerHome';
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AnimatedBuilder(
          animation: state,
          builder:
              (context, _) => MaterialApp(
                home: AppBackNavigationHandler(
                  state: state,
                  child: Scaffold(body: Text(state.page)),
                ),
              ),
        ),
      );

      state.go('customerProfile');
      state.go('editProfile');
      await tester.pump();
      expect(find.text('editProfile'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('customerProfile'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('customerHome'), findsOneWidget);
    },
  );

  testWidgets('root screen has no in-app route to pop', (tester) async {
    final state = AppState()..page = 'customerHome';
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AppBackNavigationHandler(
          state: state,
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    expect(state.popPage(), isFalse);
    expect(
      tester
          .widget<PopScope<Object?>>(
            find.byWidgetPredicate((widget) => widget is PopScope<Object?>),
          )
          .canPop,
      isTrue,
    );
  });

  testWidgets('system back closes a dialog before changing app page', (
    tester,
  ) async {
    final state = AppState()..page = 'customerHome';
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder:
            (context, _) => MaterialApp(
              home: AppBackNavigationHandler(
                state: state,
                child: Scaffold(
                  body: Builder(
                    builder:
                        (context) => TextButton(
                          onPressed:
                              () => showDialog<void>(
                                context: context,
                                builder:
                                    (context) => const AlertDialog(
                                      title: Text('Confirm'),
                                    ),
                              ),
                          child: const Text('Open dialog'),
                        ),
                  ),
                ),
              ),
            ),
      ),
    );
    state.go('customerProfile');
    await tester.pump();
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsNothing);
    expect(state.page, 'customerProfile');
  });

  testWidgets('system back closes a bottom sheet before changing app page', (
    tester,
  ) async {
    final state = AppState()..page = 'customerHome';
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: state,
        builder:
            (_, __) => MaterialApp(
              home: AppBackNavigationHandler(
                state: state,
                child: Builder(
                  builder:
                      (context) => Scaffold(
                        body: TextButton(
                          onPressed:
                              () => showModalBottomSheet<void>(
                                context: context,
                                builder:
                                    (_) => const SizedBox(
                                      height: 100,
                                      child: Center(
                                        child: Text('Sheet content'),
                                      ),
                                    ),
                              ),
                          child: const Text('Open sheet'),
                        ),
                      ),
                ),
              ),
            ),
      ),
    );
    state.go('customerProfile');
    await tester.pump();
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Sheet content'), findsNothing);
    expect(state.page, 'customerProfile');
  });
}
