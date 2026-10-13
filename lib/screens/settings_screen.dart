import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../widgets/common.dart';

/// The Settings tab: API key, model, native language, theme and reset.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

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
                      // Nothing to remove while the built-in key is in use.
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
          title: 'Model',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: SettingsProvider.availableModels
                        .contains(settings.model)
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
                'The "-latest" aliases always point at the newest model, so they '
                'keep working even as older model names are retired.',
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
          child: Text(
            'LinguaCoach AI v1.0.1\n'
            'A Duolingo-style language-learning app powered by the Google '
            'Gemini API. All calls go directly from your device to Gemini — '
            'there is no backend and nothing is sent to the developer.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
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
                  onPressed:
                      busy ? null : () => Navigator.pop(dialogContext),
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
