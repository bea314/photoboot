import 'package:flutter/material.dart';
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:fotoboot_operator/printing/printer_settings.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

/// Placeholder card model for the Gestión hub (T1).
/// Real JSON persistence / seed arrives in T2.
class _TemplateCardData {
  const _TemplateCardData({
    required this.name,
    required this.paperLabel,
    required this.slotCount,
    required this.isActive,
  });

  final String name;
  final String paperLabel;
  final int slotCount;
  final bool isActive;
}

/// Gestión hub: plantillas de impresión (no transporte / test print).
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _settings = PrinterSettingsStore();

  /// UI placeholders until T2 seeds real local templates.
  final _templates = <_TemplateCardData>[
    const _TemplateCardData(
      name: 'Térmica 80 mm · a sangre',
      paperLabel: 'Térmica 80 mm',
      slotCount: 1,
      isActive: true,
    ),
    const _TemplateCardData(
      name: 'Foto 10×15 · center-crop',
      paperLabel: '10×15 cm',
      slotCount: 1,
      isActive: true,
    ),
  ];

  bool? _lastTestOk;
  String? _endpointLabel;
  String? _profileLabel;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _loadPrinterChip();
  }

  Future<void> _loadPrinterChip() async {
    final profileId = await _settings.readActiveProfileId();
    final endpoint = await _settings.readLastEndpoint();
    final testOk = await _settings.readLastTestOk();
    if (!mounted) return;
    setState(() {
      _profileLabel = PrinterProfile.byId(profileId).label;
      _endpointLabel = endpoint?.displayName;
      _lastTestOk = testOk;
      _loadingStatus = false;
    });
  }

  String get _chipLabel {
    if (_loadingStatus) return 'Impresora…';
    if (_lastTestOk == false) return 'Impresora: error';
    if (_lastTestOk == true) {
      return _endpointLabel == null || _endpointLabel!.isEmpty
          ? 'Impresora OK'
          : 'Impresora: $_endpointLabel';
    }
    return _profileLabel == null
        ? 'Impresora · Avanzado'
        : '$_profileLabel · Avanzado';
  }

  Color get _chipFg {
    if (_lastTestOk == false) return AppColors.redDark;
    if (_lastTestOk == true) return AppColors.black;
    return AppColors.grey;
  }

  void _openAdvanced() => context.go('/templates/printer');

  void _showComingSoon(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action — disponible en el siguiente corte')),
    );
  }

  Future<void> _showNewTemplateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nueva plantilla',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El asistente y el editor llegan en cortes siguientes. '
                  'Por ahora solo eliges el papel.',
                  style: TextStyle(color: AppColors.grey, fontSize: 15),
                ),
                const SizedBox(height: 20),
                ...PrinterProfile.defaults.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _templates.insert(
                              0,
                              _TemplateCardData(
                                name: 'Plantilla ${p.frameLabel}',
                                paperLabel: p.label,
                                slotCount: 1,
                                isActive: false,
                              ),
                            );
                          });
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Plantilla de ${p.label} añadida (local, sin guardar aún)',
                              ),
                            ),
                          );
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            p.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 900 ? 3 : (width > 560 ? 2 : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantillas'),
        actions: [
          IconButton(
            tooltip: 'Avanzado · Impresora',
            onPressed: _openAdvanced,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewTemplateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Nueva plantilla'),
      ),
      body: RefreshIndicator(
        color: AppColors.red,
        onRefresh: _loadPrinterChip,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: Icon(
                      _lastTestOk == false
                          ? Icons.print_disabled_outlined
                          : Icons.print_outlined,
                      color: _chipFg,
                      size: 20,
                    ),
                    label: Text(
                      _chipLabel,
                      style: TextStyle(
                        color: _chipFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _openAdvanced,
                    backgroundColor: _lastTestOk == false
                        ? AppColors.red.withValues(alpha: 0.12)
                        : AppColors.surface,
                    side: BorderSide(
                      color: _lastTestOk == false
                          ? AppColors.red
                          : AppColors.grey.withValues(alpha: 0.35),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            if (_lastTestOk == false)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Material(
                    color: AppColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openAdvanced,
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: AppColors.redDark),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'La prueba de impresora falló. Revísala en Avanzado.',
                                style: TextStyle(
                                  color: AppColors.redDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.redDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_templates.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.dashboard_customize_outlined,
                        size: 64,
                        color: AppColors.grey.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Aún no hay plantillas para este evento',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Crea una plantilla genérica para empezar a imprimir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _showNewTemplateSheet,
                        child: const Text('Crear plantilla'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: crossAxisCount == 1 ? 1.35 : 0.92,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final t = _templates[index];
                      return _TemplateCard(
                        data: t,
                        onUse: () => _showComingSoon('Usar en este evento'),
                        onEdit: () => _showComingSoon(
                          'Editar (editor en Corte B)',
                        ),
                        onDuplicate: () {
                          setState(() {
                            _templates.insert(
                              index + 1,
                              _TemplateCardData(
                                name: '${t.name} (copia)',
                                paperLabel: t.paperLabel,
                                slotCount: t.slotCount,
                                isActive: false,
                              ),
                            );
                          });
                        },
                      );
                    },
                    childCount: _templates.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.data,
    required this.onUse,
    required this.onEdit,
    required this.onDuplicate,
  });

  final _TemplateCardData data;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 1,
      shadowColor: AppColors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: AppColors.surface,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _PaperPreviewPainter()),
                    if (data.isActive)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Activa',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.paperLabel} · ${data.slotCount} '
                    '${data.slotCount == 1 ? 'hueco' : 'huecos'}',
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: onUse,
                            child: const Text('Usar'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton.outlined(
                          tooltip: 'Editar',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton.outlined(
                          tooltip: 'Duplicar',
                          onPressed: onDuplicate,
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = AppColors.red.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fill = Paint()..color = AppColors.white;
    final margin = size.shortestSide * 0.12;
    final rect = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, border);

    final slot = Rect.fromLTWH(
      rect.left + rect.width * 0.08,
      rect.top + rect.height * 0.08,
      rect.width * 0.84,
      rect.height * 0.84,
    );
    final slotPaint = Paint()
      ..color = AppColors.red.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final slotBorder = Paint()
      ..color = AppColors.red.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(slot, const Radius.circular(4)),
      slotPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(slot, const Radius.circular(4)),
      slotBorder,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
