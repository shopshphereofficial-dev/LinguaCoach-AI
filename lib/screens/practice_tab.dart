import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../models/teacher.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';
import '../widgets/common.dart';
import '../widgets/teacher_avatar.dart';
import 'daily_practice_screen.dart';
import 'exercises_screen.dart';
import 'grammar_screen.dart';
import 'live_class_screen.dart';
import 'roleplay_screen.dart';
import 'speaking_screen.dart';

/// The Practice tab: the live class first, then a daily-practice hub and quick
/// access to the other practice modes.
class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  String _code = '';
  Map<String, dynamic>? _daily;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final progress = context.read<ProgressProvider>();
      final practised = progress.progress.languageXp.entries
          .where((e) => e.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      setState(() => _code = practised.isNotEmpty ? practised.first.key : 'es');
      await _loadDaily();
    });
  }

  Language get _language => languageByCode(_code);
  SkillLevel get _level => context.read<ProgressProvider>().levelFor(_code);
  String get _nativeName =>
      languageByCode(context.read<SettingsProvider>().nativeLanguage).name;
  Teacher get _teacher =>
      teacherById(context.read<SettingsProvider>().teacherId);

  Future<void> _loadDaily() async {
    if (_code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _daily = null;
    });
    try {
      final data = await context.read<GeminiService>().dailyPractice(
            targetLanguage: _language.name,
            nativeLanguage: _nativeName,
            level: _level,
          );
      if (!mounted) return;
      setState(() => _daily = data);
    } on GeminiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_code.isEmpty) return const AppLoading();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ------------------------------------------------------- live class
        Card(
          color: _teacher.accent.withOpacity(0.14),
          child: InkWell(
            onTap: () =>
                _open(LiveClassScreen(language: _language, level: _level)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  TeacherAvatar(teacher: _teacher, animate: false, size: 58),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live class with ${_teacher.name}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Talk in real time in ${_language.name} — no waiting.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Practise a language',
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _code,
          isExpanded: true,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.language)),
          items: kLearnableLanguages
              .map(
                (l) => DropdownMenuItem(
                  value: l.code,
                  child: Text('${l.flag}  ${l.name}'),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _code = value);
            _loadDaily();
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '🌞 Today\'s practice · ${_language.name}',
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_error!,
                            style: TextStyle(color: theme.colorScheme.error)),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _loadDaily,
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : _dailyPreview(context),
        ),
        const SizedBox(height: 16),
        Text(
          'More ways to practise',
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        FeatureTile(
          icon: Icons.mic_none,
          title: 'Speaking Practice',
          subtitle: 'Speak on a topic and get a score out of 10',
          color: Colors.blue,
          onTap: () => _open(SpeakingScreen(language: _language, level: _level)),
        ),
        const SizedBox(height: 10),
        FeatureTile(
          icon: Icons.quiz_outlined,
          title: 'Exercises',
          subtitle: 'Quizzes and drills',
          color: Colors.orange,
          onTap: () => _open(ExercisesScreen(language: _language, level: _level)),
        ),
        const SizedBox(height: 10),
        FeatureTile(
          icon: Icons.spellcheck,
          title: 'Grammar Correction',
          subtitle: 'Fix your writing',
          color: Colors.teal,
          onTap: () => _open(GrammarScreen(language: _language, level: _level)),
        ),
        const SizedBox(height: 10),
        FeatureTile(
          icon: Icons.theater_comedy_outlined,
          title: 'Role-play',
          subtitle: 'Real-life scenarios',
          color: Colors.pink,
          onTap: () => _open(RolePlayScreen(language: _language, level: _level)),
        ),
        const SizedBox(height: 10),
        FeatureTile(
          icon: Icons.wb_sunny_outlined,
          title: 'Full daily practice',
          subtitle: 'Word, phrase and challenge',
          color: Colors.amber.shade800,
          onTap: () =>
              _open(DailyPracticeScreen(language: _language, level: _level)),
        ),
      ],
    );
  }

  Widget _dailyPreview(BuildContext context) {
    final theme = Theme.of(context);
    final data = _daily;
    if (data == null) return const Text('No practice available.');
    final word = (data['word'] ?? '').toString();
    final wordTranslation = (data['wordTranslation'] ?? '').toString();
    final phrase = (data['phrase'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                word,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton.filledTonal(
              onPressed: () =>
                  context.read<SpeechService>().speak(word, _code),
              icon: const Icon(Icons.volume_up),
            ),
          ],
        ),
        Text(
          wordTranslation,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (phrase.isNotEmpty) ...[
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 8),
          Text('Phrase: $phrase', style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _loadDaily,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
        ),
      ],
    );
  }
}
