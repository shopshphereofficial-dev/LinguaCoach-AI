import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../models/teacher.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/audio_io_service.dart';
import '../services/live_session_service.dart';
import '../widgets/common.dart';
import '../widgets/teacher_avatar.dart';

/// A **live** voice class with a teacher.
///
/// Unlike the push-to-talk speaking practice, this keeps a real-time audio
/// session open with the Gemini Live API: you just talk, the teacher hears you
/// as you speak, answers out loud immediately, and you can interrupt them.
/// The teacher's avatar lip-syncs to their voice.
class LiveClassScreen extends StatefulWidget {
  final Language language;
  final SkillLevel level;

  const LiveClassScreen({
    super.key,
    required this.language,
    required this.level,
  });

  @override
  State<LiveClassScreen> createState() => _LiveClassScreenState();
}

class _LiveClassScreenState extends State<LiveClassScreen> {
  final LiveSessionService _live = LiveSessionService();
  final AudioIoService _audio = AudioIoService();
  final ValueNotifier<double> _level = ValueNotifier<double>(0);
  final TextEditingController _textController = TextEditingController();

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  late Teacher _teacher;
  LiveStatus _status = LiveStatus.idle;
  String _userText = '';
  String _modelText = '';
  String? _error;
  bool _speaking = false;
  bool _muted = false;
  bool _micRunning = false;
  bool _showTextInput = false;
  Timer? _speakTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _speakTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _textController.dispose();
    _live.dispose();
    _audio.dispose();
    _level.dispose();
    super.dispose();
  }

  SettingsProvider get _settings => context.read<SettingsProvider>();

  String get _nativeLanguageName =>
      languageByCode(_settings.nativeLanguage).name;

  String get _systemInstruction {
    final t = _teacher;
    return 'You are ${t.name}, a language teacher holding a LIVE spoken '
        'conversation with a learner who is studying ${widget.language.name} '
        'at a ${widget.level.label} level. '
        'Your native language (for any explanation) is $_nativeLanguageName. '
        'Your personality: ${t.personality} '
        'Rules for this live call: '
        '- Always speak in ${widget.language.name}, at a ${widget.level.label} '
        'level, in short natural sentences of one to three sentences. '
        '- This is speech, not text: never use markdown, bullet points, emoji '
        'or stage directions. '
        '- When the learner makes a mistake, correct it kindly in one short '
        'sentence, then keep the conversation going with a question. '
        '- If the learner speaks in $_nativeLanguageName, gently encourage them '
        'to try again in ${widget.language.name}. '
        '- Always end your turn with a short question so the learner keeps '
        'talking.';
  }

  Future<void> _start() async {
    _teacher = teacherById(_settings.teacherId);
    setState(() {
      _error = null;
      _status = LiveStatus.connecting;
    });

    _subscriptions.addAll([
      _live.status.listen((s) {
        if (!mounted) return;
        setState(() => _status = s);
        if (s == LiveStatus.connected) _onConnected();
      }),
      _live.audioOut.listen(_onAudio),
      _live.modelLevel.listen((v) => _level.value = v),
      _live.userTranscript.listen((t) {
        if (mounted) setState(() => _userText = t);
      }),
      _live.modelTranscript.listen((t) {
        if (mounted) setState(() => _modelText = t);
      }),
      _live.interruptions.listen((_) {
        _audio.flush();
        _level.value = 0;
        if (mounted) {
          setState(() {
            _speaking = false;
            _modelText = '';
          });
        }
      }),
      _live.errors.listen((message) {
        if (mounted) setState(() => _error = message);
      }),
    ]);

    await _audio.startSpeaker();
    await _live.connect(
      apiKey: _settings.apiKey,
      model: _settings.liveModel,
      systemInstruction: _systemInstruction,
      voiceName: _teacher.voiceName,
    );
  }

  Future<void> _onConnected() async {
    final granted = await _audio.hasPermission();
    if (!granted) {
      if (mounted) {
        setState(() => _error =
            'Microphone permission is needed for a live class. You can still '
            'type your answers below.');
      }
      return;
    }
    await _startMic();

    // Kick the teacher off so the class starts by itself.
    _live.sendText(
      '(The learner has just joined the call. Greet them in '
      '${widget.language.name} and ask one simple question to begin.)',
    );
  }

  Future<void> _startMic() async {
    await _audio.startMic((pcm) {
      if (_muted) return;
      _live.sendAudio(pcm);
    });
    if (mounted) {
      setState(() {
        _micRunning = true;
        _muted = false;
      });
    }
  }

  void _onAudio(Uint8List chunk) {
    _audio.playPcm(chunk);
    if (!_speaking && mounted) setState(() => _speaking = true);
    _speakTimer?.cancel();
    _speakTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _speaking = false);
    });
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    setState(() => _muted = next);
    if (next) {
      _live.sendAudioStreamEnd();
    }
  }

  void _sendTyped() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() {
      _userText = text;
      _modelText = '';
    });
    _live.sendText(text);
  }

  Future<void> _pickTeacher() async {
    final selected = await showModalBottomSheet<Teacher>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose your teacher',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...kTeachers.map(
            (t) => ListTile(
              leading: CircleAvatar(
                backgroundColor: t.accent.withOpacity(0.18),
                child: Text(
                  t.name.substring(0, 1),
                  style: TextStyle(
                    color: t.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text('${t.name}  ·  ${t.specialty}'),
              subtitle: Text(t.tagline),
              trailing: t.id == _teacher.id
                  ? const Icon(Icons.check_circle)
                  : null,
              onTap: () => Navigator.pop(context, t),
            ),
          ),
        ],
      ),
    );
    if (selected != null && selected.id != _teacher.id) {
      await _settings.setTeacherId(selected.id);
      await _endSession(award: false);
      await _start();
    }
  }

  Future<void> _endSession({bool award = true}) async {
    _speakTimer?.cancel();
    await _audio.stopMic();
    await _live.close();
    _level.value = 0;
    if (award) {
      final progress = context.read<ProgressProvider>();
      await progress.addXp(widget.language.code, 25);
      await progress.registerPractice(widget.language.code);
    }
  }

  Future<void> _leave() async {
    await _endSession();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _endSession();
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.language.flag} Live class · ${widget.level.label}'),
          actions: [
            IconButton(
              tooltip: 'Change teacher',
              onPressed: _pickTeacher,
              icon: const Icon(Icons.switch_account),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    Center(
                      child: TeacherAvatar(
                        teacher: _teacher,
                        level: _level,
                        speaking: _speaking,
                        listening: _status == LiveStatus.connected &&
                            !_speaking &&
                            !_muted,
                        size: 230,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        _teacher.name,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Center(
                      child: Text(
                        '${_teacher.tagline} · ${_teacher.specialty}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: _statusChip(theme)),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_modelText.trim().isNotEmpty)
                      _caption(
                        context,
                        icon: Icons.record_voice_over,
                        color: _teacher.accent,
                        label: _teacher.name,
                        text: _modelText,
                      ),
                    if (_userText.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _caption(
                        context,
                        icon: Icons.mic,
                        color: theme.colorScheme.primary,
                        label: 'You',
                        text: _userText,
                      ),
                    ],
                  ],
                ),
              ),
              if (_showTextInput)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendTyped(),
                          decoration: InputDecoration(
                            hintText: 'Type in ${widget.language.name}…',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sendTyped,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              _controls(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(ThemeData theme) {
    String label;
    Color color;
    switch (_status) {
      case LiveStatus.connecting:
        label = 'Connecting…';
        color = Colors.orange;
        break;
      case LiveStatus.connected:
        if (_muted) {
          label = 'Microphone muted';
          color = Colors.grey;
        } else if (_speaking) {
          label = '${_teacher.name} is speaking…';
          color = _teacher.accent;
        } else {
          label = 'Listening… just talk';
          color = Colors.green;
        }
        break;
      case LiveStatus.ended:
        label = 'Session ended';
        color = Colors.grey;
        break;
      case LiveStatus.error:
        label = 'Connection problem';
        color = theme.colorScheme.error;
        break;
      case LiveStatus.idle:
        label = 'Ready';
        color = Colors.grey;
    }
    return PillBadge(
      icon: _status == LiveStatus.connected && !_speaking && !_muted
          ? Icons.mic
          : Icons.graphic_eq,
      label: label,
      color: color,
    );
  }

  Widget _caption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String text,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.35)),
        ],
      ),
    );
  }

  Widget _controls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: _micRunning ? _toggleMute : _startMic,
                icon: Icon(_muted ? Icons.mic_off : Icons.mic),
                style: IconButton.styleFrom(
                  backgroundColor: _muted
                      ? theme.colorScheme.errorContainer
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(_muted ? 'Unmute' : 'Mute', style: theme.textTheme.labelSmall),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filled(
                onPressed: _leave,
                icon: const Icon(Icons.call_end),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 4),
              Text('End', style: theme.textTheme.labelSmall),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: () =>
                    setState(() => _showTextInput = !_showTextInput),
                icon: const Icon(Icons.keyboard),
              ),
              const SizedBox(height: 4),
              Text('Type', style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
