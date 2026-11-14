import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/features/account_deletion/data/account_deletion_service.dart';
import 'package:parchipocket/features/customer/presentation/customer_screens.dart';
import 'package:parchipocket/features/customer/data/profile_photo_store.dart';

class _FakeProfilePhotoStore implements ProfilePhotoStore {
  final Map<String, String> savedPhotos = <String, String>{};
  String? pickedPath = 'local/photo.jpg';
  Object? pickError;
  Object? clearError;
  Completer<String?>? pendingPick;

  @override
  Future<String?> load(String uid) async => savedPhotos[uid];

  @override
  Future<String?> pickAndPersist(String uid) async {
    if (pickError case final error?) throw error;
    final pending = pendingPick;
    final path = pending == null ? pickedPath : await pending.future;
    if (path == null) return null;
    return savedPhotos[uid] = path;
  }

  @override
  Future<void> clear(String uid) async {
    if (clearError case final error?) throw error;
    savedPhotos.remove(uid);
  }
}

class _TestImagePicker extends Fake implements ImagePicker {
  XFile? nextImage;

  @override
  Future<LostDataResponse> retrieveLostData() async => LostDataResponse.empty();

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      nextImage;
}

class _FakeAccountDeletionService extends Fake implements AccountDeletionService {
  @override
  Future<Map<String, dynamic>> invokeDeletion({
    bool skipFreshnessCheckForTest = false,
  }) async =>
      <String, dynamic>{
        'success': true,
        'completed': true,
        'message': 'Account and data deleted.',
      };
}

