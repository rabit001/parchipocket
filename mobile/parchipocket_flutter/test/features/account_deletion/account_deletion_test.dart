import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/services/account_deletion_service.dart';
import 'package:parchipocket/features/auth/data/google_sign_in_service.dart';

class _FakeAccountDeletionService extends AccountDeletionService {
  _FakeAccountDeletionService({
    this.shouldSucceed = true,
    this.errorMessage = 'Backend error',
  });

  final bool shouldSucceed;
  final String errorMessage;
  int invokeCount = 0;
  bool lastSkipFreshness = false;

  @override
  Future<Map<String, dynamic>> invokeDeletion({
    bool skipFreshnessCheckForTest = false,
  }) async {
    invokeCount++;
    lastSkipFreshness = skipFreshnessCheckForTest;
    if (!shouldSucceed) {
      throw StateError(errorMessage);
    }
    return <String, dynamic>{
      'success': true,
      'message': 'Account and data deleted.',
      'completed': true,
    };
  }
}

class _FakeGoogleSignInService implements GoogleSignInService {
  _FakeGoogleSignInService({
    this.idToken = 'mock-google-id-token',
  });

  String? idToken;
  int authenticateCount = 0;
  int signOutCount = 0;

  @override
  Future<String?> authenticate() async {
    authenticateCount++;
    return idToken;
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
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
    this.reauthException,
  });

  @override
  String get uid => 'google-user-123';
  @override
  String? get email => 'user@example.com';
  @override
  String? get phoneNumber => null;
  final FirebaseAuthException? reauthException;
  int reauthCount = 0;
  AuthCredential? lastCredential;

  @override
  List<UserInfo> get providerData => <UserInfo>[
    _MockUserInfo(providerId: GoogleAuthProvider.PROVIDER_ID, email: email),
  ];

  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async {
    reauthCount++;
    lastCredential = credential;
    if (reauthException != null) throw reauthException!;
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
  int reauthCount = 0;
  AuthCredential? lastCredential;

  @override
  List<UserInfo> get providerData => <UserInfo>[
    _MockUserInfo(providerId: PhoneAuthProvider.PROVIDER_ID, phoneNumber: phoneNumber),
  ];

  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async {
    reauthCount++;
    lastCredential = credential;
    return _MockUserCredential();
  }
}

class _MockUnsupportedUser extends Fake implements User {
  _MockUnsupportedUser();

  @override
  String get uid => 'custom-user-789';
  @override
  String? get email => 'custom@example.com';
  @override
  String? get phoneNumber => null;

  @override
  List<UserInfo> get providerData => <UserInfo>[
    _MockUserInfo(providerId: 'custom.token', email: email),
  ];
}

class _MockFirebaseAuth extends Fake implements FirebaseAuth {
  _MockFirebaseAuth({this.currentUser});
  @override
  User? currentUser;
  int signOutCount = 0;

  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();

  @override
  Future<void> signOut() async {
    signOutCount++;
    currentUser = null;
  }
}

