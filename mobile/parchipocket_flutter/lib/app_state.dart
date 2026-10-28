import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'services/firestore_service.dart';

enum UserRole { customer, shopOwner, streetVendor }

enum CloudProfileStatus { unknown, loading, loaded, missing, failed }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.customer => 'Customer',
        UserRole.shopOwner => 'Shop Owner',
        UserRole.streetVendor => 'Street Vendor',
      };
}

class BillLine {
  BillLine(
      {required this.name, required this.quantity, required this.unitPrice});

  final String name;
  final int quantity;
  final double unitPrice;
  double get total => quantity * unitPrice;
}

class DemoBill {
  DemoBill({
    required this.id,
    required this.store,
    required this.items,
    required this.createdAt,
    required this.paymentMode,
    this.customerPhone = '',
    this.isUdhaar = false,
    this.isSettled = false,
    this.isSaved = true,
  });

  final String id;
  final String store;
  final List<BillLine> items;
  final DateTime createdAt;
  final String paymentMode;
  final String customerPhone;
  bool isUdhaar;
  bool isSettled;
  bool isSaved;
  String get displayNumber {
    if (id.startsWith('PP-')) return id;
    return 'PP-$id';
  }

  double get total => items.fold<double>(0, (sum, item) => sum + item.total);
}

/// A deliberately minimized, read-only copy of a bill claimed by this user.
class ClaimedReceipt {
  const ClaimedReceipt({
    required this.ownerUid,
    required this.sourceBillId,
    required this.bill,
    required this.claimedAt,
  });

  final String ownerUid;
  final String sourceBillId;
  final DemoBill bill;
  final DateTime claimedAt;
}

class DemoExpense {
  DemoExpense({
    this.id = '',
    required this.title,
    required this.category,
    required this.amount,
    required this.createdAt,
  });

  /// Stable Firestore document ID for cloud writes; empty for local demo rows.
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime createdAt;
}

class AppState extends ChangeNotifier {
  AppState({FirebaseAuth? auth}) : _auth = auth {
    _restoreDemoState();
    _initAuthListener();
  }

  FirebaseAuth? _auth;
  FirebaseAuth? get auth {
    if (_auth != null) return _auth;
    try {
      if (Firebase.apps.isNotEmpty) {
        _auth = FirebaseAuth.instance;
        return _auth;
      }
    } catch (_) {}
    return _auth;
  }

  set auth(FirebaseAuth? instance) => _auth = instance;

  bool get isAuthenticated => auth?.currentUser != null;

  FirestoreService? _firestoreService;
  FirestoreService get firestoreService =>
      _firestoreService ??= FirestoreService(auth: auth);
  set firestoreService(FirestoreService service) => _firestoreService = service;

  String verificationId = '';
  int? resendToken;
  String phoneNumber = '';
  bool isPhoneAuthLoading = false;
  String? phoneAuthError;
  DateTime? lastOtpSentAt;

  int get otpCooldownSecondsRemaining {
    if (lastOtpSentAt == null) return 0;
    final elapsed = DateTime.now().difference(lastOtpSentAt!).inSeconds;
    const cooldown = 60;
    return (cooldown - elapsed).clamp(0, cooldown);
  }

  bool isDemoMode = true;
  bool _explicitDemoSession = false;
  bool _authenticationIntentActive = false;
  bool isCloudLoading = false;
  bool isSigningOut = false;
  bool hasExistingCloudProfile = false;
  CloudProfileStatus profileStatus = CloudProfileStatus.unknown;
  String? cloudError;
  String? signOutError;

  StreamSubscription<User?>? _authSubscription;
  int _authEventGeneration = 0;
  int _profileLoadGeneration = 0;
  int _sessionGeneration = 0;
  Future<bool>? _demoSignOutTask;
  Future<UserCredential>? _pendingCredentialSignIn;
  bool _disposed = false;

  String page = 'splash';
  UserRole role = UserRole.customer;
  String customerName = 'Rabit Mansuri';
  String customerEmail = '';
  String city = 'Ujjain, Madhya Pradesh';
  String shopName = 'Mansuri General Store';
  String shopCategory = 'Kirana';
  String shopAddress = 'Ujjain, Madhya Pradesh';
  String vendorName = 'Raju Tea Stall';
  String vendorCategory = 'Tea / Snacks';
  DemoBill? selectedBill;
  ClaimedReceipt? selectedClaimedReceipt;
  String supportReference = 'PP-SUP-1042';
  String lastNotice = '';
  String language = 'English';
  bool notificationsEnabled = true;
  bool spendingSummaryEnabled = true;
  bool productUpdatesEnabled = false;

  final List<DemoBill> bills = <DemoBill>[];
  final List<ClaimedReceipt> claimedReceipts = <ClaimedReceipt>[];
  final List<DemoExpense> expenses = <DemoExpense>[];
  final Set<String> savedShops = <String>{};
  int _billSequence = 10500;
  int _vendorBillSequence = 2403;
  DemoBill? _retryableCloudBill;
  DemoExpense? _retryableCloudExpense;

