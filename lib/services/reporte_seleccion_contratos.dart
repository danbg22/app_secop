import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/banderas_control.dart';
import '../utils/contract_financial_calculator.dart';
import '../utils/dependencia_contrato.dart';
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
  static const _azul = PdfColor.fromInt(0xFF0E2646);
  static const _dorado = PdfColor.fromInt(0xFFD89F22);
  static const _gris = PdfColor.fromInt(0xFF506477);

  static Future<Uint8List> generar(
    List<ContratoDelReporte> contratos, {
    DateTime? ahora,
  }) async {
    if (contratos.isEmpty) {
      throw ArgumentError('Selecciona al menos un contrato.');
    }
    final tema = await ReporteContratosPdfService.cargarTemaPdf();
    final colombia = ReporteContratosPdfService.horaColombia(ahora);
    final doc = pw.Document(
      title: 'Reporte de contratos seleccionados',
      author: 'Contrata Legal',
    );
    final contenido = <pw.Widget>[
      pw.SizedBox(height: 18),
      pw.Container(width: 52, height: 4, color: _dorado),
      pw.SizedBox(height: 16),
      pw.Text(
        'Reporte de contratos seleccionados',
        style: pw.TextStyle(
          fontSize: 28,
          fontWeight: pw.FontWeight.bold,
          color: _azul,
        ),
      ),
      pw.SizedBox(height: 10),
      _texto(ReporteContratosPdfService.fechaLarga(colombia)),
      pw.SizedBox(height: 14),
      _texto(
        'Este reporte reúne ${contratos.length} ${contratos.length == 1 ? 'contrato seleccionado' : 'contratos seleccionados'} en Contrata Legal. '
        'Cada ficha presenta el objeto, la información financiera, los campos oficiales disponibles y el listado de documentos consultados.',
      ),
      _titulo('Contratos incluidos'),
      for (final (i, contrato) in contratos.indexed)
        ..._campo(
          '${i + 1}. ${contrato.referencia.isEmpty ? 'Contrato' : contrato.referencia}',
          contrato.entidad.isEmpty ? 'Entidad sin informar' : contrato.entidad,
        ),
    ];
    for (final (i, contrato) in contratos.indexed) {
      contenido.addAll([
        pw.NewPage(),
        ..._ficha(i + 1, contratos.length, contrato),
      ]);
    }
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(44, 32, 44, 36),
        theme: tema,
        maxPages: contenido.length * 10,
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 7),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _dorado, width: 0.7),
            ),
          ),
          child: pw.Text(
            'CONTRATA LEGAL  /  CONSULTA CONTRACTUAL',
            style: pw.TextStyle(
              color: _azul,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _gris),
          ),
        ),
        build: (_) => contenido,
      ),
    );
    return doc.save();
  }

  static Iterable<pw.Widget> _ficha(
    int numero,
    int total,
    ContratoDelReporte c,
  ) sync* {
    final analisis = ContractFinancialAnalysis.fromContract(c.datos);
    final secopI = ExpedienteContratoService.esSecopI(c.datos);
    yield _titulo('Contrato $numero de $total');
    if (c.referencia.isNotEmpty) yield _texto(c.referencia, fontSize: 19);
    if (c.entidad.isNotEmpty) yield _texto(c.entidad);
    final dependencia = DependenciaContrato.desde(c.datos);
    if (dependencia != null) yield* _campo('Dependencia', dependencia);
    if (!c.expedienteCompleto) {
      yield* _campo(
        'Disponibilidad de la fuente',
        'El expediente completo no estuvo disponible al generar el reporte. Se incluyen los datos obtenidos en la búsqueda.',
      );
    }
    if (c.objeto.isNotEmpty) {
      yield _titulo('Objeto contractual');
      yield _texto(c.objeto);
    }
    if (BanderasControl.enLeyDeGarantias(c.datos) case final periodo?) {
      yield* _campo(
        'Alerta para revisión',
        'Se registró contratación directa durante el periodo de Ley de Garantías de ${periodo.eleccion} '
            '(${fechaDiaMesAnio(periodo.desde)} a ${fechaDiaMesAnio(periodo.hasta)}). Consulta la justificación en el expediente oficial.',
      );
    }
    yield _titulo('Análisis financiero y de plazo');
    if (analisis.tieneDatosFinancieros) {
      yield* _campo(
        'Valor total',
        ContractFinancialAnalysis.formatCop(analisis.valorTotal),
      );
    }
    if (analisis.tienePlazo) {
      yield* _campo('Plazo contractual', analisis.equivalenciaTexto);
      if (analisis.fuentePlazo.isNotEmpty) {
        yield* _campo('Fuente del plazo', analisis.fuentePlazo);
      }
      if (analisis.tieneDatosFinancieros) {
        yield* _campo(
          'Estimación por día',
          ContractFinancialAnalysis.formatCop(analisis.valorDiario),
        );
        if (!analisis.esMenorAUnMes) {
          yield* _campo(
            'Estimación mensual (30 días)',
            ContractFinancialAnalysis.formatCop(analisis.valorMensualEstimado),
          );
        }
        yield _texto(
          'Las estimaciones de valor por tiempo no representan pagos realizados.',
        );
      }
    } else if (!analisis.tieneDatosFinancieros) {
      yield _texto(
        'Fuente sin valor o plazo disponible para calcular estimaciones.',
      );
    }
    yield _titulo('Pagos reportados');
    if (analisis.pagos.isEmpty) {
      yield _texto(
        'Los datos consultados no informan pagos con valor positivo.',
      );
    }
    for (final entry in analisis.pagos.entries) {
      yield* _campo(
        entry.key,
        ContractFinancialAnalysis.formatCop(entry.value),
      );
    }
    if (analisis.fuentesRecursos.isNotEmpty) {
      yield _titulo('Fuentes de financiación');
      for (final entry in analisis.fuentesRecursos.entries) {
        yield* _campo(
          entry.key,
          ContractFinancialAnalysis.formatCop(entry.value),
        );
      }
    }
    yield _titulo('Ficha técnica integral');
    for (final seccion in ContractFieldCatalog.buildSections(c.datos)) {
      yield _titulo(seccion.title, menor: true);
      for (final campo in seccion.entries) {
        yield* _campo(campo.label, campo.value);
      }
    }
    yield _titulo('Documentos del expediente');
    final documentos = c.documentos;
    if (documentos == null) {
      yield _texto(
        'No fue posible obtener el listado de documentos de la fuente consultada.',
      );
    } else if (documentos.documents.isEmpty) {
      yield _texto('La consulta no devolvió documentos para este expediente.');
    } else {
      for (final item in documentos.documents) {
        yield* _campo(item.category, item.name);
        final uri = SecurityService.validateOfficialGovUrl(item.downloadUrl);
        if (uri != null) yield _enlace('Abrir documento en SECOP', uri);
      }
    }
    final rawUrl = c.datos['urlproceso'] ?? c.datos['ruta_proceso_en_secop_i'];
    final oficial = SecurityService.validateOfficialGovUrl(
      (rawUrl is Map ? rawUrl['url']?.toString() : rawUrl?.toString()) ??
          documentos?.resolvedSecopUrl,
    );
    if (oficial != null) {
      yield _enlace('Consultar expediente original', oficial);
    }
    yield pw.SizedBox(height: 10);
    yield _texto(
      'Fuente · Datos Abiertos de Colombia / ${secopI ? 'SECOP I' : 'SECOP II'}',
      fontSize: 9,
    );
  }

  static pw.Widget _titulo(String titulo, {bool menor = false}) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 13, bottom: 6),
    padding: const pw.EdgeInsets.fromLTRB(8, 5, 6, 5),
    color: menor
        ? const PdfColor.fromInt(0xFFF0F3F8)
        : const PdfColor.fromInt(0xFFE6EDF7),
    child: pw.Text(
      titulo,
      style: pw.TextStyle(
        fontSize: menor ? 11 : 14,
        color: _azul,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );

  static Iterable<pw.Widget> _campo(String etiqueta, String valor) sync* {
    if (valor.isEmpty) return;
    yield pw.SizedBox(height: 5);
    yield pw.RichText(
      overflow: pw.TextOverflow.span,
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$etiqueta\n',
            style: pw.TextStyle(
              fontSize: 9,
              height: 1.25,
              color: _azul,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.TextSpan(
            text: valor,
            style: const pw.TextStyle(fontSize: 10, height: 1.28, color: _gris),
          ),
        ],
      ),
    );
  }

  static pw.Widget _texto(String texto, {double fontSize = 11}) => pw.Text(
    texto,
    overflow: pw.TextOverflow.span,
    style: pw.TextStyle(fontSize: fontSize, height: 1.28, color: _gris),
  );

  static pw.Widget _enlace(String titulo, Uri url) => pw.UrlLink(
    destination: url.toString(),
    child: pw.Text(
      titulo,
      style: const pw.TextStyle(
        fontSize: 9,
        color: _azul,
        decoration: pw.TextDecoration.underline,
      ),
    ),
  );
}
