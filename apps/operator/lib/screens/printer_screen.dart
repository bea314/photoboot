import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/printing/print_job_reporter.dart';
import 'package:fotoboot_operator/printing/print_service.dart';
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:fotoboot_operator/printing/printer_settings.dart';
import 'package:fotoboot_operator/printing/sample_image.dart';
import 'package:fotoboot_operator/printing/thermal_test_print.dart';
import 'package:fotoboot_operator/printing/transport/bluetooth_transport.dart';
import 'package:fotoboot_operator/printing/transport/printer_transport.dart';
import 'package:fotoboot_operator/printing/transport/stub_transport.dart';
import 'package:fotoboot_operator/printing/transport/tcp_transport.dart';
import 'package:fotoboot_operator/printing/widgets/print_preview.dart';
import 'package:fotoboot_operator/services/auth_controller.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

/// Gestión → Impresora: profile, device, status, preview, test print.
class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final _settings = PrinterSettingsStore();
  final _printService = PrintService();
  final _testPrint = ThermalTestPrint();
  final _tcpHostController = TextEditingController();
  final _tcpPortController = TextEditingController(text: '9100');

  late final PrintJobReporter _reporter;

  PrinterProfileId _profileId = PrinterProfileId.thermal80;
  String _transportId = 'stub';
  PrinterConnectionStatus _status = PrinterConnectionStatus.unknown;
  PrinterEndpoint? _lastEndpoint;
  bool? _lastTestOk;
  String? _lastTestError;
  bool _busy = false;
  String? _message;
  Uint8List? _sampleBytes;

  @override
  void initState() {
    super.initState();
    _reporter = PrintJobReporter(api: widget.auth.api);
    _sampleBytes = buildSamplePng();
    _load();
  }

  @override
  void dispose() {
    _tcpHostController.dispose();
    _tcpPortController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profileId = await _settings.readActiveProfileId();
    final endpoint = await _settings.readLastEndpoint();
    final host = await _settings.readTcpHost();
    final port = await _settings.readTcpPort();
    final testOk = await _settings.readLastTestOk();
    final testError = await _settings.readLastTestError();

    _tcpHostController.text = host;
    _tcpPortController.text = '$port';

    setState(() {
      _profileId = profileId;
      _lastEndpoint = endpoint ?? PrinterEndpoint.stub;
      _transportId = endpoint?.transportId ?? 'stub';
      _lastTestOk = testOk;
      _lastTestError = testError;
      _status = PrinterConnectionStatus.disconnected;
    });

    // Best-effort: refresh offline print-job queue.
    try {
      await _reporter.flushQueue();
    } catch (_) {}
  }

  PrinterProfile get _profile => PrinterProfile.byId(_profileId);

  PrinterTransport _transportFor(String id) {
    switch (id) {
      case 'tcp':
        return TcpPrinterTransport();
      case 'bluetooth':
        return BluetoothPrinterTransport();
      default:
        return StubPrinterTransport();
    }
  }

  PrinterEndpoint _endpointFor(String transportId) {
    if (transportId == 'tcp') {
      final host = _tcpHostController.text.trim();
      final port = int.tryParse(_tcpPortController.text.trim()) ?? 9100;
      return PrinterEndpoint(
        transportId: 'tcp',
        displayName: host.isEmpty ? 'TCP (sin IP)' : '$host:$port',
        host: host,
        port: port,
      );
    }
    if (transportId == 'bluetooth') {
      return const PrinterEndpoint(
        transportId: 'bluetooth',
        displayName: 'Bluetooth (pendiente)',
      );
    }
    return PrinterEndpoint.stub;
  }

  Future<void> _setProfile(PrinterProfileId id) async {
    await _settings.saveActiveProfileId(id);
    setState(() => _profileId = id);
  }

  Future<void> _setTransport(String id) async {
    final endpoint = _endpointFor(id);
    await _settings.saveLastEndpoint(endpoint);
    if (id == 'tcp') {
      await _settings.saveTcpHost(_tcpHostController.text.trim());
      await _settings.saveTcpPort(
        int.tryParse(_tcpPortController.text.trim()) ?? 9100,
      );
    }
    setState(() {
      _transportId = id;
      _lastEndpoint = endpoint;
      _status = PrinterConnectionStatus.disconnected;
    });
  }

  Future<void> _checkStatus() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final transport = _transportFor(_transportId);
    final endpoint = _endpointFor(_transportId);
    try {
      await transport.connect(endpoint);
      final status = await transport.status();
      await _settings.saveLastEndpoint(endpoint);
      setState(() {
        _status = status;
        _lastEndpoint = endpoint;
        _message = 'Estado: ${status.labelEs}';
      });
    } on PrinterException catch (e) {
      setState(() {
        _status = PrinterConnectionStatus.disconnected;
        _message = e.messageEs;
      });
    } finally {
      await transport.disconnect();
      setState(() => _busy = false);
    }
  }

  Future<void> _runTestPrint() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final transport = _transportFor(_transportId);
    final endpoint = _endpointFor(_transportId);
    await _settings.saveLastEndpoint(endpoint);
    if (_transportId == 'tcp') {
      await _settings.saveTcpHost(_tcpHostController.text.trim());
      await _settings.saveTcpPort(
        int.tryParse(_tcpPortController.text.trim()) ?? 9100,
      );
    }

    final result = await _testPrint.run(
      transport: transport,
      endpoint: endpoint,
      profile: _profile.kind == PrinterKind.thermal
          ? _profile
          : PrinterProfile.byId(PrinterProfileId.thermal80),
      sampleImageBytes: _sampleBytes,
    );

    await _settings.recordTestResult(ok: result.ok, error: result.error);
    await transport.disconnect();

    // Audit as type=test (photoId not required). Event optional if offline.
    try {
      final event = await widget.auth.api.getCurrentEvent();
      await _reporter.report(
        PrintJobReport(
          eventId: event.id,
          printerProfile: _profile.id.apiId,
          copies: 1,
          localStatus: result.ok ? 'printed' : 'failed',
          type: 'test',
          error: result.error,
        ),
      );
    } catch (_) {
      // Offline / no event — local test result still recorded.
    }

    setState(() {
      _busy = false;
      _lastTestOk = result.ok;
      _lastTestError = result.error;
      _status = result.ok
          ? PrinterConnectionStatus.connected
          : PrinterConnectionStatus.error;
      _lastEndpoint = endpoint;
      _message = result.ok
          ? 'Prueba OK (${result.bytesSent} bytes)'
          : result.error;
    });
  }

  Future<void> _runDemoPrint() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final transport = _transportFor(_transportId);
    final endpoint = _endpointFor(_transportId);
    final sample = _sampleBytes ?? buildSamplePng();

    final result = await _printService.printOne(
      photo: PhotoPrintRequest(imageBytes: sample),
      profile: _profile,
      transport: transport,
      endpoint: endpoint,
    );
    await transport.disconnect();

    try {
      final event = await widget.auth.api.getCurrentEvent();
      await _reporter.report(
        PrintJobReport(
          eventId: event.id,
          printerProfile: _profile.id.apiId,
          copies: 1,
          localStatus: result.ok ? 'printed' : 'failed',
          // Demo sample has no server photoId yet (Phase C).
          type: 'test',
          error: result.error,
        ),
      );
    } catch (_) {}

    setState(() {
      _busy = false;
      _message = result.ok
          ? 'Demo impresa (${result.bytesSent} bytes). '
              'Galería usará PrintService.printPhotos cuando C4 esté listo.'
          : result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final warning = _lastTestOk == false;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión · Impresora')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (warning) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _lastTestError ??
                    'La prueba de impresora falló. No imprimas desde galería hasta corregirlo.',
                style: const TextStyle(
                  color: AppColors.redDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'Perfil activo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          ...PrinterProfile.defaults.map((p) {
            final selected = p.id == _profileId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected
                    ? AppColors.red.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _busy ? null : () => _setProfile(p.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: AppColors.red,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                p.frameLabel,
                                style: const TextStyle(color: AppColors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Text(
            'Preview de recorte',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'La misma foto se recorta distinto en térmica 80 mm y 10×15.',
            style: TextStyle(color: AppColors.grey),
          ),
          const SizedBox(height: 16),
          DualPrintPreview(imageBytes: _sampleBytes),
          const SizedBox(height: 12),
          PrintPreviewFrame(
            profile: _profile,
            imageBytes: _sampleBytes,
            height: 260,
          ),
          const SizedBox(height: 28),
          Text(
            'Dispositivo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Último: ${_lastEndpoint?.displayName ?? '—'}',
            style: const TextStyle(color: AppColors.grey, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Estado: ${_status.labelEs}',
            style: TextStyle(
              color: _status.isReady ? AppColors.black : AppColors.redDark,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Simulador'),
                selected: _transportId == 'stub',
                onSelected: _busy ? null : (_) => _setTransport('stub'),
                selectedColor: AppColors.red.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _transportId == 'stub' ? AppColors.red : AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ChoiceChip(
                label: const Text('TCP :9100'),
                selected: _transportId == 'tcp',
                onSelected: _busy ? null : (_) => _setTransport('tcp'),
                selectedColor: AppColors.red.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _transportId == 'tcp' ? AppColors.red : AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ChoiceChip(
                label: const Text('Bluetooth'),
                selected: _transportId == 'bluetooth',
                onSelected: _busy ? null : (_) => _setTransport('bluetooth'),
                selectedColor: AppColors.red.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color:
                      _transportId == 'bluetooth' ? AppColors.red : AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_transportId == 'tcp') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _tcpHostController,
              decoration: const InputDecoration(
                labelText: 'IP de la térmica',
                hintText: '192.168.1.50',
              ),
              keyboardType: TextInputType.number,
              enabled: !_busy,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tcpPortController,
              decoration: const InputDecoration(labelText: 'Puerto'),
              keyboardType: TextInputType.number,
              enabled: !_busy,
            ),
          ],
          if (_transportId == 'bluetooth') ...[
            const SizedBox(height: 12),
            const Text(
              'Bluetooth SPP: interfaz lista; el emparejado real requiere '
              'plugin de plataforma (TODO hardware).',
              style: TextStyle(color: AppColors.grey),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _busy ? null : _checkStatus,
            child: const Text('Comprobar conexión'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _runTestPrint,
            child: const Text('Imprimir prueba'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _runDemoPrint,
            child: const Text('Imprimir foto demo (1)'),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const Center(
              child: CircularProgressIndicator(color: AppColors.red),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(
              _message!,
              style: TextStyle(
                color: warning || _lastTestOk == false
                    ? AppColors.redDark
                    : AppColors.black,
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Text(
            'Desde galería / detalle (Fase C): usa PrintService.printOne / '
            'printPhotos y PrinterSettingsStore.galleryPrintWarning().',
            style: TextStyle(color: AppColors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
