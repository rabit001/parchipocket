import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/screens/common_screens.dart';
import 'package:parchipocket/theme.dart';
import 'package:parchipocket/features/auth/data/google_sign_in_service.dart';
import 'package:parchipocket/services/account_deletion_service.dart';

class _FakeGoogleSignInService implements GoogleSignInService {
  _FakeGoogleSignInService({this.idToken = 'mock-id-token'});
  String? idToken;
  int authCalls = 0;

  @override
  Future<String?> authenticate() async {
    authCalls++;
    return idToken;
  }

  @override
  Future<void> signOut() async {}
}

class _FakeAccountDeletionService extends AccountDeletionService {
  @override
  Future<Map<String, dynamic>> invokeDeletion({
    bool skipFreshnessCheckForTest = false,
  }) async {
    return <String, dynamic>{
      'success': true,
      'completed': true,
      'message': 'Account deleted',
    };
  }
}

class _MockUserInfo extends Fake implements UserInfo {
  _MockUserInfo({required this.providerId, this.email, this.phoneNumber});
  @override
  final String providerId;
  @override
  final String? email;
  @override
  final String? phoneNumber;
}

class _MockUserCredential extends Fake implements UserCredential {}

class _MockGoogleUser extends Fake implements User {
  _MockGoogleUser({
    this.email = 'testuser@gmail.com',
  });

  @override
  String get uid => 'google-user-123';
  @override
  final String? email;
  @override
  String? get phoneNumber => null;

  @override
  List<UserInfo> get providerData => <UserInfo>[
    _MockUserInfo(providerId: GoogleAuthProvider.PROVIDER_ID, email: email),
  ];

  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async {
    return _MockUserCredential();
  }
}

class _MockPhoneUser extends Fake implements User {
  _MockPhoneUser();

  @override
  String get uid => 'phone-user-456';
  @override
  String? get phoneNumber => '+919876543210';
  @override
  String? get email => null;

  @override
  List<UserInfo> get providerData => <UserInfo>[
    _MockUserInfo(providerId: PhoneAuthProvider.PROVIDER_ID, phoneNumber: phoneNumber),
  ];
}

class _MockUnsupportedUser extends Fake implements User {
  @override
  final String uid = 'custom-user-789';
  @override
  final String? email = 'custom@example.com';
  @override
  final String? phoneNumber = null;

  @override
  List<UserInfo> get providerData => <UserInfo>[
    _MockUserInfo(providerId: 'custom.token', email: email),
  ];
}

class _MockFirebaseAuth extends Fake implements FirebaseAuth {
  _MockFirebaseAuth({this.currentUser});
  @override
  User? currentUser;

  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();

  @override
  Future<void> signOut() async {
    currentUser = null;
  }
}

void main() {
  Widget buildTestApp(AppState state) {
    return MaterialApp(
      theme: buildPpTheme(),
      home: DeleteAccountConfirmScreen(state: state),
    );
  }

  group('DeleteAccountConfirmScreen UI Widget Tests', () {
    testWidgets('1. Google user sees Google re-authentication button and no SMS button', (tester) async {
      final googleUser = _MockGoogleUser(email: 'alice@gmail.com');
      final fakeGoogle = _FakeGoogleSignInService();
      final state = AppState(
        auth: _MockFirebaseAuth(currentUser: googleUser),
        googleSignInService: fakeGoogle,
        accountDeletionService: _FakeAccountDeletionService(),
      );
      state.isDemoMode = false;

      await tester.pumpWidget(buildTestApp(state));

      expect(find.text('Confirm Account Deletion'), findsOneWidget);
      expect(find.textContaining('alice@gmail.com'), findsOneWidget);
      expect(find.text('Re-authenticate with Google & Delete'), findsOneWidget);
      expect(find.text('Send SMS Verification Code'), findsNothing);
      expect(find.text('Cancel and Go Back'), findsOneWidget);
    });

    testWidgets('2. Tapping Google delete button invokes deleteAccountWithGoogle', (tester) async {
      final googleUser = _MockGoogleUser();
      final fakeGoogle = _FakeGoogleSignInService(idToken: 'valid-token');
      final state = AppState(
        auth: _MockFirebaseAuth(currentUser: googleUser),
        googleSignInService: fakeGoogle,
        accountDeletionService: _FakeAccountDeletionService(),
      );
      state.isDemoMode = false;

      await tester.pumpWidget(buildTestApp(state));

      await tester.tap(find.text('Re-authenticate with Google & Delete'));
      await tester.pumpAndSettle();

      expect(fakeGoogle.authCalls, 1);
      expect(state.isDemoMode, isTrue);
      expect(state.page, 'splash');
    });

    testWidgets('3. Phone user sees SMS OTP button and no Google button', (tester) async {
      final phoneUser = _MockPhoneUser();
      final state = AppState(
        auth: _MockFirebaseAuth(currentUser: phoneUser),
      );
      state.isDemoMode = false;

      await tester.pumpWidget(buildTestApp(state));

      expect(find.text('Confirm Account Deletion'), findsOneWidget);
      expect(find.textContaining('SMS OTP'), findsOneWidget);
      expect(find.text('Send SMS Verification Code'), findsOneWidget);
      expect(find.text('Re-authenticate with Google & Delete'), findsNothing);
      expect(find.text('Cancel and Go Back'), findsOneWidget);
    });

    testWidgets('4. Unsupported user sees informative guidance and Back to Privacy', (tester) async {
      final unsupportedUser = _MockUnsupportedUser();
      final state = AppState(
        auth: _MockFirebaseAuth(currentUser: unsupportedUser),
      );
      state.isDemoMode = false;

      await tester.pumpWidget(buildTestApp(state));

      expect(find.text('Confirm Account Deletion'), findsOneWidget);
      expect(find.textContaining('does not have a supported re-authentication provider'), findsOneWidget);
      expect(find.text('Back to Privacy'), findsOneWidget);
      expect(find.text('Re-authenticate with Google & Delete'), findsNothing);
      expect(find.text('Send SMS Verification Code'), findsNothing);
    });
  });
}
