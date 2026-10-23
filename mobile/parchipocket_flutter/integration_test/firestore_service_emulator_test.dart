import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/services/firestore_service.dart';

const _projectId = 'demo-parchipocket-phase3';
const _emulatorHost = '10.0.2.2';
const _firestorePort = 8088;
const _authPort = 9099;

late FirebaseApp _firebaseApp;
late FirebaseAuth _auth;
late FirebaseFirestore _firestore;
late FirestoreService _service;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!_projectId.startsWith('demo-') || _emulatorHost != '10.0.2.2') {
      throw StateError('Integration tests must use the local demo Firebase Emulator project.');
    }

    _firebaseApp = await Firebase.initializeApp(
      name: 'parchipocket-phase3-emulator-tests',
      options: const FirebaseOptions(
        apiKey: 'fake-emulator-api-key',
        appId: '1:123456789012:android:0123456789abcdef',
        messagingSenderId: '123456789012',
        projectId: _projectId,
      ),
    );
    _auth = FirebaseAuth.instanceFor(app: _firebaseApp);
    await _auth.useAuthEmulator(_emulatorHost, _authPort);

    _firestore = FirebaseFirestore.instanceFor(app: _firebaseApp);
    _firestore.settings = const Settings(persistenceEnabled: false);
    _firestore.useFirestoreEmulator(_emulatorHost, _firestorePort);
    _service = FirestoreService(firestore: _firestore, auth: _auth);
  });

  setUp(() async {
    await _auth.signInAnonymously();
  });

  tearDown(() async {
    await _auth.signOut();
  });

  testWidgets('FirestoreService creates bills under matching document IDs and owner can read/update', (tester) async {
    final bill = _newBill();

    await _service.createBill(bill);

    final reference = _billReference(_auth.currentUser!.uid, bill.id);
    final snapshot = await reference.get();
    expect(snapshot.exists, isTrue);
    expect(reference.id, bill.id);
    expect(snapshot.data()!['id'], bill.id);
    expect(snapshot.data()!['store'], bill.store);

    await _service.saveBill(_copyBill(bill, isSaved: true));
    expect((await reference.get()).data()!['isSaved'], isTrue);
  });

  testWidgets('identical create retry is idempotent and conflicting ID cannot overwrite', (tester) async {
    final bill = _newBill();
    final reference = _billReference(_auth.currentUser!.uid, bill.id);

    await _service.createBill(bill);
    final original = (await reference.get()).data()!;
    await _service.createBill(bill);

    final bills = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('bills')
        .get();
    expect(bills.docs, hasLength(1));

    final conflictingBill = DemoBill(
      id: bill.id,
      store: 'Different Store',
      items: <BillLine>[BillLine(name: 'Changed item', quantity: 1, unitPrice: 999)],
      createdAt: bill.createdAt,
      paymentMode: bill.paymentMode,
      customerPhone: bill.customerPhone,
      isUdhaar: bill.isUdhaar,
      isSettled: bill.isSettled,
      isSaved: bill.isSaved,
    );
    await expectLater(
      _service.createBill(conflictingBill),
      throwsA(isA<BillIdCollisionException>()),
    );
    expect((await reference.get()).data(), equals(original));
  });

  testWidgets('saveBill cannot recreate a missing document', (tester) async {
    final missingBill = _newBill(id: 'missing-bill-document');
    final reference = _billReference(_auth.currentUser!.uid, missingBill.id);

    await expectLater(
      _service.saveBill(_copyBill(missingBill, isSaved: true)),
      throwsA(isA<FirebaseException>()),
    );
    expect((await reference.get()).exists, isFalse);
  });

  testWidgets('another authenticated user cannot read or modify the owner bill', (tester) async {
    final ownerUid = _auth.currentUser!.uid;
    final bill = _newBill();
    await _service.createBill(bill);
    final ownerBill = _billReference(ownerUid, bill.id);

    await _auth.signOut();
    await _auth.signInAnonymously();
    expect(_auth.currentUser!.uid, isNot(ownerUid));

    await expectLater(
      ownerBill.get(),
      throwsA(isA<FirebaseException>().having((error) => error.code, 'code', 'permission-denied')),
    );
    await expectLater(
      ownerBill.update(<String, Object>{'isSaved': true}),
      throwsA(isA<FirebaseException>().having((error) => error.code, 'code', 'permission-denied')),
    );
  });
}

DemoBill _newBill({String? id}) => DemoBill(
      id: id ?? _service.newBillId(),
      store: 'Emulator Test Shop',
      items: <BillLine>[BillLine(name: 'Tea', quantity: 2, unitPrice: 10)],
      createdAt: DateTime.utc(2026, 10, 23, 12),
      paymentMode: 'Cash',
      customerPhone: '+919876543210',
      isUdhaar: false,
      isSettled: false,
      isSaved: false,
    );

DemoBill _copyBill(DemoBill bill, {required bool isSaved}) => DemoBill(
      id: bill.id,
      store: bill.store,
      items: bill.items,
      createdAt: bill.createdAt,
      paymentMode: bill.paymentMode,
      customerPhone: bill.customerPhone,
      isUdhaar: bill.isUdhaar,
      isSettled: bill.isSettled,
      isSaved: isSaved,
    );

DocumentReference<Map<String, dynamic>> _billReference(String uid, String id) =>
    _firestore.collection('users').doc(uid).collection('bills').doc(id);
