import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_state.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final currentUid = uid;
    if (currentUid == null) return null;
    return _firestore.collection('users').doc(currentUid);
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
  Future<void> saveBill(DemoBill bill) async {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    await doc.collection('bills').doc(bill.id).set({
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
    });
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
        id: data['id'] as String? ?? docSnap.id,
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
