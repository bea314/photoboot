import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fotoboot_operator/services/api_client.dart';
import 'package:fotoboot_operator/services/auth_controller.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  EventInfo? _event;
  String? _error;
  bool _loading = true;
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final event = await widget.auth.api.getCurrentEvent();
      _nameController.text = event.name;
      _slugController.text = event.slug;
      setState(() {
        _event = event;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo cargar el evento';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final event = _event;
    if (event == null) return;
    setState(() => _loading = true);
    try {
      final updated = await widget.auth.api.updateEvent(
        event.id,
        name: _nameController.text.trim(),
        slug: _slugController.text.trim(),
      );
      setState(() {
        _event = updated;
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento actualizado')),
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _copyLink() async {
    final url = _event?.publicUrl;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado')),
    );
  }

  void _openQr() {
    final url = _event?.publicUrl;
    if (url == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => QrFullscreenPage(url: url),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.auth.logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evento / QR'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading && _event == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : _error != null && _event == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      _event?.name ?? '',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.red,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _event?.publicUrl ?? '',
                      style: const TextStyle(color: AppColors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _slugController,
                      decoration: const InputDecoration(
                        labelText: 'Slug',
                        helperText: 'ej. boda-ana-2026',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.redDark),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _save,
                      child: const Text('Guardar'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _copyLink,
                      child: const Text('Copiar link'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _openQr,
                      child: const Text('Ver QR a pantalla completa'),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: QrImageView(
                        data: _event?.publicUrl ?? '',
                        size: 200,
                        backgroundColor: AppColors.white,
                      ),
                    ),
                  ],
                ),
    );
  }
}

class QrFullscreenPage extends StatelessWidget {
  const QrFullscreenPage({super.key, required this.url});

  final String url;

  static const double _maxQrSide = 420;
  static const double _minQrSide = 160;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('QR del evento'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Reserva espacio para padding + URL debajo del QR.
            const verticalChrome = 24.0 * 2 + 24.0 + 56.0;
            final availableWidth = constraints.maxWidth - 48;
            final availableHeight = constraints.maxHeight - verticalChrome;
            final side = [
              availableWidth,
              availableHeight,
              _maxQrSide,
            ].reduce((a, b) => a < b ? a : b).clamp(_minQrSide, _maxQrSide);

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: side,
                          maxHeight: side,
                        ),
                        child: QrImageView(
                          data: url,
                          size: side,
                          backgroundColor: AppColors.white,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    url,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
