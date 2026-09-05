import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/book_repository.dart';
import 'router.dart';
import 'theme.dart';

/// Rot-widget for Hyttebok. Mottar en [BookRepository] (injisert fra `main`
/// eller tester) og bygger router + tema.
class HyttebokApp extends StatelessWidget {
  const HyttebokApp({super.key, required this.repository});

  final BookRepository repository;

  @override
  Widget build(BuildContext context) {
    return Provider<BookRepository>.value(
      value: repository,
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
