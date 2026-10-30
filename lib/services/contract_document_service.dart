import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/secop_launcher.dart';
import 'contract_audit_analysis.dart';
import 'security_service.dart';

class ExpectedDocumentItem {
  const ExpectedDocumentItem({
    required this.name,
    required this.legalReference,
    required this.description,
    required this.isMandatory,
    required this.icon,
    this.status = 'CUSTODIADO EN SECOP II',
  });

  final String name;
  final String legalReference;
  final String description;
  final bool isMandatory;
  final IconData icon;
  final String status;
}

class ContractDocumentService {
  /// Obtiene la URL oficial del proceso en el portal transaccional de SECOP II.
  static String obtenerUrlSecop(dynamic rawContract) {
    final Map<String, dynamic> c = rawContract is Map
        ? Map<String, dynamic>.from(rawContract)
        : <String, dynamic>{};

    final rawUrl = c['urlproceso'];
    String candidate = '';
    if (rawUrl is Map && rawUrl['url'] != null) {
      candidate = rawUrl['url'].toString();
    } else if (rawUrl is String && rawUrl.trim().isNotEmpty) {
      candidate = rawUrl;
    }
    final safeCandidate = SecurityService.validateOfficialGovUrl(candidate);
    if (safeCandidate != null) {
      return safeCandidate.toString();
    }

    final proceso = c['proceso_de_compra']?.toString().trim() ?? '';
    if (proceso.isNotEmpty) {
      return 'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=${Uri.encodeComponent(proceso)}';
    }

    return 'https://www.colombiacompra.gov.co/secop-ii';
  }

