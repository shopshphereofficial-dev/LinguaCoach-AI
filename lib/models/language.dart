/// A language the learner can study, or use as the language of explanation.
class Language {
  /// BCP-47 code used for the Gemini prompt and the TTS/STT locale, e.g. 'es'.
  final String code;

  /// English name.
  final String name;

  /// The language's own name.
  final String nativeName;

  /// Emoji flag, used purely for decoration in the UI.
  final String flag;

  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}

/// Difficulty level, chosen per language by the learner.
enum SkillLevel {
  beginner,
  intermediate,
  advanced;

  String get label {
    switch (this) {
      case SkillLevel.beginner:
        return 'Beginner';
      case SkillLevel.intermediate:
        return 'Intermediate';
      case SkillLevel.advanced:
        return 'Advanced';
    }
  }

  /// A short description shown under the level selector.
  String get blurb {
    switch (this) {
      case SkillLevel.beginner:
        return 'Simple words and short sentences';
      case SkillLevel.intermediate:
        return 'Everyday conversation and richer vocabulary';
      case SkillLevel.advanced:
        return 'Nuanced, natural and idiomatic language';
    }
  }

  static SkillLevel fromName(String? name) {
    switch (name) {
      case 'intermediate':
        return SkillLevel.intermediate;
      case 'advanced':
        return SkillLevel.advanced;
      default:
        return SkillLevel.beginner;
    }
  }
}

