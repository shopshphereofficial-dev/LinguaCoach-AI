import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/curriculum.dart';
import '../models/language.dart';
import '../models/teacher.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common.dart';
import '../widgets/teacher_avatar.dart';
import 'conversation_screen.dart';
import 'daily_practice_screen.dart';
import 'exercises_screen.dart';
import 'grammar_screen.dart';
import 'lessons_screen.dart';
import 'live_class_screen.dart';
import 'path_screen.dart';
import 'roleplay_screen.dart';
import 'speaking_screen.dart';

/// The hub for one language: level selector, the live class and the rest.
class LanguageDetailScreen extends StatelessWidget {
  final Language language;

  const LanguageDetailScreen({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = context.watch<ProgressProvider>();
    final settings = context.watch<SettingsProvider>();
    final level = progress.levelFor(language.code);
    final xp = progress.xpFor(language.code);
    final native = languageByCode(settings.nativeLanguage);
    final teacher = teacherById(settings.teacherId);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(language.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Flexible(child: Text(language.name)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ------------------------------------------------- learning path
          Card(
            color: language.colorFor().withOpacity(0.14),
            child: InkWell(
              onTap: () => _open(context, PathScreen(language: language)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            progress.lessonsDone(language.code) == 0
                                ? 'Start the course'
                                : 'Continue your course',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        PillBadge(
                          label:
                              '${progress.lessonsDone(language.code)}/${kLessonPath.length}',
                          color: language.colorFor(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(
                      value: progress.pathProgress(language.code),
                      color: language.colorFor(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A guided path of ${kLessonPath.length} lessons — new words, '
                      'practice and a short live chat with your teacher in every one.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ---------------------------------------------------- live class
          Card(
            child: InkWell(
              onTap: () => _open(
                context,
                LiveClassScreen(language: language, level: level),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    TeacherAvatar(
                      teacher: teacher,
                      animate: false,
                      size: 56,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live class with ${teacher.name}',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Real-time voice — just talk, ${teacher.name} '
                            'answers instantly and you can interrupt.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // -------------------------------------------------------- level
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your level',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      PillBadge(icon: Icons.bolt, label: '$xp XP'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: SkillLevel.values.map((l) {
                      return ChoiceChip(
                        label: Text(l.label),
                        selected: level == l,
                        onSelected: (_) => progress.setLevel(language.code, l),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    level.blurb,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Practise',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          FeatureTile(
            icon: Icons.chat_bubble_outline,
            title: 'AI Conversation Coach',
            subtitle: 'Chat with a tutor, get corrections as you go',
            color: Colors.green,
            onTap: () => _open(
              context,
              ConversationScreen(language: language, level: level),
            ),
          ),
          const SizedBox(height: 10),
          FeatureTile(
            icon: Icons.mic_none,
            title: 'Speaking Practice',
            subtitle: 'Speak on a topic and get a score out of 10',
            color: Colors.blue,
            onTap: () => _open(
              context,
              SpeakingScreen(language: language, level: level),
            ),
          ),
          const SizedBox(height: 10),
          FeatureTile(
            icon: Icons.menu_book_outlined,
            title: 'Lessons',
            subtitle: 'AI lessons with vocabulary and examples',
            color: Colors.purple,
            onTap: () => _open(
              context,
              LessonsScreen(language: language, level: level),
            ),
          ),
          const SizedBox(height: 10),
          FeatureTile(
            icon: Icons.quiz_outlined,
            title: 'Exercises',
            subtitle: 'Quizzes: multiple choice, blanks, listening',
            color: Colors.orange,
            onTap: () => _open(
              context,
              ExercisesScreen(language: language, level: level),
            ),
          ),
          const SizedBox(height: 10),
          FeatureTile(
            icon: Icons.spellcheck,
            title: 'Grammar Correction',
            subtitle: 'Paste any text and get it fixed with explanations',
            color: Colors.teal,
            onTap: () => _open(
              context,
              GrammarScreen(language: language, level: level),
            ),
          ),
          const SizedBox(height: 10),
          FeatureTile(
            icon: Icons.wb_sunny_outlined,
            title: 'Daily Practice',
            subtitle: 'A word, a phrase and a challenge for today',
            color: Colors.amber.shade800,
            onTap: () => _open(
              context,
              DailyPracticeScreen(language: language, level: level),
            ),
          ),
          const SizedBox(height: 10),
          FeatureTile(
            icon: Icons.theater_comedy_outlined,
            title: 'Role-play Scenarios',
            subtitle: 'Restaurant, airport, interview and more',
            color: Colors.pink,
            onTap: () => _open(
              context,
              RolePlayScreen(language: language, level: level),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Explanations in ${native.name} ${native.flag}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
