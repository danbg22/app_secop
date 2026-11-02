import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/file_downloader.dart';
import '../utils/pdf_unificado.dart';
import 'juridico_contratacion_service.dart';
import 'supervision_service.dart';

/// Genera los documentos formales del informe a partir de los datos que el
/// contratista diligenció en la app. Las secciones del informe de ejecución
/// siguen el orden de la plantilla de la entidad.
class InformePdfService {
  InformePdfService._();

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

  static const _gris = PdfColor.fromInt(0xFFE8EDF5);
  static const _borde = PdfColor.fromInt(0xFF64748B);
  static const _ambar = PdfColor.fromInt(0xFF9A5B00);

  static pw.TextStyle get _txt =>
      const pw.TextStyle(fontSize: 8.6, lineSpacing: 1.2);
  static pw.TextStyle get _neg =>
      pw.TextStyle(fontSize: 8.6, fontWeight: pw.FontWeight.bold);

  static Future<pw.Document> _documento() async => pw.Document(
    theme: await _cargarTema(),
    author: 'Contrata Legal',
    creator: 'Contrata Legal',
  );

  static pw.PageTheme _pagina() => const pw.PageTheme(
    pageFormat: PdfPageFormat.letter,
    margin: pw.EdgeInsets.fromLTRB(46, 40, 46, 40),
  );

