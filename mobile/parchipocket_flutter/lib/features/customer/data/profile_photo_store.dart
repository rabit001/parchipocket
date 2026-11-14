import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ProfilePhotoStore {
  Future<String?> load(String uid);
  Future<String?> pickAndPersist(String uid);
  Future<void> clear(String uid);
}

class DeviceProfilePhotoStore implements ProfilePhotoStore {
  DeviceProfilePhotoStore({
    ImagePicker? picker,
    Future<Directory> Function()? documentsDirectory,
    Future<SharedPreferences> Function()? preferences,
  })  : _picker = picker ?? ImagePicker(),
        _documentsDirectory = documentsDirectory ?? _defaultDocumentsDirectory,
        _preferences = preferences ?? _defaultPreferences;

  final ImagePicker _picker;
  final Future<Directory> Function() _documentsDirectory;
  final Future<SharedPreferences> Function() _preferences;

  static Future<Directory> _defaultDocumentsDirectory() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Directory.systemTemp;
    }
    return getApplicationDocumentsDirectory();
  }

  static Future<SharedPreferences> _defaultPreferences() =>
      SharedPreferences.getInstance();

  String _key(String uid) => 'profile_photo_$uid';
  String get _pendingKey => 'profile_photo_pending_uid';

  @override
  Future<String?> load(String uid) async {
    final SharedPreferences preferences;
    try {
      preferences = await _preferences();
    } catch (_) {
      return null;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final lostData = await _picker.retrieveLostData();
        final recovered = lostData.files;
        final pendingUid = preferences.getString(_pendingKey);
        if (recovered != null && recovered.isNotEmpty) {
          if (pendingUid != null) {
            await _persist(pendingUid, recovered.first, preferences);
          }
        } else {
          await preferences.remove(_pendingKey);
        }
        if (pendingUid != null) await preferences.remove(_pendingKey);
        if (lostData.exception != null) throw lostData.exception!;
      } on MissingPluginException {
        // Widget tests and unsupported embedder contexts have no Android picker.
      }
    }
    final path = preferences.getString(_key(uid));
    if (path == null || !await File(path).exists()) {
      if (path != null) await preferences.remove(_key(uid));
      return null;
    }
    return path;
  }

  @override
  Future<String?> pickAndPersist(String uid) async {
    final preferences = await _preferences();
    await preferences.setString(_pendingKey, uid);
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 88,
      );
      if (image == null) {
        await preferences.remove(_pendingKey);
        return null;
      }
      final path = await _persist(uid, image, preferences);
      await preferences.remove(_pendingKey);
      return path;
    } catch (_) {
      await preferences.remove(_pendingKey);
      rethrow;
    }
  }

  Future<String> _persist(
    String uid,
    XFile image,
    SharedPreferences preferences,
  ) async {
    final extension = image.name.split('.').last.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw const FormatException('Choose a JPG, PNG or WebP image.');
    }
    final source = File(image.path);
    final size = await source.length();
    if (size > 10 * 1024 * 1024) {
      throw const FormatException('Choose an image smaller than 10 MB.');
    }

    final safeUid = uid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final directory = Directory(
      '${(await _documentsDirectory()).path}${Platform.pathSeparator}profile_photos${Platform.pathSeparator}$safeUid',
    );
    await directory.create(recursive: true);
    final destination = File(
      '${directory.path}${Platform.pathSeparator}profile_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await source.copy(destination.path);

    try {
      await preferences.setString(_key(uid), destination.path);
    } catch (_) {
      try {
        await destination.delete();
      } on FileSystemException {
        // The unreferenced file is private app data and can be cleaned later.
      }
      rethrow;
    }

    try {
      await for (final entity in directory.list()) {
        if (entity is File && entity.path != destination.path) {
          try {
            await entity.delete();
          } on FileSystemException {
            // Ignore individual file deletion errors to keep the operation safe.
          }
        }
      }
    } catch (_) {
      // Directory listing errors handled safely.
    }

    return destination.path;
  }

  @override
  Future<void> clear(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return;
    try {
      final preferences = await _preferences();
      await preferences.remove(_key(cleanUid));
    } on MissingPluginException {
      // Widget tests and unsupported embedder contexts.
    } on PlatformException {
      // Platform channel exceptions in tests without mock handlers.
    }

    try {
      final safeUid = cleanUid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final docsDir = await _documentsDirectory();
      final directory = Directory(
        '${docsDir.path}${Platform.pathSeparator}profile_photos${Platform.pathSeparator}$safeUid',
      );
      if (await directory.exists()) {
        try {
          await directory.delete(recursive: true);
        } on FileSystemException {
          try {
            await for (final entity in directory.list()) {
              if (entity is File) {
                try {
                  await entity.delete();
                } on FileSystemException {
                  // Ignore individual file deletion errors to allow sweeping remaining files.
                }
              }
            }
            await directory.delete();
          } on FileSystemException {
            rethrow;
          }
        }
      }
    } on MissingPluginException {
      // Widget tests and unsupported embedder contexts.
    } on PlatformException {
      // Platform channel exceptions in tests without mock handlers.
    }
  }
}
