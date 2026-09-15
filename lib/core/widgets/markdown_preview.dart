import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/book_repository.dart';
import 'book_image.dart';

/// Delte Markdown-stiler, brukt av både redigerings-forhåndsvisning og
/// lesevisningen, slik at innholdet ser likt ut overalt.
///
/// Overskriftene får luft over og under (h*Padding) slik at avsnittene
/// skiller seg visuelt fra innholdet. I kilden kan man i tillegg skrive
/// `---` for en horisontal linje.
MarkdownStyleSheet markdownStyleSheet(ThemeData theme) => MarkdownStyleSheet(
  h1: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
  h1Padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
  h2: theme.textTheme.titleLarge,
  h2Padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
  h3: theme.textTheme.titleMedium,
  h3Padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
  h4: theme.textTheme.titleSmall,
  h4Padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
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
