import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/core/data/firestore_service.dart';
import 'package:parchipocket/core/state/app_state.dart';
import 'package:parchipocket/features/auth/data/google_sign_in_service.dart';
import 'package:parchipocket/features/auth/presentation/auth_screens.dart';

class _GoogleUser extends Fake implements User {
  @override
  String get uid => 'google-user-1';

  @override
  String? get displayName => 'Google Person';

  @override
  String? get email => 'person@example.com';

  @override
  List<UserInfo> get providerData => <UserInfo>[_GoogleProviderInfo()];
}

class _GoogleProviderInfo extends Fake implements UserInfo {
  @override
  String get providerId => GoogleAuthProvider.PROVIDER_ID;
}

class _PhoneUser extends Fake implements User {
  @override
  String get uid => 'phone-user-1';

  @override
  List<UserInfo> get providerData => <UserInfo>[_PhoneProviderInfo()];
}

class _OtherUser extends Fake implements User {
  @override
  String get uid => 'other-user-1';

  @override
  String? get displayName => null;

  @override
  String? get email => null;

  @override
  List<UserInfo> get providerData => <UserInfo>[_PhoneProviderInfo()];
}

class _PhoneProviderInfo extends Fake implements UserInfo {
  @override
  String get providerId => PhoneAuthProvider.PROVIDER_ID;
}

class _CredentialResult extends Fake implements UserCredential {
  _CredentialResult(this.user);

  @override
  final User? user;
}

class _PhoneCredential extends Fake implements PhoneAuthCredential {}

class _Auth extends Fake implements FirebaseAuth {
  final StreamController<User?> events = StreamController<User?>.broadcast(
    sync: true,
  );
  User? current;
  Object? signInError;
  Completer<UserCredential>? credentialGate;
  Completer<void>? credentialStarted;
  Completer<void>? signOutCompleted;
  Completer<void>? signOutAttempted;
  Completer<void>? signOutGate;
  Completer<void>? phoneVerificationGate;
  Completer<void>? phoneVerificationStarted;
  Object? phoneVerificationError;
  Object? signOutError;
  bool clearCurrentUserBeforeSignOutError = false;
  bool applyCredentialResultToCurrent = true;
  PhoneVerificationCompleted? lastPhoneVerificationCompleted;
  PhoneCodeSent? lastPhoneCodeSent;
  final List<PhoneVerificationCompleted> phoneVerificationCallbacks =
      <PhoneVerificationCompleted>[];
  final List<PhoneCodeSent> codeSentCallbacks = <PhoneCodeSent>[];
  final List<PhoneCodeAutoRetrievalTimeout> autoRetrievalTimeoutCallbacks =
      <PhoneCodeAutoRetrievalTimeout>[];
  int credentialCalls = 0;
  int activeCredentialExchanges = 0;
  int maximumActiveCredentialExchanges = 0;
  String? credentialProviderId;
  int signOutCalls = 0;
  int verifyPhoneNumberCalls = 0;
  int? lastResendToken;

  @override
  User? get currentUser => current;

  @override
  Stream<User?> authStateChanges() => events.stream;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    credentialCalls++;
    activeCredentialExchanges++;
    if (activeCredentialExchanges > maximumActiveCredentialExchanges) {
      maximumActiveCredentialExchanges = activeCredentialExchanges;
    }
    credentialProviderId = credential.providerId;
    if (credentialStarted case final started? when !started.isCompleted) {
      started.complete();
    }
    try {
      final gate = credentialGate;
      final result = gate == null ? null : await gate.future;
      if (signInError case final error?) throw error;
      final credentialUser =
          result?.user ??
          (credential.providerId == PhoneAuthProvider.PROVIDER_ID
              ? _PhoneUser()
              : _GoogleUser());
      if (applyCredentialResultToCurrent) current = credentialUser;
      events.add(credentialUser);
      return result ?? _CredentialResult(credentialUser);
    } finally {
      activeCredentialExchanges--;
    }
  }

  @override
  Future<void> verifyPhoneNumber({
    String? phoneNumber,
    Duration timeout = const Duration(seconds: 60),
    int? forceResendingToken,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    String? autoRetrievedSmsCodeForTesting,
    PhoneMultiFactorInfo? multiFactorInfo,
    MultiFactorSession? multiFactorSession,
  }) async {
    verifyPhoneNumberCalls++;
    lastResendToken = forceResendingToken;
    lastPhoneVerificationCompleted = verificationCompleted;
    lastPhoneCodeSent = codeSent;
    phoneVerificationCallbacks.add(verificationCompleted);
    codeSentCallbacks.add(codeSent);
    autoRetrievalTimeoutCallbacks.add(codeAutoRetrievalTimeout);
    if (phoneVerificationStarted case final started?
        when !started.isCompleted) {
      started.complete();
    }
    await phoneVerificationGate?.future;
    if (phoneVerificationError case final error?) {
      verificationFailed(
        error is FirebaseAuthException
            ? error
            : FirebaseAuthException(code: 'unknown'),
      );
    } else {
      codeSent('controlled-verification-id', 42);
    }
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutAttempted case final attempted? when !attempted.isCompleted) {
      attempted.complete();
    }
    await signOutGate?.future;
    if (clearCurrentUserBeforeSignOutError && signOutError != null) {
      current = null;
      events.add(null);
    }
    if (signOutError case final error?) throw error;
    current = null;
    events.add(null);
    signOutCompleted?.complete();
  }
}

