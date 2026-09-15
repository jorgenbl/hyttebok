import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/format.dart';
import '../../../core/widgets/book_image.dart';
import '../../../core/widgets/cabin_illustration.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/markdown_preview.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../domain/models/cabin.dart';
import '../../../domain/models/section.dart';
import '../../../domain/models/story.dart';
import 'reader_view_model.dart';

/// Lesevisning: heila boka (eller én hytte) som ett lineært dokument –
/// samme innhold og rekkefølge som MD/PDF-eksporten, men lest direkte på
/// skjermen i stedet for å navigere mellom seksjonene.
class BookReaderView extends StatelessWidget {
  const BookReaderView({super.key, required this.bookSlug, this.cabinSlug});

  final String bookSlug;
  final String? cabinSlug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<BookRepository>();
    return ChangeNotifierProvider(
      create: (_) =>
          ReaderViewModel(repo, bookSlug, cabinSlug: cabinSlug)..load(),
      child: const _ReaderBody(),
    );
  }
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody();

  static const _hPad = 20.0;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReaderViewModel>();
    final book = vm.book;

    if (vm.loading && book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesevisning')),
        body: const SkeletonList(),
      );
    }
    if (book == null || vm.bookNotFound) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesevisning')),
        body: const EmptyState(
          icon: Icons.error_outline,
          message: 'Boken ble ikke funnet.',
        ),
      );
    }
    if (vm.cabinNotFound) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesevisning')),
        body: const EmptyState(
          icon: Icons.error_outline,
          message: 'Hytten ble ikke funnet.',
        ),
      );
    }

    final isSingleCabin = vm.cabinSlug != null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final repo = context.read<BookRepository>();
    final bookSlug = vm.bookSlug;
    final styleSheet = markdownStyleSheet(theme);

    Widget markdown(String content) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 2),
      child: MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: styleSheet,
        sizedImageBuilder: (config) => BookImage(
          repo: repo,
          bookSlug: bookSlug,
          src: config.uri.toString(),
        ),
      ),
    );

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 20, _hPad, 2),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    Widget meta(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(_hPad, 0, _hPad, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSingleCabin ? (vm.cabin?.name ?? 'Lesevisning') : book.title,
        ),
      ),
      body: ListView(
        // Key brukt av widget-testene for å finne scrolleområdet.
        key: const ValueKey('reader-scroll'),
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        children: [
          if (!isSingleCabin) ...[
            // Omslag: valgfritt omslagsbilde, ellers tegnet hyttemotiv.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: book.coverImage != null
                    ? SizedBox(
                        height: 180,
                        child: BookImage(
                          repo: repo,
                          bookSlug: bookSlug,
                          src: book.coverImage!,
                        ),
                      )
                    : const CabinIllustration(height: 180),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(_hPad, 8, _hPad, 0),
              child: Text(
                book.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            meta('Hyttebok · sist endret ${formatNorskDato(book.updatedAt)}'),
            if (book.intro.trim().isNotEmpty) markdown(book.intro),
          ],
          for (final cabin in vm.visibleCabins)
            ..._cabinBlocks(
              context,
              cabin,
              repo: repo,
              bookSlug: bookSlug,
              markdown: markdown,
              heading: heading,
              meta: meta,
            ),
        ],
      ),
    );
  }

  /// En hytte som dokumentblokk: navn, sted, beskrivelse, seksjoner (i
  /// eksportrekkefølge, også skjulte – tap-fri som PDF-en) og historier.
  List<Widget> _cabinBlocks(
    BuildContext context,
    Cabin cabin, {
    required BookRepository repo,
    required String bookSlug,
    required Widget Function(String) markdown,
    required Widget Function(String) heading,
    required Widget Function(String) meta,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final blocks = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(_hPad, 28, _hPad, 0),
        child: Text(
          cabin.name,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      if (cabin.location != null && cabin.location!.trim().isNotEmpty)
        meta(cabin.location!),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: scheme.outlineVariant),
      ),
    ];

    if (cabin.description.trim().isNotEmpty) {
      blocks.add(markdown(cabin.description));
    }

    // Tynn linje mellom seksjonene og historiene (ikke før den første
    // seksjonen – det er allerede en linje etter hyttens beskrivelse).
    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: scheme.outlineVariant),
    );

    var firstSection = true;
    for (final section in _exportSections(cabin)) {
      if (!firstSection) blocks.add(divider());
      firstSection = false;
      blocks.add(
        heading(
          section.title.trim().isEmpty ? 'Seksjon' : section.title.trim(),
        ),
      );
      if (section.markdown.trim().isNotEmpty) {
        blocks.add(markdown(section.markdown));
      }
      // Bilder som ikke allerede er inlinet i Markdown-en.
      for (final rel in section.images) {
        if (!section.markdown.contains(']($rel)')) {
          blocks.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _hPad),
              child: BookImage(repo: repo, bookSlug: bookSlug, src: rel),
            ),
          );
        }
      }
    }

    if (cabin.stories.isNotEmpty) {
      if (!firstSection || cabin.description.trim().isNotEmpty) {
        blocks.add(divider());
      }
      blocks.add(heading('Historier'));
      for (var i = 0; i < cabin.stories.length; i++) {
        if (i > 0) blocks.add(divider());
        blocks.add(
          _storyBlock(
            cabin.stories[i],
            repo: repo,
            bookSlug: bookSlug,
            markdown: markdown,
            meta: meta,
          ),
        );
      }
    }
    return blocks;
  }

  Widget _storyBlock(
    Story story, {
    required BookRepository repo,
    required String bookSlug,
    required Widget Function(String) markdown,
    required Widget Function(String) meta,
  }) {
    final blocks = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(_hPad, 12, _hPad, 0),
        child: Text(
          story.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      if (story.date != null ||
          (story.author != null && story.author!.trim().isNotEmpty))
        meta(
          [
            if (story.date != null) formatDate(story.date!),
            if (story.author != null && story.author!.trim().isNotEmpty)
              story.author!.trim(),
          ].join(' · '),
        ),
    ];
    if (story.markdown.trim().isNotEmpty) {
      blocks.add(markdown(story.markdown));
    }
    for (final rel in story.images) {
      if (!story.markdown.contains(']($rel)')) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _hPad),
            child: BookImage(repo: repo, bookSlug: bookSlug, src: rel),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  /// Faste rutine-seksjoner + ordinære tilleggsseksjoner (også skjulte), i
  /// samme rekkefølge som PDF-eksporten. Tomme seksjoner hoppes over.
  List<Section> _exportSections(Cabin cabin) {
    bool hasContent(Section s) =>
        s.markdown.trim().isNotEmpty || s.images.isNotEmpty;
    return [
      if (hasContent(cabin.startRoutines)) cabin.startRoutines,
      if (hasContent(cabin.stopRoutines)) cabin.stopRoutines,
      ...cabin.sections,
    ];
  }
}
