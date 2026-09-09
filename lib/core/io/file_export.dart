/// Betinget import for eksport av filer:
/// - Mobil: [writeExportFile] skriver til temp-mappe (for delingsmenyen).
/// - Web: [downloadBytes] laster filen ned i nettleseren.
library;

export 'file_export_io.dart'
    if (dart.library.js_interop) 'file_export_web.dart';
