// E2E-integrasjonstest (Fase 5): kjører appen på ekte enhet/simulator med
// reell fil-io og dekker brukerfløten
//
//   opprett bok → lag hytte → skriv (beskrivelse + rutiner)
//   → eksporter zip → import til ny lagring → sammenlign.
//
// Kjøres med: flutter test integration_test -d <simulator/enhet>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:integration_test/integration_test.dart';

/// Ekte enhet: la async fil-io + side-overganger fullføre med reell tid.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('e2e: opprett → skriv → eksport → import → sammenlign', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('hyttebok-e2e-');
    final importDir = Directory('${dir.path}/import')..createSync();
    addTearDown(() => dir.deleteSync(recursive: true));

    final storage = FileStorageService(Directory('${dir.path}/books'));
    final repo = BookRepository(storage);

    await tester.pumpWidget(HyttebokApp(repository: repo));
    await _settle(tester);

    // 1. Opprett bok fra biblioteket.
    await tester.tap(find.byTooltip('Ny bok'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'E2E Hytta');
    await tester.tap(find.widgetWithText(FilledButton, 'Lagre'));
    await _settle(tester);
    expect(find.text('E2E Hytta'), findsOneWidget);

    // 2. Lag ny hytte i boka.
    await tester.tap(find.byTooltip('Ny hytte'));
    await _settle(tester);
    await tester.tap(find.text('Ny hytte'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'E2E-hytten');
    await tester.tap(find.widgetWithText(FilledButton, 'Lagre'));
    await _settle(tester);
    expect(find.text('E2E-hytten'), findsWidgets);
    expect(find.text('Beskrivelse'), findsOneWidget);

    // 3. Skriv beskrivelse.
    await tester.tap(find.text('Beskrivelse'));
    await _settle(tester);
    await tester.enterText(
      find.byType(TextField),
      'E2E-beskrivelse skrevet på simulatoren.',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Lagre'));
    await _settle(tester);

    // 4. Skriv åpne-rutiner.
    await tester.tap(find.text('Åpne-rutiner'));
    await _settle(tester);
    await tester.enterText(
      find.byType(TextField),
      '- [ ] Tenn peisen\n- [ ] Sjekk vannet',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Lagre'));
    await _settle(tester);

    // 5. Eksporter til zip direkte fra repository (deling i UI åpner
    //    OS-delingsarket, som ikke egnest seg for automatisering).
    const slug = 'e2e-hytta';
    final zipBytes = await repo.exportZipBytes(slug);
    expect(zipBytes.sublist(0, 2), [0x50, 0x4B]); // PK-header

    // 6. Importer zippet til en ny lagring og sammenlign.
    final repo2 = BookRepository(FileStorageService(importDir));
    final importedSlug = await repo2.importFromBytes('e2e-hytta.zip', zipBytes);
    final original = await repo.load(slug);
    final imported = await repo2.load(importedSlug);

    expect(imported.title, original.title);
    expect(imported.intro, original.intro);
    expect(imported.cabins.length, 1);
    expect(imported.cabins.first.name, 'E2E-hytten');
    expect(
      imported.cabins.first.description,
      'E2E-beskrivelse skrevet på simulatoren.',
    );
    expect(
      imported.cabins.first.startRoutines.markdown,
      contains('Tenn peisen'),
    );
    expect(
      imported.cabins.first.startRoutines.markdown,
      contains('Sjekk vannet'),
    );

    // 7. UI-et står på hyttesiden; åpn redigereren igjen og bekreft at det
    //    vi skrev er der (round-trip gjennom lagring).
    expect(find.text('E2E-hytten'), findsWidgets); // appbar + navn-tile
    await tester.tap(find.text('Beskrivelse'));
    await _settle(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'E2E-beskrivelse skrevet på simulatoren.');
    expect(tester.takeException(), isNull);
  });
}
