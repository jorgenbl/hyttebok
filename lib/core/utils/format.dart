/// Formaterer en dato til `YYYY-MM-DD`.
String formatDate(DateTime d) {
  String p2(int x) => x.toString().padLeft(2, '0');
  return '${d.year}-${p2(d.month)}-${p2(d.day)}';
}

/// Formaterer en dato på norsk, f.eks. `14. september 2026`.
String formatNorskDato(DateTime d) {
  const months = [
    'januar',
    'februar',
    'mars',
    'april',
    'mai',
    'juni',
    'juli',
    'august',
    'september',
    'oktober',
    'november',
    'desember',
  ];
  final day = d.day.toString().padLeft(2, '0');
  return '$day. ${months[d.month - 1]} ${d.year}';
}