/// Every language that can be learned. All are well supported by Gemini.
const List<Language> kLearnableLanguages = [
  Language(code: 'en', name: 'English', nativeName: 'English', flag: '🇬🇧'),
  Language(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳'),
  Language(code: 'es', name: 'Spanish', nativeName: 'Español', flag: '🇪🇸'),
  Language(code: 'fr', name: 'French', nativeName: 'Français', flag: '🇫🇷'),
  Language(code: 'de', name: 'German', nativeName: 'Deutsch', flag: '🇩🇪'),
  Language(code: 'ja', name: 'Japanese', nativeName: '日本語', flag: '🇯🇵'),
  Language(code: 'ko', name: 'Korean', nativeName: '한국어', flag: '🇰🇷'),
  Language(code: 'ar', name: 'Arabic', nativeName: 'العربية', flag: '🇸🇦'),
  Language(code: 'zh', name: 'Chinese', nativeName: '中文', flag: '🇨🇳'),
  Language(code: 'pt', name: 'Portuguese', nativeName: 'Português', flag: '🇵🇹'),
  Language(code: 'ru', name: 'Russian', nativeName: 'Русский', flag: '🇷🇺'),
  Language(code: 'it', name: 'Italian', nativeName: 'Italiano', flag: '🇮🇹'),
  Language(code: 'bn', name: 'Bengali', nativeName: 'বাংলা', flag: '🇧🇩'),
  Language(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', flag: '🇮🇳'),
  Language(code: 'te', name: 'Telugu', nativeName: 'తెలుగు', flag: '🇮🇳'),
  Language(code: 'mr', name: 'Marathi', nativeName: 'मराठी', flag: '🇮🇳'),
  Language(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', flag: '🇮🇳'),
  Language(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', flag: '🇮🇳'),
  Language(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം', flag: '🇮🇳'),
  Language(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', flag: '🇮🇳'),
  Language(code: 'ur', name: 'Urdu', nativeName: 'اردو', flag: '🇵🇰'),
  Language(code: 'ne', name: 'Nepali', nativeName: 'नेपाली', flag: '🇳🇵'),
  Language(code: 'tr', name: 'Turkish', nativeName: 'Türkçe', flag: '🇹🇷'),
  Language(code: 'nl', name: 'Dutch', nativeName: 'Nederlands', flag: '🇳🇱'),
  Language(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt', flag: '🇻🇳'),
  Language(code: 'th', name: 'Thai', nativeName: 'ไทย', flag: '🇹🇭'),
  Language(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia', flag: '🇮🇩'),
  Language(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu', flag: '🇲🇾'),
  Language(code: 'tl', name: 'Filipino', nativeName: 'Filipino', flag: '🇵🇭'),
  Language(code: 'pl', name: 'Polish', nativeName: 'Polski', flag: '🇵🇱'),
  Language(code: 'ro', name: 'Romanian', nativeName: 'Română', flag: '🇷🇴'),
  Language(code: 'cs', name: 'Czech', nativeName: 'Čeština', flag: '🇨🇿'),
  Language(code: 'el', name: 'Greek', nativeName: 'Ελληνικά', flag: '🇬🇷'),
  Language(code: 'he', name: 'Hebrew', nativeName: 'עברית', flag: '🇮🇱'),
  Language(code: 'fa', name: 'Persian', nativeName: 'فارسی', flag: '🇮🇷'),
  Language(code: 'uk', name: 'Ukrainian', nativeName: 'Українська', flag: '🇺🇦'),
  Language(code: 'sv', name: 'Swedish', nativeName: 'Svenska', flag: '🇸🇪'),
  Language(code: 'da', name: 'Danish', nativeName: 'Dansk', flag: '🇩🇰'),
  Language(code: 'fi', name: 'Finnish', nativeName: 'Suomi', flag: '🇫🇮'),
  Language(code: 'no', name: 'Norwegian', nativeName: 'Norsk', flag: '🇳🇴'),
  Language(code: 'hu', name: 'Hungarian', nativeName: 'Magyar', flag: '🇭🇺'),
  Language(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili', flag: '🇰🇪'),
  Language(code: 'si', name: 'Sinhala', nativeName: 'සිංහල', flag: '🇱🇰'),
  Language(code: 'my', name: 'Burmese', nativeName: 'မြန်မာ', flag: '🇲🇲'),
  Language(code: 'km', name: 'Khmer', nativeName: 'ខ្មែរ', flag: '🇰🇭'),
];

/// Languages that can be selected as the learner's native language (explanations
/// are written in this language). Kept shorter than the learnable list so the
/// picker stays usable, but easy to extend.
const List<Language> kNativeLanguages = [
  Language(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳'),
  Language(code: 'en', name: 'English', nativeName: 'English', flag: '🇬🇧'),
  Language(code: 'bn', name: 'Bengali', nativeName: 'বাংলা', flag: '🇧🇩'),
  Language(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', flag: '🇮🇳'),
  Language(code: 'te', name: 'Telugu', nativeName: 'తెలుగు', flag: '🇮🇳'),
  Language(code: 'mr', name: 'Marathi', nativeName: 'मराठी', flag: '🇮🇳'),
  Language(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', flag: '🇮🇳'),
  Language(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', flag: '🇮🇳'),
  Language(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം', flag: '🇮🇳'),
  Language(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', flag: '🇮🇳'),
  Language(code: 'ur', name: 'Urdu', nativeName: 'اردو', flag: '🇵🇰'),
  Language(code: 'ar', name: 'Arabic', nativeName: 'العربية', flag: '🇸🇦'),
  Language(code: 'es', name: 'Spanish', nativeName: 'Español', flag: '🇪🇸'),
  Language(code: 'fr', name: 'French', nativeName: 'Français', flag: '🇫🇷'),
  Language(code: 'ru', name: 'Russian', nativeName: 'Русский', flag: '🇷🇺'),
  Language(code: 'zh', name: 'Chinese', nativeName: '中文', flag: '🇨🇳'),
];

/// Convenience lookup that never throws.
Language languageByCode(String code) {
  for (final l in kLearnableLanguages) {
    if (l.code == code) return l;
  }
  for (final l in kNativeLanguages) {
    if (l.code == code) return l;
  }
  return Language(code: code, name: code, nativeName: code, flag: '🌐');
}
