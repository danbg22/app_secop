import 'package:flutter/material.dart';

import '../../services/certificado_supervision.dart';
import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';

/// Revisión de un informe mensual: a la izquierda lo que reportó el
/// contratista y a la derecha lo que le toca hacer al usuario según el paso
/// (revisión documental, aprobación del supervisor o registro del pago).
class RevisionInformeScreen extends StatefulWidget {
  const RevisionInformeScreen({
    super.key,
    required this.expediente,
    required this.periodo,
  });

  final ExpedienteContratoPs expediente;
  final String periodo;

  @override
  State<RevisionInformeScreen> createState() => _RevisionInformeScreenState();
}

class _RevisionInformeScreenState extends State<RevisionInformeScreen> {
  String get _token => widget.expediente.tokenInvitado;
  late final Stream<PlanSupervision?> _plan = SupervisionService.escucharPlan(
    _token,
  );
  late final Stream<Map<String, InformeMensual>> _informes =
      SupervisionService.escucharInformes(_token);

  final Map<PuntoRevision, bool> _cumple = {};
  final Map<PuntoRevision, TextEditingController> _obs = {
    for (final p in PuntoRevision.values) p: TextEditingController(),
  };
  final _concepto = TextEditingController();
  final _referenciaPago = TextEditingController();
  String _revisionCargada = '';
  bool _ocupado = false;

