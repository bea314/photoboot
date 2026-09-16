import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:fotoboot_operator/printing/printer_settings.dart';
import 'package:fotoboot_operator/screens/template_wizard.dart';
import 'package:fotoboot_operator/services/template_store.dart';
import 'package:fotoboot_operator/templates/template_preview.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

/// Gestión hub: plantillas de impresión con biblioteca Hive local (T2 + Corte B).
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key, this.store});

  /// Optional inject for tests; production opens Hive via [TemplateStore.init].
  final TemplateStore? store;

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _settings = PrinterSettingsStore();
  late final TemplateStore _store = widget.store ?? TemplateStore();

  List<PrintTemplate> _templates = const [];
  bool _loadingTemplates = true;
  bool? _lastTestOk;
  String? _endpointLabel;
  String? _profileLabel;
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadPrinterChip(), _loadTemplates()]);
  }

  Future<void> _loadTemplates() async {
    await _store.init();
    if (!mounted) return;
    setState(() {
      _templates = _store.listAll();
      _loadingTemplates = false;
    });
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

  Future<void> _refresh() async {
    await Future.wait([_loadPrinterChip(), _loadTemplates()]);
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

  void _openEditor(PrintTemplate template) {
    context.push('/templates/edit/${template.id}').then((_) {
      if (!mounted) return;
      setState(() => _templates = _store.listAll());
    });
  }

  Future<void> _onUse(PrintTemplate template) async {
    await _store.setActive(template.id);
    if (!mounted) return;
    setState(() => _templates = _store.listAll());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '“${template.name}” activa para ${template.paper.family == PaperFamily.thermal ? 'térmica' : 'foto'}',
        ),
      ),
    );
  }

  Future<void> _onDuplicate(PrintTemplate template) async {
    await _store.duplicate(template.id);
    if (!mounted) return;
    setState(() => _templates = _store.listAll());
  }

  Future<void> _showNewTemplateSheet() async {
    await showNewTemplateWizard(context, store: _store);
    if (!mounted) return;
    setState(() => _templates = _store.listAll());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width > 900 ? 3 : (width > 560 ? 2 : 1);
    final hasActive = _templates.any((t) => t.isActive);

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
        onRefresh: _refresh,
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
            if (!_loadingTemplates && !hasActive && _templates.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Elige una plantilla para imprimir',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
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
            if (_loadingTemplates)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_templates.isEmpty)
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
                        'Elige una plantilla para imprimir',
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
                    childAspectRatio: crossAxisCount == 1 ? 1.2 : 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final t = _templates[index];
                      return _TemplateCard(
                        template: t,
                        onUse: () => _onUse(t),
                        onEdit: () => _openEditor(t),
                        onDuplicate: () => _onDuplicate(t),
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
    required this.template,
    required this.onUse,
    required this.onEdit,
    required this.onDuplicate,
  });

  final PrintTemplate template;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final slots = template.slotCount;
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TemplatePreviewThumb(template: template),
                  if (template.isActive)
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
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
                    '${template.paper.label} · $slots '
                    '${slots == 1 ? 'hueco' : 'huecos'}',
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
                            child: const Text('Usar en este evento'),
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
