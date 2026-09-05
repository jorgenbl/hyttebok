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
  Future<XFile?> pickFromGallery() =>
      _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

  /// Tar et bilde med kameraet. Ber om kamera-rettighet først; returnerer
  /// `null` hvis rettigheten avslås eller hvis brukeren avbryter.
  Future<XFile?> takePhoto() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return null;
    return _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
  }
}
