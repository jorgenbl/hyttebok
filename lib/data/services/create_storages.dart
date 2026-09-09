/// Betinget import: velger lagringsimplementasjon per plattform.
///
/// Web-buildet får `create_storages_web.dart` (ingen `dart:io`); alle andre
/// plattformer får `create_storages_io.dart`.
library;

export 'create_storages_io.dart'
    if (dart.library.js_interop) 'create_storages_web.dart';
