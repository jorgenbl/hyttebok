import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/book_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/ai_client.dart';
import '../data/services/ai_image_client.dart';
import '../data/services/file_picker_service.dart';
import '../data/services/image_picker_service.dart';
import '../data/services/secure_key_store.dart';
import '../data/services/share_service.dart';
import '../data/services/speech_to_text_service.dart';
import '../domain/templates/cabin_template.dart';
import '../ui/features/onboarding/onboarding.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_preference.dart';

/// Rot-widget for Hyttebok. Mottar en [BookRepository] (injisert fra `main`
/// eller tester) og bygger router + tema.
///
/// [imagePicker], [share], [filePicker], [cabinTemplates], [settings],
/// [secureKeyStore], [aiClientBuilder], [aiImageClientBuilder] og
/// [speechToText] kan injiseres i tester; i produksjon brukes
/// standardimplementasjonene.
class HyttebokApp extends StatelessWidget {
  const HyttebokApp({
    super.key,
    required this.repository,
    this.imagePicker,
    this.share,
    this.filePicker,
    this.cabinTemplates,
    this.settings,
    this.secureKeyStore,
    this.aiClientBuilder,
    this.aiImageClientBuilder,
    this.speechToText,
  });

  final BookRepository repository;
  final ImagePickerService? imagePicker;
  final ShareService? share;
  final FilePickerService? filePicker;

  /// Tilgjengelige maler for «Ny hytte fra mal». Standard: [standardCabinTemplates].
  final List<CabinTemplate>? cabinTemplates;

  /// App-innstillinger (AI). Må settes i produksjon og AI-tester; uten den
  /// er ikke AI-funksjonene tilgjengelige.
  final SettingsRepository? settings;
  final SecureKeyStore? secureKeyStore;
  final AiClientBuilder? aiClientBuilder;
  final AiImageClientBuilder? aiImageClientBuilder;

  /// Tale-diktering i editoren. Standard: [SpeechToTextService].
  final SpeechToTextService? speechToText;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BookRepository>.value(value: repository),
        Provider<ImagePickerService>.value(
          value: imagePicker ?? ImagePickerService(),
        ),
        Provider<ShareService>.value(value: share ?? const ShareService()),
        Provider<FilePickerService>.value(
          value: filePicker ?? const FilePickerService(),
        ),
        Provider<List<CabinTemplate>>.value(
          value: cabinTemplates ?? standardCabinTemplates,
        ),
        ChangeNotifierProvider<ThemePreference>(
          create: (_) => ThemePreference(),
        ),
        if (settings != null)
          ChangeNotifierProvider<SettingsRepository>.value(value: settings!),
        Provider<SecureKeyStore>.value(
          value: secureKeyStore ?? FlutterSecureKeyStore(),
        ),
        Provider<AiClientBuilder>.value(
          value:
              aiClientBuilder ??
              ((s, k) => AiClientFactory.create(s, apiKey: k)),
        ),
        Provider<AiImageClientBuilder>.value(
          value:
              aiImageClientBuilder ??
              ((s, k) => AiImageClientFactory.create(s, apiKey: k)),
        ),
        Provider<SpeechToTextService>.value(
          value: speechToText ?? SpeechToTextService(),
        ),
      ],
      child: _HyttebokMaterialApp(settings: settings),
    );
  }
}

/// `MaterialApp` som følger [ThemePreference] (system/lys/mørk).
class _HyttebokMaterialApp extends StatelessWidget {
  const _HyttebokMaterialApp({this.settings});

  /// Trengs for velkomst-opplæringens flagg; uten (f.eks. i enkle tester)
  /// vises ingen opplæring.
  final SettingsRepository? settings;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemePreference>().mode;
    return MaterialApp.router(
      title: 'Hyttebok',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: buildRouter(),
      builder: (context, child) =>
          _OnboardingGate(settings: settings, child: child!),
    );
  }
}

/// Viser [OnboardingView] første gang appen kjøres; etterpå bygges appen
/// direkte. Flagget ligger i innstillingslagringen ([SettingsRepository]);
/// uten den (f.eks. i enkle tester) hoppes opplæringen over.
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate({this.settings, required this.child});

  final SettingsRepository? settings;
  final Widget child;

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.settings?.hasSeenOnboarding() == false;
  }

  Future<void> _finish() async {
    await widget.settings?.markOnboardingSeen();
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOnboarding) return widget.child;
    return OnboardingView(onFinish: _finish);
  }
}
