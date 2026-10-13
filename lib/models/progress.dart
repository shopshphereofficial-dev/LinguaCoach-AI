/// All locally saved progress. Serialised to JSON and stored in
/// SharedPreferences by [ProgressProvider].
class UserProgress {
  int xp;
  int streak;

  /// 'yyyy-MM-dd' of the last day the learner practised, used for streaks.
  String? lastPracticeDay;

  /// XP earned per language code.
  Map<String, int> languageXp;

  /// Selected difficulty per language code ('beginner' | 'intermediate' | 'advanced').
  Map<String, String> languageLevel;

  /// Unlocked achievement ids.
  List<String> achievements;

  /// Stars (0-3) earned per lesson, keyed 'langCode|lessonId'.
  Map<String, int> lessonStars;

  /// XP earned today, plus the day it belongs to.
  int todayXp;
  String? todayDay;

  UserProgress({
    this.xp = 0,
    this.streak = 0,
    this.lastPracticeDay,
    Map<String, int>? languageXp,
    Map<String, String>? languageLevel,
    List<String>? achievements,
    Map<String, int>? lessonStars,
    this.todayXp = 0,
    this.todayDay,
  })  : languageXp = languageXp ?? <String, int>{},
        languageLevel = languageLevel ?? <String, String>{},
        achievements = achievements ?? <String>[],
        lessonStars = lessonStars ?? <String, int>{};

  factory UserProgress.empty() => UserProgress();

  /// 100 XP per level, starting at level 1.
  int get level => 1 + (xp ~/ 100);

  /// Progress within the current level, 0.0 - 1.0.
  double get levelProgress => (xp % 100) / 100.0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'xp': xp,
        'streak': streak,
        'lastPracticeDay': lastPracticeDay,
        'languageXp': languageXp,
        'languageLevel': languageLevel,
        'achievements': achievements,
        'lessonStars': lessonStars,
        'todayXp': todayXp,
        'todayDay': todayDay,
      };

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    Map<String, int> intMap(dynamic raw) {
      final out = <String, int>{};
      if (raw is Map) {
        raw.forEach((k, v) => out[k.toString()] = int.tryParse('$v') ?? 0);
      }
      return out;
    }

    final langLevel = <String, String>{};
    final rawLevel = json['languageLevel'];
    if (rawLevel is Map) {
      rawLevel.forEach((k, v) => langLevel[k.toString()] = v.toString());
    }

    final achievements = <String>[];
    final rawAch = json['achievements'];
    if (rawAch is List) {
      for (final a in rawAch) {
        achievements.add(a.toString());
      }
    }

    return UserProgress(
      xp: int.tryParse('${json['xp']}') ?? 0,
      streak: int.tryParse('${json['streak']}') ?? 0,
      lastPracticeDay: json['lastPracticeDay']?.toString(),
      languageXp: intMap(json['languageXp']),
      languageLevel: langLevel,
      achievements: achievements,
      lessonStars: intMap(json['lessonStars']),
      todayXp: int.tryParse('${json['todayXp']}') ?? 0,
      todayDay: json['todayDay']?.toString(),
    );
  }
}
