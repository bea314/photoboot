import 'package:fotoboot_operator/camera/booth_camera.dart';

/// Textos de la pantalla de cámara.
abstract final class BoothCameraMessages {
  static const pickPhoto = 'Elegir foto';
  static const activateCamera = 'Activar cámara';
  static const retry = 'Reintentar';

  static const idle =
      'Pulsa Activar cámara. El navegador pedirá permiso en esta pestaña.';

  static const unsupported =
      'La cámara en vivo no está disponible en esta plataforma.';

  static const desktopHint =
      'En escritorio usa Elegir foto para tomar o subir una imagen.';

  static const notFound = 'No se encontró ninguna cámara.';

  static const denied =
      'Permiso denegado. En la barra de dirección (🔒), permite Cámara para este sitio.';

  /// `Permission denied by system`: el sitio tiene permiso pero macOS niega el
  /// hardware. Con `flutter run -d chrome`, Chrome lo lanza Terminal/Cursor:
  /// hay que activar Cámara también para Cursor (o Terminal/iTerm), no solo
  /// para Google Chrome. Ver README → Cámara en web.
  static const systemDenied =
      'macOS bloqueó la cámara (Permission denied by system). '
      'Ajustes del Sistema → Privacidad → Cámara → activa Cursor y Google Chrome. '
      'Cierra Chrome (Cmd+Q), reinicia flutter run y pulsa Activar cámara.';

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
