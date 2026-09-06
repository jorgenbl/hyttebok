import 'package:file_picker/file_picker.dart';

/// Et plukket fil, avkjøpt fra `file_picker`'s plattformspecifikke
/// `PlatformFile`, slik at øvrig kode ikke avhenger av plugin-typen.
class PickedBookFile {
  const PickedBookFile({required this.path, required this.name});

  /// Absolutt sti til filen på disk.
  final String path;

  /// Filnavn med endelse (f.eks. `sommehytta.md`).
  final String name;
}

/// Tynn innpakning av `file_picker`: la brukeren plukke én fil å importere.
///
/// Håndterer kun standardtilfellet «én fil» (enkel `.md` eller `.zip`-pakke).
class FilePickerService {
  const FilePickerService();

  /// Viser plukkeren for én fil. Returnerer `null` hvis brukeren avbrøt eller
  /// filen ikke har en lokal sti.
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
    final path = picked?.path;
    if (path == null) return null;
    return PickedBookFile(path: path, name: picked!.name);
  }
}
