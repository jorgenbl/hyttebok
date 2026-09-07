import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../domain/search/book_search.dart';
import 'book_search_view_model.dart';

/// Fulltekstsøk i en hel bok (Fase 3): forside, hytter, seksjoner og historier.
class BookSearchView extends StatelessWidget {
  const BookSearchView({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<BookRepository>();
    return ChangeNotifierProvider(
      create: (_) => BookSearchViewModel(repo, slug)..load(),
      child: const _BookSearchBody(),
    );
  }
}

class _BookSearchBody extends StatefulWidget {
  const _BookSearchBody();

  @override
  State<_BookSearchBody> createState() => _BookSearchBodyState();
}

class _BookSearchBodyState extends State<_BookSearchBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(BuildContext context, SearchResult result) {
    final vm = context.read<BookSearchViewModel>();
    final cabinSlug = result.cabinSlug;
    if (cabinSlug == null) {
      // Treffer i forside: tilbake til boka (som viser forside/intro).
      context.pop();
      return;
    }
    context.go('/book/${vm.slug}/cabin/$cabinSlug');
  }

  IconData _iconFor(SearchResult r) {
    if (r.title == 'Forsiden') return Icons.description;
    if (r.location == 'Hytte') return Icons.home;
    if (r.location.endsWith('· Historier')) return Icons.book;
    return Icons.subject;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookSearchViewModel>();
    final results = vm.results;
    final query = vm.query.trim();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(
            hintText: 'Søk i boka…',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
          onChanged: vm.setQuery,
        ),
      ),
      body: vm.loading && vm.book == null
          ? const Center(child: CircularProgressIndicator())
          : results.isEmpty
          ? EmptyState(
              icon: query.isEmpty ? Icons.search : Icons.search_off,
              message: query.isEmpty
                  ? 'Skriv for å søke i hele boka.'
                  : 'Ingen treff på «$query».',
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = results[i];
                final subtitle = [
                  if (r.location.isNotEmpty) r.location,
                  if (r.snippet.isNotEmpty) r.snippet,
                ].join(' — ');
                return ListTile(
                  onTap: () => _open(context, r),
                  leading: Icon(_iconFor(r)),
                  title: Text(r.title),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            ),
    );
  }
}
