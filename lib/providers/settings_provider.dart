import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/storage_service.dart';

/// Holds user preferences: the Gemini API key, models, teacher, native
/// language and theme. Persisted through [StorageService].
///
/// The API key comes from one of two places, in order of priority:
///
///  1. A key the user pasted themselves (kept in secure storage).
///  2. The key baked into the build at compile time
///     (`--dart-define=GEMINI_API_KEY=...`).
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;

  SettingsProvider(this._storage);

  /// Text models verified against the live Gemini API. The `-latest` aliases
  /// track the newest version automatically.
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

  /// Models that support the **Live API** (real-time voice). Verified against
  /// the live API with this key.
  static const List<String> liveModels = <String>[
    'gemini-3.8-live',
    'gemini-3.1-flash-live-preview',
    'gemini-2.5-flash-native-audio-latest',
  ];

  static const String defaultModel = AppConfig.defaultModel;
  static const String defaultLiveModel = 'gemini-3.8-live';
  static const String defaultNativeLanguage = 'hi';
  static const String defaultTeacherId = 'aanya';

  String? _apiKey;
  String _model = defaultModel;
  String _liveModel = defaultLiveModel;
  String _nativeLanguage = defaultNativeLanguage;
  String _teacherId = defaultTeacherId;
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
  String get liveModel => _liveModel;
  String get nativeLanguage => _nativeLanguage;
  String get teacherId => _teacherId;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    _apiKey = await _storage.readApiKey();
    _model = await _storage.readSetting('model') ?? defaultModel;
    _liveModel = await _storage.readSetting('liveModel') ?? defaultLiveModel;
    _nativeLanguage =
        await _storage.readSetting('nativeLanguage') ?? defaultNativeLanguage;
    _teacherId = await _storage.readSetting('teacherId') ?? defaultTeacherId;
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

  Future<void> setLiveModel(String model) async {
    _liveModel = model;
    await _storage.writeSetting('liveModel', model);
    notifyListeners();
  }

  Future<void> setNativeLanguage(String code) async {
    _nativeLanguage = code;
    await _storage.writeSetting('nativeLanguage', code);
    notifyListeners();
  }

  Future<void> setTeacherId(String id) async {
    _teacherId = id;
    await _storage.writeSetting('teacherId', id);
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
