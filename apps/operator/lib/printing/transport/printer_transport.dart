import 'dart:async';
import 'dart:typed_data';

/// High-level connection status for Gestión UI and gallery warnings.
enum PrinterConnectionStatus {
  unknown,
  disconnected,
  connected,
  noPaper,
  error,
}

extension PrinterConnectionStatusLabel on PrinterConnectionStatus {
  String get labelEs {
    switch (this) {
      case PrinterConnectionStatus.unknown:
        return 'Desconocido';
      case PrinterConnectionStatus.disconnected:
        return 'Desconectada';
      case PrinterConnectionStatus.connected:
        return 'Conectada';
      case PrinterConnectionStatus.noPaper:
        return 'Sin papel';
      case PrinterConnectionStatus.error:
        return 'Error';
    }
  }

  bool get isReady => this == PrinterConnectionStatus.connected;
}

/// Typed print failures with Spanish messages for the booth UI.
enum PrinterErrorCode {
  disconnected,
  timeout,
  noPaper,
  coverOpen,
  unsupported,
  sendFailed,
}

class PrinterException implements Exception {
  PrinterException(this.code, [this.detail]);

  final PrinterErrorCode code;
  final String? detail;

  String get messageEs {
    switch (code) {
      case PrinterErrorCode.disconnected:
        return 'Impresora desconectada${detail != null ? ': $detail' : ''}';
      case PrinterErrorCode.timeout:
        return 'Tiempo de espera agotado al imprimir'
            '${detail != null ? ': $detail' : ''}';
      case PrinterErrorCode.noPaper:
        return 'Sin papel en la impresora';
      case PrinterErrorCode.coverOpen:
        return 'Tapa de la impresora abierta';
      case PrinterErrorCode.unsupported:
        return 'Transporte no disponible${detail != null ? ': $detail' : ''}';
      case PrinterErrorCode.sendFailed:
        return 'Error al enviar a la impresora'
            '${detail != null ? ': $detail' : ''}';
    }
  }

  @override
  String toString() => messageEs;
}

/// Endpoint description saved as "last device".
class PrinterEndpoint {
  const PrinterEndpoint({
    required this.transportId,
    required this.displayName,
    this.host,
    this.port,
    this.bluetoothAddress,
  });

  final String transportId; // tcp | bluetooth | stub
  final String displayName;
  final String? host;
  final int? port;
  final String? bluetoothAddress;

  Map<String, dynamic> toJson() => {
        'transportId': transportId,
        'displayName': displayName,
        'host': host,
        'port': port,
        'bluetoothAddress': bluetoothAddress,
      };

  factory PrinterEndpoint.fromJson(Map<String, dynamic> json) {
    return PrinterEndpoint(
      transportId: json['transportId'] as String? ?? 'stub',
      displayName: json['displayName'] as String? ?? 'Desconocido',
      host: json['host'] as String?,
      port: json['port'] as int?,
      bluetoothAddress: json['bluetoothAddress'] as String?,
    );
  }

  static const stub = PrinterEndpoint(
    transportId: 'stub',
    displayName: 'Simulador (sin hardware)',
  );
}

/// Sends raw ESC/POS (or other) bytes to a local printer.
abstract class PrinterTransport {
  String get id;
  String get label;

  Future<PrinterConnectionStatus> status();

  /// Open / ensure connection. Throws [PrinterException] on failure.
  Future<void> connect(PrinterEndpoint endpoint);

  Future<void> disconnect();

  /// Send [bytes]. Throws typed [PrinterException] on failure.
  Future<void> send(Uint8List bytes, {Duration? timeout});
}
