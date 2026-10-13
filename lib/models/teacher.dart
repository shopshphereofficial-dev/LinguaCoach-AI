import 'package:flutter/material.dart';

/// Hair styles the avatar can draw.
enum HairStyle { long, bob, short, bun, curly }

/// One of the app's AI teachers.
///
/// Each teacher has a name, a personality that shapes how Gemini talks, a
/// Gemini prebuilt voice, and a colour palette used to draw their animated
/// avatar.
class Teacher {
  final String id;
  final String name;
  final String tagline;
  final String specialty;
  final String voiceName;

  final Color skin;
  final Color hair;
  final Color outfit;
  final Color accent;
  final HairStyle hairStyle;

  /// Woven into the Live API system instruction so the teacher behaves
  /// consistently.
  final String personality;

  const Teacher({
    required this.id,
    required this.name,
    required this.tagline,
    required this.specialty,
    required this.voiceName,
    required this.skin,
    required this.hair,
    required this.outfit,
    required this.accent,
    required this.hairStyle,
    required this.personality,
  });
}

/// The teaching staff. Add more entries here and they appear everywhere.
const List<Teacher> kTeachers = <Teacher>[
  Teacher(
    id: 'aanya',
    name: 'Aanya',
    tagline: 'Warm & encouraging',
    specialty: 'Hindi · English',
    voiceName: 'Aoede',
    skin: Color(0xFFE8B48C),
    hair: Color(0xFF2B1B12),
    outfit: Color(0xFF58CC02),
    accent: Color(0xFF58CC02),
    hairStyle: HairStyle.long,
    personality:
        'warm, patient and encouraging. You celebrate small wins and always '
        'give a simple example after correcting a mistake.',
  ),
  Teacher(
    id: 'marco',
    name: 'Marco',
    tagline: 'Energetic & fun',
    specialty: 'Spanish · Italian',
    voiceName: 'Puck',
    skin: Color(0xFFE3A87A),
    hair: Color(0xFF3B2314),
    outfit: Color(0xFFFF9600),
    accent: Color(0xFFFF9600),
    hairStyle: HairStyle.short,
    personality:
        'energetic, playful and quick with praise. You keep the conversation '
        'lively and use everyday examples.',
  ),
  Teacher(
    id: 'yuki',
    name: 'Yuki',
    tagline: 'Calm & precise',
    specialty: 'Japanese · Korean',
    voiceName: 'Kore',
    skin: Color(0xFFF2CFAE),
    hair: Color(0xFF14110F),
    outfit: Color(0xFF1CB0F6),
    accent: Color(0xFF1CB0F6),
    hairStyle: HairStyle.bob,
    personality:
        'calm, precise and gently encouraging. You explain the "why" behind '
        'each correction in a clear, unhurried way.',
  ),
  Teacher(
    id: 'layla',
    name: 'Layla',
    tagline: 'Friendly & expressive',
    specialty: 'Arabic · French',
    voiceName: 'Leda',
    skin: Color(0xFFD9A26F),
    hair: Color(0xFF1E1410),
    outfit: Color(0xFFCE82FF),
    accent: Color(0xFFCE82FF),
    hairStyle: HairStyle.curly,
    personality:
        'friendly, expressive and very supportive. You repeat key phrases '
        'slowly when the learner struggles.',
  ),
  Teacher(
    id: 'sofia',
    name: 'Sofia',
    tagline: 'Cheerful & clear',
    specialty: 'Portuguese · German',
    voiceName: 'Zephyr',
    skin: Color(0xFFF0C49B),
    hair: Color(0xFF7A4A21),
    outfit: Color(0xFFFF4B4B),
    accent: Color(0xFFFF4B4B),
    hairStyle: HairStyle.bun,
    personality:
        'cheerful, clear and always positive. You speak at a steady pace and '
        'break long sentences into shorter ones.',
  ),
];

/// Looks a teacher up by id, falling back to the first teacher.
Teacher teacherById(String id) {
  for (final t in kTeachers) {
    if (t.id == id) return t;
  }
  return kTeachers.first;
}
