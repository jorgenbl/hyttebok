import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/book_repository.dart';
import '../data/services/file_picker_service.dart';
import '../data/services/image_picker_service.dart';
import '../data/services/share_service.dart';
import 'router.dart';
import 'theme.dart';

/// Rot-widget for Hyttebok. Mottar en [BookRepository] (injisert fra `main`
/// eller tester) og bygger router + tema.
///
/// [imagePicker], [share] og [filePicker] kan injiseres i tester; i produksjon
/// brukes standardimplementasjonene.
class HyttebokApp extends StatelessWidget {
  const HyttebokApp({
    super.key,
    required this.repository,
    this.imagePicker,
    this.share,
    this.filePicker,
  });

  final BookRepository repository;
  final ImagePickerService? imagePicker;
  final ShareService? share;
  final FilePickerService? filePicker;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BookRepository>.value(value: repository),
        Provider<ImagePickerService>.value(
          value: imagePicker ?? ImagePickerService(),
        ),
        Provider<ShareService>.value(value: share ?? const ShareService()),
        Provider<FilePickerService>.value(
          value: filePicker ?? const FilePickerService(),
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
