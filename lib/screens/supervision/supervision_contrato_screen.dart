import 'package:flutter/material.dart';

import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';
import 'editar_plan_screen.dart';
import 'revision_supervisor_screen.dart';

/// Supervisión de un contrato: plan, avance del pago y los informes por
/// periodo con su estado.
class SupervisionContratoScreen extends StatefulWidget {
  const SupervisionContratoScreen({super.key, required this.expediente});

  final ExpedienteContratoPs expediente;

  @override
  State<SupervisionContratoScreen> createState() =>
      _SupervisionContratoScreenState();
}

class _SupervisionContratoScreenState extends State<SupervisionContratoScreen> {
  ExpedienteContratoPs get _exp => widget.expediente;
  late final Stream<PlanSupervision?> _plan = SupervisionService.escucharPlan(
    _exp.tokenInvitado,
  );
  late final Stream<Map<String, InformePeriodo>> _informes =
      SupervisionService.escucharInformes(_exp.tokenInvitado);

  void _editar(PlanSupervision? plan) => Navigator.push(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => EditarPlanScreen(expediente: _exp, plan: plan),
    ),
  );

  void _abrir(String id) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => RevisionSupervisorScreen(expediente: _exp, informeId: id),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlanSupervision?>(
      stream: _plan,
      builder: (context, planSnap) => StreamBuilder<Map<String, InformePeriodo>>(
        stream: _informes,
        builder: (context, infSnap) {
          final plan = planSnap.data;
          final informes = infSnap.data ?? const <String, InformePeriodo>{};
          return PantallaContractual(
            anchoMaximo: 1120,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: PildoraVolver(
                  etiqueta: 'Equipo jurídico',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Supervisión del contrato',
                style: EstiloContractual.titulo,
              ),
              const SizedBox(height: 6),
              Text(
                '${_exp.contratistaNombreEsperado} · Contrato ${_exp.numeroContrato}',
                style: EstiloContractual.subtitulo,
              ),
              const SizedBox(height: 20),
              if (planSnap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (planSnap.hasError)
                const TarjetaSupervision(
                  titulo: 'No fue posible cargar la supervisión',
                  children: [
                    Text(
                      'Revisa tu conexión o que las reglas de Firestore estén publicadas.',
                    ),
                  ],
                )
              else if (plan == null)
                _sinPlan()
              else ...[
                _resumen(plan, informes),
                const SizedBox(height: 16),
                _periodos(plan, informes),
              ],
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  Widget _sinPlan() {
    final puede = SupervisionService.puedeConfigurar(_exp);
    return TarjetaSupervision(
      children: [
        const Icon(
          Icons.assignment_turned_in_outlined,
          size: 44,
          color: EstiloContractual.navy,
        ),
        const SizedBox(height: 12),
        const Text(
          'Activa los informes de ejecución de este contrato',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: EstiloContractual.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Define los periodos, el valor, las obligaciones y quién aprueba cada etapa. El contratista diligencia '
          'cada informe desde el mismo enlace del expediente, sin Word ni Excel, y la app arma el informe, la cuenta '
          'de cobro y el informe de supervisión.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: EstiloContractual.texto,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: puede
              ? FilledButton.icon(
                  onPressed: () => _editar(null),
                  style: EstiloContractual.botonPrincipal(),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text(
                    'Configurar supervisión',
                    style: EstiloContractual.etiquetaBoton,
                  ),
                )
              : const Text(
                  'Pídele al titular del equipo que la configure.',
                  style: TextStyle(color: EstiloContractual.gris),
                ),
        ),
      ],
    );
  }

  Widget _resumen(PlanSupervision plan, Map<String, InformePeriodo> informes) {
    int suma(bool Function(InformePeriodo) f) =>
        informes.values.where(f).fold<int>(0, (s, i) => s + i.valorCobradoCop);
    final aprobado = suma(
      (i) =>
          i.estado == EstadoInforme.aprobado ||
          i.estado == EstadoInforme.pagado,
    );
    final pagado = suma((i) => i.estado == EstadoInforme.pagado);
    final total = _exp.valorContratoCop > 0
        ? _exp.valorContratoCop
        : plan.valorPeriodoCop * plan.periodos.length;

    return TarjetaSupervision(
      titulo: 'Plan de supervisión',
      icono: Icons.assignment_ind_outlined,
      accion: SupervisionService.puedeConfigurar(_exp)
          ? TextButton.icon(
              onPressed: () => _editar(plan),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Editar'),
              style: TextButton.styleFrom(
                foregroundColor: EstiloContractual.navy,
              ),
            )
          : null,
      children: [
        Wrap(
          spacing: 28,
          runSpacing: 14,
          children: [
            DatoSupervision(
              'Informes',
              '${plan.periodos.length} ${plan.periodicidad.adjetivo}es',
            ),
            DatoSupervision(
              'Ejecución',
              '${fechaNumerica(plan.fechaInicio)} – ${fechaNumerica(plan.fechaFin)}',
            ),
            DatoSupervision(
              'Valor por periodo',
              formatoCop(plan.valorPeriodoCop),
            ),
            DatoSupervision('Supervisor', plan.supervisorNombre),
            DatoSupervision(
              'Aprueban',
              [
                for (final (i, e) in plan.etapas.indexed)
                  '${i + 1}. ${e.nombre}',
              ].join(' · '),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Avance del pago',
              style: TextStyle(
                color: EstiloContractual.navy,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${formatoCop(aprobado)} de ${formatoCop(total)}',
              style: const TextStyle(
                color: EstiloContractual.texto,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: LayoutBuilder(
              builder: (context, c) {
                double ancho(int v) =>
                    total <= 0 ? 0 : (v / total).clamp(0.0, 1.0) * c.maxWidth;
                return Stack(
                  children: [
                    Container(color: const Color(0xFFF1F5F9)),
                    Container(
                      width: ancho(aprobado),
                      color: const Color(0xFF86EFAC),
                    ),
                    Container(
                      width: ancho(pagado),
                      color: const Color(0xFF0F766E),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 16,
          children: [
            _Leyenda(color: Color(0xFF0F766E), texto: 'Pagado'),
            _Leyenda(
              color: Color(0xFF86EFAC),
              texto: 'Aprobado, pendiente de pago',
            ),
          ],
        ),
      ],
    );
  }

  Widget _periodos(PlanSupervision plan, Map<String, InformePeriodo> informes) {
    final hoy = DateTime.now();
    return TarjetaSupervision(
      titulo: 'Informes por periodo',
      subtitulo: 'Toca un informe enviado para revisarlo. Cada uno vence el último día de su periodo.',
      icono: Icons.calendar_month_rounded,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final columnas = c.maxWidth >= 900
                ? 4
                : (c.maxWidth >= 560 ? 3 : 2);
            final ancho = (c.maxWidth - 10 * (columnas - 1)) / columnas;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final p in plan.periodos)
                  SizedBox(
                    width: ancho,
                    child: _TarjetaPeriodo(
                      periodo: p,
                      informe: informes[p.id],
                      plan: plan,
                      actual:
                          !hoy.isBefore(p.desde) &&
                          !hoy.isAfter(p.hasta.add(const Duration(days: 1))),
                      futuro: p.desde.isAfter(hoy),
                      onTap: (informes[p.id]?.existe ?? false)
                          ? () => _abrir(p.id)
                          : null,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        texto,
        style: const TextStyle(color: EstiloContractual.gris, fontSize: 11.8),
      ),
    ],
  );
}

class _TarjetaPeriodo extends StatelessWidget {
  const _TarjetaPeriodo({
    required this.periodo,
    required this.informe,
    required this.plan,
    required this.actual,
    required this.futuro,
    required this.onTap,
  });

  final PeriodoInforme periodo;
  final InformePeriodo? informe;
  final PlanSupervision plan;
  final bool actual;
  final bool futuro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inf = informe;
    final estado = inf?.estado ?? EstadoInforme.pendiente;
    final etapa =
        inf != null &&
            estado == EstadoInforme.enRevision &&
            inf.etapaActual < plan.etapas.length
        ? plan.etapas[inf.etapaActual].nombre
        : null;
    final vencido =
        !futuro &&
        !(inf?.existe ?? false) &&
        DateTime.now().isAfter(periodo.limite.add(const Duration(days: 1)));
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: actual ? EstiloContractual.navy : const Color(0xFFE2E8F0),
              width: actual ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'N.º ${periodo.numero}',
                    style: const TextStyle(
                      color: EstiloContractual.gris,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (actual)
                    const Text(
                      'EN CURSO',
                      style: TextStyle(
                        color: EstiloContractual.navy,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${fechaLegible(periodo.desde, conDia: false)} – ${fechaLegible(periodo.hasta, conDia: false)}',
                style: TextStyle(
                  color: futuro
                      ? EstiloContractual.gris
                      : EstiloContractual.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (futuro && inf == null)
                const Text(
                  'Próximo',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                )
              else if (vencido)
                const EtiquetaColor(
                  texto: 'Vencido sin enviar',
                  color: Color(0xFFB91C1C),
                  fondo: Color(0xFFFEE2E2),
                )
              else
                ChipEstadoInforme(estado),
              if (etapa != null) ...[
                const SizedBox(height: 4),
                Text(
                  etapa,
                  style: const TextStyle(
                    color: EstiloContractual.texto,
                    fontSize: 11.8,
                  ),
                ),
              ],
              if (inf != null && inf.valorCobradoCop > 0 && inf.existe) ...[
                const SizedBox(height: 4),
                Text(
                  formatoCop(inf.valorCobradoCop),
                  style: const TextStyle(
                    color: EstiloContractual.texto,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
