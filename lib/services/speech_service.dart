import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps speech-to-text (for speaking practice) and text-to-speech (to model
/// correct pronunciation).
///
/// The error callback is registered on `initialize` because `listen` does not
/// accept an `onError` parameter.
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _speaking = false;
  void Function(String message)? _onError;

  bool get isListening => _speech.isListening;
  bool get isSpeaking => _speaking;

  /// Initialises the recogniser once. [onError] is remembered for the session.
  Future<bool> initStt({void Function(String message)? onError}) async {
    if (onError != null) _onError = onError;
    if (_sttReady) return true;
    try {
      _sttReady = await _speech.initialize(
        onError: (error) => _onError?.call(error.errorMsg),
        debugLogging: false,
      );
    } catch (_) {
      _sttReady = false;
    }
    return _sttReady;
  }

  Future<void> startListening({
    required String languageCode,
    required void Function(String text, bool isFinal) onResult,
    void Function(String message)? onError,
  }) async {
    if (onError != null) _onError = onError;

    final ready = await initStt(onError: onError);
    if (!ready) {
      _onError?.call(
        'Speech recognition is not available on this device. '
        'You can still type your answer.',
      );
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
        localeId: sttLocale(languageCode),
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      _onError?.call('Could not start listening: $e');
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {
      // Nothing to stop.
    }
  }

  Future<void> speak(String text, String languageCode) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.setLanguage(ttsLocale(languageCode));
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _speaking = true;
      await _tts.speak(text);
    } catch (_) {
      // The TTS language may not be installed; fail quietly.
    } finally {
      _speaking = false;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore.
    }
    _speaking = false;
  }
}

/// Locale codes for speech recognition ('es' -> 'es_ES').
String sttLocale(String code) {
  const map = <String, String>{
    'en': 'en_US', 'hi': 'hi_IN', 'es': 'es_ES', 'fr': 'fr_FR', 'de': 'de_DE',
    'ja': 'ja_JP', 'ko': 'ko_KR', 'ar': 'ar_SA', 'zh': 'zh_CN', 'pt': 'pt_PT',
    'ru': 'ru_RU', 'it': 'it_IT', 'bn': 'bn_IN', 'ta': 'ta_IN', 'te': 'te_IN',
    'mr': 'mr_IN', 'gu': 'gu_IN', 'kn': 'kn_IN', 'ml': 'ml_IN', 'pa': 'pa_IN',
    'ur': 'ur_PK', 'ne': 'ne_NP', 'tr': 'tr_TR', 'nl': 'nl_NL', 'vi': 'vi_VN',
    'th': 'th_TH', 'id': 'id_ID', 'ms': 'ms_MY', 'tl': 'fil_PH', 'pl': 'pl_PL',
    'ro': 'ro_RO', 'cs': 'cs_CZ', 'el': 'el_GR', 'he': 'he_IL', 'fa': 'fa_IR',
    'uk': 'uk_UA', 'sv': 'sv_SE', 'da': 'da_DK', 'fi': 'fi_FI', 'no': 'nb_NO',
    'hu': 'hu_HU', 'sw': 'sw_KE', 'si': 'si_LK', 'my': 'my_MM', 'km': 'km_KH',
  };
  return map[code] ?? code;
}

/// Locale codes for text-to-speech ('es' -> 'es-ES').
String ttsLocale(String code) => sttLocale(code).replaceAll('_', '-');
