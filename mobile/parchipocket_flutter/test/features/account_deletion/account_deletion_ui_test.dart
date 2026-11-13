import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/screens/common_screens.dart';
import 'package:parchipocket/services/account_deletion_service.dart';
import 'package:parchipocket/services/firestore_service.dart';

class _FakeUserCredential extends Fake implements UserCredential {}

class _FakeUser extends Fake implements User {
  _FakeUser(this.reauthentication);

  final Completer<UserCredential> reauthentication;

  @override
  String get uid => 'deletion-test-user';

  @override
  String? get phoneNumber => '+911234567890';

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) =>
      reauthentication.future;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this.user);

  User? user;

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();

  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    PhoneMultiFactorInfo? multiFactorInfo,
    Duration timeout = const Duration(seconds: 30),
    int? forceResendingToken,
    String? autoRetrievedSmsCodeForTesting,
    MultiFactorSession? multiFactorSession,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) async {
    codeSent('mock-verification-id', 7);
  }

  @override
  Future<void> signOut() async {
    user = null;
  }
}

class _FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  @override
  Future<void> clearPersistence() async {}
}

class _FakeFirestoreService extends FirestoreService {
  _FakeFirestoreService() : super(firestore: _FakeFirebaseFirestore());
}

class _FakeAccountDeletionService extends AccountDeletionService {
  int calls = 0;
  bool complete = true;

  @override
  Future<Map<String, dynamic>> invokeDeletion({
    bool skipFreshnessCheckForTest = false,
  }) async {
    calls++;
    return <String, dynamic>{
      'success': complete,
      'completed': complete,
      if (!complete) 'leaseActive': false,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Account deletion UI with local fakes', () {
    testWidgets('review requires explicit proceed and supports cancellation',
        (tester) async {
      final state = AppState()..page = 'deleteReview';
      await tester.pumpWidget(MaterialApp(
        home: DeleteAccountReviewScreen(state: state),
      ));

      expect(find.text('Review Before Deleting'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel and Keep Account'));
      expect(state.page, 'privacy');

      await tester.pumpWidget(MaterialApp(
        home: DeleteAccountReviewScreen(state: state),
      ));
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proceed to Identity Verification'));
      expect(state.page, 'deleteConfirm');
      state.dispose();
    });

    testWidgets(
        'confirmation shows loading, deletes, logs out and clears session',
        (tester) async {
      final reauthentication = Completer<UserCredential>();
      final user = _FakeUser(reauthentication);
      final auth = _FakeAuth(user);
      final deletion = _FakeAccountDeletionService();
      final state = AppState(
        auth: auth,
        accountDeletionService: deletion,
      )
        ..isDemoMode = false
        ..firestoreService = _FakeFirestoreService()
        ..page = 'deleteConfirm';

      await tester.pumpWidget(AnimatedBuilder(
        animation: state,
        builder: (_, __) => MaterialApp(
          home: DeleteAccountConfirmScreen(state: state),
        ),
      ));
      await tester.tap(find.text('Send SMS Verification Code'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Permanently Delete Account'));
      await tester.pump();

      expect(state.isDeletingAccount, isTrue);
      expect(find.text('Deleting Account & Data...'), findsOneWidget);
      final deletingButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Deleting Account & Data...'),
      );
      expect(deletingButton.onPressed, isNull);

      reauthentication.complete(_FakeUserCredential());
      await tester.pumpAndSettle();

      expect(deletion.calls, 1);
      expect(state.isDeletingAccount, isFalse);
      expect(state.deletionSuccessMessage, contains('permanently deleted'));
      expect(state.isDemoMode, isTrue);
      expect(state.page, 'splash');
      expect(auth.currentUser, isNull);

      final repeated = await state.deleteAccountWithOtp('123456');
      expect(repeated, isFalse);
      expect(deletion.calls, 1);
      state.dispose();
    });

    testWidgets('interrupted deletion remains retryable until confirmed',
        (tester) async {
      final reauthentication = Completer<UserCredential>();
      final auth = _FakeAuth(_FakeUser(reauthentication));
      final deletion = _FakeAccountDeletionService()..complete = false;
      final state = AppState(
        auth: auth,
        accountDeletionService: deletion,
      )
        ..isDemoMode = false
        ..firestoreService = _FakeFirestoreService()
        ..deletionVerificationId = 'mock-verification-id'
        ..page = 'deleteConfirm';

      final first = state.deleteAccountWithOtp('123456');
      await tester.pump();
      expect(state.isDeletingAccount, isTrue);
      reauthentication.complete(_FakeUserCredential());
      expect(await first, isFalse);
      expect(state.isDeletingAccount, isFalse);
      expect(state.page, 'deleteConfirm');
      expect(state.deletionSuccessMessage, isNull);
      expect(state.deletionError, contains('not confirmed completion'));

      deletion.complete = true;
      final recovered = await state.deleteAccountWithOtp('123456');
      expect(recovered, isTrue);
      expect(deletion.calls, 2);
      expect(state.deletionSuccessMessage, contains('permanently deleted'));
      expect(auth.currentUser, isNull);
      state.dispose();
    });
  });
}