class _GoogleProvider implements GoogleSignInService {
  Future<String?> Function()? onAuthenticate;
  Completer<void>? authenticateStarted;
  Object? signOutError;
  int authenticateCalls = 0;
  int signOutCalls = 0;

  @override
  Future<String?> authenticate() async {
    authenticateCalls++;
    authenticateStarted?.complete();
    return onAuthenticate?.call() ?? 'id-token';
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError case final error?) throw error;
  }
}

class _Firestore extends FirestoreService {
  _Firestore() : super(auth: null);

  Map<String, dynamic>? profile;
  int profileReads = 0;
  Completer<void>? profileReadStarted;

  @override
  Future<Map<String, dynamic>?> loadUserProfile() async {
    profileReads++;
    if (profileReadStarted case final started? when !started.isCompleted) {
      started.complete();
    }
    return profile;
  }

  @override
  Future<List<DemoBill>> loadBills() async => <DemoBill>[];

  @override
  Future<List<DemoExpense>> loadExpenses() async => <DemoExpense>[];

  @override
  Future<List<HouseholdExpense>> loadHouseholdExpenses() async =>
      <HouseholdExpense>[];

  @override
  Future<Set<String>> loadSavedShops() async => <String>{};

  @override
  Future<List<ClaimedReceipt>> loadClaimedReceipts() async =>
      <ClaimedReceipt>[];

  @override
  Future<List<HouseholdExpense>> loadHouseholdExpensesForMonth(
    int year,
    int month, {
    int batchSize = 500,
    int? limit,
  }) async => <HouseholdExpense>[];
}

