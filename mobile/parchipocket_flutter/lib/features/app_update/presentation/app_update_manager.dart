import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/android_update_platform.dart';
import '../data/apk_update_downloader.dart';
import '../data/github_beta_release_repository.dart';
import '../data/update_http.dart';
import '../domain/update_release.dart';

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  permissionRequired,
  waitingForInstaller,
  installationIncomplete,
  installed,
  unsupported,
  error,
}

class AppUpdateManager extends ChangeNotifier {
  AppUpdateManager({
    required GithubBetaReleaseRepository releaseRepository,
    required ApkUpdateDownloader downloader,
    required UpdatePlatform platform,
    SharedPreferences? preferences,
    DateTime Function()? clock,
    bool? isAndroid,
    VoidCallback? onDispose,
  }) : _releaseRepository = releaseRepository,
       _downloader = downloader,
       _platform = platform,
       _preferences = preferences,
       _clock = clock ?? DateTime.now,
       isAndroid = isAndroid ?? Platform.isAndroid,
       _onDispose = onDispose;

  factory AppUpdateManager.forAndroid({SharedPreferences? preferences}) {
    final transport = DartIoUpdateHttpTransport();
    const platform = AndroidUpdatePlatform();
    return AppUpdateManager(
      releaseRepository: GithubBetaReleaseRepository(transport),
      downloader: ApkUpdateDownloader(
        transport: transport,
        updateDirectory: platform.updateDirectory,
      ),
      platform: platform,
      preferences: preferences,
      onDispose: transport.close,
    );
  }

  static const Duration automaticCheckInterval = Duration(hours: 24);
  static const Duration promptDeferral = Duration(days: 7);
  static const String _lastAttemptKey = 'app_update.beta.last_attempt_ms';
  static const String _lastSuccessKey = 'app_update.beta.last_success_ms';
  static const String _deferredUntilKey = 'app_update.beta.deferred_until_ms';
  static const String _pendingVersionKey = 'app_update.pending_version_code';
  static const String _pendingPathKey = 'app_update.pending_apk_path';

  final GithubBetaReleaseRepository _releaseRepository;
  final ApkUpdateDownloader _downloader;
  final UpdatePlatform _platform;
  SharedPreferences? _preferences;
  final DateTime Function() _clock;
  final VoidCallback? _onDispose;
  final bool isAndroid;

  AppUpdateStatus status = AppUpdateStatus.idle;
  InstalledAppVersion? installedVersion;
  BetaRelease? availableRelease;
  VerifiedApk? verifiedApk;
  UpdateDownloadProgress? downloadProgress;
  String? errorMessage;
  Future<void>? _checkFuture;
  Future<void>? _downloadFuture;
  Future<void>? _resumeFuture;
  bool _sessionPromptDismissed = false;
  bool _isDisposed = false;

  bool get isChecking => status == AppUpdateStatus.checking;
  bool get isDownloading => status == AppUpdateStatus.downloading;
  bool get canInstall => verifiedApk != null;
  bool get isPromptDismissedForSession => _sessionPromptDismissed;

  Future<SharedPreferences?> get _prefs async {
    if (_preferences != null) return _preferences;
    try {
      return _preferences = await SharedPreferences.getInstance();
    } on Exception {
      return null;
    }
  }

  Future<bool> checkAutomatically() async {
    if (!isAndroid) {
      _setStatus(AppUpdateStatus.unsupported);
      return false;
    }
    await checkForUpdates();
    return true;
  }

  Future<void> checkForUpdates() {
    final running = _checkFuture;
    if (running != null) return running;
    late final Future<void> current;
    current = _performCheck().whenComplete(() {
      if (identical(_checkFuture, current)) _checkFuture = null;
    });
    _checkFuture = current;
    return current;
  }

  Future<void> _performCheck() async {
    if (!isAndroid) {
      _setStatus(AppUpdateStatus.unsupported);
      return;
    }
    errorMessage = null;
    _setStatus(AppUpdateStatus.checking);
    try {
      installedVersion = await _platform.installedVersion();
      final justInstalled = await _refreshPendingInstallOutcome();
      final release = await _releaseRepository.latestBeta();
      final prefs = await _prefs;
      await prefs?.setInt(_lastSuccessKey, _clock().millisecondsSinceEpoch);
      availableRelease = release;
      if (release != null &&
          shouldOfferUpdate(
            installedVersionCode: installedVersion!.code,
            release: release,
          )) {
        _setStatus(AppUpdateStatus.available);
      } else {
        availableRelease = null;
        _setStatus(
          justInstalled ? AppUpdateStatus.installed : AppUpdateStatus.upToDate,
        );
      }
    } on UpdateHttpException catch (error) {
      _fail(error.message);
    } on TimeoutException {
      _fail('The update check timed out. Check your connection and retry.');
    } on SocketException {
      _fail('Could not reach GitHub. Check your connection and retry.');
    } on FileSystemException catch (error) {
      _fail(error.message);
    } on FormatException catch (error) {
      _fail(error.message);
    } on Exception {
      _fail('Could not check for updates. Please try again.');
    }
  }

  Future<bool> shouldShowAutomaticPrompt() async {
    if (status != AppUpdateStatus.available) return false;
    if (_sessionPromptDismissed) return false;
    return true;
  }

  Future<void> deferAutomaticPrompt() async {
    _sessionPromptDismissed = true;
    final prefs = await _prefs;
    await prefs?.remove(_deferredUntilKey);
    await prefs?.remove(_lastAttemptKey);
  }