  @override
  void dispose() {
    for (final c in [..._obs.values, _concepto, _referenciaPago]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Prepara el formulario de revisión: la planilla arranca según la
  /// verificación automática y los demás puntos como "cumple".
  void _prepararRevision(InformeMensual inf, List<HallazgoPlanilla> hallazgos) {
    final clave = '${inf.periodo}|${inf.enviadoEnIso}';
    if (_revisionCargada == clave) return;
    _revisionCargada = clave;
    final planillaOk = hallazgos.every((h) => h.cumple);
    for (final p in PuntoRevision.values) {
      _cumple[p] = p == PuntoRevision.planilla ? planillaOk : true;
      _obs[p]!.text = p == PuntoRevision.planilla && !planillaOk
          ? hallazgos.where((h) => !h.cumple).map((h) => h.texto).join(' ')
          : '';
    }
  }

  Future<void> _accion(Future<void> Function() f, String exito) async {
    setState(() => _ocupado = true);
    try {
      await f();
      if (mounted) mensajeSupervision(context, exito);
    } on SupervisionException catch (e) {
      if (mounted) mensajeSupervision(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrir(InformeMensual inf, DocumentoInformeTipo tipo) async {
    final ok = await SupervisionService.abrirDocumento(_token, inf, tipo);
    if (!ok && mounted) {
      mensajeSupervision(
        context,
        'No fue posible abrir el documento.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlanSupervision?>(
      stream: _plan,
      builder: (context, planSnap) =>
          StreamBuilder<Map<String, InformeMensual>>(
            stream: _informes,
            builder: (context, infSnap) {
              final plan = planSnap.data;
              final todos = infSnap.data ?? const <String, InformeMensual>{};
              final inf = todos[widget.periodo];
              if (plan == null || inf == null) {
                return PantallaContractual(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PildoraVolver(
                        etiqueta: 'Volver',
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 60),
                    Center(
                      child: planSnap.hasError || infSnap.hasError
                          ? const Text('No fue posible cargar el informe.')
                          : (infSnap.hasData && inf == null)
                          ? const Text(
                              'El contratista aún no ha iniciado este informe.',
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ],
                );
              }
              return _contenido(plan, inf, todos);
            },
          ),
    );
  }

  Widget _contenido(
    PlanSupervision plan,
    InformeMensual inf,
    Map<String, InformeMensual> todos,
  ) {
    final exp = widget.expediente;
    final anio =
        int.tryParse(inf.periodo.split('-').first) ?? DateTime.now().year;
    final aporte = AporteEsperado.calcular(
      valorMensualCop: inf.valorCobradoCop,
      claseRiesgo: plan.claseRiesgo,
      anio: anio,
    );
    final hallazgos = inf.planilla.verificar(aporte, inf.periodo);
    if (inf.estado == EstadoInforme.enviado) _prepararRevision(inf, hallazgos);
    final mobile = MediaQuery.sizeOf(context).width < 980;

    final izquierda = <Widget>[
      _reporte(plan, inf),
      const SizedBox(height: 16),
      _documentos(inf),
      const SizedBox(height: 16),
      _planilla(inf, aporte, hallazgos),
    ];
    final derecha = <Widget>[
      _panelAccion(plan, inf, todos, hallazgos),
      const SizedBox(height: 16),
      TarjetaSupervision(
        titulo: 'Historial',
        icono: Icons.history_rounded,
        children: [
          HistorialInforme(
            eventos: inf.historial,
            formatoFecha: JuridicoContratacionService.formatearFechaHumana,
          ),
        ],
      ),
    ];

    return PantallaContractual(
      anchoMaximo: 1240,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Volver',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: EdgeInsets.all(mobile ? 16 : 22),
          decoration: EstiloContractual.tarjeta(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Informe de ${nombrePeriodo(inf.periodo)}',
                    style: EstiloContractual.titulo.copyWith(
                      fontSize: mobile ? 22 : 26,
                    ),
                  ),
                  ChipEstadoInforme(inf.estado),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${exp.contratistaNombreEsperado} · Contrato ${exp.numeroContrato} · Supervisor: ${plan.supervisorNombre}',
                style: EstiloContractual.subtitulo,
              ),
              const SizedBox(height: 18),
              LineaPasosInforme(estado: inf.estado),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (mobile) ...[
          ...izquierda,
          const SizedBox(height: 16),
          ...derecha,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: izquierda,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: derecha,
                ),
              ),
            ],
          ),
        const SizedBox(height: 30),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Lo que reportó el contratista
  // ---------------------------------------------------------------------------

  Widget _reporte(PlanSupervision plan, InformeMensual inf) {
    final observacion = inf.revision[PuntoRevision.actividades.name];
    return TarjetaSupervision(
      titulo: 'Actividades del periodo',
      subtitulo:
          'Lo que el contratista reporta haber hecho frente a cada obligación.',
      icono: Icons.checklist_rounded,
      accion: DatoSupervision('Valor cobrado', formatoCop(inf.valorCobradoCop)),
      children: [
        if (observacion != null &&
            !observacion.cumple &&
            inf.estado == EstadoInforme.devuelto)
          _avisoDevuelto(observacion.observacion),
        for (final (i, o) in plan.obligaciones.indexed) ...[
          Text(
            '${i + 1}. ${o.texto}',
            style: const TextStyle(
              color: EstiloContractual.navy,
              fontSize: 13.4,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              (inf.actividades[o.id] ?? '').trim().isEmpty
                  ? 'Sin actividades reportadas.'
                  : inf.actividades[o.id]!.trim(),
              style: TextStyle(
                color: (inf.actividades[o.id] ?? '').trim().isEmpty
                    ? const Color(0xFFB91C1C)
                    : EstiloContractual.texto,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _avisoDevuelto(String texto) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFCD34D)),
    ),
    child: Text(
      'Observación: $texto',
      style: const TextStyle(
        color: Color(0xFF92400E),
        fontSize: 12.8,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _documentos(InformeMensual inf) {
    return TarjetaSupervision(
      titulo: 'Documentos adjuntos',
      icono: Icons.attach_file_rounded,
      children: [
        for (final t in DocumentoInformeTipo.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  inf.documentos.containsKey(t.name)
                      ? Icons.description_rounded
                      : Icons.do_not_disturb_on_outlined,
                  color: inf.documentos.containsKey(t.name)
                      ? const Color(0xFF1D4ED8)
                      : (t.obligatorio
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFCBD5E1)),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.etiqueta,
                        style: const TextStyle(
                          color: EstiloContractual.navy,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        inf.documentos[t.name]?.nombre ??
                            (t.obligatorio
                                ? 'No adjuntó este documento'
                                : 'No adjuntó'),
                        style: const TextStyle(
                          color: EstiloContractual.gris,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (inf.documentos.containsKey(t.name))
                  OutlinedButton.icon(
                    onPressed: () => _abrir(inf, t),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Abrir'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EstiloContractual.navy,
                      shape: const StadiumBorder(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _planilla(
    InformeMensual inf,
    AporteEsperado aporte,
    List<HallazgoPlanilla> hallazgos,
  ) {
    final p = inf.planilla;
    final cumple = hallazgos.every((h) => h.cumple);
    return TarjetaSupervision(
      titulo: 'Seguridad social',
      subtitulo:
          'Verificación automática de la planilla frente al mínimo legal.',
      icono: Icons.health_and_safety_outlined,
      colorBorde: cumple ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
      accion: EtiquetaColor(
        texto: cumple ? 'Cumple' : 'Revisar',
        color: cumple ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
        fondo: cumple ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
      ),
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 10,
          children: [
            DatoSupervision('Planilla', p.numero.isEmpty ? '—' : p.numero),
            DatoSupervision('IBC', formatoCop(p.ibcCop)),
            DatoSupervision(
              'Total pagado',
              formatoCop(p.saludCop + p.pensionCop + p.arlCop),
            ),
            DatoSupervision(
              'Mínimo esperado',
              formatoCop(aporte.totalContratista),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListaHallazgos(hallazgos: hallazgos),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Panel de acción según el paso
  // ---------------------------------------------------------------------------

  Widget _panelAccion(
    PlanSupervision plan,
    InformeMensual inf,
    Map<String, InformeMensual> todos,
    List<HallazgoPlanilla> hallazgos,
  ) {
    final exp = widget.expediente;
    switch (inf.estado) {
      case EstadoInforme.enviado:
        if (!SupervisionService.puedeRevisar(exp)) {
          return _espera(
            'Pendiente de revisión documental',
            'Un abogado con permiso de verificación debe revisar los documentos.',
          );
        }
        return _formularioRevision(inf);
      case EstadoInforme.revisado:
        if (!SupervisionService.puedeAprobar(exp, plan)) {
          return _espera(
            'Esperando al supervisor',
            '${plan.supervisorNombre} debe aprobar el informe y certificar el cumplimiento.',
          );
        }
        return _formularioAprobacion(plan, inf);
      case EstadoInforme.aprobado:
        return _aprobado(
          plan,
          inf,
          todos,
          puedePagar: SupervisionService.puedeRevisar(exp),
        );
      case EstadoInforme.pagado:
        return _aprobado(plan, inf, todos, puedePagar: false);
      case EstadoInforme.devuelto:
        return _espera(
          'Devuelto al contratista',
          'El contratista debe corregir y reenviar:\n${inf.revision.entries.where((e) => !e.value.cumple).map((e) => '• ${PuntoRevision.values.firstWhere((p) => p.name == e.key, orElse: () => PuntoRevision.actividades).etiqueta}: ${e.value.observacion}').join('\n')}',
          color: const Color(0xFFB45309),
        );
      case EstadoInforme.pendiente:
      case EstadoInforme.borrador:
        return _espera(
          'En elaboración',
          'El contratista aún no ha enviado este informe.',
        );
    }
  }

  Widget _espera(String titulo, String texto, {Color? color}) =>
      TarjetaSupervision(
        titulo: titulo,
        icono: Icons.hourglass_top_rounded,
        children: [
          Text(
            texto,
            style: TextStyle(
              color: color ?? EstiloContractual.texto,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      );

  Widget _formularioRevision(InformeMensual inf) {
    final devuelve = _cumple.values.any((c) => !c);
    return TarjetaSupervision(
      titulo: 'Revisión documental',
      subtitulo: 'Marca cada punto. Si algo no cumple, escribe qué debe corregir el contratista.',
      icono: Icons.fact_check_outlined,
      colorBorde: const Color(0xFFBFDBFE),
      children: [
        for (final p in PuntoRevision.values) ...[
          Text(
            p.etiqueta,
            style: const TextStyle(
              color: EstiloContractual.navy,
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Cumple'),
                icon: Icon(Icons.check_rounded, size: 16),
              ),
              ButtonSegment(
                value: false,
                label: Text('Devolver'),
                icon: Icon(Icons.undo_rounded, size: 16),
              ),
            ],
            selected: {_cumple[p] ?? true},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _cumple[p] = v.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: (_cumple[p] ?? true)
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEF3C7),
              selectedForegroundColor: (_cumple[p] ?? true)
                  ? const Color(0xFF166534)
                  : const Color(0xFF92400E),
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (_cumple[p] == false) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _obs[p],
              maxLines: 3,
              minLines: 1,
              decoration: decoracionCampo('¿Qué debe corregir?'),
            ),
          ],
          const SizedBox(height: 14),
        ],
        FilledButton.icon(
          onPressed: _ocupado
              ? null
              : () => _accion(
                  () => SupervisionService.registrarRevision(
                    widget.expediente,
                    inf,
                    {
                      for (final p in PuntoRevision.values)
                        p: RevisionPunto(
                          cumple: _cumple[p] ?? true,
                          observacion: _obs[p]!.text,
                        ),
                    },
                  ),
                  devuelve
                      ? 'Informe devuelto al contratista.'
                      : 'Revisión registrada. Pasa al supervisor.',
                ),
          style: EstiloContractual.botonPrincipal().copyWith(
            backgroundColor: WidgetStatePropertyAll(
              devuelve ? const Color(0xFFB45309) : EstiloContractual.navy,
            ),
          ),
          icon: Icon(
            devuelve ? Icons.undo_rounded : Icons.send_rounded,
            size: 18,
          ),
          label: Text(
            devuelve ? 'Devolver al contratista' : 'Enviar al supervisor',
            style: EstiloContractual.etiquetaBoton,
          ),
        ),
      ],
    );
  }

  Widget _formularioAprobacion(PlanSupervision plan, InformeMensual inf) {
    return TarjetaSupervision(
      titulo: 'Aprobación del supervisor',
      subtitulo:
          'Revisión documental hecha por ${inf.revisorNombre}. '
          'Verifica que las actividades cumplan las obligaciones y certifica el cumplimiento.',
      icono: Icons.verified_user_outlined,
      colorBorde: const Color(0xFFDDD6FE),
      children: [
        TextField(
          controller: _concepto,
          maxLines: 4,
          minLines: 2,
          decoration: decoracionCampo(
            'Concepto del supervisor',
            ayuda: 'Va en el certificado. Si lo dejas vacío: "cumplió a satisfacción las obligaciones del periodo".',
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _ocupado
              ? null
              : () => _accion(
                  () => SupervisionService.aprobar(
                    widget.expediente,
                    plan,
                    inf,
                    concepto: _concepto.text,
                  ),
                  'Informe aprobado. Ya puedes descargar el certificado.',
                ),
          style: EstiloContractual.botonPrincipal().copyWith(
            backgroundColor: const WidgetStatePropertyAll(Color(0xFF15803D)),
          ),
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: const Text(
            'Aprobar y certificar cumplimiento',
            style: EstiloContractual.etiquetaBoton,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _ocupado ? null : () => _devolverSupervisor(plan, inf),
          style: EstiloContractual.botonSecundario(),
          icon: const Icon(Icons.undo_rounded, size: 18),
          label: const Text(
            'Devolver al contratista',
            style: EstiloContractual.etiquetaBoton,
          ),
        ),
      ],
    );
  }

  Future<void> _devolverSupervisor(
    PlanSupervision plan,
    InformeMensual inf,
  ) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Devolver al contratista'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: c,
            maxLines: 4,
            decoration: decoracionCampo('¿Qué debe corregir?'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
            ),
            child: const Text('Devolver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _accion(
      () => SupervisionService.devolverDesdeSupervisor(
        widget.expediente,
        plan,
        inf,
        motivo: c.text,
      ),
      'Informe devuelto al contratista.',
    );
  }

  Widget _aprobado(
    PlanSupervision plan,
    InformeMensual inf,
    Map<String, InformeMensual> todos, {
    required bool puedePagar,
  }) {
    final pagado = inf.estado == EstadoInforme.pagado;
    return TarjetaSupervision(
      titulo: pagado ? 'Pago registrado' : 'Aprobado para pago',
      subtitulo: pagado
          ? 'Referencia: ${inf.pagoReferencia.isEmpty ? '—' : inf.pagoReferencia} · ${JuridicoContratacionService.formatearFechaHumana(inf.pagadoEnIso)}'
          : 'Aprobado por ${inf.supervisorNombre} · ${JuridicoContratacionService.formatearFechaHumana(inf.aprobadoEnIso)}',
      icono: pagado ? Icons.payments_rounded : Icons.verified_rounded,
      colorBorde: const Color(0xFFBBF7D0),
      children: [
        FilledButton.icon(
          onPressed: () => CertificadoSupervision.descargar(
            expediente: widget.expediente,
            plan: plan,
            informe: inf,
            todos: todos,
          ),
          style: EstiloContractual.botonPrincipal(),
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text(
            'Descargar certificado de cumplimiento',
            style: EstiloContractual.etiquetaBoton,
          ),
        ),
        if (puedePagar) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          TextField(
            controller: _referenciaPago,
            decoration: decoracionCampo(
              'Referencia del pago (opcional)',
              ayuda: 'Número de orden de pago u obligación en el sistema financiero.',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _ocupado
                ? null
                : () => _accion(
                    () => SupervisionService.registrarPago(
                      widget.expediente,
                      inf,
                      referencia: _referenciaPago.text,
                    ),
                    'Pago registrado.',
                  ),
            style: EstiloContractual.botonSecundario(),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text(
              'Registrar pago',
              style: EstiloContractual.etiquetaBoton,
            ),
          ),
        ],
      ],
    );
  }
}
