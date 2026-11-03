import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/templates/template_composer.dart';
import 'package:fotoboot_operator/templates/template_layer_typography.dart';
import 'package:fotoboot_operator/templates/template_tokens.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('each catalog font has bundled google_fonts TTF assets', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();

    for (final catalogKey in TemplateFontCatalog.entries.keys) {
      for (final suffix
          in TemplateFontCatalog.bundledWeightSuffixes(catalogKey)) {
        final base = TemplateFontCatalog.bundledAssetBasename(
          catalogKey,
          suffix,
        );
        expect(
          assets.any((path) => path.endsWith(base)),
          isTrue,
          reason: 'Missing bundled font asset $base for $catalogKey',
        );
      }
    }
  });

  test('typography compose preloads bundled fonts without network', () async {
    const template = PrintTemplate(
      id: 'typo',
      name: 'Typo',
      paper: TemplatePaper(
        widthMm: 80,
        heightMm: 100,
        family: PaperFamily.thermal,
      ),
      layers: [
        TemplateLayer(
          id: 't',
          type: TemplateLayerType.text,
          x: 0.1,
          y: 0.1,
          w: 0.8,
          h: 0.2,
          text: 'Hola booth',
          fontSizePt: 12,
          fontWeight: 'bold',
          fontFamily: 'Montserrat',
          textAlign: 'center',
          color: '#000000',
        ),
      ],
    );

    await preloadTemplateTypographyFonts(template);
    final png = await const TemplateComposer().composePng(
      template: template,
      context: TemplatePrintContext.fromEvent(eventName: 'Test'),
      widthPx: 200,
    );
    expect(png.length, greaterThan(100));
  });
}
