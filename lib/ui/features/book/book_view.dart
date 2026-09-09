import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/errors.dart';
import '../../../core/io/file_export.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/services/share_service.dart';
import '../../../domain/models/cabin.dart';
import '../../../domain/templates/cabin_template.dart';
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

  /// Oppretter en hytte fra mal (Fase 3): full struktur med ledetekst.
  Future<void> _newCabinFromTemplate(
    BuildContext context,
    BookViewModel vm,
  ) async {
    final templates = context.read<List<CabinTemplate>>();
    final template = templates.isNotEmpty
        ? templates.first
        : standardCabinTemplate;
    final name = await showTextInputDialog(
      context,
      title: 'Ny hytte fra mal',
      label: 'Navn på hytta',
      hint: 'f.eks. Fjellhytta, Røros',
    );
    if (name == null || !context.mounted) return;
    final location = await showTextInputDialog(
      context,
      title: 'Ny hytte fra mal',
      label: 'Sted (valgfritt)',
      hint: 'f.eks. Røros, 638 m.o.h.',
    );
    if (!context.mounted) return;
    final cabinSlug = await vm.createCabinFromTemplate(
      template,
      name: name,
      location: location,
    );
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

  /// Eksporterer boka (én `.md`-fil eller `.zip`). [zip] velger format.
  ///
  /// Mobil: filen skrives til temp og åpnes i delingsmenyen.
  /// Web: filen lastes ned i nettleseren.
  Future<void> _shareAs(
    BuildContext context,
    BookViewModel vm, {
    required bool zip,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<BookRepository>();
    final share = context.read<ShareService>();
    final title = vm.book?.title ?? 'Hyttebok';
    final ext = zip ? 'zip' : 'md';
    final name = _exportFileName(title, ext);
    try {
      final bytes = zip
          ? await repo.exportZipBytes(vm.slug)
          : await repo.exportSingleFileBytes(vm.slug);
      if (kIsWeb) {
        downloadBytes(name, bytes);
        messenger.showSnackBar(
          SnackBar(content: Text('Boken ble lastet ned som $name.')),
        );
      } else {
        final path = await writeExportFile(name, bytes);
        final shared = await share.shareFile(path, subject: title);
        if (shared) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Boken er delt.')),
          );
        }
      }
    } on InvalidBookFile catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke dele boken.')),
      );
    }
  }

  /// Filsystem-trygt filnavn fra en tittel.
  static String _exportFileName(String title, String ext) {
    var name = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) name = 'bok';
    return '$name.$ext';
  }

  /// Eksporterer boka til PDF og åpner plattformens utskriftsdialog (F18) –
  /// der kan brukeren skrive ut, lagre PDF eller dele den.
  Future<void> _exportPdf(BuildContext context, BookViewModel vm) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<BookRepository>();
    final title = vm.book?.title ?? 'Hyttebok';
    try {
      // [Printing.layoutPdf] kaller [onLayout] (eventuelt flere ganger ved
      // endret format/retning); PDF-en bygges på nytt per layout.
      await Printing.layoutPdf(
        name: title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_'),
        onLayout: (format) => repo.exportPdfBytes(vm.slug, pageFormat: format),
      );
    } on InvalidBookFile catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kunne ikke lage PDF av boken.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookViewModel>();
    final book = vm.book;

    if (vm.loading && book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hyttebok')),
        body: const SkeletonList(),
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
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Søk i boka',
            onPressed: () => context.push('/book/${vm.slug}/search'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.share),
            tooltip: 'Del / eksporter',
            onSelected: (value) {
              if (value == 'md') {
                _shareAs(context, vm, zip: false);
              } else if (value == 'zip') {
                _shareAs(context, vm, zip: true);
              } else if (value == 'pdf') {
                _exportPdf(context, vm);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'md', child: Text('Del som Markdown (.md)')),
              PopupMenuItem(value: 'zip', child: Text('Del som mappe (.zip)')),
              PopupMenuItem(value: 'pdf', child: Text('Eksporter som PDF')),
            ],
          ),
        ],
      ),
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
        tooltip: 'Ny hytte',
        child: const Icon(Icons.add),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_home_outlined),
                  title: const Text('Ny hytte'),
                  subtitle: const Text('Tom hytte'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _newCabin(context, vm);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_fix_high),
                  title: const Text('Ny hytte fra mal'),
                  subtitle: const Text('Komplett struktur med ledetekst'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _newCabinFromTemplate(context, vm);
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
