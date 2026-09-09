import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Tjenest som abstraherer plukking av bilder fra kamera eller galleri.
///
/// Holdt i datalaget slik at UI-et aldri prater med plugin direkte – og slik
/// at test kan bytte ut metoene med en fake (via underklassing).
class ImagePickerService {
  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Velger et bilde fra galleriet. Returnerer `null` hvis brukeren avbryter.
  ///
  /// På web åpner dette nettleserens filplukker (ingen «galleri»-grensesnitt).
  Future<XFile?> pickFromGallery() =>
      _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

  /// Tar et bilde med kameraet. Ber om kamera-rettighet først; returnerer
  /// `null` hvis rettigheten avslås eller hvis brukeren avbryter.
  ///
  /// På web støttes ikke `permission_handler` (netttleseren ber om tilgang
  /// selv), og `image_picker` har ingen kamera-plugin – vi faller tilbake til
  /// filplukkeren, slik at bildet likevel kan legges inn.
  Future<XFile?> takePhoto() async {
    if (kIsWeb) return pickFromGallery();
    final status = await Permission.camera.request();
    if (!status.isGranted) return null;
    return _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
  }
}
