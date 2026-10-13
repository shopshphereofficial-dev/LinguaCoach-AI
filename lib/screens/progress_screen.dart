import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement.dart';
import '../models/language.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common.dart';

/// The Progress tab: level, streak, per-language progress and achievements.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = context.watch<ProgressProvider>();

    final practised = progress.progress.languageXp.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final settings = context.watch<SettingsProvider>();
    final goal = settings.dailyGoal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                        'Today\'s goal',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${progress.todayXp} / $goal XP',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ProgressBar(value: goal == 0 ? 0 : progress.todayXp / goal),
                const SizedBox(height: 6),
                Text(
                  progress.todayXp >= goal
                      ? 'Goal reached — nice work! 🎉'
                      : '${goal - progress.todayXp} XP to go today.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level ${progress.level}',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${progress.totalXp} XP total',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text('🔥', style: theme.textTheme.headlineMedium),
                        Text(
                          '${progress.streak}-day streak',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ProgressBar(
                  value: progress.levelProgress,
                  label:
                      '${(progress.levelProgress * 100).round()}% to level ${progress.level + 1}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _stat(context, '${progress.totalXp}', 'Total XP', Icons.bolt)),
            const SizedBox(width: 12),
            Expanded(
                child: _stat(context, '${progress.streak}', 'Day streak',
                    Icons.local_fire_department)),
            const SizedBox(width: 12),
            Expanded(
                child: _stat(context, '${progress.languagesPractised}',
                    'Languages', Icons.translate)),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'By language',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (practised.isEmpty)
          SectionCard(
            child: Text(
              'No practice yet. Start with a language from the Home tab!',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          ...practised.map((entry) {
            final language = languageByCode(entry.key);
            final topXp = practised.first.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(language.flag, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            language.name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${entry.value} XP',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(value: entry.value / topXp),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
        Text(
          'Achievements',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: kAchievements.map((a) {
            final unlocked = progress.isUnlocked(a.id);
            return Card(
              child: Opacity(
                opacity: unlocked ? 1 : 0.45,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        a.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.description,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (unlocked) ...[
                        const SizedBox(height: 4),
                        Icon(Icons.verified, size: 16, color: theme.colorScheme.primary),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String value, String label, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
