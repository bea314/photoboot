import 'package:fotoboot_operator/camera/booth_camera.dart';

/// Textos de la pantalla de cámara.
abstract final class BoothCameraMessages {
  static const pickPhoto = 'Elegir foto';
  static const activateCamera = 'Activar cámara';
  static const retry = 'Reintentar';

  static const idle =
      'Pulsa Activar cámara. Chrome pedirá permiso en esta pestaña.';

  static const unsupported =
      'La cámara no está disponible en esta plataforma.';

  static const notFound = 'No se encontró ninguna cámara.';

  static const denied =
      'Permiso denegado. En la barra de dirección (🔒), permite Cámara para este sitio.';

  static const insecureContext =
      'La cámara web solo funciona en localhost o HTTPS.';

  static const openFailed =
      'No se pudo abrir la cámara. Pulsa Activar cámara para reintentar.';

  static const busy =
      'La cámara está ocupada por otra app o pestaña (FaceTime, Zoom, Meet, '
      'Photo Booth...). Ciérrala y vuelve a pulsar Activar cámara.';

  static const unexpected = 'Error inesperado al abrir la cámara.';

  static String buttonLabel(BoothCameraStatus status) {
    return status == BoothCameraStatus.denied ? retry : activateCamera;
  }
}