void main() {
  group('ParchiPocket SEC-03 Account Deletion Client Unit Tests', () {
    test('1. Demo Mode cannot trigger server-side account deletion', () async {
      final fakeService = _FakeAccountDeletionService();
      final state = AppState(accountDeletionService: fakeService);

      state.isDemoMode = true;
      final sentOtp = await state.sendDeletionReauthOtp();
      expect(sentOtp, isFalse);
      expect(state.deletionError, contains('Demo Mode'));
      expect(fakeService.invokeCount, 0);

      final deleted = await state.deleteAccountWithOtp('123456');
      expect(deleted, isFalse);
      expect(state.deletionError, contains('Demo mode'));
      expect(fakeService.invokeCount, 0);

      final googleDeleted = await state.deleteAccountWithGoogle();
      expect(googleDeleted, isFalse);
      expect(state.deletionError, contains('Demo mode'));
      expect(fakeService.invokeCount, 0);
    });

    test('2. resetDemoData resets sample records and clears errors locally', () {
      final state = AppState();
      state.deletionError = 'Some transient error';
      state.resetDemoData();

      expect(state.deletionError, isNull);
      expect(state.deletionSuccessMessage, contains('Demo records reset'));
      expect(state.bills, isNotEmpty);
      expect(state.householdExpenses, isNotEmpty);
    });

    test('3. Unauthenticated session cannot request deletion OTP or Google deletion', () async {
      final fakeService = _FakeAccountDeletionService();
      final state = AppState(accountDeletionService: fakeService);

      // Simulate non-demo, unauthenticated state
      state.isDemoMode = false;
      final sent = await state.sendDeletionReauthOtp();
      expect(sent, isFalse);
      expect(state.deletionError, contains('signed in'));
      expect(fakeService.invokeCount, 0);

      final googleResult = await state.deleteAccountWithGoogle();
      expect(googleResult, isFalse);
      expect(state.deletionError, contains('signed in'));
      expect(fakeService.invokeCount, 0);
    });

    test('4. deleteAccountWithOtp requires SMS code and verificationId', () async {
      final fakeService = _FakeAccountDeletionService();
      final state = AppState(accountDeletionService: fakeService);

      state.isDemoMode = false;
      state.deletionVerificationId = null;

      final result = await state.deleteAccountWithOtp('123456');
      expect(result, isFalse);
      expect(state.deletionError, contains('signed in'));
      expect(fakeService.invokeCount, 0);
    });

    test('5. Backend failure preserves user context and surfaces actionable error', () async {
      final fakeService = _FakeAccountDeletionService(
        shouldSucceed: false,
        errorMessage: 'Recent authentication required (auth_time expired).',
      );
      final state = AppState(accountDeletionService: fakeService);

      state.isDemoMode = false;
      state.deletionVerificationId = 'mock-v-id';

      // Will fail when attempting to reauth without live Firebase Auth or when service throws
      final result = await state.deleteAccountWithOtp('123456');
      expect(result, isFalse);
      expect(state.isDeletingAccount, isFalse);
      expect(state.deletionError, isNotNull);
      expect(state.deletionSuccessMessage, isNull);
    });

    test('6. Deletion failure leaves safe retry path and prevents premature success', () async {
      final fakeService = _FakeAccountDeletionService(
        shouldSucceed: false,
        errorMessage: 'Backend timeout while acquiring exclusive lock',
      );
      final state = AppState(accountDeletionService: fakeService);
      state.isDemoMode = false;
      state.deletionVerificationId = 'v-id-retry';
      state.page = 'deleteConfirm';

      final success = await state.deleteAccountWithOtp('654321');
      expect(success, isFalse);
      expect(state.page, 'deleteConfirm'); // stays on confirmation page
      expect(state.deletionSuccessMessage, isNull); // no premature success
      expect(state.deletionError, isNotNull); // clear failure feedback
      expect(state.isDeletingAccount, isFalse); // loading cleared for retry
    });

    test('7. deletionAuthProvider correctly identifies Google, Phone, and Unsupported users', () {
      final googleUser = _MockGoogleUser();
      final phoneUser = _MockPhoneUser();
      final unsupportedUser = _MockUnsupportedUser();

      final state = AppState();
      state.isDemoMode = false;

      state.auth = _MockFirebaseAuth(currentUser: googleUser);
      expect(state.deletionAuthProvider, DeletionAuthProvider.google);

      state.auth = _MockFirebaseAuth(currentUser: phoneUser);
      expect(state.deletionAuthProvider, DeletionAuthProvider.phone);

      state.auth = _MockFirebaseAuth(currentUser: unsupportedUser);
      expect(state.deletionAuthProvider, DeletionAuthProvider.unsupported);

      state.auth = _MockFirebaseAuth(currentUser: null);
      expect(state.deletionAuthProvider, DeletionAuthProvider.unsupported);

      state.isDemoMode = true;
      expect(state.deletionAuthProvider, DeletionAuthProvider.unsupported);
    });

    test('8. Google user re-authenticates via GoogleSignInService and completes deletion flow', () async {
      final mockUser = _MockGoogleUser();
      final mockAuth = _MockFirebaseAuth(currentUser: mockUser);
      final fakeGoogle = _FakeGoogleSignInService(idToken: 'valid-test-token-xyz');
      final fakeDeletion = _FakeAccountDeletionService(shouldSucceed: true);

      final state = AppState(
        auth: mockAuth,
        googleSignInService: fakeGoogle,
        accountDeletionService: fakeDeletion,
      );
      state.isDemoMode = false;
      state.page = 'deleteConfirm';

      final success = await state.deleteAccountWithGoogle();

      expect(success, isTrue);
      expect(fakeGoogle.authenticateCount, 1);
      expect(mockUser.reauthCount, 1);
      expect(mockUser.lastCredential, isA<AuthCredential>());
      expect(fakeDeletion.invokeCount, 1);
      expect(mockAuth.signOutCount, 1);
      expect(fakeGoogle.signOutCount, 1);
      expect(state.isDemoMode, isTrue);
      expect(state.deletionSuccessMessage, contains('permanently deleted'));
      expect(state.page, 'splash');
      expect(state.isDeletingAccount, isFalse);
    });

    test('9. Google Sign-In cancellation leaves account untouched without error', () async {
      final mockUser = _MockGoogleUser();
      final mockAuth = _MockFirebaseAuth(currentUser: mockUser);
      final fakeGoogle = _FakeGoogleSignInService(idToken: null); // cancelled
      final fakeDeletion = _FakeAccountDeletionService();

      final state = AppState(
        auth: mockAuth,
        googleSignInService: fakeGoogle,
        accountDeletionService: fakeDeletion,
      );
      state.isDemoMode = false;

      final success = await state.deleteAccountWithGoogle();

      expect(success, isFalse);
      expect(fakeGoogle.authenticateCount, 1);
      expect(mockUser.reauthCount, 0); // No re-auth attempted
      expect(fakeDeletion.invokeCount, 0); // No deletion attempted
      expect(state.isDeletingAccount, isFalse);
      expect(state.deletionError, isNull); // User cancelled, no alarming error
      expect(mockAuth.currentUser, isNotNull); // Account untouched
    });

    test('10. Empty Google ID token halts deletion and surfaces actionable error', () async {
      final mockUser = _MockGoogleUser();
      final mockAuth = _MockFirebaseAuth(currentUser: mockUser);
      final fakeGoogle = _FakeGoogleSignInService(idToken: '   ');
      final fakeDeletion = _FakeAccountDeletionService();

      final state = AppState(
        auth: mockAuth,
        googleSignInService: fakeGoogle,
        accountDeletionService: fakeDeletion,
      );
      state.isDemoMode = false;

      final success = await state.deleteAccountWithGoogle();

      expect(success, isFalse);
      expect(fakeGoogle.authenticateCount, 1);
      expect(mockUser.reauthCount, 0);
      expect(fakeDeletion.invokeCount, 0);
      expect(state.deletionError, contains('valid token'));
      expect(state.isDeletingAccount, isFalse);
    });

    test('11. Firebase re-authentication failure halts deletion and surfaces error', () async {
      final mockUser = _MockGoogleUser(
        reauthException: FirebaseAuthException(
          code: 'user-token-expired',
          message: 'The Google authentication token has expired. Please sign in again.',
        ),
      );
      final mockAuth = _MockFirebaseAuth(currentUser: mockUser);
      final fakeGoogle = _FakeGoogleSignInService(idToken: 'expired-token');
      final fakeDeletion = _FakeAccountDeletionService();

      final state = AppState(
        auth: mockAuth,
        googleSignInService: fakeGoogle,
        accountDeletionService: fakeDeletion,
      );
      state.isDemoMode = false;

      final success = await state.deleteAccountWithGoogle();

      expect(success, isFalse);
      expect(fakeGoogle.authenticateCount, 1);
      expect(mockUser.reauthCount, 1);
      expect(fakeDeletion.invokeCount, 0); // Deletion never invoked
      expect(state.deletionError, contains('expired'));
      expect(state.isDeletingAccount, isFalse);
      expect(mockAuth.currentUser, isNotNull); // Account untouched
    });

    test('12. Phone user cannot initiate Google deletion and retains OTP flow', () async {
      final mockUser = _MockPhoneUser();
      final mockAuth = _MockFirebaseAuth(currentUser: mockUser);
      final fakeGoogle = _FakeGoogleSignInService();
      final fakeDeletion = _FakeAccountDeletionService(shouldSucceed: true);

      final state = AppState(
        auth: mockAuth,
        googleSignInService: fakeGoogle,
        accountDeletionService: fakeDeletion,
      );
      state.isDemoMode = false;

      // Google deletion rejected
      final googleSuccess = await state.deleteAccountWithGoogle();
      expect(googleSuccess, isFalse);
      expect(state.deletionError, contains('not available for this account'));
      expect(fakeGoogle.authenticateCount, 0);
      expect(fakeDeletion.invokeCount, 0);

      // Phone deletion with verification ID works
      state.deletionVerificationId = 'phone-v-id';
      final phoneSuccess = await state.deleteAccountWithOtp('123456');
      expect(phoneSuccess, isTrue);
      expect(mockUser.reauthCount, 1);
      expect(fakeDeletion.invokeCount, 1);
      expect(state.isDemoMode, isTrue);
      expect(state.page, 'splash');
    });

    test('13. Duplicate deletion requests while already in-flight are rejected', () async {
      final mockUser = _MockGoogleUser();
      final mockAuth = _MockFirebaseAuth(currentUser: mockUser);
      final state = AppState(auth: mockAuth);

      state.isDemoMode = false;
      state.isDeletingAccount = true; // simulated in-flight request

      final googleResult = await state.deleteAccountWithGoogle();
      expect(googleResult, isFalse);

      final otpResult = await state.deleteAccountWithOtp('123456');
      expect(otpResult, isFalse);
    });
  });
}
