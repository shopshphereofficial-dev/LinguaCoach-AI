import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../models/teacher.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/language_card.dart';
import '../widgets/teacher_avatar.dart';
import 'language_detail_screen.dart';
import 'live_class_screen.dart';

/// The Home tab: a live-class hero, the teaching staff, and a language grid.
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
    final teacher = teacherById(settings.teacherId);
    final query = _query.trim().toLowerCase();
    final languages = kLearnableLanguages.where((l) {
      if (query.isEmpty) return true;
      return l.name.toLowerCase().contains(query) ||
          l.nativeName.toLowerCase().contains(query) ||
          l.code.toLowerCase().contains(query);
    }).toList();

    return CustomScrollView(
      slivers: [
        // ------------------------------------------------- live class hero
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: teacher.accent.withOpacity(0.14),
              child: InkWell(
                onTap: () => _startLive(context),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      TeacherAvatar(
                        teacher: teacher,
                        animate: false,
                        size: 62,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Talk live with ${teacher.name}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Real-time voice — just speak, ${teacher.name} '
                              'answers instantly.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: teacher.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.graphic_eq,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // --------------------------------------------------- your teachers
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 0, 4),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    'Your teachers',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 16),
                    itemCount: kTeachers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final t = kTeachers[index];
                      final selected = t.id == teacher.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => settings.setTeacherId(t.id),
                        child: Container(
                          width: 132,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: t.accent
                                .withOpacity(selected ? 0.18 : 0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? t.accent : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              TeacherAvatar(
                                teacher: t,
                                animate: false,
                                size: 62,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                t.specialty,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 10.5,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ------------------------------------------------------- language
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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

  /// Asks which language to practise, then opens the live class.
  Future<void> _startLive(BuildContext context) async {
    final progress = context.read<ProgressProvider>();
    final settings = context.read<SettingsProvider>();
    final teacher = teacherById(settings.teacherId);
    final recent = progress.progress.languageXp.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final ordered = <Language>[
      for (final e in recent) languageByCode(e.key),
      ...kLearnableLanguages.where(
        (l) => !recent.any((e) => e.key == l.code),
      ),
    ];

    final language = await showModalBottomSheet<Language>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  TeacherAvatar(teacher: teacher, animate: false, size: 46),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'What should ${teacher.name} teach you?',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: ordered.length,
                itemBuilder: (context, index) {
                  final l = ordered[index];
                  final xp = progress.xpFor(l.code);
                  return ListTile(
                    leading: Text(l.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(l.name),
                    subtitle: Text(l.nativeName),
                    trailing: xp > 0
                        ? Text('$xp XP',
                            style: Theme.of(context).textTheme.labelMedium)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, l),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (language == null || !context.mounted) return;
    final level = progress.levelFor(language.code);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveClassScreen(language: language, level: level),
      ),
    );
  }
}
