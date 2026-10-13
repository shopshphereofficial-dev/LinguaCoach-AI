import 'package:flutter/material.dart';

import '../models/chat_message.dart';

/// A chat bubble. Learner messages are right-aligned; tutor messages are
/// left-aligned and get a "Listen" button.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onSpeak;

  const ChatBubble({super.key, required this.message, this.onSpeak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isUser ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 15.5, height: 1.35),
            ),
          ),
        ),
        if (!isUser && onSpeak != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onSpeak,
              icon: const Icon(Icons.volume_up, size: 18),
              label: const Text('Listen'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        if (message.feedback != null && !message.feedback!.isEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: FeedbackCard(feedback: message.feedback!),
          ),
      ],
    );
  }
}

/// Shows the tutor's corrections under a learner's message.
class FeedbackCard extends StatelessWidget {
  final TutorFeedback feedback;

  const FeedbackCard({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];

    if (feedback.correction.isNotEmpty) {
      rows.add(_row(
        context,
        icon: Icons.check_circle_outline,
        color: Colors.green,
        label: 'Corrected',
        value: feedback.correction,
      ));
    }
    if (feedback.better.isNotEmpty) {
      rows.add(_row(
        context,
        icon: Icons.auto_awesome,
        color: Colors.blue,
        label: 'More natural',
        value: feedback.better,
      ));
    }
    if (feedback.explanation.isNotEmpty) {
      rows.add(_row(
        context,
        icon: Icons.lightbulb_outline,
        color: Colors.orange,
        label: 'Why',
        value: feedback.explanation,
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 6),
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurface),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
