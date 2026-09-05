/// Omformer en tittel til et stabilt, URL-vennlig slug (mappe/filnavn).
///
/// Fjerner spesialtegn, folder norske bokstaver til ASCII og bruker
/// minustegn som skille. Eksempel: `Fjellhytta, Røros` → `fjellhytta-roros`.
String slugify(String input) {
  var s = input.trim().toLowerCase();
  s = s
      .replaceAll('å', 'a')
      .replaceAll('æ', 'ae')
      .replaceAll('ø', 'o')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'-{2,}'), '-');
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');
  return s;
}
