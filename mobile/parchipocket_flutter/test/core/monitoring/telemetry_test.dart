import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/telemetry.dart';

void main() {
  group('Enforce Environment Separation and Production-Only Telemetry (isTelemetryPermitted)', () {
    test('Debug + flag false => false', () {
      expect(
        isTelemetryPermitted(releaseMode: false, flagEnabled: false),
        isFalse,
      );
    });

    test('Debug + flag true => strictly false (Dart define cannot enable in debug)', () {
      expect(
        isTelemetryPermitted(releaseMode: false, environment: 'production', flagEnabled: true),
        isFalse,
      );
    });

    test('Release + default non-production environment => strictly false', () {
      expect(
        isTelemetryPermitted(releaseMode: true, environment: 'development', flagEnabled: true),
        isFalse,
      );
    });

    test('Release + flag alone without production environment => strictly false', () {
      expect(
        isTelemetryPermitted(releaseMode: true, environment: 'development', flagEnabled: true),
        isFalse,
      );
    });

    test('Release + production environment without telemetry flag => strictly false', () {
      expect(
        isTelemetryPermitted(releaseMode: true, environment: 'production', flagEnabled: false),
        isFalse,
      );
    });

    test('Release + production + flag enabled but test build => strictly false', () {
      expect(
        isTelemetryPermitted(
          releaseMode: true,
          environment: 'production',
          isTestBuild: true,
          flagEnabled: true,
        ),
        isFalse,
      );
    });

    test('Approved Production Release (Release + production + not test + flag true) => true', () {
      expect(
        isTelemetryPermitted(
          releaseMode: true,
          environment: 'production',
          isTestBuild: false,
          flagEnabled: true,
        ),
        isTrue,
      );
    });

    test('Runtime defaults match compile-time safety guards', () {
      expect(kAppEnvironment, 'development');
      expect(kIsTestBuild, isFalse);
      expect(kTelemetryDefaultFlag, isFalse);
      expect(kTelemetryDefaultEnabled, isFalse);
    });

    test('TelemetryService.initialize fails closed when a collection setter throws', () async {
      final service = TelemetryService.instance;
      final success = await service.initialize(
        telemetryEnabled: true,
        isPermitted: () => true,
        setCrashlyticsCollectionEnabled: (_) async {
          throw StateError('native setter unavailable');
        },
        setPerformanceCollectionEnabled: (_) async {},
      );
      expect(success, isFalse);
      expect(service.isInitialized, isFalse);
      expect(service.isTelemetryEnabled, isFalse);
    });

    test('TelemetryService.initialize ignores accidental runtime enable in non-production', () async {
      final service = TelemetryService.instance;
      bool? crashlyticsReportedState;
      bool? perfReportedState;

      final success = await service.initialize(
        telemetryEnabled: true, // Attempted runtime override
        setCrashlyticsCollectionEnabled: (val) async {
          crashlyticsReportedState = val;
        },
        setPerformanceCollectionEnabled: (val) async {
          perfReportedState = val;
        },
      );

      expect(success, isTrue);
      // isTelemetryPermitted() is false in test/debug, so effective telemetry remains false
      expect(service.isTelemetryEnabled, isFalse);
      expect(crashlyticsReportedState, isFalse);
      expect(perfReportedState, isFalse);
    });
  });

  group('Privacy Sanitization Across All Error Payloads', () {
    test('redacts phone numbers in various formats and contexts', () {
      expect(
        sanitizeDiagnosticString('Call +919876543210 failed'),
        'Call [REDACTED_PHONE] failed',
      );
      expect(
        sanitizeDiagnosticString('Dialing +1 555-234-5678'),
        'Dialing [REDACTED_PHONE]',
      );
      expect(
        sanitizeDiagnosticString('customerPhone: "+919123456789" rejected'),
        'customerPhone:[REDACTED_PHONE] rejected',
      );
      expect(
        sanitizeDiagnosticString('mobile: 9876543210 not verified'),
        'mobile:[REDACTED_PHONE] not verified',
      );
    });

    test('redacts Firebase ID tokens, App Check tokens, and Bearer headers', () {
      const fakeJwt =
          'eyJhbGciOiJSUzI1NiIsImtpZCI6ImFkMTIzIn0.eyJuYW1lIjoiQWxpY2UiLCJzdWIiOiIxMjM0NTY3OCJ9.K7j8L9mN0pQ1rS2tU3vW4xY5z';
      expect(
        sanitizeDiagnosticString('Invalid Firebase token: $fakeJwt'),
        'Invalid Firebase token: [REDACTED_TOKEN]',
      );

      const fakeAppCheck = 'eyJhYmMxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTA';
      expect(
        sanitizeDiagnosticString('App Check verification failed with $fakeAppCheck'),
        'App Check verification failed with [REDACTED_TOKEN]',
      );

      expect(
        sanitizeDiagnosticString('Authorization: Bearer mySecretToken123456789'),
        'Authorization: Bearer [REDACTED]',
      );
    });

    test('redacts passwords, OTPs, PINs, and API keys', () {
      expect(
        sanitizeDiagnosticString('Auth error with password: SecretPassword123!'),
        'Auth error with password:[REDACTED]',
      );
      expect(
        sanitizeDiagnosticString('Verification otp=849201 expired'),
        'Verification otp:[REDACTED] expired',
      );
      expect(
        sanitizeDiagnosticString('PIN validation failed for pin: "1234"'),
        'PIN validation failed for pin:[REDACTED]',
      );
      expect(
        sanitizeDiagnosticString('Invalid apiKey: AIzaSyD1234567890abcdef'),
        'Invalid apiKey:[REDACTED]',
      );
    });

    test('redacts Basic authorization headers and quoted secrets with spaces', () {
      expect(
        sanitizeDiagnosticString('Authorization: Basic dXNlcjpwYXNz'),
        'Authorization: Basic [REDACTED]',
      );
      expect(
        sanitizeDiagnosticString('password: "secret with spaces"'),
        'password:[REDACTED]',
      );
      // Do not mistake the word "password" after Basic for a base64 credential.
      // The labelled secret must be consumed in full, including spaces.
      expect(
        sanitizeDiagnosticString('Basic password: "secret with spaces"'),
        'Basic password:[REDACTED]',
      );
      expect(
        sanitizeDiagnosticString('Proxy-Authorization: Basic dXNlcjpwYXNz'),
        'Proxy-Authorization: Basic [REDACTED]',
      );
    });

    test('redacts financial details, amounts, and currency figures', () {
      expect(
        sanitizeDiagnosticString('Transaction failed for amount: 1540.50'),
        'Transaction failed for [REDACTED_FINANCIAL]',
      );
      expect(
        sanitizeDiagnosticString('Payment of ₹2,500 rejected at checkout'),
        'Payment of [REDACTED_FINANCIAL] rejected at checkout',
      );
      expect(
        sanitizeDiagnosticString('Charged \$100.00 to card'),
        'Charged [REDACTED_FINANCIAL] to card',
      );
      expect(
        sanitizeDiagnosticString('Bill total: 450.00 exceeds limit'),
        'Bill [REDACTED_FINANCIAL] exceeds limit',
      );
    });

    test('handles empty and null inputs safely', () {
      expect(sanitizeDiagnosticString(null), '');
      expect(sanitizeDiagnosticString('   '), '');
    });
  });

  group('Fatal Error Path Sanitization', () {
    test('sanitizeError produces SanitizedException preserving error category and stack', () {
      const rawError = FormatException('Failed for phone +919876543210 and amount: 500');
      final sanitized = sanitizeError(rawError);

      expect(sanitized, isA<SanitizedException>());
      expect(sanitized.category, 'FormatException');
      expect(sanitized.sanitizedMessage, contains('[REDACTED_PHONE]'));
      expect(sanitized.sanitizedMessage, contains('[REDACTED_FINANCIAL]'));
      expect(sanitized.sanitizedMessage, isNot(contains('+919876543210')));
      expect(sanitized.sanitizedMessage, isNot(contains('500')));
    });

    test('FlutterError.onError sanitizes exception and context before reporting to Crashlytics', () {
      FlutterErrorDetails? passedDetails;
      final originalOnError = FlutterError.onError;

      try {
        TelemetryService.instance.setupErrorHandlers(
          telemetryEnabled: true,
          isPermitted: () => true,
          onFatalFlutterError: (details) {
            passedDetails = details;
          },
        );

        final rawDetails = FlutterErrorDetails(
          exception: StateError('Corrupted session for +919999988888 with password: Secret'),
          stack: StackTrace.current,
          context: ErrorDescription('While processing payment of ₹9500 for customerPhone: "9876543210"'),
          library: 'parchipocket bills',
        );

        FlutterError.onError!(rawDetails);

        expect(passedDetails, isNotNull);
        expect(passedDetails!.exception, isA<SanitizedException>());

        final sanitizedEx = passedDetails!.exception as SanitizedException;
        expect(sanitizedEx.category, 'StateError');
        expect(sanitizedEx.sanitizedMessage, isNot(contains('+919999988888')));
        expect(sanitizedEx.sanitizedMessage, isNot(contains('Secret')));
        expect(sanitizedEx.sanitizedMessage, contains('[REDACTED_PHONE]'));
        expect(sanitizedEx.sanitizedMessage, contains('password:[REDACTED]'));

        // Check context sanitization
        expect(passedDetails!.context, isNotNull);
        expect(passedDetails!.context.toString(), isNot(contains('9500')));
        expect(passedDetails!.context.toString(), isNot(contains('9876543210')));
        expect(passedDetails!.context.toString(), contains('[REDACTED_FINANCIAL]'));
        expect(passedDetails!.context.toString(), contains('customerPhone:[REDACTED_PHONE]'));

        // Stack trace preserved
        expect(passedDetails!.stack, rawDetails.stack);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    test('PlatformDispatcher.instance.onError sanitizes uncaught platform errors', () {
      Object? passedError;
      StackTrace? passedStack;
      final originalPlatformOnError = PlatformDispatcher.instance.onError;

      try {
        TelemetryService.instance.setupErrorHandlers(
          telemetryEnabled: true,
          isPermitted: () => true,
          onPlatformError: (error, stack) {
            passedError = error;
            passedStack = stack;
          },
        );

        final rawError = Exception('Async failure: token=eyJhYmMxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTA with otp: 654321');
        final testStack = StackTrace.current;

        final handled = PlatformDispatcher.instance.onError!(rawError, testStack);

        expect(handled, isTrue);
        expect(passedError, isA<SanitizedException>());

        final sanitizedEx = passedError as SanitizedException;
        expect(sanitizedEx.category, '_Exception');
        expect(sanitizedEx.sanitizedMessage, isNot(contains('eyJhYmMxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTA')));
        expect(sanitizedEx.sanitizedMessage, isNot(contains('654321')));
        expect(sanitizedEx.sanitizedMessage, contains('[REDACTED_TOKEN]'));
        expect(sanitizedEx.sanitizedMessage, contains('otp:[REDACTED]'));
        expect(passedStack, testStack);
      } finally {
        PlatformDispatcher.instance.onError = originalPlatformOnError;
      }
    });

    test('recordNonFatal sanitizes error and reason before dispatching', () async {
      await TelemetryService.instance.initialize(
        telemetryEnabled: true,
        isPermitted: () => true,
        setCrashlyticsCollectionEnabled: (_) async {},
        setPerformanceCollectionEnabled: (_) async {},
      );

      Object? reportedError;
      String? reportedReason;

      await TelemetryService.instance.recordNonFatal(
        error: const FormatException('Malformed bill phone=+919876543210 amount=1200'),
        reason: 'Sync error for Bearer mySecretToken1234567890',
        onRecordError: (error, stack, reason) async {
          reportedError = error;
          reportedReason = reason;
        },
      );

      expect(reportedError, isA<SanitizedException>());
      final sanitized = reportedError as SanitizedException;
      expect(sanitized.category, 'FormatException');
      expect(sanitized.sanitizedMessage, isNot(contains('+919876543210')));
      expect(sanitized.sanitizedMessage, isNot(contains('1200')));
      expect(sanitized.sanitizedMessage, contains('[REDACTED_PHONE]'));
      expect(sanitized.sanitizedMessage, contains('[REDACTED_FINANCIAL]'));

      expect(reportedReason, isNot(contains('mySecretToken1234567890')));
      expect(reportedReason, contains('Bearer [REDACTED]'));

      // Reset
      await TelemetryService.instance.initialize(
        telemetryEnabled: false,
        setCrashlyticsCollectionEnabled: (_) async {},
        setPerformanceCollectionEnabled: (_) async {},
      );
    });
  });

  group('Performance Trace Lifecycle', () {
    test('measureTrace always stops trace in finally block even if action throws', () async {
      await TelemetryService.instance.initialize(
        telemetryEnabled: true,
        isPermitted: () => true,
        setCrashlyticsCollectionEnabled: (_) async {},
        setPerformanceCollectionEnabled: (_) async {},
      );

      bool startCalled = false;
      bool stopCalled = false;

      // Mock trace
      final mockTrace = _FakeTrace(
        onStart: () => startCalled = true,
        onStop: () => stopCalled = true,
      );

      await expectLater(
        TelemetryService.instance.measureTrace(
          traceName: 'failing_trace',
          action: () async => throw StateError('Simulated operational failure'),
          newTrace: (_) => mockTrace as dynamic,
        ),
        throwsA(isA<StateError>()),
      );

      expect(startCalled, isTrue);
      expect(stopCalled, isTrue);

      // Reset
      await TelemetryService.instance.initialize(
        telemetryEnabled: false,
        setCrashlyticsCollectionEnabled: (_) async {},
        setPerformanceCollectionEnabled: (_) async {},
      );
    });
  });
}

class _FakeTrace {
  _FakeTrace({required this.onStart, required this.onStop});

  final void Function() onStart;
  final void Function() onStop;

  Future<void> start() async => onStart();
  Future<void> stop() async => onStop();
}
