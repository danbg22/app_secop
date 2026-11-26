import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/utils/tipo_archivo_seguro.dart';

void main() {
  group('Archivos subidos por terceros', () {
    test('solo abre PDF e imágenes comunes según su contenido real', () {
      expect(
        tipoVisualizablePorContenido(utf8.encode('%PDF-1.7\n...')),
        'application/pdf',
      );
      expect(
        tipoVisualizablePorContenido(const [
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0,
        ]),
        'image/png',
      );
      expect(
        tipoVisualizablePorContenido(const [0xFF, 0xD8, 0xFF, 0xE0]),
        'image/jpeg',
      );
      expect(
        tipoVisualizablePorContenido([
          ...ascii.encode('RIFF'),
          0,
          0,
          0,
          0,
          ...ascii.encode('WEBP'),
        ]),
        'image/webp',
      );
    });

    test('un HTML o un SVG disfrazado de PDF no se abre en la app', () {
      final html = utf8.encode('<html><script>robar()</script></html>');
      final svg = utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg"><script/></svg>',
      );
      expect(tipoVisualizablePorContenido(html), isNull);
      expect(tipoVisualizablePorContenido(svg), isNull);
      expect(tipoVisualizablePorContenido(const []), isNull);
    });

    test('las descargas nunca llevan un tipo que el navegador ejecute', () {
      for (final tipo in [
        'text/html',
        'TEXT/HTML; charset=utf-8',
        'image/svg+xml',
        'application/xhtml+xml',
        'text/javascript',
        '',
      ]) {
        expect(
          tipoDescargaSeguro(tipo),
          'application/octet-stream',
          reason: tipo,
        );
      }
      expect(tipoDescargaSeguro('application/pdf'), 'application/pdf');
      expect(
        tipoDescargaSeguro('text/csv;charset=utf-8'),
        'text/csv;charset=utf-8',
      );
    });
  });
}
