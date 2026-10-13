import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../models/quiz_question.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';
import '../widgets/common.dart';

/// 4. Exercises — Gemini-generated quizzes with four question types.
class ExercisesScreen extends StatefulWidget {
  final Language language;
  final SkillLevel level;

  const ExercisesScreen({
    super.key,
    required this.language,
    required this.level,
  });

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  static const List<String> _topics = [
    'everyday vocabulary',
    'greetings and polite phrases',
    'food and ordering',
    'travel and directions',
    'numbers and time',
    'work and office',
    'verbs in the present tense',
    'common questions',
  ];

  String? _topic;
  List<QuizQuestion> _questions = [];
  int _index = 0;
  int _correct = 0;
  bool _loading = false;
  bool _checked = false;
  bool _finished = false;
  String? _error;

  String _selected = '';
  final TextEditingController _answerController = TextEditingController();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _start(String topic) async {
    setState(() {
      _topic = topic;
      _loading = true;
      _error = null;
      _index = 0;
      _correct = 0;
      _checked = false;
      _finished = false;
      _selected = '';
      _answerController.clear();
    });
    try {
      final questions = await context.read<GeminiService>().generateQuiz(
            targetLanguage: widget.language.name,
            nativeLanguage:
                languageByCode(context.read<SettingsProvider>().nativeLanguage)
                    .name,
            level: widget.level,
            topic: topic,
            count: 5,
          );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } on GeminiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  QuizQuestion get _current => _questions[_index];

  bool _isCorrect() {
    if (_current.isChoice) return _selected == _current.answer;
    return _current.matches(_answerController.text);
  }

  Future<void> _check() async {
    final correct = _isCorrect();
    setState(() {
      _checked = true;
      if (correct) _correct += 1;
    });
  }

  Future<void> _next() async {
    if (_index + 1 >= _questions.length) {
      setState(() => _finished = true);
      final progress = context.read<ProgressProvider>();
      await progress.addXp(widget.language.code, _correct * 10);
      await progress.registerPractice(widget.language.code);
      return;
    }
    setState(() {
      _index += 1;
      _checked = false;
      _selected = '';
      _answerController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.language.flag} Exercises · ${widget.level.label}'),
        actions: [
          if (_topic != null)
            IconButton(
              tooltip: 'Change topic',
              onPressed: () => setState(() {
                _topic = null;
                _questions = [];
                _finished = false;
              }),
              icon: const Icon(Icons.swap_horiz),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_topic == null) return _topicPicker();
    if (_loading) return const AppLoading(message: 'Writing your exercises…');
    if (_error != null) {
      return AppErrorView(message: _error!, onRetry: () => _start(_topic!));
    }
    if (_finished) return _summary();
    if (_questions.isEmpty) return const AppLoading();

    final theme = Theme.of(context);
    final question = _current;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: ProgressBar(
                value: (_index + 1) / _questions.length,
                label: 'Question ${_index + 1} of ${_questions.length}',
              ),
            ),
            const SizedBox(width: 12),
            PillBadge(label: '$_correct ✓', color: Colors.green),
          ],
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _typeLabel(question.type),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                question.prompt,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              if (question.isListening) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context
                      .read<SpeechService>()
                      .speak(question.prompt, widget.language.code),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play audio'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (question.isChoice)
          ...question.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _optionTile(option, question),
            ),
          )
        else
          TextField(
            controller: _answerController,
            enabled: !_checked,
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Type your answer in ${widget.language.name}…',
            ),
          ),
        const SizedBox(height: 16),
        if (!_checked)
          FilledButton(
            onPressed: (question.isChoice
                    ? _selected.isNotEmpty
                    : _answerController.text.trim().isNotEmpty)
                ? _check
                : null,
            child: const Text('Check'),
          )
        else ...[
          _resultBanner(),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _next,
            child: Text(_index + 1 >= _questions.length
                ? 'See results'
                : 'Next question'),
          ),
        ],
      ],
    );
  }

  Widget _optionTile(String option, QuizQuestion question) {
    final theme = Theme.of(context);
    Color? border;
    Color? bg;
    if (_checked) {
      if (option == question.answer) {
        border = Colors.green;
        bg = Colors.green.withOpacity(0.12);
      } else if (option == _selected) {
        border = theme.colorScheme.error;
        bg = theme.colorScheme.error.withOpacity(0.12);
      }
    } else if (option == _selected) {
      border = theme.colorScheme.primary;
      bg = theme.colorScheme.primary.withOpacity(0.12);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _checked ? null : () => setState(() => _selected = option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg ?? theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: border ?? theme.colorScheme.outlineVariant.withOpacity(0.6),
            width: border != null ? 2 : 1,
          ),
        ),
        child: Text(option, style: theme.textTheme.bodyLarge),
      ),
    );
  }

  Widget _resultBanner() {
    final theme = Theme.of(context);
    final correct = _isCorrect();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (correct ? Colors.green : theme.colorScheme.error)
            .withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle : Icons.cancel,
                color: correct ? Colors.green : theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                correct ? 'Correct!' : 'Not quite',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (!correct) ...[
            const SizedBox(height: 6),
            Text('Answer: ${_current.answer}'),
          ],
          if (_current.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _current.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary() {
    final theme = Theme.of(context);
    final total = _questions.length;
    final percent = total == 0 ? 0 : ((_correct / total) * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              percent >= 80 ? '🎉' : '💪',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 12),
            Text(
              'You scored $_correct / $total',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'You earned ${_correct * 10} XP.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _start(_topic ?? _topics.first),
              icon: const Icon(Icons.replay),
              label: const Text('Practise again'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() {
                _topic = null;
                _questions = [];
                _finished = false;
              }),
              child: const Text('Change topic'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topicPicker() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'What should we practise?',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Gemini will generate five mixed exercises for ${widget.language.name}.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        ..._topics.map(
          (topic) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FeatureTile(
              icon: Icons.quiz_outlined,
              title: topic,
              subtitle: 'Generate exercises',
              color: Colors.orange,
              onTap: () => _start(topic),
            ),
          ),
        ),
      ],
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'fillInBlank':
        return 'FILL IN THE BLANK';
      case 'translation':
        return 'TRANSLATE';
      case 'listening':
        return 'LISTENING';
      default:
        return 'MULTIPLE CHOICE';
    }
  }
}
