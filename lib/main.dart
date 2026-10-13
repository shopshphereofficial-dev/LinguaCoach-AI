import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/progress_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/api_key_screen.dart';
import 'screens/home_shell.dart';
import 'services/curriculum_service.dart';
import 'services/gemini_service.dart';
import 'services/speech_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final settings = SettingsProvider(storage);
  await settings.load();
  final progress = ProgressProvider(storage);
  await progress.load();
  final speech = SpeechService()..enabled = settings.soundEnabled;

  runApp(
    LinguaCoachApp(
      storage: storage,
      settings: settings,
      progress: progress,
      speech: speech,
    ),
  );
}

class LinguaCoachApp extends StatelessWidget {
  final StorageService storage;
  final SettingsProvider settings;
  final ProgressProvider progress;
  final SpeechService speech;

  const LinguaCoachApp({
    super.key,
    required this.storage,
    required this.settings,
    required this.progress,
    required this.speech,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<ProgressProvider>.value(value: progress),
        Provider<StorageService>.value(value: storage),
        Provider<SpeechService>.value(value: speech),
        Provider<GeminiService>(
          create: (ctx) => GeminiService(ctx.read<SettingsProvider>()),
        ),
        Provider<CurriculumService>(
          create: (ctx) => CurriculumService(
            ctx.read<GeminiService>(),
            ctx.read<StorageService>(),
          ),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'LinguaCoach AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: settings.hasApiKey ? const HomeShell() : const ApiKeyScreen(),
          );
        },
      ),
    );
  }
}
