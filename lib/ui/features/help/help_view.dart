import 'package:flutter/material.dart';

import '../../../core/widgets/markdown_preview.dart';
import 'help_content.dart';

/// «Hjelp»-siden: en kort brukerveiledning rendret som Markdown.
///
/// Innholdet ligger i appen ([helpContent]) og følger med – ingen
/// nedlasting, ingen internett.
class HelpView extends StatelessWidget {
  const HelpView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hjelp')),
      body: MarkdownPreview(content: helpContent),
    );
  }
}
