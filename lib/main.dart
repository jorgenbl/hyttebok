import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/repositories/book_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/create_storages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Plattformvalgt lagring (betinget import):
  // - Mobil: alt i appens dokument-mappe under `hyttebok/`.
  // - Web: bøker i minnet under økten, innstillinger i `localStorage`.
  final storages = await createStorages();

  runApp(
    HyttebokApp(
      repository: BookRepository(storages.books),
      settings: SettingsRepository(storages.settings),
    ),
  );
}
