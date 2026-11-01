import 'package:cloud_firestore/cloud_firestore.dart'
    show DocumentSnapshot, Timestamp;
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/account_deletion/data/account_deletion_service.dart';
import '../data/firestore_service.dart';
import '../monitoring/telemetry.dart';

enum UserRole { customer, shopOwner, streetVendor }

enum CloudProfileStatus { unknown, loading, loaded, missing, failed }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.customer => 'Home & Family',
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

class ExpenseCorrectionSnapshot {
  const ExpenseCorrectionSnapshot({
    required this.title,
    required this.category,
    required this.amount,
    this.expenseDate,
    this.modifiedAt,
  });

  final String title;
  final String category;
  final double amount;
  final DateTime? expenseDate;
  final DateTime? modifiedAt;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'category': category,
      'amount': amount,
    };
    if (expenseDate != null) {
      map['expenseDate'] = Timestamp.fromDate(expenseDate!);
    }
    if (modifiedAt != null) {
      map['modifiedAt'] = Timestamp.fromDate(modifiedAt!);
    }
    return map;
  }

  factory ExpenseCorrectionSnapshot.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return ExpenseCorrectionSnapshot(
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      expenseDate: parseDate(map['expenseDate']),
      modifiedAt: parseDate(map['modifiedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCorrectionSnapshot &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          category == other.category &&
          amount == other.amount &&
          expenseDate == other.expenseDate &&
          modifiedAt == other.modifiedAt;

  @override
  int get hashCode =>
      Object.hash(title, category, amount, expenseDate, modifiedAt);
}

class HouseholdExpense {
  const HouseholdExpense({
    this.id = '',
    required this.title,
    required this.category,
    required this.amount,
    required this.createdAt,
    this.source = 'manual',
    this.expenseDate,
    this.isVoided = false,
    this.voidedAt,
    this.voidReason,
    this.updatedAt,
    this.history = const <ExpenseCorrectionSnapshot>[],
  });

  /// Stable Firestore document ID; empty only for local demo entries.
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime createdAt;

  /// Either manual or voice. The field records how the entry was initiated,
  /// not whether the user confirmed it.
  final String source;

  final DateTime? expenseDate;
  final bool isVoided;
  final DateTime? voidedAt;
  final String? voidReason;
  final DateTime? updatedAt;
  final List<ExpenseCorrectionSnapshot> history;

  DateTime get effectiveDate => expenseDate ?? createdAt;

  factory HouseholdExpense.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final createdAt = parseDate(data['createdAt']) ?? DateTime.now();
    final expenseDate = parseDate(data['expenseDate']);
    final isVoided = data['isVoided'] == true;
    final voidedAt = parseDate(data['voidedAt']);
    final voidReason = data['voidReason'] as String?;
    final updatedAt = parseDate(data['updatedAt']);

    final historyRaw = data['history'];
    final history = <ExpenseCorrectionSnapshot>[];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is Map) {
          history.add(ExpenseCorrectionSnapshot.fromMap(
            Map<String, dynamic>.from(item),
          ));
        }
      }
    }

    return HouseholdExpense(
      id: id.isNotEmpty ? id : (data['id'] as String? ?? ''),
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAt,
      source: data['source'] as String? ?? 'manual',
      expenseDate: expenseDate,
      isVoided: isVoided,
      voidedAt: voidedAt,
      voidReason: voidReason,
      updatedAt: updatedAt,
      history: history,
    );
  }

  HouseholdExpense copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    DateTime? createdAt,
    String? source,
    DateTime? expenseDate,
    bool? isVoided,
    DateTime? voidedAt,
    String? voidReason,
    DateTime? updatedAt,
    List<ExpenseCorrectionSnapshot>? history,
  }) {
    return HouseholdExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      expenseDate: expenseDate ?? this.expenseDate,
      isVoided: isVoided ?? this.isVoided,
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
    );
  }
}

