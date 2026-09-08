import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/book_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/ai_client.dart';
import '../data/services/file_picker_service.dart';
import '../data/services/image_picker_service.dart';
import '../data/services/secure_key_store.dart';
import '../data/services/share_service.dart';
import '../domain/templates/cabin_template.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_preference.dart';

/// Rot-widget for Hyttebok. Mottar en [BookRepository] (injisert fra `main`
/// eller tester) og bygger router + tema.
///
/// [imagePicker], [share], [filePicker], [cabinTemplates], [settings],
/// [secureKeyStore] og [aiClientBuilder] kan injiseres i tester; i produksjon
/// brukes standardimplementasjonene.
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
          Provider<SettingsRepository>.value(value: settings!),
        Provider<SecureKeyStore>.value(
          value: secureKeyStore ?? FlutterSecureKeyStore(),
        ),
        Provider<AiClientBuilder>.value(
          value:
              aiClientBuilder ??
              ((s, k) => AiClientFactory.create(s, apiKey: k)),
        ),
      ],
      child: const _HyttebokMaterialApp(),
    );
  }
}

/// `MaterialApp` som følger [ThemePreference] (system/lys/mørk).
class _HyttebokMaterialApp extends StatelessWidget {
  const _HyttebokMaterialApp();

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
    );
  }
}
