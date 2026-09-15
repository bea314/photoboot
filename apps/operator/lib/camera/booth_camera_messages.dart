import 'package:fotoboot_operator/camera/booth_camera.dart';

/// Textos de cámara en un solo lugar (UI + implementación web).
abstract final class BoothCameraMessages {
  static const pickPhoto = 'Elegir foto';
  static const activateCamera = 'Activar cámara';
  static const retry = 'Reintentar';

  static const webIdleHint =
      'Pulsa Activar cámara. Usa siempre la misma URL (mismo puerto y localhost).';

  static const unsupportedBuild =
      'Esta build está preparada para probar en web.';

  static const openFailedRetry =
      'No se pudo abrir la cámara. Pulsa Activar cámara para reintentar.';

  static const openFailedBusy =
      'No se pudo abrir la cámara. Cierra otras pestañas que la usen y pulsa Activar cámara otra vez.';

  static const unexpectedOpenError = 'Error inesperado al abrir la cámara';

  static String forPermission(BoothCameraPermission permission) {
    return switch (permission) {
      BoothCameraPermission.denied =>
        'El navegador bloqueó la cámara. En la barra de dirección (🔒), permite Cámara para este sitio y pulsa Activar cámara.',
      BoothCameraPermission.notFound => 'No hay cámara en este equipo.',
      BoothCameraPermission.prompt =>
        'Pulsa Activar cámara. Si el navegador pregunta, elige Permitir.',
      BoothCameraPermission.unsupported =>
        'La cámara web no está disponible en esta compilación.',
      BoothCameraPermission.granted => '',
    };
  }

  static String enableLabel(BoothCameraPermission permission) {
    return permission == BoothCameraPermission.denied ? retry : activateCamera;
  }
}
