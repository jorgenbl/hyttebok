import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/markdown_preview.dart';

/// Input for editor-ruten: hva som redigeres og hvordan.
class EditorInput {
  const EditorInput({
    required this.title,
    required this.initialValue,
    this.hint,
    this.bookSlug,
  });

  final String title;

  /// Innholdet som skal redigeres (Markdown).
  final String initialValue;
  final String? hint;

  /// Boken som bildet hører til (for å løse opp lokale bilder i forhåndsvisning).
  final String? bookSlug;
}

/// Generisk Markdown-editor med fanene «Rediger»/«Forhåndsvis».
///
/// «Lagre» popper ruten med den aktuelle teksten ([String]) som resultat;
/// kalleren avgjør hva den gjør med den.
class EditorView extends StatefulWidget {
  const EditorView({super.key, required this.input});

  final EditorInput input;

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.input.initialValue);
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.input.title),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Rediger'),
            Tab(text: 'Forhåndsvis'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(_controller.text),
            child: const Text('Lagre'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              maxLines: null,
              minLines: 12,
              decoration: const InputDecoration(
                hintText: 'Skriv i Markdown…  (f.eks. - [ ] oppgave, # overskrift)',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => MarkdownPreview(
              content: value.text,
              bookSlug: widget.input.bookSlug,
            ),
          ),
        ],
      ),
    );
  }
}
