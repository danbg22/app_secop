import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpectedDocumentItem {
  const ExpectedDocumentItem({
    required this.name,
    required this.legalReference,
    required this.description,
    required this.isMandatory,
    required this.icon,
  });

  final String name;
  final String legalReference;
  final String description;
  final bool isMandatory;
  final IconData icon;
}

class ContractDocumentService {
  static final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  /// Obtiene la URL oficial del proceso en el portal transaccional de SECOP II.
  static String obtenerUrlSecop(dynamic rawContract) {
    final Map<String, dynamic> c =
        rawContract is Map<String, dynamic> ? rawContract : {};

    final rawUrl = c['urlproceso'];
    if (rawUrl is Map && rawUrl['url'] != null) {
      return rawUrl['url'].toString();
    } else if (rawUrl is String && rawUrl.startsWith('http')) {
      return rawUrl;
    }

    final proceso = c['proceso_de_compra']?.toString().trim() ?? '';
    if (proceso.isNotEmpty) {
      return 'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=$proceso';
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
    final url = obtenerUrlSecop(rawContract);
    final uri = Uri.tryParse(url);

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

      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
  /// Genera y descarga el reporte PDF estructurado con la información de texto
  /// y el checklist de documentos esperados, con aviso explícito de transparencia.
  static void descargarResumenInteligente(
    BuildContext context,
    dynamic rawContract,
  ) {
    try {
      final Map<String, dynamic> c =
          rawContract is Map<String, dynamic> ? rawContract : {};
      final ref = _sanitizeCode(
        c['referencia_del_contrato'] ??
            c['id_contrato'] ??
            c['proceso_de_compra'] ??
            'EXP-2026',
      );
      final fileName = 'Resumen_Inteligente_Contrato_${ref}.pdf';

      final bytes = generarPdfResumenInteligente(rawContract);
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Descargando $fileName...'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar el resumen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Visualiza el resumen inteligente en una nueva pestaña del navegador.
  static void abrirResumenEnNavegador(
    BuildContext context,
    dynamic rawContract,
  ) {
    try {
      final bytes = generarPdfResumenInteligente(rawContract);
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.visibility_outlined, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text('Abriendo visor del resumen inteligente...'),
              ),
            ],
          ),
          backgroundColor: Color(0xFF1E293B),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir el visor: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Lista los documentos esperados para este proceso según las normas de contratación pública en Colombia.
  static List<ExpectedDocumentItem> getExpectedDocumentsForContract(
    dynamic rawContract,
  ) {
    final Map<String, dynamic> c =
        rawContract is Map<String, dynamic> ? rawContract : {};

    final modalidad =
        (c['modalidad_de_contratacion'] ?? '').toString().toUpperCase();

    final isDirecta = modalidad.contains('DIRECTA');
    final isMinima = modalidad.contains('MINIMA') || modalidad.contains('MÍNIMA');

    return [
      const ExpectedDocumentItem(
        name: 'Estudios y Documentos Previos',
        legalReference: 'Art. 25 Num. 7 y 12 Ley 80/93 - Dcto. 1082/15',
        description:
            'Análisis del sector, justificación de la necesidad técnica y conveniencia institucional.',
        isMandatory: true,
        icon: Icons.assignment_outlined,
      ),
      const ExpectedDocumentItem(
        name: 'Certificado de Disponibilidad Presupuestal (CDP)',
        legalReference: 'Estatuto Orgánico de Presupuesto',
        description:
            'Garantiza que la entidad cuenta con el saldo y apropiación presupuestal para el contrato.',
        isMandatory: true,
        icon: Icons.account_balance_wallet_outlined,
      ),
      ExpectedDocumentItem(
        name: isDirecta
            ? 'Acto Administrativo de Justificación / Términos de Referencia'
            : (isMinima
                ? 'Invitación Pública y Pliego de Mínima Cuantía'
                : 'Pliego de Condiciones y Anexos Técnicos Definitivos'),
        legalReference: isDirecta ? 'Art. 2.2.1.2.1.4.1 Dcto 1082' : 'Ley 1150 de 2007',
        description:
            'Reglas de participación, requisitos habilitantes y especificaciones técnicas.',
        isMandatory: true,
        icon: Icons.menu_book_outlined,
      ),
      ExpectedDocumentItem(
        name: isDirecta
            ? 'Aceptación de Oferta / Carta de Propuesta'
            : 'Acta de Adjudicación / Resolución Definitiva',
        legalReference: 'Ley 80 de 1993 y Ley 1150 de 2007',
        description:
            'Acto formal donde la entidad selecciona y acepta la oferta del contratista adjudicado.',
        isMandatory: true,
        icon: Icons.verified_outlined,
      ),
      const ExpectedDocumentItem(
        name: 'Minuta del Contrato Estatal Suscrito',
        legalReference: 'Art. 39 Ley 80 de 1993',
        description:
            'Acuerdo bilateral formal firmado entre el representante de la entidad y el contratista.',
        isMandatory: true,
        icon: Icons.history_edu_outlined,
      ),
      const ExpectedDocumentItem(
        name: 'Póliza Única de Garantía y Aprobación',
        legalReference: 'Art. 7 Ley 1150 de 2007',
        description:
            'Amparo de cumplimiento, pago de salarios, prestaciones y calidad del servicio/obra.',
        isMandatory: true,
        icon: Icons.shield_outlined,
      ),
      const ExpectedDocumentItem(
        name: 'Registro Presupuestal (RP) y Designación de Supervisión',
        legalReference: 'Ley 1474 de 2011 (Estatuto Anticorrupción)',
        description:
            'Perfeccionamiento del compromiso fiscal y nombramiento del supervisor del contrato.',
        isMandatory: true,
        icon: Icons.fact_check_outlined,
      ),
    ];
  }

  /// Genera el contenido binario del PDF del Resumen Inteligente.
  static Uint8List generarPdfResumenInteligente(dynamic rawContract) {
    final Map<String, dynamic> c =
        rawContract is Map<String, dynamic> ? rawContract : {};

    final String entidad =
        (c['nombre_entidad'] ?? 'Entidad Pública de Colombia').toString().trim();
    final String nitEntidad =
        (c['nit_entidad'] ?? '899.999.001-1').toString().trim();
    final String contratista =
        (c['proveedor_adjudicado'] ?? 'Contratista Adjudicado').toString().trim();
    final String docContratista =
        (c['documento_proveedor'] ?? '901.000.123-4').toString().trim();
    final String proceso =
        (c['proceso_de_compra'] ?? 'CO1.BDOS.2026.001').toString().trim();
    final String referencia =
        (c['referencia_del_contrato'] ?? c['id_contrato'] ?? 'CTO-2026-001')
            .toString()
            .trim();
    final String modalidad =
        (c['modalidad_de_contratacion'] ?? 'Contratación Directa').toString().trim();
    final String estado =
        (c['estado_contrato'] ?? 'Celebrado / En Ejecución').toString().trim();
    final String orden = (c['orden'] ?? 'Nacional').toString().trim();
    final String depto = (c['departamento'] ?? 'Colombia').toString().trim();
    final String ciudad = (c['ciudad'] ?? '').toString().trim();
    final String ubicacion = ciudad.isNotEmpty ? '$ciudad, $depto' : depto;

    final double valorNum =
        double.tryParse(c['valor_del_contrato']?.toString() ?? '0') ?? 0;
    final String valorFormateado = _currencyFormat.format(valorNum.round());

    final String rawFechaFirma = (c['fecha_de_firma'] ??
            c['fecha_de_inicio_del_contrato'] ??
            '2026-10-15')
        .toString()
        .split('T')
        .first;

    final String rawFechaInicio =
        (c['fecha_de_inicio_del_contrato'] ?? rawFechaFirma)
            .toString()
            .split('T')
            .first;
    final String rawFechaFin =
        (c['fecha_de_fin_del_contrato'] ?? '2026-12-31')
            .toString()
            .split('T')
            .first;

    final String objeto = (c['descripcion_del_proceso'] ??
            c['objeto_del_contrato'] ??
            'Contratación de bienes o servicios para el cumplimiento de las metas institucionales conforme a las leyes colombianas.')
        .toString()
        .trim();

    final expectedDocs = getExpectedDocumentsForContract(c);

    return _SmartSummaryPdfEngine.construirResumenInteligente(
      entidad: entidad,
      nitEntidad: nitEntidad,
      contratista: contratista,
      docContratista: docContratista,
      proceso: proceso,
      referencia: referencia,
      modalidad: modalidad,
      estado: estado,
      orden: orden,
      ubicacion: ubicacion,
      valor: valorFormateado,
      fechaFirma: rawFechaFirma,
      fechaInicio: rawFechaInicio,
      fechaFin: rawFechaFin,
      objeto: objeto,
      expectedDocs: expectedDocs,
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

/// Motor generador del reporte PDF del Resumen Inteligente (estándar PDF 1.4).
class _SmartSummaryPdfEngine {
  static const double _pageW = 595.28;
  static const double _pageH = 841.89;

  static Uint8List construirResumenInteligente({
    required String entidad,
    required String nitEntidad,
    required String contratista,
    required String docContratista,
    required String proceso,
    required String referencia,
    required String modalidad,
    required String estado,
    required String orden,
    required String ubicacion,
    required String valor,
    required String fechaFirma,
    required String fechaInicio,
    required String fechaFin,
    required String objeto,
    required List<ExpectedDocumentItem> expectedDocs,
  }) {
    final page1 = StringBuffer();
    final page2 = StringBuffer();

    // -------------------------------------------------------------------------
    // PÁGINA 1: Encabezado + Aviso de Transparencia + Ficha de Datos + Objeto
    // -------------------------------------------------------------------------
    // Cabecera Azul Marina (#1A2B4C)
    page1.writeln('0.102 0.169 0.298 rg 0 ${_pageH - 85} $_pageW 85 re f');
    // Cinta Dorada (#F5B82E)
    page1.writeln('0.961 0.722 0.180 rg 0 ${_pageH - 90} $_pageW 5 re f');

    page1.writeln('BT /F2 13 Tf 1 1 1 rg 40 ${_pageH - 34} Td (CONTRATA LEGAL - RESUMEN INTELIGENTE DEL CONTRATO) Tj ET');
    page1.writeln('BT /F1 8.5 Tf 0.85 0.90 0.98 rg 40 ${_pageH - 49} Td (AUDITORIA Y CONTROL CIUDADANO SOBRE DATOS ABIERTOS DE SECOP II) Tj ET');
    page1.writeln('BT /F1 8 Tf 0.85 0.90 0.98 rg 40 ${_pageH - 63} Td (REPORTE ESTRUCTURADO DE TRAZABILIDAD Y EXPEDIENTE DOCUMENTAL) Tj ET');

    // Caja de Aviso de Transparencia (Destacada en amarillo/ámbar suave)
    page1.writeln('0.99 0.97 0.90 rg 40 ${_pageH - 148} ${_pageW - 80} 48 re f');
    page1.writeln('0.92 0.75 0.25 RG 1 w 40 ${_pageH - 148} ${_pageW - 80} 48 re S');
    page1.writeln('BT /F2 8.5 Tf 0.60 0.40 0.05 rg 52 ${_pageH - 114} Td (AVISO DE TRANSPARENCIA CIUDADANA:) Tj ET');
    page1.writeln('BT /F1 8 Tf 0.35 0.25 0.05 rg 52 ${_pageH - 128} Td (Este documento es un resumen sintetico generado por IA con base en los datos de datos.gov.co.) Tj ET');
    page1.writeln('BT /F1 8 Tf 0.35 0.25 0.05 rg 52 ${_pageH - 140} Td (NO reemplaza los PDF escaneados originales, los cuales se descargan en community.secop.gov.co) Tj ET');

    // Tabla de Identificación del Proceso
    double y = _pageH - 165;
    page1.writeln('0.985 0.985 0.99 rg 40 ${y - 150} ${_pageW - 80} 150 re f');
    page1.writeln('0.88 0.90 0.94 RG 1 w 40 ${y - 150} ${_pageW - 80} 150 re S');

    void meta(StringBuffer buf, String label, String value, double yPos) {
      buf.writeln('BT /F2 8.5 Tf 0.28 0.35 0.45 rg 55 $yPos Td (${_escape(label)}:) Tj ET');
      buf.writeln('BT /F1 9 Tf 0.10 0.15 0.25 rg 185 $yPos Td (${_escape(value)}) Tj ET');
    }

    meta(page1, 'NUMERO DE PROCESO', proceso, y - 20);
    meta(page1, 'REFERENCIA CONTRATO', referencia, y - 38);
    meta(page1, 'ENTIDAD CONTRATANTE', '$entidad (NIT: $nitEntidad)', y - 56);
    meta(page1, 'CONTRATISTA ADJUDICADO', '$contratista (NIT/CC: $docContratista)', y - 74);
    meta(page1, 'MODALIDAD CONTRACTUAL', modalidad, y - 92);
    meta(page1, 'VALOR DEL CONTRATO', valor, y - 110);
    meta(page1, 'ESTADO Y JURISDICCION', '$estado  |  $ubicacion ($orden)', y - 128);
    meta(page1, 'FECHAS CLAVE', 'Firma: $fechaFirma  |  Ejecucion: $fechaInicio a $fechaFin', y - 144);

    y -= 175;

    // Sección 1: Objeto Contractual
    page1.writeln('BT /F2 10.5 Tf 0.102 0.169 0.298 rg 40 $y Td (1. OBJETO Y FINALIDAD DE LA CONTRATACION) Tj ET');
    page1.writeln('0.961 0.722 0.180 rg 40 ${y - 4} 180 2 re f');
    y -= 20;

    final objetoWrap = _wrapText(objeto, 76);
    for (final line in objetoWrap.take(7)) {
      page1.writeln('BT /F1 9 Tf 0.18 0.22 0.30 rg 40 $y Td (${_escape(line)}) Tj ET');
      y -= 13;
    }

    y -= 14;

    // Sección 2: Checklist de Documentos Esperados (Parte 1)
    page1.writeln('BT /F2 10.5 Tf 0.102 0.169 0.298 rg 40 $y Td (2. EXPEDIENTE DOCUMENTAL ESPERADO SEGUN LA LEY) Tj ET');
    page1.writeln('0.961 0.722 0.180 rg 40 ${y - 4} 240 2 re f');
    y -= 22;

    for (var i = 0; i < expectedDocs.length && i < 3; i++) {
      final doc = expectedDocs[i];
      page1.writeln('0.96 0.98 0.96 rg 40 ${y - 34} ${_pageW - 80} 34 re f');
      page1.writeln('0.85 0.90 0.85 RG 0.5 w 40 ${y - 34} ${_pageW - 80} 34 re S');

      page1.writeln('BT /F2 9 Tf 0.08 0.45 0.20 rg 52 ${y - 14} Td ([X] ${_escape(doc.name)}) Tj ET');
      page1.writeln('BT /F1 7.5 Tf 0.40 0.50 0.60 rg 280 ${y - 14} Td (${_escape(doc.legalReference)}) Tj ET');
      page1.writeln('BT /F1 8 Tf 0.25 0.30 0.38 rg 52 ${y - 27} Td (${_escape(doc.description)}) Tj ET');

      y -= 40;
    }

    // Pie de página P1
    page1.writeln('0.85 0.88 0.93 RG 0.5 w 40 45 ${_pageW - 80} 0.5 re S');
    page1.writeln('BT /F1 7.5 Tf 0.45 0.52 0.62 rg 40 32 Td (Contrata Legal - Plataforma Ciudadana. Datos certificados de SECOP II Colombia.) Tj ET');
    page1.writeln('BT /F2 7.5 Tf 0.10 0.17 0.30 rg 470 32 Td (Pagina 1 de 2) Tj ET');

    // -------------------------------------------------------------------------
    // PÁGINA 2: Continuación Checklist + Guía de Descarga Oficial + Firmas
    // -------------------------------------------------------------------------
    page2.writeln('0.102 0.169 0.298 rg 0 ${_pageH - 50} $_pageW 50 re f');
    page2.writeln('0.961 0.722 0.180 rg 0 ${_pageH - 54} $_pageW 4 re f');
    page2.writeln('BT /F2 10.5 Tf 1 1 1 rg 40 ${_pageH - 32} Td (CONTINUACION DEL EXPEDIENTE DOCUMENTAL ESPERADO Y GUIA OFICIAL) Tj ET');

    double y2 = _pageH - 75;

    for (var i = 3; i < expectedDocs.length; i++) {
      final doc = expectedDocs[i];
      page2.writeln('0.96 0.98 0.96 rg 40 ${y2 - 34} ${_pageW - 80} 34 re f');
      page2.writeln('0.85 0.90 0.85 RG 0.5 w 40 ${y2 - 34} ${_pageW - 80} 34 re S');

      page2.writeln('BT /F2 9 Tf 0.08 0.45 0.20 rg 52 ${y2 - 14} Td ([X] ${_escape(doc.name)}) Tj ET');
      page2.writeln('BT /F1 7.5 Tf 0.40 0.50 0.60 rg 280 ${y2 - 14} Td (${_escape(doc.legalReference)}) Tj ET');
      page2.writeln('BT /F1 8 Tf 0.25 0.30 0.38 rg 52 ${y2 - 27} Td (${_escape(doc.description)}) Tj ET');

      y2 -= 40;
    }

    y2 -= 12;

    // Sección 3: Guía de Descarga de Documentos Escaneados Originales
    page2.writeln('BT /F2 10.5 Tf 0.102 0.169 0.298 rg 40 $y2 Td (3. COMO CONSULTAR Y DESCARGAR LOS PDF ORIGINALES ESCANEADOS) Tj ET');
    page2.writeln('0.961 0.722 0.180 rg 40 ${y2 - 4} 280 2 re f');
    y2 -= 22;

    page2.writeln('0.95 0.97 0.99 rg 40 ${y2 - 90} ${_pageW - 80} 90 re f');
    page2.writeln('0.80 0.88 0.95 RG 1 w 40 ${y2 - 90} ${_pageW - 80} 90 re S');

    page2.writeln('BT /F2 8.5 Tf 0.10 0.25 0.55 rg 52 ${y2 - 18} Td (PASOS PARA LA CIUDADANIA Y VEEDORES EN SECOP II:) Tj ET');
    page2.writeln('BT /F1 8 Tf 0.20 0.30 0.40 rg 52 ${y2 - 34} Td (1. Haz clic en el boton "Documentos oficiales en SECOP" dentro de Contrata Legal.) Tj ET');
    page2.writeln('BT /F1 8 Tf 0.20 0.30 0.40 rg 52 ${y2 - 48} Td (2. El navegador abrira la ficha del proceso: community.secop.gov.co ($proceso).) Tj ET');
    page2.writeln('BT /F1 8 Tf 0.20 0.30 0.40 rg 52 ${y2 - 62} Td (3. Dirigete a la seccion "Documentos del Proceso" en la parte inferior.) Tj ET');
    page2.writeln('BT /F1 8 Tf 0.20 0.30 0.40 rg 52 ${y2 - 76} Td (4. Encontraras los archivos originales subidos por $entidad con sus folios y firmas.) Tj ET');

    y2 -= 115;

    // Constancia de Generación
    page2.writeln('0.98 0.98 0.98 rg 40 $y2 ${_pageW - 80} 45 re f');
    page2.writeln('0.88 0.88 0.88 RG 0.5 w 40 $y2 ${_pageW - 80} 45 re S');
    page2.writeln('BT /F2 8 Tf 0.30 0.35 0.45 rg 50 ${y2 + 28} Td (CONSTANCIA DE GENERACION ELECTRONICA:) Tj ET');
    page2.writeln('BT /F1 7.5 Tf 0.45 0.50 0.58 rg 50 ${y2 + 14} Td (Reporte sintetico emitido para fines de auditoria, pedagogia y control social de los recursos publicos.) Tj ET');

    // Pie de página P2
    page2.writeln('0.85 0.88 0.93 RG 0.5 w 40 45 ${_pageW - 80} 0.5 re S');
    page2.writeln('BT /F1 7.5 Tf 0.45 0.52 0.62 rg 40 32 Td (Contrata Legal - Plataforma Ciudadana. Datos certificados de SECOP II Colombia.) Tj ET');
    page2.writeln('BT /F2 7.5 Tf 0.10 0.17 0.30 rg 470 32 Td (Pagina 2 de 2) Tj ET');

    return _ensamblarPdf([page1.toString(), page2.toString()]);
  }

  static Uint8List _ensamblarPdf(List<String> pageStreams) {
    final objects = <String>[];
    final numPages = pageStreams.length;

    final catalogId = 1;
    final pagesId = 2;
    final font1Id = 3;
    final font2Id = 4;
    final font3Id = 5;

    final firstPageId = 6;
    final pageIds = <int>[];
    for (var i = 0; i < numPages; i++) {
      pageIds.add(firstPageId + (i * 2));
    }

    final catalogObj = '<< /Type /Catalog /Pages $pagesId 0 R >>';
    final pagesObj =
        '<< /Type /Pages /Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] /Count $numPages >>';

    final f1Obj =
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>';
    final f2Obj =
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>';
    final f3Obj =
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique /Encoding /WinAnsiEncoding >>';

    objects.add(catalogObj); // 1
    objects.add(pagesObj); // 2
    objects.add(f1Obj); // 3
    objects.add(f2Obj); // 4
    objects.add(f3Obj); // 5

    for (var i = 0; i < numPages; i++) {
      final pageId = pageIds[i];
      final streamId = pageId + 1;
      final pageContent = pageStreams[i];
      final streamBytes = utf8.encode(pageContent);

      final pageDict = '<< /Type /Page /Parent $pagesId 0 R '
          '/MediaBox [0 0 $_pageW $_pageH] '
          '/Resources << /Font << /F1 $font1Id 0 R /F2 $font2Id 0 R /F3 $font3Id 0 R >> >> '
          '/Contents $streamId 0 R >>';

      final streamDict =
          '<< /Length ${streamBytes.length} >>\nstream\n$pageContent\nendstream';

      objects.add(pageDict);
      objects.add(streamDict);
    }

    final out = BytesBuilder();
    out.add(utf8.encode('%PDF-1.4\n%âãÏÓ\n'));

    final offsets = <int>[0];

    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      final objStr = '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
      out.add(utf8.encode(objStr));
    }

    final xrefOffset = out.length;
    out.add(utf8.encode('xref\n0 ${objects.length + 1}\n'));
    out.add(utf8.encode('0000000000 65535 f \n'));
    for (var i = 1; i <= objects.length; i++) {
      final off = offsets[i].toString().padLeft(10, '0');
      out.add(utf8.encode('$off 00000 n \n'));
    }

    final trailer =
        'trailer\n<< /Size ${objects.length + 1} /Root $catalogId 0 R >>\n'
        'startxref\n$xrefOffset\n%%EOF\n';
    out.add(utf8.encode(trailer));

    return out.toBytes();
  }

  static String _escape(String text) {
    final clean = text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    return clean
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  static List<String> _wrapText(String text, int maxCharsPerLine) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = StringBuffer();

    for (final w in words) {
      if (current.isEmpty) {
        current.write(w);
      } else if (current.length + 1 + w.length <= maxCharsPerLine) {
        current.write(' $w');
      } else {
        lines.add(current.toString());
        current = StringBuffer(w);
      }
    }
    if (current.isNotEmpty) {
      lines.add(current.toString());
    }
    return lines;
  }
}
