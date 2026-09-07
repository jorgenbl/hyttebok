import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-tpl-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileStorageService makeStorage() =>
      FileStorageService(Directory('${tempDir.path}/books'));

  Future<void> pumpWithLoad(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  testWidgets('kan opprette ny hytte fra mal (ledetekst-fylt)', (tester) async {
    // Høy flate slik at hele seksjonslisten renderes uten skroll.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = makeStorage();
    await tester.runAsync(() => storage.createBook('Sommehytta'));

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );

    // Åpne boka.
    await tester.tap(find.text('Sommehytta'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump();
    expect(find.byTooltip('Ny hytte'), findsOneWidget);

    // Åpne «ny»-bottom sheet og velg mal.
    await tester.tap(find.byTooltip('Ny hytte'));
    await tester.pumpAndSettle();
    expect(find.text('Ny hytte fra mal'), findsOneWidget);
    await tester.tap(find.text('Ny hytte fra mal'));
    await tester.pumpAndSettle();

    // Navn-dialog: fyll inn og lagre (Lagre er en FilledButton).
    await tester.enterText(find.byType(TextField), 'Fjellhytta');
    await tester.tap(find.widgetWithText(FilledButton, 'Lagre'));
    await tester.pumpAndSettle();

    // Sted-dialog (valgfritt): avbryt (Avbryt er en TextButton).
    expect(find.text('Sted (valgfritt)'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Avbryt'));
    await tester.pumpAndSettle();
    expect(find.text('Sted (valgfritt)'), findsNothing);

    // Navigert inn i den nye hytta; la fil-io + lasting fullføre.
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 60));
      if (find.text('Tips for gjester').evaluate().isNotEmpty) break;
    }

    // Hyttenavnet er satt og malens seksjoner er på plass.
    expect(find.text('Fjellhytta'), findsWidgets);
    expect(find.text('Kontakter & nøkkeler'), findsOneWidget);
    expect(find.text('Vann, avløp & toalett'), findsOneWidget);
    expect(find.text('Ved & peis'), findsOneWidget);
    expect(find.text('Vedlikeholdsplan'), findsOneWidget);
    expect(find.text('Inventar'), findsOneWidget);
    expect(find.text('Tips for gjester'), findsOneWidget);
  });
}
