import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/utils/voice_parser.dart';

/// Сервис голосового ввода через speech_to_text.
/// Распознаёт русскую речь и парсит числа/животных из текста.
class VoiceInputService {
  static final VoiceInputService _instance = VoiceInputService._internal();
  factory VoiceInputService() => _instance;
  VoiceInputService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _available = false;

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  final StreamController<String> _resultController =
      StreamController<String>.broadcast();
  Stream<String> get resultStream => _resultController.stream;

  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();
  Stream<bool> get listeningStream => _listeningController.stream;

  Future<bool> init() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _listeningController.add(false);
          } else if (status == 'listening') {
            _listeningController.add(true);
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          _listeningController.add(false);
        },
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
      _available = false;
    }
    return _available;
  }

  /// Начать слушать. Результаты стримятся через [resultStream].
  /// Автоматически останавливается после паузы.
  Future<void> startListening({Duration? listenFor}) async {
    if (!_available) {
      final ok = await init();
      if (!ok) return;
    }
    HapticHelper.light();

    await _speech.listen(
      onResult: (result) {
        _resultController.add(result.recognizedWords);
      },
      localeId: 'ru_RU',
      listenMode: stt.ListenMode.dictation,
      listenFor: listenFor ?? const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
    _listeningController.add(true);
  }

  /// Остановить прослушивание.
  Future<void> stopListening() async {
    await _speech.stop();
    _listeningController.add(false);
  }

  /// Переключить прослушивание (start/stop).
  Future<void> toggle() async {
    if (_speech.isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  void dispose() {
    _resultController.close();
    _listeningController.close();
  }
}
