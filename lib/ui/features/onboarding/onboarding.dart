import 'package:flutter/material.dart';

/// Én side i velkomst-opplæringen.
class _OnboardingPage {
  const _OnboardingPage(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const List<_OnboardingPage> _pages = [
  _OnboardingPage(
    Icons.menu_book,
    'Velkommen til Hyttebok',
    'En digital bok for hytta: rutiner, bilder og historier. Alt lagres '
        'lokal på enheten – ingen konto, ingen innlogging, ingen server.',
  ),
  _OnboardingPage(
    Icons.home,
    'Bøker og hytter',
    'Opprett en bok, og fyll den med hytter. «Ny hytte fra mal» gir en '
        'komplett struktur med ledetekst: åpne- og steng-rutiner, seksjoner '
        'og plass til historier.',
  ),
  _OnboardingPage(
    Icons.edit_outlined,
    'Skriv og ta bilder',
    'Redigereren klarer Markdown, sjekklister og bilder fra kamera eller '
        'galleri. Bildene lagres sammen med boken og følger med ved eksport.',
  ),
  _OnboardingPage(
    Icons.auto_awesome,
    'AI – valgfri hjelp',
    'AI-hjelp er valgfri: lokal (Ollama) holder alt hjemme, mens cloud '
        'krever en API-nøkkel som lagres kryptert i enhetens sikre lagring. '
        'Appen fungerer fullt ut uten AI.',
  ),
  _OnboardingPage(
    Icons.picture_as_pdf,
    'Eksport og sikkerhetskopi',
    'Eksporter boken som Markdown, zip-mappe eller PDF, og importer den på '
        'en ny enhet. Tips: lag en kopi før store endringer.',
  ),
];

/// Velkomst-opplæring som vises første gang appen kjøres: noen korte sider
/// om appen, deretter åpnes biblioteket.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key, required this.onFinish});

  /// Kalles når brukeren er ferdig (ofte: persister flagget før UI-et
  /// byttes).
  final Future<void> Function() onFinish;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _buildPage(context, _pages[i]),
              ),
            ),
            // Sideindikator: aktive prikken er en lang, flat «pille».
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _page ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? scheme.primary
                              : scheme.primary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
                onPressed: _finish,
                child: Text(
                  _page == _pages.length - 1 ? 'Kom i gang' : 'Ferdig',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, _OnboardingPage page) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: scheme.primaryContainer,
            child: Icon(page.icon, size: 48, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 24),
          Text(
            page.title,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.body,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
