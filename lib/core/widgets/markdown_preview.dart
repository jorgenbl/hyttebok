import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/book_repository.dart';
import 'book_image.dart';

/// Delte Markdown-stiler, brukt av både redigerings-forhåndsvisning og
/// lesevisningen, slik at innholdet ser likt ut overalt.
MarkdownStyleSheet markdownStyleSheet(ThemeData theme) => MarkdownStyleSheet(
  h1: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
  h2: theme.textTheme.titleLarge,
  h3: theme.textTheme.titleMedium,
  h4: theme.textTheme.titleSmall,
  code: const TextStyle(fontFamily: 'monospace', fontSize: 13),
);

/// Renderer Markdown. Lokale bilder (`images/…`) løses opp mot boka dersom
/// [bookSlug] er gitt; manglende bilder vises som en plassholder.
///
/// Bildene lastes som byteer fra lagringen (platform-uavhengig – fungerer
/// like godt på web der filsystem-stier ikke eksisterer).
class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({super.key, required this.content, this.bookSlug});

  final String content;
  final String? bookSlug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<BookRepository>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slug = bookSlug;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: markdownStyleSheet(theme),
        sizedImageBuilder: (MarkdownImageConfig config) {
          final srcStr = config.uri.toString();
          if (slug == null) {
            return imagePlaceholder(
              context,
              srcStr.isEmpty ? 'Bilde' : srcStr,
              scheme,
            );
          }
          return BookImage(repo: repo, bookSlug: slug, src: srcStr);
        },
      ),
    );
  }
}
