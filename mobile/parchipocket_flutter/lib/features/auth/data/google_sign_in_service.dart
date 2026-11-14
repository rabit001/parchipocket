import 'package:google_sign_in/google_sign_in.dart';

/// Injectable boundary around the platform Google account picker.
abstract interface class GoogleSignInService {
  /// Returns null when the user cancels account selection.
  Future<String?> authenticate();

  Future<void> signOut();
}

class DeviceGoogleSignInService implements GoogleSignInService {
  DeviceGoogleSignInService() : _client = GoogleSignIn.instance;

  static Future<void>? _initialization;
  final GoogleSignIn _client;

  Future<void> _initializeOnce() => _initialization ??= _client.initialize();

  @override
  Future<String?> authenticate() async {
    await _initializeOnce();
    try {
      final account = await _client.authenticate();
      return account.authentication.idToken ?? '';
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _initializeOnce();
    await _client.signOut();
  }
}