  void _initAuthListener() {
    final authInstance = auth;
    if (authInstance == null) return;

    page = 'authLoading';
    _authSubscription = authInstance.authStateChanges().listen(
      (user) => unawaited(_handleAuthStateChanged(user)),
      onError: (Object error) {
        if (_disposed || isSigningOut || _explicitDemoSession) return;
        isCloudLoading = false;
        profileStatus = CloudProfileStatus.failed;
        cloudError =
            'Unable to check your sign-in session. Check your connection and retry.';
        page = 'profileLoadError';
        notifyListeners();
      },
    );
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    final eventGeneration = ++_authEventGeneration;
    _profileLoadGeneration++;
    if (_disposed || isSigningOut) return;
    if (_explicitDemoSession) return;

    if (user == null) {
      if (_authenticationIntentActive) return;
      _restoreDemoState();
      page = 'splash';
      notifyListeners();
      return;
    }
    if (auth?.currentUser?.uid != user.uid) return;

    _authenticationIntentActive = false;
    _clearCloudAccountState();
    isDemoMode = false;
    isCloudLoading = true;
    profileStatus = CloudProfileStatus.loading;
    page = 'authLoading';
    notifyListeners();

    await loadUserDataFromCloud(
      expectedUid: user.uid,
      expectedAuthGeneration: eventGeneration,
    );
    if (!_isCurrentAuthEvent(eventGeneration, user.uid)) return;
    navigateAfterAuth();
  }

  bool _isCurrentAuthEvent(int generation, String uid) =>
      !_disposed &&
      !isSigningOut &&
      !isDemoMode &&
      !_explicitDemoSession &&
      _authEventGeneration == generation &&
      auth?.currentUser?.uid == uid;

  Future<CloudProfileStatus> loadUserDataFromCloud({
    String? expectedUid,
    int? expectedAuthGeneration,
  }) async {
    if (isDemoMode || _explicitDemoSession) {
      return CloudProfileStatus.unknown;
    }
    final user = auth?.currentUser;
    if (user == null) {
      profileStatus = CloudProfileStatus.failed;
      cloudError = 'You are signed out. Sign in again to load your account.';
      return profileStatus;
    }

    final uid = expectedUid ?? user.uid;
    final loadGeneration = ++_profileLoadGeneration;
    bool isCurrentLoad() =>
        !_disposed &&
        !isSigningOut &&
        !isDemoMode &&
        !_explicitDemoSession &&
        _profileLoadGeneration == loadGeneration &&
        auth?.currentUser?.uid == uid &&
        (expectedAuthGeneration == null ||
            _authEventGeneration == expectedAuthGeneration);

    isCloudLoading = true;
    isDemoMode = false;
    profileStatus = CloudProfileStatus.loading;
    cloudError = null;
    notifyListeners();

    CloudProfileStatus result;
    try {
      final profile = await firestoreService.loadUserProfile();
      if (!isCurrentLoad()) return CloudProfileStatus.unknown;

      if (profile != null) {
        final roleValue = profile['role'];
        if (roleValue is! String ||
            !UserRole.values.any((candidate) => candidate.name == roleValue)) {
          throw const FormatException(
              'The saved account role is missing or invalid.');
        }

        final loadedName = profile['name'];
        if (loadedName is! String || loadedName.trim().isEmpty) {
          throw const FormatException(
              'The saved account profile is missing a valid name.');
        }

        hasExistingCloudProfile = true;
        role = UserRole.values
            .firstWhere((candidate) => candidate.name == roleValue);
        customerName = loadedName;
        customerEmail = profile['email'] as String? ?? customerEmail;
        city = profile['city'] as String? ?? city;
        shopName = profile['shopName'] as String? ?? shopName;
        shopCategory = profile['shopCategory'] as String? ?? shopCategory;
        shopAddress = profile['shopAddress'] as String? ?? shopAddress;
        vendorName = profile['vendorName'] as String? ?? vendorName;
        vendorCategory = profile['vendorCategory'] as String? ?? vendorCategory;
        profileStatus = CloudProfileStatus.loaded;
        result = profileStatus;
      } else {
        hasExistingCloudProfile = false;
        profileStatus = CloudProfileStatus.missing;
        result = profileStatus;
      }
    } catch (e) {
      if (!isCurrentLoad()) return CloudProfileStatus.unknown;
      hasExistingCloudProfile = false;
      profileStatus = CloudProfileStatus.failed;
      cloudError = e is FormatException
          ? e.message
          : 'Could not read your account profile. Check your connection and try again. ($e)';
      isCloudLoading = false;
      notifyListeners();
      return profileStatus;
    }

    try {
      // Stage all reads first. If one collection fails, do not apply only a
      // subset of cloud data alongside demo or stale records.
      final cloudBills = await firestoreService.loadBills();
      if (!isCurrentLoad()) return CloudProfileStatus.unknown;
      final cloudExpenses = await firestoreService.loadExpenses();
      if (!isCurrentLoad()) return CloudProfileStatus.unknown;
      final cloudSavedShops = await firestoreService.loadSavedShops();
      if (!isCurrentLoad()) return CloudProfileStatus.unknown;
      final cloudClaims = await firestoreService.loadClaimedReceipts();
      if (!isCurrentLoad()) return CloudProfileStatus.unknown;

      bills
        ..clear()
        ..addAll(cloudBills);
      claimedReceipts
        ..clear()
        ..addAll(cloudClaims);
      expenses
        ..clear()
        ..addAll(cloudExpenses);
      savedShops
        ..clear()
        ..addAll(cloudSavedShops);
    } catch (e) {
      if (!isCurrentLoad()) return CloudProfileStatus.unknown;
      cloudError =
          'Your profile loaded, but some saved data could not be loaded. ($e)';
    } finally {
      if (isCurrentLoad()) {
        isCloudLoading = false;
        notifyListeners();
      }
    }

    return result;
  }

