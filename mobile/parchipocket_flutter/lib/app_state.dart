import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'services/firestore_service.dart';

enum UserRole { customer, shopOwner, streetVendor }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.customer => 'Customer',
        UserRole.shopOwner => 'Shop Owner',
        UserRole.streetVendor => 'Street Vendor',
      };
}

class BillLine {
  BillLine({required this.name, required this.quantity, required this.unitPrice});

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
  double get total => items.fold<double>(0, (sum, item) => sum + item.total);
}

class DemoExpense {
  DemoExpense({required this.title, required this.category, required this.amount, required this.createdAt});
  final String title;
  final String category;
  final double amount;
  final DateTime createdAt;
}

class AppState extends ChangeNotifier {
  AppState() {
    _initAuthListener();
  }

  FirebaseAuth? _auth;
  FirebaseAuth get auth {
    if (_auth != null) return _auth!;
    try {
      if (Firebase.apps.isNotEmpty) {
        _auth = FirebaseAuth.instance;
      }
    } catch (_) {}
    return _auth ??= FirebaseAuth.instance;
  }
  set auth(FirebaseAuth instance) => _auth = instance;

  FirestoreService? _firestoreService;
  FirestoreService get firestoreService => _firestoreService ??= FirestoreService(auth: auth);
  set firestoreService(FirestoreService service) => _firestoreService = service;

  String verificationId = '';
  int? resendToken;
  String phoneNumber = '';
  bool isPhoneAuthLoading = false;
  String? phoneAuthError;

  bool isDemoMode = true;
  bool isCloudLoading = false;
  String? cloudError;

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
  String supportReference = 'PP-SUP-1042';
  String lastNotice = '';
  String language = 'English';
  bool notificationsEnabled = true;
  bool spendingSummaryEnabled = true;
  bool productUpdatesEnabled = false;

  final List<DemoBill> bills = <DemoBill>[
    DemoBill(id: 'PP-10482', store: 'Sharma Kirana Store', items: <BillLine>[
      BillLine(name: 'Maggi', quantity: 1, unitPrice: 40),
      BillLine(name: 'Bread', quantity: 1, unitPrice: 30),
      BillLine(name: 'Milk', quantity: 1, unitPrice: 50),
      BillLine(name: 'Chips', quantity: 1, unitPrice: 60),
    ], createdAt: DateTime(2026, 10, 12, 17, 24), paymentMode: 'Cash', isSaved: true),
    DemoBill(id: 'PP-10481', store: 'Gupta General Store', items: <BillLine>[
      BillLine(name: 'Household items', quantity: 1, unitPrice: 240),
    ], createdAt: DateTime(2026, 10, 10, 11, 8), paymentMode: 'UPI', isSaved: true),
    DemoBill(id: 'PP-10480', store: 'Fresh Mart', items: <BillLine>[
      BillLine(name: 'Groceries', quantity: 1, unitPrice: 320),
    ], createdAt: DateTime(2026, 10, 8, 18, 42), paymentMode: 'UPI', isSaved: true),
    DemoBill(id: 'PP-10470', store: 'Mansuri General Store', items: <BillLine>[
      BillLine(name: 'Grocery order', quantity: 1, unitPrice: 450),
    ], createdAt: DateTime(2026, 10, 12, 12), paymentMode: 'Udhaar', customerPhone: '•••• 4421', isUdhaar: true, isSettled: false, isSaved: false),
    DemoBill(id: 'PP-10462', store: 'Mansuri General Store', items: <BillLine>[
      BillLine(name: 'Walk-in purchase', quantity: 1, unitPrice: 300),
    ], createdAt: DateTime(2026, 10, 11, 16), paymentMode: 'Udhaar', isUdhaar: true, isSettled: false, isSaved: false),
    DemoBill(id: 'PP-10455', store: 'Mansuri General Store', items: <BillLine>[
      BillLine(name: 'Household order', quantity: 1, unitPrice: 650),
    ], createdAt: DateTime(2026, 10, 10, 10), paymentMode: 'Udhaar', customerPhone: '•••• 1184', isUdhaar: true, isSettled: false, isSaved: false),
  ];

