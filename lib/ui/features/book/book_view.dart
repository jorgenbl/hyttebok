import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show ImageSource, XFile;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/errors.dart';
import '../../../core/io/file_export.dart';
import '../../../core/utils/swipe_delete.dart';
import '../../../core/widgets/book_image.dart';
import '../../../core/widgets/cabin_illustration.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/services/image_picker_service.dart';
import '../../../data/services/share_service.dart';
import '../../../domain/models/book.dart';
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
    // push (ikke go): boka skal ligge i historien slik at tilbake-knappen
    // fungerer når hytta er åpen.
    if (context.mounted) context.push('/book/${vm.slug}/cabin/$cabinSlug');
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
    // push (ikke go): boka skal ligge i historien slik at tilbake-knappen
    // fungerer når hytta er åpen.
    if (context.mounted) context.push('/book/${vm.slug}/cabin/$cabinSlug');
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

  /// Sveip-sletting: hytta forsvinner med det samme, men brukeren har
  /// [swipeDeleteWindow] på seg til å angre – da er ingenting slettet ennå.
  void _swipeDeleteCabin(BuildContext context, BookViewModel vm, Cabin cabin) {
    final messenger = ScaffoldMessenger.of(context);
    vm.swipeDeleteCabin(cabin.slug);
    messenger.showSnackBar(
      SnackBar(
        content: Text('«${cabin.name}» slettes om et øyeblikk.'),
        duration: swipeDeleteWindow,
        action: SnackBarAction(
          label: 'Angre',
          onPressed: () => vm.cancelSwipeDeleteCabin(cabin.slug),
        ),
      ),
    );
  }

  /// Rød bakgrunn med slette-ikon bak kortet under sveiping.
  Widget _swipeBackground(BuildContext context, EdgeInsets margin) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      color: scheme.error,
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  /// Bokens «omslag»: valgfritt omslagsbilde, ellers tegnet hyttemotiv.
  /// Ikkonen øverst til høyre bytter/fjerner omslag.
  Widget _cover(BuildContext context, BookViewModel vm, Book book) {
    final repo = context.read<BookRepository>();
    final src = book.coverImage;
    return Card(
      margin: _margin,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 180,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (src != null)
              BookImage(repo: repo, bookSlug: vm.slug, src: src)
            else
              const CabinIllustration(),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Omslag',
                icon: const Icon(Icons.photo_outlined),
                color: Theme.of(context).colorScheme.onSurface,
                onPressed: () => _coverMenu(context, vm, book),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _coverMenu(
    BuildContext context,
    BookViewModel vm,
    Book book,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Endre omslag'),
              onTap: () => Navigator.pop(sheetContext, 'endre'),
            ),
            if (book.coverImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Fjern omslag'),
                onTap: () => Navigator.pop(sheetContext, 'fjern'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'fjern') {
      await vm.removeCoverImage();
      return;
    }
    await _changeCover(context, vm);
  }

  /// Plukker et bilde (kamera/galleri), lagrer det i boken og gjør det til
  /// omslaget.
  Future<void> _changeCover(BuildContext context, BookViewModel vm) async {
    final repo = context.read<BookRepository>();
    final service = context.read<ImagePickerService>();
    final messenger = ScaffoldMessenger.of(context);
    ImageSource? source;
    if (!kIsWeb) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Ta bilde'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Fra galleri'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    } else {
      source = ImageSource.gallery;
    }
    if (source == null || !context.mounted) return;
    final XFile? file = source == ImageSource.camera
        ? await service.takePhoto()
        : await service.pickFromGallery();
    if (file == null || !context.mounted) return;
    try {
      final relative = await repo.importImage(vm.slug, file);
      if (!context.mounted) return;
      await vm.setCoverImage(relative);
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Kunne ikke lagre omslaget.')),
        );
      }
    }
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
            icon: const Icon(Icons.menu_book),
            tooltip: 'Les boka',
            onPressed: () => context.push('/book/${vm.slug}/read'),
          ),
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
          _cover(context, vm, book),
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
          if (vm.activeCabins.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Ingen hytter i denne boka ennå.'),
            )
          else
            for (final cabin in vm.activeCabins)
              Dismissible(
                key: ValueKey('hytte-${cabin.slug}'),
                direction: DismissDirection.endToStart,
                background: _swipeBackground(context, _margin),
                onDismissed: (_) => _swipeDeleteCabin(context, vm, cabin),
                child: Card(
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
