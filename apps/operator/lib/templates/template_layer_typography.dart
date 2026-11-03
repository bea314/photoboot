import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

/// Built-in font families (bundled / system — no runtime download).
abstract final class TemplateFontCatalog {
  static const defaultFamily = 'Roboto';

  static const entries = <String, String>{
    'Roboto': 'Roboto',
    'Open Sans': 'Open Sans',
    'Montserrat': 'Montserrat',
    'Lato': 'Lato',
    'Oswald': 'Oswald',
  };

  static String resolve(String? raw) {
    if (raw == null || raw.isEmpty) return defaultFamily;
    return entries.containsKey(raw) ? raw : defaultFamily;
  }

  /// [GoogleFonts] API family id (filename prefix before `-Regular.ttf`).
  static String googleApiFamily(String catalogKey) {
    switch (catalogKey) {
      case 'Open Sans':
        return 'OpenSans';
      default:
        return catalogKey;
    }
  }

  /// Bundled `.ttf` weight suffixes required for selector + presets (offline).
  static List<String> bundledWeightSuffixes(String catalogKey) {
    if (catalogKey == 'Lato') {
      // Lato has no separate Medium static file; w500 maps to Regular.
      return const ['Regular', 'Bold'];
    }
    return const ['Regular', 'Medium', 'Bold'];
  }

  static String bundledAssetBasename(String catalogKey, String weightSuffix) {
    return '${googleApiFamily(catalogKey)}-$weightSuffix.ttf';
  }
}

enum TemplateTextPresetId { title, subtitle, body }

/// Preset sizes in typographic points (physical — scales with paper mm).
abstract final class TemplateTextPresets {
  static const title = TemplateTextPresetId.title;
  static const subtitle = TemplateTextPresetId.subtitle;
  static const body = TemplateTextPresetId.body;

  static String label(TemplateTextPresetId id) {
    switch (id) {
      case TemplateTextPresetId.title:
        return 'Título';
      case TemplateTextPresetId.subtitle:
        return 'Subtítulo';
      case TemplateTextPresetId.body:
        return 'Cuerpo';
    }
  }

  static TemplateLayer apply(TemplateLayer layer, TemplateTextPresetId preset) {
    switch (preset) {
      case TemplateTextPresetId.title:
        return layer.copyWith(
          fontSizePt: 14,
          fontWeight: 'bold',
          textAlign: 'center',
          maxLines: 2,
        );
      case TemplateTextPresetId.subtitle:
        return layer.copyWith(
          fontSizePt: 11,
          fontWeight: 'medium',
          textAlign: 'center',
          maxLines: 2,
        );
      case TemplateTextPresetId.body:
        return layer.copyWith(
          fontSizePt: 9,
          fontWeight: 'regular',
          textAlign: 'center',
          maxLines: 3,
        );
    }
  }

  /// Best-effort match for the preset selector UI.
  static TemplateTextPresetId? detect(TemplateLayer layer) {
    final pt = layer.fontSizePt;
    final w = layer.fontWeight;
    if (pt == 14 && w == 'bold') return TemplateTextPresetId.title;
    if (pt == 11 && w == 'medium') return TemplateTextPresetId.subtitle;
    if (pt == 9 && w == 'regular') return TemplateTextPresetId.body;
    return null;
  }
}

