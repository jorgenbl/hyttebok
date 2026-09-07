import 'package:go_router/go_router.dart';

import '../ui/features/book/book_search_view.dart';
import '../ui/features/book/book_view.dart';
import '../ui/features/cabin/cabin_view.dart';
import '../ui/features/editor/editor.dart';
import '../ui/features/library/library_view.dart';

/// Bygger appens ruter. Opprettes per app-instans (test-vennlig).
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LibraryView()),
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
        path: '/editor',
        builder: (context, state) =>
            EditorView(input: state.extra as EditorInput),
      ),
    ],
  );
}
