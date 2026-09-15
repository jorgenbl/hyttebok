import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/skeleton.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/ai_client.dart';
import '../../../data/services/ai_settings.dart';
import '../../../data/services/secure_key_store.dart';
import 'settings_view_model.dart';

/// AI-innstillinger, nådd fra bibliotek-menyen.
///
/// [AiPurpose.standard] viser standardprofilen (med oversikt over de
/// formålsspesifikke profilene); øvrige formål redigerer sin egen profil.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key, this.purpose = AiPurpose.standard});

  final AiPurpose purpose;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsRepository>();
    final keyStore = context.read<SecureKeyStore>();
    final clientBuilder = context.read<AiClientBuilder>();
    return ChangeNotifierProvider(
      create: (_) =>
          SettingsViewModel(settings, keyStore, clientBuilder, purpose: purpose)
            ..load(),
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final purpose = vm.purpose;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          purpose == AiPurpose.standard
              ? 'Innstillinger'
              : 'AI – ${purpose.label}',
        ),
      ),
      body: !vm.loaded
          ? const SkeletonList()
          : vm.settings == null
          ? _IntroCard(vm: vm)
          : _SettingsForm(key: const ValueKey('form'), vm: vm),
    );
  }
}

/// Vises før noen leverandør er valgt: kort forklaring + valg av lokal/cloud.
///
/// For et formål med egen profil ([AiPurpose] != [AiPurpose.standard])
/// forklarer kortet at formålet foreløpig bruker standardprofilen.
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.vm});

  final SettingsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final purpose = vm.purpose;
    final isPurpose = purpose != AiPurpose.standard;
    final standard = context.read<SettingsRepository>().loadAiSettings();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isPurpose ? _iconForPurpose(purpose) : Icons.auto_awesome,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPurpose ? 'Ingen egen profil' : 'AI-hjelp',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isPurpose
                      ? '${purpose.label} bruker nå '
                            '${standard == null ? 'ingen AI-profil (ikke konfigurert).' : 'standardprofilen: ${standard.type.label} (${standard.model}).'} '
                            'Opprett en egen profil nedenfor for å bruke annen '
                            'leverandør, modell eller nøkkel for dette formålet.'
                      : 'AI-en er en valgfri hjelpefunksjon. Den kan kjøre lokalt '
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
        // Også før standardprofilen er satt kan man gå inn på et formåls
        // egen profil.
        if (!isPurpose) const _PurposeProfilesCard(),
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
        if (vm.purpose == AiPurpose.standard)
          const _PurposeProfilesCard()
        else
          _DeleteOwnProfileCard(vm: vm),
      ],
    );
  }
}

/// Oversikt over formålsprofilene (bare på standard-skjermen): viser for
/// hvert formål hvilken profil som er i bruk, og gir inngang til å redigere
/// den.
class _PurposeProfilesCard extends StatefulWidget {
  const _PurposeProfilesCard();

  @override
  State<_PurposeProfilesCard> createState() => _PurposeProfilesCardState();
}

class _PurposeProfilesCardState extends State<_PurposeProfilesCard> {
  static const _purposes = [
    AiPurpose.writing,
    AiPurpose.structure,
    AiPurpose.images,
  ];

  SettingsRepository? _repo;

  void _onRepoChanged() {
    // En profil ble endret (muligens fra en formålsrute): les fra nytt.
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<SettingsRepository>();
    if (identical(repo, _repo)) return;
    _repo?.removeListener(_onRepoChanged);
    _repo = repo;
    _repo?.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _repo?.removeListener(_onRepoChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<SettingsRepository>();
    final standard = repo.loadAiSettings();
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Profiler per formål',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Hvert formål kan ha sin egen leverandør, modell og nøkkel. '
                'Uten egen profil brukes standardprofilen.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 13,
                ),
              ),
            ),
            for (final p in _purposes)
              ListTile(
                leading: Icon(_iconForPurpose(p)),
                title: Text(p.label),
                subtitle: Text(_effectiveProfileDescription(p, repo, standard)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/ai/${p.name}'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Hvilken profil [p] faktisk bruker, til tekst i oversikten over profiler.
String _effectiveProfileDescription(
  AiPurpose p,
  SettingsRepository repo,
  AiSettings? standard,
) {
  final own = repo.loadAiProfile(p);
  if (own != null) return 'Egen: ${own.type.label} (${own.model})';
  if (standard != null) {
    return 'Standard: ${standard.type.label} (${standard.model})';
  }
  return 'Ikke konfigurert';
}

/// Fjerne egen profil for formålet, slik at standardprofilen brukes igjen.
class _DeleteOwnProfileCard extends StatelessWidget {
  const _DeleteOwnProfileCard({required this.vm});

  final SettingsViewModel vm;

  Future<void> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fjerne egen profil?'),
        content: Text(
          '«${vm.purpose.label}» vil da bruke standardprofilen. '
          'API-nøkkelen for profilen slettes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Fortsett'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Fjern'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await vm.deleteOwnProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: ListTile(
        leading: const Icon(Icons.delete_outline),
        title: const Text('Fjern egen profil'),
        subtitle: Text('«${vm.purpose.label}» bruker da standardprofilen.'),
        onTap: () => _confirm(context),
      ),
    );
  }
}

/// Ikon for en AI-profilformål i oversikten.
IconData _iconForPurpose(AiPurpose p) {
  switch (p) {
    case AiPurpose.standard:
      return Icons.auto_awesome;
    case AiPurpose.writing:
      return Icons.edit_outlined;
    case AiPurpose.structure:
      return Icons.list_alt;
    case AiPurpose.images:
      return Icons.image_outlined;
  }
}
