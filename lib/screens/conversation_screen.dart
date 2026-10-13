import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/language.dart';
import '../models/teacher.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/common.dart';
import '../widgets/teacher_avatar.dart';
import 'live_class_screen.dart';

/// 1. AI Conversation Coach — a chat with a tutor that corrects the learner
/// after every message.
class ConversationScreen extends StatefulWidget {
  final Language language;
  final SkillLevel level;

  const ConversationScreen({
    super.key,
    required this.language,
    required this.level,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _busy = false;
  bool _listening = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _nativeName =>
      languageByCode(context.read<SettingsProvider>().nativeLanguage).name;

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    setState(() => _busy = true);
    try {
      final turn = await context.read<GeminiService>().tutorTurn(
            targetLanguage: widget.language.name,
            nativeLanguage: _nativeName,
            level: widget.level,
            history: const [],
            userMessage:
                'Greet me warmly in one short sentence and ask me a simple question to start our chat.',
          );
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage(role: 'model', text: turn.reply)));
    } on GeminiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    _controller.clear();

    final gemini = context.read<GeminiService>();
    final progress = context.read<ProgressProvider>();
    final history = List<ChatMessage>.from(_messages);

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _busy = true;
    });
    _scrollToEnd();

    try {
      final turn = await gemini.tutorTurn(
        targetLanguage: widget.language.name,
        nativeLanguage: _nativeName,
        level: widget.level,
        history: history,
        userMessage: text,
      );
      if (!mounted) return;
      setState(() {
        final index = _messages.lastIndexWhere((m) => m.isUser);
        if (index != -1) {
          _messages[index] = ChatMessage(
            role: 'user',
            text: _messages[index].text,
            feedback: turn.feedback,
            time: _messages[index].time,
          );
        }
        _messages.add(ChatMessage(role: 'model', text: turn.reply));
      });
      await progress.addXp(widget.language.code, 5);
      await progress.registerPractice(widget.language.code);
    } on GeminiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  Future<void> _toggleMic() async {
    final speech = context.read<SpeechService>();
    if (_listening) {
      await speech.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await speech.startListening(
      languageCode: widget.language.code,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _controller.text = text);
        if (isFinal) setState(() => _listening = false);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _listening = false);
        _showError(message);
      },
    );
  }

  void _speak(String text) {
    context.read<SpeechService>().speak(text, widget.language.code);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 160,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            TeacherAvatar(
              teacher: teacherById(context.read<SettingsProvider>().teacherId),
              animate: false,
              size: 30,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${widget.language.flag} Text chat · ${widget.level.label}',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Go live with a teacher',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LiveClassScreen(
                  language: widget.language,
                  level: widget.level,
                ),
              ),
            ),
            icon: const Icon(Icons.graphic_eq),
          ),
          IconButton(
            tooltip: 'Clear chat',
            onPressed: () => setState(() {
              _messages.clear();
              _started = false;
              _start();
            }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && _busy
                ? const AppLoading(message: 'Starting your conversation…')
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_busy ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final message = _messages[index];
                      return ChatBubble(
                        message: message,
                        onSpeak: message.isUser
                            ? null
                            : () => _speak(message.text),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _busy ? null : _toggleMic,
                    icon: Icon(_listening ? Icons.stop : Icons.mic),
                    style: IconButton.styleFrom(
                      backgroundColor: _listening
                          ? Theme.of(context).colorScheme.errorContainer
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type in ${widget.language.name}…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
