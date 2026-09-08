import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/ai_client.dart';
import '../../../data/services/secure_key_store.dart';
import 'ai_assistant_view_model.dart';

/// Åpner dialogen for skrivehjelp (utvid/omskriv/oppsummer/rutineliste).
///
/// Prompten bygges av kalleren ([system] + [user]); dialogen streamer
/// svar-teksten og returnerer den når brukeren velger «Innsett» (ellers
/// `null` ved forkast/avbrudd).
Future<String?> showAiWritingDialog(
  BuildContext context, {
  required String title,
  required String system,
  required String user,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _AiWritingDialog(title: title, system: system, user: user),
  );
}

class _AiWritingDialog extends StatefulWidget {
  const _AiWritingDialog({
    required this.title,
    required this.system,
    required this.user,
  });

  final String title;
  final String system;
  final String user;

  @override
  State<_AiWritingDialog> createState() => _AiWritingDialogState();
}

class _AiWritingDialogState extends State<_AiWritingDialog> {
  late final AiAssistantViewModel _vm;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _vm = AiAssistantViewModel(
      context.read<SettingsRepository>(),
      context.read<SecureKeyStore>(),
      context.read<AiClientBuilder>(),
    )..addListener(_onVmChanged);
    _vm.run(system: widget.system, user: widget.user);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});
    if (_vm.state == AiRunState.running) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  void _insert() {
    final text = _vm.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  void _dismiss() => Navigator.of(context).pop();

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
                Text('Skriver…', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(_vm.text.isEmpty ? '…' : _vm.text),
          ],
        ),
      ),
    );
  }

  Widget _resultBody() {
    return SingleChildScrollView(
      controller: _scroll,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: SelectableText(_vm.text),
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

    Widget body;
    Widget primary;
    switch (state) {
      case AiRunState.idle:
        body = const SizedBox.shrink();
        primary = const SizedBox.shrink();
      case AiRunState.running:
        body = _streamBody();
        primary = OutlinedButton(
          onPressed: _vm.cancel,
          child: const Text('Avbryt'),
        );
      case AiRunState.done:
        body = _resultBody();
        primary = FilledButton.icon(
          icon: const Icon(Icons.drive_file_move_outlined),
          label: const Text('Innsett'),
          onPressed: _vm.text.trim().isEmpty ? null : _insert,
        );
      case AiRunState.error:
        body = _errorBody();
        primary = FilledButton.tonal(
          onPressed: () => _vm.run(system: widget.system, user: widget.user),
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
                      widget.title,
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