  void navigateAfterAuth() {
    if (isDemoMode || _explicitDemoSession) return;
    switch (profileStatus) {
      case CloudProfileStatus.loaded:
        if (!hasExistingCloudProfile) {
          page = 'profileLoadError';
          cloudError =
              'Your saved profile could not be verified. Retry before continuing.';
          break;
        }
        page = switch (role) {
          UserRole.customer => 'customerHome',
          UserRole.shopOwner => 'shopHome',
          UserRole.streetVendor => 'vendorHome',
        };
      case CloudProfileStatus.missing:
        page = 'roleSelection';
      case CloudProfileStatus.failed:
        page = 'profileLoadError';
      case CloudProfileStatus.loading:
      case CloudProfileStatus.unknown:
        page = 'authLoading';
    }
    notifyListeners();
  }

  Future<void> retryProfileLoad() async {
    if (isDemoMode || _explicitDemoSession) return;
    final user = auth?.currentUser;
    if (user == null) {
      profileStatus = CloudProfileStatus.failed;
      cloudError = 'You are signed out. Sign in again to load your account.';
      page = 'login';
      notifyListeners();
      return;
    }
    await _handleAuthStateChanged(user);
  }

  /// Starts an explicit, local-only demo session before any asynchronous auth
  /// sign-out or listener callback can run. Old auth/profile work is invalidated
  /// and its results cannot replace demo state.
  Future<void> enterDemoMode({String landingPage = 'roleSelection'}) async {
    _sessionGeneration++;
    _authEventGeneration++;
    _profileLoadGeneration++;
    _authenticationIntentActive = false;
    _explicitDemoSession = true;
    isSigningOut = false;
    _restoreDemoState();
    page = landingPage;
    notifyListeners();

    final authInstance = auth;
    if (authInstance?.currentUser == null) return;

    final task = _finishDemoSignOut(authInstance!);
    _demoSignOutTask = task;
    try {
      final signedOut = await task;
      if (!signedOut && !_disposed && _explicitDemoSession) {
        signOutError =
            'Demo mode is active, but the previous Firebase session could not be signed out.';
        notifyListeners();
      }
    } finally {
      if (identical(_demoSignOutTask, task)) _demoSignOutTask = null;
    }
  }

  Future<bool> _finishDemoSignOut(FirebaseAuth authInstance) async {
    final pendingSignIn = _pendingCredentialSignIn;
    if (pendingSignIn != null) {
      try {
        await pendingSignIn;
      } catch (_) {
        // Sign-out below also cleans up a credential operation that completed
        // successfully after demo mode was selected.
      }
    }
    if (authInstance.currentUser == null) return true;
    try {
      await authInstance.signOut();
      return authInstance.currentUser == null;
    } catch (_) {
      return false;
    }
  }

  /// Leaves demo mode only for an explicit sign-in action. A stale session is
  /// signed out first; if that fails, sign-in is blocked and demo remains local.
  Future<bool> beginAuthentication() async {
    if (_disposed) return false;
    if (_authenticationIntentActive && !isDemoMode && !_explicitDemoSession) {
      return true;
    }

    final session = ++_sessionGeneration;
    final pendingDemoSignOut = _demoSignOutTask;
    if (pendingDemoSignOut != null) {
      final signedOut = await pendingDemoSignOut;
      if (session != _sessionGeneration) return false;
      if (!signedOut && auth?.currentUser != null) {
        signOutError = 'Could not close the previous session. Retry sign-in.';
        notifyListeners();
        return false;
      }
    }

    final authInstance = auth;
    if (_explicitDemoSession && authInstance?.currentUser != null) {
      final signedOut = await _finishDemoSignOut(authInstance!);
      if (session != _sessionGeneration) return false;
      if (!signedOut) {
        signOutError = 'Could not close the previous session. Retry sign-in.';
        notifyListeners();
        return false;
      }
    }

    if (session != _sessionGeneration) return false;
    _explicitDemoSession = false;
    _authenticationIntentActive = true;
    _authEventGeneration++;
    _profileLoadGeneration++;
    _clearCloudAccountState();
    isDemoMode = false;
    profileStatus = CloudProfileStatus.unknown;
    isCloudLoading = false;
    cloudError = null;
    signOutError = null;
    notifyListeners();
    return true;
  }

  Future<bool> signOut() async {
    if (isSigningOut) return false;
    if (isCloudLoading) {
      signOutError =
          'Please wait for the current account update to finish, then try logging out again.';
      notifyListeners();
      return false;
    }

    isSigningOut = true;
    signOutError = null;
    final eventGeneration = ++_authEventGeneration;
    _profileLoadGeneration++;
    notifyListeners();

    try {
      final authInstance = auth;
      if (authInstance != null && authInstance.currentUser != null) {
        await authInstance.signOut();
      }
      if (_disposed || _authEventGeneration != eventGeneration) return true;
      _restoreDemoState();
      page = 'splash';
      return true;
    } catch (e) {
      if (_disposed || _authEventGeneration != eventGeneration) return false;
      signOutError =
          'Could not sign out. Check your connection and try again. ($e)';
      return false;
    } finally {
      if (_authEventGeneration == eventGeneration) {
        isSigningOut = false;
        notifyListeners();
      }
    }
  }

  void _clearCloudAccountState() {
    _retryableCloudBill = null;
    _retryableCloudExpense = null;
    hasExistingCloudProfile = false;
    profileStatus = CloudProfileStatus.loading;
    customerName = '';
    customerEmail = '';
    city = '';
    shopName = '';
    shopCategory = '';
    shopAddress = '';
    vendorName = '';
    vendorCategory = '';
    bills.clear();
    claimedReceipts.clear();
    expenses.clear();
    savedShops.clear();
    selectedBill = null;
    selectedClaimedReceipt = null;
  }

