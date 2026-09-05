/// Formaterer en dato til `YYYY-MM-DD`.
String formatDate(DateTime d) {
  String p2(int x) => x.toString().padLeft(2, '0');
  return '${d.year}-${p2(d.month)}-${p2(d.day)}';
}
