import '../../core/utils/list_equals.dart';
import 'section_type.dart';

/// En fritekst-seksjon med Markdown og valgfrie bilder.
///
/// Dette er brikken som lager opp en hytte: start-/steng-rutiner, beskrivelse,
/// notater, medier osv. [type] er et hjelp for UI/maler, men [egen] gir fri struktur.
class Section {
  const Section({
    required this.slug,
    required this.title,
    this.markdown = '',
    this.images = const [],
    this.type = SectionType.egen,
    this.order = 0,
  });

  final String slug;
  final String title;

  /// Brødtekst i Markdown.
  final String markdown;

  /// Relativer stier til bilder (relatert til boka, f.eks. `images/foo.jpg`).
  final List<String> images;

  final SectionType type;

  /// Manuel rekkefølge (større = lenger nede).
  final int order;

  Section copyWith({
    String? slug,
    String? title,
    String? markdown,
    List<String>? images,
    SectionType? type,
    int? order,
  }) {
    return Section(
      slug: slug ?? this.slug,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      images: images ?? this.images,
      type: type ?? this.type,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Section) return false;
    return other.slug == slug &&
        other.title == title &&
        other.markdown == markdown &&
        listEquals(other.images, images) &&
        other.type == type &&
        other.order == order;
  }

  @override
  int get hashCode =>
      Object.hash(slug, title, markdown, Object.hashAll(images), type, order);

  @override
  String toString() => 'Section(slug: $slug, title: $title, type: $type)';
}
