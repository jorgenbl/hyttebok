import 'package:flutter_test/flutter_test.dart';

import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/in_memory_book_storage.dart';
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';
import 'package:hyttebok/ui/features/reader/reader_view_model.dart';

Book testBook() => Book(
  slug: 'sommehytta',
  title: 'Sommehytta',
  intro: 'Intro',
  updatedAt: DateTime(2026, 1, 1),
  cabins: [
    Cabin(
      slug: 'fjellhytta',
      name: 'Fjellhytta',
      order: 0,
      startRoutines: const Section(
        slug: 'start-rutiner',
        title: 'Åpne-rutiner',
        type: SectionType.startRoutines,
        order: 1,
      ),
      stopRoutines: const Section(
        slug: 'steng-rutiner',
        title: 'Steng-rutiner',
        type: SectionType.stopRoutines,
        order: 2,
      ),
    ),
    Cabin(
      slug: 'sjohytta',
      name: 'Sjøhytta',
      order: 1,
      startRoutines: const Section(
        slug: 'start-rutiner',
        title: 'Åpne-rutiner',
        type: SectionType.startRoutines,
        order: 1,
      ),
      stopRoutines: const Section(
        slug: 'steng-rutiner',
        title: 'Steng-rutiner',
        type: SectionType.stopRoutines,
        order: 2,
      ),
    ),
  ],
);

void main() {
  group('ReaderViewModel', () {
    late BookRepository repo;

    setUp(() async {
      final storage = InMemoryBookStorage();
      await storage.writeBook(testBook());
      repo = BookRepository(storage);
    });

    test('heibok: laster boka og viser alle hytter i rekkefølge', () async {
      final vm = ReaderViewModel(repo, 'sommehytta');
      expect(vm.loading, isTrue);

      await vm.load();

      expect(vm.loading, isFalse);
      expect(vm.bookNotFound, isFalse);
      expect(vm.book, isNotNull);
      expect(vm.cabin, isNull);
      expect(vm.visibleCabins.map((c) => c.slug).toList(), [
        'fjellhytta',
        'sjohytta',
      ]);
    });

    test(
      'én hytte: cabin velges og visibleCabins inneholder kun den',
      () async {
        final vm = ReaderViewModel(repo, 'sommehytta', cabinSlug: 'sjohytta');
        await vm.load();

        expect(vm.cabinNotFound, isFalse);
        expect(vm.cabin, isNotNull);
        expect(vm.cabin!.name, 'Sjøhytta');
        expect(vm.visibleCabins, hasLength(1));
        expect(vm.visibleCabins.single.slug, 'sjohytta');
      },
    );

    test('ugyldig bok-slug → bookNotFound', () async {
      final vm = ReaderViewModel(repo, 'finnes-ikke');
      await vm.load();

      expect(vm.bookNotFound, isTrue);
      expect(vm.visibleCabins, isEmpty);
    });

    test('ugyldig hytte-slug → cabinNotFound', () async {
      final vm = ReaderViewModel(repo, 'sommehytta', cabinSlug: 'finnes-ikke');
      await vm.load();

      expect(vm.bookNotFound, isFalse);
      expect(vm.cabinNotFound, isTrue);
      expect(vm.visibleCabins, isEmpty);
    });
  });
}
