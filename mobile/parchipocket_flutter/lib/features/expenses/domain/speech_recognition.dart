/// Small boundary around the device speech plugin so voice capture can be
/// exercised deterministically without a microphone or Android speech service.
abstract interface class SpeechRecognition {
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message) onError,
  });

  Future<List<SpeechRecognitionLocale>> locales();
  Future<bool> get hasPermission;
  bool get isListening;

  Future<void> listen({
    required String localeId,
    required void Function(String words, bool isFinal) onResult,
  });

  Future<void> stop();
  Future<void> cancel();
}

class SpeechRecognitionLocale {
  const SpeechRecognitionLocale(this.localeId);

  final String localeId;
}
