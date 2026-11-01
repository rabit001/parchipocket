// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/services/firestore_service.dart';

class FakeQueryDocSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  FakeQueryDocSnapshot(this._data);
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;
}

class FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  FakeQuerySnapshot(this._docs);
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;
}

class FakeReceiptDocSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  FakeReceiptDocSnapshot({required this.exists, this.docData});
  @override
  final bool exists;
  final Map<String, dynamic>? docData;

  @override
  Map<String, dynamic>? data() => docData;
}

class FakeBillsCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  FakeBillsCollectionReference(this.receiptStore);
  final Map<String, FakeReceiptDocSnapshot> receiptStore;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeReceiptDocRef(path ?? '', receiptStore);
  }
}

class FakeReceiptDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  FakeReceiptDocRef(this.billId, this.receiptStore);
  final String billId;
  final Map<String, FakeReceiptDocSnapshot> receiptStore;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return receiptStore[billId] ?? FakeReceiptDocSnapshot(exists: false);
  }
}

class FakeOwnerDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  FakeOwnerDocRef(this.ownerUid, this.receiptStore);
  final String ownerUid;
  final Map<String, FakeReceiptDocSnapshot> receiptStore;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'bills') {
      return FakeBillsCollectionReference(receiptStore);
    }
    throw UnimplementedError('collection $collectionPath');
  }
}

class FakeClaimedReceiptsCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  FakeClaimedReceiptsCollection(this.receiptStore);
  final Map<String, FakeReceiptDocSnapshot> receiptStore;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeOwnerDocRef(path ?? '', receiptStore);
  }
}

class FakeClaimIndexCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  FakeClaimIndexCollection(this.indexDocs);
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> indexDocs;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return FakeQuerySnapshot(indexDocs);
  }
}

class FakeUserDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  FakeUserDocRef({
    required this.indexDocs,
    required this.receiptStore,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> indexDocs;
  final Map<String, FakeReceiptDocSnapshot> receiptStore;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'claimedReceiptsIndex') {
      return FakeClaimIndexCollection(indexDocs);
    }
    if (collectionPath == 'claimedReceipts') {
      return FakeClaimedReceiptsCollection(receiptStore);
    }
    throw UnimplementedError('collection $collectionPath');
  }
}

class FakeUsersCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  FakeUsersCollection(this.userDoc);
  final FakeUserDocRef userDoc;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => userDoc;
}

class FakeFirestore extends Fake implements FirebaseFirestore {
  FakeFirestore(this.userDoc);
  final FakeUserDocRef userDoc;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'users') {
      return FakeUsersCollection(userDoc);
    }
    throw UnimplementedError('collection $collectionPath');
  }
}

class FakeAuthUser extends Fake implements User {
  @override
  String get uid => 'customer-uid-123';
}

class FakeReceiptAuth extends Fake implements FirebaseAuth {
  FakeReceiptAuth([this._user]);
  final User? _user;

  @override
  User? get currentUser => _user;
}

void main() {
  group('Claimed Receipt Query Optimization', () {
    test('Empty claim index returns empty list immediately', () async {
      final userDoc = FakeUserDocRef(
        indexDocs: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        receiptStore: <String, FakeReceiptDocSnapshot>{},
      );
      final service = FirestoreService(
        firestore: FakeFirestore(userDoc),
        auth: FakeReceiptAuth(FakeAuthUser()),
      );

      final results = await service.loadClaimedReceipts();
      expect(results, isEmpty);
    });

    test('Unauthenticated user returns empty list without error', () async {
      final userDoc = FakeUserDocRef(
        indexDocs: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        receiptStore: <String, FakeReceiptDocSnapshot>{},
      );
      final service = FirestoreService(
        firestore: FakeFirestore(userDoc),
        auth: FakeReceiptAuth(null),
      );

      final results = await service.loadClaimedReceipts();
      expect(results, isEmpty);
    });

    test('Multiple receipts load in bounded parallel batches and sort descending by claimedAt', () async {
      const receiptCount = 25;
      final indexDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final receiptStore = <String, FakeReceiptDocSnapshot>{};

      for (var i = 0; i < receiptCount; i++) {
        final billId = 'bill-$i';
        indexDocs.add(FakeQueryDocSnapshot(<String, dynamic>{
          'ownerUid': 'seller-1',
          'sourceBillId': billId,
        }));

        final claimedTime = DateTime(2026, 10, 1, 10, 0).add(Duration(hours: i));
        receiptStore[billId] = FakeReceiptDocSnapshot(
          exists: true,
          docData: <String, dynamic>{
            'receipt': <String, dynamic>{
              'id': billId,
              'store': 'Kirana Store',
              'paymentMode': 'Cash',
              'createdAt': Timestamp.fromDate(claimedTime),
              'items': <dynamic>[
                <String, dynamic>{
                  'name': 'Atta',
                  'quantity': 1,
                  'unitPrice': 250.0,
                }
              ],
            },
            'claimedAt': Timestamp.fromDate(claimedTime),
          },
        );
      }

      final userDoc = FakeUserDocRef(
        indexDocs: indexDocs,
        receiptStore: receiptStore,
      );
      final service = FirestoreService(
        firestore: FakeFirestore(userDoc),
        auth: FakeReceiptAuth(FakeAuthUser()),
      );

      final results = await service.loadClaimedReceipts();
      expect(results.length, receiptCount);

      // Verify strict descending ordering by claimedAt
      for (var i = 0; i < results.length - 1; i++) {
        final current = results[i].claimedAt;
        final next = results[i + 1].claimedAt;
        expect(current.isAfter(next) || current.isAtSameMomentAs(next), isTrue);
      }
      expect(results.first.sourceBillId, 'bill-24');
      expect(results.last.sourceBillId, 'bill-0');
    });

    test('Missing receipt copy throws ReceiptClaimException with specific notice', () async {
      final indexDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
        FakeQueryDocSnapshot(<String, dynamic>{
          'ownerUid': 'seller-1',
          'sourceBillId': 'bill-existing',
        }),
        FakeQueryDocSnapshot(<String, dynamic>{
          'ownerUid': 'seller-1',
          'sourceBillId': 'bill-missing',
        }),
      ];

      final receiptStore = <String, FakeReceiptDocSnapshot>{
        'bill-existing': FakeReceiptDocSnapshot(
          exists: true,
          docData: <String, dynamic>{
            'receipt': <String, dynamic>{
              'id': 'bill-existing',
              'store': 'Store',
              'paymentMode': 'Cash',
              'createdAt': Timestamp.now(),
              'items': <dynamic>[],
            },
            'claimedAt': Timestamp.now(),
          },
        ),
        'bill-missing': FakeReceiptDocSnapshot(exists: false),
      };

      final userDoc = FakeUserDocRef(
        indexDocs: indexDocs,
        receiptStore: receiptStore,
      );
      final service = FirestoreService(
        firestore: FakeFirestore(userDoc),
        auth: FakeReceiptAuth(FakeAuthUser()),
      );

      expect(
        () async => await service.loadClaimedReceipts(),
        throwsA(
          isA<ReceiptClaimException>().having(
            (e) => e.message,
            'message',
            contains('A saved receipt copy is missing. Contact support before retrying this claim.'),
          ),
        ),
      );
    });
  });
}
