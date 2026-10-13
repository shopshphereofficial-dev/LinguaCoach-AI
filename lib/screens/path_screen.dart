import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/curriculum.dart';
import '../models/language.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common.dart';
import '../widgets/teacher_avatar.dart';
import 'lesson_player_screen.dart';

/// The learning path for one language: units of lessons, unlocked in order.
class PathScreen extends StatelessWidget {
  final Language language;

  const PathScreen({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = context.watch<ProgressProvider>();
    final settings = context.watch<SettingsProvider>();
    final teacher = teacherById(settings.teacherId);

    final done = progress.lessonsDone(language.code);
    final total = kLessonPath.length;
    final current = progress.currentSlot(language.code);

    return Scaffold(
      appBar: AppBar(
        title: Text('${language.flag}  ${language.name} path'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // ------------------------------------------------------- progress
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
                          done >= total
                              ? 'Course complete! 🎉'
                              : '${current?.unit.title ?? ''}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      PillBadge(
                        label: '$done / $total lessons',
                        color: language.colorFor(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ProgressBar(
                    value: progress.pathProgress(language.code),
                    color: language.colorFor(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TeacherAvatar(
                        teacher: teacher,
                        animate: false,
                        size: 46,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Every lesson ends with a short live chat with '
                          '${teacher.name} on that topic.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (current != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openLesson(
                          context,
                          current.unit,
                          current.lesson,
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          done == 0
                              ? 'Start: ${current.lesson.title}'
                              : 'Continue: ${current.lesson.title}',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ----------------------------------------------------------- path
          ...List.generate(kCurriculum.length, (unitIndex) {
            final unit = kCurriculum[unitIndex];
            final unitDone = unit.lessons
                .where((l) => progress.isLessonDone(language.code, l.id))
                .length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 34,
                        decoration: BoxDecoration(
                          color: unit.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.title,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${unit.subtitle} · ${unit.level.label}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$unitDone/${unit.lessons.length}',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                ...List.generate(unit.lessons.length, (lessonIndex) {
                  final lesson = unit.lessons[lessonIndex];
                  final slot = kLessonPath.firstWhere(
                    (s) => s.lesson.id == lesson.id,
                  );
                  final stars = progress.starsFor(language.code, lesson.id);
                  final unlocked =
                      progress.isLessonUnlocked(language.code, slot.flatIndex);
                  return _LessonRow(
                    lesson: lesson,
                    unit: unit,
                    stars: stars,
                    unlocked: unlocked,
                    isCurrent: current?.lesson.id == lesson.id,
                    isLast: lessonIndex == unit.lessons.length - 1,
                    onTap: unlocked
                        ? () => _openLesson(context, unit, lesson)
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Finish the previous lesson to unlock this one.',
                                ),
                              ),
                            ),
                  );
                }),
                const SizedBox(height: 18),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _openLesson(BuildContext context, Unit unit, LessonNode lesson) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonPlayerScreen(
          language: language,
          unit: unit,
          lesson: lesson,
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final LessonNode lesson;
  final Unit unit;
  final int stars;
  final bool unlocked;
  final bool isCurrent;
  final bool isLast;
  final VoidCallback onTap;

  const _LessonRow({
    required this.lesson,
    required this.unit,
    required this.stars,
    required this.unlocked,
    required this.isCurrent,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = stars > 0;
    final color = unlocked ? unit.color : theme.colorScheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: done
                        ? color
                        : unlocked
                            ? color.withOpacity(0.22)
                            : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: color, width: 3)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      done ? '✓' : lesson.emoji,
                      style: TextStyle(
                        fontSize: done ? 16 : 15,
                        color: done ? Colors.white : null,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      color: done
                          ? color.withOpacity(0.5)
                          : theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                color: isCurrent
                    ? color.withOpacity(0.14)
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lesson.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: unlocked ? null : theme.disabledColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                done
                                    ? 'Completed · replay anytime'
                                    : unlocked
                                        ? 'Tap to start'
                                        : 'Locked',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (done)
                          Row(
                            children: List.generate(
                              3,
                              (i) => Icon(
                                i < stars ? Icons.star : Icons.star_border,
                                size: 16,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          )
                        else
                          Icon(
                            unlocked ? Icons.chevron_right : Icons.lock_outline,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A per-language accent colour, derived from the language list order.
extension LanguageAccent on Language {
  Color colorFor() {
    const palette = [
      Color(0xFF58CC02),
      Color(0xFF1CB0F6),
      Color(0xFFCE82FF),
      Color(0xFFFF9600),
      Color(0xFFFF4B4B),
      Color(0xFF14D4C4),
      Color(0xFFFFC800),
    ];
    return palette[code.hashCode.abs() % palette.length];
  }
}
