import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/screens/shop_screens.dart';
import 'package:parchipocket/screens/vendor_screens.dart';

class _SignedInUser extends Fake implements User {
  @override
  String get uid => 'cloud-seller';
}

class _SignedInAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _SignedInUser();
}

void main() {
  group('Shop owner mode labels', () {
    testWidgets('demo mode keeps local demo status and disclaimer',
        (tester) async {
      final state = AppState();
      await tester.pumpWidget(MaterialApp(home: ShopHomeScreen(state: state)));

      expect(find.text('Shop owner account · Demo mode'), findsOneWidget);
      expect(find.text('0 recorded bills in this demo'), findsOneWidget);
      final demoNotice = find.textContaining('not synced to a server');
      await tester.scrollUntilVisible(
        demoNotice,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(demoNotice, findsOneWidget);
      state.dispose();
    });

    testWidgets('authenticated cloud mode does not show demo-only claims',
        (tester) async {
      final state = AppState()
        ..isDemoMode = false
        ..auth = _SignedInAuth();
      await tester.pumpWidget(MaterialApp(home: ShopHomeScreen(state: state)));

      expect(
          find.text('Shop owner account · Signed in to cloud'), findsOneWidget);
      expect(find.text('0 recorded bills in your account'), findsOneWidget);
      expect(find.textContaining('not synced to a server'), findsNothing);
      final cloudNotice =
          find.textContaining('after Firestore confirms the save');
      await tester.scrollUntilVisible(
        cloudNotice,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(cloudNotice, findsOneWidget);
      state.dispose();
    });
  });

  group('Street vendor mode labels', () {
    testWidgets('demo mode identifies local demo receipts', (tester) async {
      final state = AppState();
      await tester
          .pumpWidget(MaterialApp(home: VendorHomeScreen(state: state)));

      expect(
          find.text('Quick mode · Street vendor · Demo mode'), findsOneWidget);
      expect(find.text('0 demo receipts'), findsOneWidget);
      expect(find.textContaining('Figures are demo/local data only.'),
          findsOneWidget);
      state.dispose();
    });

    testWidgets('authenticated cloud mode identifies account receipts',
        (tester) async {
      final state = AppState()
        ..isDemoMode = false
        ..auth = _SignedInAuth();
      await tester
          .pumpWidget(MaterialApp(home: VendorHomeScreen(state: state)));

      expect(find.text('Street vendor account · Signed in to cloud'),
          findsOneWidget);
      expect(find.text('0 recorded receipts in your account'), findsOneWidget);
      expect(find.textContaining('Figures are demo/local data only.'),
          findsNothing);
      final cloudNotice =
          find.textContaining('after Firestore confirms the save');
      await tester.scrollUntilVisible(
        cloudNotice,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(cloudNotice, findsOneWidget);
      state.dispose();
    });
  });

  group('Create bill mode notice', () {
    testWidgets('demo mode explains receipt is local', (tester) async {
      final state = AppState();
      await tester
          .pumpWidget(MaterialApp(home: CreateBillScreen(state: state)));

      final demoNotice = find.textContaining('local demo state');
      await tester.scrollUntilVisible(
        demoNotice,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(demoNotice, findsOneWidget);
      state.dispose();
    });

    testWidgets('cloud mode waits for Firestore confirmation', (tester) async {
      final state = AppState()
        ..isDemoMode = false
        ..auth = _SignedInAuth();
      await tester
          .pumpWidget(MaterialApp(home: CreateBillScreen(state: state)));

      final cloudNotice =
          find.textContaining('only after Firestore confirms the write');
      await tester.scrollUntilVisible(
        cloudNotice,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(cloudNotice, findsOneWidget);
      expect(find.textContaining('local demo state'), findsNothing);
      state.dispose();
    });
  });
}
