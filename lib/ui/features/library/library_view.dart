import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/theme_preference.dart';
import '../../../core/errors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/services/file_picker_service.dart';
import 'library_view_model.dart';

/// Biblioteket: listen med hyttebøker.
class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<BookRepository>();
    return ChangeNotifierProvider(
      create: (_) => LibraryViewModel(repo)..load(),
      child: const _LibraryBody(),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody();

  Future<void> _newBook(BuildContext context) async {
    final vm = context.read<LibraryViewModel>();
    final title = await showTextInputDialog(
      context,
      title: 'Ny hyttebok',
      label: 'Navn på boka',
      hint: 'f.eks. Sommehytta',
    );
    if (title == null) return;
    final slug = await vm.createBook(title);
    if (context.mounted) context.go('/book/$slug');
  }

  Future<void> _delete(
    BuildContext context,
    LibraryViewModel vm,
    String slug,
    String title,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Slett bok',
      message: 'Slette «$title»? Dette kan ikke angres.',
    );
    if (ok) await vm.deleteBook(slug);
  }

  /// Plukker en fil (`.md` eller `.zip`) og importerer den som en ny bok.
  ///
  /// Filen leses som byteer (ingen filsystem-sti) slik at det fungerer like
  /// godt på web som på mobil.
  Future<void> _importBook(BuildContext context, LibraryViewModel vm) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await context.read<FilePickerService>().pickBookFile();
    if (picked == null || !context.mounted) return;
    try {
      final slug = await vm.importBook(picked.name, picked.bytes);
      if (context.mounted) context.go('/book/$slug');
    } on InvalidBookFile catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke importere boken.')),
      );
    }
  }

  /// Banner for web: bøkene ligger i minnet under økten, ikke på disk.
  Widget _webSessionBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Web-versjonen lagrer bøkene i minnet under økten – de forsvinner '
              'når fanen stenges. Bruk «Del / eksporter» for å ta en bok med '
              'deg, og importer den på nytt senere.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeMenu(BuildContext context) => PopupMenuButton<ThemeMode>(
    icon: const Icon(Icons.brightness_6_outlined),
    tooltip: 'Tema',
    onSelected: (mode) => context.read<ThemePreference>().setMode(mode),
    itemBuilder: (context) {
      final current = context.read<ThemePreference>().mode;
      return [
        _themeItem(ThemeMode.system, 'Følg system', current),
        _themeItem(ThemeMode.light, 'Lyst tema', current),
        _themeItem(ThemeMode.dark, 'Mørkt tema', current),
      ];
    },
  );

  PopupMenuEntry<ThemeMode> _themeItem(
    ThemeMode value,
    String label,
    ThemeMode current,
  ) {
    final selected = value == current;
    return PopupMenuItem<ThemeMode>(
      value: value,
      child: Row(
        children: [
          Icon(selected ? Icons.check : Icons.radio_button_unchecked, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LibraryViewModel>();
    final books = vm.books;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hyttebøker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Innstillinger',
            onPressed: () => context.push('/settings'),
          ),
          _themeMenu(context),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Importer bok',
            onPressed: () => _importBook(context, vm),
          ),
        ],
      ),
      body: Column(
        children: [
          if (kIsWeb) _webSessionBanner(context),
          Expanded(
            child: vm.loading && books.isEmpty
                ? const SkeletonList()
                : books.isEmpty
                ? const EmptyState(
                    icon: Icons.menu_book,
                    message:
                        'Ingen hyttebøker ennå.\nTrykk på + for å opprette din '
                        'første bok.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final meta = books[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          onTap: () => context.push('/book/${meta.slug}'),
                          onLongPress: () =>
                              _delete(context, vm, meta.slug, meta.title),
                          leading: const Icon(Icons.menu_book),
                          title: Text(meta.title),
                          subtitle: Text(
                            'Sist endret ${formatDate(meta.updatedAt)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newBook(context),
        tooltip: 'Ny bok',
        child: const Icon(Icons.add),
      ),
    );
  }
}
