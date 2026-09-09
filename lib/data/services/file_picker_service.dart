import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Et plukket fil, avkjøpt fra `file_picker`'s plattformspecifikke
/// `PlatformFile`, slik at øvrig kode ikke avhenger av plugin-typen.
class PickedBookFile {
  const PickedBookFile({required this.name, required this.bytes});

  /// Filnavn med endelse (f.eks. `sommehytta.md`).
  final String name;

  /// Filt innhold. Byte-basert (ikke sti) slik at det fungerer like godt
  /// på web, der plukkede filer ikke har en lokal sti.
  final Uint8List bytes;
}

/// Tynn innpakning av `file_picker`: la brukeren plukke én fil å importere.
///
/// Håndterer kun standardtilfellet «én fil» (enkel `.md` eller `.zip`-pakke).
class FilePickerService {
  const FilePickerService();

  /// Viser plukkeren for én fil. Returnerer `null` hvis brukeren avbrøt eller
  /// filens innhold ikke kunne leses.
  ///
  /// [allowedExtensions] styrer hvilke filtyper som kan velges; standard er
  /// `md` og `zip` (bokens eksport-/importformater).
  Future<PickedBookFile?> pickBookFile({
    String? dialogTitle,
    List<String> allowedExtensions = const ['md', 'zip'],
  }) async {
    final picked = await FilePicker.pickFile(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return null;
    return PickedBookFile(name: picked.name, bytes: bytes);
  }
}
