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
    this.hidden = false,
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

  /// Om seksjonen skal skjules fra den vanlige seksjonslisten i appen.
  ///
  /// Skjulte seksjoner beholdes i lagringen og i eksporten (tap-fri), men vises
  /// under et eget «Skjulte»-område i UI slik at brukeren kan gjenopprette dem.
  final bool hidden;

  Section copyWith({
    String? slug,
    String? title,
    String? markdown,
    List<String>? images,
    SectionType? type,
    int? order,
    bool? hidden,
  }) {
    return Section(
      slug: slug ?? this.slug,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      images: images ?? this.images,
      type: type ?? this.type,
      order: order ?? this.order,
      hidden: hidden ?? this.hidden,
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
        other.order == order &&
        other.hidden == hidden;
  }

  @override
  int get hashCode => Object.hash(
    slug,
    title,
    markdown,
    Object.hashAll(images),
    type,
    order,
    hidden,
  );

  @override
  String toString() => 'Section(slug: $slug, title: $title, type: $type)';
}
