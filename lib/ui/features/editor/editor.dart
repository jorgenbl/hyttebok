import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show ImageSource, XFile;
import 'package:provider/provider.dart';

import '../../../core/widgets/markdown_preview.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/image_picker_service.dart';
import '../../../domain/ai/prompts.dart';
import '../../../domain/models/section_type.dart';
import '../../../ui/features/ai/writing_dialog.dart';

/// Input for editor-ruten: hva som redigeres og hvordan.
class EditorInput {
  const EditorInput({
    required this.title,
    required this.initialValue,
    this.hint,
    this.bookSlug,
    this.sectionType,
  });

  final String title;

  /// Innholdet som skal redigeres (Markdown).
  final String initialValue;
  final String? hint;

  /// Boken som bildet hører til (for å lagre og vise lokale bilder).
  final String? bookSlug;

  /// Hvilken seksjonstype som redigeres; viser «Generer rutineliste» i
  /// AI-menyen når det er en start-/steng-rutine.
  final SectionType? sectionType;
}

/// Generisk Markdown-editor med fanene «Rediger»/«Forhåndsvis».
///
/// «Lagre» popper ruten med den aktuelle teksten ([String]) som resultat;
/// kalleren avgjør hva den gjør med den. Når [EditorInput.bookSlug] er satt kan
/// man ta opp / velge bilder og legge dem inn i teksten som Markdown.
class EditorView extends StatefulWidget {
  const EditorView({super.key, required this.input});

  final EditorInput input;

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView>
    with SingleTickerProviderStateMixin {
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

  /// Plukker et bilde fra [source], lagrer det i boken og setter inn en
  /// Markdown-referanse på cursorposisjonen.
  Future<void> _addImage(BuildContext context, ImageSource source) async {
    final bookSlug = widget.input.bookSlug;
    if (bookSlug == null) return;
    final service = context.read<ImagePickerService>();
    final XFile? file = source == ImageSource.camera
        ? await service.takePhoto()
        : await service.pickFromGallery();
    if (file == null || !context.mounted) return; // avbrutt / rettighet avslått
    final repo = context.read<BookRepository>();
    final String relative;
    try {
      relative = await repo.importImage(bookSlug, file);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunne ikke lagre bildet.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    _insertAtCursor('![${relative.split('/').last}]($relative)\n');
  }

  void _insertAtCursor(String text) {
    final controller = _controller;
    final sel = controller.selection;
    final end = sel.end < 0 ? controller.text.length : sel.end;
    final start = sel.start < 0 ? end : sel.start;
    final before = controller.text.substring(0, start);
    final after = controller.text.substring(end);
    controller.value = TextEditingValue(
      text: before + text + after,
      selection: TextSelection.collapsed(offset: before.length + text.length),
    );
  }

  bool get _isRoutineSection {
    final type = widget.input.sectionType;
    return type == SectionType.startRoutines ||
        type == SectionType.stopRoutines;
  }

  /// AI-skriverhjelp: utvid/omskriv/oppsummer på markert (ellers hele)
  /// tekst, eller generer en rutineliste basert på teksten.
  Future<void> _aiAction(String action) async {
    final settings = context.read<SettingsRepository>().loadAiSettings();
    if (settings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI er ikke konfigurert. Åpne Innstillinger → AI.'),
        ),
      );
      return;
    }
    final base = settings.systemPrompt;
    final value = _controller.value;
    final selected =
        value.selection.isValid && value.selection.start != value.selection.end
        ? value.text.substring(value.selection.start, value.selection.end)
        : '';
    final source = selected.isNotEmpty ? selected : value.text.trim();
    if (source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skriv eller marker tekst først.')),
      );
      return;
    }

    String title;
    String system;
    String user;
    switch (action) {
      case 'extend':
        title = 'Utvid teksten';
        system = AiPrompts.writingSystem(base, AiWritingInstruction.extend);
        user = AiPrompts.writingUser(source);
      case 'rewrite':
        title = 'Omskriv teksten';
        system = AiPrompts.writingSystem(base, AiWritingInstruction.rewrite);
        user = AiPrompts.writingUser(source);
      case 'summarize':
        title = 'Oppsummer teksten';
        system = AiPrompts.writingSystem(base, AiWritingInstruction.summarize);
        user = AiPrompts.writingUser(source);
      case 'routine':
        final isStart = widget.input.sectionType == SectionType.startRoutines;
        title = 'Generer rutineliste';
        system = AiPrompts.routineSystem(base);
        user = AiPrompts.routineUser(source, isStart: isStart);
      default:
        return;
    }

    final result = await showAiWritingDialog(
      context,
      title: title,
      system: system,
      user: user,
    );
    if (result == null || !context.mounted) return;
    _tabs.animateTo(0);
    _applyAiResult(result, hasSelection: selected.isNotEmpty);
  }

  /// Erstatte markert tekst (eller hele teksten) med AI-resultatet.
  void _applyAiResult(String result, {required bool hasSelection}) {
    final value = _controller.value;
    if (hasSelection) {
      final sel = value.selection;
      final before = value.text.substring(0, sel.start);
      final after = value.text.substring(sel.end);
      final text = before + result + after;
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: before.length + result.length,
        ),
      );
    } else {
      _controller.value = TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookSlug = widget.input.bookSlug;
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'AI-hjelp',
            onSelected: _aiAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'extend',
                child: Text('Utvid teksten'),
              ),
              const PopupMenuItem(
                value: 'rewrite',
                child: Text('Omskriv teksten'),
              ),
              const PopupMenuItem(
                value: 'summarize',
                child: Text('Oppsummer teksten'),
              ),
              if (_isRoutineSection) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'routine',
                  child: Text('Generer rutineliste'),
                ),
              ],
            ],
          ),
          TextButton(
            onPressed: () => context.pop(_controller.text),
            child: const Text('Lagre'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          Column(
            children: [
              if (bookSlug != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Ta bilde',
                          icon: const Icon(Icons.photo_camera_outlined),
                          onPressed: () =>
                              _addImage(context, ImageSource.camera),
                        ),
                        IconButton(
                          tooltip: 'Fra galleri',
                          icon: const Icon(Icons.photo_library_outlined),
                          onPressed: () =>
                              _addImage(context, ImageSource.gallery),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: null,
                    minLines: 10,
                    decoration: const InputDecoration(
                      hintText: 'Skriv i Markdown…  (f.eks. - [ ] oppgave, # overskrift)',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
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
