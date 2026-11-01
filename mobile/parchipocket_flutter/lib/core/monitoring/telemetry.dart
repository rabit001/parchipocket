import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// The environment in which the application is configured to run.
///
/// Telemetry is strictly restricted to 'production'. Default is 'development'.
const String kAppEnvironment =
    String.fromEnvironment('PP_ENVIRONMENT', defaultValue: 'development');

/// Flag indicating whether the build is an internal test, CI, or verification artifact.
///
/// If true, telemetry is unconditionally disabled.
const bool kIsTestBuild =
    bool.fromEnvironment('PP_TEST_BUILD', defaultValue: false);

/// Explicit compile-time opt-in flag for Crashlytics and Performance collection.
///
/// Default must be strictly false.
const bool kTelemetryDefaultFlag =
    bool.fromEnvironment('PP_TELEMETRY_ENABLED', defaultValue: false);

/// Determines whether telemetry collection is authorized to run.
///
/// Telemetry strictly requires ALL of the following:
/// 1. The app must be running in release mode (`releaseMode == true`).
/// 2. The app must NOT be a test build (`isTestBuild == false`).
/// 3. The app environment must be explicitly 'production' (`environment == 'production'`).
/// 4. The explicit compile-time flag must be enabled (`flagEnabled == true`).
///
/// Under NO circumstances can a Dart define alone enable collection in
/// debug, profile, test releases, non-production environments, or unapproved builds.
bool isTelemetryPermitted({
  bool releaseMode = kReleaseMode,
  String environment = kAppEnvironment,
  bool isTestBuild = kIsTestBuild,
  bool flagEnabled = kTelemetryDefaultFlag,
}) {
  if (!releaseMode) return false;
  if (isTestBuild) return false;
  if (environment != 'production') return false;
  return flagEnabled;
}

/// The effective telemetry collection status for the current runtime session.
final bool kTelemetryDefaultEnabled = isTelemetryPermitted();

/// Privacy-safe patterns to redact sensitive customer data, credentials, and financial specifics.
final RegExp _phonePattern = RegExp(r'\+?\d[\d -]{8,15}\d');
final RegExp _contextPhonePattern = RegExp(
  r"""(phone|mobile|customerPhone)\s*[:=]\s*["']?[^"',\s]+["']?""",
  caseSensitive: false,
);
final RegExp _jwtPattern = RegExp(
  r'[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}',
);
final RegExp _appCheckTokenPattern = RegExp(
  r'\bey[A-Za-z0-9_-]{20,}\b',
);
final RegExp _bearerPattern = RegExp(
  r'Bearer\s+[^\s,;]+',
  caseSensitive: false,
);
final RegExp _basicAuthPattern = RegExp(
  r'(\b(?:Proxy-)?Authorization\s*:\s*Basic\s+)[A-Za-z0-9+/]+={0,2}',
  caseSensitive: false,
);
final RegExp _secretKeyPattern = RegExp(
  r"""\b(password|passwd|secret|otp|pin|api[_-]?key|auth[_-]?token)\b\s*[:=]\s*(?:"[^"]*"|'[^']*'|[^\s,;]+)""",
  caseSensitive: false,
);
final RegExp _financialPattern = RegExp(
  r"""((amount|total|price)\s*[:=]\s*["']?[\d.,]+["']?|[₹\$]\s*[\d,]+(\.\d+)?)""",
  caseSensitive: false,
);

/// Sanitizes diagnostic strings before any reporting.
String sanitizeDiagnosticString(String? input) {
  if (input == null || input.trim().isEmpty) return '';
  var sanitized = input
      .replaceAll(_jwtPattern, '[REDACTED_TOKEN]')
      .replaceAll(_appCheckTokenPattern, '[REDACTED_TOKEN]')
      .replaceAll(_bearerPattern, 'Bearer [REDACTED]')
      .replaceAllMapped(_secretKeyPattern, (m) => '${m.group(1)}:[REDACTED]')
      .replaceAllMapped(_basicAuthPattern, (m) => '${m.group(1)}[REDACTED]')
      .replaceAllMapped(_contextPhonePattern, (m) => '${m.group(1)}:[REDACTED_PHONE]')
      .replaceAll(_phonePattern, '[REDACTED_PHONE]')
      .replaceAll(_financialPattern, '[REDACTED_FINANCIAL]');

  if (sanitized.length > 150) {
    sanitized = sanitized.substring(0, 150);
  }
  return sanitized.trim();
}

/// A sanitized error wrapper that preserves the non-sensitive error category
/// while guaranteeing sensitive values are redacted from the diagnostic message.
class SanitizedException implements Exception {
  const SanitizedException({
    required this.category,
    required this.sanitizedMessage,
  });

  final String category;
  final String sanitizedMessage;

  @override
  String toString() => '$category: $sanitizedMessage';
}

/// Sanitizes an error object into a [SanitizedException].
SanitizedException sanitizeError(Object error) {
  final category = error.runtimeType.toString();
  final sanitizedMessage = sanitizeDiagnosticString(error.toString());
  return SanitizedException(
    category: category,
    sanitizedMessage: sanitizedMessage,
  );
}

/// Sanitizes a [FlutterErrorDetails] instance, redacting sensitive content from
/// the exception and context while preserving stack traces and framework metadata.
FlutterErrorDetails sanitizeFlutterErrorDetails(FlutterErrorDetails details) {
  final sanitizedEx = sanitizeError(details.exception);
  return FlutterErrorDetails(
    exception: sanitizedEx,
    stack: details.stack,
    library: details.library,
    context: details.context != null
        ? ErrorDescription(sanitizeDiagnosticString(details.context.toString()))
        : null,
    informationCollector: null,
    silent: details.silent,
  );
}

