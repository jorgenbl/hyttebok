import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/book_repository.dart';

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
          if (bookSlug == null) {
            return _imagePlaceholder(
              context,
              srcStr.isEmpty ? 'Bilde' : srcStr,
              scheme,
            );
          }
          return _BookImage(repo: repo, bookSlug: bookSlug!, src: srcStr);
        },
      ),
    );
  }
}

/// Laster et lokalt bilde fra boka som byteer og viser det.
class _BookImage extends StatelessWidget {
  const _BookImage({
    required this.repo,
    required this.bookSlug,
    required this.src,
  });

  final BookRepository repo;
  final String bookSlug;
  final String src;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<Uint8List?>(
      future: repo.readImageSafe(bookSlug, src),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Image.memory(bytes, fit: BoxFit.fitWidth),
          );
        }
        if (snapshot.hasError) {
          return _imagePlaceholder(
            context,
            src.isEmpty ? 'Bilde' : src,
            scheme,
          );
        }
        // Lastes fortsatt: kort plassholder i stedet for flash.
        return const SizedBox(
          width: double.infinity,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}

Widget _imagePlaceholder(
  BuildContext context,
  String label,
  ColorScheme scheme,
) {
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
            child: Text('🖼️ $label', style: TextStyle(color: scheme.outline)),
          ),
        ],
      ),
    ),
  );
}
