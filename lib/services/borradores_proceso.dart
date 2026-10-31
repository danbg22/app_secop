import 'dart:convert';

import 'package:intl/intl.dart';

import '../data/modalidades_contratacion.dart';
import '../utils/file_downloader.dart';
import 'procesos_contratacion_service.dart';

/// Borradores editables (Word) que ahorran trabajo manual al equipo
/// jurídico. Son documentos internos de apoyo: el equipo los revisa, los
/// firma y los publica en SECOP II, que es donde tienen efecto.
class BorradoresProceso {
  BorradoresProceso._();

  static final NumberFormat _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  static const HtmlEscape _escape = HtmlEscape();
  static String _e(String v) => _escape.convert(v);

  static String _documento(String titulo, String cuerpo) => '''
<html><head><meta charset="utf-8"><title>${_e(titulo)}</title>
<style>
body{font-family:Arial,sans-serif;font-size:11pt;color:#111}
h1{font-size:14pt;text-align:center;margin-bottom:4pt}
h2{font-size:12pt;margin-top:16pt}
table{border-collapse:collapse;width:100%;margin-top:6pt}
th,td{border:1px solid #777;padding:4pt;vertical-align:top;font-size:9.5pt}
th{background:#e8edf5}
.nota{color:#7a4b00;font-size:9pt;border:1px solid #e0b75c;background:#fff7e0;padding:6pt}
</style></head><body>$cuerpo</body></html>''';

  static String _encabezado(ProcesoContratacion p, String titulo) => '''
<p class="nota">BORRADOR generado con Contrata Legal como apoyo interno. Revíselo, ajústelo,
fírmelo y publíquelo en SECOP II, que es el sistema oficial del proceso.</p>
<h1>${_e(titulo)}</h1>
<p style="text-align:center">${_e(p.entidadNombre)}${p.entidadNit.isEmpty ? '' : ' · NIT ${_e(p.entidadNit)}'}</p>
<table>
<tr><th style="width:28%">Proceso</th><td>${_e(p.numeroProceso)}${p.idProcesoSecop.isEmpty ? '' : ' (SECOP II: ${_e(p.idProcesoSecop)})'}</td></tr>
<tr><th>Modalidad</th><td>${_e(p.modalidad.nombre)}</td></tr>
<tr><th>Objeto</th><td>${_e(p.objeto)}</td></tr>
<tr><th>Presupuesto oficial</th><td>${_e(_cop.format(p.presupuestoCop))}</td></tr>
</table>''';

  static String _celda(VerificacionRequisito? v) {
    final estado = v?.estado ?? EstadoVerificacion.pendiente;
    final obs = (v?.observacion ?? '').trim();
    return '${_e(estado.etiqueta)}${obs.isEmpty ? '' : '<br><i>${_e(obs)}</i>'}';
  }

  /// Ofertas en orden de elegibilidad: habilitadas primero, luego mayor
  /// puntaje y, a igualdad, menor valor.
  static List<OfertaRecibida> ordenElegibilidad(ProcesoContratacion p) {
    final requisitos = p.requisitosVerificacion;
    int prioridad(OfertaRecibida o) =>
        ResultadoVerificacion.calcular(requisitos, o.verificaciones) ==
            ResultadoVerificacion.habilitada
        ? 0
        : 1;
    return [...p.ofertas]..sort((a, b) {
      final pr = prioridad(a).compareTo(prioridad(b));
      if (pr != 0) return pr;
      final pa = a.puntaje ?? -1, pb = b.puntaje ?? -1;
      if (pa != pb) return pb.compareTo(pa);
      final va = a.valorCop == 0 ? 1 << 62 : a.valorCop;
      final vb = b.valorCop == 0 ? 1 << 62 : b.valorCop;
      return va.compareTo(vb);
    });
  }

