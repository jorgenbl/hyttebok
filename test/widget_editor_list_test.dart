import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/in_memory_book_storage.dart';
import 'package:hyttebok/ui/features/editor/editor.dart';
import 'package:provider/provider.dart';

/// Editor: liste-knapper i verktøylinjen og «smarte» lister
/// (Enter fortsetter listen, tom post + Enter og Backspace forlater den).
void main() {
  /// Starter editoren med [initial] og returnerer tester.
  Future<void> pumpEditor(WidgetTester tester, {String initial = ''}) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<BookRepository>.value(
            value: BookRepository(InMemoryBookStorage()),
          ),
        ],
        child: MaterialApp(
          home: EditorView(
            input: EditorInput(title: 'Seksjon', initialValue: initial),
          ),
        ),
      ),
    );
  }

  String editorText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  /// Marker all tekst (slik at knappen gjelder hele teksten, ikke kun
  /// linjen cursor står på).
  void selectAll(WidgetTester tester) {
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    final controller = editable.controller;
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  testWidgets('avkrysningsliste-knappen starter en ny liste på tom linje', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.pump();

    await tester.tap(find.byTooltip('Avkrysningsliste'));
    await tester.pump();
    expect(editorText(tester), '- [ ] ');
  });

  testWidgets('avkrysningsliste-knappen markerer teksten på linjen', (
    tester,
  ) async {
    await pumpEditor(tester, initial: 'Tommelfinger');
    await tester.pump();

    await tester.tap(find.byTooltip('Avkrysningsliste'));
    await tester.pump();
    expect(editorText(tester), '- [ ] Tommelfinger');
  });

  testWidgets('punktliste-knappen fjerner igjen markøren (toggle av)', (
    tester,
  ) async {
    await pumpEditor(tester, initial: '- post');
    await tester.pump();

    await tester.tap(find.byTooltip('Punktliste'));
    await tester.pump();
    expect(editorText(tester), 'post');
  });

  testWidgets('nummerert-knappen nummererer markerte linjer 1, 2, 3', (
    tester,
  ) async {
    await pumpEditor(tester, initial: 'a\nb\nc');
    await tester.pump();
    selectAll(tester);

    await tester.tap(find.byTooltip('Nummerert liste'));
    await tester.pump();
    expect(editorText(tester), '1. a\n2. b\n3. c');
  });

  testWidgets('uten markering gjelder kun linjen cursor står på', (
    tester,
  ) async {
    await pumpEditor(tester, initial: 'a\nb\nc');
    await tester.pump();
    // Cursor står i slutten (linjen «c»).
    await tester.tap(find.byTooltip('Nummerert liste'));
    await tester.pump();
    expect(editorText(tester), 'a\nb\n1. c');
  });

  testWidgets('Enter fortsetter en punktoppstrek med ny markør', (
    tester,
  ) async {
    await pumpEditor(tester, initial: '- one');
    await tester.pump();
    final field = find.byType(TextField);
    await tester.enterText(field, '- one\n');
    await tester.pump();
    expect(editorText(tester), '- one\n- ');
  });

  testWidgets('Enter fortsetter en avkrysningsliste med uavkrysset boks', (
    tester,
  ) async {
    await pumpEditor(tester, initial: '- [x] done');
    await tester.pump();
    final field = find.byType(TextField);
    await tester.enterText(field, '- [x] done\n');
    await tester.pump();
    expect(editorText(tester), '- [x] done\n- [ ] ');
  });

  testWidgets('Enter i nummerert liste øker nummeret med én', (tester) async {
    await pumpEditor(tester, initial: '2. to');
    await tester.pump();
    final field = find.byType(TextField);
    await tester.enterText(field, '2. to\n');
    await tester.pump();
    expect(editorText(tester), '2. to\n3. ');
  });

  testWidgets('Enter på tom liste-post forlater listen', (tester) async {
    await pumpEditor(tester, initial: '- one\n- ');
    await tester.pump();
    final field = find.byType(TextField);
    await tester.enterText(field, '- one\n- \n');
    await tester.pump();
    expect(editorText(tester), '- one\n');
  });

  testWidgets('Enter utenfor liste gjør ikke noe ekstra', (tester) async {
    await pumpEditor(tester, initial: 'hei');
    await tester.pump();
    final field = find.byType(TextField);
    await tester.enterText(field, 'hei\n');
    await tester.pump();
    expect(editorText(tester), 'hei\n');
  });

  testWidgets('Backspace i selve markøren fjerner hele markøren', (
    tester,
  ) async {
    await pumpEditor(tester, initial: '- ');
    await tester.pump();
    final field = find.byType(TextField);
    // Fjerner mellomrommet i markøren: hele «- » skal forsvinne med ett.
    await tester.enterText(field, '-');
    await tester.pump();
    expect(editorText(tester), '');
  });

  testWidgets('Backspace i innholdet endrer ikke markøren', (tester) async {
    await pumpEditor(tester, initial: '- heisann');
    await tester.pump();
    final field = find.byType(TextField);
    // Fjerner ett tegn fra innholdet: markøren skal stå igjen.
    await tester.enterText(field, '- heisan');
    await tester.pump();
    expect(editorText(tester), '- heisan');
  });
}
