import 'package:firebase_app_check/firebase_app_check.dart';

typedef AppCheckProviders = ({
  AndroidProvider android,
  AppleProvider apple,
});

/// Selects debug providers for development and attestation providers for
/// release builds. No debug token is stored in application source.
AppCheckProviders appCheckProvidersFor({required bool debugMode}) => debugMode
    ? (android: AndroidProvider.debug, apple: AppleProvider.debug)
    : (
        android: AndroidProvider.playIntegrity,
        apple: AppleProvider.deviceCheck
      );

/// Activates Firebase App Check without preventing application startup.
///
/// Debug diagnostics include only the exception type and Firebase error code;
/// the exception message is omitted because SDK messages may contain details
/// that should not be written to logs.
Future<bool> activateAppCheckSafely({
  required Future<void> Function() activate,
  required bool debugMode,
  required void Function(String message) debugLog,
}) async {
  try {
    await activate();
    return true;
  } catch (error) {
    if (debugMode) {
      final safeError = error is FirebaseException
          ? '${error.runtimeType}, code=${error.code}'
          : error.runtimeType.toString();
      debugLog(
        'Firebase App Check activation failed ($safeError). Verify the app registration and configured attestation provider.',
      );
    }
    return false;
  }
}
