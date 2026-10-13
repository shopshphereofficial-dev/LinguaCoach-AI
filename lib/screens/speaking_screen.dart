import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';
import '../widgets/common.dart';

/// 2. Speaking Practice — the AI gives a task, the learner speaks, and Gemini
/// scores the transcript out of 10.
class SpeakingScreen extends StatefulWidget {
  final Language language;
  final SkillLevel level;

  const SpeakingScreen({
    super.key,
    required this.language,
    required this.level,
  });

  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen> {
  SpeakingPrompt? _prompt;
  Map<String, dynamic>? _result;

  String _transcript = '';
  bool _loading = true;
  bool _listening = false;
  bool _evaluating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrompt());
  }

  String get _nativeName =>
      languageByCode(context.read<SettingsProvider>().nativeLanguage).name;

  Future<void> _loadPrompt() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _transcript = '';
    });
    try {
      final prompt = await context.read<GeminiService>().speakingPrompt(
            targetLanguage: widget.language.name,
            nativeLanguage: _nativeName,
            level: widget.level,
          );
      if (!mounted) return;
      setState(() => _prompt = prompt);
    } on GeminiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleMic() async {
    final speech = context.read<SpeechService>();
    if (_listening) {
      await speech.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _transcript = '';
    });
    await speech.startListening(
      languageCode: widget.language.code,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _transcript = text);
        if (isFinal) setState(() => _listening = false);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _listening = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _evaluate() async {
    final prompt = _prompt;
    if (prompt == null) return;
    if (_transcript.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap the mic and say something first.')),
      );
      return;
    }
    setState(() => _evaluating = true);
    try {
      final result = await context.read<GeminiService>().evaluateSpeech(
            transcript: _transcript,
            targetLanguage: widget.language.name,
            nativeLanguage: _nativeName,
            level: widget.level,
            prompt: prompt.prompt,
          );
      if (!mounted) return;
      setState(() => _result = result);
      final progress = context.read<ProgressProvider>();
      await progress.addXp(widget.language.code, 15);
      await progress.registerPractice(widget.language.code);
    } on GeminiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speech = context.read<SpeechService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.language.flag} Speaking · ${widget.level.label}'),
      ),
      body: _loading
          ? const AppLoading(message: 'Preparing a task for you…')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadPrompt)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SectionCard(
                      title: 'Your task',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _prompt?.prompt ?? '',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                          if ((_prompt?.hint ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _prompt!.hint,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () =>
                                speech.speak(_prompt?.prompt ?? '', widget.language.code),
                            icon: const Icon(Icons.volume_up),
                            label: const Text('Hear the task'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _toggleMic,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: _listening
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _listening ? Icons.stop : Icons.mic,
                                color: theme.colorScheme.onPrimary,
                                size: 42,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _listening ? 'Listening… tap to stop' : 'Tap to speak',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_transcript.isNotEmpty)
                      SectionCard(
                        title: 'You said',
                        child: Text(
                          _transcript,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _evaluating ? null : _evaluate,
                      icon: _evaluating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text('Get feedback'),
                    ),
                    const SizedBox(height: 20),
                    if (_result != null) _resultCard(context, _result!),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _loadPrompt,
                      icon: const Icon(Icons.refresh),
                      label: const Text('New task'),
                    ),
                  ],
                ),
    );
  }

  Widget _resultCard(BuildContext context, Map<String, dynamic> result) {
    final theme = Theme.of(context);
    final score = int.tryParse('${result['score']}') ?? 0;
    final scoreColor = score >= 8
        ? Colors.green
        : score >= 5
            ? Colors.orange
            : Colors.red;

    return SectionCard(
      title: 'Feedback',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$score/10',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scoreColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Score',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if ((result['feedback'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text((result['feedback']).toString()),
          ],
          if ((result['corrected'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _block(context, 'A natural version', result['corrected'].toString(),
                theme.colorScheme.primary),
          ],
          if ((result['tips'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _block(context, 'Tip', result['tips'].toString(), Colors.orange),
          ],
        ],
      ),
    );
  }

  Widget _block(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
