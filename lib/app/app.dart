import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/book_repository.dart';
import '../data/services/image_picker_service.dart';
import 'router.dart';
import 'theme.dart';

/// Rot-widget for Hyttebok. Mottar en [BookRepository] (injisert fra `main`
/// eller tester) og bygger router + tema. [imagePicker] kan injiseres i tester.
class HyttebokApp extends StatelessWidget {
  const HyttebokApp({super.key, required this.repository, this.imagePicker});

  final BookRepository repository;
  final ImagePickerService? imagePicker;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BookRepository>.value(value: repository),
        Provider<ImagePickerService>.value(
          value: imagePicker ?? ImagePickerService(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Hyttebok',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: buildRouter(),
      ),
    );
  }
}
