import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/informe_pdf_service.dart';
import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';

/// Revisión de un informe: a la izquierda el informe como documento y sus
/// soportes; a la derecha el recorrido por etapas, la verificación
/// automática y la decisión de quien tiene la etapa en curso.
class RevisionSupervisorScreen extends StatefulWidget {
  const RevisionSupervisorScreen({
    super.key,
    required this.expediente,
    required this.informeId,
  });

  final ExpedienteContratoPs expediente;
  final String informeId;

  @override
  State<RevisionSupervisorScreen> createState() =>
      _RevisionSupervisorScreenState();
}

class _RevisionSupervisorScreenState extends State<RevisionSupervisorScreen> {
  ExpedienteContratoPs get _exp => widget.expediente;
  String get _token => _exp.tokenInvitado;
  late final Stream<PlanSupervision?> _plan = SupervisionService.escucharPlan(
    _token,
  );
  late final Stream<Map<String, InformePeriodo>> _informes =
      SupervisionService.escucharInformes(_token);
  late final Stream<Uint8List?> _firmaStream = SupervisionService.escucharFirma(
    _token,
  );

  final _concepto = TextEditingController();
  final _observacion = TextEditingController();
  final _referencia = TextEditingController();
  final Set<String> _items = {};
  final Set<int> _checks = {};
  bool _ocupado = false;
  String? _generando;

  static const _checklist = [
    'Las actividades corresponden a las obligaciones del contrato',
    'Las actividades están bien descritas y los soportes las respaldan',
    'El periodo, los aportes y los documentos son correctos',
  ];

