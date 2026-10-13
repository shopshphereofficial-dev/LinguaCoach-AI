import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/curriculum.dart';
import '../models/language.dart';
import '../models/quiz_question.dart';
import '../models/teacher.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/curriculum_service.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';
import '../widgets/common.dart';
import '../widgets/teacher_avatar.dart';
import 'live_class_screen.dart';

/// Plays one lesson on the path:
/// Learn → Sentences → Practice → Speak → Live with the teacher.
class LessonPlayerScreen extends StatefulWidget {
  final Language language;
  final Unit unit;
  final LessonNode lesson;

  const LessonPlayerScreen({
    super.key,
    required this.language,
    required this.unit,
    required this.lesson,
  });

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  static const int _stepCount = 5;

  LessonContent? _content;
  bool _loading = true;
  String? _error;

  int _step = 0;

  // practice
  int _qIndex = 0;
  String _selected = '';
  bool _checked = false;
  int _correct = 0;
  final TextEditingController _answerController = TextEditingController();

  // speak
  bool _listening = false;
  String _transcript = '';
  bool _spoke = false;

  bool _finished = false;
  int _earnedStars = 0;
  int _earnedXp = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final native =
          languageByCode(context.read<SettingsProvider>().nativeLanguage).name;
      final content = await context.read<CurriculumService>().load(
            language: widget.language,
            level: widget.unit.level,
            node: widget.lesson,
            nativeLanguageName: native,
            forceRefresh: force,
          );
      if (!mounted) return;
      setState(() {
        _content = content;
        _loading = false;
      });
    } on GeminiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _speak(String text) {
    if (text.trim().isEmpty) return;
    context.read<SpeechService>().speak(text, widget.language.code);
  }

  // --------------------------------------------------------------- practice

  QuizQuestion get _question => _content!.quiz[_qIndex];

  bool _isCorrect() {
    if (_question.isChoice) return _selected == _question.answer;
    return _question.matches(_answerController.text);
  }

  void _check() {
    setState(() {
      _checked = true;
      if (_isCorrect()) _correct++;
    });
  }

  void _nextQuestion() {
    if (_qIndex + 1 >= _content!.quiz.length) {
      setState(() => _step = 3);
      return;
    }
    setState(() {
      _qIndex++;
      _checked = false;
      _selected = '';
      _answerController.clear();
    });
  }

  // ------------------------------------------------------------------ speak

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
        setState(() {
          _transcript = text;
          if (text.trim().isNotEmpty) _spoke = true;
        });
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

  // ----------------------------------------------------------------- finish

  int _computeStars() {
    final total = _content?.quiz.length ?? 0;
    if (total == 0) return 3;
    final pct = _correct / total;
    if (pct >= 0.9) return 3;
    if (pct >= 0.7) return 2;
    return 1;
  }

  Future<void> _finish() async {
    final stars = _computeStars();
    final xp = 20 + _correct * 8 + (_spoke ? 10 : 0);
    final progress = context.read<ProgressProvider>();
    await progress.completeLesson(
      languageCode: widget.language.code,
      lessonId: widget.lesson.id,
      stars: stars,
      xp: xp,
    );
    if (!mounted) return;
    setState(() {
      _finished = true;
      _earnedStars = stars;
      _earnedXp = xp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.lesson.emoji}  ${widget.lesson.title}'),
        actions: [
          IconButton(
            tooltip: 'Regenerate this lesson',
            onPressed: _loading ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const AppLoading(message: 'Building your lesson…')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: () => _load(force: true))
              : _finished
                  ? _result(theme)
                  : Column(
                      children: [
                        _stepBar(theme),
                        Expanded(child: _stepBody(theme)),
                        _bottomBar(theme),
                      ],
                    ),
    );
  }

  // ------------------------------------------------------------- step chrome

  Widget _stepBar(ThemeData theme) {
    const labels = ['Learn', 'Sentences', 'Practice', 'Speak', 'Live'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < _stepCount; i++) ...[
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? widget.unit.color
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Step ${_step + 1} of $_stepCount · ${labels[_step]}',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(ThemeData theme) {
    switch (_step) {
      case 0:
        return _learnStep(theme);
      case 1:
        return _sentencesStep(theme);
      case 2:
        return _practiceStep(theme);
      case 3:
        return _speakStep(theme);
      default:
        return _liveStep(theme);
    }
  }

  Widget _bottomBar(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _primaryAction,
            child: Text(_primaryLabel),
          ),
        ),
      ),
    );
  }

  String get _primaryLabel {
    switch (_step) {
      case 0:
        return 'I know these words';
      case 1:
        return 'Next: practice';
      case 2:
        return _checked ? 'Continue' : 'Check';
      case 3:
        return 'Next: live practice';
      default:
        return 'Finish lesson';
    }
  }

  void _primaryAction() {
    switch (_step) {
      case 0:
      case 1:
        setState(() => _step++);
        break;
      case 2:
        if (_checked) {
          _nextQuestion();
        } else {
          _check();
        }
        break;
      case 3:
        setState(() => _step = 4);
        break;
      default:
        _finish();
    }
  }

  // -------------------------------------------------------------- step views

  Widget _learnStep(ThemeData theme) {
    final vocab = _content!.vocabulary;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'New words',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap the speaker to hear each one.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        ...vocab.map(
          (v) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.term,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          v.translation,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (v.example.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            v.example,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _speak(v.term),
                    icon: const Icon(Icons.volume_up),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sentencesStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Putting it together',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        ..._content!.sentences.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.target,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.native,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _speak(s.target),
                    icon: const Icon(Icons.volume_up),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _practiceStep(ThemeData theme) {
    final q = _question;
    final total = _content!.quiz.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: ProgressBar(
                value: (_qIndex + 1) / total,
                label: 'Question ${_qIndex + 1} of $total',
              ),
            ),
            const SizedBox(width: 12),
            PillBadge(label: '$_correct ✓', color: Colors.green),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q.type.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: widget.unit.color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                q.prompt,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.4),
              ),
              if (q.isListening) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _speak(q.prompt),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play audio'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (q.isChoice)
          ...q.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _optionTile(theme, option, q),
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
        if (_checked) ...[
          const SizedBox(height: 14),
          _resultBanner(theme),
        ],
      ],
    );
  }

  Widget _optionTile(ThemeData theme, String option, QuizQuestion q) {
    Color? border;
    Color? bg;
    if (_checked) {
      if (option == q.answer) {
        border = Colors.green;
        bg = Colors.green.withOpacity(0.12);
      } else if (option == _selected) {
        border = theme.colorScheme.error;
        bg = theme.colorScheme.error.withOpacity(0.12);
      }
    } else if (option == _selected) {
      border = widget.unit.color;
      bg = widget.unit.color.withOpacity(0.12);
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

  Widget _resultBanner(ThemeData theme) {
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
            Text('Answer: ${_question.answer}'),
          ],
          if (_question.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _question.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _speakStep(ThemeData theme) {
    final task = _content!.speakingTask;
    final hint = _content!.speakingHint;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Say this out loud',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.4),
              ),
              if (hint.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  hint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _speak(task),
                icon: const Icon(Icons.volume_up),
                label: const Text('Hear it'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _toggleMic,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: _listening
                    ? theme.colorScheme.error
                    : widget.unit.color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _listening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _listening ? 'Listening… tap to stop' : 'Tap and say it',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (_transcript.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionCard(
            title: 'You said',
            child: Text(_transcript, style: theme.textTheme.bodyLarge),
          ),
        ],
      ],
    );
  }

  Widget _liveStep(ThemeData theme) {
    final teacher = teacherById(context.read<SettingsProvider>().teacherId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: TeacherAvatar(teacher: teacher, animate: false, size: 130)),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Practise with ${teacher.name}',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Have a short live conversation about “${widget.lesson.title}”.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LiveClassScreen(
                  language: widget.language,
                  level: widget.unit.level,
                  lessonTopic: widget.lesson.topic,
                  lessonTitle: widget.lesson.title,
                ),
              ),
            );
          },
          icon: const Icon(Icons.graphic_eq),
          label: Text('Start live chat with ${teacher.name}'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _finish,
          child: const Text('Skip and finish the lesson'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ result

  Widget _result(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _earnedStars == 3 ? '🎉' : _earnedStars == 2 ? '👏' : '💪',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Icon(
                  i < _earnedStars ? Icons.star : Icons.star_border,
                  size: 40,
                  color: Colors.amber.shade700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Lesson complete!',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'You answered $_correct of ${_content!.quiz.length} correctly and '
              'earned $_earnedXp XP.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('Back to the path'),
            ),
          ],
        ),
      ),
    );
  }
}
