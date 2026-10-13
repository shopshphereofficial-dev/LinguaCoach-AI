import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/language.dart';
import '../models/lesson.dart';
import '../models/quiz_question.dart';
import '../models/roleplay.dart';
import '../providers/settings_provider.dart';

/// A user-presentable error from the Gemini API.
class GeminiException implements Exception {
  final String message;
  final bool isAuthError;
  final bool isRateLimit;
  final bool isNetwork;

  GeminiException(
    this.message, {
    this.isAuthError = false,
    this.isRateLimit = false,
    this.isNetwork = false,
  });

  @override
  String toString() => message;
}

/// The reply to one tutor turn: the conversational reply plus feedback.
class TutorTurn {
  final String reply;
  final TutorFeedback feedback;

  TutorTurn({required this.reply, required this.feedback});
}

/// A single speaking prompt (target-language task + a native-language hint).
class SpeakingPrompt {
  final String prompt;
  final String hint;

  SpeakingPrompt({required this.prompt, required this.hint});
}

/// All communication with the Google Gemini API.
///
/// Calls are made directly from the device over REST; there is no backend.
/// The API key and model are read from [SettingsProvider] on every call, so
/// changing them in Settings takes effect immediately.
class GeminiService {
  final SettingsProvider settings;

  GeminiService(this.settings);

  static final http.Client _client = http.Client();
  static const String _root =
      'https://generativelanguage.googleapis.com/v1beta/models';

  String get _key => settings.apiKey.trim();
  String get _model => settings.model.trim();

  // --------------------------------------------------------------- Plumbing

  Uri _uri(String model, String apiKey) =>
      Uri.parse('$_root/$model:generateContent?key=$apiKey');

