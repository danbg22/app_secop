import 'package:flutter/material.dart';

import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';
import 'informe_contratista_screen.dart';

/// Informes de ejecución en el portal del contratista. Solo aparece cuando el
/// equipo configuró la supervisión del contrato.
class InformesContratistaView extends StatefulWidget {
  const InformesContratistaView({
    super.key,
    required this.expediente,
    required this.contratistaNombre,
  });

  final ExpedienteContratoPs expediente;
  final String contratistaNombre;

  @override
  State<InformesContratistaView> createState() =>
      _InformesContratistaViewState();
}

class _InformesContratistaViewState extends State<InformesContratistaView> {
  String get _token => widget.expediente.tokenInvitado;
  late final Stream<PlanSupervision?> _plan = SupervisionService.escucharPlan(
    _token,
  );
  late final Stream<Map<String, InformePeriodo>> _informes =
      SupervisionService.escucharInformes(_token);
  bool _verTodos = false;

  void _abrir(
    PlanSupervision plan,
    PeriodoInforme p,
    Map<String, InformePeriodo> todos,
  ) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => InformeContratistaScreen(
        expediente: widget.expediente,
        plan: plan,
        periodo: p,
        todos: todos,
        contratistaNombre: widget.contratistaNombre,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlanSupervision?>(
      stream: _plan,
      builder: (context, planSnap) {
        final plan = planSnap.data;
        if (plan == null) return const SizedBox.shrink();
        return StreamBuilder<Map<String, InformePeriodo>>(
          stream: _informes,
          builder: (context, snap) {
            final todos = snap.data ?? const <String, InformePeriodo>{};
            final hoy = DateTime.now();
            final abiertos = plan.periodos
                .where((p) => !p.desde.isAfter(hoy))
                .toList();
            final devueltos = todos.values
                .where((i) => i.estado == EstadoInforme.devuelto)
                .length;
            // Lo urgente primero: devueltos y pendientes del más antiguo al más reciente.
            final pendientes = abiertos
                .where(
                  (p) => (todos[p.id]?.estado ?? EstadoInforme.pendiente)
                      .editablePorContratista,
                )
                .toList();
            final proximo = pendientes.isEmpty ? null : pendientes.first;
            final lista = _verTodos
                ? plan.periodos
                : abiertos.reversed.take(4).toList();

            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: TarjetaSupervision(
                titulo: 'Informes de ejecución',
                subtitulo:
                    '${plan.periodicidad.etiqueta} · supervisor ${plan.supervisorNombre}. Reporta tus actividades, '
                    'tu planilla y tus documentos; la app arma el informe y la cuenta de cobro.',
                icono: Icons.event_note_rounded,
                colorBorde: devueltos > 0 ? const Color(0xFFFCD34D) : null,
                children: [
                  if (proximo != null) ...[
                    _Proximo(
                      periodo: proximo,
                      informe: todos[proximo.id],
                      plan: plan,
                      onAbrir: () => _abrir(plan, proximo, todos),
                    ),
                    const SizedBox(height: 14),
                  ] else if (abiertos.isEmpty)
                    Text(
                      'Tu primer informe se habilita el ${fechaLegible(plan.periodos.first.desde)}.',
                      style: const TextStyle(color: EstiloContractual.texto),
                    ),
                  for (final p in lista)
                    _FilaPeriodo(
                      periodo: p,
                      informe: todos[p.id],
                      futuro: p.desde.isAfter(hoy),
                      onAbrir: p.desde.isAfter(hoy)
                          ? null
                          : () => _abrir(plan, p, todos),
                    ),
                  if (plan.periodos.length > lista.length || _verTodos)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _verTodos = !_verTodos),
                        style: TextButton.styleFrom(
                          foregroundColor: EstiloContractual.navy,
                        ),
                        child: Text(
                          _verTodos
                              ? 'Ver menos'
                              : 'Ver los ${plan.periodos.length} periodos del contrato',
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Proximo extends StatelessWidget {
  const _Proximo({
    required this.periodo,
    required this.informe,
    required this.plan,
    required this.onAbrir,
  });
  final PeriodoInforme periodo;
  final InformePeriodo? informe;
  final PlanSupervision plan;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final devuelto = informe?.estado == EstadoInforme.devuelto;
    final iniciado = informe?.existe ?? false;
    final faltan = informe?.faltantes(plan).length;
    final vencido = DateTime.now().isAfter(
      periodo.limite.add(const Duration(days: 1)),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: devuelto ? const Color(0xFFFFFBEB) : const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: devuelto ? const Color(0xFFFCD34D) : const Color(0xFFDCE4EF),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                devuelto
                    ? 'Corrige tu informe N.º ${periodo.numero}'
                    : (iniciado
                          ? 'Termina tu informe N.º ${periodo.numero}'
                          : 'Diligencia tu informe N.º ${periodo.numero}'),
                style: TextStyle(
                  color: devuelto
                      ? const Color(0xFF92400E)
                      : EstiloContractual.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${fechaLegible(periodo.desde, conDia: false)} – ${fechaLegible(periodo.hasta, conDia: false)} · '
                '${vencido ? 'venció el' : 'vence el'} ${fechaLegible(periodo.limite)}'
                '${iniciado && faltan != null && faltan > 0 ? ' · te faltan $faltan' : ''}',
                style: TextStyle(
                  color: vencido
                      ? const Color(0xFFB91C1C)
                      : EstiloContractual.texto,
                  fontSize: 13,
                ),
              ),
              if (devuelto && informe!.devolucion != null) ...[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    informe!.devolucion!.observacion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
          FilledButton.icon(
            onPressed: onAbrir,
            style: EstiloContractual.botonPrincipal(),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              devuelto ? 'Corregir' : (iniciado ? 'Continuar' : 'Empezar'),
              style: EstiloContractual.etiquetaBoton,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaPeriodo extends StatelessWidget {
  const _FilaPeriodo({
    required this.periodo,
    required this.informe,
    required this.futuro,
    required this.onAbrir,
  });
  final PeriodoInforme periodo;
  final InformePeriodo? informe;
  final bool futuro;
  final VoidCallback? onAbrir;

  @override
  Widget build(BuildContext context) {
    final estado = informe?.estado ?? EstadoInforme.pendiente;
    return InkWell(
      onTap: onAbrir,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                'N.º ${periodo.numero}',
                style: const TextStyle(
                  color: EstiloContractual.gris,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${fechaLegible(periodo.desde, conDia: false)} – ${fechaLegible(periodo.hasta, conDia: false)}',
                style: TextStyle(
                  color: futuro
                      ? EstiloContractual.gris
                      : EstiloContractual.navy,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (futuro)
              const Text(
                'Próximo',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              )
            else
              ChipEstadoInforme(estado),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: futuro ? Colors.transparent : EstiloContractual.gris,
            ),
          ],
        ),
      ),
    );
  }
}