  Future<void> downloadAndInstall() {
    final running = _downloadFuture;
    if (running != null) return running;
    late final Future<void> current;
    current = _downloadAndInstall().whenComplete(() {
      if (identical(_downloadFuture, current)) _downloadFuture = null;
    });
    _downloadFuture = current;
    return current;
  }

  Future<void> _downloadAndInstall() async {
    final release = availableRelease;
    if (release == null) {
      _fail('Check for an available update before downloading.');
      return;
    }
    errorMessage = null;
    downloadProgress = null;
    _setStatus(AppUpdateStatus.downloading);
    try {
      final storage = await _platform.availableStorageBytes();
      verifiedApk = await _downloader.download(
        release,
        availableStorageBytes: storage,
        onProgress: (progress) {
          downloadProgress = progress;
          _notify();
        },
      );
      final prefs = await _prefs;
      await prefs?.setInt(_pendingVersionKey, release.versionCode);
      await prefs?.setString(_pendingPathKey, verifiedApk!.file.path);
      await _installVerifiedApk();
    } on InsufficientUpdateStorageException {
      _fail('There is not enough free space to download this update.');
    } on UpdateHttpException catch (error) {
      _fail(error.message);
    } on ConcurrentUpdateDownloadException {
      _fail('An update download is already in progress.');
    } on TimeoutException {
      _fail('The update download timed out. You can retry.');
    } on SocketException {
      _fail(
        'The update download was interrupted. Check your connection and retry.',
      );
    } on FileSystemException {
      _fail(
        'The update could not be saved. Check available storage and retry.',
      );
    } on FormatException catch (error) {
      _fail(error.message);
      verifiedApk = null;
    } on Exception {
      _fail('The update could not be prepared. Please retry.');
    }
  }

  Future<void> installVerifiedUpdate() async {
    if (verifiedApk == null) {
      await downloadAndInstall();
      return;
    }
    await _installVerifiedApk();
  }

  Future<void> _installVerifiedApk() async {
    final apk = verifiedApk;
    if (apk == null ||
        !await apk.file.exists() ||
        await apk.file.length() == 0) {
      verifiedApk = null;
      _fail(
        'The verified update file is no longer available. Download it again.',
      );
      return;
    }
    errorMessage = null;
    try {
      if (!await _platform.canRequestPackageInstalls()) {
        _setStatus(AppUpdateStatus.permissionRequired);
        return;
      }
      await _platform.installVerifiedApk(apk.file.path);
      _setStatus(AppUpdateStatus.waitingForInstaller);
    } on InstallPermissionRequiredException {
      _setStatus(AppUpdateStatus.permissionRequired);
    } on Exception {
      _fail('Android could not open the package installer. You can retry.');
    }
  }

  Future<void> openInstallPermissionSettings() async {
    try {
      await _platform.openInstallPermissionSettings();
    } on Exception {
      _fail('Could not open Android installation settings. You can retry.');
    }
  }

  Future<void> onAppResumed() {
    final running = _resumeFuture;
    if (running != null) return running;
    late final Future<void> current;
    current = _handleAppResumed().whenComplete(() {
      if (identical(_resumeFuture, current)) _resumeFuture = null;
    });
    _resumeFuture = current;
    return current;
  }

  Future<void> _handleAppResumed() async {
    if (!isAndroid) return;
    try {
      installedVersion = await _platform.installedVersion();
      final prefs = await _prefs;
      final pendingVersion = prefs?.getInt(_pendingVersionKey);
      if (pendingVersion != null && installedVersion!.code >= pendingVersion) {
        await _clearPendingApk();
        availableRelease = null;
        verifiedApk = null;
        errorMessage = null;
        _setStatus(AppUpdateStatus.installed);
        return;
      }
      if (status == AppUpdateStatus.permissionRequired) {
        if (await _platform.canRequestPackageInstalls()) {
          await _installVerifiedApk();
        }
      } else if (status == AppUpdateStatus.waitingForInstaller) {
        errorMessage =
            'Android did not complete the update. If Android reported a signing-certificate mismatch, this APK cannot update this installation. Uninstalling removes local app data; keep ParchiPocket installed until you choose a migration plan.';
        _setStatus(AppUpdateStatus.installationIncomplete);
      }
    } on Exception {
      if (status == AppUpdateStatus.waitingForInstaller) {
        _fail(
          'Could not confirm the installed version. Check again in a moment.',
        );
      }
    }
  }

  Future<bool> _refreshPendingInstallOutcome() async {
    final pendingVersion = (await _prefs)?.getInt(_pendingVersionKey);
    if (pendingVersion == null || installedVersion!.code < pendingVersion) {
      return false;
    }
    await _clearPendingApk();
    return true;
  }

  Future<void> _clearPendingApk() async {
    final prefs = await _prefs;
    final path = prefs?.getString(_pendingPathKey);
    if (path != null) {
      final updateDirectory = (await _platform.updateDirectory()).absolute.path
          .replaceAll('\\', '/');
      final file = File(path).absolute;
      final filePath = file.path.replaceAll('\\', '/');
      final prefix = '$updateDirectory/';
      if (filePath.startsWith(prefix) && await file.exists()) {
        await file.delete();
      }
    }
    await prefs?.remove(_pendingPathKey);
    await prefs?.remove(_pendingVersionKey);
  }

  void _fail(String message) {
    errorMessage = message;
    _setStatus(AppUpdateStatus.error);
  }

  void _setStatus(AppUpdateStatus value) {
    status = value;
    _notify();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _onDispose?.call();
    super.dispose();
  }
}
