import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

/// Web: utløser en nedlasting i nettleseren.
///
/// Den faktiske `<a download>`-logikken ligger i `web/index.html`
/// (`window.hyttebokDownload`); her kaller vi den via `@JS`. Byteene
/// base64-kodes til en data-URL (bøker er små – noen MB som mest), slik at
/// vi slipper Blob/typed-array-interop.
@JS('hyttebokDownload')
external void _hyttebokDownload(String filename, String dataUrl);

void downloadBytes(String filename, Uint8List bytes) {
  _hyttebokDownload(
    filename,
    'data:application/octet-stream;base64,${base64Encode(bytes)}',
  );
}

/// Kaldes aldri på web (kun mobil) – holder interfacet samlet.
Future<String> writeExportFile(String filename, Uint8List bytes) async {
  throw UnimplementedError('writeExportFile er kun tilgjengelig på mobil.');
}
