import '../../core/utils/list_equals.dart';

/// En historie / gjestebok-innlegg under en hytte.
class Story {
  const Story({
    required this.slug,
    required this.title,
    this.date,
    this.author,
    this.markdown = '',
    this.images = const [],
    this.order = 0,
  });

  final String slug;
  final String title;
  final DateTime? date;
  final String? author;

  /// Brødtekst i Markdown.
  final String markdown;

  /// Relativer stier til bilder (relatert til boka).
  final List<String> images;

  /// Manuel rekkefølge.
  final int order;

  Story copyWith({
    String? slug,
    String? title,
    DateTime? date,
    String? author,
    String? markdown,
    List<String>? images,
    int? order,
  }) {
    return Story(
      slug: slug ?? this.slug,
      title: title ?? this.title,
      date: date ?? this.date,
      author: author ?? this.author,
      markdown: markdown ?? this.markdown,
      images: images ?? this.images,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Story) return false;
    return other.slug == slug &&
        other.title == title &&
        other.date == date &&
        other.author == author &&
        other.markdown == markdown &&
        listEquals(other.images, images) &&
        other.order == order;
  }

  @override
  int get hashCode => Object.hash(
        slug,
        title,
        date,
        author,
        markdown,
        Object.hashAll(images),
        order,
      );

  @override
  String toString() => 'Story(slug: $slug, title: $title, date: $date)';
}