  final List<DemoExpense> expenses = <DemoExpense>[
    DemoExpense(title: 'Stock purchase', category: 'Stock', amount: 300, createdAt: DateTime(2026, 10, 19, 10, 30)),
    DemoExpense(title: 'Transport', category: 'Transport', amount: 150, createdAt: DateTime(2026, 10, 19, 9, 20)),
  ];
  final Set<String> savedShops = <String>{'Sharma Kirana Store', 'Gupta General Store', 'Fresh Mart'};
  int _billSequence = 10500;
  int _vendorBillSequence = 2403;

  void _initAuthListener() {
    try {
      if (Firebase.apps.isNotEmpty) {
        auth.authStateChanges().listen((User? user) {
          if (user != null) {
            isDemoMode = false;
            loadUserDataFromCloud();
          } else {
            isDemoMode = true;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> loadUserDataFromCloud() async {
    final user = auth.currentUser;
    if (user == null) {
      isDemoMode = true;
      return;
    }

    isCloudLoading = true;
    cloudError = null;
    notifyListeners();

    try {
      isDemoMode = false;
      final profile = await firestoreService.loadUserProfile();
      if (profile != null) {
        if (profile['role'] != null) {
          final roleStr = profile['role'] as String;
          role = UserRole.values.firstWhere(
            (r) => r.name == roleStr,
            orElse: () => UserRole.customer,
          );
        }
        customerName = profile['name'] as String? ?? customerName;
        customerEmail = profile['email'] as String? ?? customerEmail;
        city = profile['city'] as String? ?? city;
        shopName = profile['shopName'] as String? ?? shopName;
        shopCategory = profile['shopCategory'] as String? ?? shopCategory;
        shopAddress = profile['shopAddress'] as String? ?? shopAddress;
        vendorName = profile['vendorName'] as String? ?? vendorName;
        vendorCategory = profile['vendorCategory'] as String? ?? vendorCategory;
      }

      final cloudBills = await firestoreService.loadBills();
      bills.clear();
      bills.addAll(cloudBills);

      final cloudExpenses = await firestoreService.loadExpenses();
      expenses.clear();
      expenses.addAll(cloudExpenses);

      final cloudSavedShops = await firestoreService.loadSavedShops();
      savedShops.clear();
      savedShops.addAll(cloudSavedShops);

      isCloudLoading = false;
      cloudError = null;
      notifyListeners();
    } catch (e) {
      isCloudLoading = false;
      cloudError = e.toString();
      lastNotice = 'Cloud sync error: $e';
      notifyListeners();
    }
  }

  void go(String nextPage) {
    page = nextPage;
    notifyListeners();
  }

  void setRole(UserRole value) {
    role = value;
    page = switch (value) {
      UserRole.customer => 'customerSetup',
      UserRole.shopOwner => 'shopSetup',
      UserRole.streetVendor => 'vendorSetup',
    };
    notifyListeners();
    if (!isDemoMode && auth.currentUser != null) {
      updateProfile(name: customerName, email: customerEmail, location: city);
    }
  }

  String get activeStoreName => role == UserRole.streetVendor ? vendorName : shopName;

  List<DemoBill> get customerBills => bills.where((bill) => bill.isSaved).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<DemoBill> get shopBills => bills.where((bill) => bill.store == shopName || bill.store == vendorName)
    .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<DemoBill> get udhaarBills => bills.where((bill) => bill.isUdhaar && !bill.isSettled).toList();

  double get recordedSales => shopBills.where((b) => !b.isUdhaar).fold<double>(0, (sum, bill) => sum + bill.total);
  double get expensesTotal => expenses.fold<double>(0, (sum, item) => sum + item.amount);
  double get outstandingTotal => udhaarBills.fold<double>(0, (sum, bill) => sum + bill.total);

  void openBill(DemoBill bill) {
    selectedBill = bill;
    page = 'billDetail';
    notifyListeners();
  }

  DemoBill createBill({
    required List<BillLine> items,
    required String paymentMode,
    String customerPhone = '',
    required bool vendorMode,
  }) {
    final bill = DemoBill(
      id: vendorMode ? 'PP-${_vendorBillSequence++}' : 'PP-${_billSequence++}',
      store: vendorMode ? vendorName : shopName,
      items: List<BillLine>.from(items),
      createdAt: DateTime.now(),
      paymentMode: paymentMode,
      customerPhone: customerPhone,
      isUdhaar: paymentMode == 'Udhaar',
      isSaved: false,
    );
    bills.insert(0, bill);
    selectedBill = bill;
    page = vendorMode ? 'vendorReceipt' : 'receipt';
    lastNotice = isDemoMode ? 'Bill created (demo).' : 'Bill created successfully.';
    notifyListeners();

    if (!isDemoMode && auth.currentUser != null) {
      firestoreService.saveBill(bill).catchError((e) {
        cloudError = e.toString();
        lastNotice = 'Failed to save bill to cloud: $e';
        notifyListeners();
      });
    }
    return bill;
  }

  void saveSelectedBill() {
    if (selectedBill != null) {
      selectedBill!.isSaved = true;
      lastNotice = isDemoMode ? 'Receipt saved (demo).' : 'Receipt saved to cloud.';
      notifyListeners();

      if (!isDemoMode && auth.currentUser != null) {
        firestoreService.saveBill(selectedBill!).catchError((e) {
          cloudError = e.toString();
          lastNotice = 'Failed to save receipt to cloud: $e';
          notifyListeners();
        });
      }
    }
  }

  void markSettled(DemoBill bill) {
    bill.isSettled = true;
    lastNotice = isDemoMode ? '${bill.id} settled (demo).' : '${bill.id} marked as settled.';
    notifyListeners();

    if (!isDemoMode && auth.currentUser != null) {
      firestoreService.saveBill(bill).catchError((e) {
        cloudError = e.toString();
        lastNotice = 'Failed to update settlement: $e';
        notifyListeners();
      });
    }
  }

  void addExpense({required String title, required String category, required double amount}) {
    final expense = DemoExpense(
      title: title.trim().isEmpty ? 'Other expense' : title.trim(),
      category: category,
      amount: amount,
      createdAt: DateTime.now(),
    );
    expenses.insert(0, expense);
    lastNotice = isDemoMode ? 'Expense recorded (demo).' : 'Expense saved to cloud.';
    page = 'expenseSaved';
    notifyListeners();

    if (!isDemoMode && auth.currentUser != null) {
      firestoreService.addExpense(expense).catchError((e) {
        cloudError = e.toString();
        lastNotice = 'Failed to record expense: $e';
        notifyListeners();
      });
    }
  }

  void toggleSavedShop(String name) {
    if (savedShops.contains(name)) {
      savedShops.remove(name);
      lastNotice = 'Removed from saved shops.';
      if (!isDemoMode && auth.currentUser != null) {
        firestoreService.removeSavedShop(name).catchError((e) {
          cloudError = e.toString();
          lastNotice = 'Failed to remove shop: $e';
        });
      }
    } else {
      savedShops.add(name);
      lastNotice = 'Shop saved.';
      if (!isDemoMode && auth.currentUser != null) {
        firestoreService.saveShop(name).catchError((e) {
          cloudError = e.toString();
          lastNotice = 'Failed to save shop: $e';
        });
      }
    }
    notifyListeners();
  }

  void submitSupport() {
    supportReference = 'PP-SUP-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    page = 'supportSubmitted';
    notifyListeners();
  }

  void updateProfile({required String name, required String email, required String location}) {
    customerName = name.trim().isEmpty ? customerName : name.trim();
    customerEmail = email.trim();
    city = location.trim().isEmpty ? city : location.trim();
    lastNotice = isDemoMode ? 'Profile updated (demo).' : 'Profile updated in cloud.';
    page = 'customerProfile';
    notifyListeners();

    if (!isDemoMode && auth.currentUser != null) {
      firestoreService.saveUserProfile(
        role: role,
        name: customerName,
        email: customerEmail,
        city: city,
        shopName: shopName,
        shopCategory: shopCategory,
        shopAddress: shopAddress,
        vendorName: vendorName,
        vendorCategory: vendorCategory,
      ).catchError((e) {
        cloudError = e.toString();
        lastNotice = 'Failed to update profile: $e';
        notifyListeners();
      });
    }
  }

  void updateShop({required String name, required String category, required String address}) {
    shopName = name.trim().isEmpty ? shopName : name.trim();
    shopCategory = category;
    shopAddress = address.trim().isEmpty ? shopAddress : address.trim();
    lastNotice = isDemoMode ? 'Shop updated (demo).' : 'Shop profile updated in cloud.';
    page = 'shopHome';
    notifyListeners();

    if (!isDemoMode && auth.currentUser != null) {
      firestoreService.saveUserProfile(
        role: role,
        name: customerName,
        email: customerEmail,
        city: city,
        shopName: shopName,
        shopCategory: shopCategory,
        shopAddress: shopAddress,
        vendorName: vendorName,
        vendorCategory: vendorCategory,
      ).catchError((e) {
        cloudError = e.toString();
        lastNotice = 'Failed to update shop: $e';
        notifyListeners();
      });
    }
  }

  void updateVendor({required String name, required String category}) {
    vendorName = name.trim().isEmpty ? vendorName : name.trim();
    vendorCategory = category;
    lastNotice = isDemoMode ? 'Vendor updated (demo).' : 'Vendor profile updated in cloud.';
    page = 'vendorHome';
    notifyListeners();

    if (!isDemoMode && auth.currentUser != null) {
      firestoreService.saveUserProfile(
        role: role,
        name: customerName,
        email: customerEmail,
        city: city,
        shopName: shopName,
        shopCategory: shopCategory,
        shopAddress: shopAddress,
        vendorName: vendorName,
        vendorCategory: vendorCategory,
      ).catchError((e) {
        cloudError = e.toString();
        lastNotice = 'Failed to update vendor: $e';
        notifyListeners();
      });
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
    final formatted = formatPhoneNumber(rawPhone);
    if (formatted == null) {
      const err =
          'Please enter a valid 10-digit mobile number (e.g. 9876543210 or +919876543210).';
      phoneAuthError = err;
      notifyListeners();
      onError(err);
      return;
    }

    phoneNumber = formatted;
    isPhoneAuthLoading = true;
    phoneAuthError = null;
    notifyListeners();

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: formatted,
        timeout: const Duration(seconds: 60),
        forceResendingToken: isResend ? resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await auth.signInWithCredential(credential);
            isDemoMode = false;
            isPhoneAuthLoading = false;
            phoneAuthError = null;
            notifyListeners();
            await loadUserDataFromCloud();
            go('roleSelection');
          } catch (e) {
            isPhoneAuthLoading = false;
            final err = _mapAuthException(e);
            phoneAuthError = err;
            notifyListeners();
            onError(err);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          isPhoneAuthLoading = false;
          final err = _mapAuthException(e);
          phoneAuthError = err;
          notifyListeners();
          onError(err);
        },
        codeSent: (String verId, int? forceResendingToken) {
          verificationId = verId;
          resendToken = forceResendingToken;
          isPhoneAuthLoading = false;
          phoneAuthError = null;
          notifyListeners();
          onSuccessCodeSent();
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
      );
    } catch (e) {
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

    isPhoneAuthLoading = true;
    phoneAuthError = null;
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: cleanCode,
      );
      await auth.signInWithCredential(credential);
      isDemoMode = false;
      isPhoneAuthLoading = false;
      phoneAuthError = null;
      notifyListeners();
      await loadUserDataFromCloud();
      go('roleSelection');
    } catch (e) {
      isPhoneAuthLoading = false;
      final err = _mapAuthException(e);
      phoneAuthError = err;
      notifyListeners();
      onError(err);
    }
  }

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