  /// BOTÓN 1: El Acceso Oficial (Opción A)
  /// Abre directamente el portal transaccional de SECOP II en la pestaña del proceso,
  /// donde reposan los archivos escaneados originales (24+ folios, firmas y sellos).
  static Future<void> abrirDocumentosOficialesSecop(
    BuildContext context,
    dynamic rawContract,
  ) async {
    final uri = SecurityService.validateOfficialGovUrl(
      obtenerUrlSecop(rawContract),
    );

    if (uri != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Abriendo portal oficial de SECOP II para consultar los PDFs originales escaneados...',
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF1E293B),
          duration: Duration(seconds: 3),
        ),
      );

      if (kIsWeb) {
        final opened = openControlledSecopPopup(uri.toString());
        if (!opened) {
          await launchUrl(
            uri,
            mode: LaunchMode.inAppBrowserView,
            webOnlyWindowName: 'secop_expediente_oficial',
          );
        }
      } else {
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
        if (!opened) {
          await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible abrir el enlace oficial de SECOP II.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// BOTÓN 2: El Resumen Inteligente (Opción B)
  /// Ejecuta el análisis (Gemini o motor de reglas) y descarga el
  /// "Certificado de Auditoría Avanzado" en PDF.
  static Future<void> descargarResumenInteligente(
    BuildContext context,
    dynamic rawContract,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    _mostrarProgreso(messenger);
    try {
      final Map<String, dynamic> c = rawContract is Map
          ? Map<String, dynamic>.from(rawContract)
          : <String, dynamic>{};
      final ref = _sanitizeCode(
        c['referencia_del_contrato'] ??
            c['id_contrato'] ??
            c['proceso_de_compra'] ??
            'EXP',
      );
      final fileName = SecurityService.sanitizeFileName(
        'Certificado_Auditoria_Avanzado_$ref.pdf',
        fallback: 'Certificado_Auditoria_Avanzado_EXP.pdf',
      );

      final analysis = await ContractAuditAnalyzer.analizar(c);
      final bytes = generarPdfResumenInteligente(c, analysis);

      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..setAttribute('rel', 'noopener noreferrer')
        ..click();
      Future<void>.delayed(
        const Duration(seconds: 30),
        () => html.Url.revokeObjectUrl(url),
      );

      _mostrarResultado(messenger, analysis, 'Descargando $fileName');
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Error al generar el certificado: ${SecurityService.sanitizeErrorMessage(e)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  /// Visualiza el certificado en una nueva pestaña del navegador.
  static Future<void> abrirResumenEnNavegador(
    BuildContext context,
    dynamic rawContract,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // La pestaña se abre ANTES del await para que el navegador no la bloquee
    // como ventana emergente (debe ocurrir dentro del gesto del usuario).
    final dynamic tab = html.window.open('', '_blank');
    try {
      tab.opener = null;
    } catch (_) {}
    _mostrarProgreso(messenger);
    try {
      final Map<String, dynamic> c = rawContract is Map
          ? Map<String, dynamic>.from(rawContract)
          : <String, dynamic>{};
      final analysis = await ContractAuditAnalyzer.analizar(c);
      final bytes = generarPdfResumenInteligente(c, analysis);
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      tab.location.href = url;
      Future<void>.delayed(
        const Duration(seconds: 60),
        () => html.Url.revokeObjectUrl(url),
      );

      _mostrarResultado(
        messenger,
        analysis,
        'Certificado abierto en una nueva pestaña',
      );
    } catch (e) {
      try {
        tab.close();
      } catch (_) {}
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Error al abrir el certificado: ${SecurityService.sanitizeErrorMessage(e)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  static void _mostrarProgreso(ScaffoldMessengerState messenger) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Analizando el contrato y generando el Certificado de Auditoría Avanzado...',
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF1E293B),
          duration: Duration(seconds: 60),
        ),
      );
  }

  static void _mostrarResultado(
    ScaffoldMessengerState messenger,
    ContractAuditAnalysis analysis,
    String accion,
  ) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            analysis.esIA
                ? '$accion · Análisis generado con IA (${analysis.modelo}).'
                : '$accion · IA no disponible: se usó el motor de reglas local.',
          ),
          backgroundColor: analysis.esIA
              ? const Color(0xFF059669)
              : const Color(0xFFB45309),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  /// Lista los documentos esperados para este proceso según el Estatuto General de Contratación Pública en Colombia.
  static List<ExpectedDocumentItem> getExpectedDocumentsForContract(
    dynamic rawContract,
  ) {
    final Map<String, dynamic> c = rawContract is Map<String, dynamic>
        ? rawContract
        : {};

    final modalidad = (c['modalidad_de_contratacion'] ?? '')
        .toString()
        .toUpperCase();

    final isDirecta = modalidad.contains('DIRECTA');
    final isMinima =
        modalidad.contains('MINIMA') || modalidad.contains('MÍNIMA');

    return [
      const ExpectedDocumentItem(
        name: 'Estudios y Documentos Previos',
        legalReference: 'Art. 25 Num. 7 y 12 Ley 80/93 - Dcto 1082/15',
        description: 'Análisis del sector, justificación de conveniencia técnica y matriz de riesgos previsibles.',
        isMandatory: true,
        icon: Icons.assignment_outlined,
      ),
      const ExpectedDocumentItem(
        name: 'Certificado de Disponibilidad Presupuestal (CDP)',
        legalReference: 'Art. 71 Dcto. 111 de 1996 (Estatuto Presupuestal)',
        description: 'Garantiza apropiación suficiente en el rubro del gasto antes de iniciar el compromiso.',
        isMandatory: true,
        icon: Icons.account_balance_wallet_outlined,
      ),
      ExpectedDocumentItem(
        name: isDirecta
            ? 'Acto de Justificación / Términos de Referencia'
            : (isMinima
                  ? 'Invitación Pública y Pliego de Mínima Cuantía'
                  : 'Pliego de Condiciones Definitivo y Anexos'),
        legalReference: isDirecta
            ? 'Art. 2.2.1.2.1.4.1 Decreto 1082 de 2015'
            : (isMinima
                  ? 'Art. 2 Num. 5 Ley 1150/07 y Dcto 1082/15'
                  : 'Art. 30 Ley 80 de 1993 y Ley 1150 de 2007'),
        description: isDirecta
            ? 'Fijación de alcance, perfil de idoneidad, obligaciones y honorarios pactados.'
            : 'Reglas definitivas de participación, criterios de evaluación y anexos técnicos.',
        isMandatory: true,
        icon: Icons.menu_book_outlined,
      ),
      ExpectedDocumentItem(
        name: isDirecta
            ? 'Propuesta Económica y Hoja de Vida SIGEP'
            : 'Acto de Adjudicación / Resolución Definitiva',
        legalReference: isDirecta
            ? 'Ley 190 de 1995 y Decreto 1083 de 2015'
            : 'Art. 9 Ley 1150 de 2007 (Irrevocable)',
        description: isDirecta
            ? 'Oferta formal, constancia de idoneidad, antecedentes y declaración de bienes y rentas.'
            : 'Acto administrativo que asigna el contrato al oferente mejor calificado.',
        isMandatory: true,
        icon: Icons.verified_outlined,
      ),
      const ExpectedDocumentItem(
        name: 'Minuta del Contrato Estatal Suscrito',
        legalReference: 'Art. 39 y 41 de la Ley 80 de 1993',
        description: 'Documento perfeccionado con cláusulas obligatorias, valor, plazo y firmas de las partes.',
        isMandatory: true,
        icon: Icons.history_edu_outlined,
      ),
      const ExpectedDocumentItem(
        name: 'Póliza de Cumplimiento y Aprobación',
        legalReference: 'Art. 7 Ley 1150 de 2007 y Dcto 1082/15',
        description: 'Garantía con amparos de cumplimiento, calidad, salarios y prestaciones sociales.',
        isMandatory: true,
        icon: Icons.shield_outlined,
      ),
      const ExpectedDocumentItem(
        name: 'Registro Presupuestal (RP) y Supervisión',
        legalReference: 'Ley 1474 de 2011 (Estatuto Anticorrupción)',
        description: 'Afectación presupuestal definitiva y acto de designación del supervisor o interventor.',
        isMandatory: true,
        icon: Icons.fact_check_outlined,
      ),
      const ExpectedDocumentItem(
        name: 'Acta de Inicio, Informes y Liquidación',
        legalReference: 'Art. 60 Ley 80/93 y Art. 11 Ley 1150/07',
        description: 'Control de plazos, pagos a seguridad social, informes de avance y acta de liquidación.',
        isMandatory: true,
        icon: Icons.task_alt_outlined,
        status: 'EXPEDIENTE EN CURSO',
      ),
    ];
  }

  /// Genera el PDF del "Certificado de Auditoría Avanzado".
  static Uint8List generarPdfResumenInteligente(
    Map<String, dynamic> c, [
    ContractAuditAnalysis? analysis,
  ]) {
    analysis ??= ContractAuditAnalyzer.analizarPorReglas(
      c,
      ContractMetrics.from(c),
    );

    String campo(String k, [String porDefecto = 'No reportado']) {
      final v = c[k];
      final t = (v is Map ? v['url'] : v)?.toString().trim() ?? '';
      return (t.isEmpty || t.toLowerCase() == 'null') ? porDefecto : t;
    }

    final metrics = ContractMetrics.from(c);
    final proceso = campo('proceso_de_compra', campo('id_contrato'));
    final ciudad = campo('ciudad', '');
    final depto = campo('departamento', '');
    final ubicacion = [ciudad, depto].where((e) => e.isNotEmpty).join(', ');
    final docProv = campo('documento_proveedor');
    final tipoDocProv = campo('tipodocproveedor', '');

    final data = _PdfContractData(
      entidad: campo('nombre_entidad'),
      nitEntidad: campo('nit_entidad'),
      contratista: campo('proveedor_adjudicado'),
      docContratista: tipoDocProv.isEmpty ? docProv : '$tipoDocProv: $docProv',
      proceso: proceso,
      referencia: campo('referencia_del_contrato', campo('id_contrato')),
      idContrato: campo('id_contrato'),
      modalidad: campo('modalidad_de_contratacion'),
      tipoContrato: campo('tipo_de_contrato'),
      estado: campo('estado_contrato'),
      sector: campo('sector'),
      orden: campo('orden'),
      ubicacion: ubicacion.isEmpty ? 'No reportada' : ubicacion,
      objeto: campo(
        'descripcion_del_proceso',
        campo(
          'objeto_del_contrato',
          'Objeto no reportado en los datos abiertos.',
        ),
      ),
      urlSecop: obtenerUrlSecop(c),
    );

    return _SmartSummaryPdfEngine.construir(
      data: data,
      metrics: metrics,
      analysis: analysis,
      expectedDocs: getExpectedDocumentsForContract(c),
    );
  }

  static String _sanitizeCode(dynamic val) {
    final s = val?.toString() ?? '';
    return s
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }
}

class _PdfContractData {
  const _PdfContractData({
    required this.entidad,
    required this.nitEntidad,
    required this.contratista,
    required this.docContratista,
    required this.proceso,
    required this.referencia,
    required this.idContrato,
    required this.modalidad,
    required this.tipoContrato,
    required this.estado,
    required this.sector,
    required this.orden,
    required this.ubicacion,
    required this.objeto,
    required this.urlSecop,
  });

  final String entidad;
  final String nitEntidad;
  final String contratista;
  final String docContratista;
  final String proceso;
  final String referencia;
  final String idContrato;
  final String modalidad;
  final String tipoContrato;
  final String estado;
  final String sector;
  final String orden;
  final String ubicacion;
  final String objeto;
  final String urlSecop;
}

/// Documento PDF con soporte de flujo (salto de página automático).
class _PdfDoc {
  _PdfDoc({required this.tituloContinuacion, required this.subContinuacion});

  final String tituloContinuacion;
  final String subContinuacion;
  final List<StringBuffer> pages = [];
  late StringBuffer cur;

  /// Coordenada superior del siguiente bloque en la página actual.
  double y = 0;

  static const double bottomLimit = 64;

  StringBuffer addBlankPage() {
    cur = StringBuffer();
    pages.add(cur);
    return cur;
  }

  void addFlowPage() {
    addBlankPage();
    _SmartSummaryPdfEngine._rect(
      cur,
      0,
      _SmartSummaryPdfEngine._h - 46,
      _SmartSummaryPdfEngine._w,
      46,
      fill: _SmartSummaryPdfEngine._navy,
    );
    _SmartSummaryPdfEngine._rect(
      cur,
      0,
      _SmartSummaryPdfEngine._h - 49,
      _SmartSummaryPdfEngine._w,
      3,
      fill: _SmartSummaryPdfEngine._gold,
    );
    _SmartSummaryPdfEngine._text(
      cur,
      tituloContinuacion,
      _SmartSummaryPdfEngine._l,
      _SmartSummaryPdfEngine._h - 22,
      size: 10,
      bold: true,
      color: '1 1 1',
    );
    _SmartSummaryPdfEngine._text(
      cur,
      subContinuacion,
      _SmartSummaryPdfEngine._l,
      _SmartSummaryPdfEngine._h - 36,
      size: 7.2,
      color: '0.82 0.88 0.96',
    );
    y = _SmartSummaryPdfEngine._h - 64;
  }

  void ensure(double h) {
    if (y - h < bottomLimit) addFlowPage();
  }
}

/// Motor generador del PDF (estándar PDF 1.4, fuentes Helvetica WinAnsi).
class _SmartSummaryPdfEngine {
  static const double _w = 595.28;
  static const double _h = 841.89;
  static const double _l = 35.0;
  static const double _cw = 525.28;

  static const String _navy = '0.06 0.13 0.24';
  static const String _gold = '0.96 0.72 0.18';
  static const String _ink = '0.12 0.16 0.24';
  static const String _muted = '0.35 0.40 0.50';

  static Uint8List construir({
    required _PdfContractData data,
    required ContractMetrics metrics,
    required ContractAuditAnalysis analysis,
    required List<ExpectedDocumentItem> expectedDocs,
  }) {
    final now = DateTime.now();
    final fechaEmision =
        '${ContractMetrics.formatoFecha(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final hash =
        'CTL-${_hashStr(data.proceso + data.referencia + metrics.valor.toString()).substring(0, 16).toUpperCase()}';
    final origenTxt = analysis.esIA
        ? 'Análisis generado por IA (${analysis.modelo}) sobre datos abiertos'
        : 'Análisis automático por reglas (IA no disponible en esta emisión)';

    final doc = _PdfDoc(
      tituloContinuacion: 'CERTIFICADO DE AUDITORÍA AVANZADO · CONTRATA LEGAL',
      subContinuacion:
          'Proceso ${_fit(data.proceso, 160, 7.2)}  ·  ${_fit(data.entidad, 280, 7.2)}  ·  Código $hash',
    );

    _paginaFicha(doc, data, metrics, analysis, fechaEmision, hash, origenTxt);
    _paginasAnalisis(
      doc,
      data,
      metrics,
      analysis,
      origenTxt,
      hash,
      fechaEmision,
    );
    _paginaMatriz(doc, data, expectedDocs);

    // Pies de página con numeración total.
    final total = doc.pages.length;
    for (var i = 0; i < total; i++) {
      final p = doc.pages[i];
      _rect(p, _l, 46, _cw, 0.5, fill: '0.82 0.85 0.90');
      _text(
        p,
        'Contrata Legal · Certificado de Auditoría Avanzado (documento ciudadano no oficial) · $hash',
        _l,
        34,
        size: 6.8,
        color: '0.40 0.45 0.55',
      );
      _text(
        p,
        'Página ${i + 1} de $total',
        _w - 95,
        34,
        size: 7.5,
        bold: true,
        color: '0.10 0.18 0.30',
      );
    }

    return _ensamblarPdf(doc.pages.map((b) => b.toString()).toList());
  }

  // ===========================================================================
  // PÁGINA 1: FICHA TÉCNICA + DICTAMEN EJECUTIVO
  // ===========================================================================
  static void _paginaFicha(
    _PdfDoc doc,
    _PdfContractData d,
    ContractMetrics m,
    ContractAuditAnalysis a,
    String fechaEmision,
    String hash,
    String origenTxt,
  ) {
    final p = doc.addBlankPage();

    _rect(p, 0, _h - 72, _w, 72, fill: _navy);
    _rect(p, 0, _h - 76, _w, 4, fill: _gold);
    _text(
      p,
      'CERTIFICADO DE AUDITORÍA AVANZADO',
      _l,
      _h - 28,
      size: 14,
      bold: true,
      color: '1 1 1',
    );
    _text(
      p,
      'CONTRATA LEGAL · AUDITORÍA CIUDADANA DE CONTRATACIÓN ESTATAL · SECOP II',
      _l,
      _h - 43,
      size: 8,
      color: '0.82 0.88 0.96',
    );
    _text(
      p,
      'Fuente: datos abiertos de Colombia (datos.gov.co) · Documento analítico no oficial',
      _l,
      _h - 56,
      size: 7.2,
      color: '0.65 0.75 0.88',
    );

    _rect(
      p,
      _w - 195,
      _h - 64,
      160,
      52,
      fill: '0.09 0.18 0.32',
      stroke: '0.20 0.32 0.50',
      lw: 0.8,
    );
    _text(
      p,
      'CÓDIGO DE TRAZABILIDAD',
      _w - 187,
      _h - 25,
      size: 6.4,
      bold: true,
      color: _gold,
    );
    _text(p, hash, _w - 187, _h - 36, size: 8, bold: true, color: '1 1 1');
    _text(
      p,
      'Emitido: $fechaEmision',
      _w - 187,
      _h - 48,
      size: 6.5,
      color: '0.80 0.86 0.94',
    );
    _text(
      p,
      a.esIA ? 'Motor: IA Gemini' : 'Motor: reglas locales',
      _w - 187,
      _h - 58,
      size: 6.5,
      color: '0.80 0.86 0.94',
    );

    // Aviso de transparencia
    _rect(
      p,
      _l,
      _h - 120,
      _cw,
      36,
      fill: '0.99 0.98 0.92',
      stroke: '0.92 0.78 0.35',
      lw: 0.8,
    );
    _text(
      p,
      'AVISO DE TRANSPARENCIA',
      _l + 10,
      _h - 96,
      size: 7.5,
      bold: true,
      color: '0.62 0.40 0.04',
    );
    _text(
      p,
      'Este certificado es un análisis ciudadano generado por la plataforma a partir de los metadatos de texto de SECOP II. No es una',
      _l + 10,
      _h - 106,
      size: 7,
      color: '0.35 0.25 0.08',
    );
    _text(
      p,
      'certificación de un organismo de control ni sustituye los documentos oficiales, que se consultan en community.secop.gov.co.',
      _l + 10,
      _h - 115,
      size: 7,
      color: '0.35 0.25 0.08',
    );

    double y = _h - 138;
    const colW = (_cw - 6) / 2;
    const rowH = 26.0;

    _sectionHeaderAt(p, '1. IDENTIFICACIÓN DEL PROCESO', y);
    y -= 14;
    _cell(
      p,
      _l,
      y - rowH,
      colW,
      rowH,
      'Número de proceso SECOP II',
      d.proceso,
      bold: true,
    );
    _cell(
      p,
      _l + colW + 6,
      y - rowH,
      colW,
      rowH,
      'Referencia / ID del contrato',
      '${d.referencia}  ·  ${d.idContrato}',
      bold: true,
    );
    y -= rowH + 4;
    _cell(p, _l, y - rowH, colW, rowH, 'Modalidad de selección', d.modalidad);
    _cell(
      p,
      _l + colW + 6,
      y - rowH,
      colW,
      rowH,
      'Tipo de contrato',
      d.tipoContrato,
    );
    y -= rowH + 4;
    _cell(
      p,
      _l,
      y - rowH,
      colW,
      rowH,
      'Estado reportado',
      d.estado,
      bold: true,
      valueColor: '0.05 0.45 0.20',
    );
    _cell(
      p,
      _l + colW + 6,
      y - rowH,
      colW,
      rowH,
      'Sector de inversión',
      d.sector,
    );
    y -= rowH + 12;

    _sectionHeaderAt(p, '2. ACTORES CONTRACTUALES', y);
    y -= 14;
    _cell(
      p,
      _l,
      y - rowH,
      colW,
      rowH,
      'Entidad contratante',
      d.entidad,
      bold: true,
    );
    _cell(
      p,
      _l + colW + 6,
      y - rowH,
      colW,
      rowH,
      'NIT entidad · Orden · Ubicación',
      '${d.nitEntidad}  ·  ${d.orden}  ·  ${d.ubicacion}',
    );
    y -= rowH + 4;
    _cell(
      p,
      _l,
      y - rowH,
      colW,
      rowH,
      'Contratista adjudicado',
      d.contratista,
      bold: true,
    );
    _cell(
      p,
      _l + colW + 6,
      y - rowH,
      colW,
      rowH,
      'Identificación · Tipo de persona',
      '${d.docContratista}  ·  ${m.tipoPersona}',
    );
    y -= rowH + 12;

    _sectionHeaderAt(p, '3. CONDICIONES FINANCIERAS Y CRONOGRAMA', y);
    y -= 14;
    const kpiW = (_cw - 15) / 4;
    const kpiH = 38.0;
    _kpi(
      p,
      _l,
      y - kpiH,
      kpiW,
      kpiH,
      'Valor total',
      ContractMetrics.formatoCop(m.valor > 0 ? m.valor : null),
      green: true,
    );
    _kpi(
      p,
      _l + (kpiW + 5),
      y - kpiH,
      kpiW,
      kpiH,
      'Fecha de firma',
      ContractMetrics.formatoFecha(m.fechaFirma),
    );
    _kpi(
      p,
      _l + (kpiW + 5) * 2,
      y - kpiH,
      kpiW,
      kpiH,
      'Inicio → fin',
      '${ContractMetrics.formatoFecha(m.fechaInicio)} → ${ContractMetrics.formatoFecha(m.fechaFin)}',
    );
    _kpi(
      p,
      _l + (kpiW + 5) * 3,
      y - kpiH,
      kpiW,
      kpiH,
      'Plazo',
      m.plazoDias == null ? 'No calculable' : '${m.plazoDias} días',
    );
    y -= kpiH + 12;

    _sectionHeaderAt(p, '4. OBJETO DEL CONTRATO', y);
    y -= 14;
    final objLines = _wrap(d.objeto, _cw - 20, 7.6);
    final shown = objLines.take(5).toList();
    if (objLines.length > 5) {
      shown[4] =
          '${_fit(shown[4], _cw - 40, 7.6)} (continúa en la sección 2 del análisis)';
    }
    final objH = 20.0 + shown.length * 11;
    _rect(
      p,
      _l,
      y - objH,
      _cw,
      objH,
      fill: '0.985 0.99 1.0',
      stroke: '0.82 0.86 0.92',
      lw: 0.8,
    );
    var ty = y - 14;
    for (final line in shown) {
      _text(p, line, _l + 10, ty, size: 7.6, color: _ink);
      ty -= 11;
    }
    y -= objH + 14;

    // Dictamen ejecutivo
    _sectionHeaderAt(p, '5. DICTAMEN EJECUTIVO DE AUDITORÍA', y);
    y -= 14;
    final resumenLines = _wrap(a.resumenEjecutivo, _cw - 20, 7.5);
    final maxLines = ((y - 70 - 52) / 10.5).floor().clamp(3, 14);
    final resShown = resumenLines.take(maxLines).toList();
    if (resumenLines.length > maxLines) {
      resShown[resShown.length - 1] =
          '${_fit(resShown.last, _cw - 70, 7.5)} (...)';
    }
    final dictH = 44.0 + resShown.length * 10.5;
    _rect(
      p,
      _l,
      y - dictH,
      _cw,
      dictH,
      fill: '0.96 0.97 0.99',
      stroke: '0.30 0.45 0.70',
      lw: 0.9,
    );

    final pillW = (_cw - 30) / 3;
    _pill(
      p,
      _l + 8,
      y - 26,
      pillW,
      18,
      'CALIFICACIÓN',
      a.calificacion,
      _riskColor(a.nivelRiesgo),
    );
    _pill(
      p,
      _l + 15 + pillW,
      y - 26,
      pillW,
      18,
      'NIVEL DE RIESGO',
      a.nivelRiesgo,
      _riskColor(a.nivelRiesgo),
    );
    _pill(
      p,
      _l + 22 + pillW * 2,
      y - 26,
      pillW,
      18,
      'MONTO vs MODALIDAD',
      a.coherenciaMontoModalidad,
      _coherenceColor(a.coherenciaMontoModalidad),
    );

    ty = y - 40;
    for (final line in resShown) {
      _text(p, line, _l + 10, ty, size: 7.5, color: _ink);
      ty -= 10.5;
    }
    _text(
      p,
      origenTxt,
      _l + 10,
      y - dictH + 6,
      size: 6.3,
      italic: true,
      color: '0.25 0.35 0.50',
    );
  }

  // ===========================================================================
  // PÁGINAS DE ANÁLISIS AVANZADO (flujo con salto automático)
  // ===========================================================================
  static void _paginasAnalisis(
    _PdfDoc doc,
    _PdfContractData d,
    ContractMetrics m,
    ContractAuditAnalysis a,
    String origenTxt,
    String hash,
    String fechaEmision,
  ) {
    doc.addFlowPage();

    // Banda de origen del análisis
    final bandColor = a.esIA ? '0.92 0.97 0.94' : '1.0 0.97 0.90';
    final bandStroke = a.esIA ? '0.50 0.80 0.60' : '0.92 0.75 0.35';
    _rect(
      doc.cur,
      _l,
      doc.y - 24,
      _cw,
      24,
      fill: bandColor,
      stroke: bandStroke,
      lw: 0.7,
    );
    _text(
      doc.cur,
      a.esIA ? 'ORIGEN: INTELIGENCIA ARTIFICIAL' : 'ORIGEN: MOTOR DE REGLAS',
      _l + 10,
      doc.y - 10,
      size: 6.8,
      bold: true,
      color: a.esIA ? '0.05 0.45 0.20' : '0.62 0.40 0.04',
    );
    _text(
      doc.cur,
      '$origenTxt. Las frases marcadas "(inferencia)" son deducciones, no hechos verificados.',
      _l + 10,
      doc.y - 19,
      size: 6.6,
      color: _muted,
    );
    doc.y -= 36;

    // 1. Monto vs modalidad
    _flowSection(doc, '1. ANÁLISIS DE COHERENCIA MONTO vs. MODALIDAD');
    _flowCellsRow(doc, [
      ['Modalidad', d.modalidad],
      ['Valor', ContractMetrics.formatoCop(m.valor > 0 ? m.valor : null)],
      ['Dictamen', a.coherenciaMontoModalidad],
    ]);
    _flowParagraph(doc, a.analisisMontoModalidad);
    if (a.causalProbable.isNotEmpty) {
      _flowLabeled(doc, 'Causal o fundamento probable: ', a.causalProbable);
    }
    doc.y -= 8;

    // 2. Desglose del objeto
    _flowSection(doc, '2. DESGLOSE DEL OBJETO CONTRACTUAL');
    _flowCellsRow(doc, [
      ['Naturaleza', a.naturalezaObjeto],
      ['Sector', a.sectorInferido],
    ]);
    _flowLabeled(doc, 'Beneficiarios: ', a.beneficiarios);
    _flowLabeled(doc, 'Objeto completo: ', d.objeto);
    if (a.componentesObjeto.isNotEmpty) {
      _flowSubtitle(doc, 'Componentes y entregables identificados');
      _flowNumbered(doc, a.componentesObjeto);
    }
    doc.y -= 8;

    // 3. Indicadores financieros
    _flowSection(doc, '3. INDICADORES Y ANÁLISIS FINANCIERO');
    _flowCellsRow(doc, [
      ['Valor total', ContractMetrics.formatoCop(m.valor > 0 ? m.valor : null)],
      ['Promedio diario', ContractMetrics.formatoCop(m.valorDiario)],
      ['Promedio mensual', ContractMetrics.formatoCop(m.valorMensual)],
      [
        'Vigencias',
        m.superaVigenciaFiscal
            ? 'Supera el año fiscal'
            : 'Dentro del año / N.D.',
      ],
    ]);
    _flowBullets(doc, a.analisisFinanciero);
    doc.y -= 8;

    // 4. Temporal
    _flowSection(doc, '4. ANÁLISIS TEMPORAL Y DE EJECUCIÓN');
    _flowCellsRow(doc, [
      ['Firma', ContractMetrics.formatoFecha(m.fechaFirma)],
      ['Inicio', ContractMetrics.formatoFecha(m.fechaInicio)],
      ['Fin', ContractMetrics.formatoFecha(m.fechaFin)],
      ['Vigencia a hoy', m.estadoVigencia],
    ]);
    _flowParagraph(doc, a.analisisTemporal);
    doc.y -= 8;

    // 5. Alertas
    _flowSection(doc, '5. ALERTAS Y BANDERAS ROJAS (${a.alertas.length})');
    if (a.alertas.isEmpty) {
      _flowParagraph(
        doc,
        'No se identificaron alertas a partir de los metadatos disponibles. Esto no descarta hallazgos en el expediente documental.',
      );
    } else {
      for (final al in a.alertas) {
        _flowAlert(doc, al);
      }
    }
    doc.y -= 8;

    // 6. Marco legal
    _flowSection(doc, '6. MARCO LEGAL APLICABLE');
    _flowLegalTable(doc, a.marcoLegal);
    doc.y -= 8;

    // 7. Recomendaciones
    _flowSection(doc, '7. RECOMENDACIONES PARA VEEDURÍA Y CONTROL SOCIAL');
    _flowNumbered(doc, a.recomendaciones);
    doc.y -= 8;

    // 8. Limitaciones
    _flowSection(doc, '8. INFORMACIÓN NO DISPONIBLE EN DATOS ABIERTOS');
    _flowBullets(doc, a.datosNoDisponibles, color: _muted);
    doc.y -= 10;

    // Constancia final
    doc.ensure(62);
    final p = doc.cur;
    final y = doc.y;
    _rect(
      p,
      _l,
      y - 56,
      _cw,
      56,
      fill: '0.96 0.97 0.98',
      stroke: '0.80 0.85 0.90',
      lw: 0.8,
    );
    _text(
      p,
      'CONSTANCIA DE EMISIÓN',
      _l + 10,
      y - 13,
      size: 7.2,
      bold: true,
      color: '0.15 0.25 0.40',
    );
    _text(
      p,
      'Emitido el $fechaEmision por la plataforma Contrata Legal. Código de trazabilidad: $hash.',
      _l + 10,
      y - 25,
      size: 6.8,
      color: _muted,
    );
    _text(
      p,
      'Documento ciudadano de carácter informativo, amparado en el derecho de acceso a la información pública (Ley 1712 de 2014)',
      _l + 10,
      y - 36,
      size: 6.8,
      color: _muted,
    );
    _text(
      p,
      'y en el control social a la gestión pública (Ley 850 de 2003). No reemplaza los documentos oficiales del proceso.',
      _l + 10,
      y - 47,
      size: 6.8,
      italic: true,
      color: _muted,
    );
    doc.y -= 66;
  }

  // ===========================================================================
  // ÚLTIMA PÁGINA: MATRIZ DE EXPEDIENTE DOCUMENTAL ESPERADO
  // ===========================================================================
  static void _paginaMatriz(
    _PdfDoc doc,
    _PdfContractData d,
    List<ExpectedDocumentItem> expectedDocs,
  ) {
    final p = doc.addBlankPage();
    _rect(p, 0, _h - 48, _w, 48, fill: _navy);
    _rect(p, 0, _h - 51, _w, 3, fill: _gold);
    _text(
      p,
      'MATRIZ DE EXPEDIENTE DOCUMENTAL ESPERADO Y CONTROL DE LEGALIDAD',
      _l,
      _h - 24,
      size: 10.5,
      bold: true,
      color: '1 1 1',
    );
    _text(
      p,
      'Proceso: ${_fit(d.proceso, 180, 7.5)}   ·   Entidad: ${_fit(d.entidad, 260, 7.5)}',
      _l,
      _h - 38,
      size: 7.5,
      color: '0.82 0.88 0.96',
    );

    var y = _h - 68;
    _text(
      p,
      'Documentos que, según la modalidad, deberían existir en el expediente (no se verificó su contenido):',
      _l,
      y,
      size: 7.6,
      bold: true,
      color: '0.08 0.18 0.35',
    );
    y -= 14;

    const c1 = 26.0, c2 = 140.0, c3 = 112.0, c4 = 88.0;
    const c5 = _cw - c1 - c2 - c3 - c4;
    _rect(p, _l, y - 18, _cw, 18, fill: '0.10 0.20 0.38');
    _text(p, 'No.', _l + 6, y - 12, size: 6.8, bold: true, color: '1 1 1');
    _text(
      p,
      'DOCUMENTO',
      _l + c1 + 6,
      y - 12,
      size: 6.8,
      bold: true,
      color: '1 1 1',
    );
    _text(
      p,
      'FUNDAMENTO LEGAL',
      _l + c1 + c2 + 6,
      y - 12,
      size: 6.8,
      bold: true,
      color: '1 1 1',
    );
    _text(
      p,
      'UBICACIÓN',
      _l + c1 + c2 + c3 + 6,
      y - 12,
      size: 6.8,
      bold: true,
      color: '1 1 1',
    );
    _text(
      p,
      'CONTENIDO OBLIGATORIO',
      _l + c1 + c2 + c3 + c4 + 6,
      y - 12,
      size: 6.8,
      bold: true,
      color: '1 1 1',
    );
    y -= 18;

    const rowH = 40.0;
    for (var i = 0; i < expectedDocs.length; i++) {
      final doc0 = expectedDocs[i];
      _rect(
        p,
        _l,
        y - rowH,
        _cw,
        rowH,
        fill: i.isEven ? '1 1 1' : '0.975 0.985 0.995',
        stroke: '0.84 0.87 0.91',
        lw: 0.5,
      );
      var sx = _l + c1;
      for (final cw in [c2, c3, c4]) {
        _rect(p, sx, y - rowH, 0.5, rowH, fill: '0.86 0.89 0.93');
        sx += cw;
      }
      _rect(p, sx, y - rowH, 0.5, rowH, fill: '0.86 0.89 0.93');

      _text(
        p,
        (i + 1).toString().padLeft(2, '0'),
        _l + 8,
        y - 22,
        size: 7.5,
        bold: true,
        color: '0.20 0.30 0.45',
      );

      final nameLines = _wrap(
        doc0.name,
        c2 - 12,
        7.2,
        bold: true,
      ).take(2).toList();
      var ny = y - 13;
      for (final l in nameLines) {
        _text(
          p,
          l,
          _l + c1 + 6,
          ny,
          size: 7.2,
          bold: true,
          color: '0.08 0.15 0.30',
        );
        ny -= 9;
      }
      _rect(
        p,
        _l + c1 + 6,
        y - rowH + 5,
        76,
        10,
        fill: '0.92 0.98 0.94',
        stroke: '0.65 0.88 0.72',
        lw: 0.5,
      );
      _text(
        p,
        'REQUERIDO POR LEY',
        _l + c1 + 10,
        y - rowH + 8,
        size: 5.8,
        bold: true,
        color: '0.04 0.48 0.22',
      );

      var ly = y - 14;
      for (final l in _wrap(
        doc0.legalReference,
        c3 - 12,
        6.7,
        italic: true,
      ).take(3)) {
        _text(
          p,
          l,
          _l + c1 + c2 + 6,
          ly,
          size: 6.7,
          italic: true,
          color: '0.25 0.35 0.45',
        );
        ly -= 9;
      }

      _rect(
        p,
        _l + c1 + c2 + c3 + 5,
        y - 26,
        c4 - 10,
        14,
        fill: '0.90 0.96 0.99',
        stroke: '0.45 0.72 0.95',
        lw: 0.6,
      );
      _text(
        p,
        _fit(doc0.status, c4 - 16, 5.8, bold: true),
        _l + c1 + c2 + c3 + 9,
        y - 21,
        size: 5.8,
        bold: true,
        color: '0.05 0.35 0.65',
      );

      var dy = y - 14;
      for (final l in _wrap(doc0.description, c5 - 12, 6.7).take(3)) {
        _text(
          p,
          l,
          _l + c1 + c2 + c3 + c4 + 6,
          dy,
          size: 6.7,
          color: '0.15 0.20 0.28',
        );
        dy -= 9;
      }
      y -= rowH;
    }

    y -= 16;
    _sectionHeaderAt(
      p,
      'CÓMO DESCARGAR LOS DOCUMENTOS ORIGINALES EN SECOP II',
      y,
    );
    y -= 14;
    const stepW = (_cw - 10) / 3;
    const stepH = 62.0;
    final pasos = [
      [
        'PASO 1',
        'Abrir el expediente',
        'En la app, pulsa "Documentos oficiales en SECOP" para abrir la ficha del proceso en el portal del Estado.',
      ],
      [
        'PASO 2',
        'Documentos del proceso',
        'En community.secop.gov.co ubica la sección "Documentos del Proceso", donde la entidad publica los archivos.',
      ],
      [
        'PASO 3',
        'Descargar los PDF',
        'Descarga los archivos escaneados originales con membrete, firmas y sellos de la entidad.',
      ],
    ];
    for (var i = 0; i < 3; i++) {
      final x = _l + (stepW + 5) * i;
      _rect(
        p,
        x,
        y - stepH,
        stepW,
        stepH,
        fill: '0.975 0.985 1.0',
        stroke: '0.82 0.86 0.92',
        lw: 0.7,
      );
      _rect(p, x, y - 13, stepW, 13, fill: '0.10 0.20 0.38');
      _text(p, pasos[i][0], x + 6, y - 9.5, size: 6, bold: true, color: _gold);
      _text(
        p,
        pasos[i][1],
        x + 6,
        y - 24,
        size: 7.3,
        bold: true,
        color: '0.08 0.15 0.30',
      );
      var sy = y - 34;
      for (final l in _wrap(pasos[i][2], stepW - 12, 6.4).take(3)) {
        _text(p, l, x + 6, sy, size: 6.4, color: _muted);
        sy -= 8.5;
      }
    }
    y -= stepH + 14;

    _rect(
      p,
      _l,
      y - 40,
      _cw,
      40,
      fill: '0.98 0.985 0.995',
      stroke: '0.82 0.86 0.92',
      lw: 0.8,
    );
    _text(
      p,
      'DERECHO DE ACCESO Y CONTROL SOCIAL',
      _l + 10,
      y - 13,
      size: 7,
      bold: true,
      color: '0.12 0.22 0.38',
    );
    _text(
      p,
      'Si un documento obligatorio no aparece publicado en SECOP II, puede solicitarse a la entidad mediante derecho de petición',
      _l + 10,
      y - 24,
      size: 6.8,
      color: '0.28 0.32 0.40',
    );
    _text(
      p,
      '(Art. 23 de la Constitución y Ley 1755 de 2015) o a través de una veeduría ciudadana (Ley 850 de 2003).',
      _l + 10,
      y - 34,
      size: 6.8,
      italic: true,
      color: '0.25 0.35 0.48',
    );
  }

  // ===========================================================================
  // BLOQUES DE FLUJO
  // ===========================================================================
  static void _flowSection(_PdfDoc doc, String title) {
    doc.ensure(48); // título + al menos un bloque corto
    _text(
      doc.cur,
      title,
      _l,
      doc.y - 9,
      size: 8.8,
      bold: true,
      color: '0.08 0.18 0.35',
    );
    _rect(doc.cur, _l, doc.y - 14, _cw, 0.6, fill: '0.85 0.88 0.93');
    _rect(doc.cur, _l, doc.y - 14.5, 70, 1.8, fill: _gold);
    doc.y -= 24;
  }

  static void _flowSubtitle(_PdfDoc doc, String text) {
    doc.ensure(20);
    _text(
      doc.cur,
      text,
      _l,
      doc.y - 8,
      size: 7.4,
      bold: true,
      color: '0.15 0.25 0.42',
    );
    doc.y -= 14;
  }

  static void _flowParagraph(
    _PdfDoc doc,
    String text, {
    double size = 7.6,
    String color = _ink,
    double x = _l,
    double w = _cw,
  }) {
    if (text.trim().isEmpty) return;
    final lh = size * 1.42;
    for (final line in _wrap(text, w, size)) {
      doc.ensure(lh);
      _text(doc.cur, line, x, doc.y - size, size: size, color: color);
      doc.y -= lh;
    }
    doc.y -= 4;
  }

  static void _flowLabeled(_PdfDoc doc, String label, String text) {
    if (text.trim().isEmpty) return;
    const size = 7.6;
    const lh = size * 1.42;
    final labelW = _textWidth(label, size, bold: true);
    final first = _wrap(text, _cw - labelW, size);
    if (first.isEmpty) return;
    doc.ensure(lh);
    _text(
      doc.cur,
      label,
      _l,
      doc.y - size,
      size: size,
      bold: true,
      color: '0.12 0.22 0.38',
    );
    _text(
      doc.cur,
      first.first,
      _l + labelW,
      doc.y - size,
      size: size,
      color: _ink,
    );
    doc.y -= lh;
    final rest = first.skip(1).join(' ');
    if (rest.isNotEmpty) {
      _flowParagraph(doc, rest);
    } else {
      doc.y -= 4;
    }
  }

  static void _flowBullets(
    _PdfDoc doc,
    List<String> items, {
    String color = _ink,
  }) {
    const size = 7.5;
    const lh = size * 1.42;
    for (final item in items) {
      final lines = _wrap(item, _cw - 14, size);
      for (var i = 0; i < lines.length; i++) {
        doc.ensure(lh);
        if (i == 0) {
          _text(
            doc.cur,
            '\u2022',
            _l + 3,
            doc.y - size,
            size: size,
            bold: true,
            color: '0.10 0.30 0.60',
          );
        }
        _text(
          doc.cur,
          lines[i],
          _l + 14,
          doc.y - size,
          size: size,
          color: color,
        );
        doc.y -= lh;
      }
      doc.y -= 2.5;
    }
    doc.y -= 3;
  }

  static void _flowNumbered(_PdfDoc doc, List<String> items) {
    const size = 7.5;
    const lh = size * 1.42;
    for (var n = 0; n < items.length; n++) {
      final lines = _wrap(items[n], _cw - 22, size);
      for (var i = 0; i < lines.length; i++) {
        doc.ensure(lh);
        if (i == 0) {
          _rect(
            doc.cur,
            _l,
            doc.y - size - 2.5,
            14,
            11,
            fill: '0.10 0.20 0.38',
          );
          _text(
            doc.cur,
            '${n + 1}',
            _l + (n + 1 >= 10 ? 2.5 : 5),
            doc.y - size + 0.5,
            size: 6.5,
            bold: true,
            color: '1 1 1',
          );
        }
        _text(
          doc.cur,
          lines[i],
          _l + 22,
          doc.y - size,
          size: size,
          color: _ink,
        );
        doc.y -= lh;
      }
      doc.y -= 3;
    }
    doc.y -= 3;
  }

  static void _flowCellsRow(_PdfDoc doc, List<List<String>> cells) {
    const h = 28.0;
    doc.ensure(h + 6);
    final gap = 5.0;
    final cw = (_cw - gap * (cells.length - 1)) / cells.length;
    for (var i = 0; i < cells.length; i++) {
      _cell(
        doc.cur,
        _l + (cw + gap) * i,
        doc.y - h,
        cw,
        h,
        cells[i][0],
        cells[i][1],
        bold: true,
      );
    }
    doc.y -= h + 8;
  }

  static void _flowAlert(_PdfDoc doc, AuditAlert a) {
    const size = 7.2;
    final lines = _wrap(a.detalle, _cw - 92, size);
    final h = 16.0 + lines.length * 9.6 + 4;
    doc.ensure(h + 4);
    final p = doc.cur;
    final y = doc.y;
    final color = a.nivel == 'ALTA'
        ? ['0.99 0.93 0.93', '0.85 0.25 0.25', '0.70 0.10 0.10']
        : (a.nivel == 'MEDIA'
              ? ['1.0 0.97 0.90', '0.92 0.65 0.20', '0.65 0.40 0.02']
              : ['0.93 0.96 1.0', '0.45 0.62 0.90', '0.15 0.35 0.70']);
    _rect(
      p,
      _l,
      y - h,
      _cw,
      h,
      fill: '1 1 1',
      stroke: '0.85 0.88 0.92',
      lw: 0.6,
    );
    _rect(p, _l, y - h, 4, h, fill: color[1]);
    _rect(
      p,
      _l + 10,
      y - 17,
      62,
      12,
      fill: color[0],
      stroke: color[1],
      lw: 0.6,
    );
    _text(
      p,
      'NIVEL ${a.nivel}',
      _l + 15,
      y - 13.5,
      size: 6,
      bold: true,
      color: color[2],
    );
    _text(
      p,
      _fit(a.titulo, _cw - 100, 7.6, bold: true),
      _l + 82,
      y - 13.5,
      size: 7.6,
      bold: true,
      color: '0.08 0.15 0.30',
    );
    var ty = y - 25;
    for (final l in lines) {
      _text(p, l, _l + 82, ty, size: size, color: _ink);
      ty -= 9.6;
    }
    doc.y -= h + 5;
  }

  static void _flowLegalTable(_PdfDoc doc, List<LegalReferenceItem> items) {
    if (items.isEmpty) return;
    const c1 = 150.0;
    const size = 7.0;
    doc.ensure(16 + 24);
    _rect(doc.cur, _l, doc.y - 15, _cw, 15, fill: '0.10 0.20 0.38');
    _text(
      doc.cur,
      'NORMA',
      _l + 6,
      doc.y - 10.5,
      size: 6.6,
      bold: true,
      color: '1 1 1',
    );
    _text(
      doc.cur,
      'APLICACIÓN AL CONTRATO',
      _l + c1 + 6,
      doc.y - 10.5,
      size: 6.6,
      bold: true,
      color: '1 1 1',
    );
    doc.y -= 15;
    for (var i = 0; i < items.length; i++) {
      final nLines = _wrap(items[i].norma, c1 - 12, size, bold: true);
      final aLines = _wrap(items[i].aplicacion, _cw - c1 - 12, size);
      final rows = nLines.length > aLines.length
          ? nLines.length
          : aLines.length;
      final h = 8.0 + rows * 9.4;
      doc.ensure(h);
      final p = doc.cur;
      _rect(
        p,
        _l,
        doc.y - h,
        _cw,
        h,
        fill: i.isEven ? '1 1 1' : '0.975 0.985 0.995',
        stroke: '0.85 0.88 0.92',
        lw: 0.5,
      );
      _rect(p, _l + c1, doc.y - h, 0.5, h, fill: '0.86 0.89 0.93');
      var ty = doc.y - 10;
      for (final l in nLines) {
        _text(
          p,
          l,
          _l + 6,
          ty,
          size: size,
          bold: true,
          color: '0.08 0.18 0.35',
        );
        ty -= 9.4;
      }
      ty = doc.y - 10;
      for (final l in aLines) {
        _text(p, l, _l + c1 + 6, ty, size: size, color: _ink);
        ty -= 9.4;
      }
      doc.y -= h;
    }
    doc.y -= 6;
  }

  // ===========================================================================
  // PRIMITIVAS
  // ===========================================================================
  static void _sectionHeaderAt(StringBuffer p, String title, double y) {
    _text(p, title, _l, y + 2, size: 8.5, bold: true, color: '0.08 0.18 0.35');
    _rect(p, _l, y - 2, _textWidth(title, 8.5, bold: true), 1.8, fill: _gold);
  }

  static void _cell(
    StringBuffer p,
    double x,
    double yb,
    double w,
    double h,
    String label,
    String value, {
    bool bold = false,
    String valueColor = '0.10 0.15 0.25',
  }) {
    _rect(p, x, yb, w, h, fill: '1 1 1', stroke: '0.84 0.87 0.91', lw: 0.6);
    _rect(p, x, yb + h - 10.5, w, 10.5, fill: '0.94 0.96 0.98');
    _text(
      p,
      _fit(label.toUpperCase(), w - 12, 5.8, bold: true),
      x + 6,
      yb + h - 8,
      size: 5.8,
      bold: true,
      color: '0.22 0.32 0.48',
    );
    _text(
      p,
      _fit(value, w - 12, 7.6, bold: bold),
      x + 6,
      yb + 5,
      size: 7.6,
      bold: bold,
      color: valueColor,
    );
  }

  static void _kpi(
    StringBuffer p,
    double x,
    double yb,
    double w,
    double h,
    String label,
    String value, {
    bool green = false,
  }) {
    _rect(
      p,
      x,
      yb,
      w,
      h,
      fill: green ? '0.93 0.98 0.94' : '1 1 1',
      stroke: green ? '0.50 0.82 0.60' : '0.84 0.87 0.91',
      lw: 0.8,
    );
    _text(
      p,
      label.toUpperCase(),
      x + 6,
      yb + h - 11,
      size: 5.8,
      bold: true,
      color: green ? '0.08 0.45 0.20' : '0.25 0.35 0.50',
    );
    final size = green ? 9.6 : 7.6;
    _text(
      p,
      _fit(value, w - 12, size, bold: true),
      x + 6,
      yb + 8,
      size: size,
      bold: true,
      color: green ? '0.04 0.48 0.18' : '0.10 0.15 0.25',
    );
  }

  static void _pill(
    StringBuffer p,
    double x,
    double yb,
    double w,
    double h,
    String label,
    String value,
    List<String> c,
  ) {
    _rect(p, x, yb, w, h, fill: c[0], stroke: c[1], lw: 0.7);
    final lbl = '$label: ';
    _text(p, lbl, x + 6, yb + 6, size: 6, bold: true, color: '0.25 0.32 0.45');
    final lw = _textWidth(lbl, 6, bold: true);
    _text(
      p,
      _fit(value, w - lw - 12, 6.8, bold: true),
      x + 6 + lw,
      yb + 6,
      size: 6.8,
      bold: true,
      color: c[2],
    );
  }

  static List<String> _riskColor(String r) => r == 'ALTO'
      ? ['0.99 0.93 0.93', '0.85 0.25 0.25', '0.70 0.10 0.10']
      : (r == 'MEDIO'
            ? ['1.0 0.97 0.90', '0.92 0.65 0.20', '0.65 0.40 0.02']
            : ['0.92 0.98 0.94', '0.45 0.78 0.55', '0.05 0.45 0.20']);

  static List<String> _coherenceColor(String c) => c.startsWith('INCONS')
      ? _riskColor('ALTO')
      : (c.startsWith('COHER') ? _riskColor('BAJO') : _riskColor('MEDIO'));

  static void _rect(
    StringBuffer b,
    double x,
    double y,
    double w,
    double h, {
    String? fill,
    String? stroke,
    double lw = 0.5,
  }) {
    if (fill != null) {
      b.writeln('$fill rg ${_n(x)} ${_n(y)} ${_n(w)} ${_n(h)} re f');
    }
    if (stroke != null) {
      b.writeln(
        '$stroke RG ${_n(lw)} w ${_n(x)} ${_n(y)} ${_n(w)} ${_n(h)} re S',
      );
    }
  }

  static void _text(
    StringBuffer b,
    String text,
    double x,
    double y, {
    double size = 8,
    bool bold = false,
    bool italic = false,
    String color = '0.1 0.1 0.1',
  }) {
    final font = bold ? '/F2' : (italic ? '/F3' : '/F1');
    b.writeln(
      'BT $font ${_n(size)} Tf $color rg ${_n(x)} ${_n(y)} Td (${_escape(text)}) Tj ET',
    );
  }

  static String _n(double v) => v.toStringAsFixed(2);

  /// Ancho aproximado en puntos según métricas de Helvetica.
  static double _textWidth(String s, double size, {bool bold = false}) {
    var units = 0.0;
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      if (ch == ' ') {
        units += 0.278;
      } else if ('iljI.,;:\'|!'.contains(ch)) {
        units += 0.26;
      } else if ('ftr()[]-'.contains(ch)) {
        units += 0.34;
      } else if ('mwMW'.contains(ch)) {
        units += 0.86;
      } else if (RegExp(r'[0-9]').hasMatch(ch)) {
        units += 0.556;
      } else if (ch.toUpperCase() == ch && ch.toLowerCase() != ch) {
        units += 0.70;
      } else {
        units += 0.53;
      }
    }
    return units * size * (bold ? 1.06 : 1.0);
  }

  static List<String> _wrap(
    String text,
    double maxW,
    double size, {
    bool bold = false,
    bool italic = false,
  }) {
    final words = text.replaceAll(RegExp(r'\s+'), ' ').trim().split(' ');
    final lines = <String>[];
    var cur = '';
    for (final w in words) {
      if (w.isEmpty) continue;
      final test = cur.isEmpty ? w : '$cur $w';
      if (_textWidth(test, size, bold: bold) <= maxW) {
        cur = test;
      } else {
        if (cur.isNotEmpty) lines.add(cur);
        cur = _textWidth(w, size, bold: bold) > maxW
            ? _fit(w, maxW, size, bold: bold)
            : w;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines;
  }

  static String _fit(
    String text,
    double maxW,
    double size, {
    bool bold = false,
  }) {
    if (_textWidth(text, size, bold: bold) <= maxW) return text;
    var t = text;
    while (t.isNotEmpty && _textWidth('$t...', size, bold: bold) > maxW) {
      t = t.substring(0, t.length - 1);
    }
    return '${t.trimRight()}...';
  }

  static String _hashStr(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = (31 * hash + input.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0') +
        ((hash * 7) & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  }

  /// Escapa el texto para un string literal PDF con codificación WinAnsi.
  /// Los caracteres Latin-1 (tildes, ñ, ¿, ¡, °) se emiten como octal para
  /// que se vean correctamente; el stream resultante es 100% ASCII.
  static String _escape(String text) {
    const especiales = {
      0x2022: 149, // •
      0x2013: 150, // –
      0x2014: 151, // —
      0x2018: 145, 0x2019: 146, // ‘ ’
      0x201C: 147, 0x201D: 148, // “ ”
      0x2026: 133, // …
      0x20AC: 128, // €
    };
    final sb = StringBuffer();
    for (final r in text.runes) {
      if (r == 0x5C) {
        sb.write(r'\\');
      } else if (r == 0x28) {
        sb.write(r'\(');
      } else if (r == 0x29) {
        sb.write(r'\)');
      } else if (r >= 0x20 && r <= 0x7E) {
        sb.writeCharCode(r);
      } else if (r >= 0xA0 && r <= 0xFF) {
        sb.write('\\${r.toRadixString(8).padLeft(3, '0')}');
      } else if (especiales.containsKey(r)) {
        sb.write('\\${especiales[r]!.toRadixString(8).padLeft(3, '0')}');
      } else if (r == 0x2192) {
        sb.write('->'); // →
      } else if (r == 0x0A || r == 0x09) {
        sb.write(' ');
      }
    }
    return sb.toString();
  }

  static Uint8List _ensamblarPdf(List<String> pageStreams) {
    final objects = <String>[];
    final numPages = pageStreams.length;

    const catalogId = 1;
    const pagesId = 2;
    const font1Id = 3;
    const font2Id = 4;
    const font3Id = 5;
    const firstPageId = 6;

    final pageIds = <int>[
      for (var i = 0; i < numPages; i++) firstPageId + (i * 2),
    ];

    objects.add('<< /Type /Catalog /Pages $pagesId 0 R >>');
    objects.add(
      '<< /Type /Pages /Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] /Count $numPages >>',
    );
    objects.add(
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
    );
    objects.add(
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>',
    );
    objects.add(
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique /Encoding /WinAnsiEncoding >>',
    );

    for (var i = 0; i < numPages; i++) {
      final streamId = pageIds[i] + 1;
      final content = pageStreams[i];
      final len = ascii.encode(content).length;
      objects.add(
        '<< /Type /Page /Parent $pagesId 0 R '
        '/MediaBox [0 0 $_w $_h] '
        '/Resources << /Font << /F1 $font1Id 0 R /F2 $font2Id 0 R /F3 $font3Id 0 R >> >> '
        '/Contents $streamId 0 R >>',
      );
      objects.add('<< /Length $len >>\nstream\n$content\nendstream');
    }

    final out = BytesBuilder();
    out.add(latin1.encode('%PDF-1.4\n%\u00E2\u00E3\u00CF\u00D3\n'));
    final offsets = <int>[0];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      out.add(ascii.encode('${i + 1} 0 obj\n${objects[i]}\nendobj\n'));
    }
    final xrefOffset = out.length;
    out.add(
      ascii.encode('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n'),
    );
    for (var i = 1; i <= objects.length; i++) {
      out.add(
        ascii.encode('${offsets[i].toString().padLeft(10, '0')} 00000 n \n'),
      );
    }
    out.add(
      ascii.encode(
        'trailer\n<< /Size ${objects.length + 1} /Root $catalogId 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
      ),
    );
    return out.toBytes();
  }
}
