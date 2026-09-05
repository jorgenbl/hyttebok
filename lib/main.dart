import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'data/repositories/book_repository.dart';
import 'data/services/file_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // All data ligger i enhetens dokument-mappe under `hyttebok/`.
  final documents = await getApplicationDocumentsDirectory();
  final storage = FileStorageService(
    Directory(p.join(documents.path, 'hyttebok')),
  );

  runApp(HyttebokApp(repository: BookRepository(storage)));
}
