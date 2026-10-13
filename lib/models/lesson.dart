/// One vocabulary entry inside a lesson.
class VocabItem {
  final String term;
  final String translation;
  final String example;

  const VocabItem({
    required this.term,
    required this.translation,
    this.example = '',
  });

  factory VocabItem.fromJson(Map<String, dynamic> json) => VocabItem(
        term: (json['term'] ?? '').toString(),
        translation: (json['translation'] ?? '').toString(),
        example: (json['example'] ?? '').toString(),
      );
}

/// A target-language sentence with its translation.
class SentencePair {
  final String target;
  final String native;

  const SentencePair({required this.target, required this.native});

  factory SentencePair.fromJson(Map<String, dynamic> json) => SentencePair(
        target: (json['target'] ?? '').toString(),
        native: (json['native'] ?? '').toString(),
      );
}

/// A complete AI-generated lesson on a topic.
class Lesson {
  final String title;
  final String topic;
  final String level;
  final List<VocabItem> vocabulary;
  final List<SentencePair> sentences;

  const Lesson({
    required this.title,
    required this.topic,
    required this.level,
    required this.vocabulary,
    required this.sentences,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final vocab = <VocabItem>[];
    final rawVocab = json['vocabulary'];
    if (rawVocab is List) {
      for (final v in rawVocab) {
        if (v is Map) {
          vocab.add(VocabItem.fromJson(Map<String, dynamic>.from(v)));
        }
      }
    }
    final sentences = <SentencePair>[];
    final rawSentences = json['sentences'];
    if (rawSentences is List) {
      for (final s in rawSentences) {
        if (s is Map) {
          sentences.add(SentencePair.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    return Lesson(
      title: (json['title'] ?? 'Lesson').toString(),
      topic: (json['topic'] ?? '').toString(),
      level: (json['level'] ?? '').toString(),
      vocabulary: vocab,
      sentences: sentences,
    );
  }
}
