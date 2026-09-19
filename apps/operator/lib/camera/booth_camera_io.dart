import 'dart:io' show Platform;

import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_desktop.dart';
import 'package:fotoboot_operator/camera/booth_camera_mobile.dart';

Stream<void> watchWebCameraPermissionGranted() => const Stream.empty();

Future<BoothCameraResult> openBoothCamera({bool userGesture = false}) {
  if (Platform.isAndroid || Platform.isIOS) {
    return openMobileBoothCamera();
  }
  return openDesktopBoothCamera();
}
