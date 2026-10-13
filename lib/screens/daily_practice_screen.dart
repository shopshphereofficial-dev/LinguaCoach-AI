import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';
import '../widgets/common.dart';

/// 6. Daily Practice — a word, a phrase and a challenge for today.
class DailyPracticeScreen extends StatefulWidget {
  final Language language;
  final SkillLevel level;

  const DailyPracticeScreen({
    super.key,
    required this.language,
    required this.level,
  });

  @override
  State<DailyPracticeScreen> createState() => _DailyPracticeScreenState();
}

class _DailyPracticeScreenState extends State<DailyPracticeScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _nativeName =>
      languageByCode(context.read<SettingsProvider>().nativeLanguage).name;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<GeminiService>().dailyPractice(
            targetLanguage: widget.language.name,
            nativeLanguage: _nativeName,
            level: widget.level,
          );
      if (!mounted) return;
      setState(() => _data = data);
      final progress = context.read<ProgressProvider>();
      await progress.addXp(widget.language.code, 10);
      await progress.registerPractice(widget.language.code);
    } on GeminiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _speak(String text) {
    if (text.trim().isEmpty) return;
    context.read<SpeechService>().speak(text, widget.language.code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.language.flag} Daily · ${widget.level.label}',
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const AppLoading(message: 'Fetching today\'s practice…')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _load)
              : _content(),
    );
  }

  Widget _content() {
    final theme = Theme.of(context);
    final data = _data!;
    final word = (data['word'] ?? '').toString();
    final wordTranslation = (data['wordTranslation'] ?? '').toString();
    final wordExample = (data['wordExample'] ?? '').toString();
    final phrase = (data['phrase'] ?? '').toString();
    final phraseTranslation = (data['phraseTranslation'] ?? '').toString();
    final challenge = (data['challenge'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: '📖 Word of the day',
          child: _termBlock(
            context,
            word,
            wordTranslation,
            example: wordExample,
            onSpeak: () => _speak(word),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '💬 Phrase of the day',
          child: _termBlock(
            context,
            phrase,
            phraseTranslation,
            onSpeak: () => _speak(phrase),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '🎯 Today\'s challenge',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(challenge, style: theme.textTheme.bodyLarge?.copyWith(height: 1.4)),
              const SizedBox(height: 8),
              Text(
                'Try saying it out loud in the Speaking Practice section.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Come back tomorrow for a new set!',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _termBlock(
    BuildContext context,
    String term,
    String translation, {
    String? example,
    required VoidCallback onSpeak,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                term,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton.filledTonal(
              onPressed: onSpeak,
              icon: const Icon(Icons.volume_up),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          translation,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (example != null && example.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            example,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}