  @override
  void dispose() {
    for (final c in [_concepto, _observacion, _referencia]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _accion(Future<void> Function() f, String exito) async {
    setState(() => _ocupado = true);
    try {
      await f();
      if (!mounted) return;
      mensajeSupervision(context, exito);
      setState(() {
        _items.clear();
        _checks.clear();
        _observacion.clear();
        _concepto.clear();
      });
    } on SupervisionException catch (e) {
      if (mounted) mensajeSupervision(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _pdf(String clave, Future<Uint8List?> Function() generar) async {
    setState(() => _generando = clave);
    try {
      final bytes = await generar();
      if (bytes != null) InformePdfService.abrir(bytes);
    } catch (e) {
      if (mounted) {
        mensajeSupervision(
          context,
          'No fue posible generar el PDF: $e',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _generando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlanSupervision?>(
      stream: _plan,
      builder: (context, planSnap) =>
          StreamBuilder<Map<String, InformePeriodo>>(
            stream: _informes,
            builder: (context, infSnap) => StreamBuilder<Uint8List?>(
              stream: _firmaStream,
              builder: (context, firmaSnap) {
                final plan = planSnap.data;
                final todos = infSnap.data ?? const <String, InformePeriodo>{};
                final inf = todos[widget.informeId];
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
                            : const CircularProgressIndicator(),
                      ),
                    ],
                  );
                }
                return _contenido(plan, inf, todos, firmaSnap.data);
              },
            ),
          ),
    );
  }

  Widget _contenido(
    PlanSupervision plan,
    InformePeriodo inf,
    Map<String, InformePeriodo> todos,
    Uint8List? firma,
  ) {
    final mobile = MediaQuery.sizeOf(context).width < 1000;
    final retraso = inf.diasRetraso;
    final izquierda = <Widget>[
      _Hoja(expediente: _exp, plan: plan, informe: inf),
      const SizedBox(height: 16),
      _soportes(plan, inf, todos, firma),
    ];
    final derecha = <Widget>[
      TarjetaSupervision(
        titulo: 'Recorrido del informe',
        icono: Icons.alt_route_rounded,
        children: [RielEtapas(plan: plan, informe: inf, vertical: true)],
      ),
      const SizedBox(height: 14),
      TarjetaSupervision(
        titulo: 'Verificación automática',
        subtitulo: 'La app revisa estos puntos; la decisión es de quien tiene la etapa.',
        icono: Icons.rule_rounded,
        children: [ListaVerificaciones(verificaciones: inf.verificar(plan))],
      ),
      const SizedBox(height: 14),
      _decision(plan, inf, todos, firma),
      const SizedBox(height: 14),
      TarjetaSupervision(
        titulo: 'Trazabilidad (${inf.historial.length})',
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
      anchoMaximo: 1320,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Volver',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(mobile ? 16 : 22),
          decoration: EstiloContractual.tarjeta(),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_exp.contratistaNombreEsperado} · Informe ${plan.periodicidad.adjetivo} N.º ${inf.numero}',
                    style: EstiloContractual.titulo.copyWith(
                      fontSize: mobile ? 20 : 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contrato ${_exp.numeroContrato} · ${fechaLegible(inf.desde, conDia: false)} – '
                    '${fechaLegible(inf.hasta, conDia: false)} · ${formatoCop(inf.valorCobradoCop)}',
                    style: EstiloContractual.subtitulo,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (retraso > 0)
                    EtiquetaColor(
                      texto: 'Con retraso · $retraso d',
                      color: const Color(0xFFB45309),
                      fondo: const Color(0xFFFEF3C7),
                      icono: Icons.schedule_rounded,
                    ),
                  ChipEstadoInforme(inf.estado),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (mobile) ...[
          // En el celular se lee el informe antes de decidir: recorrido y
          // verificación, luego el informe, y al final la decisión.
          ...derecha.take(4),
          ...izquierda,
          const SizedBox(height: 14),
          ...derecha.skip(4),
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
  // Soportes y documentos
  // ---------------------------------------------------------------------------

  Widget _soportes(
    PlanSupervision plan,
    InformePeriodo inf,
    Map<String, InformePeriodo> todos,
    Uint8List? firma,
  ) {
    final docs = inf.documentosDelPeriodo(plan);
    Widget boton(
      String clave,
      String texto,
      IconData icono,
      Future<Uint8List?> Function() f,
    ) => OutlinedButton.icon(
      onPressed: _generando != null ? null : () => _pdf(clave, f),
      style: EstiloContractual.botonSecundario(),
      icon: _generando == clave
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icono, size: 18),
      label: Text(texto, style: EstiloContractual.etiquetaBoton),
    );
    return TarjetaSupervision(
      titulo: 'Documentos del informe',
      subtitulo:
          '${docs.length} documento${docs.length == 1 ? '' : 's'} del periodo y ${inf.anexos.length} anexo${inf.anexos.length == 1 ? '' : 's'}.',
      icono: Icons.folder_open_rounded,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            boton(
              'informe',
              'Informe en PDF',
              Icons.picture_as_pdf_outlined,
              () => InformePdfService.informeEjecucion(
                expediente: _exp,
                plan: plan,
                informe: inf,
                firma: firma,
              ),
            ),
            boton(
              'paquete',
              'Paquete completo',
              Icons.library_books_outlined,
              () => InformePdfService.paqueteCompleto(
                expediente: _exp,
                plan: plan,
                informe: inf,
                todos: todos,
                firma: firma,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final d in docs)
          _FilaSoporte(
            titulo: d.nombre,
            detalle: d.origen == OrigenDocumento.sistema
                ? 'Lo arma la app'
                : ((inf.documentos[d.id] ?? const []).isEmpty
                      ? 'No adjuntado'
                      : (inf.documentos[d.id] ?? const [])
                            .map((a) => a.nombre)
                            .join(' · ')),
            falta:
                d.origen == OrigenDocumento.contratista &&
                (inf.documentos[d.id] ?? const []).isEmpty,
            devuelto: inf.estaDevuelto('documento:${d.id}'),
            acciones: [
              if (d.origen == OrigenDocumento.sistema)
                TextButton(
                  onPressed: _generando != null
                      ? null
                      : () => _pdf(
                          d.id,
                          () => InformePdfService.documentoSistema(
                            d.id,
                            expediente: _exp,
                            plan: plan,
                            informe: inf,
                            todos: todos,
                            firma: firma,
                          ),
                        ),
                  child: const Text('Ver'),
                ),
              for (final a in inf.documentos[d.id] ?? const <ArchivoAdjunto>[])
                TextButton(
                  onPressed: () =>
                      SupervisionService.abrirArchivo(_token, inf.id, a),
                  child: Text(
                    (inf.documentos[d.id] ?? const []).length > 1
                        ? 'Abrir ${a.nombre}'
                        : 'Abrir',
                  ),
                ),
            ],
          ),
        if (inf.anexos.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Anexos',
            style: TextStyle(
              color: EstiloContractual.navy,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          for (final (i, a) in inf.anexos.indexed)
            _FilaSoporte(
              titulo: 'Anexo ${i + 1}. ${a.titulo}',
              detalle: a.descripcion,
              acciones: [
                for (final f in a.archivos)
                  TextButton(
                    onPressed: () =>
                        SupervisionService.abrirArchivo(_token, inf.id, f),
                    child: Text(f.nombre, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Decisión
  // ---------------------------------------------------------------------------

  Widget _decision(
    PlanSupervision plan,
    InformePeriodo inf,
    Map<String, InformePeriodo> todos,
    Uint8List? firma,
  ) {
    switch (inf.estado) {
      case EstadoInforme.enRevision:
        final etapa =
            plan.etapas[inf.etapaActual.clamp(0, plan.etapas.length - 1)];
        if (!SupervisionService.puedeDecidir(_exp, plan, inf)) {
          return TarjetaSupervision(
            titulo: 'Le toca a ${etapa.nombre}',
            icono: Icons.hourglass_top_rounded,
            children: [
              Text(
                '${etapa.responsableNombre.isEmpty ? etapa.responsableEmail : etapa.responsableNombre} debe revisar y verificar '
                'el informe. No requiere acción de tu parte en este momento.',
                style: const TextStyle(
                  color: EstiloContractual.texto,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          );
        }
        return _formularioDecision(plan, inf, etapa);
      case EstadoInforme.devuelto:
        final d = inf.devolucion;
        return TarjetaSupervision(
          titulo: 'Devuelto al contratista',
          icono: Icons.undo_rounded,
          colorBorde: const Color(0xFFFCD34D),
          children: [
            if (d != null)
              Text(
                '${d.etapaNombre} · ${d.actor}: ${d.observacion}',
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              'Cuando lo corrija y lo reenvíe, vuelve a la etapa que lo devolvió.',
              style: TextStyle(color: EstiloContractual.gris, fontSize: 12.3),
            ),
          ],
        );
      case EstadoInforme.aprobado:
      case EstadoInforme.pagado:
        final pagado = inf.estado == EstadoInforme.pagado;
        return TarjetaSupervision(
          titulo: pagado ? 'Pago registrado' : 'Informe aprobado',
          subtitulo: pagado
              ? 'Referencia ${inf.pagoReferencia.isEmpty ? '—' : inf.pagoReferencia} · ${JuridicoContratacionService.formatearFechaHumana(inf.pagadoEnIso)}'
              : 'Aprobado ${JuridicoContratacionService.formatearFechaHumana(inf.aprobadoEnIso)}. Descarga el paquete completo para radicación.',
          icono: pagado ? Icons.payments_rounded : Icons.verified_rounded,
          colorBorde: const Color(0xFFBBF7D0),
          children: [
            if (!pagado && SupervisionService.puedeRegistrarPago(_exp)) ...[
              TextField(
                controller: _referencia,
                decoration: decoracionCampo(
                  'Referencia del pago (opcional)',
                  ayuda: 'Orden de pago u obligación del sistema financiero.',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _ocupado
                    ? null
                    : () => _accion(
                        () => SupervisionService.registrarPago(
                          _exp,
                          inf,
                          referencia: _referencia.text,
                        ),
                        'Pago registrado.',
                      ),
                style: EstiloContractual.botonPrincipal(),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text(
                  'Registrar pago',
                  style: EstiloContractual.etiquetaBoton,
                ),
              ),
            ],
          ],
        );
      case EstadoInforme.pendiente:
      case EstadoInforme.borrador:
        return const TarjetaSupervision(
          titulo: 'En elaboración',
          icono: Icons.edit_note_rounded,
          children: [Text('El contratista aún no ha enviado este informe.')],
        );
    }
  }

  Widget _formularioDecision(
    PlanSupervision plan,
    InformePeriodo inf,
    EtapaAprobacion etapa,
  ) {
    final ultima = inf.etapaActual >= plan.etapas.length - 1;
    final siguiente = ultima ? null : plan.etapas[inf.etapaActual + 1];
    final todosChecks = _checks.length == _checklist.length;
    final itemsPosibles = <(String, String)>[
      for (final (i, o) in plan.obligaciones.indexed)
        ('obligacion:${o.id}', 'Obligación ${i + 1}'),
      ('aportes', 'Datos de aportes'),
      if (inf.pideEstampilla(plan)) ('estampilla', 'Estampilla'),
      ('cobro', 'Cobro y datos'),
      ('anexos', 'Anexos'),
      for (final d
          in inf
              .documentosDelPeriodo(plan)
              .where((d) => d.origen == OrigenDocumento.contratista))
        ('documento:${d.id}', d.nombre),
    ];
    return TarjetaSupervision(
      titulo: 'Tu revisión · ${etapa.nombre}',
      subtitulo: ultima
          ? 'Eres la última etapa: al aprobar, el informe queda aprobado para pago.'
          : 'Al aprobar, el informe pasa a ${siguiente!.nombre}.',
      icono: Icons.fact_check_outlined,
      colorBorde: const Color(0xFFBFDBFE),
      children: [
        Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (final (i, t) in _checklist.indexed)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _checks.contains(i),
                  onChanged: (v) => setState(
                    () => v == true ? _checks.add(i) : _checks.remove(i),
                  ),
                  title: Text(t, style: const TextStyle(fontSize: 13.2)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _concepto,
          decoration: decoracionCampo(
            'Concepto (opcional)',
            ayuda: 'Ej.: Cumple. Va en la constancia del informe.',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _ocupado || !todosChecks
              ? null
              : () => _accion(
                  () => SupervisionService.aprobarEtapa(
                    _exp,
                    plan,
                    inf,
                    concepto: _concepto.text,
                  ),
                  ultima
                      ? 'Informe aprobado.'
                      : 'Revisado y verificado. Pasa a ${siguiente!.nombre}.',
                ),
          style: EstiloContractual.botonPrincipal().copyWith(
            backgroundColor: WidgetStatePropertyAll(
              todosChecks ? const Color(0xFF15803D) : const Color(0xFFCBD5E1),
            ),
          ),
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: Text(
            ultima ? 'Aprobar informe' : 'Revisado y verificado',
            style: EstiloContractual.etiquetaBoton,
          ),
        ),
        if (!todosChecks)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Marca los tres puntos para aprobar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: EstiloContractual.gris, fontSize: 12),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Divider(height: 1),
        ),
        const Text(
          'Devolver con observaciones',
          style: TextStyle(
            color: EstiloContractual.navy,
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Marca lo que debe corregir y explícale cómo. El contratista lo verá primero al abrir su informe.',
          style: TextStyle(color: EstiloContractual.texto, fontSize: 12.6),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (id, texto) in itemsPosibles)
              FilterChip(
                label: Text(texto, style: const TextStyle(fontSize: 12.3)),
                selected: _items.contains(id),
                onSelected: (s) =>
                    setState(() => s ? _items.add(id) : _items.remove(id)),
                selectedColor: const Color(0xFFFEF3C7),
                checkmarkColor: const Color(0xFF92400E),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _observacion,
          minLines: 3,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          decoration: decoracionCampo(
            'Observación para el contratista (obligatoria)',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _ocupado || _observacion.text.trim().length < 10
              ? null
              : () => _accion(
                  () => SupervisionService.devolver(
                    _exp,
                    plan,
                    inf,
                    observacion: _observacion.text,
                    items: _items.toList(),
                  ),
                  'Informe devuelto al contratista.',
                ),
          style: EstiloContractual.botonSecundario().copyWith(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFB45309)),
          ),
          icon: const Icon(Icons.undo_rounded, size: 18),
          label: const Text(
            'Devolver al contratista',
            style: EstiloContractual.etiquetaBoton,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// El informe como documento
// =============================================================================

class _Hoja extends StatelessWidget {
  const _Hoja({
    required this.expediente,
    required this.plan,
    required this.informe,
  });
  final ExpedienteContratoPs expediente;
  final PlanSupervision plan;
  final InformePeriodo informe;

  static const _linea = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    final e = expediente;
    final inf = informe;
    Widget fila(String k, String v) => Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _linea)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              k.toUpperCase(),
              style: const TextStyle(
                color: EstiloContractual.gris,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '—' : v,
              style: const TextStyle(
                color: EstiloContractual.navy,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: EstiloContractual.navy.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final l in plan.plantilla.encabezado)
            Text(
              l,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: EstiloContractual.navy,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Informe ${plan.periodicidad.adjetivo} de ejecución contractual N.º ${inf.numero}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: EstiloContractual.navy,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          fila(
            'Contrato',
            [
              e.numeroContrato,
              if (plan.cdp.registrado) 'CDP ${plan.cdp.numero}',
              plan.rp.registrado ? 'RP ${plan.rp.numero}' : 'RP pendiente',
            ].join(' · '),
          ),
          fila(
            'Contratista',
            '${e.contratistaNombreEsperado} · C.C. ${e.contratistaCedulaEsperada}',
          ),
          fila(
            'Periodo',
            '${fechaNumerica(inf.desde)} – ${fechaNumerica(inf.hasta)}',
          ),
          fila('Valor a cobrar', formatoCop(inf.valorCobradoCop)),
          fila('Objeto', e.objetoContrato),
          fila('Supervisor', plan.supervisorNombre),
          const SizedBox(height: 18),
          const Text(
            'Obligaciones y actividades',
            style: TextStyle(
              color: EstiloContractual.navy,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 8),
          for (final (i, o) in plan.obligaciones.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: const Border(bottom: BorderSide(color: _linea)),
                color: inf.estaDevuelto('obligacion:${o.id}')
                    ? const Color(0xFFFFFBEB)
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: EstiloContractual.gris,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.texto,
                          style: const TextStyle(
                            color: EstiloContractual.gris,
                            fontSize: 12.3,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          (inf.actividades[o.id] ?? '').trim().isEmpty
                              ? 'Sin actividades.'
                              : inf.actividades[o.id]!.trim(),
                          style: TextStyle(
                            color: (inf.actividades[o.id] ?? '').trim().isEmpty
                                ? const Color(0xFFB91C1C)
                                : EstiloContractual.navy,
                            fontSize: 13.3,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          const Text(
            'Aportes a seguridad social',
            style: TextStyle(
              color: EstiloContractual.navy,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 6),
          for (final p in inf.planillas.where((p) => p.diligenciada))
            fila(
              'Planilla ${p.numero}',
              '${nombreMes(p.periodo)} · pagada el ${fechaNumerica(DateTime.parse(p.fechaPagoIso))} · ${formatoCop(p.valorCop)}',
            ),
          if (inf.pensionado)
            fila(
              'Pensión',
              'No cotiza${inf.motivoNoPension.isEmpty ? '' : ': ${inf.motivoNoPension}'}',
            ),
          if (inf.pideEstampilla(plan) && inf.estampilla.diligenciada)
            fila(
              'Estampilla departamental',
              '${formatoCop(inf.estampilla.valorPagadoCop)} · liquidación ${inf.estampilla.liquidacion}',
            ),
          const SizedBox(height: 18),
          const Text(
            'Cuenta de cobro',
            style: TextStyle(
              color: EstiloContractual.navy,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 6),
          fila(
            'Cuenta',
            '${inf.datosCobro.banco} · ${inf.datosCobro.tipoCuenta} ${inf.datosCobro.numeroCuenta}',
          ),
          fila(
            'Dirección',
            '${inf.datosCobro.direccion} · ${inf.datosCobro.ciudad} · ${inf.datosCobro.celular}',
          ),
        ],
      ),
    );
  }
}

class _FilaSoporte extends StatelessWidget {
  const _FilaSoporte({
    required this.titulo,
    required this.detalle,
    required this.acciones,
    this.falta = false,
    this.devuelto = false,
  });

  final String titulo;
  final String detalle;
  final List<Widget> acciones;
  final bool falta;
  final bool devuelto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
    ),
    child: Row(
      children: [
        Icon(
          devuelto
              ? Icons.undo_rounded
              : (falta
                    ? Icons.error_outline_rounded
                    : Icons.description_outlined),
          size: 19,
          color: devuelto
              ? const Color(0xFFD97706)
              : (falta ? const Color(0xFFDC2626) : EstiloContractual.navy),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: EstiloContractual.navy,
                  fontSize: 13.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detalle.isNotEmpty)
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: falta
                        ? const Color(0xFFB91C1C)
                        : EstiloContractual.gris,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        ...acciones.map(
          (a) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: a,
          ),
        ),
      ],
    ),
  );
}
