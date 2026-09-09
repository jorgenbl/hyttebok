import 'dart:io';

import 'package:path/path.dart' as p;

import 'text_key_value_store.dart';

/// [TextKeyValueStore] som lagrer JSON-dokumentet som `settings.json` i
/// [baseDirectory].
class FileTextKeyValueStore implements TextKeyValueStore {
  FileTextKeyValueStore(Directory baseDirectory)
    : _file = File(p.join(baseDirectory.path, 'settings.json'));

  final File _file;

  @override
  String? load() {
    if (!_file.existsSync()) return null;
    try {
      return _file.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String value) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(value);
  }
}
