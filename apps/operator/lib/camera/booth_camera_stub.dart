import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';

const bool kBoothCameraSupported = false;

Future<BoothCameraPermission> requestBoothCameraPermission() async {
  return BoothCameraPermission.unsupported;
}

Future<BoothCameraOpenResult> openBoothCamera({
  bool fromUserGesture = false,
}) async {
  return BoothCameraOpenResult(
    permission: BoothCameraPermission.unsupported,
    error: BoothCameraMessages.forPermission(BoothCameraPermission.unsupported),
  );
}
