import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Unified voice service for TTS (flutter_tts) and STT (speech_to_text).
/// Uses the phone's on-device speech recognizer — works offline on most
/// modern Androids because Google keeps an offline model cached.
class VoiceService {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _ttsReady = false;
  bool _sttReady = false;
  bool _sttAvailable = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get sttAvailable => _sttAvailable;

  Future<void> initTTS() async {
    if (_ttsReady) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.52);
      await _tts.setVolume(1.0);
      await _tts.setPitch(0.95);
      _ttsReady = true;
    } catch (_) {}
  }

  Future<void> initSTT() async {
    if (_sttReady) return;
    try {
      _sttAvailable = await _stt.initialize(
        onStatus: (_) {},
        onError: (_) {
          _isListening = false;
        },
      );
      _sttReady = true;
    } catch (_) {
      _sttAvailable = false;
      _sttReady = true;
    }
  }

  Future<void> speak(String text) async {
    if (!_ttsReady) await initTTS();
    try {
      await _tts.stop();
      final clean = text.replaceAll(RegExp(r'[*_#`]'), '').trim();
      if (clean.isEmpty) return;
      await _tts.speak(clean);
    } catch (_) {}
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Listen up to [timeout]; emit interim + final results through [onText].
  /// Returns the final transcript (or null if unavailable).
  Future<String?> listen({
    required void Function(String text, bool isFinal) onText,
    Duration timeout = const Duration(seconds: 15),
    String localeId = 'en_US',
  }) async {
    if (!_sttReady) await initSTT();
    if (!_sttAvailable) return null;
    if (_isListening) await stopListening();

    String last = '';
    final completer = Completer<String?>();

    _isListening = true;
    try {
      await _stt.listen(
        localeId: localeId,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
        onResult: (r) {
          last = r.recognizedWords;
          onText(last, r.finalResult);
          if (r.finalResult && !completer.isCompleted) {
            completer.complete(last.isEmpty ? null : last);
          }
        },
      );

      // Safety timeout that closes the future if the recognizer falls silent.
      Future.delayed(timeout + const Duration(seconds: 2), () {
        if (!completer.isCompleted) {
          completer.complete(last.isEmpty ? null : last);
        }
      });

      final result = await completer.future;
      _isListening = false;
      return result;
    } catch (_) {
      _isListening = false;
      return last.isEmpty ? null : last;
    }
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {}
    _isListening = false;
  }

  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
    try {
      _stt.stop();
    } catch (_) {}
  }
}