  static pw.Widget _celda(
    String texto, {
    bool negrita = false,
    bool fondo = false,
    PdfColor? color,
    pw.TextAlign? alinear,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
    color: fondo ? _gris : null,
    child: pw.Text(
      texto,
      textAlign: alinear,
      style: (negrita ? _neg : _txt).copyWith(color: color),
    ),
  );

  /// Tabla de dos columnas etiqueta / valor.
  static pw.Widget _tablaDatos(
    List<(String, String)> filas, {
    double anchoEtiqueta = 0.34,
  }) => pw.Table(
    border: pw.TableBorder.all(color: _borde, width: 0.6),
    columnWidths: {
      0: pw.FlexColumnWidth(anchoEtiqueta),
      1: pw.FlexColumnWidth(1 - anchoEtiqueta),
    },
    children: [
      for (final (e, v) in filas)
        pw.TableRow(
          children: [
            _celda('${e.toUpperCase()}:', negrita: true),
            _celda(v.isEmpty ? '—' : v),
          ],
        ),
    ],
  );

  static pw.Widget _titulo(String texto) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 12, bottom: 0),
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
    decoration: pw.BoxDecoration(
      color: _gris,
      border: pw.Border.all(color: _borde, width: 0.6),
    ),
    child: pw.Text(
      texto.toUpperCase(),
      textAlign: pw.TextAlign.center,
      style: _neg.copyWith(fontSize: 9),
    ),
  );

  static pw.Widget _encabezado(
    PlanSupervision plan,
    String titulo, {
    String? sello,
  }) => pw.Column(
    children: [
      for (final (i, l) in plan.plantilla.encabezado.indexed)
        pw.Text(
          l,
          textAlign: pw.TextAlign.center,
          style: i == 0 ? _neg.copyWith(fontSize: 10.5) : _txt,
        ),
      pw.SizedBox(height: 8),
      pw.Stack(
        overflow: pw.Overflow.visible,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            decoration: pw.BoxDecoration(
              color: _gris,
              border: pw.Border.all(color: _borde, width: 0.6),
            ),
            child: pw.Text(
              titulo,
              textAlign: pw.TextAlign.center,
              style: _neg.copyWith(fontSize: 10),
            ),
          ),
          if (sello != null)
            pw.Positioned(
              right: 4,
              top: -12,
              child: pw.Transform.rotate(
                angle: 0.06,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red700, width: 1.2),
                  ),
                  child: pw.Text(
                    sello,
                    style: _neg.copyWith(color: PdfColors.red700, fontSize: 8),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  static pw.Widget _firma({
    Uint8List? firma,
    required String nombre,
    required List<String> lineas,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 6),
      pw.SizedBox(
        height: 46,
        child: firma == null
            ? pw.SizedBox()
            : pw.Image(
                pw.MemoryImage(firma),
                fit: pw.BoxFit.contain,
                alignment: pw.Alignment.bottomLeft,
              ),
      ),
      pw.Container(width: 210, height: 0.7, color: PdfColors.black),
      pw.SizedBox(height: 2),
      pw.Text(nombre.toUpperCase(), style: _neg),
      for (final l in lineas) pw.Text(l, style: _txt),
    ],
  );

  static String _titular(String t) =>
      t.isEmpty ? '' : t[0].toUpperCase() + t.substring(1);

  // ---------------------------------------------------------------------------
  // Informe de ejecución
  // ---------------------------------------------------------------------------

  static Future<Uint8List> informeEjecucion({
    required ExpedienteContratoPs expediente,
    required PlanSupervision plan,
    required InformePeriodo informe,
    Uint8List? firma,
  }) async {
    final doc = await _documento();
    final e = expediente;
    final inf = informe;
    final titulo =
        'INFORME ${plan.periodicidad.adjetivo.toUpperCase()} DE EJECUCIÓN CONTRACTUAL No. ${inf.numero}';
    final sello = switch (inf.estado) {
      EstadoInforme.aprobado || EstadoInforme.pagado => null,
      EstadoInforme.enRevision => 'EN REVISIÓN',
      EstadoInforme.devuelto => 'DEVUELTO',
      _ => 'BORRADOR',
    };
    final presentado = DateTime.tryParse(inf.enviadoEnIso)?.toLocal();
    final nombresObligaciones = {
      for (final (i, o) in plan.obligaciones.indexed) o.id: '${i + 1}',
    };

    pw.Widget seccion(String id) {
      switch (id) {
        case 'datos':
          return pw.Column(
            children: [
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: _borde, width: 0.6),
                columnWidths: const {
                  0: pw.FlexColumnWidth(0.34),
                  1: pw.FlexColumnWidth(0.66),
                },
                children: [
                  for (final (k, v) in [
                    (
                      'Fecha de presentación',
                      presentado == null
                          ? 'Sin presentar'
                          : fechaLegible(
                              presentado,
                              conDia: false,
                            ).toUpperCase(),
                    ),
                    (
                      'Contrato No.',
                      [
                        e.numeroContrato,
                        if (plan.cdp.registrado)
                          'CDP No. ${plan.cdp.numero}${plan.cdp.fechaIso.isEmpty ? '' : ' del ${fechaNumerica(DateTime.parse(plan.cdp.fechaIso))}'}',
                        plan.rp.registrado
                            ? 'RP No. ${plan.rp.numero}${plan.rp.fechaIso.isEmpty ? '' : ' del ${fechaNumerica(DateTime.parse(plan.rp.fechaIso))}'}'
                            : 'RP pendiente',
                      ].join('   ·   '),
                    ),
                    ('Modalidad de contratación', 'CONTRATACIÓN DIRECTA'),
                    (
                      'Justificación de la modalidad',
                      'PRESTACIÓN DE SERVICIOS PROFESIONALES Y DE APOYO A LA GESTIÓN',
                    ),
                    (
                      'Nombre del contratista',
                      e.contratistaNombreEsperado.toUpperCase(),
                    ),
                    ('C.C. / NIT', e.contratistaCedulaEsperada),
                    (
                      'Teléfono celular',
                      inf.datosCobro.celular.isEmpty
                          ? e.contratistaTelefono
                          : inf.datosCobro.celular,
                    ),
                    ('Plazo de ejecución', e.plazoEjecucion.toUpperCase()),
                    (
                      'Valor total del contrato',
                      formatoCop(e.valorContratoCop),
                    ),
                    ('Fecha de inicio', fechaNumerica(plan.fechaInicio)),
                    ('Fecha de terminación', fechaNumerica(plan.fechaFin)),
                    (
                      'Período de actividades',
                      'DESDE ${fechaNumerica(inf.desde)}   HASTA ${fechaNumerica(inf.hasta)}',
                    ),
                    ('Objeto', e.objetoContrato.toUpperCase()),
                    ('Supervisor', plan.supervisorNombre.toUpperCase()),
                    if (plan.sectorial.isNotEmpty)
                      ('Dependencia', plan.sectorial.toUpperCase()),
                  ])
                    pw.TableRow(
                      children: [
                        _celda('${k.toUpperCase()}:', negrita: true),
                        _celda(v),
                      ],
                    ),
                ],
              ),
            ],
          );
        case 'obligaciones':
          return pw.Column(
            children: [
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: _borde, width: 0.6),
                columnWidths: const {
                  0: pw.FixedColumnWidth(40),
                  1: pw.FlexColumnWidth(0.42),
                  2: pw.FlexColumnWidth(0.58),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _celda(
                        'ÍTEM',
                        negrita: true,
                        fondo: true,
                        alinear: pw.TextAlign.center,
                      ),
                      _celda(
                        'OBLIGACIONES ESPECÍFICAS DEL CONTRATO',
                        negrita: true,
                        fondo: true,
                        alinear: pw.TextAlign.center,
                      ),
                      _celda(
                        'ACTIVIDADES',
                        negrita: true,
                        fondo: true,
                        alinear: pw.TextAlign.center,
                      ),
                    ],
                  ),
                  for (final (i, o) in plan.obligaciones.indexed)
                    pw.TableRow(
                      children: [
                        _celda('${i + 1}', alinear: pw.TextAlign.center),
                        _celda(o.texto),
                        _celda((inf.actividades[o.id] ?? '').trim()),
                      ],
                    ),
                ],
              ),
            ],
          );
        case 'declaracion':
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 10),
              pw.Text(
                'Para todos los efectos legales y bajo la gravedad de juramento:',
                style: _neg,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                plan.plantilla.declaracion,
                style: _txt,
                textAlign: pw.TextAlign.justify,
              ),
              _firma(
                firma: inf.declaracion || inf.estado != EstadoInforme.borrador
                    ? firma
                    : null,
                nombre: e.contratistaNombreEsperado,
                lineas: [
                  'CONTRATISTA',
                  'C.C. No. ${e.contratistaCedulaEsperada}',
                  if (presentado != null)
                    'Fecha y hora de envío: ${fechaNumerica(presentado)} ${presentado.hour.toString().padLeft(2, '0')}:${presentado.minute.toString().padLeft(2, '0')}',
                ],
              ),
            ],
          );
        case 'anexos':
          if (inf.anexos.isEmpty) return pw.SizedBox();
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 10),
              pw.Text('ANEXOS', style: _neg),
              pw.SizedBox(height: 3),
              for (final (i, a) in inf.anexos.indexed)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Anexo ${i + 1}. ${a.titulo}${a.obligaciones.isEmpty ? '' : ' (obligación ${a.obligaciones.map((o) => nombresObligaciones[o] ?? '').where((x) => x.isNotEmpty).join(', ')})'}',
                        style: _neg,
                      ),
                      if (a.descripcion.isNotEmpty)
                        pw.Text(a.descripcion, style: _txt),
                      for (final f in a.archivos)
                        pw.Text(
                          '•  ${f.nombre} (${f.tamanoLegible}) · se anexa al final del informe',
                          style: _txt,
                        ),
                    ],
                  ),
                ),
            ],
          );
        case 'aportes':
          return pw.Column(
            children: [
              _titulo(
                'Pago de aportes al sistema de seguridad social integral',
              ),
              pw.Table(
                border: pw.TableBorder.all(color: _borde, width: 0.6),
                children: [
                  pw.TableRow(
                    children: [
                      for (final h in [
                        'Periodo del aporte',
                        'Fecha de pago',
                        'No. planilla (PILA)',
                        'IBC',
                        'Valor aporte',
                      ])
                        _celda(h.toUpperCase(), negrita: true, fondo: true),
                    ],
                  ),
                  for (final p in inf.planillas.where((p) => p.diligenciada))
                    pw.TableRow(
                      children: [
                        _celda(_titular(nombreMes(p.periodo))),
                        _celda(
                          p.fechaPagoIso.isEmpty
                              ? '—'
                              : fechaNumerica(DateTime.parse(p.fechaPagoIso)),
                        ),
                        _celda(p.numero),
                        _celda(p.ibcCop > 0 ? formatoCop(p.ibcCop) : '—'),
                        _celda(formatoCop(p.valorCop)),
                      ],
                    ),
                ],
              ),
              if (inf.pensionado)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(
                    'No cotiza a pensión${inf.motivoNoPension.isEmpty ? ' (pensionado)' : ': ${inf.motivoNoPension}'}.',
                    style: _txt,
                  ),
                ),
              if (inf.pideEstampilla(plan) && inf.estampilla.diligenciada) ...[
                _titulo('Estampilla departamental'),
                _tablaDatos([
                  (
                    'Fecha de pago',
                    fechaNumerica(DateTime.parse(inf.estampilla.fechaPagoIso)),
                  ),
                  ('Base (valor del contrato)', formatoCop(e.valorContratoCop)),
                  (
                    'Tarifa',
                    '${inf.estampilla.tarifaPct.toString().replaceAll('.', ',')} %',
                  ),
                  (
                    'Valor pagado',
                    '${formatoCop(inf.estampilla.valorPagadoCop)}${inf.estampilla.interesesCop > 0 ? ' (incluye intereses ${formatoCop(inf.estampilla.interesesCop)})' : ''}',
                  ),
                  ('No. de liquidación', inf.estampilla.liquidacion),
                ]),
              ],
            ],
          );
        case 'certificaciones':
          return pw.Column(
            children: [
              for (final etapa in plan.etapas.where(
                (x) => x.certificacion.trim().isNotEmpty,
              )) ...[
                _titulo('Certificación · ${etapa.nombre}'),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _borde, width: 0.6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        etapa.certificacion.toUpperCase(),
                        style: _txt,
                        textAlign: pw.TextAlign.justify,
                      ),
                      pw.SizedBox(height: 4),
                      () {
                        final r = inf.revisiones.lastWhere(
                          (r) => r.etapaId == etapa.id && r.aprobado,
                          orElse: () => const RevisionEtapa(
                            etapaId: '',
                            etapaNombre: '',
                            actor: '',
                            fechaIso: '',
                            aprobado: false,
                          ),
                        );
                        return r.etapaId.isEmpty
                            ? pw.Text(
                                'Pendiente de la certificación de ${etapa.nombre.toLowerCase()}.',
                                style: _neg.copyWith(color: _ambar),
                              )
                            : pw.Text(
                                'Certificado electrónicamente por ${r.actor.toUpperCase()} el ${fechaNumerica(DateTime.parse(r.fechaIso).toLocal())}.',
                                style: _neg,
                              );
                      }(),
                    ],
                  ),
                ),
              ],
            ],
          );
        case 'constancia':
          final limite = inf.hasta;
          final primera = DateTime.tryParse(inf.primeraPresentacionIso)
              ?.toLocal();
          return pw.Column(
            children: [
              _titulo(
                'Constancia de revisión y aprobación · generada por el sistema',
              ),
              pw.Table(
                border: pw.TableBorder.all(color: _borde, width: 0.6),
                children: [
                  pw.TableRow(
                    children: [
                      _celda('Fecha límite', negrita: true),
                      _celda(fechaLegible(limite)),
                      _celda('Primera presentación', negrita: true),
                      _celda(primera == null ? '—' : fechaLegible(primera)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _celda('Cumplimiento del plazo', negrita: true),
                      _celda(
                        primera == null
                            ? '—'
                            : (inf.diasRetraso == 0
                                  ? 'A tiempo'
                                  : 'Con retraso de ${inf.diasRetraso} día(s)'),
                        negrita: true,
                        color: inf.diasRetraso > 0 ? _ambar : null,
                      ),
                      _celda(''),
                      _celda(''),
                    ],
                  ),
                ],
              ),
              if (inf.revisiones.any((r) => !r.aprobado)) ...[
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: _borde, width: 0.6),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(0.22),
                    1: pw.FlexColumnWidth(0.48),
                    2: pw.FlexColumnWidth(0.30),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        _celda('Fecha', negrita: true, fondo: true),
                        _celda('Observación', negrita: true, fondo: true),
                        _celda('Respuesta', negrita: true, fondo: true),
                      ],
                    ),
                    for (final r in inf.revisiones.where((r) => !r.aprobado))
                      pw.TableRow(
                        children: [
                          _celda(
                            '${fechaNumerica(DateTime.parse(r.fechaIso).toLocal())}\n${r.actor.toUpperCase()}',
                          ),
                          _celda(r.observacion),
                          _celda(inf.respuestas[r.fechaIso] ?? '—'),
                        ],
                      ),
                  ],
                ),
              ],
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: _borde, width: 0.6),
                children: [
                  pw.TableRow(
                    children: [
                      for (final h in [
                        'Etapa',
                        'Responsable',
                        'Fecha',
                        'Visto y concepto',
                      ])
                        _celda(h, negrita: true, fondo: true),
                    ],
                  ),
                  for (final etapa in plan.etapas)
                    () {
                      final r = inf.revisiones
                          .where((r) => r.etapaId == etapa.id && r.aprobado)
                          .lastOrNull;
                      return pw.TableRow(
                        children: [
                          _celda(etapa.nombre),
                          _celda(
                            r?.actor ?? 'Pendiente',
                            color: r == null ? _ambar : null,
                            negrita: r == null,
                          ),
                          _celda(
                            r == null
                                ? ''
                                : fechaNumerica(
                                    DateTime.parse(r.fechaIso).toLocal(),
                                  ),
                          ),
                          _celda(
                            r == null
                                ? ''
                                : (r.concepto.isEmpty
                                      ? 'Revisado y verificado'
                                      : r.concepto),
                          ),
                        ],
                      );
                    }(),
                ],
              ),
            ],
          );
      }
      return pw.SizedBox();
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: _pagina(),
        header: (c) => c.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  '${e.numeroContrato} · $titulo',
                  style: _txt.copyWith(color: _borde, fontSize: 7),
                ),
              ),
        footer: (c) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${c.pageNumber} de ${c.pagesCount}',
            style: _txt.copyWith(color: _borde, fontSize: 7),
          ),
        ),
        build: (c) => [
          _encabezado(plan, titulo, sello: sello),
          for (final s in plan.plantilla.secciones) seccion(s),
        ],
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Informe de supervisión
  // ---------------------------------------------------------------------------

  static Future<Uint8List> informeSupervision({
    required ExpedienteContratoPs expediente,
    required PlanSupervision plan,
    required InformePeriodo informe,
    required Map<String, InformePeriodo> todos,
  }) async {
    final doc = await _documento();
    final e = expediente;
    final inf = informe;
    final anteriores = todos.values
        .where(
          (i) =>
              i.numero < inf.numero &&
              (i.estado == EstadoInforme.aprobado ||
                  i.estado == EstadoInforme.pagado),
        )
        .fold<int>(0, (s, i) => s + i.valorCobradoCop);
    final saldo = e.valorContratoCop - anteriores - inf.valorCobradoCop;
    final pagado = inf.planillas.fold<int>(0, (s, p) => s + p.valorCop);
    doc.addPage(
      pw.MultiPage(
        pageTheme: _pagina(),
        build: (c) => [
          _encabezado(plan, 'INFORME DE SUPERVISIÓN No. ${inf.numero}'),
          pw.SizedBox(height: 8),
          _tablaDatos([
            ('Contrato No.', e.numeroContrato),
            (
              'Contratista',
              '${e.contratistaNombreEsperado.toUpperCase()} · C.C. ${e.contratistaCedulaEsperada}',
            ),
            ('Objeto', e.objetoContrato),
            ('Valor total del contrato', formatoCop(e.valorContratoCop)),
            ('Plazo', e.plazoEjecucion),
            (
              'Período supervisado',
              'Desde ${fechaNumerica(inf.desde)} hasta ${fechaNumerica(inf.hasta)}',
            ),
            if (plan.formaPago.isNotEmpty) ('Forma de pago', plan.formaPago),
          ]),
          _titulo('Balance financiero'),
          _tablaDatos([
            ('Valor a pagar en este periodo', formatoCop(inf.valorCobradoCop)),
            ('Pagos anteriores', formatoCop(anteriores)),
            ('Saldo del contrato', formatoCop(saldo < 0 ? 0 : saldo)),
          ]),
          _titulo('Cumplimiento de obligaciones'),
          pw.Table(
            border: pw.TableBorder.all(color: _borde, width: 0.6),
            columnWidths: const {
              0: pw.FixedColumnWidth(40),
              1: pw.FlexColumnWidth(0.8),
              2: pw.FixedColumnWidth(60),
            },
            children: [
              pw.TableRow(
                children: [
                  _celda('ÍTEM', negrita: true, fondo: true),
                  _celda('OBLIGACIÓN', negrita: true, fondo: true),
                  _celda(
                    'CUMPLE',
                    negrita: true,
                    fondo: true,
                    alinear: pw.TextAlign.center,
                  ),
                ],
              ),
              for (final (i, o) in plan.obligaciones.indexed)
                pw.TableRow(
                  children: [
                    _celda('${i + 1}'),
                    _celda(o.texto),
                    _celda('SÍ', alinear: pw.TextAlign.center),
                  ],
                ),
            ],
          ),
          _titulo('Aportes a seguridad social'),
          _tablaDatos([
            for (final p in inf.planillas.where((p) => p.diligenciada))
              (
                'Planilla ${p.numero}',
                '${_titular(nombreMes(p.periodo))} · pagada el ${fechaNumerica(DateTime.parse(p.fechaPagoIso))} · ${formatoCop(p.valorCop)}',
              ),
            ('Total aportado', formatoCop(pagado)),
            (
              'Pensión',
              inf.pensionado
                  ? 'NO APLICA${inf.motivoNoPension.isEmpty ? '' : ' (${inf.motivoNoPension})'}'
                  : 'Aportada',
            ),
          ]),
          pw.SizedBox(height: 10),
          pw.Text(
            'Con base en el informe de actividades presentado por el contratista y sus soportes, certifico el '
            'cumplimiento de las obligaciones del contrato durante el periodo y autorizo el pago correspondiente.',
            style: _txt,
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 26),
          _firma(
            nombre: plan.supervisorNombre,
            lineas: ['SUPERVISOR DEL CONTRATO'],
          ),
        ],
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Documento equivalente a factura (cuenta de cobro)
  // ---------------------------------------------------------------------------

  static Future<Uint8List> documentoEquivalente({
    required ExpedienteContratoPs expediente,
    required PlanSupervision plan,
    required InformePeriodo informe,
    Uint8List? firma,
  }) async {
    final doc = await _documento();
    final e = expediente;
    final inf = informe;
    final d = inf.datosCobro;
    final fecha =
        DateTime.tryParse(inf.enviadoEnIso)?.toLocal() ?? DateTime.now();
    String sn(bool v) => v ? 'SÍ' : 'NO';
    doc.addPage(
      pw.Page(
        pageTheme: _pagina(),
        build: (c) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _encabezado(
              plan,
              'DOCUMENTO EQUIVALENTE A FACTURA No. ${inf.numero}',
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Fecha de expedición: ${fechaLegible(fecha, conDia: false)}',
              style: _txt,
            ),
            _titulo('Adquiriente'),
            _tablaDatos([
              ('Entidad', e.entidadNombre),
              ('NIT', e.entidadNit),
              if (plan.sectorial.isNotEmpty) ('Dependencia', plan.sectorial),
            ]),
            _titulo('Prestador del servicio'),
            _tablaDatos([
              ('Nombre', e.contratistaNombreEsperado.toUpperCase()),
              ('C.C. / NIT', e.contratistaCedulaEsperada),
              ('Dirección', '${d.direccion} · ${d.ciudad}'),
              ('Celular', d.celular),
              ('Responsable de IVA', sn(d.responsableIva)),
              ('Declarante de renta', sn(d.declaranteRenta)),
              ('Facturador electrónico', sn(d.facturadorElectronico)),
              ('Régimen simple de tributación', sn(d.regimenSimple)),
            ]),
            _titulo('Concepto'),
            _tablaDatos([
              (
                'Descripción',
                'Honorarios del contrato ${e.numeroContrato}, pago No. ${inf.numero}, por el periodo del ${fechaNumerica(inf.desde)} al ${fechaNumerica(inf.hasta)}.',
              ),
              ('Valor', formatoCop(inf.valorCobradoCop)),
              (
                'Valor en letras',
                '${valorEnLetras(inf.valorCobradoCop)} M/CTE',
              ),
            ]),
            _titulo('Datos para el pago'),
            _tablaDatos([
              ('Entidad bancaria', d.banco),
              ('Tipo de cuenta', d.tipoCuenta),
              ('Número de cuenta', d.numeroCuenta),
            ]),
            pw.SizedBox(height: 18),
            _firma(
              firma: firma,
              nombre: e.contratistaNombreEsperado,
              lineas: ['C.C. No. ${e.contratistaCedulaEsperada}'],
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Solicitud de descuento de estampillas municipales
  // ---------------------------------------------------------------------------

  static Future<Uint8List> solicitudEstampilla({
    required ExpedienteContratoPs expediente,
    required PlanSupervision plan,
    required InformePeriodo informe,
    Uint8List? firma,
  }) async {
    final doc = await _documento();
    final e = expediente;
    final inf = informe;
    final fecha =
        DateTime.tryParse(inf.enviadoEnIso)?.toLocal() ?? DateTime.now();
    doc.addPage(
      pw.Page(
        pageTheme: _pagina(),
        build: (c) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${_titular(inf.datosCobro.ciudad.toLowerCase())}, ${fechaLegible(fecha, conDia: false)}',
              style: _txt,
            ),
            pw.SizedBox(height: 18),
            pw.Text('Señores', style: _txt),
            pw.Text(e.entidadNombre.toUpperCase(), style: _neg),
            if (plan.sectorial.isNotEmpty) pw.Text(plan.sectorial, style: _txt),
            pw.SizedBox(height: 14),
            pw.Text(
              'Asunto: Solicitud de descuento de estampillas municipales · Contrato ${e.numeroContrato}',
              style: _neg,
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Yo, ${e.contratistaNombreEsperado.toUpperCase()}, identificado(a) con cédula de ciudadanía No. '
              '${e.contratistaCedulaEsperada}, en calidad de contratista, solicito respetuosamente que el valor de '
              'las estampillas municipales a que haya lugar se descuente del pago No. ${inf.numero} del contrato '
              '${e.numeroContrato}, correspondiente al periodo del ${fechaNumerica(inf.desde)} al '
              '${fechaNumerica(inf.hasta)}, por valor de ${formatoCop(inf.valorCobradoCop)}.',
              style: _txt.copyWith(fontSize: 10, lineSpacing: 2),
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 12),
            pw.Text('Atentamente,', style: _txt.copyWith(fontSize: 10)),
            pw.SizedBox(height: 10),
            _firma(
              firma: firma,
              nombre: e.contratistaNombreEsperado,
              lineas: [
                'C.C. No. ${e.contratistaCedulaEsperada}',
                'Contratista',
              ],
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Generados y paquete completo
  // ---------------------------------------------------------------------------

  /// PDF de un documento que arma el sistema, o `null` si no es uno de ellos.
  static Future<Uint8List?> documentoSistema(
    String id, {
    required ExpedienteContratoPs expediente,
    required PlanSupervision plan,
    required InformePeriodo informe,
    required Map<String, InformePeriodo> todos,
    Uint8List? firma,
  }) => switch (id) {
    DocumentosSistema.informeSupervision => informeSupervision(
      expediente: expediente,
      plan: plan,
      informe: informe,
      todos: todos,
    ),
    DocumentosSistema.documentoEquivalente => documentoEquivalente(
      expediente: expediente,
      plan: plan,
      informe: informe,
      firma: firma,
    ),
    DocumentosSistema.estampillaMunicipal => solicitudEstampilla(
      expediente: expediente,
      plan: plan,
      informe: informe,
      firma: firma,
    ),
    _ => Future.value(null),
  };

  static String _nombreArchivo(
    ExpedienteContratoPs e,
    String prefijo,
    InformePeriodo inf,
  ) =>
      '${prefijo}_${e.numeroContrato.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}_No${inf.numero}.pdf';

  static bool abrir(Uint8List bytes) =>
      openBinaryInNewTab(bytes: bytes, mimeType: 'application/pdf');

  static bool descargar(
    Uint8List bytes,
    ExpedienteContratoPs e,
    InformePeriodo inf,
    String prefijo,
  ) => downloadBinaryBytes(
    bytes: bytes,
    fileName: _nombreArchivo(e, prefijo, inf),
    mimeType: 'application/pdf',
  );

  /// Informe de ejecución seguido de los documentos del periodo (en el orden
  /// de la plantilla) y los anexos, en un solo PDF para el archivo.
  static Future<Uint8List> paqueteCompleto({
    required ExpedienteContratoPs expediente,
    required PlanSupervision plan,
    required InformePeriodo informe,
    required Map<String, InformePeriodo> todos,
    Uint8List? firma,
  }) async {
    final token = expediente.tokenInvitado;
    final partes = <DocumentoParaUnir>[
      DocumentoParaUnir(
        titulo: 'Informe de ejecución No. ${informe.numero}',
        nombreArchivo: 'informe.pdf',
        bytes: await informeEjecucion(
          expediente: expediente,
          plan: plan,
          informe: informe,
          firma: firma,
        ),
        tipo: TipoDocumentoParaUnir.pdf,
      ),
    ];
    for (final d in informe.documentosDelPeriodo(plan)) {
      if (d.origen == OrigenDocumento.sistema) {
        final bytes = await documentoSistema(
          d.id,
          expediente: expediente,
          plan: plan,
          informe: informe,
          todos: todos,
          firma: firma,
        );
        if (bytes != null) {
          partes.add(
            DocumentoParaUnir(
              titulo: d.nombre,
              nombreArchivo: '${d.id}.pdf',
              bytes: bytes,
              tipo: TipoDocumentoParaUnir.pdf,
            ),
          );
        }
        continue;
      }
      for (final a in informe.documentos[d.id] ?? const <ArchivoAdjunto>[]) {
        final bytes = await SupervisionService.bytesArchivo(
          token,
          informe.id,
          a,
        );
        if (bytes == null) continue;
        partes.add(
          DocumentoParaUnir(
            titulo: d.nombre,
            nombreArchivo: a.nombre,
            bytes: bytes,
            tipo: TipoDocumentoParaUnir.detectar(bytes, a.nombre),
          ),
        );
      }
    }
    for (final (i, anexo) in informe.anexos.indexed) {
      for (final a in anexo.archivos) {
        final bytes = await SupervisionService.bytesArchivo(
          token,
          informe.id,
          a,
        );
        if (bytes == null) continue;
        partes.add(
          DocumentoParaUnir(
            titulo: 'Anexo ${i + 1}. ${anexo.titulo}',
            nombreArchivo: a.nombre,
            bytes: bytes,
            tipo: TipoDocumentoParaUnir.detectar(bytes, a.nombre),
          ),
        );
      }
    }
    return unirDocumentosEnPdf(
      partes,
      tituloDocumento:
          'Informe No. ${informe.numero} · ${expediente.numeroContrato}',
    );
  }
}
