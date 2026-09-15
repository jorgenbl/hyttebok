import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/repositories/book_repository.dart';

/// Laster et lokalt bilde fra boka som byteer og viser det.
///
/// Plattform-uavhengig (fungerer også på web der filsystem-stier ikke
/// eksisterer). Manglende eller ulesbare bilder vises som en plassholder;
/// mens det lastes vises en kort spinner i stedet for flash.
class BookImage extends StatelessWidget {
  const BookImage({
    super.key,
    required this.repo,
    required this.bookSlug,
    required this.src,
  });

  final BookRepository repo;
  final String bookSlug;
  final String src;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<Uint8List?>(
      future: repo.readImageSafe(bookSlug, src),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Image.memory(bytes, fit: BoxFit.fitWidth),
          );
        }
        if (snapshot.hasError) {
          return imagePlaceholder(context, src.isEmpty ? 'Bilde' : src, scheme);
        }
        // Lastes fortsatt: kort plassholder i stedet for flash.
        return const SizedBox(
          width: double.infinity,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}

/// Plassholder for manglende/ulesbare bilder.
Widget imagePlaceholder(
  BuildContext context,
  String label,
  ColorScheme scheme,
) {
  return Padding(
    padding: const EdgeInsets.all(8),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.broken_image, color: scheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text('🖼️ $label', style: TextStyle(color: scheme.outline)),
          ),
        ],
      ),
    ),
  );
}
