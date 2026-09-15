import 'package:go_router/go_router.dart';

import '../data/services/ai_settings.dart';
import '../ui/features/book/book_search_view.dart';
import '../ui/features/book/book_view.dart';
import '../ui/features/cabin/cabin_view.dart';
import '../ui/features/editor/editor.dart';
import '../ui/features/help/help_view.dart';
import '../ui/features/library/library_view.dart';
import '../ui/features/reader/reader_view.dart';
import '../ui/features/settings/settings_view.dart';

/// Bygger appens ruter. Opprettes per app-instans (test-vennlig).
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LibraryView()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsView(),
      ),
      // Egen AI-profil for et formål (skrivehjelp/strukturforslag/
      // bildegenerering). Ukjent formål behandles som standard.
      GoRoute(
        path: '/settings/ai/:purpose',
        builder: (context, state) {
          final purpose = AiPurpose.values.firstWhere(
            (p) => p.name == state.pathParameters['purpose'],
            orElse: () => AiPurpose.standard,
          );
          return SettingsView(purpose: purpose);
        },
      ),
      GoRoute(path: '/help', builder: (context, state) => const HelpView()),
      GoRoute(
        path: '/book/:slug',
        builder: (context, state) =>
            BookView(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/book/:slug/search',
        builder: (context, state) =>
            BookSearchView(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/book/:slug/cabin/:cabinSlug',
        builder: (context, state) => CabinView(
          bookSlug: state.pathParameters['slug']!,
          cabinSlug: state.pathParameters['cabinSlug']!,
        ),
      ),
      GoRoute(
        path: '/book/:slug/read',
        builder: (context, state) =>
            BookReaderView(bookSlug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/book/:slug/cabin/:cabinSlug/read',
        builder: (context, state) => BookReaderView(
          bookSlug: state.pathParameters['slug']!,
          cabinSlug: state.pathParameters['cabinSlug']!,
        ),
      ),
      GoRoute(
        path: '/editor',
        builder: (context, state) =>
            EditorView(input: state.extra as EditorInput),
      ),
    ],
  );
}
