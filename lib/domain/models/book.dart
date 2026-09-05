import '../../core/utils/list_equals.dart';
import 'cabin.dart';

/// En hyttebok – én mappe med Markdown + bilder.
///
/// [slug] er mappenavn (f.eks. `sommehytta`). [intro] er forsiden
/// (brødtekst i `book.md`). [cabins] inneholder én eller flere hytter.
class Book {
  const Book({
    required this.slug,
    required this.title,
    this.intro = '',
    this.coverImage,
    this.cabins = const [],
    required this.updatedAt,
  });

  final String slug;
  final String title;

  /// Forsiden / introduksjon (Markdown) – brødtekst i `book.md`.
  final String intro;

  /// Relativ sti til coverbilde (f.eks. `images/fasade.png`), om noe.
  final String? coverImage;

  final List<Cabin> cabins;

  /// Når boken sist ble endret (lagres i `book.md`-frontmatter).
  final DateTime updatedAt;

  Book copyWith({
    String? slug,
    String? title,
    String? intro,
    String? coverImage,
    List<Cabin>? cabins,
    DateTime? updatedAt,
  }) {
    return Book(
      slug: slug ?? this.slug,
      title: title ?? this.title,
      intro: intro ?? this.intro,
      coverImage: coverImage ?? this.coverImage,
      cabins: cabins ?? this.cabins,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Book) return false;
    return other.slug == slug &&
        other.title == title &&
        other.intro == intro &&
        other.coverImage == coverImage &&
        other.updatedAt == updatedAt &&
        listEquals(other.cabins, cabins);
  }

  @override
  int get hashCode => Object.hash(
    slug,
    title,
    intro,
    coverImage,
    Object.hashAll(cabins),
    updatedAt,
  );

  @override
  String toString() =>
      'Book(slug: $slug, title: $title, cabins: ${cabins.length})';
}
