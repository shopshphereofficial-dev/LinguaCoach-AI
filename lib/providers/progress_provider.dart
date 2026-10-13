import 'package:flutter/foundation.dart';

import '../models/curriculum.dart';
import '../models/language.dart';
import '../models/progress.dart';
import '../services/storage_service.dart';

/// Owns the learner's XP, streak, per-language progress, lesson stars and
/// achievements.
class ProgressProvider extends ChangeNotifier {
  final StorageService _storage;

  ProgressProvider(this._storage);

  UserProgress _progress = UserProgress.empty();
  UserProgress get progress => _progress;

  int get totalXp => _progress.xp;
  int get streak => _progress.streak;
  int get level => _progress.level;
  double get levelProgress => _progress.levelProgress;
  List<String> get unlockedAchievements => _progress.achievements;

  int xpFor(String languageCode) => _progress.languageXp[languageCode] ?? 0;

  SkillLevel levelFor(String languageCode) =>
      SkillLevel.fromName(_progress.languageLevel[languageCode]);

  bool isUnlocked(String achievementId) =>
      _progress.achievements.contains(achievementId);

  int get languagesPractised =>
      _progress.languageXp.entries.where((e) => e.value > 0).length;

  // ----------------------------------------------------------- learning path

  String _starKey(String languageCode, String lessonId) =>
      '$languageCode|$lessonId';

  /// Stars earned on a lesson (0-3).
  int starsFor(String languageCode, String lessonId) =>
      _progress.lessonStars[_starKey(languageCode, lessonId)] ?? 0;

  bool isLessonDone(String languageCode, String lessonId) =>
      starsFor(languageCode, lessonId) > 0;

  /// How many lessons of a language have been completed.
  int lessonsDone(String languageCode) => kLessonPath
      .where((slot) => isLessonDone(languageCode, slot.lesson.id))
      .length;

  /// Lessons are unlocked one after another along the path.
  bool isLessonUnlocked(String languageCode, int flatIndex) {
    if (flatIndex <= 0) return true;
    final previous = kLessonPath[flatIndex - 1];
    return isLessonDone(languageCode, previous.lesson.id);
  }

  /// The next lesson the learner should do, or null when the path is finished.
  LessonSlot? currentSlot(String languageCode) {
    for (final slot in kLessonPath) {
      if (!isLessonDone(languageCode, slot.lesson.id)) return slot;
    }
    return null;
  }

  double pathProgress(String languageCode) =>
      lessonsDone(languageCode) / kLessonPath.length;

  Future<void> completeLesson({
    required String languageCode,
    required String lessonId,
    required int stars,
    required int xp,
  }) async {
    final key = _starKey(languageCode, lessonId);
    final best = _progress.lessonStars[key] ?? 0;
    if (stars > best) _progress.lessonStars[key] = stars;
    await addXp(languageCode, xp);
  }

  // -------------------------------------------------------------- daily goal

  int get todayXp => _progress.todayDay == _dayKey(DateTime.now())
      ? _progress.todayXp
      : 0;

  /// Total XP earned across every lesson (used for the "course" stat).
  int get lessonsCompletedTotal {
    var total = 0;
    for (final code in _progress.languageXp.keys) {
      total += lessonsDone(code);
    }
    return total;
  }

  Future<void> load() async {
    final data = await _storage.readProgress();
    if (data != null) {
      _progress = UserProgress.fromJson(data);
    }
    _resetStreakIfBroken();
    notifyListeners();
  }

  void _resetStreakIfBroken() {
    final last = _progress.lastPracticeDay;
    if (last == null) return;
    final parsed = DateTime.tryParse(last);
    if (parsed == null) return;
    final gap = DateTime.now().difference(parsed).inDays;
    if (gap > 1) {
      _progress.streak = 0;
    }
  }

  Future<void> setLevel(String languageCode, SkillLevel level) async {
    _progress.languageLevel[languageCode] = level.name;
    await _save();
    notifyListeners();
  }

  Future<void> addXp(String languageCode, int amount) async {
    if (amount <= 0) return;
    final today = _dayKey(DateTime.now());
    if (_progress.todayDay != today) {
      _progress.todayDay = today;
      _progress.todayXp = 0;
    }
    _progress.xp += amount;
    _progress.todayXp += amount;
    _progress.languageXp[languageCode] =
        (_progress.languageXp[languageCode] ?? 0) + amount;
    _checkAchievements();
    await _save();
    notifyListeners();
  }

  /// Call once per practice session to advance the daily streak.
  Future<void> registerPractice(String languageCode) async {
    final today = _dayKey(DateTime.now());
    if (_progress.lastPracticeDay != today) {
      final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
      if (_progress.lastPracticeDay == yesterday) {
        _progress.streak += 1;
      } else {
        _progress.streak = 1;
      }
      _progress.lastPracticeDay = today;
    }
    _progress.languageLevel
        .putIfAbsent(languageCode, () => SkillLevel.beginner.name);
    _checkAchievements();
    await _save();
    notifyListeners();
  }

  void _checkAchievements() {
    void unlock(String id) {
      if (!_progress.achievements.contains(id)) {
        _progress.achievements.add(id);
      }
    }

    if (_progress.xp > 0) unlock('first_step');
    if (_progress.streak >= 3) unlock('streak_3');
    if (_progress.streak >= 7) unlock('streak_7');
    if (_progress.xp >= 100) unlock('xp_100');
    if (_progress.xp >= 500) unlock('xp_500');
    if (_progress.xp >= 1000) unlock('xp_1000');
    if (languagesPractised >= 3) unlock('polyglot');
    if (_progress.lessonStars.length >= 5) unlock('pathfinder');
    if (_progress.lessonStars.length >= 20) unlock('course_clear');
  }

  /// Clears the saved lessons for one language (keeps XP and streak).
  Future<void> resetLanguage(String languageCode) async {
    _progress.lessonStars
        .removeWhere((key, _) => key.startsWith('$languageCode|'));
    _progress.languageXp.remove(languageCode);
    await _save();
    notifyListeners();
  }

  Future<void> reset() async {
    _progress = UserProgress.empty();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async => _storage.writeProgress(_progress.toJson());

  String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
