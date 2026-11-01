import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_check_activation.dart';

void main() {
  group('appCheckProvidersFor', () {
    test('uses debug providers in debug builds', () {
      final providers = appCheckProvidersFor(debugMode: true);

      expect(providers.android, AndroidProvider.debug);
      expect(providers.apple, AppleProvider.debug);
    });

    test('uses attestation providers in release builds', () {
      final providers = appCheckProvidersFor(debugMode: false);

      expect(providers.android, AndroidProvider.playIntegrity);
      expect(providers.apple, AppleProvider.deviceCheck);
    });
  });

  group('requireAppCheckToken', () {
    test('returns a non-empty attestation token', () async {
      final token = await requireAppCheckToken(
        getToken: () async => 'verified-app-check-token',
      );

      expect(token, 'verified-app-check-token');
    });

    test('rejects a null token', () async {
      await expectLater(
        requireAppCheckToken(getToken: () async => null),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects an empty token', () async {
      await expectLater(
        requireAppCheckToken(getToken: () async => '  '),
        throwsA(isA<StateError>()),
      );
    });

    test('does not expose provider exception details', () async {
      await expectLater(
        requireAppCheckToken(
          getToken: () async => throw StateError('private provider detail'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            isNot(contains('private provider detail')),
          ),
        ),
      );
    });
  });

  group('activateAppCheckSafely', () {
    test('returns true when activation succeeds', () async {
      final diagnostics = <String>[];

      final activated = await activateAppCheckSafely(
        activate: () async {},
        debugMode: true,
        debugLog: diagnostics.add,
      );

      expect(activated, isTrue);
      expect(diagnostics, isEmpty);
    });

    test('reports safe error details in debug mode without logging message',
        () async {
      final diagnostics = <String>[];

      final activated = await activateAppCheckSafely(
        activate: () async => throw FirebaseException(
          plugin: 'firebase_app_check',
          code: 'provider-not-registered',
          message: 'sensitive test detail',
        ),
        debugMode: true,
        debugLog: diagnostics.add,
      );

      expect(activated, isFalse);
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single, contains('FirebaseException'));
      expect(diagnostics.single, contains('provider-not-registered'));
      expect(diagnostics.single, isNot(contains('sensitive test detail')));
    });

    test('does not emit diagnostics in release mode and allows startup',
        () async {
      final diagnostics = <String>[];

      final activated = await activateAppCheckSafely(
        activate: () async => throw StateError('private exception detail'),
        debugMode: false,
        debugLog: diagnostics.add,
      );

      expect(activated, isFalse);
      expect(diagnostics, isEmpty);
    });
  });
}
