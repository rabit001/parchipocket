import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../app_state.dart';

class BillIdCollisionException implements Exception {
  const BillIdCollisionException(this.billId);

  final String billId;

  @override
  String toString() =>
      'A different bill already uses document ID $billId. Retry to create this bill with a fresh ID.';
}

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  FirebaseFirestore get firestore {
    if (_firestore != null) return _firestore;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return FirebaseFirestore.instance;
  }

  FirebaseAuth get auth {
    if (_auth != null) return _auth;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return FirebaseAuth.instance;
  }

  String? get uid => auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final currentUid = uid;
    if (currentUid == null) return null;
    return firestore.collection('users').doc(currentUid);
  }

  /// Allocates an ID using Firestore's collision-resistant document ID generator.
  /// The same ID is kept on the bill model and is used as its document path.
  String newBillId() {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    return doc.collection('bills').doc().id;
  }

  // Profile serialization & persistence
  Future<void> saveUserProfile({
    required UserRole role,
    required String name,
    required String email,
    required String city,
    required String shopName,
    required String shopCategory,
    required String shopAddress,
    required String vendorName,
    required String vendorCategory,
  }) async {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    await doc.set({
      'role': role.name,
      'name': name,
      'email': email,
      'city': city,
      'shopName': shopName,
      'shopCategory': shopCategory,
      'shopAddress': shopAddress,
      'vendorName': vendorName,
      'vendorCategory': vendorCategory,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> loadUserProfile() async {
    final doc = _userDoc;
    if (doc == null) return null;
    final snapshot = await doc.get();
    return snapshot.data();
  }

  // Bills serialization & persistence
  Future<void> createBill(DemoBill bill) async {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    final billRef = doc.collection('bills').doc(bill.id);
    final data = _serializeBill(bill);
    final hasConflictingBill = await firestore.runTransaction<bool>((transaction) async {
      final existing = await transaction.get(billRef);
      if (existing.exists) {
        if (_isSameBillIdentity(existing.data()!, data)) {
          // A prior create may have committed even if its acknowledgement was lost.
          // Treat an exact retry as success without writing over the existing record.
          return false;
        }
        // Return the outcome from the callback. Throwing here interacts poorly with
        // the Android MethodChannel transaction error protocol, which can complete
        // the Dart future twice for user-thrown callback errors.
        return true;
      }
      transaction.set(billRef, data);
      return false;
    });
    if (hasConflictingBill) throw BillIdCollisionException(bill.id);
  }

  /// Applies allowed monotonic bill changes to a record that must already exist.
  /// Using update() prevents accidental creation if a bill ID is stale or wrong.
  Future<void> saveBill(DemoBill bill) async {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    await doc.collection('bills').doc(bill.id).update(_serializeBill(bill));
  }

  Map<String, dynamic> _serializeBill(DemoBill bill) => {
      'id': bill.id,
      'store': bill.store,
      'items': bill.items
          .map((item) => {
                'name': item.name,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
              })
          .toList(),
      'createdAt': Timestamp.fromDate(bill.createdAt),
      'paymentMode': bill.paymentMode,
      'customerPhone': bill.customerPhone,
      'isUdhaar': bill.isUdhaar,
      'isSettled': bill.isSettled,
      'isSaved': bill.isSaved,
    };

  bool _isSameBillIdentity(
    Map<String, dynamic> existing,
    Map<String, dynamic> requested,
  ) {
    if (existing['id'] != requested['id'] ||
        existing['store'] != requested['store'] ||
        existing['paymentMode'] != requested['paymentMode'] ||
        existing['customerPhone'] != requested['customerPhone'] ||
        existing['isUdhaar'] != requested['isUdhaar']) {
      return false;
    }
    final existingDate = existing['createdAt'];
    final requestedDate = requested['createdAt'];
    if (existingDate is! Timestamp ||
        requestedDate is! Timestamp ||
        existingDate.seconds != requestedDate.seconds ||
        existingDate.nanoseconds != requestedDate.nanoseconds) {
      return false;
    }
    final existingItems = existing['items'];
    final requestedItems = requested['items'];
    if (existingItems is! List ||
        requestedItems is! List ||
        existingItems.length != requestedItems.length) {
      return false;
    }
    for (var index = 0; index < existingItems.length; index++) {
      final existingItem = existingItems[index];
      final requestedItem = requestedItems[index];
      if (existingItem is! Map ||
          requestedItem is! Map ||
          existingItem['name'] != requestedItem['name'] ||
          existingItem['quantity'] != requestedItem['quantity'] ||
          existingItem['unitPrice'] != requestedItem['unitPrice']) {
        return false;
      }
    }
    return true;
  }

  Future<List<DemoBill>> loadBills() async {
    final doc = _userDoc;
    if (doc == null) return [];
    final snapshot =
        await doc.collection('bills').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((docSnap) {
      final data = docSnap.data();
      final itemsData = (data['items'] as List<dynamic>? ?? [])
          .map((item) => BillLine(
                name: item['name'] as String? ?? '',
                quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0.0,
              ))
          .toList();

      final createdAtTs = data['createdAt'];
      DateTime createdAt = DateTime.now();
      if (createdAtTs is Timestamp) {
        createdAt = createdAtTs.toDate();
      } else if (createdAtTs is String) {
        createdAt = DateTime.tryParse(createdAtTs) ?? DateTime.now();
      }

      return DemoBill(
        // The Firestore document path is the authoritative bill identity.
        id: docSnap.id,
        store: data['store'] as String? ?? '',
        items: itemsData,
        createdAt: createdAt,
        paymentMode: data['paymentMode'] as String? ?? 'Cash',
        customerPhone: data['customerPhone'] as String? ?? '',
        isUdhaar: data['isUdhaar'] as bool? ?? false,
        isSettled: data['isSettled'] as bool? ?? false,
        isSaved: data['isSaved'] as bool? ?? true,
      );
    }).toList();
  }

  // Expenses serialization & persistence
  Future<void> addExpense(DemoExpense expense) async {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    await doc.collection('expenses').add({
      'title': expense.title,
      'category': expense.category,
      'amount': expense.amount,
      'createdAt': Timestamp.fromDate(expense.createdAt),
    });
  }

  Future<List<DemoExpense>> loadExpenses() async {
    final doc = _userDoc;
    if (doc == null) return [];
    final snapshot =
        await doc.collection('expenses').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((docSnap) {
      final data = docSnap.data();
      final createdAtTs = data['createdAt'];
      DateTime createdAt = DateTime.now();
      if (createdAtTs is Timestamp) {
        createdAt = createdAtTs.toDate();
      } else if (createdAtTs is String) {
        createdAt = DateTime.tryParse(createdAtTs) ?? DateTime.now();
      }
      return DemoExpense(
        title: data['title'] as String? ?? '',
        category: data['category'] as String? ?? '',
        amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
        createdAt: createdAt,
      );
    }).toList();
  }

  // Saved Shops serialization & persistence
  Future<void> saveShop(String shopName) async {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    final shopId = shopName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await doc.collection('savedShops').doc(shopId).set({
      'shopName': shopName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeSavedShop(String shopName) async {
    final doc = _userDoc;
    if (doc == null) return;
    final shopId = shopName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await doc.collection('savedShops').doc(shopId).delete();
  }

  Future<Set<String>> loadSavedShops() async {
    final doc = _userDoc;
    if (doc == null) return {};
    final snapshot = await doc.collection('savedShops').get();
    return snapshot.docs
        .map((d) => d.data()['shopName'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
  }
}
