import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../services/gemini_service.dart';
import '../widgets/common.dart';

/// 5. Grammar Correction — paste any text and get it fixed with explanations.
class GrammarScreen extends StatefulWidget {
  final Language language;
  final SkillLevel level;

  const GrammarScreen({
    super.key,
    required this.language,
    required this.level,
  });

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? _result;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type or paste some text first.')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final result = await context.read<GeminiService>().correctText(
            text: text,
            targetLanguage: widget.language.name,
            nativeLanguage:
                languageByCode(context.read<SettingsProvider>().nativeLanguage)
                    .name,
          );
      if (!mounted) return;
      setState(() => _result = result);
      final progress = context.read<ProgressProvider>();
      await progress.addXp(widget.language.code, 10);
      await progress.registerPractice(widget.language.code);
    } on GeminiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.language.flag} Grammar · ${widget.level.label}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            maxLines: 6,
            minLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Paste or type text in ${widget.language.name} to check…',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _check,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.spellcheck),
            label: const Text('Check my text'),
          ),
          const SizedBox(height: 20),
          if (_result != null) ..._results(context),
        ],
      ),
    );
  }

  List<Widget> _results(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result!;
    final correctedText = (result['correctedText'] ?? '').toString();
    final overall = (result['overall'] ?? '').toString();
    final corrections = <Map<String, dynamic>>[];
    final raw = result['corrections'];
    if (raw is List) {
      for (final c in raw) {
        if (c is Map) corrections.add(Map<String, dynamic>.from(c));
      }
    }

    return [
      if (correctedText.isNotEmpty)
        SectionCard(
          title: 'Corrected text',
          child: Text(
            correctedText,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
        ),
      const SizedBox(height: 16),
      if (corrections.isEmpty)
        SectionCard(
          title: 'Great news',
          child: Text(
            'No mistakes found — your text looks correct! 🎉',
            style: theme.textTheme.bodyLarge,
          ),
        )
      else ...[
        Text(
          'Corrections (${corrections.length})',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...corrections.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(context, '✍️ You wrote',
                      (c['original'] ?? '').toString(), theme.colorScheme.error),
                  const SizedBox(height: 8),
                  _line(context, '✅ Correct',
                      (c['corrected'] ?? '').toString(), Colors.green),
                  if ((c['explanation'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _line(context, '💡 Why', (c['explanation']).toString(),
                        Colors.orange),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
      if (overall.isNotEmpty) ...[
        const SizedBox(height: 6),
        SectionCard(
          title: 'Summary',
          child: Text(overall, style: theme.textTheme.bodyLarge),
        ),
      ],
    ];
  }

  Widget _line(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
