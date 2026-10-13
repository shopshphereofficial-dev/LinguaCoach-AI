import 'dart:convert';

import '../models/curriculum.dart';
import '../models/language.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';

/// Loads the content for a lesson on the learning path.
///
/// The path *structure* is fixed (see [kCurriculum]); the content is generated
/// by Gemini once per language + lesson and then cached on the device, so
/// revisiting a lesson is instant and works offline.
class CurriculumService {
  final GeminiService gemini;
  final StorageService storage;

  CurriculumService(this.gemini, this.storage);

  String _cacheKey(Language language, LessonNode node) =>
      'lesson_${language.code}_${node.id}';

  Future<LessonContent> load({
    required Language language,
    required SkillLevel level,
    required LessonNode node,
    required String nativeLanguageName,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(language, node);

    if (!forceRefresh) {
      final cached = await storage.readSetting(key);
      if (cached != null && cached.isNotEmpty) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is Map) {
            return LessonContent.fromJson(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Corrupt cache entry: regenerate below.
        }
      }
    }

    final map = await gemini.lessonPack(
      targetLanguage: language.name,
      nativeLanguage: nativeLanguageName,
      level: level,
      topic: node.topic,
    );
    final content = LessonContent.fromJson(map);
    try {
      await storage.writeSetting(key, jsonEncode(content.toJson()));
    } catch (_) {
      // Caching is best-effort.
    }
    return content;
  }
}
