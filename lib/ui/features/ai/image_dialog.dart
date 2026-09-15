import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/ai_image_client.dart';
import '../../../data/services/ai_settings.dart';
import '../../../data/services/secure_key_store.dart';

/// Åpner dialogen for AI-bildegenerering.
///
/// Genererer på bildeprofils ([AiPurpose.images]) egen profil om satt,
/// ellers standardprofilen. Returnerer den relative stien til det lagrede
/// bildet når brukeren innsetter det (ellers `null`).
Future<String?> showAiImageDialog(
  BuildContext context, {
  required String bookSlug,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _AiImageDialog(bookSlug: bookSlug),
  );
}

class _AiImageDialog extends StatefulWidget {
  const _AiImageDialog({required this.bookSlug});

  final String bookSlug;

  @override
  State<_AiImageDialog> createState() => _AiImageDialogState();
}

enum _ImageState { input, running, done, error }

class _AiImageDialogState extends State<_AiImageDialog> {
  late final SettingsRepository _settingsRepo;
  late final SecureKeyStore _keyStore;
  late final AiImageClientBuilder _clientBuilder;
  late final BookRepository _bookRepo;

  /// Bildeprofilen: egen for formålet om satt, ellers standardprofilen.
  late final AiSettings? _settings;
  late final bool _hasOwnProfile;
  late final TextEditingController _prompt;

  _ImageState _state = _ImageState.input;
  String _error = '';
  AiGeneratedImage? _image;

  @override
  void initState() {
    super.initState();
    _settingsRepo = context.read<SettingsRepository>();
    _keyStore = context.read<SecureKeyStore>();
    _clientBuilder = context.read<AiImageClientBuilder>();
    _bookRepo = context.read<BookRepository>();
    final own = _settingsRepo.loadAiProfile(AiPurpose.images);
    _hasOwnProfile = own != null;
    _settings = own ?? _settingsRepo.loadAiSettings();
    _prompt = TextEditingController();
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  /// Hvor brukeren skal for å fikse manglende oppsett/nøkkel.
  String get _setupHint => _hasOwnProfile
      ? 'Innstillinger → AI → ${AiPurpose.images.label}'
      : 'Innstillinger → AI';

  Future<void> _generate() async {
    final settings = _settings;
    if (settings == null) return;
    final slot = _hasOwnProfile
        ? aiApiKeyKeyFor(AiPurpose.images)
        : kAiApiKeyKey;
    final apiKey = (await _keyStore.readKey(slot)) ?? '';
    if (!mounted) return;
    if (settings.needsApiKey && apiKey.isEmpty) {
      setState(() {
        _state = _ImageState.error;
        _error =
            'Ingen API-nøkkel er satt. Skriv den inn under '
            '$_setupHint.';
      });
      return;
    }

    setState(() {
      _state = _ImageState.running;
      _error = '';
    });

    final client = _clientBuilder(settings, apiKey.isEmpty ? null : apiKey);
    try {
      final image = await client.generate(prompt: _prompt.text.trim());
      if (!mounted) return;
      setState(() {
        _image = image;
        _state = _ImageState.done;
      });
    } on AiProviderError catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ImageState.error;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ImageState.error;
        _error = 'Uventet feil: $e';
      });
    }
  }

  Future<void> _insert() async {
    final image = _image;
    if (image == null) return;
    try {
      final relative = await _bookRepo.saveGeneratedImage(
        widget.bookSlug,
        image.bytes,
        extension: image.extension,
      );
      if (!mounted) return;
      Navigator.of(context).pop(relative);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _ImageState.error;
        _error = 'Kunne ikke lagre bildet i boken.';
      });
    }
  }

  void _tryAgain() {
    setState(() {
      _state = _ImageState.input;
      _error = '';
      _image = null;
    });
  }

  Widget _inputBody() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _prompt,
            maxLines: 3,
            autofocus: true,
            // «Generer»-knappen er aktivert/deaktivert ut fra prompten.
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Beskriv bildet',
              hintText:
                  'f.eks. en liten trestue på fjellet om morgenen, akvarell',
            ),
          ),
          if (_settings == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'AI er ikke konfigurert. Åpne $_setupHint og sett opp en '
                'leverandør som kan generere bilder (f.eks. OpenAI eller en '
                'lokal SD WebUI-instans).',
                style: TextStyle(color: scheme.outline),
              ),
            ),
        ],
      ),
    );
  }

  Widget _runningBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Genererer bilde…\nDette kan ta litt tid.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneBody() {
    final image = _image!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: Image.memory(
              image.bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBody() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Text(_error, style: TextStyle(color: scheme.error)),
      ),
    );
  }

  /// Handlinger nederst i dialogen. «Ferdig»-tilstanden har tre knapper og
  /// bruker [Wrap] slik at de bryter til en ny linje på smale skjermer
  /// (eller med store fontstørrelser) i stedet for å flyte over.
  Widget _actions(Widget primary, _ImageState state) {
    if (state == _ImageState.done) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(onPressed: _tryAgain, child: const Text('Prøv igjen')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Forkast'),
          ),
          primary,
        ],
      );
    }
    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Forkast'),
        ),
        const Spacer(),
        primary,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    Widget body;
    Widget primary;
    switch (state) {
      case _ImageState.input:
        body = _inputBody();
        primary = FilledButton.icon(
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generer'),
          onPressed: (_prompt.text.trim().isNotEmpty && _settings != null)
              ? _generate
              : null,
        );
      case _ImageState.running:
        body = _runningBody();
        primary = OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        );
      case _ImageState.done:
        body = _doneBody();
        primary = FilledButton.icon(
          icon: const Icon(Icons.drive_file_move_outlined),
          label: const Text('Innsett i teksten'),
          onPressed: _insert,
        );
      case _ImageState.error:
        body = _errorBody();
        primary = FilledButton.tonal(
          onPressed: _tryAgain,
          child: const Text('Prøv igjen'),
        );
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome),
                  const SizedBox(width: 8),
                  const Text(
                    'Generer bilde',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: body),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _actions(primary, state),
            ),
          ],
        ),
      ),
    );
  }
}