  bool _isCurrentAuthenticatedSession(String uid, int generation) =>
      !_disposed &&
      !isSigningOut &&
      !isDemoMode &&
      !_explicitDemoSession &&
      generation == _authEventGeneration &&
      auth?.currentUser?.uid == uid;

  void _restoreDemoState() {
    _retryableCloudBill = null;
    _retryableCloudExpense = null;
    isDemoMode = true;
    isCloudLoading = false;
    hasExistingCloudProfile = false;
    profileStatus = CloudProfileStatus.unknown;
    cloudError = null;
    signOutError = null;
    role = UserRole.customer;
    customerName = 'Rabit Mansuri';
    customerEmail = '';
    city = 'Ujjain, Madhya Pradesh';
    shopName = 'Mansuri General Store';
    shopCategory = 'Kirana';
    shopAddress = 'Ujjain, Madhya Pradesh';
    vendorName = 'Raju Tea Stall';
    vendorCategory = 'Tea / Snacks';
    verificationId = '';
    resendToken = null;
    phoneNumber = '';
    isPhoneAuthLoading = false;
    phoneAuthError = null;
    lastOtpSentAt = null;
    selectedBill = null;
    selectedClaimedReceipt = null;
    claimedReceipts.clear();
    lastNotice = '';
    supportReference = 'PP-SUP-1042';
    language = 'English';
    notificationsEnabled = true;
    spendingSummaryEnabled = true;
    productUpdatesEnabled = false;
    _billSequence = 10500;
    _vendorBillSequence = 2403;
    bills
      ..clear()
      ..addAll(_demoBills());
    expenses
      ..clear()
      ..addAll(<DemoExpense>[
        DemoExpense(
            title: 'Stock purchase',
            category: 'Stock',
            amount: 300,
            createdAt: DateTime(2026, 10, 19, 10, 30)),
        DemoExpense(
            title: 'Transport',
            category: 'Transport',
            amount: 150,
            createdAt: DateTime(2026, 10, 19, 9, 20)),
      ]);
    savedShops
      ..clear()
      ..addAll(
          <String>{'Sharma Kirana Store', 'Gupta General Store', 'Fresh Mart'});
  }

  List<DemoBill> _demoBills() => <DemoBill>[
        DemoBill(
            id: 'PP-10482',
            store: 'Sharma Kirana Store',
            items: <BillLine>[
              BillLine(name: 'Maggi', quantity: 1, unitPrice: 40),
              BillLine(name: 'Bread', quantity: 1, unitPrice: 30),
              BillLine(name: 'Milk', quantity: 1, unitPrice: 50),
              BillLine(name: 'Chips', quantity: 1, unitPrice: 60),
            ],
            createdAt: DateTime(2026, 10, 12, 17, 24),
            paymentMode: 'Cash',
            isSaved: true),
        DemoBill(
            id: 'PP-10481',
            store: 'Gupta General Store',
            items: <BillLine>[
              BillLine(name: 'Household items', quantity: 1, unitPrice: 240),
            ],
            createdAt: DateTime(2026, 10, 10, 11, 8),
            paymentMode: 'UPI',
            isSaved: true),
        DemoBill(
            id: 'PP-10480',
            store: 'Fresh Mart',
            items: <BillLine>[
              BillLine(name: 'Groceries', quantity: 1, unitPrice: 320),
            ],
            createdAt: DateTime(2026, 10, 8, 18, 42),
            paymentMode: 'UPI',
            isSaved: true),
        DemoBill(
            id: 'PP-10470',
            store: 'Mansuri General Store',
            items: <BillLine>[
              BillLine(name: 'Grocery order', quantity: 1, unitPrice: 450),
            ],
            createdAt: DateTime(2026, 10, 12, 12),
            paymentMode: 'Udhaar',
            customerPhone: '•••• 4421',
            isUdhaar: true,
            isSettled: false,
            isSaved: false),
        DemoBill(
            id: 'PP-10462',
            store: 'Mansuri General Store',
            items: <BillLine>[
              BillLine(name: 'Walk-in purchase', quantity: 1, unitPrice: 300),
            ],
            createdAt: DateTime(2026, 10, 11, 16),
            paymentMode: 'Udhaar',
            isUdhaar: true,
            isSettled: false,
            isSaved: false),
        DemoBill(
            id: 'PP-10455',
            store: 'Mansuri General Store',
            items: <BillLine>[
              BillLine(name: 'Household order', quantity: 1, unitPrice: 650),
            ],
            createdAt: DateTime(2026, 10, 10, 10),
            paymentMode: 'Udhaar',
            customerPhone: '•••• 1184',
            isUdhaar: true,
            isSettled: false,
            isSaved: false),
      ];

