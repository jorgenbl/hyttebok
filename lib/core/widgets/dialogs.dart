import 'package:flutter/material.dart';

/// Viser en enkel tekst-innspurt-dialog og returnerer den inntastede
/// teksten (trimmet), eller `null` ved avbryt/tomt.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? label,
  String? initialValue,
  String? hint,
  String submitLabel = 'Lagre',
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => _TextInputDialog(
      title: title,
      label: label,
      initialValue: initialValue,
      hint: hint,
      submitLabel: submitLabel,
    ),
  );
  return (result == null || result.isEmpty) ? null : result;
}

/// Enkel tekst-innspurt-dialog som selv eier sin [TextEditingController]
/// (disposert i [State.dispose]), slik at kontrollen ikke rammes av «used
/// after dispose» under dialogens ut-animation.
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    this.label,
    this.initialValue,
    this.hint,
    required this.submitLabel,
  });

  final String title;
  final String? label;
  final String? initialValue;
  final String? hint;
  final String submitLabel;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

/// Viser en bekreftelsesdialog. Returnerer `true` ved bekreftelse.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Slett',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
