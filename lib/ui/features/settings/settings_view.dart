import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/skeleton.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/ai_client.dart';
import '../../../data/services/ai_settings.dart';
import '../../../data/services/secure_key_store.dart';
import 'settings_view_model.dart';

/// AI-innstillinger, nådd fra bibliotek-menyen.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsRepository>();
    final keyStore = context.read<SecureKeyStore>();
    final clientBuilder = context.read<AiClientBuilder>();
    return ChangeNotifierProvider(
      create: (_) =>
          SettingsViewModel(settings, keyStore, clientBuilder)..load(),
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Innstillinger')),
      body: !vm.loaded
          ? const SkeletonList()
          : vm.settings == null
          ? _IntroCard(vm: vm)
          : _SettingsForm(key: const ValueKey('form'), vm: vm),
    );
  }
}

/// Vises før noen leverandør er valgt: kort forklaring + valg av lokal/cloud.
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.vm});

  final SettingsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome),
                    SizedBox(width: 8),
                    Text(
                      'AI-hjelp',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'AI-en er en valgfri hjelpefunksjon. Den kan kjøre lokalt '
                  '(Ollama eller LM Studio), slik at dataene aldri forlater '
                  'enheten, eller mot en cloud-tjeneste (OpenAI eller '
                  'Anthropic) der dataene sendes til leverandøren.',
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.memory),
                  label: const Text('Sett opp lokal leverandør'),
                  onPressed: () => vm.setType(AiProviderType.ollama),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.cloud),
                  label: const Text('Sett opp cloud-leverandør'),
                  onPressed: () => vm.setType(AiProviderType.openai),
                ),
                const SizedBox(height: 16),
                Text(
                  'Alt lagres lokalt på enheten. API-nøkkelen (hvis noe) '
                  'legges i sikker lagring og sendes kun til den valgte '
                  'leverandøren.',
                  style: TextStyle(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Innstillings-formularet. Eier egne [TextEditingController]-er som
/// initialiseres fra ViewModel-en (som er lastet ved dette tidspunktet);
/// synk er entydig felt → VM (utenom leverandørbytte som setter
/// standard-URL/modell).
class _SettingsForm extends StatefulWidget {
  const _SettingsForm({super.key, required this.vm});

  final SettingsViewModel vm;

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;
  late final TextEditingController _systemPrompt;
  late final TextEditingController _maxTokens;
  bool _showKey = false;

  SettingsViewModel get vm => widget.vm;

  @override
  void initState() {
    super.initState();
    final s = vm.settings!;
    _baseUrl = TextEditingController(text: s.baseUrl);
    _model = TextEditingController(text: s.model);
    _apiKey = TextEditingController(text: vm.apiKey);
    _systemPrompt = TextEditingController(text: s.systemPrompt);
    _maxTokens = TextEditingController(text: s.maxTokens.toString());
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    _systemPrompt.dispose();
    _maxTokens.dispose();
    super.dispose();
  }

  void _selectType(AiProviderType type) {
    vm.setType(type);
    // Bytte leverandør setter nye standard-URL/modell i VM-en; synk dem til
    // feltene slik at brukeren ser startverdiene.
    _baseUrl.text = vm.settings!.baseUrl;
    _model.text = vm.settings!.model;
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? type,
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        obscureText: obscure,
        keyboardType: type,
        autofocus: autofocus,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = vm.settings!;
    final scheme = Theme.of(context).colorScheme;
    final isLocal = s.isLocal;
    final running = vm.testState == AiTestState.running;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<AiProviderType>(
                  initialValue: s.type,
                  decoration: const InputDecoration(labelText: 'Leverandør'),
                  items: [
                    for (final t in AiProviderType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (t) {
                    if (t != null) _selectType(t);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isLocal ? Icons.cloud_off : Icons.cloud,
                      size: 18,
                      color: isLocal ? scheme.primary : scheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isLocal
                            ? 'Lokal – dataene forlater ikke enheten.'
                            : 'Cloud – dataene sendes til leverandøren.',
                        style: TextStyle(
                          color: isLocal ? scheme.primary : scheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _field(
                  controller: _baseUrl,
                  label: 'Base-URL',
                  hint: 'f.eks. http://localhost:11434/v1',
                  onChanged: vm.setBaseUrl,
                  autofocus: s.type == AiProviderType.custom,
                ),
                _field(
                  controller: _model,
                  label: 'Modell',
                  hint: 'f.eks. llama3.1',
                  onChanged: vm.setModel,
                ),
                if (s.needsApiKey)
                  _field(
                    controller: _apiKey,
                    label: 'API-nøkkel',
                    hint: 'skjules i sikker lagring',
                    onChanged: vm.setApiKey,
                    obscure: !_showKey,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showKey ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _showKey = !_showKey),
                    ),
                  ),
              ],
            ),
          ),
        ),

        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Systemprompt',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.outline,
                  ),
                ),
                TextField(
                  controller: _systemPrompt,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Hvordan AI-en skal svare…',
                  ),
                  onChanged: vm.setSystemPrompt,
                ),
                ExpansionTile(
                  title: const Text('Avansert'),
                  children: [
                    _field(
                      controller: _maxTokens,
                      label: 'Maks token (svarlengde)',
                      hint: 'f.eks. 2048',
                      onChanged: (value) {
                        final n = int.tryParse(value);
                        if (n != null) vm.setMaxTokens(n);
                      },
                      type: TextInputType.number,
                    ),
                    Row(
                      children: [
                        const Expanded(child: Text('Temperatur')),
                        Text(s.temperature.toStringAsFixed(1)),
                      ],
                    ),
                    Slider(
                      value: s.temperature,
                      min: 0,
                      max: 2,
                      onChanged: vm.setTemperature,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              FilledButton.icon(
                icon: running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(running ? 'Tester…' : 'Test tilkobling'),
                onPressed: running ? null : vm.testConnection,
              ),
              if (vm.testState == AiTestState.success)
                Text(vm.testMessage, style: TextStyle(color: scheme.primary)),
              if (vm.testState == AiTestState.failure)
                Text(vm.testMessage, style: TextStyle(color: scheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}
