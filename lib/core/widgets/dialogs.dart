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
  final controller = TextEditingController(text: initialValue);
  try {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(submitLabel),
          ),
        ],
      ),
    );
    return (result == null || result.isEmpty) ? null : result;
  } finally {
    controller.dispose();
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