  /// Low-level call. Throws [GeminiException] with a friendly message.
  Future<String> _generate({
    required List<Map<String, dynamic>> contents,
    String? systemInstruction,
    bool json = false,
    double temperature = 1.0,
    String? apiKey,
    String? model,
  }) async {
    final key = (apiKey ?? _key).trim();
    final useModel = (model ?? _model).trim();

    if (key.isEmpty) {
      throw GeminiException(
        'No API key set. Add your Gemini API key in Settings.',
        isAuthError: true,
      );
    }

    final body = <String, dynamic>{
      if (systemInstruction != null && systemInstruction.trim().isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
      'contents': contents,
      'generationConfig': <String, dynamic>{
        'temperature': temperature,
        if (json) 'responseMimeType': 'application/json',
      },
    };

    http.Response response;
    try {
      response = await _client
          .post(
            _uri(useModel, key),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw GeminiException(
        'The request timed out. Check your internet connection and try again.',
        isNetwork: true,
      );
    } catch (_) {
      throw GeminiException(
        'Could not reach Gemini. Check your internet connection and try again.',
        isNetwork: true,
      );
    }

    if (response.statusCode != 200) {
      _throwForStatus(response, useModel);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw GeminiException('Gemini returned an unexpected response.');
    }
    final text = _extractText(Map<String, dynamic>.from(decoded));
    if (text == null || text.trim().isEmpty) {
      throw GeminiException('Gemini returned an empty response. Please try again.');
    }
    return text;
  }

  /// Validates an API key (and optional model) with a tiny test call.
  Future<void> validateKey({String? apiKey, String? model}) async {
    await _generate(
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': 'Reply with the single word OK.'}
          ]
        }
      ],
      temperature: 0,
      apiKey: apiKey,
      model: model,
    );
  }

  Never _throwForStatus(http.Response response, String model) {
    int code = response.statusCode;
    String detail = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        final err = decoded['error'] as Map;
        if (err['message'] is String) detail = err['message'] as String;
      }
    } catch (_) {
      // Non-JSON error body.
    }
    final lower = detail.toLowerCase();

    if (code == 400 && (lower.contains('api key') || lower.contains('api_key'))) {
      throw GeminiException(
        'That API key was rejected. Please check it and try again.',
        isAuthError: true,
      );
    }
    if (code == 400) {
      throw GeminiException(
        detail.isEmpty ? 'Bad request sent to Gemini.' : detail,
        isAuthError: true,
      );
    }
    if (code == 403) {
      throw GeminiException(
        'Access denied. Your API key may not have permission for this model.',
        isAuthError: true,
      );
    }
    if (code == 404) {
      throw GeminiException(
        'The model "$model" was not found. Choose a different model in Settings.',
      );
    }
    if (code == 429) {
      throw GeminiException(
        'Rate limit reached. Please wait a moment and try again.',
        isRateLimit: true,
      );
    }
    if (code >= 500) {
      throw GeminiException(
        'Gemini is temporarily unavailable. Please try again shortly.',
      );
    }
    throw GeminiException(
      detail.isEmpty ? 'Request failed (HTTP $code).' : detail,
    );
  }

  String? _extractText(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;
      if (first is Map) {
        final content = first['content'];
        if (content is Map && content['parts'] is List) {
          final buffer = StringBuffer();
          for (final part in content['parts'] as List) {
            if (part is Map && part['text'] is String) {
              buffer.write(part['text'] as String);
            }
          }
          final out = buffer.toString();
          if (out.trim().isNotEmpty) return out;
        }
      }
    }
    final feedback = data['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw GeminiException(
        'That request was blocked by safety filters (${feedback['blockReason']}). '
        'Try rephrasing it.',
      );
    }
    return null;
  }

  /// Calls Gemini in JSON mode and retries if the model returns malformed JSON.
  Future<Map<String, dynamic>> _generateJsonMap({
    required List<Map<String, dynamic>> contents,
    String? systemInstruction,
    double temperature = 1.0,
    int attempts = 3,
  }) async {
    for (var i = 0; i < attempts; i++) {
      final raw = await _generate(
        contents: contents,
        systemInstruction: systemInstruction,
        json: true,
        temperature: temperature,
      );
      final parsed = _tryParseJson(raw);
      if (parsed is Map) {
        return Map<String, dynamic>.from(parsed);
      }
      if (parsed is List && parsed.isNotEmpty && parsed.first is Map) {
        return <String, dynamic>{'items': parsed};
      }
    }
    throw GeminiException(
      'Gemini returned data in an unexpected format. Please try again.',
    );
  }

  /// Best-effort JSON extraction: strips markdown fences and leading prose.
  dynamic _tryParseJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      final end = text.lastIndexOf('```');
      if (end != -1) text = text.substring(0, end);
      text = text.trim();
    }
    try {
      return jsonDecode(text);
    } catch (_) {
      // Fall through to brace extraction.
    }
    final objStart = text.indexOf('{');
    final arrStart = text.indexOf('[');
    int start = -1;
    if (objStart == -1) {
      start = arrStart;
    } else if (arrStart == -1) {
      start = objStart;
    } else {
      start = objStart < arrStart ? objStart : arrStart;
    }
    if (start == -1) return null;
    final isObject = text[start] == '{';
    final end = isObject ? text.lastIndexOf('}') : text.lastIndexOf(']');
    if (end <= start) return null;
    try {
      return jsonDecode(text.substring(start, end + 1));
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------------- 1. Conversation Coach

  Future<TutorTurn> tutorTurn({
    required String targetLanguage,
    required String nativeLanguage,
    required SkillLevel level,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    final system = '''You are "Lingo", a warm, patient and encouraging language tutor.
The learner is studying $targetLanguage at a ${level.label} level.
Their native language is $nativeLanguage, so write every explanation in $nativeLanguage.
Rules:
- Always reply in $targetLanguage, pitched at a ${level.label} level.
- Keep the conversational reply to 1-3 short sentences and end with a question.
- Never use markdown, bullet points or emoji inside the reply.
Respond with ONLY a JSON object (no code fences) using exactly these keys:
{"reply": string, "correction": string, "explanation": string, "better": string}
- "reply": your conversational reply in $targetLanguage.
- "correction": a corrected version of the learner's last message, in $targetLanguage. Use "" if it was already correct.
- "explanation": a short, kind explanation of any mistakes, in $nativeLanguage. Use "" if there were none.
- "better": a more natural or idiomatic way to express the learner's message, in $targetLanguage. Use "" if the original was already natural.''';

    final contents = <Map<String, dynamic>>[];
    for (final message in history) {
      contents.add({
        'role': message.isUser ? 'user' : 'model',
        'parts': [
          {'text': message.text}
        ]
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ]
    });

    final map = await _generateJsonMap(
      contents: contents,
      systemInstruction: system,
      temperature: 0.9,
    );

    final reply = (map['reply'] ?? '').toString().trim();
    return TutorTurn(
      reply: reply.isEmpty ? 'Let us keep going — what would you like to talk about?' : reply,
      feedback: TutorFeedback.fromJson(map),
    );
  }

  // --------------------------------------------------------- 5. Grammar check

  Future<Map<String, dynamic>> correctText({
    required String text,
    required String targetLanguage,
    required String nativeLanguage,
  }) async {
    final system = '''You are a meticulous but kind $targetLanguage language teacher.
The learner's native language is $nativeLanguage; write all explanations in $nativeLanguage.
Analyse the learner's text and return ONLY a JSON object (no code fences):
{"corrections":[{"original":string,"corrected":string,"explanation":string}],"correctedText":string,"overall":string}
- "corrections": one entry per distinct mistake. Use an empty array if the text is already correct.
- "correctedText": the whole text rewritten correctly, in $targetLanguage.
- "overall": a short, encouraging summary in $nativeLanguage.
No markdown.''';

    return _generateJsonMap(
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': text}
          ]
        }
      ],
      systemInstruction: system,
      temperature: 0.4,
    );
  }

  // ------------------------------------------------------------- 4. Exercises

  Future<List<QuizQuestion>> generateQuiz({
    required String targetLanguage,
    required String nativeLanguage,
    required SkillLevel level,
    required String topic,
    int count = 5,
  }) async {
    final system = '''You are an expert $targetLanguage teacher who writes exercises.
The learner is at a ${level.label} level and their native language is $nativeLanguage.
Create exactly $count exercises about "$topic".
Mix these types: "multipleChoice", "fillInBlank", "translation", "listening".
For "listening", "prompt" is a sentence in $targetLanguage to be read aloud and "options" are four possible translations in $nativeLanguage.
Return ONLY a JSON object (no code fences):
{"questions":[{"type":string,"prompt":string,"options":[string],"answer":string,"explanation":string}]}
Rules: "multipleChoice" and "listening" must have exactly 4 options; "fillInBlank" and "translation" must have an empty options array. When options exist, "answer" must match one of them exactly. Explanations are in $nativeLanguage. No markdown.''';

    final map = await _generateJsonMap(
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': 'Generate the exercises now.'}
          ]
        }
      ],
      systemInstruction: system,
      temperature: 0.9,
    );

    final questions = <QuizQuestion>[];
    final raw = map['questions'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          questions.add(QuizQuestion.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    if (questions.isEmpty) {
      throw GeminiException('Gemini did not return any exercises. Please try again.');
    }
    return questions;
  }

  // ---------------------------------------------------------------- 3. Lessons

  Future<Lesson> generateLesson({
    required String targetLanguage,
    required String nativeLanguage,
    required SkillLevel level,
    required String topic,
  }) async {
    final system = '''You are an expert $targetLanguage teacher creating a mini-lesson.
The learner is at a ${level.label} level; their native language is $nativeLanguage.
Topic: "$topic".
Return ONLY a JSON object (no code fences):
{"title":string,"topic":string,"level":string,"vocabulary":[{"term":string,"translation":string,"example":string}],"sentences":[{"target":string,"native":string}]}
Provide 8 vocabulary items and 5 example sentences.
"term" and "target" are in $targetLanguage; translations are in $nativeLanguage; "example" is a short sentence in $targetLanguage. No markdown.''';

    final map = await _generateJsonMap(
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': 'Create the lesson now.'}
          ]
        }
      ],
      systemInstruction: system,
      temperature: 0.8,
    );
    return Lesson.fromJson(map);
  }

  // ------------------------------------------------------- 2. Speaking coach

  Future<SpeakingPrompt> speakingPrompt({
    required String targetLanguage,
    required String nativeLanguage,
    required SkillLevel level,
  }) async {
    final system = '''You are a $targetLanguage speaking coach.
Give ONE short speaking task suitable for a ${level.label} learner.
Return ONLY a JSON object (no code fences):
{"prompt":string,"hint":string}
- "prompt": the task written in $targetLanguage (1-2 sentences).
- "hint": a short translation/explanation of the task in $nativeLanguage.
No markdown.''';

    final map = await _generateJsonMap(
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': 'Give me a speaking task.'}
          ]
        }
      ],
      systemInstruction: system,
      temperature: 1.0,
    );
    return SpeakingPrompt(
      prompt: (map['prompt'] ?? '').toString().trim(),
      hint: (map['hint'] ?? '').toString().trim(),
    );
  }

  Future<Map<String, dynamic>> evaluateSpeech({
    required String transcript,
    required String targetLanguage,
    required String nativeLanguage,
    required SkillLevel level,
    required String prompt,
  }) async {
    final system = '''You are a patient $targetLanguage pronunciation and speaking coach.
The learner is at a ${level.label} level; their native language is $nativeLanguage.
They were asked: "$prompt".
You only receive an automatic speech-to-text transcript (no audio), so judge grammar, vocabulary and fluency, and note that pronunciation is estimated.
Return ONLY a JSON object (no code fences):
{"score":number,"feedback":string,"corrected":string,"tips":string}
- "score": an integer from 0 to 10.
- "feedback": 2-3 encouraging sentences in $nativeLanguage.
- "corrected": a corrected, natural version of what they said, in $targetLanguage.
- "tips": one concrete tip in $nativeLanguage.
No markdown.''';

    return _generateJsonMap(
      contents: [
        {
          'role': 'user',
          'parts': [
            {
              'text': transcript.trim().isEmpty
                  ? '(the learner said nothing intelligible)'
                  : transcript
            }
          ]
        }
      ],
      systemInstruction: system,
      temperature: 0.5,
    );
  }

  // ---------------------------------------------------------- 6. Daily practice

  Future<Map<String, dynamic>> dailyPractice({
    required String targetLanguage,
    required String nativeLanguage,
    required SkillLevel level,
  }) async {
    final system = '''You are a $targetLanguage teacher preparing a daily practice for a ${level.label} learner whose native language is $nativeLanguage.
Return ONLY a JSON object (no code fences):
{"word":string,"wordTranslation":string,"wordExample":string,"phrase":string,"phraseTranslation":string,"challenge":string}
- "word"/"phrase"/"wordExample"/"challenge": in $targetLanguage (the challenge is a short speaking or writing task).
- "wordTranslation"/"phraseTranslation": in $nativeLanguage.
Pick something fresh and useful each day. No markdown.''';

    return _generateJsonMap(
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': 'Give me today\'s practice.'}
          ]
        }
      ],
      systemInstruction: system,
      temperature: 1.1,
    );
  }

  // ------------------------------------------------------------ 7. Role-play

  String _rolePlaySystem({
    required RolePlayScenario scenario,
    required String targetLanguage,
    required String nativeLanguage,
    required SkillLevel level,
  }) =>
      '''You are ${scenario.aiRole} in a role-play with a learner studying $targetLanguage at a ${level.label} level.
Stay in character at all times. Always speak in $targetLanguage, at a ${level.label} level, in 1-2 short sentences.
Keep the conversation moving by asking questions or reacting naturally.
Reply with plain text only — no JSON, no markdown, no emoji.''';

  Future<String> rolePlayOpening({
    required RolePlayScenario scenario,
    required String targetLanguage,
    required String nativeLanguage,
    required SkillLevel level,
  }) async {
    return _generate(
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': 'Begin the role-play with your first line.'}
          ]
        }
      ],
      systemInstruction: _rolePlaySystem(
        scenario: scenario,
        targetLanguage: targetLanguage,
        nativeLanguage: nativeLanguage,
        level: level,
      ),
      temperature: 0.9,
    );
  }

  Future<String> rolePlayReply({
    required RolePlayScenario scenario,
    required String targetLanguage,
    required String nativeLanguage,
    required SkillLevel level,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    final contents = <Map<String, dynamic>>[];
    for (final message in history) {
      contents.add({
        'role': message.isUser ? 'user' : 'model',
        'parts': [
          {'text': message.text}
        ]
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ]
    });

    return _generate(
      contents: contents,
      systemInstruction: _rolePlaySystem(
        scenario: scenario,
        targetLanguage: targetLanguage,
        nativeLanguage: nativeLanguage,
        level: level,
      ),
      temperature: 0.9,
    );
  }
}
