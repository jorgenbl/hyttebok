import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_storages.dart';
import 'file_storage_service.dart';
import 'file_text_key_value_store.dart';

/// Mobil/macOS/iOS: alt i appens dokument-mappe under `hyttebok/`.
Future<AppStorages> createStorages() async {
  final documents = await getApplicationDocumentsDirectory();
  final appDir = Directory(p.join(documents.path, 'hyttebok'));
  return AppStorages(
    books: FileStorageService(appDir),
    settings: FileTextKeyValueStore(appDir),
  );
}
