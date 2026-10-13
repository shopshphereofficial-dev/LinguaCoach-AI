/// One generated exercise. `type` is one of:
/// multipleChoice, fillInBlank, translation, listening.
class QuizQuestion {
  final String type;
  final String prompt;
  final List<String> options;
  final String answer;
  final String explanation;

  const QuizQuestion({
    required this.type,
    required this.prompt,
    this.options = const <String>[],
    required this.answer,
    this.explanation = '',
  });

  bool get isListening => type == 'listening';

  /// Whether this question is answered by picking one of the options.
  bool get isChoice => options.isNotEmpty;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final options = <String>[];
    final raw = json['options'];
    if (raw is List) {
      for (final o in raw) {
        options.add(o.toString());
      }
    }
    return QuizQuestion(
      type: (json['type'] ?? 'multipleChoice').toString(),
      prompt: (json['prompt'] ?? json['question'] ?? '').toString(),
      options: options,
      answer: (json['answer'] ?? '').toString(),
      explanation: (json['explanation'] ?? '').toString(),
    );
  }

  /// Tolerant comparison used when checking the learner's typed answer.
  bool matches(String input) {
    String norm(String s) => s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[.,!?¿¡"\'`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    return norm(input) == norm(answer);
  }
}
