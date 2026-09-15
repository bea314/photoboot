import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fotoboot_operator/printing/transport/printer_transport.dart';

/// Raw TCP transport for ESC/POS printers listening on IP:9100 (JetDirect).
class TcpPrinterTransport implements PrinterTransport {
  Socket? _socket;
  PrinterEndpoint? _endpoint;

  @override
  String get id => 'tcp';

  @override
  String get label => 'TCP IP:9100';

  @override
  Future<PrinterConnectionStatus> status() async {
    if (_socket == null) return PrinterConnectionStatus.disconnected;
    return PrinterConnectionStatus.connected;
  }

  @override
  Future<void> connect(PrinterEndpoint endpoint) async {
    await disconnect();
    final host = endpoint.host;
    final port = endpoint.port ?? 9100;
    if (host == null || host.isEmpty) {
      throw PrinterException(
        PrinterErrorCode.disconnected,
        'Falta la IP de la impresora',
      );
    }
    try {
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      _endpoint = endpoint;
    } on SocketException catch (e) {
      throw PrinterException(PrinterErrorCode.disconnected, e.message);
    } on TimeoutException {
      throw PrinterException(
        PrinterErrorCode.timeout,
        'No se pudo abrir $host:$port',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    _endpoint = null;
  }

  @override
  Future<void> send(Uint8List bytes, {Duration? timeout}) async {
    final socket = _socket;
    if (socket == null) {
      throw PrinterException(
        PrinterErrorCode.disconnected,
        _endpoint?.displayName,
      );
    }
    try {
      socket.add(bytes);
      await socket.flush().timeout(timeout ?? const Duration(seconds: 15));
    } on TimeoutException {
      throw PrinterException(PrinterErrorCode.timeout);
    } on SocketException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('paper')) {
        throw PrinterException(PrinterErrorCode.noPaper);
      }
      throw PrinterException(PrinterErrorCode.sendFailed, e.message);
    } catch (e) {
      throw PrinterException(PrinterErrorCode.sendFailed, e.toString());
    }
  }
}