void main() {
  testWidgets('mobile number can be edited without claiming verification', (
    tester,
  ) async {
    final state = AppState()..page = 'editProfile';
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: EditProfileScreen(state: state)));

    final mobileField = find.byKey(const ValueKey('profile-mobile-number'));
    expect(mobileField, findsOneWidget);
    expect(tester.widget<TextField>(mobileField).readOnly, isFalse);
    expect(find.textContaining('not verified'), findsOneWidget);
  });

  testWidgets('valid mobile number is saved to the profile state', (
    tester,
  ) async {
    final state = AppState()..page = 'editProfile';
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: EditProfileScreen(state: state)));
    await tester.enterText(
      find.byKey(const ValueKey('profile-mobile-number')),
      '+91 98765 43210',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(state.profileMobileNumber, '+919876543210');
  });

  testWidgets('saved mobile number is prefilled when profile is reopened', (
    tester,
  ) async {
    final state =
        AppState()
          ..page = 'editProfile'
          ..profileMobileNumber = '+919876543210';
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: EditProfileScreen(state: state)));
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('profile-mobile-number')),
          )
          .controller
          ?.text,
      '+919876543210',
    );
  });

  testWidgets('profile offers a persistent photo picker action', (
    tester,
  ) async {
    final state = AppState(profilePhotoStore: _FakeProfilePhotoStore())
      ..page = 'customerProfile';
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(home: CustomerProfileScreen(state: state)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.isProfilePhotoLoading, isFalse);
    expect(find.byKey(const ValueKey('profile-photo-action')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-photo-action')));
    await tester.pump();
    await tester.pump();
    expect(state.profilePhotoPath, 'local/photo.jpg');
    expect(find.textContaining('saved on this device only'), findsOneWidget);
  });

  test(
    'profile photo storage is scoped to the Firebase UID and survives reload',
    () async {
      final store = _FakeProfilePhotoStore();
      const uid = 'google-account-uid';
      final first =
          AppState(profilePhotoStore: store)
            ..auth = _FakeFirebaseAuth(uid)
            ..isDemoMode = false;

      expect(await first.chooseProfilePhoto(), isTrue);
      expect(store.savedPhotos, containsPair(uid, 'local/photo.jpg'));
      first.dispose();

      final reopened =
          AppState(profilePhotoStore: store)
            ..auth = _FakeFirebaseAuth(uid)
            ..isDemoMode = false;
      await reopened.loadProfilePhoto();
      expect(reopened.profilePhotoPath, 'local/photo.jpg');
      reopened.dispose();
    },
  );

  test(
    'photo picker cancellation preserves the current profile photo',
    () async {
      final store = _FakeProfilePhotoStore()..pickedPath = null;
      final state = AppState(profilePhotoStore: store)
        ..profilePhotoPath = 'local/previous.jpg';

      expect(await state.chooseProfilePhoto(), isFalse);
      expect(state.profilePhotoPath, 'local/previous.jpg');
      expect(state.profilePhotoError, isNull);
      expect(state.isProfilePhotoLoading, isFalse);
      state.dispose();
    },
  );

  test(
    'photo picker errors leave the current photo and loading state intact',
    () async {
      final store =
          _FakeProfilePhotoStore()
            ..pickError = const FormatException('Choose a supported image.');
      final state = AppState(profilePhotoStore: store)
        ..profilePhotoPath = 'local/previous.jpg';

      expect(await state.chooseProfilePhoto(), isFalse);
      expect(state.profilePhotoPath, 'local/previous.jpg');
      expect(state.profilePhotoError, 'Choose a supported image.');
      expect(state.isProfilePhotoLoading, isFalse);
      state.dispose();
    },
  );

  test(
    'duplicate photo picker requests are rejected while one is pending',
    () async {
      final pending = Completer<String?>();
      final store = _FakeProfilePhotoStore()..pendingPick = pending;
      final state = AppState(profilePhotoStore: store);

      final firstPick = state.chooseProfilePhoto();
      expect(state.isProfilePhotoLoading, isTrue);
      expect(await state.chooseProfilePhoto(), isFalse);
      pending.complete('local/photo.jpg');
      expect(await firstPick, isTrue);
      expect(state.isProfilePhotoLoading, isFalse);
      state.dispose();
    },
  );

  test(
    'DeviceProfilePhotoStore deletes obsolete images after successful persistence',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('pp_photo_cleanup_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      SharedPreferences.setMockInitialValues({});

      final picker = _TestImagePicker();
      final store = DeviceProfilePhotoStore(
        picker: picker,
        documentsDirectory: () async => tempDir,
      );

      final file1 = File('${tempDir.path}/first.jpg')..writeAsBytesSync([1, 2, 3]);
      picker.nextImage = XFile(file1.path, name: 'first.jpg');
      final path1 = await store.pickAndPersist('user123');
      expect(path1, isNotNull);
      expect(File(path1!).existsSync(), isTrue);

      final file2 = File('${tempDir.path}/second.png')..writeAsBytesSync([4, 5, 6]);
      picker.nextImage = XFile(file2.path, name: 'second.png');
      final path2 = await store.pickAndPersist('user123');
      expect(path2, isNotNull);
      expect(File(path2!).existsSync(), isTrue);

      // Previous photo file was cleaned up; only latest photo remains in the user directory
      expect(File(path1).existsSync(), isFalse);
      final userDir = Directory('${tempDir.path}/profile_photos/user123');
      final remainingFiles = userDir.listSync().whereType<File>().toList();
      expect(remainingFiles.length, 1);
      expect(
        File(remainingFiles.first.path).resolveSymbolicLinksSync(),
        File(path2).resolveSymbolicLinksSync(),
      );
    },
  );

  test(
    'failed replacement preserves the previous photo and reference',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('pp_photo_fail_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      SharedPreferences.setMockInitialValues({});

      final picker = _TestImagePicker();
      final store = DeviceProfilePhotoStore(
        picker: picker,
        documentsDirectory: () async => tempDir,
      );

      final file1 = File('${tempDir.path}/first.jpg')..writeAsBytesSync([1, 2, 3]);
      picker.nextImage = XFile(file1.path, name: 'first.jpg');
      final path1 = await store.pickAndPersist('user123');
      expect(path1, isNotNull);
      expect(File(path1!).existsSync(), isTrue);

      final file2 = File('${tempDir.path}/unsupported.gif')..writeAsBytesSync([4, 5, 6]);
      picker.nextImage = XFile(file2.path, name: 'unsupported.gif');
      await expectLater(
        store.pickAndPersist('user123'),
        throwsA(isA<FormatException>()),
      );

      // Previous photo and reference remain intact
      expect(File(path1).existsSync(), isTrue);
      final loaded = await store.load('user123');
      expect(loaded, path1);
    },
  );

  test('account deletion cleans only the target UID profile photo', () async {
    final store = _FakeProfilePhotoStore();
    store.savedPhotos['target_user'] = 'path/to/target.jpg';
    store.savedPhotos['other_user'] = 'path/to/other.jpg';

    final state = AppState(
      profilePhotoStore: store,
      accountDeletionService: _FakeAccountDeletionService(),
    )
      ..auth = _FakeFirebaseAuth('target_user')
      ..isDemoMode = false
      ..profilePhotoPath = 'path/to/target.jpg'
      ..deletionVerificationId = 'test-verification-id';

    final deleted = await state.deleteAccountWithOtp('123456');
    expect(deleted, isTrue);
    expect(store.savedPhotos.containsKey('target_user'), isFalse);
    expect(store.savedPhotos['other_user'], 'path/to/other.jpg');
    state.dispose();
  });

  test('ordinary sign-out does not accidentally delete the stored photo', () async {
    final store = _FakeProfilePhotoStore();
    store.savedPhotos['signed_in_user'] = 'path/to/saved.jpg';

    final state = AppState(profilePhotoStore: store)
      ..auth = _FakeFirebaseAuth('signed_in_user')
      ..isDemoMode = false
      ..profilePhotoPath = 'path/to/saved.jpg';

    await state.signOut();
    expect(store.savedPhotos['signed_in_user'], 'path/to/saved.jpg');

    // Re-signing in restores the photo
    final reopened = AppState(profilePhotoStore: store)
      ..auth = _FakeFirebaseAuth('signed_in_user')
      ..isDemoMode = false;
    await reopened.loadProfilePhoto();
    expect(reopened.profilePhotoPath, 'path/to/saved.jpg');
    reopened.dispose();
    state.dispose();
  });

  testWidgets(
    'Remove Photo action confirms before removing and restores fallback',
    (tester) async {
      final store = _FakeProfilePhotoStore();
      store.savedPhotos['demo'] = 'local/custom_photo.jpg';

      final state = AppState(profilePhotoStore: store)
        ..profilePhotoPath = 'local/custom_photo.jpg'
        ..page = 'customerProfile';
      addTearDown(state.dispose);

      await tester.pumpWidget(
        MaterialApp(home: CustomerProfileScreen(state: state)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final removeButton = find.byKey(const ValueKey('profile-photo-remove-action'));
      expect(removeButton, findsOneWidget);
      expect(find.text('Change photo'), findsOneWidget);

      // Tap remove photo -> dialog appears
      await tester.tap(removeButton);
      await tester.pumpAndSettle();
      expect(find.text('Remove photo'), findsNWidgets(2)); // Button label + dialog title
      expect(find.text('Are you sure you want to remove your custom profile photo from this device?'), findsOneWidget);

      // Cancel dialog -> photo is preserved
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(state.profilePhotoPath, 'local/custom_photo.jpg');
      expect(find.byKey(const ValueKey('profile-photo-remove-action')), findsOneWidget);

      // Tap remove photo again and confirm
      await tester.tap(removeButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      // Custom photo removed, button gone, Add photo restored
      expect(state.profilePhotoPath, isNull);
      expect(store.savedPhotos.containsKey('demo'), isFalse);
      expect(find.byKey(const ValueKey('profile-photo-remove-action')), findsNothing);
      expect(find.text('Add photo'), findsOneWidget);
    },
  );

  test('Remove Photo failure preserves photo and reports error', () async {
    final store = _FakeProfilePhotoStore()
      ..savedPhotos['user123'] = 'local/photo.jpg'
      ..clearError = const FormatException('Filesystem lock error.');

    final state = AppState(profilePhotoStore: store)
      ..auth = _FakeFirebaseAuth('user123')
      ..isDemoMode = false
      ..profilePhotoPath = 'local/photo.jpg';

    final removed = await state.removeProfilePhoto();
    expect(removed, isFalse);
    expect(state.profilePhotoPath, 'local/photo.jpg');
    expect(state.profilePhotoError, 'Filesystem lock error.');
    expect(state.isProfilePhotoLoading, isFalse);
    state.dispose();
  });

  testWidgets(
    'Google profile image and demo mode fallbacks work correctly',
    (tester) async {
      // 1. Google user with photoURL and no custom photo
      final googleState = AppState(profilePhotoStore: _FakeProfilePhotoStore())
        ..auth = _FakeFirebaseAuth('google_user', photoURL: 'https://example.com/avatar.jpg')
        ..isDemoMode = false
        ..page = 'customerProfile';
      addTearDown(googleState.dispose);

      await tester.pumpWidget(
        MaterialApp(home: CustomerProfileScreen(state: googleState)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Add photo'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-photo-remove-action')), findsNothing);

      // 2. Demo mode with no custom photo -> shows initials 'RM'
      final demoState = AppState(profilePhotoStore: _FakeProfilePhotoStore())
        ..page = 'customerProfile';
      addTearDown(demoState.dispose);

      await tester.pumpWidget(
        MaterialApp(home: CustomerProfileScreen(state: demoState)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('RM'), findsOneWidget);
      expect(find.text('Add photo'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-photo-remove-action')), findsNothing);
    },
  );
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  _FakeFirebaseAuth(this._uid, {this.photoURL});

  final String _uid;
  final String? photoURL;

  @override
  User? get currentUser => _FakeFirebaseUser(_uid, photoURL: photoURL);

  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();

  @override
  Future<void> signOut() async {}
}

class _FakeFirebaseUser extends Fake implements User {
  _FakeFirebaseUser(this.uid, {this.photoURL});

  @override
  final String uid;

  @override
  final String? photoURL;

  @override
  String? get phoneNumber => '+919876543210';

  @override
  Future<UserCredential> reauthenticateWithCredential(AuthCredential credential) async =>
      _FakeUserCredential(this);
}

class _FakeUserCredential extends Fake implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User user;
}