class AppState extends ChangeNotifier {
  AppState({
    FirebaseAuth? auth,
    SharedPreferences? prefs,
    AccountDeletionService? accountDeletionService,
  })  : _auth = auth,
        _prefs = prefs,
        _accountDeletionService = accountDeletionService {
    _loadPersistedTheme();
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

  AccountDeletionService? _accountDeletionService;
  AccountDeletionService get accountDeletionService =>
      _accountDeletionService ??= AccountDeletionService(auth: auth);
  set accountDeletionService(AccountDeletionService service) =>
      _accountDeletionService = service;

  bool isDeletingAccount = false;
  String? deletionError;
  String? deletionSuccessMessage;
  String? deletionVerificationId;
  int? deletionResendToken;

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
  SharedPreferences? _prefs;
  static const String _themePrefKey = 'user_theme_mode';

  void _loadPersistedTheme() {
    final prefs = _prefs;
    if (prefs != null) {
      _applyThemeString(prefs.getString(_themePrefKey));
    } else {
      SharedPreferences.getInstance().then((p) {
        _prefs = p;
        final saved = p.getString(_themePrefKey);
        if (saved != null) {
          _applyThemeString(saved);
          notifyListeners();
        }
      }).catchError((_) {});
    }
  }

  void _applyThemeString(String? value) {
    if (value == 'light') {
      _themeMode = ThemeMode.light;
    } else if (value == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
  }

  bool _isOffline = false;
  bool get isOffline => _isOffline;
  void setOffline(bool offline) {
    if (_isOffline == offline) return;
    _isOffline = offline;
    notifyListeners();
  }

  bool _isNetworkError(dynamic error) {
    if (error == null) return false;
    final message = error.toString().toLowerCase();
    return message.contains('network') ||
        message.contains('offline') ||
        message.contains('unavailable') ||
        message.contains('socketexception') ||
        message.contains('client is offline') ||
        message.contains('failed host lookup') ||
        message.contains('connection timed out');
  }

  Future<void> retryConnection() async {
    if (isDemoMode || auth?.currentUser == null) {
      _isOffline = false;
      notifyListeners();
      return;
    }
    clearCloudError();
    await refreshHouseholdExpenses();
  }

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = _prefs;
    if (prefs != null) {
      prefs.setString(_themePrefKey, mode.name);
    } else {
      SharedPreferences.getInstance().then((p) {
        _prefs = p;
        p.setString(_themePrefKey, mode.name);
      }).catchError((_) {});
    }
    notifyListeners();
  }

  bool notificationsEnabled = true;
  bool spendingSummaryEnabled = true;
  bool productUpdatesEnabled = false;

  final List<DemoBill> bills = <DemoBill>[];
  final List<ClaimedReceipt> claimedReceipts = <ClaimedReceipt>[];
  final List<DemoExpense> expenses = <DemoExpense>[];
  final List<HouseholdExpense> householdExpenses = <HouseholdExpense>[];
  final List<HouseholdExpense> _monthlyHouseholdExpenses = <HouseholdExpense>[];
  int? _loadedMonthlyExpensesYear;
  int? _loadedMonthlyExpensesMonth;
  bool hasMoreHouseholdExpenses = false;
  bool isLoadingMoreHouseholdExpenses = false;
  DocumentSnapshot<Map<String, dynamic>>? _lastHouseholdExpenseDoc;
  final Set<String> savedShops = <String>{};
  int _billSequence = 10500;
  int _vendorBillSequence = 2403;
  DemoBill? _retryableCloudBill;
  DemoExpense? _retryableCloudExpense;
  HouseholdExpense? _retryableHouseholdExpense;
  final Set<String> _pendingHouseholdExpenseOperations = <String>{};

  bool isHouseholdExpenseOperationPending(String expenseId) =>
      _pendingHouseholdExpenseOperations.contains(expenseId);

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
    if (_disposed || isSigningOut) return;

    final eventGeneration = ++_authEventGeneration;
    _profileLoadGeneration++;
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
      await TelemetryService.instance.measureTrace(
        traceName: 'initial_dashboard_data_load',
        action: () async {
          // Stage all reads first. If one collection fails, do not apply only a
          // subset of cloud data alongside demo or stale records.
          final cloudBills = await firestoreService.loadBills();
          if (!isCurrentLoad()) return;
          final cloudExpenses = await firestoreService.loadExpenses();
          if (!isCurrentLoad()) return;
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          final initialExpensePage =
              await firestoreService.loadHouseholdExpensesPage(limit: 50);
          if (!isCurrentLoad()) return;

          final cloudHouseholdExpenses = <HouseholdExpense>[
            ...initialExpensePage.items
          ];
          var lastDoc = initialExpensePage.lastDocument;
          var hasMore = initialExpensePage.hasMore;

          while (
              hasMore && lastDoc != null && cloudHouseholdExpenses.isNotEmpty) {
            final oldestLoaded = cloudHouseholdExpenses.last.createdAt;
            if (oldestLoaded.isBefore(startOfMonth)) {
              break;
            }
            final nextPage = await firestoreService.loadHouseholdExpensesPage(
              startAfter: lastDoc,
              limit: 50,
            );
            if (!isCurrentLoad()) return;
            if (nextPage.items.isEmpty) {
              hasMore = false;
              break;
            }
            cloudHouseholdExpenses.addAll(nextPage.items);
            lastDoc = nextPage.lastDocument;
            hasMore = nextPage.hasMore;
          }
          final cloudSavedShops = await firestoreService.loadSavedShops();
          if (!isCurrentLoad()) return;
          final cloudClaims = await firestoreService.loadClaimedReceipts();
          if (!isCurrentLoad()) return;
          final cloudMonthlyExpenses = await firestoreService
              .loadHouseholdExpensesForMonth(now.year, now.month);
          if (!isCurrentLoad()) return;

          bills
            ..clear()
            ..addAll(cloudBills);
          claimedReceipts
            ..clear()
            ..addAll(cloudClaims);
          expenses
            ..clear()
            ..addAll(cloudExpenses);
          householdExpenses
            ..clear()
            ..addAll(cloudHouseholdExpenses);
          _lastHouseholdExpenseDoc = lastDoc;
          hasMoreHouseholdExpenses = hasMore;
          _monthlyHouseholdExpenses
            ..clear()
            ..addAll(cloudMonthlyExpenses);
          _loadedMonthlyExpensesYear = now.year;
          _loadedMonthlyExpensesMonth = now.month;
          savedShops
            ..clear()
            ..addAll(cloudSavedShops);
        },
      );
      if (!isCurrentLoad()) return CloudProfileStatus.unknown;
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
        // The current product scope is Home & Family daily spending. Existing
        // seller roles remain stored for backward compatibility, but all
        // authenticated profiles now enter the household experience.
        page = 'customerHome';
      case CloudProfileStatus.missing:
        page = 'customerSetup';
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
  Future<void> enterDemoMode({String landingPage = 'customerSetup'}) async {
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
    _retryableHouseholdExpense = null;
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
    householdExpenses.clear();
    _monthlyHouseholdExpenses.clear();
    _loadedMonthlyExpensesYear = null;
    _loadedMonthlyExpensesMonth = null;
    savedShops.clear();
    selectedBill = null;
    selectedClaimedReceipt = null;
    hasMoreHouseholdExpenses = false;
    isLoadingMoreHouseholdExpenses = false;
    _lastHouseholdExpenseDoc = null;
    _pendingHouseholdExpenseOperations.clear();
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
    _retryableHouseholdExpense = null;
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
    hasMoreHouseholdExpenses = false;
    isLoadingMoreHouseholdExpenses = false;
    _lastHouseholdExpenseDoc = null;
    _pendingHouseholdExpenseOperations.clear();
    _monthlyHouseholdExpenses.clear();
    _loadedMonthlyExpensesYear = null;
    _loadedMonthlyExpensesMonth = null;
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
    householdExpenses
      ..clear()
      ..addAll(<HouseholdExpense>[
        HouseholdExpense(
            title: 'Vegetables',
            category: 'Vegetables',
            amount: 250,
            createdAt: DateTime.now().subtract(const Duration(hours: 2))),
        HouseholdExpense(
            title: 'Milk',
            category: 'Dairy',
            amount: 60,
            createdAt: DateTime.now().subtract(const Duration(hours: 4))),
        HouseholdExpense(
            title: 'Bus fare',
            category: 'Transport',
            amount: 30,
            createdAt: DateTime.now().subtract(const Duration(days: 1))),
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
        page = 'customerHome';
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

    if (value != UserRole.customer) {
      // Seller/vendor experiences are paused in the current product scope.
      role = UserRole.customer;
      page = 'customerSetup';
      lastNotice = 'Only Home & Family is available in this version.';
      notifyListeners();
      return;
    }
    role = UserRole.customer;
    page = 'customerSetup';
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
        if (_isNetworkError(error)) {
          _isOffline = true;
        }
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
        if (_isNetworkError(error)) {
          _isOffline = true;
        }
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
    final hasInvalidItem = items.any((item) {
      final itemTotal = item.total;
      return item.name.trim().isEmpty ||
          item.quantity < 1 ||
          !item.unitPrice.isFinite ||
          item.unitPrice <= 0 ||
          !itemTotal.isFinite ||
          itemTotal <= 0;
    });

    final billTotal = items.fold<double>(0, (sum, item) => sum + item.total);

    if (hasInvalidItem || !billTotal.isFinite || billTotal <= 0) {
      const err =
          'Each bill item needs a name, a quantity of at least 1, and a valid price; the total must be finite and greater than ₹0.';
      throw ArgumentError(err);
    }
    final cloudBill = !isDemoMode && isAuthenticated;
    final store = vendorMode ? vendorName : shopName;
    final rawCustomerPhone = customerPhone.trim();
    final normalizedPhone =
        rawCustomerPhone.isEmpty ? '' : formatPhoneNumber(rawCustomerPhone);

    if (normalizedPhone == null) {
      const err = 'Enter a valid customer mobile number or leave it blank.';
      throw ArgumentError(err);
    }
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
      _isOffline = false;
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
      _isOffline = false;
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
      _isOffline = false;
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
    if (!bill.isUdhaar) {
      const err = 'Only Udhaar bills can be marked as settled.';
      cloudError = null;
      _isOffline = false;
      lastNotice = err;
      notifyListeners();
      return false;
    }

    if (bill.isSettled) return true;
    if (isDemoMode || !isAuthenticated) {
      bill.isSettled = true;
      lastNotice = '${bill.id} settled (demo).';
      cloudError = null;
      _isOffline = false;
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
      _isOffline = false;
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

  Future<bool> addHouseholdExpense({
    required String title,
    required String category,
    required double amount,
    String source = 'manual',
    DateTime? expenseDate,
  }) async {
    if (isCloudLoading || isSigningOut) return false;
    final normalizedTitle = title.trim();
    final normalizedCategory = category.trim();
    if (normalizedTitle.isEmpty ||
        normalizedTitle.length > 100 ||
        normalizedCategory.isEmpty ||
        normalizedCategory.length > 50 ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > 10000000 ||
        !const <String>{'manual', 'voice'}.contains(source)) {
      const error = 'Enter a purchase, category and amount greater than ₹0.';
      cloudError = error;
      lastNotice = error;
      notifyListeners();
      return false;
    }

    final cloudWrite = !isDemoMode && isAuthenticated;
    final pending = _retryableHouseholdExpense;
    final isRetry = cloudWrite &&
        pending != null &&
        pending.title == normalizedTitle &&
        pending.category == normalizedCategory &&
        pending.amount == amount &&
        pending.source == source &&
        pending.expenseDate == expenseDate;

    final HouseholdExpense expense;
    if (isRetry) {
      expense = pending;
    } else {
      expense = HouseholdExpense(
        id: cloudWrite ? firestoreService.newHouseholdExpenseId() : '',
        title: normalizedTitle,
        category: normalizedCategory,
        amount: amount,
        createdAt: DateTime.now(),
        source: source,
        expenseDate: expenseDate,
      );
      if (cloudWrite) _retryableHouseholdExpense = expense;
    }

    if (!cloudWrite) {
      householdExpenses.insert(0, expense);
      lastNotice = 'Household expense recorded in demo mode.';
      page = 'householdExpenses';
      cloudError = null;
      _isOffline = false;
      notifyListeners();
      return true;
    }

    isCloudLoading = true;
    cloudError = null;
    notifyListeners();
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;
    try {
      await firestoreService.addHouseholdExpense(expense);
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      householdExpenses.insert(0, expense);
      if (identical(_retryableHouseholdExpense, expense)) {
        _retryableHouseholdExpense = null;
      }
      if (_loadedMonthlyExpensesYear != null &&
          _loadedMonthlyExpensesMonth != null) {
        final eff = expense.effectiveDate;
        if (eff.year == _loadedMonthlyExpensesYear &&
            eff.month == _loadedMonthlyExpensesMonth) {
          _monthlyHouseholdExpenses.removeWhere((e) => e.id == expense.id);
          _monthlyHouseholdExpenses.add(expense);
          _monthlyHouseholdExpenses
              .sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
        }
      }
      lastNotice = 'Household expense saved to cloud.';
      page = 'householdExpenses';
      cloudError = null;
      _isOffline = false;
      return true;
    } catch (error) {
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      if (_isNetworkError(error)) {
        _isOffline = true;
      }
      cloudError = error.toString();
      lastNotice = 'Household expense was not saved. Retry the same entry.';
      return false;
    } finally {
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadMoreHouseholdExpenses({int pageSize = 50}) async {
    if (isDemoMode) {
      hasMoreHouseholdExpenses = false;
      return false;
    }
    if (isLoadingMoreHouseholdExpenses || !hasMoreHouseholdExpenses) {
      return false;
    }
    final lastDoc = _lastHouseholdExpenseDoc;
    if (lastDoc == null) {
      hasMoreHouseholdExpenses = false;
      return false;
    }

    isLoadingMoreHouseholdExpenses = true;
    notifyListeners();

    try {
      final page = await firestoreService.loadHouseholdExpensesPage(
        startAfter: lastDoc,
        limit: pageSize,
      );
      if (_disposed || isDemoMode) return false;

      final existingIds = householdExpenses.map((e) => e.id).toSet();
      for (final item in page.items) {
        if (!existingIds.contains(item.id)) {
          householdExpenses.add(item);
          existingIds.add(item.id);
        }
      }
      _lastHouseholdExpenseDoc = page.lastDocument;
      hasMoreHouseholdExpenses = page.hasMore;
      return true;
    } catch (_) {
      return false;
    } finally {
      isLoadingMoreHouseholdExpenses = false;
      notifyListeners();
    }
  }

  /// Active (non-voided) household expenses.
  Iterable<HouseholdExpense> get activeHouseholdExpenses =>
      householdExpenses.where((e) => !e.isVoided);

  /// Non-voided household expenses for the current month.
  ///
  /// In cloud mode, this is populated via [FirestoreService.loadHouseholdExpensesForMonth].
  /// In demo mode or if monthly query has not run, falls back to filtering [activeHouseholdExpenses].
  List<HouseholdExpense> get monthlyHouseholdExpenses {
    final now = DateTime.now();
    if (!isDemoMode &&
        _loadedMonthlyExpensesYear == now.year &&
        _loadedMonthlyExpensesMonth == now.month) {
      return List.unmodifiable(
          _monthlyHouseholdExpenses.where((e) => !e.isVoided));
    }
    return List.unmodifiable(
      activeHouseholdExpenses.where((e) {
        final d = e.effectiveDate;
        return d.year == now.year && d.month == now.month;
      }),
    );
  }

  /// Total spending across all active household expenses.
  double get totalHouseholdSpend =>
      activeHouseholdExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

  /// Household spend for today based on each expense's effectiveDate.
  double get spentToday {
    final now = DateTime.now();
    return spentOnDay(now);
  }

  /// Household spend on a specific calendar day based on effectiveDate.
  double spentOnDay(DateTime day) {
    final source = (!isDemoMode &&
            _loadedMonthlyExpensesYear == day.year &&
            _loadedMonthlyExpensesMonth == day.month)
        ? _monthlyHouseholdExpenses.where((e) => !e.isVoided)
        : activeHouseholdExpenses;
    return source.where((e) {
      final date = e.effectiveDate;
      return date.year == day.year &&
          date.month == day.month &&
          date.day == day.day;
    }).fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  /// Household spend for the current calendar month based on effectiveDate.
  double get spentThisMonth {
    final now = DateTime.now();
    return householdSpendForMonth(now.year, now.month);
  }

  /// Alias matching requirements for total monthly household spend.
  double get totalHouseholdSpendThisMonth => spentThisMonth;

  /// Household spend for a specific year and month based on effectiveDate.
  double householdSpendForMonth(int year, int month) {
    final source = (!isDemoMode &&
            _loadedMonthlyExpensesYear == year &&
            _loadedMonthlyExpensesMonth == month)
        ? _monthlyHouseholdExpenses.where((e) => !e.isVoided)
        : activeHouseholdExpenses;
    return source.where((e) {
      final date = e.effectiveDate;
      return date.year == year && date.month == month;
    }).fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  bool _isRefreshingHouseholdExpenses = false;
  bool get isRefreshingHouseholdExpenses => _isRefreshingHouseholdExpenses;

  /// Refreshes the current month's household expenses from Firestore.
  ///
  /// In demo mode or when unauthenticated, this is a no-op.
  Future<void> refreshCurrentMonthExpenses() async {
    if (isDemoMode || !isAuthenticated || _isRefreshingHouseholdExpenses) {
      return;
    }
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;
    try {
      final now = DateTime.now();
      final items = await firestoreService.loadHouseholdExpensesForMonth(
        now.year,
        now.month,
      );
      if (_disposed ||
          isSigningOut ||
          uid == null ||
          !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return;
      }
      _monthlyHouseholdExpenses
        ..clear()
        ..addAll(items);
      _loadedMonthlyExpensesYear = now.year;
      _loadedMonthlyExpensesMonth = now.month;
      cloudError = null;
      _isOffline = false;
      notifyListeners();
    } catch (e) {
      if (_disposed ||
          isSigningOut ||
          uid == null ||
          !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return;
      }
      if (_isNetworkError(e)) {
        _isOffline = true;
      }
      cloudError = 'Could not refresh insights: $e';
      notifyListeners();
    }
  }

  /// Refreshes all household expenses (first page of daily log and current month query).
  ///
  /// In demo mode or when unauthenticated, triggers a local notification update.
  Future<void> refreshHouseholdExpenses() async {
    if (isDemoMode) {
      notifyListeners();
      return;
    }
    if (!isAuthenticated || _isRefreshingHouseholdExpenses) return;
    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;
    _isRefreshingHouseholdExpenses = true;
    try {
      final now = DateTime.now();
      final pageResult =
          await firestoreService.loadHouseholdExpensesPage(limit: 50);
      final monthlyResult =
          await firestoreService.loadHouseholdExpensesForMonth(
        now.year,
        now.month,
      );
      if (_disposed ||
          isSigningOut ||
          uid == null ||
          !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return;
      }
      householdExpenses
        ..clear()
        ..addAll(pageResult.items);
      _lastHouseholdExpenseDoc = pageResult.lastDocument;
      hasMoreHouseholdExpenses = pageResult.hasMore;
      _monthlyHouseholdExpenses
        ..clear()
        ..addAll(monthlyResult);
      _loadedMonthlyExpensesYear = now.year;
      _loadedMonthlyExpensesMonth = now.month;
      cloudError = null;
      _isOffline = false;
      notifyListeners();
    } catch (e) {
      if (_disposed ||
          isSigningOut ||
          uid == null ||
          !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return;
      }
      if (_isNetworkError(e)) {
        _isOffline = true;
      }
      cloudError = 'Could not refresh expenses: $e';
      notifyListeners();
    } finally {
      _isRefreshingHouseholdExpenses = false;
    }
  }

  /// Clears any active cloud error message.
  void clearCloudError() {
    if (cloudError != null) {
      cloudError = null;
      notifyListeners();
    }
  }

  /// Updates an existing household expense.
  ///
  /// In cloud mode, executes a Firestore transaction via [FirestoreService].
  /// In demo mode, records a correction snapshot and updates local state.
  Future<bool> updateHouseholdExpense(HouseholdExpense expense) async {
    if (_disposed || isSigningOut) return false;
    final trimmedId = expense.id.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('Expense ID cannot be empty.');
    }

    if (_pendingHouseholdExpenseOperations.contains(trimmedId)) {
      throw StateError('An operation is already in progress for this expense.');
    }

    var index = householdExpenses.indexWhere((e) => e.id == trimmedId);
    final HouseholdExpense existing;
    if (index != -1) {
      existing = householdExpenses[index];
    } else {
      final mIndex =
          _monthlyHouseholdExpenses.indexWhere((e) => e.id == trimmedId);
      if (mIndex != -1) {
        existing = _monthlyHouseholdExpenses[mIndex];
      } else {
        throw StateError('Household expense not found.');
      }
    }
    if (existing.isVoided) {
      throw StateError('Cannot modify a voided household expense.');
    }

    final normalizedTitle = expense.title.trim();
    if (normalizedTitle.isEmpty || normalizedTitle.length > 100) {
      throw ArgumentError('Title must be between 1 and 100 characters.');
    }
    final normalizedCategory = expense.category.trim();
    if (normalizedCategory.isEmpty || normalizedCategory.length > 50) {
      throw ArgumentError('Category must be between 1 and 50 characters.');
    }
    if (!expense.amount.isFinite ||
        expense.amount <= 0 ||
        expense.amount > 10000000) {
      throw ArgumentError('Amount must be positive, finite and <= 10,000,000.');
    }

    final targetExpenseDate = expense.expenseDate ?? existing.expenseDate;

    if (existing.history.length >= 10) {
      throw StateError('Maximum correction history limit of 10 reached.');
    }

    // Build the prior state snapshot
    final snapshot = ExpenseCorrectionSnapshot(
      title: existing.title,
      category: existing.category,
      amount: existing.amount,
      expenseDate: existing.expenseDate,
      modifiedAt: existing.updatedAt,
    );
    final newHistory = <ExpenseCorrectionSnapshot>[
      ...existing.history,
      snapshot,
    ];

    final updatedLocal = existing.copyWith(
      title: normalizedTitle,
      category: normalizedCategory,
      amount: expense.amount,
      expenseDate: targetExpenseDate,
      updatedAt: DateTime.now(),
      history: newHistory,
    );

    final cloudWrite = !isDemoMode && isAuthenticated;
    if (!cloudWrite) {
      if (index != -1) {
        householdExpenses[index] = updatedLocal;
      }
      final mIndex =
          _monthlyHouseholdExpenses.indexWhere((e) => e.id == trimmedId);
      if (mIndex != -1) {
        _monthlyHouseholdExpenses[mIndex] = updatedLocal;
      }
      lastNotice = 'Household expense updated in demo mode.';
      cloudError = null;
      _isOffline = false;
      notifyListeners();
      return true;
    }

    _pendingHouseholdExpenseOperations.add(trimmedId);
    isCloudLoading = true;
    cloudError = null;
    notifyListeners();

    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;

    try {
      final targetForCloud = expense.copyWith(
        id: existing.id,
        title: normalizedTitle,
        category: normalizedCategory,
        amount: expense.amount,
        createdAt: existing.createdAt,
        source: existing.source,
        expenseDate: targetExpenseDate,
      );

      await firestoreService.updateHouseholdExpense(targetForCloud);

      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }

      final currentIndex =
          householdExpenses.indexWhere((e) => e.id == trimmedId);
      if (currentIndex != -1) {
        householdExpenses[currentIndex] = updatedLocal;
      }

      final eff = updatedLocal.effectiveDate;
      final mIndex =
          _monthlyHouseholdExpenses.indexWhere((e) => e.id == trimmedId);
      final isCurrentMonth = _loadedMonthlyExpensesYear != null &&
          _loadedMonthlyExpensesMonth != null &&
          eff.year == _loadedMonthlyExpensesYear &&
          eff.month == _loadedMonthlyExpensesMonth;
      if (isCurrentMonth) {
        if (mIndex != -1) {
          _monthlyHouseholdExpenses[mIndex] = updatedLocal;
        } else {
          _monthlyHouseholdExpenses.add(updatedLocal);
        }
        _monthlyHouseholdExpenses
            .sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
      } else if (mIndex != -1) {
        _monthlyHouseholdExpenses.removeAt(mIndex);
      }

      if (_loadedMonthlyExpensesYear != null &&
          _loadedMonthlyExpensesMonth != null) {
        try {
          final refreshed =
              await firestoreService.loadHouseholdExpensesForMonth(
            _loadedMonthlyExpensesYear!,
            _loadedMonthlyExpensesMonth!,
          );
          if (_isCurrentAuthenticatedSession(uid, authGeneration)) {
            _monthlyHouseholdExpenses
              ..clear()
              ..addAll(refreshed);
          }
        } catch (_) {
          // Fallback to in-memory update
        }
      }

      lastNotice = 'Household expense updated in cloud.';
      cloudError = null;
      _isOffline = false;
      return true;
    } catch (error) {
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      if (_isNetworkError(error)) {
        _isOffline = true;
      }
      cloudError = error.toString();
      rethrow;
    } finally {
      _pendingHouseholdExpenseOperations.remove(trimmedId);
      if (uid != null && _isCurrentAuthenticatedSession(uid, authGeneration)) {
        isCloudLoading = false;
        notifyListeners();
      }
    }
  }

  /// Marks a household expense as voided (soft-delete).
  ///
  /// In cloud mode, executes a Firestore transaction via [FirestoreService].
  /// In demo mode, marks the item voided in local memory.
  Future<bool> voidHouseholdExpense(String expenseId, {String? reason}) async {
    if (_disposed || isSigningOut) return false;
    final trimmedId = expenseId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('Expense ID cannot be empty.');
    }
    final trimmedReason = reason?.trim();
    if (trimmedReason != null && trimmedReason.length > 200) {
      throw ArgumentError('Void reason cannot exceed 200 characters.');
    }

    if (_pendingHouseholdExpenseOperations.contains(trimmedId)) {
      throw StateError('An operation is already in progress for this expense.');
    }

    var index = householdExpenses.indexWhere((e) => e.id == trimmedId);
    final HouseholdExpense existing;
    if (index != -1) {
      existing = householdExpenses[index];
    } else {
      final mIndex =
          _monthlyHouseholdExpenses.indexWhere((e) => e.id == trimmedId);
      if (mIndex != -1) {
        existing = _monthlyHouseholdExpenses[mIndex];
      } else {
        throw StateError('Household expense not found.');
      }
    }
    if (existing.isVoided) {
      throw StateError('Expense is already voided.');
    }

    final voidedLocal = existing.copyWith(
      isVoided: true,
      voidedAt: DateTime.now(),
      voidReason: trimmedReason,
    );

    final cloudWrite = !isDemoMode && isAuthenticated;
    if (!cloudWrite) {
      if (index != -1) {
        householdExpenses[index] = voidedLocal;
      }
      _monthlyHouseholdExpenses.removeWhere((e) => e.id == trimmedId);
      lastNotice = 'Household expense voided in demo mode.';
      cloudError = null;
      _isOffline = false;
      notifyListeners();
      return true;
    }

    _pendingHouseholdExpenseOperations.add(trimmedId);
    isCloudLoading = true;
    cloudError = null;
    notifyListeners();

    final uid = auth?.currentUser?.uid;
    final authGeneration = _authEventGeneration;

    try {
      await firestoreService.voidHouseholdExpense(trimmedId,
          reason: trimmedReason);

      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }

      final currentIndex =
          householdExpenses.indexWhere((e) => e.id == trimmedId);
      if (currentIndex != -1) {
        householdExpenses[currentIndex] = voidedLocal;
      }
      _monthlyHouseholdExpenses.removeWhere((e) => e.id == trimmedId);

      if (_loadedMonthlyExpensesYear != null &&
          _loadedMonthlyExpensesMonth != null) {
        try {
          final refreshed =
              await firestoreService.loadHouseholdExpensesForMonth(
            _loadedMonthlyExpensesYear!,
            _loadedMonthlyExpensesMonth!,
          );
          if (_isCurrentAuthenticatedSession(uid, authGeneration)) {
            _monthlyHouseholdExpenses
              ..clear()
              ..addAll(refreshed);
          }
        } catch (_) {
          // Fallback to in-memory removal
        }
      }

      lastNotice = 'Household expense voided in cloud.';
      cloudError = null;
      _isOffline = false;
      return true;
    } catch (error) {
      if (uid == null || !_isCurrentAuthenticatedSession(uid, authGeneration)) {
        return false;
      }
      if (_isNetworkError(error)) {
        _isOffline = true;
      }
      cloudError = error.toString();
      rethrow;
    } finally {
      _pendingHouseholdExpenseOperations.remove(trimmedId);
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
    if (!amount.isFinite || amount <= 0) {
      const err = 'Expense amount must be a finite number greater than ₹0.';
      cloudError = err;
      lastNotice = err;
      notifyListeners();
      return false;
    }

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
      _isOffline = false;
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
      _isOffline = false;
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
      _isOffline = false;
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
      _isOffline = false;
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
      _isOffline = false;
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
      _isOffline = false;
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
      cloudError =
          'Enter the owner/contact full name before saving the shop profile.';
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
      _isOffline = false;
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
      _isOffline = false;
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
      cloudError =
          'Enter the owner/contact full name before saving the vendor profile.';
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
      _isOffline = false;
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
      _isOffline = false;
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

    // Allow digits, spaces, hyphens, parentheses and one leading + only.
    if (!RegExp(r'^\+?[\d\s\-()]+$').hasMatch(trimmed)) {
      return null;
    }

    var cleaned = trimmed.replaceAll(RegExp(r'[\s\-()]'), '');

    if (cleaned.startsWith('+')) {
      final digitsOnly = cleaned.substring(1);

      if (!RegExp(r'^[1-9]\d{6,14}$').hasMatch(digitsOnly)) {
        return null;
      }

      if (digitsOnly.startsWith('91')) {
        final indianMobile = digitsOnly.substring(2);

        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(indianMobile)) {
          return null;
        }
      }

      return '+$digitsOnly';
    }
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }

    if (RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
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

  Future<bool> sendDeletionReauthOtp({
    void Function(String verificationId)? onCodeSent,
    void Function(String error)? onError,
  }) async {
    if (isDemoMode || _explicitDemoSession) {
      deletionError =
          'Account deletion is not supported in Demo Mode. Reset demo data locally instead.';
      notifyListeners();
      onError?.call(deletionError!);
      return false;
    }

    final user = auth?.currentUser;
    if (user == null) {
      deletionError = 'You must be signed in to request account deletion.';
      notifyListeners();
      onError?.call(deletionError!);
      return false;
    }

    final targetPhone = user.phoneNumber?.trim() ?? '';
    if (targetPhone.isEmpty) {
      deletionError =
          'No verified phone number found on account to re-authenticate.';
      notifyListeners();
      onError?.call(deletionError!);
      return false;
    }

    deletionError = null;
    notifyListeners();

    final completer = Completer<bool>();

    try {
      await auth!.verifyPhoneNumber(
        phoneNumber: targetPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: deletionResendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await user.reauthenticateWithCredential(credential);
            if (!completer.isCompleted) completer.complete(true);
          } catch (_) {
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          deletionError =
              e.message ?? 'SMS verification failed. Check phone connection.';
          notifyListeners();
          onError?.call(deletionError!);
          if (!completer.isCompleted) completer.complete(false);
        },
        codeSent: (String vId, int? resendToken) {
          deletionVerificationId = vId;
          deletionResendToken = resendToken;
          onCodeSent?.call(vId);
          notifyListeners();
          if (!completer.isCompleted) completer.complete(true);
        },
        codeAutoRetrievalTimeout: (String vId) {
          deletionVerificationId = vId;
        },
      );
    } catch (e) {
      deletionError = 'Failed to send verification SMS: $e';
      notifyListeners();
      onError?.call(deletionError!);
      return false;
    }

    return completer.future;
  }

  Future<bool> deleteAccountWithOtp(
    String smsCode, {
    bool skipFreshnessCheckForTest = false,
  }) async {
    if (isDemoMode || _explicitDemoSession) {
      deletionError =
          'Demo mode sessions cannot perform server-side account deletion.';
      notifyListeners();
      return false;
    }

    final user = auth?.currentUser;
    if (user == null) {
      deletionError = 'You must be signed in to delete your account.';
      notifyListeners();
      return false;
    }

    if (deletionVerificationId == null || deletionVerificationId!.isEmpty) {
      deletionError = 'Please request an SMS verification code first.';
      notifyListeners();
      return false;
    }

    isDeletingAccount = true;
    deletionError = null;
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: deletionVerificationId!,
        smsCode: smsCode.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      await accountDeletionService.invokeDeletion(
        skipFreshnessCheckForTest: skipFreshnessCheckForTest,
      );

      _clearCloudAccountState();
      try {
        await firestoreService.firestore.clearPersistence();
      } catch (_) {}

      try {
        await auth?.signOut();
      } catch (_) {}

      _restoreDemoState();
      isDemoMode = true;
      deletionSuccessMessage =
          'Your account and personal data have been permanently deleted.';
      page = 'splash';
      return true;
    } catch (e) {
      deletionError = 'Account deletion failed: $e';
      return false;
    } finally {
      isDeletingAccount = false;
      notifyListeners();
    }
  }

  void resetDemoData() {
    _restoreDemoState();
    deletionError = null;
    deletionSuccessMessage = 'Demo records reset to default state.';
    notifyListeners();
  }
}
