import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/slug.dart';
import '../../../core/utils/swipe_delete.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/cabin.dart';
import '../../../domain/models/section.dart';
import '../../../domain/models/section_type.dart';
import '../../../domain/templates/cabin_template.dart';

/// Tilstand og kommandoer for én bok (forside + listen med hytter).
class BookViewModel extends ChangeNotifier {
  BookViewModel(this._repo, this.slug);

  final BookRepository _repo;
  final String slug;

  Book? _book;
  bool _loading = false;

  /// Hytter som er sveipet bort, men ikke fysisk slettet ennå. Dataene er
  /// intakte inntil tidsvinduet går ut uten at brukeren angret.
  final Map<String, Timer> _pendingCabinDeletes = {};

  Book? get book => _book;
  bool get loading => _loading;

  /// Hyttene som fortsatt vises (ikke sveipet bort).
  List<Cabin> get activeCabins =>
      _book?.cabins
          .where((c) => !_pendingCabinDeletes.containsKey(c.slug))
          .toList() ??
      const [];

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _book = await _repo.load(slug);
    } catch (_) {
      _book = null;
    }
    _loading = false;
    notifyListeners();
  }

  /// Oppretter en ny (tom) hytte i boka og returnerer slug.
  Future<String> createCabin(String name) async {
    final b = _book!;
    final slug = _uniqueCabinSlug(name, b);
    final cabin = Cabin(
      slug: slug,
      name: name,
      order: b.cabins.length,
      startRoutines: Section(
        slug: 'start-rutiner',
        title: 'Åpne-rutiner',
        type: SectionType.startRoutines,
        order: 1,
      ),
      stopRoutines: Section(
        slug: 'steng-rutiner',
        title: 'Steng-rutiner',
        type: SectionType.stopRoutines,
        order: 2,
      ),
    );
    await _save(b.copyWith(cabins: [...b.cabins, cabin]));
    return slug;
  }

  /// Oppretter en ny hytte fra en [template] (Fase 3): beskrivelse, rutiner og
  /// alle seksjoner fylles med malens ledetekst. Returnerer slug.
  Future<String> createCabinFromTemplate(
    CabinTemplate template, {
    required String name,
    String? location,
  }) async {
    final b = _book!;
    final slug = _uniqueCabinSlug(name, b);
    final cabin = cabinFromTemplate(
      template,
      name: name,
      slug: slug,
      location: (location == null || location.trim().isEmpty)
          ? null
          : location.trim(),
      order: b.cabins.length,
    );
    await _save(b.copyWith(cabins: [...b.cabins, cabin]));
    return slug;
  }

  /// Gir et unikt slug for en ny hytte basert på [name].
  String _uniqueCabinSlug(String name, Book b) {
    var base = slugify(name);
    if (base.isEmpty) base = 'hytte';
    var candidate = base;
    var i = 2;
    final existing = b.cabins.map((c) => c.slug).toSet();
    while (existing.contains(candidate)) {
      candidate = '$base-$i';
      i++;
    }
    return candidate;
  }

  Future<void> deleteCabin(String cabinSlug) async {
    final b = _book!;
    await _save(
      b.copyWith(cabins: b.cabins.where((c) => c.slug != cabinSlug).toList()),
    );
  }

  /// Sveip-sletting: hytta forsvinner fra listen med det samme, men
  /// slettes ikke fysisk før tidsvinduet er passert uten at
  /// [cancelSwipeDeleteCabin] kalles.
  void swipeDeleteCabin(String cabinSlug) {
    _pendingCabinDeletes[cabinSlug]?.cancel();
    _pendingCabinDeletes[cabinSlug] = Timer(swipeDeleteCommitDelay, () {
      _pendingCabinDeletes.remove(cabinSlug);
      notifyListeners();
      if (_book != null) unawaited(deleteCabin(cabinSlug));
    });
    notifyListeners();
  }

  /// Angrer en pågående sveip-sletting: hytta dukker tilbake opp, og
  /// ingenting er slettet.
  void cancelSwipeDeleteCabin(String cabinSlug) {
    _pendingCabinDeletes.remove(cabinSlug)?.cancel();
    notifyListeners();
  }

  Future<void> updateIntro(String markdown) async {
    final b = _book!;
    await _save(b.copyWith(intro: markdown));
  }

  /// Setter et omslagsbilde (relativ sti i boken, f.eks. `images/…`).
  Future<void> setCoverImage(String src) async {
    final b = _book!;
    await _save(b.copyWith(coverImage: src));
  }

  /// Fjerner omslagsbildet (boka bruker da tegnet hyttemotiv).
  Future<void> removeCoverImage() async {
    final b = _book!;
    if (b.coverImage == null) return;
    await _save(b.copyWith(coverImage: null));
  }

  Future<void> _save(Book updated) async {
    await _repo.save(updated.copyWith(updatedAt: DateTime.now()));
    await load();
  }
}
