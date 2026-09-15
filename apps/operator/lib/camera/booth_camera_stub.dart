import 'package:fotoboot_operator/camera/booth_camera.dart';

const bool kBoothCameraSupported = false;

Future<BoothCameraPermission> requestBoothCameraPermission() async {
  return BoothCameraPermission.unsupported;
}

Future<BoothCameraOpenResult> openBoothCamera() async {
  return const BoothCameraOpenResult(
    permission: BoothCameraPermission.unsupported,
    error: 'La cámara nativa se conectará cuando elijamos plataforma.',
  );
}