void main() {
  group('Google sign-in', () {
    late _Auth auth;
    late _GoogleProvider provider;
    late _Firestore firestore;
    late AppState state;

    AppState createState({
      Duration cleanupNoticeAfter = const Duration(seconds: 8),
    }) =>
        AppState(
          auth: auth,
          googleSignInService: provider,
          phoneCredentialCleanupNoticeAfter: cleanupNoticeAfter,
        )..firestoreService = firestore;

    Future<void> useImmediateCleanupNotice() async {
      state.dispose();
      state = createState(cleanupNoticeAfter: Duration.zero);
    }

    setUp(() {
      auth = _Auth();
      provider = _GoogleProvider();
      firestore = _Firestore();
      state = createState();
    });

    tearDown(() async {
      state.dispose();
      await auth.events.close();
    });

    test('signs in with Google credential and loads profile once', () async {
      expect(await state.signInWithGoogle(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(auth.credentialCalls, 1);
      expect(auth.credentialProviderId, GoogleAuthProvider.PROVIDER_ID);
      expect(firestore.profileReads, 1);
      expect(state.profileStatus, CloudProfileStatus.missing);
      expect(state.page, 'customerSetup');
      expect(state.customerName, 'Google Person');
      expect(state.customerEmail, 'person@example.com');
    });

    test('uses Firestore profile as authority for existing account', () async {
      firestore.profile = <String, dynamic>{
        'role': 'customer',
        'name': 'Saved Name',
        'email': 'saved@example.com',
      };

      expect(await state.signInWithGoogle(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(state.page, 'customerHome');
      expect(state.customerName, 'Saved Name');
      expect(state.customerEmail, 'saved@example.com');
      expect(firestore.profileReads, 1);
    });

    test('cancellation leaves login usable without an auth error', () async {
      provider.onAuthenticate = () async => null;

      expect(await state.signInWithGoogle(), isFalse);
      expect(state.page, 'login');
      expect(state.isGoogleSignInLoading, isFalse);
      expect(state.googleAuthError, isNull);
      expect(state.isDemoMode, isTrue);
    });

    test('missing ID token fails safely and clears loading state', () async {
      provider.onAuthenticate = () async => '';

      expect(await state.signInWithGoogle(), isFalse);
      expect(state.googleAuthError, contains('could not complete'));
      expect(state.isGoogleSignInLoading, isFalse);
      expect(auth.credentialCalls, 0);
    });

    test(
      'Firebase authentication failure clears intent and can retry',
      () async {
        auth.signInError = FirebaseAuthException(code: 'invalid-credential');

        expect(await state.signInWithGoogle(), isFalse);
        expect(state.isGoogleSignInLoading, isFalse);
        expect(state.isDemoMode, isTrue);
        expect(state.googleAuthError, contains('Google sign-in failed'));

        auth.signInError = null;
        expect(await state.signInWithGoogle(), isTrue);
      },
    );

    test(
      'concurrent requests start only one provider and credential flow',
      () async {
        final gate = Completer<String?>();
        provider.onAuthenticate = () => gate.future;

        final first = state.signInWithGoogle();
        final second = state.signInWithGoogle();
        gate.complete('id-token');

        expect(await first, isTrue);
        expect(await second, isFalse);
        expect(provider.authenticateCalls, 1);
        expect(auth.credentialCalls, 1);
      },
    );

    test(
      'Google provider sign-out failure does not block Firebase sign-out',
      () async {
        auth.current = _GoogleUser();
        state.isDemoMode = false;
        provider.signOutError = StateError('provider unavailable');

        expect(await state.signOut(), isTrue);
        expect(auth.signOutCalls, 1);
        expect(provider.signOutCalls, 1);
        expect(auth.currentUser, isNull);
      },
    );

    test('a pending Google sign-in blocks phone credential exchange', () async {
      final providerStarted = Completer<void>();
      final googleGate = Completer<String?>();
      provider.authenticateStarted = providerStarted;
      provider.onAuthenticate = () => googleGate.future;
      final google = state.signInWithGoogle();
      await providerStarted.future;

      var phoneError = false;
      await state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) => phoneError = true,
      );

      expect(phoneError, isTrue);
      expect(auth.verifyPhoneNumberCalls, 0);
      googleGate.complete('id-token');
      expect(await google, isTrue);
      expect(auth.credentialCalls, 1);
      expect(auth.maximumActiveCredentialExchanges, 1);
    });

    test('a pending phone sign-in blocks Google credential exchange', () async {
      final phoneStarted = Completer<void>();
      auth.phoneVerificationStarted = phoneStarted;
      auth.phoneVerificationGate = Completer<void>();
      final phone = state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) {},
      );
      await phoneStarted.future;

      expect(await state.signInWithGoogle(), isFalse);
      expect(provider.authenticateCalls, 0);
      expect(auth.credentialCalls, 0);
      expect(state.isGoogleSignInLoading, isFalse);

      auth.phoneVerificationGate!.complete();
      await phone;
      expect(auth.verifyPhoneNumberCalls, 1);
    });

    test(
      'phone sign-in cannot reserve twice while stale Firebase sign-out waits',
      () async {
        auth.current = _GoogleUser();
        auth.signOutGate = Completer<void>();
        final demo = state.enterDemoMode();
        final first = state.beginAuthentication(method: SignInMethod.phone);

        expect(
          await state.beginAuthentication(method: SignInMethod.phone),
          isFalse,
        );
        auth.signOutGate!.complete();
        await demo;
        expect(await first, isTrue);
        expect(state.isDemoMode, isFalse);
      },
    );

    test(
      'repeated Demo Mode taps reuse the in-flight Firebase sign-out',
      () async {
        auth.current = _GoogleUser();
        auth.signOutGate = Completer<void>();
        auth.signOutAttempted = Completer<void>();
        final first = state.enterDemoMode();
        await auth.signOutAttempted!.future;

        await state.enterDemoMode();
        expect(auth.signOutCalls, 1);

        auth.signOutGate!.complete();
        await first;
        expect(auth.signOutCalls, 1);
        expect(state.isDemoMode, isTrue);
      },
    );

    test('phone failure clears loading and allows an OTP retry', () async {
      auth.phoneVerificationError = FirebaseAuthException(
        code: 'invalid-phone-number',
      );
      await state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) {},
      );
      expect(state.isPhoneAuthLoading, isFalse);

      auth.phoneVerificationError = null;
      await state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) {},
      );
      expect(auth.verifyPhoneNumberCalls, 2);
      expect(state.isPhoneAuthLoading, isFalse);
      expect(state.verificationId, 'controlled-verification-id');
    });

    test(
      'Demo Mode signs out a credential exchange that finishes later',
      () async {
        auth.credentialGate = Completer<UserCredential>();
        auth.credentialStarted = Completer<void>();
        auth.signOutCompleted = Completer<void>();
        final google = state.signInWithGoogle();
        await auth.credentialStarted!.future;
        expect(auth.currentUser, isNull);

        await state.enterDemoMode();
        expect(state.isDemoMode, isTrue);
        expect(state.page, 'customerSetup');

        auth.credentialGate!.complete(_CredentialResult(_GoogleUser()));
        expect(await google, isFalse);
        await auth.signOutCompleted!.future;

        auth.events.add(_GoogleUser());
        expect(state.isDemoMode, isTrue);
        expect(state.page, 'customerSetup');
        expect(auth.currentUser, isNull);
        expect(auth.signOutCalls, 1);

        auth.credentialGate = null;
        auth.credentialStarted = null;
        auth.signOutCompleted = null;
        expect(await state.signInWithGoogle(), isTrue);
      },
    );

    test(
      'Demo Mode reports Firebase sign-out failure after pending sign-in',
      () async {
        final cleanupReported = Completer<void>();
        state.addListener(() {
          if (state.signOutError != null && !cleanupReported.isCompleted) {
            cleanupReported.complete();
          }
        });
        auth.credentialGate = Completer<UserCredential>();
        auth.credentialStarted = Completer<void>();
        auth.signOutAttempted = Completer<void>();
        auth.signOutError = StateError('sign out failed');
        final google = state.signInWithGoogle();
        await auth.credentialStarted!.future;
        await state.enterDemoMode();
        auth.credentialGate!.complete(_CredentialResult(_GoogleUser()));
        expect(await google, isFalse);

        await auth.signOutAttempted!.future;
        await cleanupReported.future;
        expect(state.isDemoMode, isTrue);
        expect(
          state.signOutError,
          contains('previous Firebase session could not be signed out'),
        );
        expect(auth.currentUser, isNotNull);
      },
    );

    test(
      'Demo Mode completes cleanup when credential exchange fails',
      () async {
        auth.credentialGate = Completer<UserCredential>();
        auth.credentialStarted = Completer<void>();
        final google = state.signInWithGoogle();
        await auth.credentialStarted!.future;

        await state.enterDemoMode();
        auth.credentialGate!.completeError(
          FirebaseAuthException(code: 'network-request-failed'),
        );

        expect(await google, isFalse);
        expect(state.isDemoMode, isTrue);
        expect(state.page, 'customerSetup');
        expect(auth.signOutCalls, 0);
      },
    );

    test('phone OTP resend and verification remain available', () async {
      expect(await state.beginAuthentication(), isTrue);
      await state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) {},
      );
      state.lastOtpSentAt = DateTime.now().subtract(
        const Duration(seconds: 61),
      );

      await state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) {},
        isResend: true,
      );
      expect(auth.verifyPhoneNumberCalls, 2);
      expect(auth.lastResendToken, 42);

      await state.verifySmsCode(smsCode: '123456', onError: (_) {});
      expect(auth.credentialCalls, 1);
      expect(state.isPhoneAuthLoading, isFalse);
    });

    test('duplicate OTP requests share one in-flight Firebase request',
        () async {
      auth.phoneVerificationGate = Completer<void>();
      auth.phoneVerificationStarted = Completer<void>();
      final first = state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) {},
      );
      await auth.phoneVerificationStarted!.future;

      await state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) {},
      );
      expect(auth.verifyPhoneNumberCalls, 1);
      expect(state.isPhoneAuthLoading, isTrue);

      auth.phoneVerificationGate!.complete();
      await first;
      expect(state.isPhoneAuthLoading, isFalse);
    });

    test('duplicate SMS verification shares one credential exchange',
        () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final first = state.verifySmsCode(smsCode: '123456', onError: (_) {});
      await auth.credentialStarted!.future;
      await state.verifySmsCode(smsCode: '123456', onError: (_) {});
      expect(auth.credentialCalls, 1);
      expect(auth.maximumActiveCredentialExchanges, 1);

      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      await first;
      expect(state.isPhoneAuthLoading, isFalse);
    });

    test('abandoned phone credential is cleaned before Google can proceed',
        () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      auth.signOutCompleted = Completer<void>();
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final phone = state.verifySmsCode(smsCode: '123456', onError: (_) {});
      await auth.credentialStarted!.future;
      state.go('login');

      final googleStarted = Completer<void>();
      provider.authenticateStarted = googleStarted;
      final google = state.signInWithGoogle();
      expect(provider.authenticateCalls, 0);

      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      auth.credentialGate = null;
      await phone;
      await auth.signOutCompleted!.future;
      await googleStarted.future;
      expect(await google, isTrue);
      expect(auth.signOutCalls, 1);
      expect(auth.credentialCalls, 2);
      expect(auth.maximumActiveCredentialExchanges, 1);
    });

    test('failed abandoned phone credential releases Google safely', () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final phone = state.verifySmsCode(smsCode: '123456', onError: (_) {});
      await auth.credentialStarted!.future;
      state.go('login');

      final googleStarted = Completer<void>();
      provider.authenticateStarted = googleStarted;
      final google = state.signInWithGoogle();
      expect(provider.authenticateCalls, 0);

      auth.credentialGate!.completeError(
        FirebaseAuthException(code: 'invalid-verification-code'),
      );
      auth.credentialGate = null;
      await phone;
      await googleStarted.future;
      expect(await google, isTrue);
      expect(auth.signOutCalls, 0);
      expect(auth.maximumActiveCredentialExchanges, 1);
    });

    test('same-provider retry is rejected while phone cleanup is pending',
        () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      auth.signOutCompleted = Completer<void>();
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final originalPhone = state.verifySmsCode(
        smsCode: '123456',
        onError: (_) {},
      );
      await auth.credentialStarted!.future;
      state.go('login');

      final firstRetry = state.beginAuthentication(method: SignInMethod.phone);
      expect(
        await state.beginAuthentication(method: SignInMethod.phone),
        isFalse,
      );
      expect(auth.credentialCalls, 1);
      expect(auth.maximumActiveCredentialExchanges, 1);

      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      auth.credentialGate = null;
      await originalPhone;
      await auth.signOutCompleted!.future;
      expect(await firstRetry, isTrue);

      await state.verifySmsCode(smsCode: '123456', onError: (_) {});
      expect(auth.credentialCalls, 2);
      expect(auth.maximumActiveCredentialExchanges, 1);
      expect(auth.signOutCalls, 1);
    });

    test('successful abandoned credential with null currentUser is cleaned',
        () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      auth.applyCredentialResultToCurrent = false;
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final originalPhone = state.verifySmsCode(
        smsCode: '123456',
        onError: (_) {},
      );
      await auth.credentialStarted!.future;
      state.go('login');
      final google = state.signInWithGoogle();

      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      auth.credentialGate = null;
      await originalPhone;
      expect(await google, isTrue);
      expect(auth.signOutCalls, 0);
      expect(auth.maximumActiveCredentialExchanges, 1);
    });

    test('unidentified abandoned credential preserves current account',
        () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      auth.applyCredentialResultToCurrent = false;
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final originalPhone = state.verifySmsCode(
        smsCode: '123456',
        onError: (_) {},
      );
      await auth.credentialStarted!.future;
      state.go('login');
      auth.current = _OtherUser();
      final google = state.signInWithGoogle();

      auth.credentialGate!.complete(_CredentialResult(null));
      auth.credentialGate = null;
      await originalPhone;
      expect(await google, isFalse);
      expect(auth.currentUser?.uid, 'other-user-1');
      expect(auth.signOutCalls, 0);
      expect(provider.authenticateCalls, 0);
    });

    test('a newer same-UID phone session starts after cleanup completes',
        () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      auth.signOutCompleted = Completer<void>();
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final originalPhone = state.verifySmsCode(
        smsCode: '123456',
        onError: (_) {},
      );
      await auth.credentialStarted!.future;
      state.go('login');
      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      auth.credentialGate = null;
      await originalPhone;
      await auth.signOutCompleted!.future;

      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);
      await state.verifySmsCode(smsCode: '654321', onError: (_) {});
      expect(auth.currentUser?.uid, 'phone-user-1');
      expect(auth.signOutCalls, 1);
    });

    test('cleanup timeout remains locked until late success is cleaned',
        () async {
      await useImmediateCleanupNotice();
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      auth.signOutCompleted = Completer<void>();
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final originalPhone = state.verifySmsCode(
        smsCode: '123456',
        onError: (_) {},
      );
      await auth.credentialStarted!.future;
      state.go('login');

      final statusShown = Completer<void>();
      void observeStatus() {
        if (state.authenticationCleanupStatus != null &&
            !statusShown.isCompleted) {
          statusShown.complete();
        }
      }

      state.addListener(observeStatus);
      await statusShown.future;
      expect(state.authenticationCleanupStatus, contains('still finishing'));
      expect(state.isAuthenticationCleanupInProgress, isTrue);

      final googleStarted = Completer<void>();
      provider.authenticateStarted = googleStarted;
      final google = state.signInWithGoogle();
      expect(provider.authenticateCalls, 0);
      await state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) {},
      );
      await state.verifySmsCode(smsCode: '123456', onError: (_) {});
      expect(auth.verifyPhoneNumberCalls, 0);
      expect(auth.credentialCalls, 1);

      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      auth.credentialGate = null;
      await originalPhone;
      await auth.signOutCompleted!.future;
      await googleStarted.future;
      expect(await google, isTrue);
      expect(auth.maximumActiveCredentialExchanges, 1);
      expect(state.authenticationCleanupStatus, isNull);
      expect(state.isAuthenticationCleanupInProgress, isFalse);
      state.removeListener(observeStatus);
    });

    test('cleanup timeout followed by late failure releases the lock safely',
        () async {
      await useImmediateCleanupNotice();
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final originalPhone = state.verifySmsCode(
        smsCode: '123456',
        onError: (_) {},
      );
      await auth.credentialStarted!.future;
      state.go('login');
      final statusShown = Completer<void>();
      void observeStatus() {
        if (state.authenticationCleanupStatus != null &&
            !statusShown.isCompleted) {
          statusShown.complete();
        }
      }

      state.addListener(observeStatus);
      await statusShown.future;
      final googleStarted = Completer<void>();
      provider.authenticateStarted = googleStarted;
      final google = state.signInWithGoogle();
      auth.credentialGate!.completeError(
        FirebaseAuthException(code: 'network-request-failed'),
      );
      auth.credentialGate = null;
      await originalPhone;
      await googleStarted.future;
      expect(await google, isTrue);
      expect(auth.signOutCalls, 0);
      expect(auth.maximumActiveCredentialExchanges, 1);
      expect(state.authenticationCleanupStatus, isNull);
      state.removeListener(observeStatus);
    });

    test('cleanup timeout failure remains visible until cleanup retry succeeds',
        () async {
      await useImmediateCleanupNotice();
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      auth.signOutAttempted = Completer<void>();
      auth.clearCurrentUserBeforeSignOutError = true;
      auth.signOutError = StateError('platform sign-out failed');
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final originalPhone = state.verifySmsCode(
        smsCode: '123456',
        onError: (_) {},
      );
      await auth.credentialStarted!.future;
      state.go('login');
      final statusShown = Completer<void>();
      final cleanupFailureShown = Completer<void>();
      void observeStatus() {
        final status = state.authenticationCleanupStatus;
        if (status != null &&
            !statusShown.isCompleted) {
          statusShown.complete();
        }
        if (status != null &&
            status.contains('Retry') &&
            !cleanupFailureShown.isCompleted) {
          cleanupFailureShown.complete();
        }
      }

      state.addListener(observeStatus);
      await statusShown.future;
      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      auth.credentialGate = null;
      await originalPhone;
      await auth.signOutAttempted!.future;
      await cleanupFailureShown.future;
      expect(state.authenticationCleanupStatus, contains('Retry'));
      expect(state.isAuthenticationCleanupRequired, isTrue);

      auth.signOutError = null;
      auth.signOutAttempted = Completer<void>();
      expect(await state.retryAuthenticationCleanup(), isTrue);
      await auth.signOutAttempted!.future;
      expect(state.authenticationCleanupStatus, isNull);
      expect(state.isAuthenticationCleanupRequired, isFalse);
      state.removeListener(observeStatus);
    });

    test('late phone auth-state event cannot replace a newer provider attempt',
        () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final originalPhone = state.verifySmsCode(
        smsCode: '123456',
        onError: (_) {},
      );
      await auth.credentialStarted!.future;
      state.go('login');
      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      auth.credentialGate = null;
      await originalPhone;

      final providerGate = Completer<String?>();
      final providerStarted = Completer<void>();
      provider.authenticateStarted = providerStarted;
      provider.onAuthenticate = () => providerGate.future;
      final google = state.signInWithGoogle();
      await providerStarted.future;
      auth.events.add(_PhoneUser());
      expect(state.page, 'login');
      expect(auth.credentialCalls, 1);

      providerGate.complete('id-token');
      expect(await google, isTrue);
      expect(auth.currentUser?.uid, 'google-user-1');
    });

    test('OTP resend callbacks arriving out of order are ignored', () async {
      await state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) {},
      );
      final oldCodeSent = auth.codeSentCallbacks.first;
      final oldAutoTimeout = auth.autoRetrievalTimeoutCallbacks.first;
      state.lastOtpSentAt = DateTime.now().subtract(
        const Duration(seconds: 61),
      );
      await state.sendPhoneOtp(
        rawPhone: '9876543210',
        isResend: true,
        onSuccessCodeSent: () {},
        onError: (_) {},
      );
      final currentVerificationId = state.verificationId;

      oldCodeSent('stale-verification-id', 7);
      oldAutoTimeout('stale-timeout-id');

      expect(state.verificationId, currentVerificationId);
      expect(state.resendToken, 42);
    });

    test('Demo Mode waits for an existing abandoned phone cleanup', () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      auth.signOutCompleted = Completer<void>();
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final phone = state.verifySmsCode(smsCode: '123456', onError: (_) {});
      await auth.credentialStarted!.future;
      state.go('login');
      final enterDemo = state.enterDemoMode();
      await state.enterDemoMode();
      expect(auth.signOutCalls, 0);

      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      await phone;
      await enterDemo;

      expect(auth.signOutCalls, 1);
      expect(auth.currentUser, isNull);
      expect(state.isDemoMode, isTrue);
      expect(state.page, 'customerSetup');
    });

    test('stale phone auto-verification callback is ignored after leaving',
        () async {
      await state.sendPhoneOtp(
        rawPhone: '9876543210',
        onSuccessCodeSent: () {},
        onError: (_) {},
      );
      final staleCallback = auth.lastPhoneVerificationCompleted!;
      state.go('login');

      staleCallback(_PhoneCredential());
      expect(auth.credentialCalls, 0);
      expect(state.page, 'login');
      expect(auth.currentUser, isNull);
    });

    test('abandoned phone cleanup never signs out a newer user', () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      auth.applyCredentialResultToCurrent = false;
      firestore.profileReadStarted = Completer<void>();
      final newerProfileReady = Completer<void>();
      void observeProfileRoute() {
        if (state.page == 'customerSetup' && !newerProfileReady.isCompleted) {
          newerProfileReady.complete();
        }
      }

      state.addListener(observeProfileRoute);
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final phone = state.verifySmsCode(smsCode: '123456', onError: (_) {});
      await auth.credentialStarted!.future;
      state.go('login');
      final google = state.signInWithGoogle();
      expect(provider.authenticateCalls, 0);
      auth.current = _OtherUser();
      auth.events.add(auth.current);

      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      await phone;
      expect(await google, isFalse);
      await firestore.profileReadStarted!.future;
      await newerProfileReady.future;

      expect(auth.currentUser?.uid, 'other-user-1');
      expect(auth.signOutCalls, 0);
      expect(provider.authenticateCalls, 0);
      expect(state.page, 'customerSetup');
      state.removeListener(observeProfileRoute);
    });

    test('cleanup failure with null currentUser blocks auth until retry',
        () async {
      auth.credentialGate = Completer<UserCredential>();
      auth.credentialStarted = Completer<void>();
      auth.signOutAttempted = Completer<void>();
      auth.clearCurrentUserBeforeSignOutError = true;
      auth.signOutError = StateError('platform sign-out failed');
      state.verificationId = 'controlled-verification-id';
      expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

      final phone = state.verifySmsCode(smsCode: '123456', onError: (_) {});
      await auth.credentialStarted!.future;
      state.go('login');
      final google = state.signInWithGoogle();

      auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
      auth.credentialGate = null;
      await phone;
      await auth.signOutAttempted!.future;
      expect(await google, isFalse);
      expect(auth.currentUser, isNull);
      expect(state.signOutError, isNotNull);
      expect(provider.authenticateCalls, 0);

      auth.signOutError = null;
      auth.signOutAttempted = Completer<void>();
      final retryProviderStarted = Completer<void>();
      provider.authenticateStarted = retryProviderStarted;
      final retry = state.signInWithGoogle();
      await auth.signOutAttempted!.future;
      await retryProviderStarted.future;
      expect(await retry, isTrue);
      expect(auth.signOutCalls, 2);
    });

    test('sign-out failure after clearing currentUser blocks auth until retry',
        () async {
      auth.current = _PhoneUser();
      auth.clearCurrentUserBeforeSignOutError = true;
      auth.signOutError = StateError('platform sign-out failed');
      auth.signOutAttempted = Completer<void>();

      final signOut = state.signOut();
      await auth.signOutAttempted!.future;
      expect(await signOut, isFalse);
      expect(auth.currentUser, isNull);
      expect(state.signOutError, isNotNull);

      auth.signOutError = null;
      auth.signOutAttempted = Completer<void>();
      final providerStarted = Completer<void>();
      provider.authenticateStarted = providerStarted;
      final retry = state.signInWithGoogle();
      await auth.signOutAttempted!.future;
      await providerStarted.future;

      expect(await retry, isTrue);
      expect(auth.signOutCalls, 2);
      expect(auth.credentialCalls, 1);
    });

    test(
      'demo transition invalidates an in-flight Google account result',
      () async {
        final providerStarted = Completer<void>();
        final gate = Completer<String?>();
        provider.authenticateStarted = providerStarted;
        provider.onAuthenticate = () => gate.future;

        final signIn = state.signInWithGoogle();
        await providerStarted.future;
        await state.enterDemoMode();
        gate.complete('late-id-token');

        expect(await signIn, isFalse);
        expect(auth.credentialCalls, 0);
        expect(state.isDemoMode, isTrue);
        expect(state.page, 'customerSetup');
      },
    );
  });

  testWidgets('login button shows progress and blocks repeated taps', (
    tester,
  ) async {
    final auth = _Auth();
    final provider = _GoogleProvider();
    final firestore = _Firestore();
    final state = AppState(auth: auth, googleSignInService: provider)
      ..firestoreService = firestore;
    final gate = Completer<String?>();
    provider.onAuthenticate = () => gate.future;

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => LoginScreen(state: state),
        ),
      ),
    );
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Signing in with Google…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Signing in with Google…'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
    final phoneButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue with Phone Number'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(phoneButton.onPressed, isNull);
    expect(find.text('Skip sign-in and explore demo'), findsOneWidget);
    expect(provider.authenticateCalls, 1);

    gate.complete('id-token');
    await tester.pumpAndSettle();
    state.dispose();
    await auth.events.close();
  });

  testWidgets('phone button is disabled during abandoned credential cleanup', (
    tester,
  ) async {
    final auth = _Auth();
    final provider = _GoogleProvider();
    final firestore = _Firestore();
    final state = AppState(
      auth: auth,
      googleSignInService: provider,
      phoneCredentialCleanupNoticeAfter: Duration.zero,
    )..firestoreService = firestore;
    auth.credentialGate = Completer<UserCredential>();
    auth.credentialStarted = Completer<void>();
    auth.signOutCompleted = Completer<void>();
    state.verificationId = 'controlled-verification-id';
    expect(await state.beginAuthentication(method: SignInMethod.phone), isTrue);

    final originalPhone = state.verifySmsCode(
      smsCode: '123456',
      onError: (_) {},
    );
    await auth.credentialStarted!.future;
    state.go('login');
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => LoginScreen(state: state),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    final phoneButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continue with Phone Number'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(phoneButton.onPressed, isNull);
    expect(find.textContaining('still finishing'), findsOneWidget);

    auth.credentialGate!.complete(_CredentialResult(_PhoneUser()));
    auth.credentialGate = null;
    await originalPhone;
    await auth.signOutCompleted!.future;
    state.dispose();
    await auth.events.close();
  });
}
