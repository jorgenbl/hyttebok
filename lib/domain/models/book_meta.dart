/// Lettviktig oversikt over en bok – brukt i lister uten å lese hele innholdet.
class BookMeta {
  const BookMeta({
    required this.slug,
    required this.title,
    required this.updatedAt,
  });

  final String slug;
  final String title;
  final DateTime updatedAt;

  @override
  String toString() => 'BookMeta(slug: $slug, title: $title)';
}
