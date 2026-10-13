/// Feedback the tutor returns about the learner's last message.
class TutorFeedback {
  /// A grammatically corrected version of what the learner wrote.
  final String correction;

  /// A short explanation of the mistakes, in the learner's native language.
  final String explanation;

  /// A more natural / idiomatic way to say the same thing.
  final String better;

  const TutorFeedback({
    this.correction = '',
    this.explanation = '',
    this.better = '',
  });

  bool get isEmpty =>
      correction.trim().isEmpty &&
      explanation.trim().isEmpty &&
      better.trim().isEmpty;

  factory TutorFeedback.fromJson(Map<String, dynamic> json) => TutorFeedback(
        correction: (json['correction'] ?? '').toString().trim(),
        explanation: (json['explanation'] ?? '').toString().trim(),
        better: (json['better'] ?? '').toString().trim(),
      );
}

/// A single message in the AI Conversation Coach.
class ChatMessage {
  /// 'user' or 'model'.
  final String role;

  /// The conversational text (in the target language for the tutor).
  final String text;

  /// Optional feedback attached to a learner's message.
  final TutorFeedback? feedback;

  final DateTime time;

  ChatMessage({
    required this.role,
    required this.text,
    this.feedback,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  bool get isUser => role == 'user';
}
