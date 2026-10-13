import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central storage helper.
///
/// The Gemini API key is the only sensitive value, so it lives in
/// [FlutterSecureStorage] (Android Keystore backed). Everything else
/// (settings and progress) is plain JSON in SharedPreferences.
///
/// `encryptedSharedPreferences` is left off so the app works on API 21+;
/// storage is still backed by the Android Keystore.
class StorageService {
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );

  static const String _kApiKey = 'gemini_api_key';
  static const String _kProgress = 'user_progress';

  // ---------------------------------------------------------------- API key

  Future<String?> readApiKey() async {
    try {
      return await _secure.read(key: _kApiKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeApiKey(String value) async {
    await _secure.write(key: _kApiKey, value: value);
  }

  Future<void> deleteApiKey() async {
    try {
      await _secure.delete(key: _kApiKey);
    } catch (_) {
      // Ignore: nothing to delete.
    }
  }

  // ---------------------------------------------------------------- Settings

  Future<String?> readSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('setting_$key');
  }

  Future<void> writeSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('setting_$key', value);
  }

  // ---------------------------------------------------------------- Progress

  Future<Map<String, dynamic>?> readProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProgress);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Corrupt data: start fresh rather than crash.
    }
    return null;
  }

  Future<void> writeProgress(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProgress, jsonEncode(data));
  }
}
