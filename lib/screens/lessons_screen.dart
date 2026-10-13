import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../widgets/common.dart';
import 'lesson_detail_screen.dart';

/// 3. Lessons — pick a topic and Gemini writes a mini-lesson for it.
class LessonsScreen extends StatefulWidget {
  final Language language;
  final SkillLevel level;

  const LessonsScreen({
    super.key,
    required this.language,
    required this.level,
  });

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  bool _generating = false;

  static const List<String> _topics = [
    'Greetings & introductions',
    'Numbers & counting',
    'Food & drink',
    'Travel & directions',
    'Shopping',
    'Family & friends',
    'Work & office',
    'Health & the body',
    'Weather & seasons',
    'Hobbies & free time',
    'At the restaurant',
    'Making plans',
    'Describing people',
    'Feelings & emotions',
    'Time & dates',
    'School & study',
  ];

  Future<void> _openLesson(String topic) async {
    setState(() => _generating = true);
    final gemini = context.read<GeminiService>();
    final native =
        languageByCode(context.read<SettingsProvider>().nativeLanguage).name;
    try {
      final lesson = await gemini.generateLesson(
        targetLanguage: widget.language.name,
        nativeLanguage: native,
        level: widget.level,
        topic: topic,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonDetailScreen(
            lesson: lesson,
            language: widget.language,
          ),
        ),
      );
    } on GeminiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.language.flag} Lessons · ${widget.level.label}'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Choose a topic',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Gemini will build a lesson with vocabulary and example '
                'sentences for ${widget.language.name}.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ..._topics.map(
                (topic) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FeatureTile(
                    icon: Icons.menu_book_outlined,
                    title: topic,
                    subtitle: 'Tap to generate this lesson',
                    color: Colors.purple,
                    onTap: _generating ? () {} : () => _openLesson(topic),
                  ),
                ),
              ),
            ],
          ),
          if (_generating)
            Container(
              color: theme.colorScheme.surface.withOpacity(0.85),
              child: const AppLoading(message: 'Writing your lesson…'),
            ),
        ],
      ),
    );
  }
}
