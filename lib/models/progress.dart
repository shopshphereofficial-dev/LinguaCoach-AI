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

  UserProgress({
    this.xp = 0,
    this.streak = 0,
    this.lastPracticeDay,
    Map<String, int>? languageXp,
    Map<String, String>? languageLevel,
    List<String>? achievements,
  })  : languageXp = languageXp ?? <String, int>{},
        languageLevel = languageLevel ?? <String, String>{},
        achievements = achievements ?? <String>[];

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
      };

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    final langXp = <String, int>{};
    final rawXp = json['languageXp'];
    if (rawXp is Map) {
      rawXp.forEach((key, value) {
        langXp[key.toString()] = int.tryParse(value.toString()) ?? 0;
      });
    }

    final langLevel = <String, String>{};
    final rawLevel = json['languageLevel'];
    if (rawLevel is Map) {
      rawLevel.forEach((key, value) {
        langLevel[key.toString()] = value.toString();
      });
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
      languageXp: langXp,
      languageLevel: langLevel,
      achievements: achievements,
    );
  }
}
