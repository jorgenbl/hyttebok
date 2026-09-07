import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-theme-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileStorageService makeStorage() =>
      FileStorageService(Directory('${tempDir.path}/books'));

  ThemeData themeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first));

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
    }
  }

  testWidgets('tema kan byttes mellom mørkt og lyst', (tester) async {
    final storage = makeStorage();
    await tester.pumpWidget(HyttebokApp(repository: BookRepository(storage)));
    await flush(tester);

    // Standard er «Følg system» → lyst i testmiljøet.
    expect(themeOf(tester).brightness, Brightness.light);

    // Velg mørkt tema.
    await tester.tap(find.byTooltip('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mørkt tema'));
    await tester.pumpAndSettle();
    expect(themeOf(tester).brightness, Brightness.dark);

    // Bytt tilbake til lyst tema.
    await tester.tap(find.byTooltip('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lyst tema'));
    await tester.pumpAndSettle();
    expect(themeOf(tester).brightness, Brightness.light);
  });
}
