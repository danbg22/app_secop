import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/logos_entidades.dart';
import '../utils/file_downloader.dart';
import '../utils/texto_profesional.dart';
import 'reporte_contratos_modelo.dart';

export 'reporte_contratos_modelo.dart';

/// Reporte institucional en PDF de los contratos de una entidad o
/// dependencia, para responder requerimientos de entes de control.
///
/// Se genera en el navegador con el paquete `pdf` (sin servidor): encabezado
/// con logo, criterios de la consulta, resumen ejecutivo y la relación de
/// contratos con las columnas elegidas, el encabezado de la tabla repetido en
/// cada página y el número de contrato enlazado a SECOP II.
class ReporteContratosPdfService {
  ReporteContratosPdfService._();

  /// Tope de filas: más allá el documento pasa de ~400 páginas y el
  /// navegador tarda demasiado en armarlo.
  static const int maxContratos = 5000;

  static const _navy = PdfColor.fromInt(0xFF0E2646);
  static const _texto = PdfColor.fromInt(0xFF364F6B);
  static const _gris = PdfColor.fromInt(0xFF64748B);
  static const _enlace = PdfColor.fromInt(0xFF1D4ED8);
  static const _fondoCabecera = PdfColor.fromInt(0xFFE8EEF7);
  static const _fondoPar = PdfColor.fromInt(0xFFF8FAFC);
  static const _fondoDiligenciar = PdfColor.fromInt(0xFFFFFBEB);
  static const _borde = PdfColor.fromInt(0xFFD5DEEA);

  static const _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static pw.ThemeData? _tema;

  static Future<pw.ThemeData> _cargarTema() async {
    if (_tema != null) return _tema!;
    Future<pw.Font> f(String peso) async => pw.Font.ttf(
      await rootBundle.load('assets/fonts/inter/Inter-$peso.ttf'),
    );
    return _tema = pw.ThemeData.withFont(
      base: await f('Regular'),
      bold: await f('Bold'),
      italic: await f('Regular'),
      boldItalic: await f('Bold'),
    );
  }

  static String cop(double v) => pesos(v);

  static String fechaLarga(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${d.day} de ${_meses[d.month - 1]} de ${d.year}, '
        '${dos(d.hour)}:${dos(d.minute)}';
  }

  static String _recortar(String t, int max) {
    final limpio = t.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (limpio.length <= max) return limpio;
    final corte = limpio.lastIndexOf(' ', max);
    return '${limpio.substring(0, corte > max * 0.7 ? corte : max)}…';
  }

