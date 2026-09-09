import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/book.dart';
import '../../domain/models/cabin.dart';
import '../../domain/models/section.dart';
import '../../domain/models/section_type.dart';

/// Eksporterer en [Book] til PDF-byteer (F18: utskrift / lagre PDF).
///
/// Renderer en forenklet, utskriftsvennlig versjon av boken: tittel, forside,
/// så per hytte beskrivelse, åpne/steng-rutiner, tilleggsseksjoner (også
/// skjulte – tap-fri som øvrig eksport) og historier. Markdown-reduksjon
/// dekker overskrifter, avkrysningslister, punktlisteposter, sitering og
/// bilder; annet syntaks skrives ut som ren tekst.
class BookPdfExporter {
  /// Breddemaks for bilder i PDF-en (A4 med standard marg i pdf-punkt).
  static const double maxImageWidth = 380;

  // pdf-widgets' [pw.TextStyle] har ikke const-konstruktør.
  static final _title = pw.TextStyle(
    fontSize: 24,
    fontWeight: pw.FontWeight.bold,
  );
  static final _cabin = pw.TextStyle(
    fontSize: 17,
    fontWeight: pw.FontWeight.bold,
  );
  static final _section = pw.TextStyle(
    fontSize: 13,
    fontWeight: pw.FontWeight.bold,
  );
  static final _story = pw.TextStyle(
    fontSize: 11.5,
    fontWeight: pw.FontWeight.bold,
  );
  static final _meta = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);
  static final _text = pw.TextStyle(fontSize: 10.5, height: 1.35);
  static final _quote = pw.TextStyle(
    fontSize: 10,
    height: 1.3,
    fontStyle: pw.FontStyle.italic,
    color: PdfColors.grey800,
  );

  /// Lager PDF-byteer for [book].
  ///
  /// [imageBytes] henter bytes for en relativ bildesti (relativt boka);
  /// returner `null` for manglende eller ulesbar fil da hoppes bildet over
  /// (eventuell bildetekst beholdes). Uten [imageBytes] vises kun
  /// bildeteksten.
  Future<Uint8List> exportPdf(
    Book book, {
    Future<Uint8List?> Function(String relativePath)? imageBytes,
    PdfPageFormat pageFormat = PdfPageFormat.standard,
  }) async {
    // Last alle bildene først slik at widget-treet kan bygges synkron.
    final imageLookup = imageBytes == null
        ? null
        : await _collectImages(book, imageBytes);

    final blocks = <pw.Widget>[
      pw.Text(book.title, style: _title),
      pw.SizedBox(
        height: 4,
        child: pw.Container(
          height: 0.8,
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
        ),
      ),
      pw.Text(
        'Hyttebok · sist endret ${_norskDato(book.updatedAt)}',
        style: _meta,
      ),
      pw.SizedBox(height: 14),
    ];

    if (book.intro.trim().isNotEmpty) {
      blocks.addAll(_markdown(book.intro, imageLookup));
      blocks.add(pw.SizedBox(height: 18));
    }

    for (final cabin in book.cabins) {
      blocks.addAll(_cabinBlocks(cabin, imageLookup));
    }

    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: blocks,
        ),
      ),
    );
    return document.save();
  }

  /// Henter bytes for alle bildene i boka (unike stier, uendelige feil →
  /// `null` slik at et ødelagt bilde ikke knuser eksporten).
  Future<Map<String, Uint8List?>> _collectImages(
    Book book,
    Future<Uint8List?> Function(String) imageBytes,
  ) async {
    final paths = <String>{
      if (book.coverImage != null) book.coverImage!,
      for (final cabin in book.cabins) ..._cabinImagePaths(cabin),
    };
    final result = <String, Uint8List?>{};
    for (final rel in paths) {
      Uint8List? bytes;
      try {
        bytes = await imageBytes(rel);
      } catch (_) {
        bytes = null;
      }
      result[rel] = bytes;
    }
    return result;
  }

  Set<String> _cabinImagePaths(Cabin cabin) {
    return {
      ...cabin.startRoutines.images,
      ...cabin.stopRoutines.images,
      for (final s in cabin.sections) ...s.images,
      for (final s in cabin.stories) ...s.images,
    };
  }

  List<pw.Widget> _cabinBlocks(
    Cabin cabin,
    Map<String, Uint8List?>? imageLookup,
  ) {
    final blocks = <pw.Widget>[
      pw.SizedBox(height: 16),
      pw.Text(cabin.name, style: _cabin),
      if (cabin.location != null && cabin.location!.trim().isNotEmpty)
        pw.Text(cabin.location!, style: _meta),
      pw.SizedBox(height: 8),
    ];

    if (cabin.description.trim().isNotEmpty) {
      blocks.addAll(_markdown(cabin.description, imageLookup));
      blocks.add(pw.SizedBox(height: 10));
    }

    for (final section in _routineAndExtraSections(cabin)) {
      if (section.markdown.trim().isEmpty && section.images.isEmpty) continue;
      blocks.add(pw.Text(_sectionTitle(section), style: _section));
      blocks.add(pw.SizedBox(height: 4));
      blocks.addAll(_markdown(section.markdown, imageLookup));
      blocks.addAll(_images(section.images, imageLookup));
      blocks.add(pw.SizedBox(height: 10));
    }

    if (cabin.stories.isNotEmpty) {
      blocks.add(pw.Text('Historier', style: _section));
      blocks.add(pw.SizedBox(height: 4));
      for (final story in cabin.stories) {
        blocks.add(
          pw.Text(
            story.title +
                (story.date != null ? '  (${_norskDato(story.date!)})' : '') +
                (story.author != null && story.author!.trim().isNotEmpty
                    ? '  –  ${story.author}'
                    : ''),
            style: _story,
          ),
        );
        if (story.markdown.trim().isNotEmpty) {
          blocks.add(pw.SizedBox(height: 2));
          blocks.addAll(_markdown(story.markdown, imageLookup));
        }
        blocks.addAll(_images(story.images, imageLookup));
        blocks.add(pw.SizedBox(height: 8));
      }
    }
    return blocks;
  }

  /// Fast rutine-seksjoner + ordinære tilleggsseksjoner (også skjulte), i
  /// naturlig rekkefølge som i appen.
  List<Section> _routineAndExtraSections(Cabin cabin) {
    return [
      if (cabin.startRoutines.markdown.trim().isNotEmpty ||
          cabin.startRoutines.images.isNotEmpty)
        cabin.startRoutines,
      if (cabin.stopRoutines.markdown.trim().isNotEmpty ||
          cabin.stopRoutines.images.isNotEmpty)
        cabin.stopRoutines,
      ...cabin.sections,
    ];
  }

  String _sectionTitle(Section section) {
    final title = section.title.trim();
    if (title.isNotEmpty) return title;
    switch (section.type) {
      case SectionType.startRoutines:
        return 'Åpne-rutiner';
      case SectionType.stopRoutines:
        return 'Steng-rutiner';
      default:
        return 'Seksjon';
    }
  }

  /// Bilder knyttet direkte til en seksjon/historie (bortsett fra de som
  /// allerede er inlinet i Markdown-en).
  List<pw.Widget> _images(
    List<String> relPaths,
    Map<String, Uint8List?>? imageLookup,
  ) {
    final widgets = <pw.Widget>[];
    for (final rel in relPaths) {
      final widget = _imageWidget(rel, null, imageLookup);
      if (widget != null) widgets.add(widget);
    }
    return widgets;
  }

  pw.Widget? _imageWidget(
    String rel,
    String? alt,
    Map<String, Uint8List?>? imageLookup,
  ) {
    if (imageLookup == null) return null;
    final bytes = imageLookup[rel];
    if (bytes != null && bytes.isNotEmpty) {
      try {
        return pw.Image(
          pw.MemoryImage(bytes),
          width: maxImageWidth,
          fit: pw.BoxFit.contain,
        );
      } catch (_) {
        // Ulesbart bildeformat: fall tilbake til tekst.
      }
    }
    if (alt != null && alt.trim().isNotEmpty) {
      return pw.Text(alt, style: _meta);
    }
    return null;
  }

  List<pw.Widget> _markdown(
    String markdown,
    Map<String, Uint8List?>? imageLookup,
  ) {
    final widgets = <pw.Widget>[];
    final lines = markdown.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final size = switch (level) {
          1 => 15.0,
          2 => 13.0,
          3 => 12.0,
          _ => 11.0,
        };
        widgets.add(pw.SizedBox(height: 6));
        widgets.add(
          pw.Text(
            heading.group(2)!.trim(),
            style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
          ),
        );
        widgets.add(pw.SizedBox(height: 2));
        continue;
      }

      final checkbox = RegExp(r'^[-*]\s+\[( |x|X)\]\s*(.*)$').firstMatch(line);
      if (checkbox != null) {
        final checked = checkbox.group(1)!.toLowerCase() == 'x';
        widgets.add(_checkboxRow(checkbox.group(2)!.trim(), checked: checked));
        continue;
      }

      final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        widgets.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 10, child: pw.Text('•', style: _text)),
              pw.Expanded(
                child: pw.Text(bullet.group(1)!.trim(), style: _text),
              ),
            ],
          ),
        );
        continue;
      }

      final quote = RegExp(r'^>\s*(.*)$').firstMatch(line);
      if (quote != null) {
        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(left: 12),
            child: pw.Text(quote.group(1)!.trim(), style: _quote),
          ),
        );
        continue;
      }

      final image = RegExp(r'^!\[(.*?)\]\((.*?)\)$').firstMatch(line);
      if (image != null) {
        final widget = _imageWidget(
          image.group(2)!,
          image.group(1),
          imageLookup,
        );
        if (widget != null) widgets.add(widget);
        continue;
      }

      widgets.add(pw.Text(line, style: _text));
    }
    return widgets;
  }

  pw.Widget _checkboxRow(String text, {required bool checked}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 10,
          height: 10,
          margin: pw.EdgeInsets.only(right: 6, top: 3),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
            borderRadius: pw.BorderRadius.circular(2),
          ),
          child: checked
              ? pw.Center(child: pw.Text('x', style: pw.TextStyle(fontSize: 8)))
              : null,
        ),
        pw.Expanded(
          child: pw.Text(
            text,
            style: _text.copyWith(
              color: checked ? PdfColors.grey700 : null,
              decoration: checked ? pw.TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }

  String _norskDato(DateTime d) {
    const months = [
      'januar',
      'februar',
      'mars',
      'april',
      'mai',
      'juni',
      'juli',
      'august',
      'september',
      'oktober',
      'november',
      'desember',
    ];
    final day = d.day.toString().padLeft(2, '0');
    return '$day. ${months[d.month - 1]} ${d.year}';
  }
}
