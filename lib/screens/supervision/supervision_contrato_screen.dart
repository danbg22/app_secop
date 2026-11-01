import 'package:flutter/material.dart';

import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';
import 'editar_plan_screen.dart';
import 'revision_informe_screen.dart';

/// Supervisión de un contrato: plan, avance del pago y los meses del
/// contrato con el estado de cada informe.
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
  late final Stream<Map<String, InformeMensual>> _informes =
      SupervisionService.escucharInformes(_exp.tokenInvitado);

  void _editar(PlanSupervision? plan) => Navigator.push(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => EditarPlanScreen(expediente: _exp, plan: plan),
    ),
  );

  void _abrirInforme(String periodo) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => RevisionInformeScreen(expediente: _exp, periodo: periodo),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlanSupervision?>(
      stream: _plan,
      builder: (context, planSnap) => StreamBuilder<Map<String, InformeMensual>>(
        stream: _informes,
        builder: (context, infSnap) {
          final cargando = planSnap.connectionState == ConnectionState.waiting;
          final plan = planSnap.data;
          final informes = infSnap.data ?? const <String, InformeMensual>{};
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
              if (cargando)
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
                _meses(plan, informes),
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
          'Activa la supervisión mensual de este contrato',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: EstiloContractual.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Define el supervisor, los honorarios y las obligaciones. Cada mes el contratista envía su '
          'informe desde el mismo enlace del expediente; un abogado revisa los documentos y la planilla, '
          'y el supervisor aprueba y descarga el certificado de cumplimiento.',
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

  Widget _resumen(PlanSupervision plan, Map<String, InformeMensual> informes) {
    final aprobado = informes.values
        .where(
          (i) =>
              i.estado == EstadoInforme.aprobado ||
              i.estado == EstadoInforme.pagado,
        )
        .fold<int>(0, (s, i) => s + i.valorCobradoCop);
    final pagado = informes.values
        .where((i) => i.estado == EstadoInforme.pagado)
        .fold<int>(0, (s, i) => s + i.valorCobradoCop);
    final total = _exp.valorContratoCop > 0
        ? _exp.valorContratoCop
        : plan.valorMensualCop * plan.periodos.length;
    final aporte = AporteEsperado.calcular(
      valorMensualCop: plan.valorMensualCop,
      claseRiesgo: plan.claseRiesgo,
      anio: plan.fechaInicio.year,
    );
    String f(DateTime d) => '${d.day}/${d.month}/${d.year}';

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
            DatoSupervision('Supervisor', plan.supervisorNombre),
            DatoSupervision(
              'Ejecución',
              '${f(plan.fechaInicio)} – ${f(plan.fechaFin)}',
            ),
            DatoSupervision(
              'Honorarios mensuales',
              formatoCop(plan.valorMensualCop),
            ),
            DatoSupervision(
              'Aporte mínimo mensual',
              formatoCop(aporte.totalContratista),
            ),
            DatoSupervision('Obligaciones', '${plan.obligaciones.length}'),
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
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: EstiloContractual.gris),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El contratista envía sus informes desde el mismo enlace del expediente.',
                  style: TextStyle(
                    color: EstiloContractual.texto,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _meses(PlanSupervision plan, Map<String, InformeMensual> informes) {
    final actual = periodoDe(DateTime.now());
    return TarjetaSupervision(
      titulo: 'Informes mensuales',
      subtitulo: 'Toca un mes para ver el informe y revisarlo.',
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
                for (final (i, periodo) in plan.periodos.indexed)
                  SizedBox(
                    width: ancho,
                    child: _TarjetaMes(
                      numero: i + 1,
                      periodo: periodo,
                      informe: informes[periodo],
                      actual: periodo == actual,
                      futuro: periodo.compareTo(actual) > 0,
                      onTap: informes[periodo] == null
                          ? null
                          : () => _abrirInforme(periodo),
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

class _TarjetaMes extends StatelessWidget {
  const _TarjetaMes({
    required this.numero,
    required this.periodo,
    required this.informe,
    required this.actual,
    required this.futuro,
    required this.onTap,
  });

  final int numero;
  final String periodo;
  final InformeMensual? informe;
  final bool actual;
  final bool futuro;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final estado = informe?.estado ?? EstadoInforme.pendiente;
    final mes = nombrePeriodo(periodo);
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
                    'Mes $numero',
                    style: const TextStyle(
                      color: EstiloContractual.gris,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (actual)
                    const Text(
                      'ACTUAL',
                      style: TextStyle(
                        color: EstiloContractual.navy,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                mes[0].toUpperCase() + mes.substring(1),
                style: TextStyle(
                  color: futuro
                      ? EstiloContractual.gris
                      : EstiloContractual.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              futuro && informe == null
                  ? const Text(
                      'Próximo',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    )
                  : ChipEstadoInforme(estado),
              if (informe != null && informe!.valorCobradoCop > 0) ...[
                const SizedBox(height: 6),
                Text(
                  formatoCop(informe!.valorCobradoCop),
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
