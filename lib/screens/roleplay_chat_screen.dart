import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/language.dart';
import '../models/roleplay.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/common.dart';

/// A live role-play conversation with the AI playing a character.
class RolePlayChatScreen extends StatefulWidget {
  final RolePlayScenario scenario;
  final Language language;
  final SkillLevel level;

  const RolePlayChatScreen({
    super.key,
    required this.scenario,
    required this.language,
    required this.level,
  });

  @override
  State<RolePlayChatScreen> createState() => _RolePlayChatScreenState();
}

class _RolePlayChatScreenState extends State<RolePlayChatScreen> {
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
      final opening = await context.read<GeminiService>().rolePlayOpening(
            scenario: widget.scenario,
            targetLanguage: widget.language.name,
            nativeLanguage: _nativeName,
            level: widget.level,
          );
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage(role: 'model', text: opening)));
    } on GeminiException catch (e) {
      _showError(e.message);
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
      final reply = await gemini.rolePlayReply(
        scenario: widget.scenario,
        targetLanguage: widget.language.name,
        nativeLanguage: _nativeName,
        level: widget.level,
        history: history,
        userMessage: text,
      );
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage(role: 'model', text: reply)));
      await progress.addXp(widget.language.code, 5);
      await progress.registerPractice(widget.language.code);
    } on GeminiException catch (e) {
      _showError(e.message);
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
        title: Text('${widget.scenario.emoji} ${widget.scenario.title}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && _busy
                ? const AppLoading(message: 'Setting the scene…')
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
                        onSpeak:
                            message.isUser ? null : () => _speak(message.text),
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
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Reply in ${widget.language.name}…',
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