  static Future<pw.ImageProvider?> _logo(String entidad, String nit) async {
    final l = LogosEntidades.buscar(nombre: entidad, nit: nit);
    if (l == null) return null;
    try {
      final bytes = await rootBundle.load(l.asset);
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// Genera el PDF. [criterios] son pares etiqueta → valor que se listan
  /// antes de la tabla; [columnas], en el orden en que se muestran.
  static Future<Uint8List> generar({
    required String entidad,
    required String nit,
    required String titulo,
    required List<(String, String)> criterios,
    required List<ContratoReporte> contratos,
    required String generadoPor,
    required DateTime generadoEn,
    List<ColumnaReporte> columnas = const [
      ColumnaReporte.fila,
      ColumnaReporte.numero,
      ColumnaReporte.firma,
      ColumnaReporte.objeto,
      ColumnaReporte.modalidad,
      ColumnaReporte.contratista,
      ColumnaReporte.valor,
      ColumnaReporte.estado,
    ],
    List<String> notas = const [],
    bool firmaResponsable = false,
  }) async {
    final tema = await _cargarTema();
    final logo = await _logo(entidad, nit);
    final doc = pw.Document(
      theme: tema,
      title: '$titulo · $entidad',
      author: generadoPor,
      creator: 'Contrata Legal',
      subject: 'Relación de contratos (SECOP II)',
    );

    // Con muchas columnas, hoja oficio y letra más pequeña.
    final ancha = columnas.length > 9;
    final formato = ancha
        ? PdfPageFormat.legal.landscape
        : PdfPageFormat.letter.landscape;
    final tam = columnas.length > 12 ? 6.4 : (ancha ? 6.9 : 7.6);
    final txt = pw.TextStyle(fontSize: tam, color: _texto, lineSpacing: 1.1);
    final neg = pw.TextStyle(
      fontSize: tam,
      color: _navy,
      fontWeight: pw.FontWeight.bold,
    );
    final link = pw.TextStyle(
      fontSize: tam,
      color: _enlace,
      fontWeight: pw.FontWeight.bold,
      decoration: pw.TextDecoration.underline,
    );

    final total = contratos.fold<double>(0, (s, c) => s + c.valorCop);
    final pagado = contratos.fold<double>(0, (s, c) => s + c.pagadoCop);
    final contratistas = <String, int>{};
    for (final c in contratos) {
      final k = c.documentoContratista.isNotEmpty
          ? c.documentoContratista
          : c.contratista;
      contratistas[k] = (contratistas[k] ?? 0) + 1;
    }
    final conHistorial = contratos.any((c) => c.contratosConEntidad != null);
    final recurrentes = conHistorial
        ? {
            for (final c in contratos)
              if ((c.contratosConEntidad ?? 0) > 1)
                c.documentoContratista.isNotEmpty
                    ? c.documentoContratista
                    : c.contratista,
          }.length
        : 0;
    final continuidad = contratos
        .where(
          (c) => c.interrupcionHabiles != null && c.interrupcionHabiles! <= 30,
        )
        .length;

    Map<String, (int, double)> agrupar(String Function(ContratoReporte) k) {
      final r = <String, (int, double)>{};
      for (final c in contratos) {
        final clave = k(c);
        final p = r[clave] ?? (0, 0.0);
        r[clave] = (p.$1 + 1, p.$2 + c.valorCop);
      }
      return r;
    }

    final porAnio = agrupar(
      (c) => '${c.anioFirma ?? 'Sin fecha'}',
    ).entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final porDependencia = agrupar((c) => c.dependencia).entries.toList()
      ..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final porModalidad = agrupar(
      (c) => c.modalidad.isEmpty
          ? 'Sin modalidad'
          : TextoProfesional.etiqueta(c.modalidad),
    ).entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));

    pw.Widget celda(
      String t, {
      pw.TextStyle? estilo,
      pw.TextAlign alinear = pw.TextAlign.left,
      double pad = 3.5,
    }) => pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 3, vertical: pad),
      child: pw.Text(t, style: estilo ?? txt, textAlign: alinear),
    );

    pw.Widget tablaResumen(
      String titulo,
      List<MapEntry<String, (int, double)>> filas,
    ) {
      const chico = pw.TextStyle(fontSize: 7.2, color: _texto);
      pw.Widget c(String t, [pw.TextAlign a = pw.TextAlign.left]) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
        child: pw.Text(t, style: chico, textAlign: a),
      );
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            titulo.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 6.8,
              color: _gris,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _borde, width: 0.4),
              bottom: pw.BorderSide(color: _borde, width: 0.4),
              top: pw.BorderSide(color: _borde, width: 0.4),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FixedColumnWidth(30),
              2: pw.FlexColumnWidth(2.2),
            },
            children: [
              for (final e in filas.take(8))
                pw.TableRow(
                  children: [
                    c(e.key),
                    c('${e.value.$1}', pw.TextAlign.right),
                    c(pesos(e.value.$2), pw.TextAlign.right),
                  ],
                ),
              if (filas.length > 8)
                pw.TableRow(
                  children: [
                    c('Otras (${filas.length - 8})'),
                    c(
                      '${filas.skip(8).fold<int>(0, (s, e) => s + e.value.$1)}',
                      pw.TextAlign.right,
                    ),
                    c(
                      pesos(
                        filas.skip(8).fold<double>(0, (s, e) => s + e.value.$2),
                      ),
                      pw.TextAlign.right,
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
    }

    pw.Widget cifra(String k, String v) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          color: _fondoPar,
          border: pw.Border.all(color: _borde, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              k.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 6.4,
                color: _gris,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 11.5,
                color: _navy,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    pw.Widget encabezado(pw.Context ctx) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 1.2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.SizedBox(
              height: 34,
              width: 60,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 10),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  entidad.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _navy,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (nit.isNotEmpty)
                  pw.Text(
                    'NIT $nit',
                    style: const pw.TextStyle(fontSize: 7.5, color: _gris),
                  ),
                pw.Text(
                  titulo,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: _texto,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Generado: ${fechaLarga(generadoEn)}',
                style: const pw.TextStyle(fontSize: 7.2, color: _texto),
              ),
              pw.Text(
                'Por: $generadoPor',
                style: const pw.TextStyle(fontSize: 7.2, color: _texto),
              ),
              pw.Text(
                'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 7.2, color: _gris),
              ),
            ],
          ),
        ],
      ),
    );

    pw.Widget pie(pw.Context ctx) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borde, width: 0.5)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Fuente: SECOP II, Datos Abiertos de Colombia (datos.gov.co: contratos jbjy-vk9h y procesos '
              'p6dx-8zbt), consultado el ${fechaLarga(generadoEn)}. Reporte generado con Contrata Legal; '
              'no reemplaza las certificaciones expedidas por la entidad.',
              style: const pw.TextStyle(fontSize: 6.2, color: _gris),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: _gris),
          ),
        ],
      ),
    );

    pw.Widget valorCelda(ColumnaReporte col, ContratoReporte c, int i) {
      final t = textoColumna(col, c, i);
      switch (col) {
        case ColumnaReporte.numero when c.url.startsWith('http'):
          return pw.UrlLink(
            destination: c.url,
            child: celda(t, estilo: link),
          );
        case ColumnaReporte.enlace when c.url.startsWith('http'):
          return pw.UrlLink(
            destination: c.url,
            child: celda(t, estilo: link),
          );
        case ColumnaReporte.fila:
          return celda(
            t,
            estilo: pw.TextStyle(fontSize: tam - 0.6, color: _gris),
          );
        case ColumnaReporte.objeto:
          return celda(_recortar(t, ancha ? 170 : 190));
        case ColumnaReporte.contratista:
          return celda(_recortar(t, 80));
        default:
          return celda(
            t,
            alinear: col.numerica ? pw.TextAlign.right : pw.TextAlign.left,
          );
      }
    }

    final anchos = <int, pw.TableColumnWidth>{
      for (final (i, c) in columnas.indexed)
        i: c.flex > 0
            ? pw.FlexColumnWidth(c.flex)
            : pw.FixedColumnWidth(ancha ? c.anchoPdf * 0.92 : c.anchoPdf),
    };
    final idxValor = columnas.indexOf(ColumnaReporte.valor);

    doc.addPage(
      pw.MultiPage(
        pageFormat: formato,
        // Por defecto el paquete corta en 20 páginas; con el tope de
        // contratos el reporte puede llegar a unas 450.
        maxPages: 1000,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
        header: encabezado,
        footer: pie,
        build: (ctx) => [
          // Criterios de la consulta.
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borde, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CRITERIOS DE LA CONSULTA',
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: _gris,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Wrap(
                  spacing: 18,
                  runSpacing: 2,
                  children: [
                    for (final (k, v) in criterios)
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text: '$k: ',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: _gris,
                              ),
                            ),
                            pw.TextSpan(
                              text: v,
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: _navy,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          // Resumen ejecutivo.
          pw.Row(
            children: [
              cifra('Total de contratos', '${contratos.length}'),
              pw.SizedBox(width: 7),
              cifra('Cuantía total', pesos(total)),
              pw.SizedBox(width: 7),
              cifra('Valor pagado reportado', pesos(pagado)),
              pw.SizedBox(width: 7),
              cifra('Contratistas distintos', '${contratistas.length}'),
              if (conHistorial) ...[
                pw.SizedBox(width: 7),
                cifra('Contratistas recurrentes', '$recurrentes'),
                pw.SizedBox(width: 7),
                cifra('Interrupción de 30 días hábiles o menos', '$continuidad'),
              ],
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: tablaResumen('Por vigencia', porAnio)),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: porDependencia.length > 1
                    ? tablaResumen('Por dependencia', porDependencia)
                    : tablaResumen('Por modalidad', porModalidad),
              ),
            ],
          ),
          if (notas.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            for (final n in notas)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 1.5),
                child: pw.Text(
                  'Nota: $n',
                  style: const pw.TextStyle(fontSize: 6.8, color: _gris),
                ),
              ),
          ],
          pw.SizedBox(height: 10),
          pw.Text(
            'RELACIÓN DE CONTRATOS',
            style: pw.TextStyle(
              fontSize: 8,
              color: _navy,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _borde, width: 0.4),
              verticalInside: pw.BorderSide(color: _borde, width: 0.3),
              bottom: pw.BorderSide(color: _borde, width: 0.4),
            ),
            columnWidths: anchos,
            children: [
              // Se repite en cada página.
              pw.TableRow(
                repeat: true,
                decoration: const pw.BoxDecoration(color: _fondoCabecera),
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  for (final c in columnas)
                    celda(
                      c.titulo,
                      estilo: neg,
                      alinear: c.numerica
                          ? pw.TextAlign.right
                          : pw.TextAlign.left,
                    ),
                ],
              ),
              for (final (i, c) in contratos.indexed)
                pw.TableRow(
                  decoration: i.isOdd
                      ? const pw.BoxDecoration(color: _fondoPar)
                      : null,
                  children: [
                    for (final col in columnas)
                      col.porDiligenciar
                          ? pw.Container(
                              color: _fondoDiligenciar,
                              child: celda(''),
                            )
                          : valorCelda(col, c, i),
                  ],
                ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _fondoCabecera),
                children: [
                  for (final (i, _) in columnas.indexed)
                    i == idxValor
                        ? celda(
                            pesos(total),
                            estilo: neg,
                            alinear: pw.TextAlign.right,
                          )
                        : i == 0
                        ? celda('TOTAL', estilo: neg)
                        : i == 1
                        ? celda('${contratos.length} contratos', estilo: neg)
                        : celda(''),
                ],
              ),
            ],
          ),
          if (columnas.any((c) => c.porDiligenciar)) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Las columnas sombreadas no están en datos públicos y debe diligenciarlas la entidad.',
              style: const pw.TextStyle(fontSize: 6.8, color: _gris),
            ),
          ],
          if (firmaResponsable) ...[
            pw.SizedBox(height: 22),
            pw.Row(
              children: [
                for (final etiqueta in [
                  'Servidor responsable de la información',
                  'Cargo',
                  'Correo / teléfono',
                ]) ...[
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 14),
                        pw.Container(height: 0.6, color: _texto),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          etiqueta,
                          style: const pw.TextStyle(
                            fontSize: 7.5,
                            color: _texto,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                ],
              ],
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static String nombreArchivo(
    String entidad,
    String alcance,
    DateTime fecha, {
    String extension = 'pdf',
  }) {
    String limpio(String t) => t
        .replaceAll(RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÑáéíóúñ ]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    String dos(int n) => n.toString().padLeft(2, '0');
    final base = [
      'Reporte_contratos',
      limpio(entidad),
      if (alcance.isNotEmpty) limpio(alcance),
      '${fecha.year}${dos(fecha.month)}${dos(fecha.day)}',
    ].join('_');
    return '${base.length > 120 ? base.substring(0, 120) : base}.$extension';
  }

  static bool descargar(Uint8List bytes, String nombre) => downloadBinaryBytes(
    bytes: bytes,
    fileName: nombre,
    mimeType: 'application/pdf',
  );
}
