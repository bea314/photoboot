import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';

/// Escritorio (macOS / Windows / Linux): sin preview en vivo.
/// Usa [ImagePicker] desde la pantalla de cámara.
Future<BoothCameraResult> openDesktopBoothCamera() async {
  return const BoothCameraResult(
    status: BoothCameraStatus.unsupported,
    message: BoothCameraMessages.desktopHint,
  );
}
