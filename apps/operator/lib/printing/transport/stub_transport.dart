import 'dart:async';
import 'dart:typed_data';

import 'package:fotoboot_operator/printing/transport/printer_transport.dart';

/// In-memory transport for demos and unit tests (no hardware).
class StubPrinterTransport implements PrinterTransport {
  StubPrinterTransport({
    this.failWith,
    this.delay = Duration.zero,
  });

  /// When set, [send] throws this error (for failure-path demos).
  PrinterException? failWith;
  Duration delay;

  final List<Uint8List> sent = [];
  bool _connected = false;
  PrinterEndpoint? endpoint;

  @override
  String get id => 'stub';

  @override
  String get label => 'Simulador';

  @override
  Future<PrinterConnectionStatus> status() async {
    if (!_connected) return PrinterConnectionStatus.disconnected;
    if (failWith?.code == PrinterErrorCode.noPaper) {
      return PrinterConnectionStatus.noPaper;
    }
    return PrinterConnectionStatus.connected;
  }

  @override
  Future<void> connect(PrinterEndpoint endpoint) async {
    this.endpoint = endpoint;
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> send(Uint8List bytes, {Duration? timeout}) async {
    if (!_connected) {
      throw PrinterException(PrinterErrorCode.disconnected, 'Simulador');
    }
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final err = failWith;
    if (err != null) throw err;
    sent.add(Uint8List.fromList(bytes));
  }
}
