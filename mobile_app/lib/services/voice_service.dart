import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) => print('Speech recognition status: $status'),
      );
      return _isInitialized;
    } catch (e) {
      print('Failed to initialize speech recognition: $e');
      return false;
    }
  }

  Future<void> startListening({required Function(String) onResult}) async {
    if (!_isInitialized || _isListening) return;

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
            stopListening();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: false,
          cancelOnError: true,
        ),
        localeId: 'en_US',
      );
    } catch (e) {
      print('Failed to start listening: $e');
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      print('Failed to stop listening: $e');
    }
  }

  Future<List<LocaleName>> get availableLocales => _speech.locales();
}