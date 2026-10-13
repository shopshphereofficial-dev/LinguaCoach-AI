/// A badge the learner can unlock.
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// All achievements. Unlocking rules live in [ProgressProvider].
const List<Achievement> kAchievements = [
  Achievement(
    id: 'first_step',
    title: 'First Steps',
    description: 'Complete your first practice session.',
    icon: '🐣',
  ),
  Achievement(
    id: 'streak_3',
    title: 'On a Roll',
    description: 'Reach a 3-day streak.',
    icon: '🔥',
  ),
  Achievement(
    id: 'streak_7',
    title: 'Week Warrior',
    description: 'Reach a 7-day streak.',
    icon: '⚡',
  ),
  Achievement(
    id: 'xp_100',
    title: 'Century',
    description: 'Earn 100 XP.',
    icon: '💯',
  ),
  Achievement(
    id: 'xp_500',
    title: 'Scholar',
    description: 'Earn 500 XP.',
    icon: '🎓',
  ),
  Achievement(
    id: 'xp_1000',
    title: 'Master',
    description: 'Earn 1000 XP.',
    icon: '👑',
  ),
  Achievement(
    id: 'polyglot',
    title: 'Polyglot',
    description: 'Practise three different languages.',
    icon: '🌍',
  ),
];
