import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/format.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../domain/models/section.dart';
import '../../../domain/models/section_type.dart';
import '../../../domain/models/story.dart';
import '../../../ui/features/ai/structure_suggestion_dialog.dart';
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
    SectionType? sectionType,
  }) {
    return context.push<String>(
      '/editor',
      extra: EditorInput(
        title: title,
        initialValue: initial,
        bookSlug: bookSlug,
        hint: hint,
        sectionType: sectionType,
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

  /// AI foreslår en seksjonsstruktur basert på hyttebeskrivelsen; godkjente
  /// forslag blir vanlige seksjoner i boka.
  Future<void> _suggestStructure(
    BuildContext context,
    CabinViewModel vm,
  ) async {
    final cabin = vm.cabin;
    if (cabin == null) return;
    await showAiStructureDialog(
      context,
      description: cabin.description,
      onApprove: (suggestion) => vm.addSections(suggestion.sections),
    );
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

  /// En seksjonstile med kontekstmeny (flytt opp/ned, skjul/vis, slett).
  ///
  /// [onMove] må settes for å tillate omstilling; [index] og [count] gjelder
  /// innenom den synlige underlisten.
  Widget _sectionTile(
    Section section, {
    required int index,
    required int count,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    required VoidCallback onToggleHide,
    void Function(int delta)? onMove,
  }) {
    return Card(
      margin: _margin,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          section.hidden ? Icons.visibility_outlined : Icons.subject,
        ),
        title: Text(section.title),
        trailing: PopupMenuButton<String>(
          tooltip: 'Alternativer',
          onSelected: (value) {
            switch (value) {
              case 'opp':
                onMove?.call(-1);
              case 'ned':
                onMove?.call(1);
              case 'skjul':
                onToggleHide();
              case 'slett':
                onDelete();
            }
          },
          itemBuilder: (_) => [
            if (onMove != null && index > 0)
              const PopupMenuItem(value: 'opp', child: Text('Flytt opp')),
            if (onMove != null && index < count - 1)
              const PopupMenuItem(value: 'ned', child: Text('Flytt ned')),
            PopupMenuItem(
              value: 'skjul',
              child: Text(section.hidden ? 'Vis igjen' : 'Skjul'),
            ),
            const PopupMenuItem(value: 'slett', child: Text('Slett')),
          ],
        ),
      ),
    );
  }

  Future<void> _editSection(
    BuildContext context,
    CabinViewModel vm,
    Section section,
  ) async {
    final text = await _edit(
      context,
      title: section.title,
      initial: section.markdown,
      bookSlug: vm.bookSlug,
      sectionType: section.type,
    );
    if (text != null) await vm.updateSectionMarkdown(section.slug, text);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CabinViewModel>();
    final cabin = vm.cabin;

    if (vm.loading && cabin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hytte')),
        body: const SkeletonList(),
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

    final visibleSections = cabin.sections.where((s) => !s.hidden).toList();
    final hiddenSections = cabin.sections.where((s) => s.hidden).toList();

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
                sectionType: SectionType.startRoutines,
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
                sectionType: SectionType.stopRoutines,
              );
              if (text != null) await vm.updateStop(text);
            },
          ),

          _header('Seksjoner'),
          if (visibleSections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Ingen synlige seksjoner. Legg til en med +, eller vis igjen '
                'en skjult seksjon nedenfor.',
              ),
            )
          else
            for (var i = 0; i < visibleSections.length; i++)
              _sectionTile(
                visibleSections[i],
                index: i,
                count: visibleSections.length,
                onTap: () => _editSection(context, vm, visibleSections[i]),
                onDelete: () => _deleteSection(context, vm, visibleSections[i]),
                onToggleHide: () =>
                    vm.toggleHideSection(visibleSections[i].slug),
                onMove: (delta) =>
                    vm.moveSection(visibleSections[i].slug, delta),
              ),
          if (hiddenSections.isNotEmpty) ...[
            _header('Skjulte seksjoner'),
            for (final section in hiddenSections)
              _sectionTile(
                section,
                index: 0,
                count: 0,
                onTap: () => _editSection(context, vm, section),
                onDelete: () => _deleteSection(context, vm, section),
                onToggleHide: () => vm.toggleHideSection(section.slug),
              ),
          ],

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
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Foreslå struktur (AI)'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _suggestStructure(context, vm);
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
