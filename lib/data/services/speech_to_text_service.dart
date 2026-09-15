import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Kastet av [SpeechToTextService] når diktering ikke kan gjennomføres
/// (manglende mikrofon-rettighet eller utilgjengelig talegjenkjenning).
/// Meldingen er brukerredd og kan vises direkte i et snackbar.
class DictationException implements Exception {
  const DictationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Tjenest som abstraherer tale-diktering (stemme → tekst) for editoren.
///
/// Holdt i datalaget slik at UI-et aldri prater med plugin direkte – og slik
/// at test kan bytte ut metoden med en fake (via underklassing). [listen]
/// returnerer den anerkjente teksten, eller `null` hvis brukeren ikke sa
/// noe. Rettighets-/init-feil kastes som [DictationException].
class SpeechToTextService {
  SpeechToTextService({SpeechToText? speechToText})
    : _speech = speechToText ?? SpeechToText();

  final SpeechToText _speech;

  /// Gjenkjenningssesjonens maksimale slutt; lengre enn noensinne snakket.
  static const _sessionTimeout = Duration(minutes: 2);

  /// Maks pause uten tale før sesjonen avsluttes automatisk.
  static const _pauseFor = Duration(seconds: 8);

  /// Akkumulerer det siste del-resultatet, slik at en avbrutt/tiden-ut-
  /// sesjon likevel kan gi tilbake det som ble fanget.
  String? _partial;

  /// Fullfører [listen]-future når den endelige teksten (eller «done»)
  /// kommer. Én aktiv sesjon ad gangen.
  Completer<String?>? _completer;

  /// Kjører en dikteringsøkt og returnerer den anerkjente teksten.
  ///
  /// Returnerer `null` hvis brukeren ikke sa noe. Kaster [DictationException]
  /// hvis mikrofon-rettigheten ikke er gitt, eller hvis talegjenkjenning
  /// ikke er tilgjengelig på enheten.
  Future<String?> listen() async {
    if (!await _speech.hasPermission) {
      throw const DictationException(
        'Mikrofon-tillatelse er ikke gitt. Tillat tilgang i enhetens '
        'innstillinger.',
      );
    }

    // Initialiseres kun én gang; status- og feil-lytterne er da fastkoblet
    // til denne tjeneste-instansen (enkel-instans for appens levetid).
    final ready = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
    if (!ready) {
      throw const DictationException(
        'Talegjenkjenning er ikke tilgjengelig på denne enheten.',
      );
    }

    final locale = await _pickLocale();
    _partial = null;
    final completer = Completer<String?>();
    _completer = completer;

    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        pauseFor: _pauseFor,
        localeId: locale,
        listenMode: ListenMode.dictation,
      ),
    );

    final result = await completer.future.timeout(
      _sessionTimeout,
      onTimeout: () {
        unawaited(_speech.stop());
        return _finish();
      },
    );
    _completer = null;
    return result;
  }

  /// Stopper en pågående sesjon (f.eks. når editoren lukkes midt i
  /// diktering). Pluginen sender da et endelig resultat, som fullfører den
  /// ventende [listen].
  Future<void> stop() => _speech.stop();

  /// Velger språk for gjenkjenningen: foretrekker norsk bokmål (`nb-NO`),
  /// faller tilbake til andre nb-/no-varianter, ellers `nb-NO`.
  Future<String> _pickLocale() async {
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        if (locale.localeId == 'nb-NO') return 'nb-NO';
      }
      for (final locale in locales) {
        final id = locale.localeId;
        if (id.startsWith('nb') || id.startsWith('no')) return id;
      }
    } catch (_) {
      // Liste over lokaler utilgjengelig – bruk standardspråket.
    }
    return 'nb-NO';
  }

  void _onResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      _partial = result.recognizedWords;
      _complete(_finish());
    } else {
      _partial = result.recognizedWords;
    }
  }

  void _onStatus(String status) {
    // 'done' betyr at sesjonen er slutt (inkl. når brukeren ikke sa noe).
    if (status == SpeechToText.doneStatus) {
      _complete(_finish());
    }
  }

  void _onError(SpeechRecognitionError error) {
    // Feil avslutter sesjonen; gi tilbake det som ble fanget (eventuelt null).
    _complete(_finish());
  }

  String? _finish() {
    final text = _partial?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  void _complete(String? value) {
    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }
}
