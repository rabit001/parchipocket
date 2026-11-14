import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';
import 'package:parchipocket/features/customer/presentation/customer_screens.dart';
import 'package:parchipocket/features/expenses/domain/speech_recognition.dart';

class _FakeSpeechRecognition implements SpeechRecognition {
  void Function(String, bool)? onResult;
  final List<void Function(String, bool)> results =
      <void Function(String, bool)>[];
  void Function(String)? onStatus;
  void Function(String)? onError;
  bool listening = false;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int initializeCalls = 0;
  int listenFailuresRemaining = 0;
  bool emitCleanupDone = true;
  bool failInitialization = false;
  Completer<void>? listenGate;
  Completer<bool>? initializationGate;
  final List<Object> initializationOutcomes = <Object>[];
  bool permissionGranted = true;
  bool emitListeningStatusOnListen = true;
  String? localeId;
  final List<void Function(String)> sessionStatuses = <void Function(String)>[];
  final List<void Function(String)> sessionErrors = <void Function(String)>[];

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) async {
    initializeCalls++;
    this.onStatus = onStatus;
    this.onError = onError;
    final gate = initializationGate;
    if (gate != null) return gate.future;
    if (initializationOutcomes.isNotEmpty) {
      final outcome = initializationOutcomes.removeAt(0);
      if (outcome is Exception) throw outcome;
      return outcome as bool;
    }
    return !failInitialization;
  }

  @override
  Future<List<SpeechRecognitionLocale>> locales() async =>
      const <SpeechRecognitionLocale>[SpeechRecognitionLocale('hi_IN')];

  @override
  Future<bool> get hasPermission async => permissionGranted;

  @override
  bool get isListening => listening;

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words, bool isFinal) onResult,
  }) async {
    listenCalls++;
    this.localeId = localeId;
    this.onResult = onResult;
    results.add(onResult);
    sessionStatuses.add(onStatus!);
    sessionErrors.add(onError!);
    if (listenFailuresRemaining > 0) {
      listenFailuresRemaining--;
      throw StateError('simulated listen start failure');
    }
    await listenGate?.future;
    listening = true;
    if (emitListeningStatusOnListen) onStatus!('listening');
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    listening = false;
    onStatus?.call('notListening');
    if (emitCleanupDone) onStatus?.call('done');
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    listening = false;
    if (sessionStatuses.isNotEmpty) {
      onStatus?.call('notListening');
      if (emitCleanupDone) onStatus?.call('done');
    }
  }

  void partial(String words) => onResult?.call(words, false);
  void finalTranscript(String words) => onResult?.call(words, true);

  void stopStatus([int session = -1]) {
    listening = false;
    sessionStatuses[session < 0 ? sessionStatuses.length - 1 : session](
        'notListening');
  }

  void finish(String words) {
    finalTranscript(words);
    stopStatus();
    onStatus?.call('done');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Voice purchase recognition lifecycle', () {
    late AppState state;
    late _FakeSpeechRecognition speech;

    setUp(() {
      state = AppState()..householdExpenses.clear();
      speech = _FakeSpeechRecognition();
    });

    tearDown(() => state.dispose());

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HouseholdExpenseEntryScreen(
          state: state,
          speechRecognition: speech,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('starts listening and displays a partial transcript',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();

      expect(speech.listenCalls, 1);
      expect(speech.localeId, 'hi_IN');
      expect(find.text('Listening…'), findsOneWidget);

      speech.partial('250 rupaye ki sabzi');
      await tester.pumpAndSettle();
      expect(find.text('“250 rupaye ki sabzi”'), findsOneWidget);
      expect(find.text('Listening…'), findsOneWidget);
      expect(state.householdExpenses, isEmpty);
    });

    testWidgets('final transcript waits for provider stopped status',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      speech.finalTranscript('250 rupaye ki sabzi');
      await tester.pumpAndSettle();

      expect(find.text('Listening…'), findsOneWidget);
      expect(speech.listening, isTrue);
      expect(find.text('“250 rupaye ki sabzi”'), findsOneWidget);
      expect(find.text('Review fields'), findsOneWidget);
      expect(state.householdExpenses, isEmpty);

      speech.stopStatus();
      await tester.pumpAndSettle();
      expect(find.text('Voice input ready'), findsOneWidget);
    });

    testWidgets('cannot save an unreviewed voice draft', (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      speech.finish('250 rupaye ki sabzi');
      await tester.pumpAndSettle();

      final save = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save purchase'),
      );
      expect(save.onPressed, isNull);
      expect(state.householdExpenses, isEmpty);
    });

    testWidgets('reviewing and correcting a voice draft saves once',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      speech.finish('250 rupaye ki sabzi');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review fields'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Item name'),
        'Tomatoes corrected',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (₹)'),
        '275',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save purchase'));
      await tester.pumpAndSettle();

      expect(state.householdExpenses, hasLength(1));
      expect(state.householdExpenses.single.title, 'Tomatoes corrected');
      expect(state.householdExpenses.single.amount, 275);
      expect(state.householdExpenses.single.source, 'voice');
    });

    testWidgets('stop button stops listening without discarding transcript',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      expect(speech.listening, isTrue);
      expect(find.text('Listening…'), findsOneWidget);
      speech.partial('Milk 60');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop listening'));
      await tester.pumpAndSettle();

      expect(speech.stopCalls, 1);
      expect(find.text('Voice input ready'), findsOneWidget);
      expect(find.text('“Milk 60”'), findsOneWidget);
    });

    testWidgets('switching to manual entry cancels active recognition',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Type manually'));
      await tester.pumpAndSettle();

      expect(speech.cancelCalls, 1);
      expect(find.text('Start voice entry'), findsNothing);
      expect(find.text('Item name'), findsOneWidget);
    });

    testWidgets('recognition errors stop listening and show an error',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      speech.sessionErrors.last('network unavailable');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('Voice recognition error: network unavailable'),
          findsOneWidget);
      expect(state.householdExpenses, isEmpty);
    });

    testWidgets('disposing an active voice screen cancels recognition',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(speech.cancelCalls, 1);
      speech.partial('late result after dispose');
      speech.onStatus?.call('listening');
      speech.onError?.call('late error after dispose');
      await tester.pump();
      expect(state.householdExpenses, isEmpty);
    });

    testWidgets('rapid repeated start taps invoke listen only once',
        (tester) async {
      speech.listenGate = Completer<void>();
      await open(tester);

      final startButton = find.text('Start voice entry');
      await tester.tap(startButton);
      await tester.tap(startButton, warnIfMissed: false);
      await tester.pump();

      expect(speech.listenCalls, 1);
      expect(find.text('Starting voice entry…'), findsOneWidget);
      expect(speech.listening, isFalse);

      speech.listenGate!.complete();
      await tester.pumpAndSettle();
      expect(speech.listenCalls, 1);
      expect(find.text('Listening…'), findsOneWidget);
    });

    testWidgets('failed listen start releases the guard for retry',
        (tester) async {
      speech.listenFailuresRemaining = 1;
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();

      expect(speech.listenCalls, 1);
      expect(find.text('Start voice entry'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not start the microphone'),
          findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      expect(speech.listenCalls, 2);
      expect(find.text('Listening…'), findsOneWidget);
    });

    testWidgets('provider startup failure releases the guard for retry',
        (tester) async {
      speech.emitListeningStatusOnListen = false;
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      speech.sessionErrors[0]('startup rejected');
      await tester.pumpAndSettle();

      expect(find.text('Start voice entry'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.textContaining('Voice recognition error: startup rejected'),
          findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();
      speech.emitListeningStatusOnListen = true;
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      expect(speech.listenCalls, 2);
      expect(find.text('Listening…'), findsOneWidget);
    });

    testWidgets('completed listen waits for delayed listening status',
        (tester) async {
      speech.emitListeningStatusOnListen = false;
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();

      expect(speech.listenCalls, 1);
      expect(speech.listening, isTrue);
      expect(find.text('Starting voice entry…'), findsOneWidget);
      expect(find.text('Listening…'), findsNothing);

      speech.sessionStatuses.single('listening');
      await tester.pumpAndSettle();
      expect(find.text('Listening…'), findsOneWidget);
      expect(find.text('Starting voice entry…'), findsNothing);
    });

    testWidgets('start guard blocks a second tap until listening status',
        (tester) async {
      speech.emitListeningStatusOnListen = false;
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Starting voice entry…'), warnIfMissed: false);
      await tester.pump();

      expect(speech.listenCalls, 1);
      speech.sessionStatuses.single('listening');
      await tester.pumpAndSettle();
      expect(find.text('Listening…'), findsOneWidget);
      expect(speech.listenCalls, 1);
    });

    testWidgets('a new session starts after the previous session stops',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      speech.stopStatus(0);
      await tester.pumpAndSettle();
      expect(speech.listenCalls, 1);
      speech.onStatus?.call('done');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      expect(speech.listenCalls, 2);
      expect(find.text('Listening…'), findsOneWidget);
    });

    testWidgets('startup timeout releases the guard and allows retry',
        (tester) async {
      speech.emitListeningStatusOnListen = false;
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 9));
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.text('Start voice entry'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(find.textContaining('did not start'), findsOneWidget);

      speech.emitListeningStatusOnListen = true;
      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      expect(speech.listenCalls, 2);
      expect(find.text('Listening…'), findsOneWidget);
    });

    testWidgets('callbacks from an older session cannot change a newer one',
        (tester) async {
      speech.emitListeningStatusOnListen = false;
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      speech.sessionStatuses[0]('listening');
      await tester.pumpAndSettle();
      speech.stopStatus(0);
      speech.onStatus?.call('done');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      expect(find.text('Starting voice entry…'), findsOneWidget);
      speech.results[0]('late old result 44', true);
      await tester.pumpAndSettle();
      expect(find.text('Starting voice entry…'), findsOneWidget);
      expect(find.text('“late old result 44”'), findsNothing);

      speech.sessionStatuses[1]('listening');
      await tester.pumpAndSettle();
      expect(find.text('Listening…'), findsOneWidget);
    });

    testWidgets('notListening retains the session lock until done',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      speech.onStatus?.call('notListening');
      speech.listening = false;
      await tester.pumpAndSettle();
      expect(find.text('Start voice entry'), findsOneWidget);
      expect(speech.listenCalls, 1);
      speech.onStatus?.call('done');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      expect(speech.listenCalls, 2);
    });

    testWidgets('initialization callbacks are registered once', (tester) async {
      await open(tester);
      expect(speech.initializeCalls, 1);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      expect(speech.initializeCalls, 1);
    });

    testWidgets('failed initialization can be retried successfully',
        (tester) async {
      speech.initializationOutcomes.addAll(<Object>[false, true]);
      await open(tester);
      expect(speech.initializeCalls, 1);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Speech recognition is unavailable'),
        findsOneWidget,
      );

      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();

      expect(speech.initializeCalls, 2);
      expect(speech.listenCalls, 1);
      expect(find.text('Listening…'), findsOneWidget);
    });

    testWidgets('thrown initialization can be retried successfully',
        (tester) async {
      speech.initializationOutcomes
          .addAll(<Object>[Exception('temporary initialization error'), true]);
      await open(tester);
      expect(speech.initializeCalls, 1);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('temporary initialization error'),
        findsOneWidget,
      );

      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();

      expect(speech.initializeCalls, 2);
      expect(speech.listenCalls, 1);
      expect(find.text('Listening…'), findsOneWidget);
    });

    testWidgets('concurrent initialization callers share one attempt',
        (tester) async {
      speech.initializationGate = Completer<bool>();
      await tester.pumpWidget(MaterialApp(
        home: HouseholdExpenseEntryScreen(
          state: state,
          speechRecognition: speech,
        ),
      ));
      await tester.pump();
      expect(speech.initializeCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(speech.initializeCalls, 1);

      speech.initializationGate!.complete(true);
      await tester.pumpAndSettle();
      expect(speech.initializeCalls, 1);
    });

    testWidgets(
        'resume retries initialization after microphone permission changes',
        (tester) async {
      speech
        ..initializationOutcomes.addAll(<Object>[false, true])
        ..permissionGranted = false;
      await open(tester);
      expect(speech.initializeCalls, 1);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Microphone permission is required'),
        findsOneWidget,
      );

      speech.permissionGranted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(speech.initializeCalls, 2);
      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      expect(speech.listenCalls, 1);
      expect(find.text('Listening…'), findsOneWidget);
    });

    testWidgets('cleanup timeout blocks overlapping retry', (tester) async {
      speech.emitListeningStatusOnListen = false;
      speech.emitCleanupDone = false;
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 9));
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(speech.cancelCalls, 1);
      expect(speech.listenCalls, 1);
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.textContaining('until the app is fully restarted'),
          findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 900));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Type manually'));
      await tester.pumpAndSettle();
      expect(find.text('Item name'), findsOneWidget);
    });

    testWidgets('stale result callback is ignored after a completed session',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      final oldResult = speech.results.first;
      speech.onStatus?.call('done');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start voice entry'));
      await tester.pumpAndSettle();
      oldResult('stale purchase 99', true);
      await tester.pumpAndSettle();
      expect(find.text('“stale purchase 99”'), findsNothing);
    });
  });
}
