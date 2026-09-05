import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/format.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../domain/models/section.dart';
import '../../../domain/models/story.dart';
import '../../../ui/features/editor/editor.dart';
import 'cabin_view_model.dart';

/// Detalj for én hytte: navn/sted, beskrivelse, rutiner, seksjoner, historier.
class CabinView extends StatelessWidget {
  const CabinView({super.key, required this.bookSlug, required this.cabinSlug});

  final String bookSlug;
  final String cabinSlug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<BookRepository>();
    return ChangeNotifierProvider(
      create: (_) => CabinViewModel(repo, bookSlug, cabinSlug)..load(),
      child: const _CabinBody(),
    );
  }
}

class _CabinBody extends StatelessWidget {
  const _CabinBody();

  static const _margin = EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  Future<String?> _edit(
    BuildContext context, {
    required String title,
    required String initial,
    required String bookSlug,
    String? hint,
  }) {
    return context.push<String>(
      '/editor',
      extra: EditorInput(
        title: title,
        initialValue: initial,
        bookSlug: bookSlug,
        hint: hint,
      ),
    );
  }

  Future<void> _addSection(BuildContext context, CabinViewModel vm) async {
    final title = await showTextInputDialog(
      context,
      title: 'Ny seksjon',
      label: 'Navn',
      hint: 'f.eks. Ved & peis',
    );
    if (title == null) return;
    await vm.addSection(title);
  }

  Future<void> _addStory(BuildContext context, CabinViewModel vm) async {
    final title = await showTextInputDialog(
      context,
      title: 'Ny historie',
      label: 'Tittel',
      hint: 'f.eks. Første jul',
    );
    if (title == null || !context.mounted) return;
    final author = await showTextInputDialog(
      context,
      title: 'Ny historie',
      label: 'Forfatter (valgfritt)',
    );
    await vm.addStory(
      title,
      author: (author == null || author.isEmpty) ? null : author,
    );
  }

  Future<void> _deleteSection(
    BuildContext context,
    CabinViewModel vm,
    Section section,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Slett seksjon',
      message: 'Slette «${section.title}»?',
    );
    if (ok) await vm.deleteSection(section.slug);
  }

  Future<void> _deleteStory(
    BuildContext context,
    CabinViewModel vm,
    Story story,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Slett historie',
      message: 'Slette «${story.title}»?',
    );
    if (ok) await vm.deleteStory(story.slug);
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    VoidCallback? onDelete,
  }) {
    return Card(
      margin: _margin,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CabinViewModel>();
    final cabin = vm.cabin;

    if (vm.loading && cabin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hytte')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (cabin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hytte')),
        body: const EmptyState(
          icon: Icons.error_outline,
          message: 'Hytten ble ikke funnet.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(cabin.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _tile(
            icon: Icons.edit_outlined,
            title: 'Navn',
            subtitle: cabin.name,
            onTap: () async {
              final name = await showTextInputDialog(
                context,
                title: 'Navn på hytta',
                label: 'Navn',
                initialValue: cabin.name,
              );
              if (name != null) await vm.rename(name);
            },
          ),
          _tile(
            icon: Icons.place_outlined,
            title: 'Sted',
            subtitle: cabin.location ?? '–',
            onTap: () async {
              final loc = await showTextInputDialog(
                context,
                title: 'Sted',
                label: 'Sted / koordinater',
                initialValue: cabin.location ?? '',
              );
              if (loc != null) await vm.setLocation(loc);
            },
          ),
          _tile(
            icon: Icons.description,
            title: 'Beskrivelse',
            subtitle: 'Klikk for å redigere',
            onTap: () async {
              final text = await _edit(
                context,
                title: 'Beskrivelse',
                initial: cabin.description,
                bookSlug: vm.bookSlug,
                hint: 'Beskriv hytta…',
              );
              if (text != null) await vm.updateDescription(text);
            },
          ),
          _tile(
            icon: Icons.play_circle,
            title: 'Åpne-rutiner',
            subtitle: 'Klikk for å redigere',
            onTap: () async {
              final text = await _edit(
                context,
                title: 'Åpne-rutiner',
                initial: cabin.startRoutines.markdown,
                bookSlug: vm.bookSlug,
                hint: '- [ ] oppgave',
              );
              if (text != null) await vm.updateStart(text);
            },
          ),
          _tile(
            icon: Icons.stop_circle,
            title: 'Steng-rutiner',
            subtitle: 'Klikk for å redigere',
            onTap: () async {
              final text = await _edit(
                context,
                title: 'Steng-rutiner',
                initial: cabin.stopRoutines.markdown,
                bookSlug: vm.bookSlug,
                hint: '- [ ] oppgave',
              );
              if (text != null) await vm.updateStop(text);
            },
          ),

          _header('Seksjoner'),
          if (cabin.sections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Ingen tilleggsseksjoner.'),
            )
          else
            for (final section in cabin.sections)
              _tile(
                icon: Icons.subject,
                title: section.title,
                onTap: () async {
                  final text = await _edit(
                    context,
                    title: section.title,
                    initial: section.markdown,
                    bookSlug: vm.bookSlug,
                  );
                  if (text != null) {
                    await vm.updateSectionMarkdown(section.slug, text);
                  }
                },
                onDelete: () => _deleteSection(context, vm, section),
              ),

          _header('Historier'),
          if (cabin.stories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Ingen historier ennå.'),
            )
          else
            for (final story in cabin.stories)
              _tile(
                icon: Icons.book,
                title: story.title,
                subtitle: [
                  if (story.date != null) formatDate(story.date!),
                  if (story.author != null) story.author!,
                ].where((s) => s.isNotEmpty).join(' · '),
                onTap: () async {
                  final text = await _edit(
                    context,
                    title: story.title,
                    initial: story.markdown,
                    bookSlug: vm.bookSlug,
                  );
                  if (text != null) {
                    await vm.updateStoryMarkdown(story.slug, text);
                  }
                },
                onDelete: () => _deleteStory(context, vm, story),
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Legg til',
        child: const Icon(Icons.add),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.subject),
                  title: const Text('Ny seksjon'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _addSection(context, vm);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.book),
                  title: const Text('Ny historie'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _addStory(context, vm);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