  @override
  void dispose() {
    _disposed = true;
    _authEventGeneration++;
    _profileLoadGeneration++;
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  void go(String nextPage) {
    page = nextPage;
    notifyListeners();
  }

  void setRole(UserRole value) {
    if (!isDemoMode && profileStatus != CloudProfileStatus.missing) {
      // Existing cloud profiles retain their stored role to satisfy Firestore security rules
      if (profileStatus == CloudProfileStatus.loaded &&
          hasExistingCloudProfile) {
        page = switch (role) {
          UserRole.customer => 'customerSetup',
          UserRole.shopOwner => 'shopSetup',
          UserRole.streetVendor => 'vendorSetup',
        };
        lastNotice =
            'Role is locked for existing cloud profile (${role.label}).';
      } else if (profileStatus == CloudProfileStatus.failed) {
        page = 'profileLoadError';
      } else {
        page = 'authLoading';
      }
      notifyListeners();
      return;
    }

    role = value;
    page = switch (value) {
      UserRole.customer => 'customerSetup',
      UserRole.shopOwner => 'shopSetup',
      UserRole.streetVendor => 'vendorSetup',
    };
    notifyListeners();
  }

  String get activeStoreName =>
      role == UserRole.streetVendor ? vendorName : shopName;

  List<DemoBill> get customerBills =>
      bills.where((bill) => bill.isSaved).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<DemoBill> get shopBills => bills
      .where((bill) => bill.store == shopName || bill.store == vendorName)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<DemoBill> get udhaarBills =>
      bills.where((bill) => bill.isUdhaar && !bill.isSettled).toList();

  double get recordedSales => shopBills
      .where((b) => !b.isUdhaar)
      .fold<double>(0, (sum, bill) => sum + bill.total);
  double get expensesTotal =>
      expenses.fold<double>(0, (sum, item) => sum + item.amount);
  double get outstandingTotal =>
      udhaarBills.fold<double>(0, (sum, bill) => sum + bill.total);

  void openBill(DemoBill bill) {
    selectedClaimedReceipt = null;
    selectedBill = bill;
    page = 'billDetail';
    notifyListeners();
  }

  void openClaimedReceipt(ClaimedReceipt receipt) {
    selectedBill = null;
    selectedClaimedReceipt = receipt;
    page = 'billDetail';
    notifyListeners();
  }

  String newReceiptClaimCode() => firestoreService.newReceiptClaimCode();

  Future<void> issueReceiptClaim(DemoBill bill, String rawCode) async {
    if (isDemoMode || !isAuthenticated) {
      throw StateError(
          'Sign in with a shop-owner or vendor account to issue a receipt code.');
    }
    if (isCloudLoading || isSigningOut) {
      throw StateError(
          'Another account operation is still in progress. Please wait.');
    }
    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;
    try {
      await firestoreService.createReceiptClaim(bill, rawCode: rawCode);
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        lastNotice = 'Receipt claim code is ready. It expires within 24 hours.';
      }
    } catch (error) {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        cloudError = error.toString();
      }
      rethrow;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  Future<ClaimedReceipt> claimReceipt(String rawCode) async {
    if (isDemoMode || !isAuthenticated) {
      throw StateError('Sign in with a customer account to claim a receipt.');
    }
    if (isCloudLoading || isSigningOut) {
      throw StateError(
          'Another account operation is still in progress. Please wait.');
    }
    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;
    try {
      final receipt = await firestoreService.claimReceipt(rawCode);
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        throw StateError(
            'Your sign-in session changed while claiming a receipt.');
      }
      claimedReceipts.removeWhere((entry) =>
          entry.ownerUid == receipt.ownerUid &&
          entry.sourceBillId == receipt.sourceBillId);
      claimedReceipts.insert(0, receipt);
      lastNotice = 'Receipt added to your account.';
      return receipt;
    } catch (error) {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        cloudError = error.toString();
      }
      rethrow;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  Future<DemoBill> createBill({
    required List<BillLine> items,
    required String paymentMode,
    String customerPhone = '',
    required bool vendorMode,
  }) async {
    if (isCloudLoading || isSigningOut) {
      throw StateError(
          'Another account operation is still in progress. Please wait.');
    }
    if (items.isEmpty) {
      throw Exception('A bill must contain at least 1 item.');
    }
    if (items.length > 10) {
      const err = 'Maximum 10 items allowed per bill.';
      lastNotice = err;
      notifyListeners();
      throw Exception(err);
    }

    final cloudBill = !isDemoMode && isAuthenticated;
    final store = vendorMode ? vendorName : shopName;
    final normalizedPhone = customerPhone.trim();
    DemoBill bill;
    if (cloudBill &&
        _matchesRetryableBill(
          store: store,
          items: items,
          paymentMode: paymentMode,
          customerPhone: normalizedPhone,
        )) {
      bill = _retryableCloudBill!;
    } else {
      bill = DemoBill(
        id: cloudBill
            ? firestoreService.newBillId()
            : vendorMode
                ? 'PP-${_vendorBillSequence++}'
                : 'PP-${_billSequence++}',
        store: store,
        items: List<BillLine>.from(items),
        createdAt: DateTime.now(),
        paymentMode: paymentMode,
        customerPhone: normalizedPhone,
        isUdhaar: paymentMode == 'Udhaar',
        isSettled: false,
        isSaved: false,
      );
      if (cloudBill) _retryableCloudBill = bill;
    }

    if (!cloudBill) {
      bills.insert(0, bill);
      selectedBill = bill;
      page = vendorMode ? 'vendorReceipt' : 'receipt';
      lastNotice = 'Bill created (demo).';
      notifyListeners();
      return bill;
    }

    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;

    try {
      await firestoreService.createBill(bill);
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        throw StateError(
            'Your sign-in session changed before the bill was saved.');
      }
      bills.insert(0, bill);
      if (identical(_retryableCloudBill, bill)) _retryableCloudBill = null;
      selectedBill = bill;
      page = vendorMode ? 'vendorReceipt' : 'receipt';
      lastNotice = 'Bill created successfully.';
      cloudError = null;
      return bill;
    } catch (e) {
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        rethrow;
      }
      if (e is BillIdCollisionException &&
          identical(_retryableCloudBill, bill)) {
        _retryableCloudBill = null;
      }
      cloudError = e.toString();
      lastNotice = 'Failed to save bill to cloud: $e';
      rethrow;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  bool _matchesRetryableBill({
    required String store,
    required List<BillLine> items,
    required String paymentMode,
    required String customerPhone,
  }) {
    final pending = _retryableCloudBill;
    if (pending == null ||
        pending.store != store ||
        pending.paymentMode != paymentMode ||
        pending.customerPhone != customerPhone ||
        pending.isUdhaar != (paymentMode == 'Udhaar') ||
        pending.items.length != items.length) {
      return false;
    }
    for (var index = 0; index < items.length; index++) {
      final existing = pending.items[index];
      final candidate = items[index];
      if (existing.name != candidate.name ||
          existing.quantity != candidate.quantity ||
          existing.unitPrice != candidate.unitPrice) {
        return false;
      }
    }
    return true;
  }

  Future<bool> saveSelectedBill() async {
    if (selectedBill == null) return false;
    if (isCloudLoading || isSigningOut) return false;

    if (isDemoMode || !isAuthenticated) {
      selectedBill!.isSaved = true;
      lastNotice = 'Receipt saved (demo).';
      cloudError = null;
      notifyListeners();
      return true;
    }

    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;

    final updatedBill = DemoBill(
      id: selectedBill!.id,
      store: selectedBill!.store,
      items: selectedBill!.items,
      createdAt: selectedBill!.createdAt,
      paymentMode: selectedBill!.paymentMode,
      customerPhone: selectedBill!.customerPhone,
      isUdhaar: selectedBill!.isUdhaar,
      isSettled: selectedBill!.isSettled,
      isSaved: true,
    );

    try {
      await firestoreService.saveBill(updatedBill);
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      selectedBill!.isSaved = true;
      lastNotice = 'Receipt saved to cloud.';
      cloudError = null;
      return true;
    } catch (e) {
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      cloudError = e.toString();
      lastNotice = 'Failed to save receipt to cloud: $e';
      return false;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> markSettled(DemoBill bill) async {
    if (isCloudLoading || isSigningOut) return false;
    if (isDemoMode || !isAuthenticated) {
      bill.isSettled = true;
      lastNotice = '${bill.id} settled (demo).';
      cloudError = null;
      notifyListeners();
      return true;
    }

    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;

    final updatedBill = DemoBill(
      id: bill.id,
      store: bill.store,
      items: bill.items,
      createdAt: bill.createdAt,
      paymentMode: bill.paymentMode,
      customerPhone: bill.customerPhone,
      isUdhaar: bill.isUdhaar,
      isSettled: true,
      isSaved: bill.isSaved,
    );

    try {
      await firestoreService.saveBill(updatedBill);
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      bill.isSettled = true;
      lastNotice = '${bill.id} marked as settled.';
      cloudError = null;
      return true;
    } catch (e) {
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      cloudError = e.toString();
      lastNotice = 'Failed to update settlement: $e';
      return false;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> addExpense({
    required String title,
    required String category,
    required double amount,
  }) async {
    if (isCloudLoading || isSigningOut) return false;

    final normalizedTitle =
        title.trim().isEmpty ? 'Other expense' : title.trim();
    final cloudWrite = !isDemoMode && isAuthenticated;
    final pending = _retryableCloudExpense;
    final isRetry = cloudWrite &&
        pending != null &&
        pending.title == normalizedTitle &&
        pending.category == category &&
        pending.amount == amount;

    final DemoExpense expense;
    if (isRetry) {
      expense = pending;
    } else {
      expense = DemoExpense(
        id: cloudWrite ? firestoreService.newExpenseId() : '',
        title: normalizedTitle,
        category: category,
        amount: amount,
        createdAt: DateTime.now(),
      );
      if (cloudWrite) _retryableCloudExpense = expense;
    }

    if (!cloudWrite) {
      expenses.insert(0, expense);
      lastNotice = 'Expense recorded (demo).';
      page = 'expenseSaved';
      cloudError = null;
      notifyListeners();
      return true;
    }

    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;

    try {
      await firestoreService.addExpense(expense);
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      expenses.insert(0, expense);
      if (identical(_retryableCloudExpense, expense)) {
        _retryableCloudExpense = null;
      }
      lastNotice = 'Expense saved to cloud.';
      page = 'expenseSaved';
      cloudError = null;
      return true;
    } catch (e) {
      // A write from the previous account/session must not surface an error
      // into a demo session or a newly authenticated account.
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      // Keep the same expense ID for an identical retry after an ambiguous
      // acknowledgement, preventing duplicate ledger entries.
      cloudError = e.toString();
      lastNotice = 'Failed to record expense: $e';
      return false;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> toggleSavedShop(String name) async {
    if (isCloudLoading || isSigningOut) return false;
    final isCurrentlySaved = savedShops.contains(name);

    if (isDemoMode || !isAuthenticated) {
      if (isCurrentlySaved) {
        savedShops.remove(name);
        lastNotice = 'Removed from saved shops.';
      } else {
        savedShops.add(name);
        lastNotice = 'Shop saved.';
      }
      cloudError = null;
      notifyListeners();
      return true;
    }

    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;

    try {
      if (isCurrentlySaved) {
        await firestoreService.removeSavedShop(name);
        if (uid == null ||
            !_isCurrentAuthenticatedSession(uid, authGeneration)) {
          return false;
        }
        savedShops.remove(name);
        lastNotice = 'Removed from saved shops.';
      } else {
        await firestoreService.saveShop(name);
        if (uid == null ||
            !_isCurrentAuthenticatedSession(uid, authGeneration)) {
          return false;
        }
        savedShops.add(name);
        lastNotice = 'Shop saved.';
      }
      cloudError = null;
      return true;
    } catch (e) {
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      cloudError = e.toString();
      lastNotice = 'Failed to update saved shop: $e';
      return false;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  void submitSupport() {
    supportReference =
        'PP-SUP-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    page = 'supportSubmitted';
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String location,
    String? successPage = 'customerProfile',
  }) async {
    if (isCloudLoading || isSigningOut) return false;
    final newName = name.trim().isEmpty ? customerName : name.trim();
    final newEmail = email.trim();
    final newCity = location.trim().isEmpty ? city : location.trim();

    if (isDemoMode || !isAuthenticated) {
      customerName = newName;
      customerEmail = newEmail;
      city = newCity;
      lastNotice = 'Profile updated (demo).';
      if (successPage != null) page = successPage;
      cloudError = null;
      notifyListeners();
      return true;
    }

    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;

    try {
      await firestoreService.saveUserProfile(
        role: role,
        name: newName,
        email: newEmail,
        city: newCity,
        shopName: shopName,
        shopCategory: shopCategory,
        shopAddress: shopAddress,
        vendorName: vendorName,
        vendorCategory: vendorCategory,
      );
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      customerName = newName;
      customerEmail = newEmail;
      city = newCity;
      hasExistingCloudProfile = true;
      profileStatus = CloudProfileStatus.loaded;
      lastNotice = 'Profile updated in cloud.';
      if (successPage != null) page = successPage;
      cloudError = null;
      return true;
    } catch (e) {
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      cloudError = e.toString();
      lastNotice = 'Failed to update profile: $e';
      return false;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateShop(
      {required String ownerName,
      required String name,
      required String category,
      required String address}) async {
    if (isCloudLoading || isSigningOut) return false;
    final newOwnerName = ownerName.trim();
    if (newOwnerName.isEmpty) {
      cloudError = 'Enter the owner/contact full name before saving the shop profile.';
      notifyListeners();
      return false;
    }
    final newShopName = name.trim().isEmpty ? shopName : name.trim();
    final newCategory = category;
    final newAddress = address.trim().isEmpty ? shopAddress : address.trim();

    if (isDemoMode || !isAuthenticated) {
      customerName = newOwnerName;
      shopName = newShopName;
      shopCategory = newCategory;
      shopAddress = newAddress;
      lastNotice = 'Shop updated (demo).';
      cloudError = null;
      notifyListeners();
      return true;
    }

    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;

    try {
      await firestoreService.saveUserProfile(
        role: role,
        name: newOwnerName,
        email: customerEmail,
        city: city,
        shopName: newShopName,
        shopCategory: newCategory,
        shopAddress: newAddress,
        vendorName: vendorName,
        vendorCategory: vendorCategory,
      );
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      customerName = newOwnerName;
      shopName = newShopName;
      shopCategory = newCategory;
      shopAddress = newAddress;
      hasExistingCloudProfile = true;
      profileStatus = CloudProfileStatus.loaded;
      lastNotice = 'Shop profile updated in cloud.';
      cloudError = null;
      return true;
    } catch (e) {
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      cloudError = e.toString();
      lastNotice = 'Failed to update shop: $e';
      return false;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateVendor(
      {required String ownerName,
      required String name,
      required String category}) async {
    if (isCloudLoading || isSigningOut) return false;
    final newOwnerName = ownerName.trim();
    if (newOwnerName.isEmpty) {
      cloudError = 'Enter the owner/contact full name before saving the vendor profile.';
      notifyListeners();
      return false;
    }
    final newVendorName = name.trim().isEmpty ? vendorName : name.trim();
    final newCategory = category;

    if (isDemoMode || !isAuthenticated) {
      customerName = newOwnerName;
      vendorName = newVendorName;
      vendorCategory = newCategory;
      lastNotice = 'Vendor updated (demo).';
      cloudError = null;
      notifyListeners();
      return true;
    }

    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;

    try {
      await firestoreService.saveUserProfile(
        role: role,
        name: newOwnerName,
        email: customerEmail,
        city: city,
        shopName: shopName,
        shopCategory: shopCategory,
        shopAddress: shopAddress,
        vendorName: newVendorName,
        vendorCategory: newCategory,
      );
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      customerName = newOwnerName;
      vendorName = newVendorName;
      vendorCategory = newCategory;
      hasExistingCloudProfile = true;
      profileStatus = CloudProfileStatus.loaded;
      lastNotice = 'Vendor profile updated in cloud.';
      cloudError = null;
      return true;
    } catch (e) {
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      cloudError = e.toString();
      lastNotice = 'Failed to update vendor: $e';
      return false;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;
    notifyListeners();
  }

  void setSpendingSummaryEnabled(bool value) {
    spendingSummaryEnabled = value;
    notifyListeners();
  }

  void setProductUpdatesEnabled(bool value) {
    productUpdatesEnabled = value;
    notifyListeners();
  }

  void setLanguage(String value) {
    language = value;
    notifyListeners();
  }

  String? formatPhoneNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    String cleaned = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.startsWith('+')) {
      final digitsOnly = cleaned.substring(1).replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length >= 7 && digitsOnly.length <= 15) {
        return '+$digitsOnly';
      }
      return null;
    }

    cleaned = cleaned.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.length == 10) {
      return '+91$cleaned';
    }

    return null;
  }

  Future<void> sendPhoneOtp({
    required String rawPhone,
    required VoidCallback onSuccessCodeSent,
    required void Function(String error) onError,
    bool isResend = false,
  }) async {
    final remaining = otpCooldownSecondsRemaining;
    if (remaining > 0 && !isResend) {
      final err = 'Please wait ${remaining}s before requesting another OTP.';
      phoneAuthError = err;
      notifyListeners();
      onError(err);
      return;
    }

    final formatted = formatPhoneNumber(rawPhone);
    if (formatted == null) {
      const err =
          'Please enter a valid 10-digit mobile number (e.g. 9876543210 or +919876543210).';
      phoneAuthError = err;
      notifyListeners();
      onError(err);
      return;
    }

    if (!await beginAuthentication()) {
      final err = signOutError ?? 'Could not start sign-in. Please retry.';
      phoneAuthError = err;
      notifyListeners();
      onError(err);
      return;
    }
    final authAttemptGeneration = ++_sessionGeneration;

    phoneNumber = formatted;
    isPhoneAuthLoading = true;
    phoneAuthError = null;
    notifyListeners();

    try {
      if (auth == null) {
        throw Exception('FirebaseAuth instance not available.');
      }
      await auth!.verifyPhoneNumber(
        phoneNumber: formatted,
        timeout: const Duration(seconds: 60),
        forceResendingToken: isResend ? resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!_isCurrentAuthenticationGeneration(authAttemptGeneration)) {
            return;
          }
          Future<UserCredential>? pending;
          try {
            pending = auth!.signInWithCredential(credential);
            _pendingCredentialSignIn = pending;
            await pending;
            if (!_isCurrentAuthenticationGeneration(authAttemptGeneration)) {
              return;
            }
            isPhoneAuthLoading = false;
            phoneAuthError = null;
            notifyListeners();
          } catch (e) {
            if (!_isCurrentAuthenticationGeneration(authAttemptGeneration)) {
              return;
            }
            isPhoneAuthLoading = false;
            final err = _mapAuthException(e);
            phoneAuthError = err;
            notifyListeners();
            onError(err);
          } finally {
            if (identical(_pendingCredentialSignIn, pending)) {
              _pendingCredentialSignIn = null;
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!_isCurrentAuthenticationGeneration(authAttemptGeneration)) {
            return;
          }
          isPhoneAuthLoading = false;
          final err = _mapAuthException(e);
          phoneAuthError = err;
          notifyListeners();
          onError(err);
        },
        codeSent: (String verId, int? forceResendingToken) {
          if (!_isCurrentAuthenticationGeneration(authAttemptGeneration)) {
            return;
          }
          verificationId = verId;
          resendToken = forceResendingToken;
          lastOtpSentAt = DateTime.now();
          isPhoneAuthLoading = false;
          phoneAuthError = null;
          notifyListeners();
          onSuccessCodeSent();
        },
        codeAutoRetrievalTimeout: (String verId) {
          if (!_isCurrentAuthenticationGeneration(authAttemptGeneration)) {
            return;
          }
          verificationId = verId;
        },
      );
    } catch (e) {
      if (!_isCurrentAuthenticationGeneration(authAttemptGeneration)) return;
      isPhoneAuthLoading = false;
      final err = _mapAuthException(e);
      phoneAuthError = err;
      notifyListeners();
      onError(err);
    }
  }

  Future<void> verifySmsCode({
    required String smsCode,
    required void Function(String error) onError,
  }) async {
    final cleanCode = smsCode.trim();
    if (cleanCode.length != 6) {
      const err = 'Please enter a valid 6-digit OTP.';
      phoneAuthError = err;
      notifyListeners();
      onError(err);
      return;
    }

    if (verificationId.isEmpty) {
      const err = 'Verification session expired. Please request a new OTP.';
      phoneAuthError = err;
      notifyListeners();
      onError(err);
      return;
    }

    if (!await beginAuthentication()) {
      final err = signOutError ?? 'Could not start sign-in. Please retry.';
      phoneAuthError = err;
      notifyListeners();
      onError(err);
      return;
    }
    final authAttemptGeneration = _sessionGeneration;

    isPhoneAuthLoading = true;
    phoneAuthError = null;
    notifyListeners();

    Future<UserCredential>? pending;
    try {
      if (auth == null) {
        throw Exception('FirebaseAuth instance not available.');
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: cleanCode,
      );
      pending = auth!.signInWithCredential(credential);
      _pendingCredentialSignIn = pending;
      await pending;
      if (!_isCurrentAuthenticationGeneration(authAttemptGeneration)) return;
      isPhoneAuthLoading = false;
      phoneAuthError = null;
      // The auth-state listener owns profile loading and routing. Waiting here
      // would start a duplicate Firestore read and create competing route changes.
      notifyListeners();
    } catch (e) {
      if (!_isCurrentAuthenticationGeneration(authAttemptGeneration)) return;
      isPhoneAuthLoading = false;
      final err = _mapAuthException(e);
      phoneAuthError = err;
      notifyListeners();
      onError(err);
    } finally {
      if (identical(_pendingCredentialSignIn, pending)) {
        _pendingCredentialSignIn = null;
      }
    }
  }

  bool _isCurrentAuthenticationGeneration(int generation) =>
      !_disposed &&
      generation == _sessionGeneration &&
      !_explicitDemoSession &&
      !isDemoMode;

  String _mapAuthException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-phone-number':
          return 'The phone number entered is invalid. Please check the number and try again.';
        case 'quota-exceeded':
          return 'SMS quota for this project has been exceeded. Please try again later.';
        case 'too-many-requests':
          return 'Too many requests from this device. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'invalid-verification-code':
          return 'Invalid OTP entered. Please check and try again.';
        case 'invalid-verification-id':
          return 'Verification session expired. Please request a new OTP.';
        case 'session-expired':
          return 'OTP has expired. Please request a new OTP.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'operation-not-allowed':
          return 'Phone authentication is not enabled in Firebase Console.';
        default:
          if (e.message != null && e.message!.isNotEmpty) {
            return e.message!;
          }
          return 'Authentication failed (${e.code}). Please try again.';
      }
    }
    return e.toString();
  }
}
