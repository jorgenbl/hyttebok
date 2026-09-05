import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../domain/models/cabin.dart';
import '../../../ui/features/editor/editor.dart';
import 'book_view_model.dart';

/// Oversikt over én bok: forside + listen med hytter.
class BookView extends StatelessWidget {
  const BookView({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<BookRepository>();
    return ChangeNotifierProvider(
      create: (_) => BookViewModel(repo, slug)..load(),
      child: const _BookBody(),
    );
  }
}

class _BookBody extends StatelessWidget {
  const _BookBody();

  static const _margin = EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  Future<void> _editIntro(BuildContext context, BookViewModel vm) async {
    final book = vm.book;
    if (book == null) return;
    final text = await context.push<String>(
      '/editor',
      extra: EditorInput(
        title: 'Forsiden',
        initialValue: book.intro,
        bookSlug: vm.slug,
        hint: 'Skriv en kort introduksjon om boka…',
      ),
    );
    if (text != null) await vm.updateIntro(text);
  }

  Future<void> _newCabin(BuildContext context, BookViewModel vm) async {
    final name = await showTextInputDialog(
      context,
      title: 'Ny hytte',
      label: 'Navn på hytta',
      hint: 'f.eks. Fjellhytta, Røros',
    );
    if (name == null) return;
    final cabinSlug = await vm.createCabin(name);
    if (context.mounted) context.go('/book/${vm.slug}/cabin/$cabinSlug');
  }

  Future<void> _deleteCabin(
    BuildContext context,
    BookViewModel vm,
    Cabin cabin,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Slett hytte',
      message: 'Slette «${cabin.name}» og alt innholdet?',
    );
    if (ok) await vm.deleteCabin(cabin.slug);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookViewModel>();
    final book = vm.book;

    if (vm.loading && book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hyttebok')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hyttebok')),
        body: const EmptyState(
          icon: Icons.error_outline,
          message: 'Boken ble ikke funnet.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Card(
            margin: _margin,
            child: ListTile(
              onTap: () => _editIntro(context, vm),
              leading: const Icon(Icons.description),
              title: const Text('Forsiden / intro'),
              subtitle: const Text('Klikk for å redigere'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Hytter',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (book.cabins.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Ingen hytter i denne boka ennå.'),
            )
          else
            for (final cabin in book.cabins)
              Card(
                margin: _margin,
                child: ListTile(
                  onTap: () =>
                      context.push('/book/${vm.slug}/cabin/${cabin.slug}'),
                  onLongPress: () => _deleteCabin(context, vm, cabin),
                  leading: const Icon(Icons.home),
                  title: Text(cabin.name),
                  subtitle: cabin.location != null
                      ? Text(cabin.location!)
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newCabin(context, vm),
        tooltip: 'Ny hytte',
        child: const Icon(Icons.add),
      ),
    );
  }
}
