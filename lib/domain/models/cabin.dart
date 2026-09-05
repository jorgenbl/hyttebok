import '../../core/utils/list_equals.dart';
import 'section.dart';
import 'story.dart';

/// Én hytte i en bok.
///
/// [description] er hyttens hovedbeskrivelse (lagres som brødtekst i `cabin.md`).
/// [startRoutines]/[stopRoutines] er de faste rutine-seksjonene; [sections] er
/// ordinære, ordnede tilleggsseksjoner; [stories] er historier/gjestebok.
class Cabin {
  const Cabin({
    required this.slug,
    required this.name,
    this.location,
    this.description = '',
    required this.startRoutines,
    required this.stopRoutines,
    this.sections = const [],
    this.stories = const [],
    this.order = 0,
  });

  final String slug;
  final String name;
  final String? location;

  /// Hovedbeskrivelse (Markdown) – brødtekst i `cabin.md`.
  final String description;

  final Section startRoutines;
  final Section stopRoutines;

  /// Ordinære tilleggsseksjoner (notater, medier, tips …).
  final List<Section> sections;

  final List<Story> stories;

  /// Manuel rekkefølge blant hytter i boka.
  final int order;

  Cabin copyWith({
    String? slug,
    String? name,
    String? location,
    String? description,
    Section? startRoutines,
    Section? stopRoutines,
    List<Section>? sections,
    List<Story>? stories,
    int? order,
  }) {
    return Cabin(
      slug: slug ?? this.slug,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.description,
      startRoutines: startRoutines ?? this.startRoutines,
      stopRoutines: stopRoutines ?? this.stopRoutines,
      sections: sections ?? this.sections,
      stories: stories ?? this.stories,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Cabin) return false;
    return other.slug == slug &&
        other.name == name &&
        other.location == location &&
        other.description == description &&
        other.startRoutines == startRoutines &&
        other.stopRoutines == stopRoutines &&
        listEquals(other.sections, sections) &&
        listEquals(other.stories, stories) &&
        other.order == order;
  }

  @override
  int get hashCode => Object.hash(
        slug,
        name,
        location,
        description,
        startRoutines,
        stopRoutines,
        Object.hashAll(sections),
        Object.hashAll(stories),
        order,
      );

  @override
  String toString() => 'Cabin(slug: $slug, name: $name)';
}
