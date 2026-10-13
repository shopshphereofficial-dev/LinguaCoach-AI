import 'package:flutter/material.dart';

import '../services/storage_service.dart';

/// Holds user preferences: the Gemini API key, model, native language and
/// theme. Persisted through [StorageService].
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;

  SettingsProvider(this._storage);

  /// Models offered in Settings. The first is the default.
  static const List<String> availableModels = <String>[
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
  ];

  static const String defaultModel = 'gemini-2.5-flash';
  static const String defaultNativeLanguage = 'hi';

  String? _apiKey;
  String _model = defaultModel;
  String _nativeLanguage = defaultNativeLanguage;
  ThemeMode _themeMode = ThemeMode.system;

  String get apiKey => _apiKey ?? '';
  bool get hasApiKey => (_apiKey ?? '').trim().isNotEmpty;
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

  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    await _storage.writeApiKey(_apiKey!);
    notifyListeners();
  }

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
