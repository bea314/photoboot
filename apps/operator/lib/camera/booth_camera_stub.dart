import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';

Future<BoothCameraResult> openBoothCamera({bool userGesture = false}) async {
  return const BoothCameraResult(
    status: BoothCameraStatus.unsupported,
    message: BoothCameraMessages.unsupported,
  );
}

Stream<void> watchWebCameraPermissionGranted() => const Stream.empty();
