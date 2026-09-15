import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show ImageSource, XFile;
import 'package:provider/provider.dart';

import '../../../core/widgets/markdown_preview.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/ai_settings.dart';
import '../../../data/services/image_picker_service.dart';
import '../../../data/services/speech_to_text_service.dart';
import '../../../domain/ai/prompts.dart';
import '../../../domain/models/section_type.dart';
import '../../../ui/features/ai/image_dialog.dart';
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

/// Liste-markører editoren kjennes og hjelper brukeren med:
/// avkrysningsliste (`- [ ] `), punktoppstrek (`- `) og nummerert (`1. `).
final RegExp _checklistMarker = RegExp(r'^- \[[ xX]\] ?');
final RegExp _bulletMarker = RegExp(r'^[-*] ?');
final RegExp _numberedMarker = RegExp(r'^(\d+)\. ?');

/// Liste-typer som verktøylinjen kan sette/ta av.
enum _ListKind { checklist, bullet, numbered }

/// Markøren for [line], dersom linjen er en liste-post (ellers `null`).
String? _listMarkerFor(String line) {
  if (_checklistMarker.hasMatch(line)) return '- [ ] ';
  if (_bulletMarker.hasMatch(line)) return '- ';
  if (_numberedMarker.hasMatch(line)) return '1. ';
  return null;
}

/// Markøren som en ny liste-post skal få etter [line]: samme type, og
/// nummerert lister øker med én.
String _continuationMarker(String line) {
  final numbered = _numberedMarker.firstMatch(line);
  if (numbered != null) return '${int.parse(numbered.group(1)!) + 1}. ';
  if (_checklistMarker.hasMatch(line)) return '- [ ] ';
  return '- ';
}

/// Fjerner en liste-markør fra start av [line] (endres ikke hvis ingen).
String _stripListMarker(String line) {
  for (final re in [_checklistMarker, _bulletMarker, _numberedMarker]) {
    final m = re.firstMatch(line);
    if (m != null) return line.substring(m.end);
  }
  return line;
}

/// Er hele [s] akkurat en liste-markør (eventuelt med mellomrom)?
bool _isFullMarker(String s) =>
    _checklistFull.hasMatch(s) ||
    _bulletFull.hasMatch(s) ||
    _numberedFull.hasMatch(s);

final RegExp _checklistFull = RegExp(r'^- \[[ xX]\] ?$');
final RegExp _bulletFull = RegExp(r'^[-*] ?$');
final RegExp _numberedFull = RegExp(r'^\d+\. ?$');

