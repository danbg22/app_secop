import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/paa_service.dart';
import '../../services/verificacion_paa_service.dart';
import '../../utils/file_downloader.dart';
import '../../utils/texto_profesional.dart';
import '../gestion_contractual/estilo_contractual.dart';

const _mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
const _meses = [
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

String copVerif(double v) {
  final t = v.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '\$ $t';
}

String millonesVerif(double v) {
  final m = v / 1e6;
  if (m.abs() < 10) return '\$ ${m.toStringAsFixed(1).replaceAll('.', ',')} M';
  final t = m.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '\$ $t M';
}

String fechaVerif(String iso) {
  final d = DateTime.tryParse(iso.replaceFirst(' ', 'T').split('.').first);
  if (d == null || d.year < 2000) return '';
  return '${d.day} ${_mesesCortos[d.month - 1]} ${d.year}';
}

/// Colores y nombre de cada estado real de un proceso.
(Color, Color) coloresEstado(EstadoProceso e) => switch (e) {
  EstadoProceso.abierto => (const Color(0xFF15803D), const Color(0xFFDCFCE7)),
  EstadoProceso.enCurso => (const Color(0xFF1D4ED8), const Color(0xFFDBEAFE)),
  EstadoProceso.estudioMercado => (
    const Color(0xFF6D28D9),
    const Color(0xFFEDE9FE),
  ),
  EstadoProceso.adjudicado => (EstiloContractual.navy, const Color(0xFFE2E8F0)),
  EstadoProceso.desierto ||
  EstadoProceso.cancelado => (const Color(0xFFB91C1C), const Color(0xFFFEE2E2)),
};

Widget _clave(String t) =>
    Text(t.toUpperCase(), style: EstiloContractual.seccion);

// -----------------------------------------------------------------------------
// Ejecución frente al plan
// -----------------------------------------------------------------------------

/// Proyectado en el PAA frente a lo contratado, pagado y en proceso en el
/// año, con lo que falta por contratar (aproximado).
class TarjetaEjecucion extends StatelessWidget {
  const TarjetaEjecucion({
    super.key,
    required this.anio,
    required this.proyectadoCop,
    required this.ejecucion,
    required this.enProcesoCop,
    required this.procesosEnCurso,
  });

  final int anio;
  final double proyectadoCop;
  final Future<EjecucionPlan>? ejecucion;

  /// Precio base de los procesos del año abiertos o en evaluación.
  final double? enProcesoCop;
  final int procesosEnCurso;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 22),
      decoration: EstiloContractual.tarjeta(),
      child: FutureBuilder<EjecucionPlan>(
        future: ejecucion,
        builder: (context, snap) {
          final e = snap.data;
          final enProceso = enProcesoCop;
          Widget cuerpo;
          if (snap.hasError) {
            cuerpo = const Text(
              'No fue posible consultar los contratos en SECOP II. Intenta más tarde.',
              style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
            );
          } else if (e == null || enProceso == null) {
            cuerpo = const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 3),
            );
          } else {
            final porPagar = (e.contratadoCop - e.pagadoCop)
                .clamp(0, double.infinity)
                .toDouble();
            final falta = (proyectadoCop - e.contratadoCop - enProceso)
                .clamp(0, double.infinity)
                .toDouble();
            final base = [
              proyectadoCop,
              e.contratadoCop + enProceso,
            ].reduce((a, b) => a > b ? a : b);
            Widget cifra(String k, String v, String nota, Color color) =>
                SizedBox(
                  width: mobile ? double.infinity : 230,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(child: _clave(k)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          v,
                          style: const TextStyle(
                            color: EstiloContractual.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          nota,
                          style: const TextStyle(
                            color: EstiloContractual.gris,
                            fontSize: 12.3,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
            const cPagado = Color(0xFF15803D);
            const cContratado = Color(0xFF86EFAC);
            const cProceso = Color(0xFF60A5FA);
            const cFalta = Color(0xFFFBBF24);
            cuerpo = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 14,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        double w(double v) =>
                            base <= 0 ? 0 : (v / base) * c.maxWidth;
                        return Row(
                          children: [
                            Container(width: w(e.pagadoCop), color: cPagado),
                            Container(width: w(porPagar), color: cContratado),
                            Container(width: w(enProceso), color: cProceso),
                            Container(width: w(falta), color: cFalta),
                            const Expanded(
                              child: ColoredBox(color: Color(0xFFF1F5F9)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 12,
                  children: [
                    cifra(
                      'Pagado',
                      millonesVerif(e.pagadoCop),
                      e.contratadoCop <= 0
                          ? 'Sin contratos firmados en $anio'
                          : '${(e.pagadoCop / e.contratadoCop * 100).round()} % de lo contratado',
                      cPagado,
                    ),
                    cifra(
                      'Contratado sin pagar',
                      millonesVerif(porPagar),
                      '${e.contratos} contratos firmados en $anio por ${millonesVerif(e.contratadoCop)}',
                      cContratado,
                    ),
                    cifra(
                      'En proceso de selección',
                      millonesVerif(enProceso),
                      '$procesosEnCurso procesos abiertos o en evaluación (presupuesto oficial)',
                      cProceso,
                    ),
                    cifra(
                      'Falta por contratar (aprox.)',
                      millonesVerif(falta),
                      'Proyectado ${millonesVerif(proyectadoCop)} menos lo contratado y lo que está en proceso',
                      cFalta,
                    ),
                  ],
                ),
                if (e.sinValor > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Ojo: ${e.sinValor} de los ${e.contratos} contratos firmados en $anio figuran con valor '
                    '\$ 0 en Datos Abiertos, así que lo contratado real es mayor y lo que falta por '
                    'contratar, menor.',
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 12.3,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Es un cruce aproximado de tres fuentes de SECOP II: el PAA, los procesos y los contratos '
                  'firmados en el año. Puede diferir de la ejecución presupuestal oficial: hay contratos que '
                  'no estaban en el plan (urgencias, convenios), compras del plan que se pagan en otra '
                  'vigencia y gastos que no pasan por SECOP (como la nómina).',
                  style: TextStyle(
                    color: EstiloContractual.gris,
                    fontSize: 11.8,
                    height: 1.45,
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ejecución frente al plan $anio',
                style: EstiloContractual.tituloGrupo,
              ),
              const SizedBox(height: 4),
              const Text(
                '¿Cuánto del plan ya se contrató y pagó, y cuánto queda por contratar?',
                style: TextStyle(color: EstiloContractual.gris, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              cuerpo,
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Procesos abiertos hoy
// -----------------------------------------------------------------------------

/// Procesos competitivos que hoy reciben ofertas en SECOP II, estén o no en
/// el plan, con su cierre y la competencia que ya tienen.
class PanelProcesosAbiertos extends StatelessWidget {
  const PanelProcesosAbiertos({
    super.key,
    required this.procesos,
    required this.enPlan,
    required this.entidad,
    required this.error,
    this.cuentaDe = const {},
    this.titulo = 'Procesos abiertos hoy en SECOP II',
    this.vacio =
        'Hoy esta cuenta no tiene procesos competitivos recibiendo ofertas.',
  });

  final List<ProcesoSecop>? procesos;

  /// Nombre de la cuenta (regional, centro) de cada proceso, por referencia.
  final Map<String, String> cuentaDe;
  final String titulo;
  final String vacio;

  /// Referencias de procesos que corresponden a una compra del plan.
  final Set<String> enPlan;
  final String entidad;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final abiertos =
        [
          for (final p in procesos ?? const <ProcesoSecop>[])
            if (p.estado == EstadoProceso.abierto && p.esCompetitivo) p,
        ]..sort((a, b) {
          final ca = a.cierre, cb = b.cierre;
          if (ca == null) return 1;
          if (cb == null) return -1;
          return ca.compareTo(cb);
        });
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 22),
      decoration: EstiloContractual.tarjeta(
        colorBorde: const Color(0xFFBBF7D0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined, color: Color(0xFF15803D)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  procesos == null ? titulo : '$titulo (${abiertos.length})',
                  style: EstiloContractual.tituloGrupo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Recibiendo ofertas ahora mismo, estén o no en el plan. Verificado contra SECOP II '
            '(Datos Abiertos se actualiza a diario; confirma la hora de cierre en el proceso).',
            style: TextStyle(color: EstiloContractual.gris, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (error != null)
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
            )
          else if (procesos == null)
            const LinearProgressIndicator(minHeight: 3)
          else if (abiertos.isEmpty)
            Text(
              vacio,
              style: const TextStyle(
                color: EstiloContractual.texto,
                fontSize: 13.2,
              ),
            )
          else
            for (final p in abiertos.take(20))
              _FilaAbierto(
                proceso: p,
                enPlan: cuentaDe.isEmpty ? enPlan.contains(p.referencia) : null,
                entidad: entidad,
                cuenta: cuentaDe[p.referencia],
              ),
        ],
      ),
    );
  }
}

class _FilaAbierto extends StatelessWidget {
  const _FilaAbierto({
    required this.proceso,
    required this.enPlan,
    required this.entidad,
    this.cuenta,
  });

  final ProcesoSecop proceso;

  /// null: no se sabe si está en el plan (vista de la entidad).
  final bool? enPlan;
  final String entidad;
  final String? cuenta;

  @override
  Widget build(BuildContext context) {
    final p = proceso;
    final cierre = p.cierre;
    final hoy = DateTime.now();
    final dias = cierre == null
        ? null
        : DateTime(
            cierre.year,
            cierre.month,
            cierre.day,
          ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    final textoCierre = dias == null
        ? 'Cierre: consúltalo en SECOP II'
        : dias == 0
        ? 'Cierra hoy (${fechaVerif(p.recepcionIso)})'
        : dias == 1
        ? 'Cierra mañana (${fechaVerif(p.recepcionIso)})'
        : 'Cierra en $dias días (${fechaVerif(p.recepcionIso)})';
    final competencia = [
      if (p.respuestas > 0)
        '${p.respuestas} oferta${p.respuestas == 1 ? '' : 's'}',
      if (p.manifestaciones > 0)
        '${p.manifestaciones} manifestaci${p.manifestaciones == 1 ? 'ón' : 'ones'} de interés',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              EtiquetaColor(
                texto: textoCierre,
                color: dias != null && dias <= 2
                    ? const Color(0xFFB45309)
                    : const Color(0xFF15803D),
                fondo: dias != null && dias <= 2
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFDCFCE7),
                icono: Icons.schedule_rounded,
              ),
              if (p.modalidad.isNotEmpty)
                EtiquetaColor(
                  texto: TextoProfesional.etiqueta(p.modalidad),
                  color: const Color(0xFF1D4ED8),
                  fondo: const Color(0xFFEFF6FF),
                ),
              if (cuenta != null)
                EtiquetaColor(
                  texto: cuenta!,
                  color: EstiloContractual.navy,
                  fondo: const Color(0xFFF1F5F9),
                ),
              if (enPlan != null)
                EtiquetaColor(
                  texto: enPlan! ? 'Estaba en el PAA' : 'No figura en el PAA',
                  color: enPlan!
                      ? EstiloContractual.navy
                      : EstiloContractual.gris,
                  fondo: const Color(0xFFF1F5F9),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            TextoProfesional.oracion(
              p.nombre.isEmpty ? p.descripcion : p.nombre,
            ),
            style: const TextStyle(
              color: EstiloContractual.navy,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (p.descripcion.isNotEmpty && p.nombre.isNotEmpty)
            Text(
              TextoProfesional.oracion(p.descripcion),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EstiloContractual.texto,
                fontSize: 12.8,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            [
              p.referencia,
              if (p.precioBaseCop > 0)
                'presupuesto oficial ${copVerif(p.precioBaseCop)}',
              competencia.isEmpty
                  ? 'aún sin ofertas registradas'
                  : 'competencia: ${competencia.join(', ')}',
            ].join(' · '),
            style: const TextStyle(
              color: EstiloContractual.gris,
              fontSize: 12.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (p.url.startsWith('http'))
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(p.url)),
                  style: EstiloContractual.botonSecundario(),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text(
                    'Ver en SECOP II',
                    style: EstiloContractual.etiquetaBoton,
                  ),
                ),
              if (p.cierre != null)
                OutlinedButton.icon(
                  onPressed: () {
                    final ok = downloadBinaryBytes(
                      bytes: utf8.encode(
                        VerificacionPaaService.eventoCalendario(p, entidad),
                      ),
                      fileName:
                          'cierre-${p.referencia.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '_')}.ics',
                      mimeType: 'text/calendar',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Abre el archivo descargado para agregar el cierre a tu calendario.'
                              : 'No fue posible descargar el evento.',
                        ),
                      ),
                    );
                  },
                  style: EstiloContractual.botonSecundario(),
                  icon: const Icon(Icons.event_available_rounded, size: 17),
                  label: const Text(
                    'Agregar a mi calendario',
                    style: EstiloContractual.etiquetaBoton,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Verificación de una compra del plan
// -----------------------------------------------------------------------------

/// Proceso real de la compra en SECOP II, su contrato y modificaciones,
/// comparados con lo planeado en el PAA.
class DetalleVerificacion extends StatefulWidget {
  const DetalleVerificacion({
    super.key,
    required this.item,
    required this.cruce,
    required this.verificando,
    required this.anio,
  });

  final ItemPaa item;
  final Cruce? cruce;

  /// true mientras se consultan los procesos de la cuenta.
  final bool verificando;
  final int anio;

  @override
  State<DetalleVerificacion> createState() => _DetalleVerificacionState();
}

class _DetalleVerificacionState extends State<DetalleVerificacion> {
  // Se conservan entre aperturas para no repetir consultas.
  static final Map<String, Future<List<ContratoSecop>>> _contratos = {};
  static final Map<String, Future<List<ModificacionContrato>>> _mods = {};

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final c = widget.cruce;
    if (widget.verificando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Verificando en SECOP II…',
              style: TextStyle(color: EstiloContractual.gris, fontSize: 12.8),
            ),
          ],
        ),
      );
    }
    if (c == null) {
      return _Caja(
        children: [
          _clave('Verificación en SECOP II'),
          const SizedBox(height: 4),
          Text(
            i.yaTieneProceso
                ? 'La entidad vinculó el proceso ${i.procesoRelacionado}, pero no aparece entre sus '
                      'procesos publicados desde enero de ${widget.anio} en Datos Abiertos.'
                : 'No encontramos un proceso en SECOP II con este objeto desde enero de ${widget.anio}. '
                      'Si su mes ya pasó, la entidad pudo aplazarlo, contratarlo con otro nombre o quitarlo del plan.',
            style: const TextStyle(
              color: EstiloContractual.texto,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      );
    }
    final p = c.proceso;
    final (color, fondo) = coloresEstado(p.estado);
    final publicado = p.publicacion;
    final contratos = _contratos.putIfAbsent(
      p.portafolio,
      () => VerificacionPaaService.contratos(p.portafolio),
    );

    String diferencia(double real, double plan) {
      if (plan <= 0 || real <= 0) return '';
      final d = ((real - plan) / plan * 100).round();
      if (d == 0) return 'igual a lo planeado';
      return d > 0
          ? '$d % más que lo planeado'
          : '${-d} % menos que lo planeado';
    }

    return _Caja(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _clave('Verificación en SECOP II'),
            EtiquetaColor(texto: p.estado.etiqueta, color: color, fondo: fondo),
            EtiquetaColor(
              texto: c.vinculo == Vinculo.porEntidad
                  ? 'Vinculado por la entidad'
                  : 'Coincidencia por objeto y valor (${(c.similitud * 100).round()} %)',
              color: EstiloContractual.gris,
              fondo: const Color(0xFFF1F5F9),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${p.referencia} · ${TextoProfesional.oracion(p.nombre.isEmpty ? p.descripcion : p.nombre)}',
          style: const TextStyle(
            color: EstiloContractual.navy,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (p.fase.isNotEmpty)
          Text(
            'Fase en SECOP II: ${p.fase}',
            style: const TextStyle(
              color: EstiloContractual.gris,
              fontSize: 12.3,
            ),
          ),
        const SizedBox(height: 10),
        _clave('Planeado frente a lo real'),
        const SizedBox(height: 4),
        _Comparacion(
          filas: [
            (
              'Inicio',
              i.mes == 0 ? 'Sin mes definido' : _meses[i.mes - 1],
              publicado == null
                  ? '—'
                  : 'Publicado el ${fechaVerif(p.publicacionIso)}',
            ),
            (
              'Valor',
              copVerif(i.valorCop),
              p.precioBaseCop > 0
                  ? 'Presupuesto oficial ${copVerif(p.precioBaseCop)}'
                        '${diferencia(p.precioBaseCop, i.valorCop).isEmpty ? '' : ' (${diferencia(p.precioBaseCop, i.valorCop)})'}'
                  : '—',
            ),
            if (p.valorAdjudicadoCop > 0 || p.proveedor.isNotEmpty)
              (
                'Adjudicación',
                '',
                [
                  if (p.proveedor.isNotEmpty)
                    TextoProfesional.titulo(p.proveedor),
                  if (p.valorAdjudicadoCop > 0) copVerif(p.valorAdjudicadoCop),
                ].join(' · '),
              ),
          ],
        ),
        FutureBuilder<List<ContratoSecop>>(
          future: contratos,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No fue posible consultar el contrato.',
                  style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5),
                ),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LinearProgressIndicator(minHeight: 3),
              );
            }
            final lista = snap.data!;
            if (lista.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  p.estado == EstadoProceso.adjudicado
                      ? 'SECOP II aún no registra el contrato firmado de este proceso.'
                      : 'Todavía no hay contrato: el proceso no ha terminado.',
                  style: const TextStyle(
                    color: EstiloContractual.texto,
                    fontSize: 12.8,
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final k in lista.take(5))
                  _Contrato(
                    contrato: k,
                    planeadoCop: i.valorCop,
                    duracionPlaneada: i.duracion,
                    modificaciones: _mods.putIfAbsent(
                      k.id,
                      () => VerificacionPaaService.modificaciones(k.id),
                    ),
                    diferencia: diferencia,
                  ),
                if (lista.length > 5)
                  Text(
                    'y ${lista.length - 5} contratos más de este proceso.',
                    style: const TextStyle(
                      color: EstiloContractual.gris,
                      fontSize: 12.3,
                    ),
                  ),
              ],
            );
          },
        ),
        if (p.url.startsWith('http')) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(p.url)),
            style: EstiloContractual.botonSecundario(),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text(
              'Ver el proceso en SECOP II',
              style: EstiloContractual.etiquetaBoton,
            ),
          ),
        ],
      ],
    );
  }
}

class _Contrato extends StatelessWidget {
  const _Contrato({
    required this.contrato,
    required this.planeadoCop,
    required this.duracionPlaneada,
    required this.modificaciones,
    required this.diferencia,
  });

  final ContratoSecop contrato;
  final double planeadoCop;
  final String duracionPlaneada;
  final Future<List<ModificacionContrato>> modificaciones;
  final String Function(double, double) diferencia;

  @override
  Widget build(BuildContext context) {
    final k = contrato;
    final estado = k.estado.isEmpty
        ? ''
        : k.estado[0].toUpperCase() + k.estado.substring(1).toLowerCase();
    final inicio = fechaVerif(k.inicioIso), fin = fechaVerif(k.finIso);
    final dif = diferencia(k.valorCop, planeadoCop);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EstiloContractual.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Contrato ${k.referencia.isEmpty ? k.id : k.referencia}',
                style: const TextStyle(
                  color: EstiloContractual.navy,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (estado.isNotEmpty)
                EtiquetaColor(
                  texto: estado,
                  color: EstiloContractual.navy,
                  fondo: const Color(0xFFE2E8F0),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (k.proveedor.isNotEmpty) TextoProfesional.titulo(k.proveedor),
              if (k.valorCop > 0)
                'valor ${copVerif(k.valorCop)}${dif.isEmpty ? '' : ' ($dif)'}',
              if (k.valorCop > 0) 'pagado ${copVerif(k.pagadoCop)}',
            ].join(' · '),
            style: const TextStyle(
              color: EstiloContractual.texto,
              fontSize: 12.8,
              height: 1.4,
            ),
          ),
          if (inicio.isNotEmpty || fin.isNotEmpty)
            Text(
              [
                'Ejecución: ${inicio.isEmpty ? '—' : inicio} a ${fin.isEmpty ? '—' : fin}',
                if (duracionPlaneada.isNotEmpty) 'planeado: $duracionPlaneada',
                if (k.diasAdicionados > 0)
                  'prorrogado ${k.diasAdicionados} días',
              ].join(' · '),
              style: const TextStyle(
                color: EstiloContractual.gris,
                fontSize: 12.3,
              ),
            ),
          FutureBuilder<List<ModificacionContrato>>(
            future: modificaciones,
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final mods = snap.data!;
              if (mods.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Sin modificaciones registradas.',
                    style: TextStyle(
                      color: EstiloContractual.gris,
                      fontSize: 12.3,
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    '${mods.length} modificaci${mods.length == 1 ? 'ón' : 'ones'} aprobada${mods.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: EstiloContractual.navy,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  for (final m in mods.take(6))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          fechaVerif(m.fechaIso),
                          if (m.diasExtendidos > 0)
                            'prórroga de ${m.diasExtendidos} días',
                          if (m.valorCop > 0)
                            'valor registrado ${copVerif(m.valorCop)}',
                          if (m.proposito.isNotEmpty)
                            TextoProfesional.oracion(
                              m.proposito.replaceAll(RegExp(r'\s+'), ' '),
                            ),
                        ].where((t) => t.isNotEmpty).join(' · '),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: EstiloContractual.texto,
                          fontSize: 12.3,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Comparacion extends StatelessWidget {
  const _Comparacion({required this.filas});

  final List<(String, String, String)> filas;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (k, plan, real) in filas)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    k,
                    style: const TextStyle(
                      color: EstiloContractual.gris,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (plan.isNotEmpty)
                          TextSpan(
                            text: 'Planeado: $plan · real: ',
                            style: const TextStyle(
                              color: EstiloContractual.gris,
                            ),
                          ),
                        TextSpan(
                          text: real,
                          style: const TextStyle(
                            color: EstiloContractual.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12.8, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Caja extends StatelessWidget {
  const _Caja({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
