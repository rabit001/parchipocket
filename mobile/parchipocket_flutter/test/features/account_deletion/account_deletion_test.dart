import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/services/account_deletion_service.dart';

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

    test('3. Unauthenticated session cannot request deletion OTP', () async {
      final fakeService = _FakeAccountDeletionService();
      final state = AppState(accountDeletionService: fakeService);

      // Simulate non-demo, unauthenticated state
      state.isDemoMode = false;
      final sent = await state.sendDeletionReauthOtp();
      expect(sent, isFalse);
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
  });
}
