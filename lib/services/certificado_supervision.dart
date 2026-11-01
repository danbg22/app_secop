import 'dart:convert';

import '../utils/file_downloader.dart';
import 'juridico_contratacion_service.dart';
import 'supervision_service.dart';

/// Certificado de cumplimiento del mes (Word), para que el supervisor lo
/// firme y lo anexe a la cuenta de cobro.
class CertificadoSupervision {
  CertificadoSupervision._();

  static const HtmlEscape _escape = HtmlEscape();
  static String _e(String v) => _escape.convert(v);

  static String html({
    required ExpedienteContratoPs expediente,
    required PlanSupervision plan,
    required InformeMensual informe,
    required Map<String, InformeMensual> todos,
  }) {
    final aporte = AporteEsperado.calcular(
      valorMensualCop: informe.valorCobradoCop,
      claseRiesgo: plan.claseRiesgo,
      anio:
          int.tryParse(informe.periodo.split('-').first) ?? DateTime.now().year,
    );
    final pagadoAntes = todos.values
        .where(
          (i) =>
              i.periodo.compareTo(informe.periodo) < 0 &&
              (i.estado == EstadoInforme.aprobado ||
                  i.estado == EstadoInforme.pagado),
        )
        .fold<int>(0, (s, i) => s + i.valorCobradoCop);
    final acumulado = pagadoAntes + informe.valorCobradoCop;
    final saldo = expediente.valorContratoCop - acumulado;
    final p = informe.planilla;

    final obligaciones = StringBuffer(
      '<tr><th style="width:4%">N.°</th><th style="width:40%">Obligación</th><th>Actividades realizadas</th></tr>',
    );
    for (var i = 0; i < plan.obligaciones.length; i++) {
      final o = plan.obligaciones[i];
      obligaciones.write(
        '<tr><td>${i + 1}</td><td>${_e(o.texto)}</td>'
        '<td>${_e(informe.actividades[o.id] ?? '').replaceAll('\n', '<br>')}</td></tr>',
      );
    }

    final titulo =
        'CERTIFICADO DE CUMPLIMIENTO — ${nombrePeriodo(informe.periodo).toUpperCase()}';
    return '''
<html><head><meta charset="utf-8"><title>${_e(titulo)}</title>
<style>
body{font-family:Arial,sans-serif;font-size:11pt;color:#111}
h1{font-size:13.5pt;text-align:center;margin-bottom:2pt}
h2{font-size:11.5pt;margin-top:14pt}
table{border-collapse:collapse;width:100%;margin-top:6pt}
th,td{border:1px solid #777;padding:4pt;vertical-align:top;font-size:9.5pt}
th{background:#e8edf5;text-align:left}
.nota{color:#7a4b00;font-size:9pt;border:1px solid #e0b75c;background:#fff7e0;padding:6pt}
</style></head><body>
<p class="nota">Documento generado con Contrata Legal a partir del informe aprobado. Revíselo y fírmelo.</p>
<h1>${_e(titulo)}</h1>
<p style="text-align:center">${_e(expediente.entidadNombre)}${expediente.dependencia.isEmpty ? '' : ' · ${_e(expediente.dependencia)}'}</p>
<table>
<tr><th style="width:30%">Contrato</th><td>${_e(expediente.numeroContrato)}</td></tr>
<tr><th>Contratista</th><td>${_e(expediente.contratistaNombreEsperado)} · C.C. ${_e(expediente.contratistaCedulaEsperada)}</td></tr>
<tr><th>Objeto</th><td>${_e(expediente.objetoContrato)}</td></tr>
<tr><th>Valor total del contrato</th><td>${_e(formatoCop(expediente.valorContratoCop))}</td></tr>
<tr><th>Periodo certificado</th><td>${_e(nombrePeriodo(informe.periodo))}</td></tr>
<tr><th>Valor a pagar este periodo</th><td><b>${_e(formatoCop(informe.valorCobradoCop))}</b></td></tr>
<tr><th>Pagado en periodos anteriores</th><td>${_e(formatoCop(pagadoAntes))}</td></tr>
<tr><th>Saldo del contrato después de este pago</th><td>${_e(formatoCop(saldo < 0 ? 0 : saldo))}</td></tr>
</table>

<h2>1. Cumplimiento de las obligaciones</h2>
<table>$obligaciones</table>

<h2>2. Aportes al Sistema de Seguridad Social Integral</h2>
<p>Se verificó el pago de aportes conforme al artículo 23 de la Ley 1150 de 2007 y al Decreto 1273 de 2018:</p>
<table>
<tr><th style="width:30%">Planilla</th><td>${_e(p.numero)} · periodo ${_e(nombrePeriodo(p.periodoCotizado))}</td></tr>
<tr><th>IBC</th><td>${_e(formatoCop(p.ibcCop))} (mínimo ${_e(formatoCop(aporte.ibc))})</td></tr>
<tr><th>Salud</th><td>${_e(formatoCop(p.saludCop))}</td></tr>
<tr><th>Pensión</th><td>${p.pensionado ? 'No aplica (pensionado)' : _e(formatoCop(p.pensionCop))}</td></tr>
<tr><th>Riesgos laborales</th><td>${aporte.arlLaPagaLaEntidad ? 'Riesgo ${plan.claseRiesgo}: a cargo de la entidad' : _e(formatoCop(p.arlCop))}</td></tr>
</table>

<h2>3. Concepto del supervisor</h2>
<p>${_e(informe.conceptoSupervisor.isEmpty ? 'El contratista cumplió a satisfacción las obligaciones del periodo.' : informe.conceptoSupervisor)}</p>
<p>Revisión documental: ${_e(informe.revisorNombre)}${informe.revisadoEnIso.isEmpty ? '' : ', ${_e(JuridicoContratacionService.formatearFechaHumana(informe.revisadoEnIso))}'}.</p>

<p style="margin-top:40pt">______________________________<br>
${_e(plan.supervisorNombre)}<br>Supervisor del contrato</p>
</body></html>''';
  }

  static bool descargar({
    required ExpedienteContratoPs expediente,
    required PlanSupervision plan,
    required InformeMensual informe,
    required Map<String, InformeMensual> todos,
  }) => downloadBinaryBytes(
    bytes: utf8.encode(
      html(expediente: expediente, plan: plan, informe: informe, todos: todos),
    ),
    fileName:
        'Certificado_cumplimiento_${expediente.numeroContrato.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}_${informe.periodo}.doc',
    mimeType: 'application/msword',
  );
}
