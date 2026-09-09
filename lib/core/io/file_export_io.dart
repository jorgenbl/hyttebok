import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Mobil: skriver en eksportert fil til `hyttebok-eksport/` i systemtemp
/// og returnerer absolutt sti (delingsmenyen trenger en ekte fil).
Future<String> writeExportFile(String filename, Uint8List bytes) async {
  final dir = Directory(
    p.join((await getTemporaryDirectory()).path, 'hyttebok-eksport'),
  );
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, filename));
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Kaldes aldri på mobil (kun web) – holder interfacet samlet.
void downloadBytes(String filename, Uint8List bytes) {
  throw UnimplementedError('downloadBytes er kun tilgjengelig på web.');
}