/// Manages crash reporting and performance telemetry with strict isolation.
class TelemetryService {
  TelemetryService._();
  static final TelemetryService instance = TelemetryService._();

  bool _isInitialized = false;
  bool _telemetryEnabled = false;

  bool get isInitialized => _isInitialized;
  bool get isTelemetryEnabled => _telemetryEnabled;

  /// Initializes Crashlytics and Performance monitoring.
  ///
  /// Telemetry collection is strictly disabled unless [telemetryEnabled] is true.
  Future<bool> initialize({
    bool telemetryEnabled = false,
    bool Function()? isPermitted,
    Future<void> Function(bool enabled)? setCrashlyticsCollectionEnabled,
    Future<void> Function(bool enabled)? setPerformanceCollectionEnabled,
    void Function(String message)? debugLog,
  }) async {
    // Defense-in-depth: Telemetry is strictly disabled unless both runtime parameter
    // and isTelemetryPermitted() independently authorize it.
    final permitted = (isPermitted ?? isTelemetryPermitted)();
    _telemetryEnabled = telemetryEnabled && permitted;
    try {
      if (setCrashlyticsCollectionEnabled != null) {
        await setCrashlyticsCollectionEnabled(_telemetryEnabled);
      } else {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(_telemetryEnabled);
      }

      if (setPerformanceCollectionEnabled != null) {
        await setPerformanceCollectionEnabled(_telemetryEnabled);
      } else {
        await FirebasePerformance.instance
            .setPerformanceCollectionEnabled(_telemetryEnabled);
      }

      _isInitialized = true;
      if (debugLog != null) {
        debugLog(
          'TelemetryService initialized (telemetryEnabled: $_telemetryEnabled, permitted: $permitted).',
        );
      }
      return true;
    } catch (error) {
      _isInitialized = false;
      _telemetryEnabled = false;
      if (debugLog != null) {
        final safeError = error.runtimeType.toString();
        debugLog(
          'TelemetryService initialization failed ($safeError). App startup continuing safely.',
        );
      }
      return false;
    }
  }

  /// Configures Flutter framework fatal errors and uncaught platform errors.
  void setupErrorHandlers({
    bool telemetryEnabled = false,
    bool Function()? isPermitted,
    void Function(FlutterErrorDetails details)? onFatalFlutterError,
    void Function(Object error, StackTrace stack)? onPlatformError,
    FlutterExceptionHandler? originalOnError,
    bool Function(Object error, StackTrace stack)? originalPlatformOnError,
  }) {
    final permitted = (isPermitted ?? isTelemetryPermitted)();
    _telemetryEnabled = telemetryEnabled && permitted;

    // 1. Flutter framework error handler
    final fallbackOnError = originalOnError ?? FlutterError.presentError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_telemetryEnabled) {
        final sanitizedDetails = sanitizeFlutterErrorDetails(details);
        if (onFatalFlutterError != null) {
          onFatalFlutterError(sanitizedDetails);
        } else {
          FirebaseCrashlytics.instance.recordFlutterFatalError(sanitizedDetails);
        }
      } else {
        fallbackOnError(details);
      }
    };

    // 2. Uncaught asynchronous / platform error handler
    final fallbackPlatform =
        originalPlatformOnError ?? PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (_telemetryEnabled) {
        final sanitizedError = sanitizeError(error);
        if (onPlatformError != null) {
          onPlatformError(sanitizedError, stack);
        } else {
          FirebaseCrashlytics.instance.recordError(
            sanitizedError,
            stack,
            fatal: true,
          );
        }
        return true;
      }
      if (fallbackPlatform != null) {
        return fallbackPlatform(error, stack);
      }
      return false;
    };
  }

  /// Records non-fatal exceptions with sanitization, strictly when telemetry is enabled.
  Future<void> recordNonFatal({
    required Object error,
    StackTrace? stack,
    String? reason,
    Future<void> Function(Object error, StackTrace? stack, String? reason)?
        onRecordError,
  }) async {
    if (!_telemetryEnabled) return;
    try {
      final sanitizedError = sanitizeError(error);
      final safeReason = sanitizeDiagnosticString(reason);
      if (onRecordError != null) {
        await onRecordError(
          sanitizedError,
          stack,
          safeReason.isNotEmpty ? safeReason : null,
        );
      } else {
        await FirebaseCrashlytics.instance.recordError(
          sanitizedError,
          stack,
          reason: safeReason.isNotEmpty ? safeReason : null,
          fatal: false,
        );
      }
    } catch (_) {
      // Suppress any reporting failure to protect user workflow
    }
  }

  /// Measures execution time of an operation with a custom performance trace.
  ///
  /// When telemetry is disabled (the default), executes the action directly
  /// with zero telemetry overhead and no data transmission.
  Future<T> measureTrace<T>({
    required String traceName,
    required Future<T> Function() action,
    dynamic Function(String name)? newTrace,
  }) async {
    if (!_telemetryEnabled) {
      return await action();
    }

    dynamic trace;
    try {
      trace = newTrace != null
          ? newTrace(traceName)
          : FirebasePerformance.instance.newTrace(traceName);
      await trace?.start();
    } catch (_) {
      trace = null;
    }

    try {
      return await action();
    } finally {
      try {
        await trace?.stop();
      } catch (_) {
        // Suppress trace stop errors
      }
    }
  }
}
