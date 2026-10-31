import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import '../app_state.dart';

class BillIdCollisionException implements Exception {
  const BillIdCollisionException(this.billId);

  final String billId;

  @override
  String toString() =>
      'A different bill already uses document ID $billId. Retry to create this bill with a fresh ID.';
}

class ExpenseIdCollisionException implements Exception {
  const ExpenseIdCollisionException(this.expenseId);

  final String expenseId;

  @override
  String toString() =>
      'A different expense already uses document ID $expenseId. Retry with a fresh ID.';
}

class ReceiptClaimException implements Exception {
  const ReceiptClaimException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HouseholdExpensePage {
  const HouseholdExpensePage({
    required this.items,
    this.lastDocument,
    required this.hasMore,
  });

  final List<HouseholdExpense> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
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

  /// Allocates a stable ID for an expense so retries can reuse the same path.
  String newExpenseId() {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    return doc.collection('expenses').doc().id;
  }

  /// Allocates a stable ID for a personal household expense entry.
  String newHouseholdExpenseId() {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    return doc.collection('householdExpenses').doc().id;
  }

  /// Generates 128 bits of entropy from the platform CSPRNG. Only the SHA-256
  /// digest is persisted; rules cannot verify entropy, so callers must use this.
  String newReceiptClaimCode() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String _claimDigest(String rawCode) =>
      sha256.convert(rawCode.codeUnits).toString();

  Map<String, dynamic> _receiptSnapshot(DemoBill bill) => {
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
      };

  Future<void> createReceiptClaim(
    DemoBill bill, {
    required String rawCode,
    DateTime? expiresAt,
  }) async {
    final uid = this.uid;
    if (uid == null) {
      throw const ReceiptClaimException('Sign in before sharing a receipt.');
    }
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(rawCode)) {
      throw const ReceiptClaimException(
          'The claim code is invalid. Generate a new code and retry.');
    }
    final user = _userDoc!;
    final billRef = user.collection('bills').doc(bill.id);
    final digest = _claimDigest(rawCode);
    final claimRef = firestore.collection('receiptClaims').doc(digest);
    // Leave a clock-skew margin because rules compare this client timestamp
    // against server request.time and enforce a maximum 24-hour lifetime.
    final expiry =
        expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 23));
    final receipt = _receiptSnapshot(bill);
    late final bool conflict;
    try {
      conflict = await firestore.runTransaction<bool>((transaction) async {
        final existingClaim = await transaction.get(claimRef);
        final source = await transaction.get(billRef);
        if (!source.exists || !_sameReceiptSnapshot(source.data()!, receipt)) {
          return true;
        }
        if (existingClaim.exists) {
          final existing = existingClaim.data()!;
          final existingExpiry = existing['expiresAt'];
          final sameClaim = existing['ownerUid'] == uid &&
              existing['sourceBillId'] == bill.id &&
              existing['status'] == 'open' &&
              existingExpiry is Timestamp &&
              existingExpiry.toDate().isAfter(DateTime.now()) &&
              _sameReceiptSnapshot(
                  existing['receipt'] as Map<String, dynamic>, receipt);
          // An ambiguous successful create is safely retried by recognizing
          // the persisted identity. Never write the document again here: its
          // original expiry is part of the bearer code's lifetime.
          return !sameClaim;
        }
        transaction.set(claimRef, {
          'ownerUid': uid,
          'sourceBillId': bill.id,
          'receipt': receipt,
          'expiresAt': Timestamp.fromDate(expiry),
          'status': 'open',
        });
        return false;
      });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const ReceiptClaimException(
            'Could not issue this code. Confirm this bill belongs to the signed-in seller account, then generate a new code or retry.');
      }
      rethrow;
    }
    if (conflict) {
      throw const ReceiptClaimException(
          'This code could not be issued. Refresh the bill and generate a new code.');
    }
  }

  Future<ClaimedReceipt> claimReceipt(String rawCode) async {
    final uid = this.uid;
    if (uid == null) {
      throw const ReceiptClaimException('Sign in before claiming a receipt.');
    }
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(rawCode)) {
      throw const ReceiptClaimException(
          'Enter a valid 32-character receipt claim code.');
    }
    final digest = _claimDigest(rawCode);
    final claimRef = firestore.collection('receiptClaims').doc(digest);
    // Read once outside the transaction to turn ordinary invalid/expired-code
    // denials into a useful UI message without throwing from a transaction callback.
    try {
      await claimRef.get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const ReceiptClaimException(
            'This code is invalid, expired, or already claimed by another account. Ask the seller for a new code.');
      }
      rethrow;
    }
    String? ownerUid;
    String? sourceBillId;
    Map<String, dynamic>? receipt;
    Timestamp? claimedAt;
    late final bool conflict;
    try {
      conflict = await firestore.runTransaction<bool>((transaction) async {
        final claimSnapshot = await transaction.get(claimRef);
        if (!claimSnapshot.exists) return true;
        final claim = claimSnapshot.data()!;
        final candidateOwner = claim['ownerUid'];
        final candidateBillId = claim['sourceBillId'];
        final candidateReceipt = claim['receipt'];
        if (candidateOwner is! String ||
            candidateBillId is! String ||
            candidateReceipt is! Map) {
          return true;
        }
        final ownerCopyRef = firestore
            .collection('users')
            .doc(uid)
            .collection('claimedReceipts')
            .doc(candidateOwner)
            .collection('bills')
            .doc(candidateBillId);
        final indexRef = firestore
            .collection('users')
            .doc(uid)
            .collection('claimedReceiptsIndex')
            .doc(_receiptIndexId(candidateOwner, candidateBillId));
        final copySnapshot = await transaction.get(ownerCopyRef);
        final indexSnapshot = await transaction.get(indexRef);
        final status = claim['status'];
        final sameReceipt = copySnapshot.exists &&
            indexSnapshot.exists &&
            copySnapshot.data()!['recipientUid'] == uid &&
            copySnapshot.data()!['ownerUid'] == candidateOwner &&
            copySnapshot.data()!['sourceBillId'] == candidateBillId &&
            indexSnapshot.data()!['recipientUid'] == uid &&
            indexSnapshot.data()!['ownerUid'] == candidateOwner &&
            indexSnapshot.data()!['sourceBillId'] == candidateBillId &&
            _sameReceiptSnapshot(
                copySnapshot.data()!['receipt'] as Map<String, dynamic>,
                candidateReceipt.cast<String, dynamic>()) &&
            _sameReceiptSnapshot(
                indexSnapshot.data()!['receipt'] as Map<String, dynamic>,
                candidateReceipt.cast<String, dynamic>());
        if (status == 'claimed') {
          if (claim['claimedBy'] != uid || !sameReceipt) return true;
          ownerUid = candidateOwner;
          sourceBillId = candidateBillId;
          receipt = candidateReceipt.cast<String, dynamic>();
          claimedAt = copySnapshot.data()!['claimedAt'] is Timestamp
              ? copySnapshot.data()!['claimedAt'] as Timestamp
              : Timestamp.now();
          return false;
        }
        if (status != 'open' ||
            claim['expiresAt'] is! Timestamp ||
            !(claim['expiresAt'] as Timestamp)
                .toDate()
                .isAfter(DateTime.now())) {
          return true;
        }
        ownerUid = candidateOwner;
        sourceBillId = candidateBillId;
        receipt = candidateReceipt.cast<String, dynamic>();
        claimedAt = Timestamp.now();
        if (!sameReceipt) {
          final copy = {
            'recipientUid': uid,
            'ownerUid': candidateOwner,
            'sourceBillId': candidateBillId,
            'receipt': receipt,
            'claimedAt': FieldValue.serverTimestamp(),
            'claimDigest': digest,
          };
          transaction.set(ownerCopyRef, copy);
          transaction.set(indexRef, copy);
        }
        transaction.update(claimRef, {
          'status': 'claimed',
          'claimedBy': uid,
        });
        return false;
      });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const ReceiptClaimException(
            'This code is invalid, expired, already claimed, or this account is not set up as a customer. Ask the seller for a new code.');
      }
      rethrow;
    }
    if (conflict ||
        ownerUid == null ||
        sourceBillId == null ||
        receipt == null) {
      throw const ReceiptClaimException(
          'This code is invalid, expired, or has already been claimed by another account. Ask the seller for a new code.');
    }
    return _claimedReceipt(
        ownerUid!, sourceBillId!, receipt!, claimedAt ?? Timestamp.now());
  }

  String _receiptIndexId(String ownerUid, String billId) => '$ownerUid~$billId';

  ClaimedReceipt _claimedReceipt(
    String ownerUid,
    String billId,
    Map<String, dynamic> receipt,
    Timestamp claimedAt,
  ) {
    final items = (receipt['items'] as List<dynamic>).map((raw) {
      final item = raw as Map<String, dynamic>;
      return BillLine(
        name: item['name'] as String,
        quantity: (item['quantity'] as num).toInt(),
        unitPrice: (item['unitPrice'] as num).toDouble(),
      );
    }).toList();
    return ClaimedReceipt(
      ownerUid: ownerUid,
      sourceBillId: billId,
      claimedAt: claimedAt.toDate(),
      bill: DemoBill(
        id: receipt['id'] as String,
        store: receipt['store'] as String,
        items: items,
        createdAt: (receipt['createdAt'] as Timestamp).toDate(),
        paymentMode: receipt['paymentMode'] as String,
        isSaved: true,
      ),
    );
  }

  bool _sameReceiptSnapshot(
      Map<String, dynamic> left, Map<String, dynamic> right) {
    for (final key in const ['id', 'store', 'paymentMode']) {
      if (left[key] != right[key]) return false;
    }
    final leftDate = left['createdAt'];
    final rightDate = right['createdAt'];
    if (leftDate is! Timestamp ||
        rightDate is! Timestamp ||
        leftDate != rightDate) {
      return false;
    }
    final leftItems = left['items'];
    final rightItems = right['items'];
    if (leftItems is! List ||
        rightItems is! List ||
        leftItems.length != rightItems.length) {
      return false;
    }
    for (var i = 0; i < leftItems.length; i++) {
      final a = leftItems[i] as Map;
      final b = rightItems[i] as Map;
      if (a['name'] != b['name'] ||
          a['quantity'] != b['quantity'] ||
          a['unitPrice'] != b['unitPrice']) {
        return false;
      }
    }
    return true;
  }

  Future<List<ClaimedReceipt>> loadClaimedReceipts() async {
    final user = _userDoc;
    if (user == null) return <ClaimedReceipt>[];
    final index = await user.collection('claimedReceiptsIndex').get();
    if (index.docs.isEmpty) return <ClaimedReceipt>[];

    final results = <ClaimedReceipt>[];
    final docs = index.docs;
    const effectiveBatchSize = 10;

    for (var i = 0; i < docs.length; i += effectiveBatchSize) {
      final chunk = docs.sublist(i, min(i + effectiveBatchSize, docs.length));
      final chunkResults = await Future.wait(
        chunk.map((entry) async {
          final data = entry.data();
          final ownerUid = data['ownerUid'];
          final billId = data['sourceBillId'];
          if (ownerUid is! String || billId is! String) return null;
          final copy = await user
              .collection('claimedReceipts')
              .doc(ownerUid)
              .collection('bills')
              .doc(billId)
              .get();
          if (!copy.exists) {
            throw const ReceiptClaimException(
                'A saved receipt copy is missing. Contact support before retrying this claim.');
          }
          final copyData = copy.data();
          if (copyData == null) {
            throw const ReceiptClaimException(
                'A saved receipt copy is missing. Contact support before retrying this claim.');
          }
          final receiptMap = copyData['receipt'];
          final claimedAtTs = copyData['claimedAt'];
          if (receiptMap is! Map<String, dynamic> || claimedAtTs is! Timestamp) {
            throw const ReceiptClaimException(
                'Saved receipt copy has invalid or corrupted data.');
          }
          return _claimedReceipt(
            ownerUid,
            billId,
            receiptMap,
            claimedAtTs,
          );
        }),
      );
      for (final r in chunkResults) {
        if (r != null) {
          results.add(r);
        }
      }
    }

    results.sort((a, b) => b.claimedAt.compareTo(a.claimedAt));
    return results;
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
    final hasConflictingBill =
        await firestore.runTransaction<bool>((transaction) async {
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
    final snapshot = await doc
        .collection('bills')
        .orderBy('createdAt', descending: true)
        .get();
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
    final collection = doc.collection('expenses');
    final expenseId = expense.id.isEmpty ? collection.doc().id : expense.id;
    final expenseRef = collection.doc(expenseId);
    final data = {
      'title': expense.title,
      'category': expense.category,
      'amount': expense.amount,
      'createdAt': Timestamp.fromDate(expense.createdAt),
    };

    final hasConflictingExpense = await firestore.runTransaction<bool>(
      (transaction) async {
        final existing = await transaction.get(expenseRef);
        if (existing.exists) {
          // A retry after a lost acknowledgement succeeds only for an exact
          // match; expense rules deny updates to existing records.
          return !_isSameExpense(existing.data()!, data);
        }
        transaction.set(expenseRef, data);
        return false;
      },
    );

    if (hasConflictingExpense) {
      throw ExpenseIdCollisionException(expenseId);
    }
  }

  bool _isSameExpense(
    Map<String, dynamic> existing,
    Map<String, dynamic> requested,
  ) {
    if (existing['title'] != requested['title'] ||
        existing['category'] != requested['category'] ||
        existing['amount'] != requested['amount']) {
      return false;
    }
    final existingDate = existing['createdAt'];
    final requestedDate = requested['createdAt'];
    return existingDate is Timestamp &&
        requestedDate is Timestamp &&
        existingDate.seconds == requestedDate.seconds &&
        existingDate.nanoseconds == requestedDate.nanoseconds;
  }

  Future<List<DemoExpense>> loadExpenses() async {
    final doc = _userDoc;
    if (doc == null) return [];
    final snapshot = await doc
        .collection('expenses')
        .orderBy('createdAt', descending: true)
        .get();
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
        id: docSnap.id,
        title: data['title'] as String? ?? '',
        category: data['category'] as String? ?? '',
        amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
        createdAt: createdAt,
      );
    }).toList();
  }

  // Personal household spending is separate from seller business expenses.
  Future<void> addHouseholdExpense(HouseholdExpense expense) async {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    final collection = doc.collection('householdExpenses');
    final expenseId = expense.id.isEmpty ? collection.doc().id : expense.id;
    final expenseRef = collection.doc(expenseId);
    final data = <String, dynamic>{
      'id': expenseId,
      'title': expense.title,
      'category': expense.category,
      'amount': expense.amount,
      'createdAt': Timestamp.fromDate(expense.createdAt),
      'source': expense.source,
    };

    final hasConflictingExpense = await firestore.runTransaction<bool>(
      (transaction) async {
        final existing = await transaction.get(expenseRef);
        if (existing.exists) {
          // An ambiguous retry is safe only if this is the exact same entry.
          return !_isSameHouseholdExpense(existing.data()!, data);
        }
        transaction.set(expenseRef, data);
        return false;
      },
    );

    if (hasConflictingExpense) {
      throw StateError('Household expense ID collision. Please retry.');
    }
  }

  bool _isSameHouseholdExpense(
    Map<String, dynamic> existing,
    Map<String, dynamic> requested,
  ) {
    if (existing['id'] != requested['id'] ||
        existing['title'] != requested['title'] ||
        existing['category'] != requested['category'] ||
        existing['amount'] != requested['amount'] ||
        existing['source'] != requested['source']) {
      return false;
    }
    final existingDate = existing['createdAt'];
    final requestedDate = requested['createdAt'];
    return existingDate is Timestamp &&
        requestedDate is Timestamp &&
        existingDate.seconds == requestedDate.seconds &&
        existingDate.nanoseconds == requestedDate.nanoseconds;
  }

  Future<HouseholdExpensePage> loadHouseholdExpensesPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 50,
  }) async {
    try {
      final doc = _userDoc;
      if (doc == null) {
        final fallbackItems = await loadHouseholdExpenses();
        return HouseholdExpensePage(
          items: fallbackItems,
          hasMore: false,
        );
      }
      Query<Map<String, dynamic>> query = doc
          .collection('householdExpenses')
          .orderBy('createdAt', descending: true);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      query = query.limit(limit);
      final snapshot = await query.get();
      final items = snapshot.docs.map((docSnap) {
        final data = docSnap.data();
        final createdAtValue = data['createdAt'];
        DateTime createdAt = DateTime.now();
        if (createdAtValue is Timestamp) {
          createdAt = createdAtValue.toDate();
        } else if (createdAtValue is String) {
          createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
        }
        return HouseholdExpense(
          id: docSnap.id,
          title: data['title'] as String? ?? '',
          category: data['category'] as String? ?? 'Other',
          amount: (data['amount'] as num?)?.toDouble() ?? 0,
          createdAt: createdAt,
          source: data['source'] as String? ?? 'manual',
        );
      }).toList();

      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      final hasMore = snapshot.docs.length == limit;

      return HouseholdExpensePage(
        items: items,
        lastDocument: lastDoc,
        hasMore: hasMore,
      );
    } catch (e) {
      if ((e is FirebaseException && e.code == 'no-app') ||
          e.toString().contains('no-app')) {
        final fallbackItems = await loadHouseholdExpenses();
        return HouseholdExpensePage(
          items: fallbackItems,
          hasMore: false,
        );
      }
      rethrow;
    }
  }

  Future<List<HouseholdExpense>> loadHouseholdExpenses() async {
    final doc = _userDoc;
    if (doc == null) return <HouseholdExpense>[];
    final snapshot = await doc
        .collection('householdExpenses')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((docSnap) {
      final data = docSnap.data();
      final createdAtValue = data['createdAt'];
      DateTime createdAt = DateTime.now();
      if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate();
      } else if (createdAtValue is String) {
        createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
      }
      return HouseholdExpense(
        id: docSnap.id,
        title: data['title'] as String? ?? '',
        category: data['category'] as String? ?? 'Other',
        amount: (data['amount'] as num?)?.toDouble() ?? 0,
        createdAt: createdAt,
        source: data['source'] as String? ?? 'manual',
      );
    }).toList();
  }

  // Saved Shops serialization & persistence
  String _savedShopId(String shopName) =>
      'shop_${sha256.convert(utf8.encode(shopName.trim().toLowerCase()))}';

  String _legacySavedShopId(String shopName) =>
      shopName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Future<void> saveShop(String shopName) async {
    final doc = _userDoc;
    if (doc == null) throw Exception('User not authenticated.');
    final shopId = _savedShopId(shopName);
    await doc.collection('savedShops').doc(shopId).set({
      'shopName': shopName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeSavedShop(String shopName) async {
    final doc = _userDoc;
    if (doc == null) return;
    final collection = doc.collection('savedShops');
    final ids = <String>{
      _savedShopId(shopName),
      _legacySavedShopId(shopName),
    };
    await Future.wait(ids.map((id) => collection.doc(id).delete()));
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
