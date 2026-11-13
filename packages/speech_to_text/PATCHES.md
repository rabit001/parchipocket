# Local ParchiPocket fork

This package is based on upstream `speech_to_text` 7.5.0. The upstream BSD
3-Clause license is preserved in `LICENSE`. The Flutter app resolves this
fork through a repository-relative path dependency.

## ParchiPocket changes

- Android `SpeechToTextPlugin` uses `RecognitionGenerationRouter` to serialize
  native recognition lifecycles and attach monotonically increasing generation
  IDs to channel events.
- Each command receives a `GenerationRecognitionListener` bound to its
  generation. `notListening` only updates recording state; final results or
  errors precede the matching terminal event, and duplicate or stale router
  events are ignored.
- Android channel events carry `generationId` and `eventType`; the Dart
  dispatcher filters results, errors, statuses, and terminal events by the
  active generation. Other platform implementations retain their existing
  string-based event handling.
- JUnit tests cover generation routing, listener identity, event ordering,
  empty final results, stale callbacks, and terminal suppression.

## Cancellation limitation

Android `SpeechRecognizer.cancel()` does not synchronously confirm that native
recognition has terminated. The router keeps the generation locked until the
matching native `onResults` or `onError` callback arrives. If Android never
sends either callback, voice recognition remains blocked for the app process;
the plugin does not fabricate a cancellation acknowledgement. The application
asks the user to fully restart it and keeps manual purchase entry available.

## Modified and added fork files

- Modified: `android/build.gradle` (JUnit test setup).
- Modified: `android/src/main/kotlin/com/csdcorp/speech_to_text/SpeechToTextPlugin.kt`.
- Added: `android/src/main/kotlin/com/csdcorp/speech_to_text/RecognitionGenerationRouter.kt`.
- Added: `android/src/main/kotlin/com/csdcorp/speech_to_text/GenerationRecognitionListener.kt`.
- Added: `android/src/test/kotlin/com/csdcorp/speech_to_text/RecognitionGenerationRouterTest.kt`.
- Added: `android/src/test/kotlin/com/csdcorp/speech_to_text/GenerationRecognitionListenerTest.kt`.
- Modified: `lib/speech_to_text.dart` (generation-aware Android event filtering).

Real Android `SpeechRecognizer` callback behavior and cancellation recovery
still require verification on Android devices. The JVM tests exercise the
Kotlin router and listener adapter, not the system speech service.
