import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/language_card.dart';
import 'language_detail_screen.dart';

/// The Home tab: a searchable grid of languages, each its own section.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = context.watch<ProgressProvider>();
    final settings = context.watch<SettingsProvider>();

    final native = languageByCode(settings.nativeLanguage);
    final query = _query.trim().toLowerCase();
    final languages = kLearnableLanguages.where((l) {
      if (query.isEmpty) return true;
      return l.name.toLowerCase().contains(query) ||
          l.nativeName.toLowerCase().contains(query) ||
          l.code.toLowerCase().contains(query);
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pick a language to learn',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Explanations are shown in ${native.name} '
                            '(${native.nativeName}). Change this in Settings.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(native.flag, style: const TextStyle(fontSize: 34)),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          sliver: SliverToBoxAdapter(
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search languages…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
        if (languages.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No languages match your search.')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final language = languages[index];
                  return LanguageCard(
                    language: language,
                    xp: progress.xpFor(language.code),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              LanguageDetailScreen(language: language),
                        ),
                      );
                    },
                  );
                },
                childCount: languages.length,
              ),
            ),
          ),
      ],
    );
  }
}
