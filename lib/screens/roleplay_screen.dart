import 'package:flutter/material.dart';

import '../models/language.dart';
import '../models/roleplay.dart';
import '../widgets/common.dart';
import 'roleplay_chat_screen.dart';

/// 7. Role-play — pick a real-life scenario and act it out with the AI.
class RolePlayScreen extends StatelessWidget {
  final Language language;
  final SkillLevel level;

  const RolePlayScreen({
    super.key,
    required this.language,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${language.flag} Role-play · ${level.label}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose a scenario',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'The AI plays a character and chats with you in ${language.name}.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ...kRolePlayScenarios.map(
            (scenario) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FeatureTile(
                icon: Icons.theater_comedy_outlined,
                title: '${scenario.emoji}  ${scenario.title}',
                subtitle: scenario.description,
                color: Colors.pink,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RolePlayChatScreen(
                        scenario: scenario,
                        language: language,
                        level: level,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
