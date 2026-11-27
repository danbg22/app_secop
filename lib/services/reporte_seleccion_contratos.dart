import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/banderas_control.dart';
import '../utils/contract_financial_calculator.dart';
import '../utils/secop_i.dart';
import 'expediente_contrato_service.dart';
import 'reporte_contratos_pdf_service.dart';
import 'secop_document_intelligence_service.dart';
import 'security_service.dart';

class ContratoDelReporte {
  const ContratoDelReporte({
    required this.datos,
    required this.expedienteCompleto,
    required this.documentos,
  });

  final Map<String, dynamic> datos;
  final bool expedienteCompleto;
  final SecopExtractionResult? documentos;

  String get referencia => _campo(datos, [
    'referencia_del_contrato',
    'id_contrato',
    'proceso_de_compra',
  ]);
  String get entidad => _campo(datos, ['nombre_entidad']);
  String get objeto =>
      _campo(datos, ['objeto_del_contrato', 'descripcion_del_proceso']);

  static String _campo(Map<String, dynamic> datos, List<String> claves) {
    for (final clave in claves) {
      final valor = (datos[clave] ?? '').toString().trim();
      if (valor.isNotEmpty && valor.toLowerCase() != 'no definido') {
        return valor;
      }
    }
    return '';
  }

  static Future<ContratoDelReporte> consultar(
    Map<String, dynamic> entrada,
  ) async {
    Map<String, dynamic>? expediente;
    try {
      expediente = await ExpedienteContratoService.consultar(entrada);
    } catch (_) {
      // El PDF conserva los datos de la búsqueda e identifica la consulta parcial.
    }
    final datos = expediente ?? SecopI.normalizar(entrada);
    SecopExtractionResult? documentos;
    try {
      documentos = await SecopDocumentIntelligenceService.obtenerCacheSiExiste(
        datos,
      );
      if (documentos == null && !ExpedienteContratoService.esSecopI(datos)) {
        documentos =
            await SecopDocumentIntelligenceService.obtenerDocumentosDatosAbiertos(
              datos,
            );
      }
    } catch (_) {
      // La ficha puede exportarse aunque no responda el listado de documentos.
    }
    return ContratoDelReporte(
      datos: datos,
      expedienteCompleto: expediente != null,
      documentos: documentos,
    );
  }
}

abstract final class ReporteSeleccionContratos {
  static const _azul = PdfColor.fromInt(0xFF102645);
  static const _dorado = PdfColor.fromInt(0xFFFFC53D);
  static const _tinta = PdfColor.fromInt(0xFF213650);
  static const _gris = PdfColor.fromInt(0xFF4B6179);
  static const _fondo = PdfColor.fromInt(0xFFEDF2F8);
  static const _borde = PdfColor.fromInt(0xFFCDDAE8);
  static const _azulClaro = PdfColor.fromInt(0xFFE2EDF9);
  static const _enlaceAzul = PdfColor.fromInt(0xFF144E97);

  static Future<Uint8List> generar(
    List<ContratoDelReporte> contratos, {
    DateTime? ahora,
    String? entidad,
  }) async {
    if (contratos.isEmpty) {
      throw ArgumentError('Selecciona al menos un contrato.');
    }
    return _generar(
      cantidad: contratos.length,
      singular: 'Contrato',
      plural: 'Contratos',
      ficha: (i) => _ficha(i + 1, contratos[i]),
      ahora: ahora,
      entidad: entidad,
    );
  }

