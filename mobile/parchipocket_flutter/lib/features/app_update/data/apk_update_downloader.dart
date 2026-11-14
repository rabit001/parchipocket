import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/update_release.dart';
import 'update_http.dart';

class UpdateDownloadProgress {
  const UpdateDownloadProgress(this.receivedBytes, this.totalBytes);

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction =>
      totalBytes == null || totalBytes == 0
          ? null
          : (receivedBytes / totalBytes!).clamp(0, 1);
}

class VerifiedApk {
  const VerifiedApk({required this.file, required this.sha256});

  final File file;
  final String sha256;
}

class ConcurrentUpdateDownloadException implements Exception {
  const ConcurrentUpdateDownloadException();
}

class InsufficientUpdateStorageException implements Exception {
  const InsufficientUpdateStorageException();
}

class ApkUpdateDownloader {
  ApkUpdateDownloader({
    required UpdateHttpTransport transport,
    required Future<Directory> Function() updateDirectory,
  }) : _transport = transport,
       _updateDirectory = updateDirectory;

  static const int maximumApkBytes = 500 * 1024 * 1024;
  final UpdateHttpTransport _transport;
  final Future<Directory> Function() _updateDirectory;
  bool _downloading = false;

  Future<VerifiedApk> download(
    BetaRelease release, {
    required int? availableStorageBytes,
    void Function(UpdateDownloadProgress progress)? onProgress,
  }) async {
    if (_downloading) throw const ConcurrentUpdateDownloadException();
    _downloading = true;
    File? partialFile;
    IOSink? output;
    var digestClosed = false;
    final digestSink = _DigestSink();
    final digestInput = sha256.startChunkedConversion(digestSink);
    try {
      final directory = await _updateDirectory();
      await directory.create(recursive: true);
      final baseName = 'parchipocket-update-${release.versionCode}.apk';
      final destination = File(
        '${directory.path}${Platform.pathSeparator}$baseName',
      );
      partialFile = File('${destination.path}.part');

      final response = await getFollowingGithubRedirects(
        _transport,
        release.apkDownloadUrl,
      );
      if (response.statusCode != 200) {
        throw UpdateHttpException(
          response.statusCode,
          'The update download failed (HTTP ${response.statusCode}).',
        );
      }
      final expectedLength = response.contentLength;
      if (expectedLength != null && expectedLength > maximumApkBytes) {
        throw const FormatException('The update APK is too large to download.');
      }
      if (expectedLength != null &&
          availableStorageBytes != null &&
          availableStorageBytes < expectedLength) {
        throw const InsufficientUpdateStorageException();
      }

      output = partialFile.openWrite(mode: FileMode.writeOnly);
      var received = 0;
      await for (final chunk in response.body.timeout(
        const Duration(seconds: 45),
      )) {
        received += chunk.length;
        if (received > maximumApkBytes ||
            (expectedLength != null && received > expectedLength)) {
          throw const FormatException(
            'The update download exceeded its expected size.',
          );
        }
        digestInput.add(chunk);
        output.add(chunk);
        onProgress?.call(UpdateDownloadProgress(received, expectedLength));
      }
      if (expectedLength != null && received != expectedLength) {
        throw const UpdateNetworkException(
          'The update download was incomplete.',
        );
      }
      await output.flush();
      await output.close();
      output = null;
      digestInput.close();
      digestClosed = true;
      if (received <= 0 || !await partialFile.exists()) {
        throw const UpdateNetworkException('The downloaded APK is empty.');
      }
      final actualHash = digestSink.digest.toString();
      if (actualHash != release.sha256) {
        throw const FormatException(
          'The downloaded APK failed its SHA-256 check.',
        );
      }
      if (await partialFile.length() != received) {
        throw const UpdateNetworkException(
          'The update APK could not be fully written.',
        );
      }
      if (await destination.exists()) await destination.delete();
      final verifiedFile = await partialFile.rename(destination.path);
      partialFile = null;
      return VerifiedApk(file: verifiedFile, sha256: actualHash);
    } catch (_) {
      if (!digestClosed) digestInput.close();
      rethrow;
    } finally {
      try {
        if (output != null) await output.close();
      } on FileSystemException {
        // Preserve the original download error; the partial file is removed below.
      } finally {
        try {
          if (partialFile != null && await partialFile.exists()) {
            await partialFile.delete();
          }
        } on FileSystemException {
          // A later attempt overwrites the same private partial path.
        } finally {
          _downloading = false;
        }
      }
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _digest;

  Digest get digest =>
      _digest ?? (throw StateError('APK digest was not finalized.'));

  @override
  void add(Digest data) => _digest = data;

  @override
  void close() {}
}
