import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/services/template_store.dart';
import 'package:fotoboot_operator/templates/paper_presets.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

enum _CreateMode { background, blank }

/// Short wizard: mode → paper → name → open editor.
Future<void> showNewTemplateWizard(
  BuildContext context, {
  required TemplateStore store,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _NewTemplateWizard(store: store),
      );
    },
  );
}

class _NewTemplateWizard extends StatefulWidget {
  const _NewTemplateWizard({required this.store});

  final TemplateStore store;

  @override
  State<_NewTemplateWizard> createState() => _NewTemplateWizardState();
}

class _NewTemplateWizardState extends State<_NewTemplateWizard> {
  int _step = 0;
  _CreateMode? _mode;
  PaperPreset? _preset;
  bool _custom = false;
  double _customW = 100;
  double _customH = 150;
  late final TextEditingController _name;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final label =
        'Plantilla ${now.day} ${_monthShort(now.month)}';
    _name = TextEditingController(text: label);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _monthShort(int m) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return months[m - 1];
  }

  TemplatePaper get _paper {
    if (_custom) {
      return TemplatePaper(
        widthMm: _customW,
        heightMm: _customH,
        family: _customW <= 80 ? PaperFamily.thermal : PaperFamily.photo,
      );
    }
    return _preset!.paper;
  }

  Future<void> _finish() async {
    if (_mode == null) return;
    if (!_custom && _preset == null) return;
    if (_paper.widthMm < 20 || _paper.heightMm < 20) {
      setState(() => _error = 'Medidas inválidas (mín. 20 mm)');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.store.init();
      PrintTemplate created;
      var promptSlots = false;

      if (_mode == _CreateMode.background) {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 5000,
          maxHeight: 5000,
          imageQuality: 95,
        );
        if (picked == null) {
          setState(() => _busy = false);
          return;
        }
        final bytes = await picked.readAsBytes();
        created = await widget.store.createWithBackground(
          paper: _paper,
          name: _name.text.trim().isEmpty ? 'Plantilla' : _name.text.trim(),
          backgroundBytes: Uint8List.fromList(bytes),
        );
        promptSlots = true;
      } else {
        created = await widget.store.createBlank(
          paper: _paper,
          name: _name.text.trim().isEmpty ? 'Plantilla' : _name.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      context.push(
        '/templates/edit/${created.id}?promptSlots=${promptSlots ? '1' : '0'}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo crear la plantilla';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
            const SizedBox(height: 4),
            Text(
              _stepTitle,
              style: const TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 16),
            if (_step == 0) _modeStep(),
            if (_step == 1) _paperStep(),
            if (_step == 2) _nameStep(),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.redDark)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _step -= 1;
                              _error = null;
                            }),
                    child: const Text('Atrás'),
                  ),
                const Spacer(),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _busy ? null : _onPrimary,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_primaryLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return 'Cómo empezamos';
      case 1:
        return 'Elige el papel';
      default:
        return 'Nombre';
    }
  }

  String get _primaryLabel {
    if (_step < 2) return 'Siguiente';
    return _mode == _CreateMode.background
        ? 'Listo — editar huecos'
        : 'Abrir editor';
  }

  void _onPrimary() {
    if (_step == 0) {
      if (_mode == null) {
        setState(() => _error = 'Elige cómo empezar');
        return;
      }
      setState(() {
        _step = 1;
        _error = null;
      });
      return;
    }
    if (_step == 1) {
      if (!_custom && _preset == null) {
        setState(() => _error = 'Elige un tamaño de papel');
        return;
      }
      setState(() {
        _step = 2;
        _error = null;
      });
      return;
    }
    _finish();
  }

  Widget _modeStep() {
    Widget option({
      required _CreateMode mode,
      required String title,
      required String subtitle,
      required IconData icon,
    }) {
      final selected = _mode == mode;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: selected
              ? AppColors.red.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              _mode = mode;
              _error = null;
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(icon, color: AppColors.red),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppColors.red),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        option(
          mode: _CreateMode.background,
          title: 'Subir fondo (Canva u otra imagen)',
          subtitle: 'JPEG/PNG · luego dibujas los huecos',
          icon: Icons.upload_file_outlined,
        ),
        option(
          mode: _CreateMode.blank,
          title: 'Empezar en blanco',
          subtitle: 'Capas: huecos, texto, QR, formas…',
          icon: Icons.dashboard_customize_outlined,
        ),
      ],
    );
  }

  Widget _paperStep() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final p in PaperPreset.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: !_custom && _preset?.id == p.id
                        ? AppColors.red.withValues(alpha: 0.08)
                        : null,
                    side: BorderSide(
                      color: !_custom && _preset?.id == p.id
                          ? AppColors.red
                          : AppColors.grey.withValues(alpha: 0.4),
                    ),
                  ),
                  onPressed: () => setState(() {
                    _preset = p;
                    _custom = false;
                    _error = null;
                  }),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      p.hint == null ? p.label : '${p.label} · ${p.hint}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _custom,
            title: const Text('Personalizado (mm)'),
            onChanged: (v) => setState(() {
              _custom = v ?? false;
              _error = null;
            }),
          ),
          if (_custom)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _customW.toStringAsFixed(0),
                    decoration: const InputDecoration(
                      labelText: 'Ancho mm',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = double.tryParse(v);
                      if (n != null) _customW = n;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _customH.toStringAsFixed(0),
                    decoration: const InputDecoration(
                      labelText: 'Alto mm',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = double.tryParse(v);
                      if (n != null) _customH = n;
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _nameStep() {
    return TextField(
      controller: _name,
      decoration: const InputDecoration(
        labelText: 'Nombre',
        border: OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.done,
    );
  }
}
