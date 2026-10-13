import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Connection state of a live voice session.
enum LiveStatus { idle, connecting, connected, ended, error }

/// Talks to the **Gemini Live API** (BidiGenerateContent) over a WebSocket.
///
/// This is what makes the conversation truly live: audio is streamed in and
/// out continuously, and the model can be interrupted mid-sentence.
///
/// * Input audio: raw PCM, 16-bit, 16 kHz, mono.
/// * Output audio: raw PCM, 16-bit, 24 kHz, mono.
class LiveSessionService {
  static const String _endpoint =
      'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = true;

  final StreamController<LiveStatus> _status =
      StreamController<LiveStatus>.broadcast();
  final StreamController<Uint8List> _audioOut =
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _userTranscript =
      StreamController<String>.broadcast();
  final StreamController<String> _modelTranscript =
      StreamController<String>.broadcast();
  final StreamController<double> _modelLevel =
      StreamController<double>.broadcast();
  final StreamController<void> _interruptions =
      StreamController<void>.broadcast();
  final StreamController<String> _errors = StreamController<String>.broadcast();

  /// Connection state changes.
  Stream<LiveStatus> get status => _status.stream;

  /// Raw PCM (24 kHz, 16-bit, mono) chunks spoken by the teacher.
  Stream<Uint8List> get audioOut => _audioOut.stream;

  /// Live transcription of what the learner said.
  Stream<String> get userTranscript => _userTranscript.stream;

  /// Live transcription of what the teacher said.
  Stream<String> get modelTranscript => _modelTranscript.stream;

  /// A 0..1 loudness value for the teacher's voice, used to drive lip sync.
  Stream<double> get modelLevel => _modelLevel.stream;

  /// Fires when the learner interrupts the teacher.
  Stream<void> get interruptions => _interruptions.stream;

  /// Human-readable error messages.
  Stream<String> get errors => _errors.stream;

  bool get isConnected => !_closed && _channel != null;

  /// Opens the session and sends the setup message.
  Future<void> connect({
    required String apiKey,
    required String model,
    required String systemInstruction,
    required String voiceName,
  }) async {
    await close();
    _closed = false;
    _emit(_status, LiveStatus.connecting);

    final uri = Uri.parse('$_endpoint?key=$apiKey');
    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
    } catch (e) {
      _closed = true;
      _emit(_status, LiveStatus.error);
      _emit(_errors, _friendly(e));
      return;
    }

    _subscription = _channel!.stream.listen(
      _onMessage,
      onError: (Object e) {
        _emit(_errors, _friendly(e));
        _emit(_status, LiveStatus.error);
      },
      onDone: () {
        if (!_closed) _emit(_status, LiveStatus.ended);
      },
      cancelOnError: false,
    );

    // Exactly the setup shape verified against the live endpoint.
    _send(<String, dynamic>{
      'setup': {
        'model': 'models/$model',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voiceName},
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction}
          ],
        },
        'inputAudioTranscription': <String, dynamic>{},
        'outputAudioTranscription': <String, dynamic>{},
      },
    });
  }

  /// Streams a chunk of microphone audio (PCM 16-bit, 16 kHz, mono).
  void sendAudio(Uint8List pcm16) {
    if (_closed || _channel == null || pcm16.isEmpty) return;
    _send(<String, dynamic>{
      'realtimeInput': {
        'audio': {
          'data': base64Encode(pcm16),
          'mimeType': 'audio/pcm;rate=16000',
        },
      },
    });
  }

  /// Sends a text turn (used for the kickoff greeting and the text fallback).
  void sendText(String text) {
    if (_closed || _channel == null || text.trim().isEmpty) return;
    _send(<String, dynamic>{
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text}
            ],
          }
        ],
        'turnComplete': true,
      },
    });
  }

  /// Tells the server the microphone has been muted.
  void sendAudioStreamEnd() {
    if (_closed || _channel == null) return;
    _send(<String, dynamic>{
      'realtimeInput': {'audioStreamEnd': true},
    });
  }

  void _send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (_) {
      // The socket is gone; the status stream already reports it.
    }
  }

  void _onMessage(dynamic data) {
    final String text;
    if (data is String) {
      text = data;
    } else if (data is List<int>) {
      text = utf8.decode(data, allowMalformed: true);
    } else {
      return;
    }

    Map<String, dynamic> message;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;
      message = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    if (message['setupComplete'] != null) {
      _emit(_status, LiveStatus.connected);
      return;
    }

    final serverContent = message['serverContent'];
    if (serverContent is Map) {
      final content = Map<String, dynamic>.from(serverContent);

      if (content['interrupted'] == true) {
        _emit(_interruptions, null);
      }

      final input = content['inputTranscription'];
      if (input is Map && input['text'] is String) {
        _emit(_userTranscript, input['text'] as String);
      }

      final output = content['outputTranscription'];
      if (output is Map && output['text'] is String) {
        _emit(_modelTranscript, output['text'] as String);
      }

      final turn = content['modelTurn'];
      if (turn is Map && turn['parts'] is List) {
        for (final part in turn['parts'] as List) {
          if (part is Map && part['inlineData'] is Map) {
            final inline = part['inlineData'] as Map;
            final data64 = inline['data'];
            if (data64 is String && data64.isNotEmpty) {
              final bytes = base64Decode(data64);
              _emit(_audioOut, bytes);
              _emitLevel(bytes);
            }
          }
        }
      }
    }

    if (message['goAway'] != null) {
      _emit(_errors, 'The session time limit was reached. Reconnecting…');
    }
  }

  /// Converts a PCM chunk into a 0..1 loudness value for lip sync.
  void _emitLevel(Uint8List pcm) {
    if (pcm.length < 4) return;
    final view = ByteData.sublistView(pcm);
    final samples = pcm.length ~/ 2;
    final step = samples > 400 ? samples ~/ 400 : 1;
    double sumSquares = 0;
    var counted = 0;
    for (var i = 0; i < samples; i += step) {
      final s = view.getInt16(i * 2, Endian.little) / 32768.0;
      sumSquares += s * s;
      counted++;
    }
    if (counted == 0) return;
    final rms = math.sqrt(sumSquares / counted);
    _emit(_modelLevel, (rms * 3.4).clamp(0.0, 1.0));
  }

  String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('401') || text.contains('403')) {
      return 'The API key was rejected for live audio.';
    }
    if (text.contains('SocketException') || text.contains('Failed host')) {
      return 'Could not reach the live server. Check your internet connection.';
    }
    return 'Live connection problem: $text';
  }

  void _emit<T>(StreamController<T> controller, T value) {
    if (!controller.isClosed) controller.add(value);
  }

  /// Closes the session but keeps the service reusable.
  Future<void> close() async {
    _closed = true;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final channel = _channel;
    _channel = null;
    try {
      await channel?.sink.close();
    } catch (_) {
      // Already closed.
    }
  }

  Future<void> dispose() async {
    await close();
    await _status.close();
    await _audioOut.close();
    await _userTranscript.close();
    await _modelTranscript.close();
    await _modelLevel.close();
    await _interruptions.close();
    await _errors.close();
  }
}