  static String informeEvaluacionHtml(ProcesoContratacion p) {
    final requisitos = p.requisitosVerificacion;
    final ofertas = ordenElegibilidad(p);
    final titulo = p.esDirecta
        ? 'INFORME DE VERIFICACIÓN DE REQUISITOS DEL CONTRATISTA'
        : 'INFORME DE EVALUACIÓN DE OFERTAS';
    final verificacion = StringBuffer('<tr><th>Requisito</th>');
    for (final o in ofertas) {
      verificacion.write('<th>${_e(o.proponente)}<br>${_e(o.nit)}</th>');
    }
    verificacion.write('</tr>');
    for (final r in requisitos) {
      verificacion.write(
        '<tr><td>${_e(r.nombre)}${r.obligatorio ? '' : ' (si aplica)'}</td>',
      );
      for (final o in ofertas) {
        verificacion.write('<td>${_celda(o.verificaciones[r.id])}</td>');
      }
      verificacion.write('</tr>');
    }
    verificacion.write('<tr><th>Resultado</th>');
    for (final o in ofertas) {
      verificacion.write(
        '<th>${_e(ResultadoVerificacion.calcular(requisitos, o.verificaciones).etiqueta)}</th>',
      );
    }
    verificacion.write('</tr>');

    final calificacion = StringBuffer(
      '<tr><th>Orden</th><th>Proponente</th><th>Valor ofertado</th><th>Puntaje</th><th>Observaciones</th></tr>',
    );
    for (var i = 0; i < ofertas.length; i++) {
      final o = ofertas[i];
      calificacion.write(
        '<tr><td>${i + 1}</td><td>${_e(o.proponente)}</td>'
        '<td>${o.valorCop > 0 ? _e(_cop.format(o.valorCop)) : '—'}</td>'
        '<td>${o.puntaje?.toString() ?? '—'}</td><td>${_e(o.nota)}</td></tr>',
      );
    }

    final cuerpo = '''
${_encabezado(p, titulo)}
${p.modalidad.criterioEvaluacion == null ? '' : '<p><b>Criterio de escogencia:</b> ${_e(p.modalidad.criterioEvaluacion!)}</p>'}
<h2>1. Ofertas recibidas en SECOP II</h2>
<p>Se recibieron ${ofertas.length} ${ofertas.length == 1 ? 'oferta' : 'ofertas'}${p.fechaHito('cierre') == null ? '' : ' al cierre del ${_e(ProcesosContratacionService.fechaCorta(p.fechaHito('cierre')!))}'}.</p>
<h2>2. Verificación de requisitos habilitantes</h2>
<table>$verificacion</table>
${p.esDirecta ? '' : '<h2>3. Calificación y orden de elegibilidad</h2><table>$calificacion</table>'}
<h2>${p.esDirecta ? '3' : '4'}. Conclusión y recomendación</h2>
<p>[Redacte aquí la recomendación del comité evaluador.]</p>
<h2>Firmas del comité evaluador</h2>
<table><tr><td style="height:60pt">Nombre y cargo</td><td>Nombre y cargo</td><td>Nombre y cargo</td></tr></table>
''';
    return _documento(titulo, cuerpo);
  }

  static String respuestasObservacionesHtml(ProcesoContratacion p) {
    final etapas = {for (final e in p.modalidad.etapas) e.id: e.nombre};
    final filas = StringBuffer(
      '<tr><th>N.°</th><th>Interesado y fecha</th><th>Etapa</th><th>Observación</th><th>Respuesta de la entidad</th></tr>',
    );
    for (var i = 0; i < p.observaciones.length; i++) {
      final o = p.observaciones[i];
      filas.write(
        '<tr><td>${i + 1}</td><td>${_e(o.interesado)}<br>${_e(o.fechaIso)}</td>'
        '<td>${_e(etapas[o.etapaId] ?? '')}</td><td>${_e(o.texto)}</td>'
        '<td>${o.respondida ? _e(o.respuesta) : '<i>[Pendiente de respuesta]</i>'}</td></tr>',
      );
    }
    const titulo = 'RESPUESTA A OBSERVACIONES';
    return _documento(titulo, '''
${_encabezado(p, titulo)}
<h2>Observaciones recibidas en SECOP II y respuestas</h2>
<table>$filas</table>
<h2>Firma</h2>
<p style="height:50pt">Nombre y cargo</p>
''');
  }

  static String _nombreArchivo(ProcesoContratacion p, String prefijo) =>
      '${prefijo}_${p.numeroProceso.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}.doc';

  static bool descargarInformeEvaluacion(ProcesoContratacion p) =>
      downloadBinaryBytes(
        bytes: utf8.encode(informeEvaluacionHtml(p)),
        fileName: _nombreArchivo(p, 'Borrador_informe_evaluacion'),
        mimeType: 'application/msword',
      );

  static bool descargarRespuestasObservaciones(ProcesoContratacion p) =>
      downloadBinaryBytes(
        bytes: utf8.encode(respuestasObservacionesHtml(p)),
        fileName: _nombreArchivo(p, 'Borrador_respuesta_observaciones'),
        mimeType: 'application/msword',
      );

  /// Referencia a los requisitos para mostrar el criterio en la interfaz.
  static List<DocumentoRequerido> requisitos(ProcesoContratacion p) =>
      p.requisitosVerificacion;
}
