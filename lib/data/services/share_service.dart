import 'package:share_plus/share_plus.dart';

/// Tynn innpakning av `share_plus`: deler én fil ut via delingsmenyen.
///
/// Konstruktøren er `const` og tar ingen avhengigheter, slik at den enkelt kan
/// testes ved å bytte ut [SharePlus.instance] (eller kjøre mot et stub-iOS/macOS
/// som returnerer umiddelbart).
class ShareService {
  const ShareService();

  /// Deler filen på [path]. [subject] vises som tittel i delingsmenyen
  /// (f.eks. bokens tittel). Returnerer `false` hvis brukeren avbrøt.
  Future<bool> shareFile(String path, {String? subject}) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: subject),
    );
    return result.status == ShareResultStatus.success;
  }
}