  static Future<Uint8List> _generar({
    required int cantidad,
    required String singular,
    required String plural,
    required pw.Widget Function(int) ficha,
    DateTime? ahora,
    String? entidad,
  }) async {
    final titulo = 'Reporte de ${plural.toLowerCase()}';
    final tema = await ReporteContratosPdfService.cargarTemaPdf();
    final fecha = ReporteContratosPdfService.horaColombia(ahora);
    final doc = pw.Document(
      title: '$titulo seleccionados',
      author: 'Contrata Legal',
    );
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(34, 32, 34, 28),
          theme: tema,
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: _fondo),
          ),
        ),
        maxPages: (cantidad + 1) ~/ 2 + 1,
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            children: [
              pw.Container(width: 12, height: 3, color: _dorado),
              pw.SizedBox(width: 7),
              _texto('Contrata Legal', tam: 10, negrita: true, color: _azul),
              pw.Spacer(),
              _texto('Consulta contractual', tam: 9, color: _gris),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _borde)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _texto(
                'Fuente · Datos Abiertos de Colombia y SECOP',
                tam: 8,
                color: _gris,
              ),
              _texto(
                '${ctx.pageNumber} / ${ctx.pagesCount}',
                tam: 8,
                color: _gris,
              ),
            ],
          ),
        ),
        build: (_) => [
          _portadaCompacta(
            titulo,
            cantidad,
            cantidad == 1 ? singular : plural,
            fecha,
            entidad,
          ),
          for (var i = 0; i < cantidad; i += 2)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: ficha(i)),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: i + 1 < cantidad ? ficha(i + 1) : pw.SizedBox(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _portadaCompacta(
    String titulo,
    int cantidad,
    String unidad,
    DateTime fecha,
    String? entidad,
  ) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    padding: const pw.EdgeInsets.fromLTRB(17, 15, 16, 15),
    decoration: pw.BoxDecoration(
      color: _azul,
      borderRadius: pw.BorderRadius.circular(9),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _texto(
                'RESUMEN DE LA SELECCIÓN',
                tam: 8,
                negrita: true,
                color: _dorado,
              ),
              pw.SizedBox(height: 4),
              _texto(titulo, tam: 23, negrita: true, color: PdfColors.white),
              if (entidad != null && entidad.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                _texto(
                  entidad,
                  tam: 11,
                  negrita: true,
                  color: PdfColors.white,
                  lineas: 2,
                ),
              ],
              pw.SizedBox(height: 6),
              _texto(
                ReporteContratosPdfService.fechaLarga(fecha),
                tam: 9,
                color: _azulClaro,
              ),
            ],
          ),
        ),
        pw.Container(
          width: 78,
          padding: const pw.EdgeInsets.symmetric(vertical: 7),
          decoration: pw.BoxDecoration(
            color: _dorado,
            borderRadius: pw.BorderRadius.circular(7),
          ),
          child: pw.Column(
            children: [
              _texto('$cantidad', tam: 20, negrita: true, color: _azul),
              _texto(unidad, tam: 8, negrita: true, color: _azul),
            ],
          ),
        ),
      ],
    ),
  );

  static pw.Widget _ficha(int numero, ContratoDelReporte c) {
    final analisis = ContractFinancialAnalysis.fromContract(c.datos);
    final dias = analisis.diasCalendario;
    final plazo = switch (dias) {
      1 => '1 día calendario',
      final int cantidad when cantidad > 0 => '$cantidad días calendario',
      _ =>
        analisis.tienePlazo ? analisis.mesesDesglosadosTexto : 'Sin informar',
    };
    final secop = ExpedienteContratoService.esSecopI(c.datos)
        ? 'SECOP I'
        : 'SECOP II';
    final estado = ContratoDelReporte._campo(c.datos, ['estado_contrato']);
    final contratista = ContratoDelReporte._campo(c.datos, [
      'proveedor_adjudicado',
    ]);
    final modalidad = ContratoDelReporte._campo(c.datos, [
      'modalidad_de_contratacion',
      'tipo_de_proceso',
    ]);
    final firma = DateTime.tryParse(
      ContratoDelReporte._campo(c.datos, ['fecha_de_firma']),
    );
    final pagado = analisis.pagos['Valor pagado'];
    final alerta = BanderasControl.enLeyDeGarantias(c.datos);
    final documentos = c.documentos?.documents;
    final rawUrl = c.datos['urlproceso'] ?? c.datos['ruta_proceso_en_secop_i'];
    final oficial =
        SecurityService.validateOfficialGovUrl(
          rawUrl is Map ? rawUrl['url']?.toString() : rawUrl?.toString(),
        ) ??
        SecurityService.validateOfficialGovUrl(c.documentos?.resolvedSecopUrl);
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borde, width: 0.75),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _etiqueta('$numero  /  $secop'),
              if (estado.isNotEmpty) ...[
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: _texto(estado, tam: 8, color: _gris, lineas: 2),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 7),
          _texto(
            c.referencia.isEmpty ? 'Contrato $numero' : c.referencia,
            tam: 14,
            negrita: true,
            color: _azul,
            lineas: 2,
          ),
          _texto(
            c.entidad.isEmpty ? 'Entidad sin informar' : c.entidad,
            tam: 10,
            color: _gris,
            lineas: 2,
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: pw.BoxDecoration(
              color: _fondo,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _dato(
                    'Valor del contrato',
                    analisis.tieneDatosFinancieros
                        ? ContractFinancialAnalysis.formatCop(
                            analisis.valorTotal,
                          )
                        : 'Sin informar',
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(child: _dato('Plazo', plazo)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          _dato(
            'Extracto del objeto',
            c.objeto.isEmpty ? 'Sin informar' : _extracto(c.objeto),
            lineas: 7,
          ),
          if (contratista.isNotEmpty ||
              modalidad.isNotEmpty ||
              firma != null ||
              pagado != null) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (contratista.isNotEmpty)
                        _dato('Contratista', contratista),
                      if (pagado != null)
                        _dato(
                          'Pago reportado',
                          ContractFinancialAnalysis.formatCop(pagado),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (modalidad.isNotEmpty) _dato('Modalidad', modalidad),
                      if (firma != null)
                        _dato('Firmado el', fechaDiaMesAnio(firma)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (alerta != null) ...[
            pw.SizedBox(height: 6),
            _texto(
              'Revisar contratación directa en Ley de Garantías',
              tam: 8,
              color: _azul,
              negrita: true,
            ),
          ],
          if (!c.expedienteCompleto ||
              documentos?.isNotEmpty == true ||
              oficial != null) ...[
            pw.SizedBox(height: 7),
            pw.Divider(color: _borde, height: 6, thickness: 0.6),
            if (!c.expedienteCompleto)
              _texto(
                'Fuente parcial · datos de la búsqueda',
                tam: 8,
                color: _gris,
              ),
            if (documentos != null && documentos.isNotEmpty)
              _texto(
                '${documentos.length} ${documentos.length == 1 ? 'documento consultado' : 'documentos consultados'}',
                tam: 8,
                color: _gris,
              ),
            if (oficial != null)
              pw.UrlLink(
                destination: oficial.toString(),
                child: pw.Text(
                  'Consultar expediente en SECOP',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: _enlaceAzul,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _extracto(String objeto) {
    final limpio = objeto.replaceAll(RegExp(r'\s+'), ' ').trim();
    const limite = 315;
    if (limpio.length <= limite) return limpio;
    final corte = limpio.lastIndexOf(' ', limite);
    return '${limpio.substring(0, corte > 0 ? corte : limite).trimRight()}…';
  }

  static pw.Widget _etiqueta(String texto) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: pw.BoxDecoration(
      color: _azulClaro,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: _texto(texto, tam: 8, negrita: true, color: _azul),
  );

  static pw.Widget _dato(String etiqueta, String valor, {int lineas = 2}) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _texto(etiqueta, tam: 8, negrita: true, color: _azul),
          _texto(valor, tam: 9.5, lineas: lineas),
          pw.SizedBox(height: 2),
        ],
      );

  static pw.Widget _texto(
    String texto, {
    double tam = 10,
    PdfColor color = _tinta,
    bool negrita = false,
    int? lineas,
  }) => pw.Text(
    texto,
    maxLines: lineas,
    overflow: pw.TextOverflow.clip,
    style: pw.TextStyle(
      fontSize: tam,
      color: color,
      lineSpacing: 1,
      fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  );
}

typedef ContratistaDelReporte = ({
  String nombre,
  String documento,
  String tipo,
  int contratos,
  double valor,
  int entidades,
  String ultimaFirma,
  String? alcance,
});

abstract final class ReporteSeleccionContratistas {
  static Future<Uint8List> generar(
    List<ContratistaDelReporte> contratistas, {
    DateTime? ahora,
  }) {
    if (contratistas.isEmpty) {
      throw ArgumentError('Selecciona al menos un contratista.');
    }
    return ReporteSeleccionContratos._generar(
      cantidad: contratistas.length,
      singular: 'Contratista',
      plural: 'Contratistas',
      ficha: (i) => _ficha(contratistas[i]),
      ahora: ahora,
    );
  }

  static pw.Widget _ficha(ContratistaDelReporte c) {
    final alcance = c.alcance;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: ReporteSeleccionContratos._borde),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          ReporteSeleccionContratos._etiqueta(c.tipo),
          pw.SizedBox(height: 6),
          ReporteSeleccionContratos._texto(
            c.nombre,
            tam: 12,
            negrita: true,
            lineas: 3,
          ),
          pw.SizedBox(height: 6),
          ReporteSeleccionContratos._dato('Documento', c.documento),
          if (alcance != null)
            ReporteSeleccionContratos._dato('Entidad consultada', alcance),
          pw.SizedBox(height: 5),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: ReporteSeleccionContratos._dato(
                  'Contratos',
                  '${c.contratos}',
                ),
              ),
              pw.Expanded(
                child: ReporteSeleccionContratos._dato(
                  'Entidades',
                  '${c.entidades}',
                ),
              ),
            ],
          ),
          ReporteSeleccionContratos._dato(
            'Valor contratado',
            ContractFinancialAnalysis.formatCop(c.valor),
          ),
          ReporteSeleccionContratos._dato('Última firma', c.ultimaFirma),
        ],
      ),
    );
  }
}
