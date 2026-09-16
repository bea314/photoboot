import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/services/api_client.dart';
import 'package:fotoboot_operator/services/photo_controller.dart';
import 'package:fotoboot_operator/services/template_store.dart';
import 'package:fotoboot_operator/templates/editor/template_editor_canvas.dart';
import 'package:fotoboot_operator/templates/editor/template_editor_controller.dart';
import 'package:fotoboot_operator/templates/editor/template_layer_list.dart';
import 'package:fotoboot_operator/templates/editor/template_layer_props.dart';
import 'package:fotoboot_operator/templates/template_composer.dart';
import 'package:fotoboot_operator/templates/template_tokens.dart';
import 'package:fotoboot_operator/templates/template_validation.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Full-bleed template editor (Corte B).
class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({
    super.key,
    required this.templateId,
    this.store,
    this.photos,
    this.api,
    this.promptDrawSlots = false,
  });

  final String templateId;
  final TemplateStore? store;
  final PhotoController? photos;
  final ApiClient? api;

  /// Mode A: show tip to draw slots after open.
  final bool promptDrawSlots;

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TemplateStore _store = widget.store ?? TemplateStore();
  TemplateEditorController? _controller;
  Timer? _autosave;
  Map<String, ui.Image?> _assets = {};
  List<ui.Image?> _previewPhotos = [];
  TemplatePrintContext _printContext = TemplatePrintContext.fromEvent(
    eventName: 'Fotoboot',
  );
  String? _loadError;
  bool _loading = true;
  late final TabController _sheetTabs;

  @override
  void initState() {
    super.initState();
    _sheetTabs = TabController(length: 3, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _controller?.removeListener(_onEditorChanged);
    _controller?.dispose();
    _sheetTabs.dispose();
    for (final a in _assets.values) {
      a?.dispose();
    }
    for (final p in _previewPhotos) {
      p?.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await _store.init();
      final template = _store.getById(widget.templateId);
      if (template == null) {
        setState(() {
          _loading = false;
          _loadError = 'No se encontró la plantilla';
        });
        return;
      }

      final controller = TemplateEditorController(initial: template);
      controller.addListener(_onEditorChanged);

      EventInfo? event;
      try {
        final api = widget.api ?? widget.photos?.api;
        if (api != null) {
          event = await api.getCurrentEvent();
        }
      } catch (_) {}

      final assetBytes = await _store.loadAssetsFor(template);
      final decoded = await decodeTemplateAssets(assetBytes);
      final preview = await _loadGalleryPreviewPhotos();

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _assets = decoded;
        _previewPhotos = preview;
        _printContext = TemplatePrintContext.fromEvent(
          eventName: event?.name ?? 'Fotoboot',
          eventUrl: event?.publicUrl,
        );
        _loading = false;
      });

      if (widget.promptDrawSlots) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          controller.setDrawSlotMode(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dibuja los huecos donde deben ir las fotos'),
            ),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudo abrir el editor';
      });
    }
  }

  void _onEditorChanged() {
    final c = _controller;
    if (c == null || !c.dirty) return;
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 700), _autosaveNow);
    // Jump to props when selecting a layer on phone sheet.
    if (c.selectedLayerId != null && _sheetTabs.index != 2) {
      // only on narrow layouts handled in build via listener side-effect — skip
    }
    setState(() {});
  }

  Future<void> _autosaveNow() async {
    final c = _controller;
    if (c == null || !c.dirty) return;
    c.markSaving();
    try {
      await _store.upsert(c.template);
      c.markSaved();
    } catch (_) {
      c.markSaveError('Sin guardar — reintentar');
    }
  }

  Future<List<ui.Image?>> _loadGalleryPreviewPhotos() async {
    final photos = widget.photos?.photos ?? const [];
    final out = <ui.Image?>[];
    final take = photos.take(6);
    for (final photo in take) {
      final bytes = await widget.photos?.files.readBest(photo.clientPhotoId);
      if (bytes == null) {
        out.add(null);
        continue;
      }
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        out.add(frame.image);
      } catch (_) {
        out.add(null);
      }
    }
    return out;
  }

  Future<void> _save({bool activate = false}) async {
    final c = _controller;
    if (c == null) return;
    await _autosaveNow();
    if (activate) {
      final issues = TemplateValidation.activateIssues(c.template);
      final errors =
          issues.where((i) => i.severity == TemplateIssueSeverity.error);
      if (errors.isNotEmpty) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No se puede activar aún'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in errors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${e.message}'),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        return;
      }
      await _store.setActive(c.template.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${c.template.name}” — Usar en este evento')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plantilla guardada')),
      );
    }
  }

  Future<void> _pickImageForSelected({bool asBackground = false}) async {
    final c = _controller;
    if (c == null) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 4000,
      maxHeight: 4000,
      imageQuality: 92,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final key = await _store.assets.putBytes(Uint8List.fromList(bytes));
    final decoded = await decodeTemplateAssets({key: Uint8List.fromList(bytes)});
    setState(() {
      _assets = {..._assets, ...decoded};
    });

    if (asBackground) {
      final existing = c.template.layers
          .where((l) => l.type == TemplateLayerType.background)
          .toList();
      if (existing.isNotEmpty) {
        c.updateLayer(existing.first.copyWith(assetKey: key, locked: true));
        c.selectLayer(existing.first.id);
      } else {
        final bg = c.newBackground(assetKey: key);
        // Put background at bottom.
        c.replaceTemplate(
          c.template.copyWith(layers: [bg, ...c.template.layers]),
        );
        c.selectLayer(bg.id);
      }
    } else {
      final selected = c.selectedLayer;
      if (selected != null &&
          (selected.type == TemplateLayerType.image ||
              selected.type == TemplateLayerType.background)) {
        c.updateLayer(selected.copyWith(assetKey: key));
      } else {
        c.addLayer(c.newImage(assetKey: key));
      }
    }
  }

  Future<void> _showPreview() async {
    final c = _controller;
    if (c == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Vista previa',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.template.slotCount == 0
                        ? 'Sin huecos — solo fondo / capas fijas'
                        : 'Fotos de galería en los huecos (no imprime desde aquí)',
                    style: const TextStyle(color: AppColors.grey),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TemplatePrintPreview(
                      template: c.template,
                      contextData: _printContext,
                      photos: _previewPhotos,
                      assets: _assets,
                      height: 480,
                      showSlotLabels: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLeave() async {
    final c = _controller;
    if (c != null && c.dirty) {
      await _autosaveNow();
    }
    if (!mounted) return;
    context.pop();
  }

  String get _autosaveLabel {
    final c = _controller;
    if (c == null) return '';
    if (c.saving) return 'Guardando…';
    if (c.saveError != null) return c.saveError!;
    final at = c.lastSavedAt;
    if (at == null) {
      return c.dirty ? 'Sin guardar' : '';
    }
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return 'Guardado automático $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editor')),
        body: Center(child: Text(_loadError ?? 'Error')),
      );
    }

    final c = _controller!;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _confirmLeave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: _NameField(controller: c),
          actions: [
            IconButton(
              tooltip: 'Deshacer',
              onPressed: c.canUndo ? c.undo : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Rehacer',
              onPressed: c.canRedo ? c.redo : null,
              icon: const Icon(Icons.redo),
            ),
            IconButton(
              tooltip: 'Vista previa',
              onPressed: _showPreview,
              icon: const Icon(Icons.visibility_outlined),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton(
                onPressed: () => _save(activate: false),
                child: const Text('Guardar'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                onPressed: () => _save(activate: true),
                child: const Text('Usar en este evento'),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${c.template.paper.label} · $_autosaveLabel',
                style: const TextStyle(color: AppColors.grey, fontSize: 13),
              ),
            ),
          ),
        ),
        floatingActionButton: wide
            ? null
            : FloatingActionButton(
                onPressed: () => showAddLayerSheet(
                  context,
                  c,
                  onPickImage: () => _pickImageForSelected(),
                  onPickBackground: () =>
                      _pickImageForSelected(asBackground: true),
                ),
                child: const Icon(Icons.add),
              ),
        body: wide ? _buildLandscape(c) : _buildPortrait(c),
      ),
    );
  }

  Widget _buildLandscape(TemplateEditorController c) {
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Material(
            color: AppColors.white,
            elevation: 1,
            child: TemplateLayerListPanel(controller: c),
          ),
        ),
        Expanded(
          child: TemplateEditorCanvas(
            controller: c,
            printContext: _printContext,
            photos: _previewPhotos,
            assets: _assets,
          ),
        ),
        SizedBox(
          width: 300,
          child: Material(
            color: AppColors.white,
            elevation: 1,
            child: TemplateLayerPropsPanel(
              controller: c,
              onReplaceImage: () => _pickImageForSelected(
                asBackground:
                    c.selectedLayer?.type == TemplateLayerType.background,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortrait(TemplateEditorController c) {
    return Column(
      children: [
        Expanded(
          child: TemplateEditorCanvas(
            controller: c,
            printContext: _printContext,
            photos: _previewPhotos,
            assets: _assets,
          ),
        ),
        Material(
          color: AppColors.white,
          elevation: 8,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.38,
            child: Column(
              children: [
                TabBar(
                  controller: _sheetTabs,
                  labelColor: AppColors.red,
                  tabs: const [
                    Tab(text: 'Capas'),
                    Tab(text: 'Añadir'),
                    Tab(text: 'Props'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _sheetTabs,
                    children: [
                      TemplateLayerListPanel(controller: c, compact: true),
                      _AddTab(
                        controller: c,
                        onPickImage: () => _pickImageForSelected(),
                        onPickBackground: () =>
                            _pickImageForSelected(asBackground: true),
                      ),
                      TemplateLayerPropsPanel(
                        controller: c,
                        onReplaceImage: () => _pickImageForSelected(
                          asBackground: c.selectedLayer?.type ==
                              TemplateLayerType.background,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({required this.controller});

  final TemplateEditorController controller;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.template.name);
    widget.controller.addListener(_sync);
  }

  void _sync() {
    final name = widget.controller.template.name;
    if (_text.text != name && !_text.selection.isValid) {
      _text.text = name;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _text,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        hintText: 'Nombre de plantilla',
      ),
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      onSubmitted: widget.controller.rename,
      onTapOutside: (_) {
        widget.controller.rename(_text.text);
        FocusScope.of(context).unfocus();
      },
    );
  }
}

class _AddTab extends StatelessWidget {
  const _AddTab({
    required this.controller,
    required this.onPickImage,
    required this.onPickBackground,
  });

  final TemplateEditorController controller;
  final VoidCallback onPickImage;
  final VoidCallback onPickBackground;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, VoidCallback onTap) {
      return ListTile(
        leading: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.red),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: onTap,
      );
    }

    return ListView(
      children: [
        tile(Icons.photo_outlined, 'Hueco de foto', () {
          controller.setDrawSlotMode(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dibuja los huecos donde deben ir las fotos'),
            ),
          );
        }),
        tile(Icons.image_outlined, 'Imagen / logo', onPickImage),
        tile(Icons.title, 'Texto', () => controller.addLayer(controller.newText())),
        tile(Icons.qr_code_2, 'QR', () => controller.addLayer(controller.newQr())),
        tile(
          Icons.crop_square,
          'Forma',
          () => controller.addLayer(controller.newShape()),
        ),
        tile(Icons.wallpaper_outlined, 'Fondo', onPickBackground),
        const Divider(),
        ListTile(
          title: const Text('Starter: 1 hueco'),
          onTap: controller.applyStarterOneSlot,
        ),
        ListTile(
          title: const Text('Starter: tira'),
          onTap: controller.applyStarterStrip,
        ),
      ],
    );
  }
}
