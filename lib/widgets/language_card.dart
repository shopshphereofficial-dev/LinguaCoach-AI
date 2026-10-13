import 'package:flutter/material.dart';

import '../models/language.dart';

/// A grid tile for one language.
class LanguageCard extends StatelessWidget {
  final Language language;
  final int xp;
  final VoidCallback onTap;

  const LanguageCard({
    super.key,
    required this.language,
    required this.xp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 30)),
              const Spacer(),
              Text(
                language.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                language.nativeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.bolt, size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    '$xp XP',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
