import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/ai_client.dart';
import '../../../data/services/ai_settings.dart';
import '../../../data/services/secure_key_store.dart';
import '../../../domain/ai/prompts.dart';
import '../../../domain/ai/structure_suggestion.dart';
import '../../../domain/models/section_type.dart';
import 'ai_assistant_view_model.dart';

/// Åpner dialogen for AI-strukturforslag.
///
/// [description] er prefyllt hyttebeskrivelse (brukes som prompt-innhold).
/// [onApprove] kalles med det parsede forslaget når brukeren godkjenner;
/// dialogen popper seg selv uansett utfall.
Future<void> showAiStructureDialog(
  BuildContext context, {
  required String description,
  required FutureOr<void> Function(AiStructureSuggestion suggestion) onApprove,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _AiStructureDialog(description: description, onApprove: onApprove),
  );
}

class _AiStructureDialog extends StatefulWidget {
  const _AiStructureDialog({
    required this.description,
    required this.onApprove,
  });

  final String description;
  final FutureOr<void> Function(AiStructureSuggestion suggestion) onApprove;

  @override
  State<_AiStructureDialog> createState() => _AiStructureDialogState();
}

class _AiStructureDialogState extends State<_AiStructureDialog> {
  late final AiAssistantViewModel _vm;
  late final TextEditingController _description;
  final ScrollController _scroll = ScrollController();

  AiStructureSuggestion? _parsed;
  bool _parseChecked = false;

  @override
  void initState() {
    super.initState();
    _vm = AiAssistantViewModel(
      context.read<SettingsRepository>(),
      context.read<SecureKeyStore>(),
      context.read<AiClientBuilder>(),
    )..addListener(_onVmChanged);
    _description = TextEditingController(text: widget.description);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _description.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (!_parseChecked && _vm.state == AiRunState.done) {
      _parseChecked = true;
      _parsed = AiStructureSuggestion.tryParse(_vm.text);
    }
    if (!mounted) return;
    setState(() {});
    // Følg med på streamingen.
    if (_vm.state == AiRunState.running) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  void _generate() {
    final settings = context.read<SettingsRepository>().loadAiSettings();
    final base = settings?.systemPrompt ?? kDefaultAiSystemPrompt;
    _parsed = null;
    _parseChecked = false;
    final text = _description.text.trim();
    _vm.run(
      system: AiPrompts.structureSystem(base),
      user: AiPrompts.structureUser(text.isEmpty ? 'En hytte.' : text),
    );
  }

  void _dismiss() => Navigator.of(context).pop();

  Future<void> _approve() async {
    final parsed = _parsed;
    if (parsed == null) return;
    await widget.onApprove(parsed);
    if (mounted) Navigator.of(context).pop();
  }

  static String _typeLabel(SectionType type) {
    switch (type) {
      case SectionType.startRoutines:
        return 'Start';
      case SectionType.stopRoutines:
        return 'Stopp';
      case SectionType.beskrivelse:
        return 'Beskrivelse';
      case SectionType.notater:
        return 'Notater';
      case SectionType.medier:
        return 'Medier';
      case SectionType.egen:
        return 'Egen';
    }
  }

  Widget _inputBody() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: _description,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Beskriv hytta',
            hintText: 'f.eks. trestue på fjellet med peis, båt og hester',
          ),
        ),
      ),
    );
  }

  Widget _streamBody() {
    return SingleChildScrollView(
      controller: _scroll,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Genererer…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(_vm.text.isEmpty ? '…' : _vm.text),
          ],
        ),
      ),
    );
  }

  Widget _parsedBody() {
    final suggestion = _parsed!;
    return ListView(
      shrinkWrap: true,
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final s in suggestion.sections)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _typeLabel(s.type),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (s.hint.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        s.hint,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _unparsedBody() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kunne ikke tolke svaret som en seksjonsliste. Prøv igjen, '
              'eller sjekk rå svar-tekst under.',
              style: TextStyle(color: scheme.error),
            ),
            const SizedBox(height: 8),
            SelectableText(_vm.text),
          ],
        ),
      ),
    );
  }

  Widget _errorBody() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Text(_vm.errorMessage, style: TextStyle(color: scheme.error)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _vm.state;
    final parsed = _parsed != null && state == AiRunState.done;

    Widget body;
    Widget primary;
    switch (state) {
      case AiRunState.idle:
        body = _inputBody();
        primary = FilledButton.icon(
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generer'),
          onPressed: _generate,
        );
      case AiRunState.running:
        body = _streamBody();
        primary = OutlinedButton(
          onPressed: _vm.cancel,
          child: const Text('Avbryt'),
        );
      case AiRunState.done:
        body = parsed ? _parsedBody() : _unparsedBody();
        primary = parsed
            ? FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Opprett seksjoner'),
                onPressed: _approve,
              )
            : FilledButton.tonal(
                onPressed: _generate,
                child: const Text('Prøv igjen'),
              );
      case AiRunState.error:
        body = _errorBody();
        primary = FilledButton.tonal(
          onPressed: _generate,
          child: const Text('Prøv igjen'),
        );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Foreslå struktur',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: body),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  TextButton(onPressed: _dismiss, child: const Text('Forkast')),
                  const Spacer(),
                  primary,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
