/// A role-play scenario the learner can practise.
class RolePlayScenario {
  final String id;
  final String title;
  final String emoji;
  final String description;

  /// The role the AI will play, e.g. "a friendly restaurant waiter".
  final String aiRole;

  const RolePlayScenario({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.aiRole,
  });
}

/// Built-in scenarios. They are language-agnostic: the AI adapts them to the
/// target language and level.
const List<RolePlayScenario> kRolePlayScenarios = [
  RolePlayScenario(
    id: 'restaurant',
    title: 'At the Restaurant',
    emoji: '🍽️',
    description: 'Order food, ask about the menu and pay the bill.',
    aiRole: 'a friendly restaurant waiter',
  ),
  RolePlayScenario(
    id: 'airport',
    title: 'At the Airport',
    emoji: '✈️',
    description: 'Check in, go through security and find your gate.',
    aiRole: 'an airport check-in agent',
  ),
  RolePlayScenario(
    id: 'interview',
    title: 'Job Interview',
    emoji: '💼',
    description: 'Answer questions about yourself and your experience.',
    aiRole: 'a hiring manager conducting a job interview',
  ),
  RolePlayScenario(
    id: 'shopping',
    title: 'Shopping',
    emoji: '🛍️',
    description: 'Ask for sizes, prices and try things on.',
    aiRole: 'a helpful shop assistant',
  ),
  RolePlayScenario(
    id: 'doctor',
    title: 'At the Doctor',
    emoji: '🩺',
    description: 'Describe how you feel and understand the advice.',
    aiRole: 'a kind family doctor',
  ),
  RolePlayScenario(
    id: 'directions',
    title: 'Asking for Directions',
    emoji: '🗺️',
    description: 'Find your way around an unfamiliar city.',
    aiRole: 'a friendly local passer-by',
  ),
  RolePlayScenario(
    id: 'hotel',
    title: 'Hotel Check-in',
    emoji: '🏨',
    description: 'Book a room, ask about facilities and check out.',
    aiRole: 'a hotel receptionist',
  ),
  RolePlayScenario(
    id: 'smalltalk',
    title: 'Meeting a New Friend',
    emoji: '🤝',
    description: 'Introduce yourself and make small talk.',
    aiRole: 'a new neighbour you just met',
  ),
];