class _EditorViewState extends State<EditorView>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final TabController _tabs;

  /// Forrige tekstverdi; brukt av de smarte listene til å se hva brukeren
  /// nettopp gjorde (Enter/Backspace) uten å avhenge av tastehendelser.
  late TextEditingValue _prevValue;

  /// Dikteringstjenesten; leses lat når dikteringsknappen trykkes (editoren
  /// fungerer uten den, f.eks. i tester som bare øver på listene). Holdes
  /// slik at [dispose] kan stoppe en pågående sesjon.
  SpeechToTextService? _speech;

  /// `true` mens en dikteringsøkt kjører; knappen vises aktiv og kan ikke
  /// trykkes på nytt.
  bool _dictating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.input.initialValue);
    _prevValue = _controller.value;
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // Avslutt en pågående mikrofon-sesjon når editoren lukkes.
    if (_dictating) {
      final speech = _speech;
      if (speech != null) unawaited(speech.stop());
    }
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  /// Dikterer med stemmen og setter den anerkjente teksten inn på
  /// cursorposisjonen (med ett mellomrom foran hvis det ligger tekst der).
  Future<void> _dictate() async {
    if (_dictating) return;
    final speech = context.read<SpeechToTextService>();
    _speech = speech;
    setState(() => _dictating = true);
    try {
      final text = await speech.listen();
      if (text == null || text.isEmpty || !mounted) return;
      _insertDictated(text);
    } on DictationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _dictating = false);
    }
  }

  /// Setter inn diktert tekst på cursorposisjonen; legger til ett mellomrom
  /// foran dersom det forrige tegnet ikke er blankt (eller tekst er tom).
  void _insertDictated(String text) {
    final controller = _controller;
    final sel = controller.selection;
    final end = sel.end < 0 ? controller.text.length : sel.end;
    final start = sel.start < 0 ? end : sel.start;
    final before = controller.text.substring(0, start);
    final after = controller.text.substring(end);
    final needsSpace =
        before.isNotEmpty && !RegExp(r'\s').hasMatch(before[before.length - 1]);
    final insert = (needsSpace ? ' ' : '') + text;
    controller.value = TextEditingValue(
      text: before + insert + after,
      selection: TextSelection.collapsed(offset: before.length + insert.length),
    );
  }

  /// Smarte lister: Enter fortsetter en liste-post (ny markør, nummer øker),
  /// Enter på en tom post forlater listen, og Backspace i selve markøren
  /// fjerner hele markøren med ett. Tekstbasert (ikke tastehendelser), slik
  /// at det fungerer likt på iOS, Android og web.
  void _onTextChanged(TextEditingValue value) {
    final prev = _prevValue;
    _prevValue = value;
    final fixed = _smartListFix(prev, value);
    if (fixed != null) _controller.value = fixed;
  }

  TextEditingValue? _smartListFix(
    TextEditingValue prev,
    TextEditingValue next,
  ) {
    final old = prev.text;
    final text = next.text;

    // Enter: nøyaktig ett '\n' er satt inn ved posisjon [c], og cursor
    // står rett etter det.
    if (text.length == old.length + 1) {
      var c = 0;
      while (c < old.length && text[c] == old[c]) {
        c++;
      }
      final atCursor =
          next.selection.isCollapsed && next.selection.baseOffset == c + 1;
      if (c <= old.length &&
          text[c] == '\n' &&
          text.substring(c + 1) == old.substring(c) &&
          atCursor) {
        final lineStart = c == 0 ? 0 : text.lastIndexOf('\n', c - 1) + 1;
        final line = text.substring(lineStart, c);
        if (_listMarkerFor(line) != null || _numberedMarker.hasMatch(line)) {
          // Tom liste-post: går ut av listen.
          if (_isFullMarker(line)) {
            return TextEditingValue(
              text: text.substring(0, lineStart) + text.substring(c + 1),
              selection: TextSelection.collapsed(offset: lineStart),
            );
          }
          final marker = _continuationMarker(line);
          final t = text.substring(0, c + 1) + marker + text.substring(c + 1);
          return TextEditingValue(
            text: t,
            selection: TextSelection.collapsed(offset: c + 1 + marker.length),
          );
        }
      }
    }

    // Backspace: nøyaktig ett tegn er fjernet (ved [c] i gammel tekst).
    if (text.length == old.length - 1) {
      var c = 0;
      while (c < text.length && text[c] == old[c]) {
        c++;
      }
      final atCursor =
          next.selection.isCollapsed && next.selection.baseOffset == c;
      if (c < old.length &&
          text.substring(c) == old.substring(c + 1) &&
          atCursor) {
        final removed = old[c];
        if (removed != '\n' && c > 0) {
          final lineStart = text.lastIndexOf('\n', c - 1) + 1;
          // Bare «ute av listen» når cursor stod i enden av linjen.
          final lineEnd = text.indexOf('\n', c);
          final rest = lineEnd == -1 ? '' : text.substring(c, lineEnd);
          if (rest.isEmpty) {
            final line = text.substring(lineStart, c);
            if (_isFullMarker(line + removed)) {
              return TextEditingValue(
                text: text.substring(0, lineStart) + text.substring(c),
                selection: TextSelection.collapsed(offset: lineStart),
              );
            }
          }
        }
      }
    }
    return null;
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

  /// Genererer et bilde med AI (bildeprofilen, ellers standardprofilen),
  /// lagrer det i boken og setter inn en Markdown-referanse på cursorposi-
  /// sjonen.
  Future<void> _generateAiImage(BuildContext context) async {
    final bookSlug = widget.input.bookSlug;
    if (bookSlug == null) return;
    final repo = context.read<SettingsRepository>();
    final settings =
        repo.loadAiProfile(AiPurpose.images) ?? repo.loadAiSettings();
    if (settings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI er ikke konfigurert. Åpne Innstillinger → AI → Bildegenerering.',
          ),
        ),
      );
      return;
    }
    final relative = await showAiImageDialog(context, bookSlug: bookSlug);
    if (relative == null || !context.mounted) return;
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

  bool _hasKindMarker(String line, _ListKind kind) {
    switch (kind) {
      case _ListKind.checklist:
        return _checklistMarker.hasMatch(line);
      case _ListKind.bullet:
        return _bulletMarker.hasMatch(line);
      case _ListKind.numbered:
        return _numberedMarker.hasMatch(line);
    }
  }

  /// Setter av (eller på) [kind]-liste-markør på markerte linjer (eller
  /// linjen cursor står på). Marker man hele listen og trykker samme knapp
  /// igjen, fjernes markørene. Nummererte lister nummereres på nytt 1, 2, …
  void _applyList(_ListKind kind) {
    final value = _controller.value;
    final text = value.text;
    final sel = value.selection;
    final collapsed = sel.isValid && sel.isCollapsed;
    final start = (sel.isValid && sel.start >= 0) ? sel.start : 0;
    final end = (sel.isValid && sel.end >= 0) ? sel.end : text.length;

    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    var lineEnd = end;
    if (lineEnd < text.length && text[lineEnd] != '\n') {
      final nl = text.indexOf('\n', lineEnd);
      lineEnd = nl == -1 ? text.length : nl;
    }

    final lines = <String>[];
    var i = lineStart;
    while (i < lineEnd) {
      final nl = text.indexOf('\n', i);
      final e = nl == -1 ? text.length : nl;
      lines.add(text.substring(i, e));
      i = e + 1;
    }

    if (lines.isEmpty) {
      // Tom tekst (eller cursor på linjegrense): start listen her.
      final marker = switch (kind) {
        _ListKind.checklist => '- [ ] ',
        _ListKind.bullet => '- ',
        _ListKind.numbered => '1. ',
      };
      _controller.value = TextEditingValue(
        text: text.substring(0, lineStart) + marker + text.substring(lineStart),
        selection: TextSelection.collapsed(offset: lineStart + marker.length),
      );
      return;
    }

    final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList();
    final allMarked =
        nonEmpty.isNotEmpty && nonEmpty.every((l) => _hasKindMarker(l, kind));

    final out = StringBuffer(text.substring(0, lineStart));
    var counter = 0;
    for (var li = 0; li < lines.length; li++) {
      var line = lines[li];
      if (line.trim().isNotEmpty) {
        counter++;
        final body = _stripListMarker(line);
        if (allMarked) {
          line = body;
        } else {
          line = switch (kind) {
            _ListKind.checklist => '- [ ] $body',
            _ListKind.bullet => '- $body',
            _ListKind.numbered => '$counter. $body',
          };
        }
      } else if (collapsed && lines.length == 1) {
        // Tom linje: start en ny liste (ellers skulle tomme linjer i et
        // utvalg ikke markeres).
        counter = 1;
        line = switch (kind) {
          _ListKind.checklist => '- [ ] ',
          _ListKind.bullet => '- ',
          _ListKind.numbered => '1. ',
        };
      }
      out.write(line);
      if (li < lines.length - 1) out.write('\n');
    }
    out.write(text.substring(lineEnd));

    final newEnd =
        lineStart + (out.length - lineStart) - (text.length - lineEnd);
    _controller.value = TextEditingValue(
      text: out.toString(),
      selection: collapsed
          ? TextSelection.collapsed(offset: newEnd)
          : TextSelection(baseOffset: lineStart, extentOffset: newEnd),
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
    // Skrivehjelpen kjører på formålet [AiPurpose.writing]: egen profil om
    // satt, ellers standardprofilen.
    final repo = context.read<SettingsRepository>();
    final settings =
        repo.loadAiProfile(AiPurpose.writing) ?? repo.loadAiSettings();
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
    final theme = Theme.of(context);
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
              // Verktøylinje: liste-knapper alltid; bilde-knapper når
              // editoren hører til en bok.
              Padding(
                padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Avkrysningsliste',
                      icon: const Icon(Icons.checklist),
                      onPressed: () => _applyList(_ListKind.checklist),
                    ),
                    IconButton(
                      tooltip: 'Punktliste',
                      icon: const Icon(Icons.format_list_bulleted),
                      onPressed: () => _applyList(_ListKind.bullet),
                    ),
                    IconButton(
                      tooltip: 'Nummerert liste',
                      icon: const Icon(Icons.format_list_numbered),
                      onPressed: () => _applyList(_ListKind.numbered),
                    ),
                    IconButton(
                      tooltip: _dictating ? 'Stemmen lyttes på …' : 'Diktering',
                      icon: Icon(
                        Icons.mic,
                        color: _dictating ? theme.colorScheme.primary : null,
                      ),
                      onPressed: _dictating ? null : _dictate,
                    ),
                    const Spacer(),
                    if (bookSlug != null) ...[
                      // Web har ingen kamera-plugin; filplukkeren dekkes
                      // av «Fra galleri».
                      if (!kIsWeb)
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
                      IconButton(
                        tooltip: 'Generer bilde (AI)',
                        icon: const Icon(Icons.auto_awesome),
                        onPressed: () => _generateAiImage(context),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: null,
                    minLines: 10,
                    onChanged: (_) => _onTextChanged(_controller.value),
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
