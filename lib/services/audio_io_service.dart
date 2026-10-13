import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';

/// Microphone capture and PCM speaker playback for the live class.
///
/// * Microphone: 16 kHz, 16-bit, mono PCM (what the Live API expects).
/// * Speaker: 24 kHz, 16-bit, mono PCM (what the Live API returns).
class AudioIoService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSubscription;

  bool _speakerReady = false;

  /// Asks for microphone permission (shows the system dialog the first time).
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Starts streaming microphone audio.
  Future<void> startMic(void Function(Uint8List pcm16) onChunk) async {
    await stopMic();
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _micSubscription = stream.listen(onChunk);
    } catch (_) {
      // Reported through the UI by the caller.
    }
  }

  Future<void> stopMic() async {
    await _micSubscription?.cancel();
    _micSubscription = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // Not recording.
    }
  }

  /// Prepares the speaker for 24 kHz PCM playback.
  Future<void> startSpeaker() async {
    if (_speakerReady) return;
    try {
      await FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
      _speakerReady = true;
    } catch (_) {
      _speakerReady = false;
    }
  }

  /// Queues a chunk of teacher audio (PCM 16-bit, 24 kHz, mono).
  Future<void> playPcm(Uint8List pcm16) async {
    if (pcm16.length < 2) return;
    if (!_speakerReady) await startSpeaker();
    if (!_speakerReady) return;

    final view = ByteData.sublistView(pcm16);
    final samples = <int>[];
    for (var i = 0; i + 1 < pcm16.length; i += 2) {
      samples.add(view.getInt16(i, Endian.little));
    }
    try {
      await FlutterPcmSound.feed(PcmArrayInt16.fromList(samples));
    } catch (_) {
      // Drop the chunk if the speaker went away.
    }
  }

  /// Drops anything still queued — used when the learner barges in.
  Future<void> flush() async {
    if (!_speakerReady) return;
    try {
      await FlutterPcmSound.release();
    } catch (_) {
      // Ignore.
    }
    _speakerReady = false;
  }

  Future<void> dispose() async {
    await stopMic();
    try {
      await _recorder.dispose();
    } catch (_) {
      // Ignore.
    }
    await flush();
  }
}