class TemplateResolvedTextStyle {
  const TemplateResolvedTextStyle({
    required this.fontSize,
    required this.fontWeight,
    required this.fontFamily,
    required this.textAlign,
    required this.color,
    required this.maxLines,
    this.lineHeight,
    this.legacy = false,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final String fontFamily;
  final TextAlign textAlign;
  final Color color;
  final int maxLines;
  final double? lineHeight;
  final bool legacy;
}

bool layerHasTypography(TemplateLayer layer) {
  return layer.fontSizePt != null ||
      layer.fontWeight != null ||
      layer.fontFamily != null ||
      layer.textAlign != null ||
      layer.color != null ||
      layer.lineHeight != null ||
      layer.maxLines != null;
}

/// Builds a [TextStyle] for the layout painter (bundled Google Fonts, no runtime fetch).
TextStyle buildTemplateTextStyle(TemplateResolvedTextStyle resolved) {
  final base = TextStyle(
    color: resolved.color,
    fontWeight: resolved.fontWeight,
    fontSize: resolved.fontSize,
    height: resolved.lineHeight,
  );
  switch (resolved.fontFamily) {
    case 'Open Sans':
      return GoogleFonts.openSans(textStyle: base);
    case 'Montserrat':
      return GoogleFonts.montserrat(textStyle: base);
    case 'Lato':
      return GoogleFonts.lato(textStyle: base);
    case 'Oswald':
      return GoogleFonts.oswald(textStyle: base);
    case 'Roboto':
    default:
      return GoogleFonts.roboto(textStyle: base);
  }
}

TextStyle painterTextStyle(
  TemplateLayer layer,
  TemplateResolvedTextStyle resolved,
) {
  if (resolved.legacy) {
    return TextStyle(
      color: resolved.color,
      fontWeight: resolved.fontWeight,
      fontSize: resolved.fontSize,
      height: resolved.lineHeight,
    );
  }
  return buildTemplateTextStyle(resolved);
}

/// Ensures bundled Google Fonts for typography layers are loaded before raster paint.
Future<void> preloadTemplateTypographyFonts(PrintTemplate template) async {
  final paper = template.paper;
  final paperRect = Rect.fromLTWH(0, 0, 1000, 1000 / paper.aspectRatio);
  for (final layer in template.layers) {
    if (layer.type != TemplateLayerType.text || !layerHasTypography(layer)) {
      continue;
    }
    final rect = Rect.fromLTWH(
      paperRect.left + layer.x * paperRect.width,
      paperRect.top + layer.y * paperRect.height,
      layer.w * paperRect.width,
      layer.h * paperRect.height,
    );
    final resolved = resolveTextStyle(layer, paper, rect);
    painterTextStyle(layer, resolved);
  }
  await GoogleFonts.pendingFonts();
}

Color? parseTemplateHex(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  var s = raw.trim();
  if (s.toLowerCase() == 'none') return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  return Color(value);
}

FontWeight templateFontWeight(String? raw, {required FontWeight legacy}) {
  switch (raw) {
    case 'regular':
      return FontWeight.w400;
    case 'medium':
      return FontWeight.w500;
    case 'bold':
      return FontWeight.w700;
    default:
      return legacy;
  }
}

TextAlign templateTextAlign(String? raw, {required TextAlign legacy}) {
  switch (raw) {
    case 'left':
      return TextAlign.left;
    case 'right':
      return TextAlign.right;
    case 'center':
      return TextAlign.center;
    default:
      return legacy;
  }
}

/// Converts typographic pt on [paper] to canvas pixels for [layerRect] height scale.
double fontSizePxFromPt(double pt, TemplatePaper paper, Rect layerRect) {
  final mm = pt * 25.4 / 72;
  return mm / paper.heightMm * layerRect.height;
}

double strokeWidthPxFromMm(double mm, TemplatePaper paper, Rect layerRect) {
  return mm / paper.heightMm * layerRect.height;
}

/// Legacy Corte A/B text when optional typography fields are absent.
TemplateResolvedTextStyle resolveTextStyle(
  TemplateLayer layer,
  TemplatePaper paper,
  Rect rect,
) {
  final hasTypography = layerHasTypography(layer);

  if (!hasTypography) {
    final fontSize = (rect.height * 0.55).clamp(10.0, 36.0);
    return TemplateResolvedTextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      fontFamily: TemplateFontCatalog.defaultFamily,
      textAlign: TextAlign.center,
      color: AppColors.black,
      maxLines: 2,
      legacy: true,
    );
  }

  final pt = layer.fontSizePt ?? 9;
  return TemplateResolvedTextStyle(
    fontSize: fontSizePxFromPt(pt, paper, rect),
    fontWeight: templateFontWeight(
      layer.fontWeight,
      legacy: FontWeight.w400,
    ),
    fontFamily: TemplateFontCatalog.resolve(layer.fontFamily),
    textAlign: templateTextAlign(
      layer.textAlign,
      legacy: TextAlign.center,
    ),
    color: parseTemplateHex(layer.color) ?? AppColors.black,
    maxLines: layer.maxLines ?? 4,
    lineHeight: layer.lineHeight,
    legacy: false,
  );
}
