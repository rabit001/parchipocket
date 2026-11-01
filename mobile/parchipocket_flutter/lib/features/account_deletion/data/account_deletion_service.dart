import 'dart:convert';
import 'dart:io';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parchipocket/app_check_activation.dart';

/// Service responsible for invoking the trusted backend `deleteUserAccount`
/// Callable Cloud Function adhering strictly to the Firebase HTTPS Callable protocol.
class AccountDeletionService {
  AccountDeletionService({
    FirebaseAuth? auth,
    FirebaseAppCheck? appCheck,
    String? functionsUrl,
    HttpClient? httpClient,
  })  : _auth = auth,
        _appCheck = appCheck,
        _customFunctionsUrl = functionsUrl,
        _httpClient = httpClient;

  final FirebaseAuth? _auth;
  final FirebaseAppCheck? _appCheck;
  final String? _customFunctionsUrl;
  final HttpClient? _httpClient;

  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseAppCheck get appCheck => _appCheck ?? FirebaseAppCheck.instance;

  /// Resolves the callable endpoint URL.
  ///
  /// Priority:
  /// 1. Explicit constructor URL parameter (testing / mock harnesses)
  /// 2. `PP_FUNCTIONS_URL` dart-define environment variable
  /// 3. Emulator URL when `PP_USE_EMULATOR` or `USE_FIREBASE_EMULATOR` is enabled
  ///    (10.0.2.2 on Android, 127.0.0.1 on desktop / tests)
  /// 4. Default production us-central1 Cloud Function endpoint
  String get endpointUrl {
    if (_customFunctionsUrl != null && _customFunctionsUrl.isNotEmpty) {
      return _customFunctionsUrl;
    }
    const envUrl = String.fromEnvironment('PP_FUNCTIONS_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    const useEmulator = bool.fromEnvironment('PP_USE_EMULATOR') ||
        bool.fromEnvironment('USE_FIREBASE_EMULATOR');
    if (useEmulator) {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5001/demo-parchipocket-phase4/us-central1/deleteUserAccount';
      }
      return 'http://127.0.0.1:5001/demo-parchipocket-phase4/us-central1/deleteUserAccount';
    }
    return 'https://us-central1-parchipocket.cloudfunctions.net/deleteUserAccount';
  }

  /// Calls the backend `deleteUserAccount` callable Cloud Function.
  ///
  /// Enforces:
  /// - Complete Firebase Callable protocol (POST, JSON content-type, Authorization Bearer,
  ///   X-Firebase-AppCheck, `{data: ...}` request envelope, `{result: ...}` / `{error: ...}` response envelope).
  /// - A fresh ID token (auth_time within 5 minutes).
  /// - ZERO PII and never accepts a client-selected target UID. Target UID is derived
  ///   exclusively by the backend from verified auth token claims.
  Future<Map<String, dynamic>> invokeDeletion({
    bool skipFreshnessCheckForTest = false,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      throw StateError(
          'Authentication required: No active user session found to delete.');
    }

    // Force refresh ID token to ensure auth_time is up to date
    final idToken = await currentUser.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Failed to obtain a valid Firebase ID token.');
    }

    final uri = Uri.parse(endpointUrl);
    final client = _httpClient ?? HttpClient();
    client.connectionTimeout ??= const Duration(seconds: 20);

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');

      // Account deletion is App Check protected. Obtain a fresh token and
      // fail closed rather than sending the callable request without attestation.
      final appCheckToken = await requireAppCheckToken(
        getToken: () => appCheck.getToken(true),
      );
      request.headers.set('X-Firebase-AppCheck', appCheckToken);

      final requestData = <String, dynamic>{};
      if (skipFreshnessCheckForTest) {
        requestData['__skipFreshnessCheckForTest'] = true;
      }

      // Standard Firebase Callable envelope: {"data": {...}}
      final body = jsonEncode(<String, dynamic>{'data': requestData});
      request.write(body);

      // Account deletion can process a large receipt history. Bound the wait,
      // while leaving time for the backend's maximum execution window.
      final response = await request.close().timeout(const Duration(minutes: 10));
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonResponse;
      try {
        jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (e) {
        throw StateError(
            'Invalid response from deletion service (${response.statusCode}): $responseBody');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (jsonResponse.containsKey('result')) {
          return jsonResponse['result'] as Map<String, dynamic>;
        }
        return jsonResponse;
      } else {
        final errorMap = jsonResponse['error'] as Map<String, dynamic>?;
        final message = errorMap?['message'] as String? ??
            'Account deletion failed with status ${response.statusCode}';
        throw StateError(message);
      }
    } finally {
      if (_httpClient == null) {
        client.close();
      }
    }
  }
}
