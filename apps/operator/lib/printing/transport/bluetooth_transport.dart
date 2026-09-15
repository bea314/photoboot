import 'dart:typed_data';

import 'package:fotoboot_operator/printing/transport/printer_transport.dart';

/// Bluetooth SPP placeholder.
///
/// Real pairing needs platform plugins (`flutter_blue_plus` / classic SPP).
/// This stub keeps the interface ready and returns readable errors until
/// hardware wiring lands with Phase D2 device testing.
class BluetoothPrinterTransport implements PrinterTransport {
  PrinterEndpoint? _endpoint;
  bool _connected = false;

  @override
  String get id => 'bluetooth';

  @override
  String get label => 'Bluetooth SPP';

  @override
  Future<PrinterConnectionStatus> status() async {
    if (!_connected) return PrinterConnectionStatus.disconnected;
    return PrinterConnectionStatus.connected;
  }

  @override
  Future<void> connect(PrinterEndpoint endpoint) async {
    // TODO(phase-d2-hw): wire flutter_blue_plus / classic Bluetooth SPP.
    _endpoint = endpoint;
    _connected = false;
    throw PrinterException(
      PrinterErrorCode.unsupported,
      'Bluetooth SPP aún no integrado en este build. '
      'Usa TCP IP:9100 o el simulador.',
    );
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _endpoint = null;
  }

  @override
  Future<void> send(Uint8List bytes, {Duration? timeout}) async {
    if (!_connected || _endpoint == null) {
      throw PrinterException(
        PrinterErrorCode.disconnected,
        'Bluetooth no conectado',
      );
    }
    throw PrinterException(
      PrinterErrorCode.unsupported,
      'Envío Bluetooth pendiente de SDK',
    );
  }
}
