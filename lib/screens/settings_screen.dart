import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../models/teacher.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';

/// The Settings tab: API key, models, teacher, native language, theme, reset.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final teacher = teacherById(settings.teacherId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Gemini API key',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _mask(settings.apiKey),
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              Text(
                settings.usingBuiltInKey
                    ? 'The built-in key is in use. Paste your own key below to '
                        'override it.'
                    : 'Your own key is stored securely on this device.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _changeKey(context),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Change'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: settings.usingBuiltInKey
                          ? null
                          : () => _removeKey(context),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Your teacher',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: settings.teacherId,
                isExpanded: true,
                items: kTeachers
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text('${t.name}  ·  ${t.specialty}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) settings.setTeacherId(value);
                },
              ),
              const SizedBox(height: 6),
              Text(
                '${teacher.name} — ${teacher.tagline}. This teacher runs your '
                'live classes and role-plays, with the voice "${teacher.voiceName}".',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Learning',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily XP goal',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: SettingsProvider.dailyGoals.contains(settings.dailyGoal)
                    ? settings.dailyGoal
                    : SettingsProvider.defaultDailyGoal,
                isExpanded: true,
                items: SettingsProvider.dailyGoals
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text('$g XP per day'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) settings.setDailyGoal(value);
                },
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.soundEnabled,
                title: const Text('Sound'),
                subtitle: const Text(
                  'Speak vocabulary and example sentences out loud',
                ),
                onChanged: (value) {
                  settings.setSoundEnabled(value);
                  context.read<SpeechService>().enabled = value;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Live voice model',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: SettingsProvider.liveModels.contains(settings.liveModel)
                    ? settings.liveModel
                    : SettingsProvider.defaultLiveModel,
                isExpanded: true,
                items: SettingsProvider.liveModels
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) settings.setLiveModel(value);
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Used for the real-time voice classes (Gemini Live API).',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Text model',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value:
                    SettingsProvider.availableModels.contains(settings.model)
                        ? settings.model
                        : SettingsProvider.defaultModel,
                isExpanded: true,
                items: SettingsProvider.availableModels
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) settings.setModel(value);
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Used for lessons, quizzes and grammar. The "-latest" aliases '
                'always point at the newest model.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Native language (for explanations)',
          child: DropdownButtonFormField<String>(
            value: settings.nativeLanguage,
            isExpanded: true,
            items: kNativeLanguages
                .map(
                  (l) => DropdownMenuItem(
                    value: l.code,
                    child: Text('${l.flag}  ${l.name} (${l.nativeName})'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) settings.setNativeLanguage(value);
            },
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Appearance',
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {settings.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                settings.setThemeMode(selection.first),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Progress',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reset your XP, streak and achievements. This cannot be undone.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _resetProgress(context),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset progress'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'About',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: AppLogo(size: 72, showShadow: true)),
              const SizedBox(height: 12),
              Text(
                'LinguaCoach AI v1.3.0\n'
                'A Duolingo-style language-learning app powered by the Google '
                'Gemini API — including real-time voice classes with animated '
                'AI teachers. All calls go directly from your device to Gemini; '
                'there is no backend.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _mask(String key) {
    if (key.isEmpty) return 'No key set';
    if (key.length <= 10) return '••••';
    return '${key.substring(0, 6)}••••••${key.substring(key.length - 4)}';
  }

  Future<void> _changeKey(BuildContext context) async {
    final controller = TextEditingController();
    final settings = context.read<SettingsProvider>();
    final gemini = context.read<GeminiService>();
    bool busy = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Use your own API key'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    obscureText: true,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Paste a Gemini API key',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final key = controller.text.trim();
                          if (key.isEmpty) {
                            setDialogState(() => error = 'Please paste a key.');
                            return;
                          }
                          setDialogState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await gemini.validateKey(
                              apiKey: key,
                              model: settings.model,
                            );
                            await settings.setApiKey(key);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } on GeminiException catch (e) {
                            setDialogState(() {
                              error = e.message;
                              busy = false;
                            });
                          } catch (e) {
                            setDialogState(() {
                              error = '$e';
                              busy = false;
                            });
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeKey(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove your key?'),
        content: const Text(
          'Your key will be deleted from this device and the built-in key will '
          'be used again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await settings.clearApiKey();
    }
  }

  Future<void> _resetProgress(BuildContext context) async {
    final progress = context.read<ProgressProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This clears your XP, streak and achievements. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await progress.reset();
    }
  }
}
