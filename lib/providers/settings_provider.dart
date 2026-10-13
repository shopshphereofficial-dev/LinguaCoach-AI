import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/storage_service.dart';

/// Holds user preferences: the Gemini API key, model, native language and
/// theme. Persisted through [StorageService].
///
/// The API key comes from one of two places, in order of priority:
///
///  1. A key the user pasted themselves (kept in secure storage).
///  2. The key baked into the build at compile time
///     (`--dart-define=GEMINI_API_KEY=...`).
///
/// Because a key is normally built in, the app opens straight into the home
/// screen and never asks the user to paste one.
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;

  SettingsProvider(this._storage);

  /// Models verified against the live Gemini API. The `-latest` aliases track
  /// the newest version automatically, so they keep working over time.
  static const List<String> availableModels = <String>[
    'gemini-flash-latest',
    'gemini-pro-latest',
    'gemini-flash-lite-latest',
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
  ];

  static const String defaultModel = AppConfig.defaultModel;
  static const String defaultNativeLanguage = 'hi';

  String? _apiKey;
  String _model = defaultModel;
  String _nativeLanguage = defaultNativeLanguage;
  ThemeMode _themeMode = ThemeMode.system;

  /// The key actually used for requests: the user's own key if they set one,
  /// otherwise the key baked into the build.
  String get apiKey {
    final stored = (_apiKey ?? '').trim();
    if (stored.isNotEmpty) return stored;
    return AppConfig.builtInApiKey.trim();
  }

  bool get hasApiKey => apiKey.isNotEmpty;

  /// True when the user has not supplied their own key and the built-in key is
  /// the one being used.
  bool get usingBuiltInKey =>
      (_apiKey ?? '').trim().isEmpty &&
      AppConfig.builtInApiKey.trim().isNotEmpty;

  String get model => _model;
  String get nativeLanguage => _nativeLanguage;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    _apiKey = await _storage.readApiKey();
    _model = await _storage.readSetting('model') ?? defaultModel;
    _nativeLanguage =
        await _storage.readSetting('nativeLanguage') ?? defaultNativeLanguage;
    _themeMode = _themeFromString(await _storage.readSetting('themeMode'));
    notifyListeners();
  }

  /// Stores a personal key, which takes priority over the built-in one.
  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    await _storage.writeApiKey(_apiKey!);
    notifyListeners();
  }

  /// Removes the personal key; the built-in key (if any) takes over again.
  Future<void> clearApiKey() async {
    _apiKey = null;
    await _storage.deleteApiKey();
    notifyListeners();
  }

  Future<void> setModel(String model) async {
    _model = model;
    await _storage.writeSetting('model', model);
    notifyListeners();
  }

  Future<void> setNativeLanguage(String code) async {
    _nativeLanguage = code;
    await _storage.writeSetting('nativeLanguage', code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _storage.writeSetting('themeMode', mode.name);
    notifyListeners();
  }

  ThemeMode _themeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
