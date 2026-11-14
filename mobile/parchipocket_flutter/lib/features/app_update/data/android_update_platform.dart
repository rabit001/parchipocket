import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/update_release.dart';

abstract interface class UpdatePlatform {
  Future<Directory> updateDirectory();
  Future<int> availableStorageBytes();
  Future<InstalledAppVersion> installedVersion();
  Future<bool> canRequestPackageInstalls();
  Future<void> openInstallPermissionSettings();
  Future<void> installVerifiedApk(String path);
}

class InstallPermissionRequiredException implements Exception {
  const InstallPermissionRequiredException();
}

class AndroidUpdatePlatform implements UpdatePlatform {
  const AndroidUpdatePlatform();

  static const MethodChannel _channel = MethodChannel(
    'com.parchipocket.app/update_installer',
  );

  @override
  Future<Directory> updateDirectory() async {
    final path = await _channel.invokeMethod<String>('getUpdateDirectory');
    if (path == null || path.isEmpty) {
      throw const FileSystemException(
        'The app update directory is unavailable.',
      );
    }
    return Directory(path);
  }

  @override
  Future<int> availableStorageBytes() async =>
      await _channel.invokeMethod<int>('getAvailableStorageBytes') ?? 0;

  @override
  Future<InstalledAppVersion> installedVersion() async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'getInstalledVersion',
    );
    final name = value?['versionName'];
    final code = value?['versionCode'];
    if (name is! String || code is! int) {
      throw const FormatException(
        'Android did not return the installed app version.',
      );
    }
    return InstalledAppVersion(name: name, code: code);
  }

  @override
  Future<bool> canRequestPackageInstalls() async =>
      await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;

  @override
  Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  @override
  Future<void> installVerifiedApk(String path) async {
    try {
      await _channel.invokeMethod<void>('installVerifiedApk', <String, Object?>{
        'path': path,
      });
    } on PlatformException catch (error) {
      if (error.code == 'install_permission_required') {
        throw const InstallPermissionRequiredException();
      }
      rethrow;
    }
  }
}
