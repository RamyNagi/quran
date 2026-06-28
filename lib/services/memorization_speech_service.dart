import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

class MemorizationSpeechService {
  final speech.SpeechToText _speech = speech.SpeechToText();

  bool _initialized = false;
  void Function(String text, bool isFinal)? _resultHandler;
  ValueChanged<String>? _statusHandler;
  ValueChanged<String>? _errorHandler;

  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    if (_initialized) return true;

    _initialized = await _speech.initialize(
      onStatus: (status) => _statusHandler?.call(status),
      onError: (error) => _errorHandler?.call(error.errorMsg),
      options: [
        speech.SpeechToText.androidNoBluetooth,
        speech.SpeechToText.iosNoBluetooth,
      ],
    );

    return _initialized;
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
    ValueChanged<double>? onSoundLevel,
  }) async {
    _resultHandler = onResult;
    _statusHandler = onStatus;
    _errorHandler = onError;

    final ready = await initialize();
    if (!ready) {
      onError('permission_denied');
      return;
    }

    await _speech.listen(
      onResult: (result) =>
          _resultHandler?.call(result.recognizedWords, result.finalResult),
      onSoundLevelChange: onSoundLevel,
      listenOptions: speech.SpeechListenOptions(
        localeId: 'ar',
        partialResults: true,
        cancelOnError: false,
        onDevice: false,
        listenMode: speech.ListenMode.dictation,
        pauseFor: Duration(seconds: 8),
        listenFor: Duration(minutes: 10),
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
