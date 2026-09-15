import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:fotoboot_operator/printing/transport/printer_transport.dart';

/// Persists active profile, last endpoint, and last test-print outcome.
class PrinterSettingsStore {
  PrinterSettingsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _profileKey = 'fotoboot_printer_profile';
  static const _endpointKey = 'fotoboot_printer_endpoint';
  static const _testOkKey = 'fotoboot_printer_test_ok';
  static const _testAtKey = 'fotoboot_printer_test_at';
  static const _testErrorKey = 'fotoboot_printer_test_error';
  static const _tcpHostKey = 'fotoboot_printer_tcp_host';
  static const _tcpPortKey = 'fotoboot_printer_tcp_port';

  final FlutterSecureStorage _storage;

  Future<PrinterProfileId> readActiveProfileId() async {
    final raw = await _storage.read(key: _profileKey);
    if (raw == null || raw.isEmpty) return PrinterProfileId.thermal80;
    return PrinterProfileId.fromApiId(raw);
  }

  Future<void> saveActiveProfileId(PrinterProfileId id) {
    return _storage.write(key: _profileKey, value: id.apiId);
  }

  Future<PrinterEndpoint?> readLastEndpoint() async {
    final raw = await _storage.read(key: _endpointKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PrinterEndpoint.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastEndpoint(PrinterEndpoint endpoint) {
    return _storage.write(
      key: _endpointKey,
      value: jsonEncode(endpoint.toJson()),
    );
  }

  Future<String> readTcpHost() async =>
      (await _storage.read(key: _tcpHostKey)) ?? '';

  Future<void> saveTcpHost(String host) =>
      _storage.write(key: _tcpHostKey, value: host);

  Future<int> readTcpPort() async {
    final raw = await _storage.read(key: _tcpPortKey);
    return int.tryParse(raw ?? '') ?? 9100;
  }

  Future<void> saveTcpPort(int port) =>
      _storage.write(key: _tcpPortKey, value: '$port');

  /// `true` = last test succeeded, `false` = failed, `null` = never tested.
  Future<bool?> readLastTestOk() async {
    final raw = await _storage.read(key: _testOkKey);
    if (raw == null) return null;
    return raw == '1';
  }

  Future<String?> readLastTestError() => _storage.read(key: _testErrorKey);

  Future<DateTime?> readLastTestAt() async {
    final raw = await _storage.read(key: _testAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> recordTestResult({required bool ok, String? error}) async {
    await _storage.write(key: _testOkKey, value: ok ? '1' : '0');
    await _storage.write(
      key: _testAtKey,
      value: DateTime.now().toIso8601String(),
    );
    if (ok) {
      await _storage.delete(key: _testErrorKey);
    } else if (error != null) {
      await _storage.write(key: _testErrorKey, value: error);
    }
  }

  /// Red warning path for gallery (Phase C can read this).
  Future<String?> galleryPrintWarning() async {
    final ok = await readLastTestOk();
    if (ok == false) {
      final err = await readLastTestError();
      return err ?? 'La prueba de impresora falló. Revisa Gestión → Impresora.';
    }
    return null;
  }
}
