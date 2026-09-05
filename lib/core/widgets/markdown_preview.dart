import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/book_repository.dart';

/// Renderer Markdown. Lokale bilder (`images/…`) løses opp mot bokens mappe
/// dersom [bookSlug] er gitt; manglende bilder vises som en plassholder.
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({super.key, required this.content, this.bookSlug});

  final String content;
  final String? bookSlug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<BookRepository>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          h1: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          h2: theme.textTheme.titleLarge,
          h3: theme.textTheme.titleMedium,
          h4: theme.textTheme.titleSmall,
          code: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
        sizedImageBuilder: (MarkdownImageConfig config) {
          final srcStr = config.uri.toString();
          final path = bookSlug == null
              ? null
              : repo.resolveImagePath(bookSlug!, srcStr);
          if (path == null) {
            return _placeholder(
              context,
              srcStr.isEmpty ? 'Bilde' : srcStr,
              scheme,
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Image.file(File(path), fit: BoxFit.fitWidth),
          );
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context, String label, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.broken_image, color: scheme.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '🖼️ $label',
                style: TextStyle(color: scheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
