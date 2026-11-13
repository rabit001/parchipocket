import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../domain/speech_recognition.dart';

/// Production adapter backed by the device's speech_to_text plugin.
class DeviceSpeechRecognition implements SpeechRecognition {
  DeviceSpeechRecognition({stt.SpeechToText? speech})
      : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  }) =>
      _speech.initialize(
        onStatus: onStatus,
        onError: (error) => onError(error.errorMsg),
      );

  @override
  Future<List<SpeechRecognitionLocale>> locales() async =>
      (await _speech.locales())
          .map((locale) => SpeechRecognitionLocale(locale.localeId))
          .toList(growable: false);

  @override
  Future<bool> get hasPermission => _speech.hasPermission;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words, bool isFinal) onResult,
  }) =>
      _speech.listen(
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 25),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
        ),
      );

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
