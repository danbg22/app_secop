import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';

/// Informes mensuales en el portal del contratista. Solo aparece cuando el
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
  late final Stream<Map<String, InformeMensual>> _informes =
      SupervisionService.escucharInformes(_token);

  String? _periodo;

  // Formulario del mes abierto.
  String _cargado = '';
  final _valor = TextEditingController();
  final Map<String, TextEditingController> _actividades = {};
  final _planillaNumero = TextEditingController();
  final _ibc = TextEditingController();
  final _salud = TextEditingController();
  final _pension = TextEditingController();
  final _arl = TextEditingController();
  String _periodoCotizado = '';
  bool _pensionado = false;
  Map<String, DocumentoInforme> _documentos = {};
  bool _ocupado = false;
  String? _subiendo;

  @override
  void dispose() {
    for (final c in [
      _valor,
      _planillaNumero,
      _ibc,
      _salud,
      _pension,
      _arl,
      ..._actividades.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static int _n(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
  static String _t(int v) => v == 0 ? '' : '$v';

  /// Carga el informe del servidor en el formulario (al cambiar de mes o de
  /// estado), sin pisar lo que el contratista está escribiendo.
  void _cargar(PlanSupervision plan, InformeMensual inf) {
    final clave = '${inf.periodo}|${inf.estado.name}';
    if (_cargado == clave) return;
    _cargado = clave;
    _valor.text = _t(
      inf.valorCobradoCop == 0 && !inf.existe
          ? plan.valorMensualCop
          : inf.valorCobradoCop,
    );
    for (final o in plan.obligaciones) {
      (_actividades[o.id] ??= TextEditingController()).text =
          inf.actividades[o.id] ?? '';
    }
    final p = inf.planilla;
    _planillaNumero.text = p.numero;
    _ibc.text = _t(p.ibcCop);
    _salud.text = _t(p.saludCop);
    _pension.text = _t(p.pensionCop);
    _arl.text = _t(p.arlCop);
    _periodoCotizado = p.periodoCotizado.isEmpty
        ? inf.periodo
        : p.periodoCotizado;
    _pensionado = p.pensionado;
    _documentos = Map.of(inf.documentos);
  }

  InformeMensual _armar(InformeMensual base) => base.copyWith(
    valorCobradoCop: _n(_valor),
    actividades: {
      for (final e in _actividades.entries) e.key: e.value.text.trim(),
    },
    planilla: PlanillaReportada(
      numero: _planillaNumero.text.trim(),
      periodoCotizado: _periodoCotizado,
      ibcCop: _n(_ibc),
      saludCop: _n(_salud),
      pensionCop: _pensionado ? 0 : _n(_pension),
      arlCop: _n(_arl),
      pensionado: _pensionado,
    ),
    documentos: _documentos,
  );

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

  Future<void> _subir(InformeMensual base, DocumentoInformeTipo tipo) async {
    setState(() => _subiendo = tipo.name);
    try {
      final r = await SupervisionService.cargarDocumento(
        _token,
        _armar(base),
        tipo,
      );
      if (r != null && mounted) {
        setState(() => _documentos = Map.of(r.documentos));
        mensajeSupervision(context, '${tipo.etiqueta}: cargado.');
      }
    } on SupervisionException catch (e) {
      if (mounted) mensajeSupervision(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _subiendo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlanSupervision?>(
      stream: _plan,
      builder: (context, planSnap) {
        final plan = planSnap.data;
        if (plan == null) return const SizedBox.shrink();
        return StreamBuilder<Map<String, InformeMensual>>(
          stream: _informes,
          builder: (context, infSnap) {
            final informes = infSnap.data ?? const <String, InformeMensual>{};
            final hoy = periodoDe(DateTime.now());
            final disponibles = plan.periodos
                .where((p) => p.compareTo(hoy) <= 0)
                .toList();
            if (disponibles.isEmpty) {
              return _contenedor(plan, informes, const [
                Text(
                  'Tu primer informe se habilita cuando empiece la ejecución del contrato.',
                  style: TextStyle(color: EstiloContractual.texto),
                ),
              ]);
            }
            final sugerido = disponibles.firstWhere(
              (p) =>
                  (informes[p]?.estado ?? EstadoInforme.pendiente) ==
                  EstadoInforme.devuelto,
              orElse: () => disponibles.firstWhere(
                (p) => {
                  EstadoInforme.pendiente,
                  EstadoInforme.borrador,
                }.contains(informes[p]?.estado ?? EstadoInforme.pendiente),
                orElse: () => disponibles.last,
              ),
            );
            final periodo = disponibles.contains(_periodo)
                ? _periodo!
                : sugerido;
            final inf = informes[periodo] ?? InformeMensual(periodo: periodo);
            if (inf.estado.editablePorContratista || !inf.existe) {
              _cargar(plan, inf);
            }

            return _contenedor(plan, informes, [
              _selectorMeses(disponibles, informes, periodo),
              const SizedBox(height: 18),
              if (inf.existe && !inf.estado.editablePorContratista)
                _enRevision(inf)
              else
                ..._formulario(plan, inf),
            ]);
          },
        );
      },
    );
  }

  Widget _contenedor(
    PlanSupervision plan,
    Map<String, InformeMensual> informes,
    List<Widget> hijos,
  ) {
    final devueltos = informes.values
        .where((i) => i.estado == EstadoInforme.devuelto)
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: TarjetaSupervision(
        titulo: 'Informes mensuales de actividades',
        subtitulo:
            'Supervisor: ${plan.supervisorNombre}. Cada mes reporta tus actividades, adjunta la '
            'planilla de seguridad social y tu cuenta de cobro, y envíalo a revisión.',
        icono: Icons.event_note_rounded,
        colorBorde: devueltos > 0 ? const Color(0xFFFCD34D) : null,
        children: hijos,
      ),
    );
  }

  Widget _selectorMeses(
    List<String> periodos,
    Map<String, InformeMensual> informes,
    String actual,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in periodos) ...[
            _ChipMes(
              periodo: p,
              estado: informes[p]?.estado ?? EstadoInforme.pendiente,
              seleccionado: p == actual,
              onTap: () => setState(() {
                _periodo = p;
                _cargado = '';
              }),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _enRevision(InformeMensual inf) {
    final texto = switch (inf.estado) {
      EstadoInforme.enviado =>
        'Tu informe fue enviado y está en revisión documental.',
      EstadoInforme.revisado =>
        'Tus documentos fueron revisados. Falta la aprobación del supervisor.',
      EstadoInforme.aprobado =>
        'Tu informe fue aprobado. Está en trámite de pago.',
      EstadoInforme.pagado =>
        'El pago de este mes fue registrado${inf.pagoReferencia.isEmpty ? '' : ' (${inf.pagoReferencia})'}.',
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LineaPasosInforme(estado: inf.estado),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color(inf.estado.fondo),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: Color(inf.estado.color),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Cobro de ${nombrePeriodo(inf.periodo)}: ${formatoCop(inf.valorCobradoCop)}',
          style: const TextStyle(
            color: EstiloContractual.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<Widget> _formulario(PlanSupervision plan, InformeMensual base) {
    final mobile = MediaQuery.sizeOf(context).width < 680;
    final actual = _armar(base);
    final anio =
        int.tryParse(base.periodo.split('-').first) ?? DateTime.now().year;
    final aporte = AporteEsperado.calcular(
      valorMensualCop: actual.valorCobradoCop,
      claseRiesgo: plan.claseRiesgo,
      anio: anio,
    );
    final hallazgos = actual.planilla.diligenciada
        ? actual.planilla.verificar(aporte, base.periodo)
        : const <HallazgoPlanilla>[];
    final faltan = actual.faltantes(plan);
    final devueltos = base.estado == EstadoInforme.devuelto
        ? base.revision.entries.where((e) => !e.value.cumple).toList()
        : const <MapEntry<String, RevisionPunto>>[];

    Widget seccion(int n, String titulo, String ayuda) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: EstiloContractual.navy,
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  ayuda,
                  style: const TextStyle(
                    color: EstiloContractual.gris,
                    fontSize: 12.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    Widget dinero(TextEditingController c, String etiqueta) => TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      decoration: decoracionCampo(etiqueta, prefijo: '\$ '),
    );
    Widget fila(List<Widget> hijos) => mobile
        ? Column(
            children: [
              for (final (i, h) in hijos.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                h,
              ],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, h) in hijos.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: h),
              ],
            ],
          );

    return [
      if (devueltos.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu informe fue devuelto. Corrige lo siguiente y vuelve a enviarlo:',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 6),
              for (final d in devueltos)
                Text(
                  '• ${PuntoRevision.values.firstWhere((p) => p.name == d.key, orElse: () => PuntoRevision.actividades).etiqueta}: ${d.value.observacion}',
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      seccion(1, 'Valor que cobras', 'Honorarios del mes según tu contrato.'),
      SizedBox(
        width: mobile ? double.infinity : 300,
        child: dinero(
          _valor,
          'Valor a cobrar en ${nombrePeriodo(base.periodo)}',
        ),
      ),
      const SizedBox(height: 22),
      seccion(
        2,
        'Actividades del mes',
        'Describe qué hiciste para cumplir cada obligación. Sé concreto: fechas, productos, entregables.',
      ),
      for (final (i, o) in plan.obligaciones.indexed) ...[
        Text(
          '${i + 1}. ${o.texto}',
          style: const TextStyle(
            color: EstiloContractual.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _actividades[o.id],
          minLines: 2,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: decoracionCampo('Actividades realizadas'),
        ),
        const SizedBox(height: 14),
      ],
      const SizedBox(height: 8),
      seccion(
        3,
        'Seguridad social',
        'Copia los datos de tu planilla PILA pagada para este mes.',
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Text(
          'Con honorarios de ${formatoCop(actual.valorCobradoCop)} debes cotizar sobre un IBC de al menos '
          '${formatoCop(aporte.ibc)}: salud ${formatoCop(aporte.salud)}, pensión ${formatoCop(aporte.pension)}'
          '${aporte.arlLaPagaLaEntidad ? ' (la ARL la paga la entidad)' : ' y ARL ${formatoCop(aporte.arl)}'}.',
          style: const TextStyle(
            color: Color(0xFF075985),
            fontSize: 12.8,
            height: 1.45,
          ),
        ),
      ),
      const SizedBox(height: 12),
      fila([
        TextField(
          controller: _planillaNumero,
          onChanged: (_) => setState(() {}),
          decoration: decoracionCampo('Número de planilla'),
        ),
        DropdownButtonFormField<String>(
          initialValue: plan.periodos.contains(_periodoCotizado)
              ? _periodoCotizado
              : base.periodo,
          isExpanded: true,
          decoration: decoracionCampo('Periodo cotizado'),
          items: [
            for (final p in plan.periodos)
              DropdownMenuItem(value: p, child: Text(nombrePeriodo(p))),
          ],
          onChanged: (v) =>
              setState(() => _periodoCotizado = v ?? base.periodo),
        ),
        dinero(_ibc, 'IBC'),
      ]),
      const SizedBox(height: 12),
      fila([
        dinero(_salud, 'Salud'),
        if (!_pensionado) dinero(_pension, 'Pensión'),
        if (!aporte.arlLaPagaLaEntidad) dinero(_arl, 'ARL'),
      ]),
      Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _pensionado,
          onChanged: (v) => setState(() => _pensionado = v ?? false),
          title: const Text(
            'Soy pensionado (no cotizo a pensión)',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ),
      if (hallazgos.isNotEmpty) ListaHallazgos(hallazgos: hallazgos),
      const SizedBox(height: 22),
      seccion(4, 'Documentos', 'PDF o imagen, hasta 25 MB cada uno.'),
      for (final t in DocumentoInformeTipo.values)
        _FilaDocumento(
          tipo: t,
          documento: _documentos[t.name],
          subiendo: _subiendo == t.name,
          onCargar: _ocupado || _subiendo != null
              ? null
              : () => _subir(base, t),
          onAbrir: () => SupervisionService.abrirDocumento(
            _token,
            base.copyWith(documentos: _documentos),
            t,
          ),
        ),
      const SizedBox(height: 18),
      if (faltan.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para enviar te falta (${faltan.length}):',
                style: const TextStyle(
                  color: EstiloContractual.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.8,
                ),
              ),
              for (final f in faltan.take(5))
                Text(
                  '• $f',
                  style: const TextStyle(
                    color: EstiloContractual.texto,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: _ocupado
                ? null
                : () => _accion(
                    () => SupervisionService.guardarBorrador(
                      _token,
                      _armar(base),
                    ),
                    'Borrador guardado.',
                  ),
            style: EstiloContractual.botonSecundario(),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text(
              'Guardar borrador',
              style: EstiloContractual.etiquetaBoton,
            ),
          ),
          FilledButton.icon(
            onPressed: _ocupado || faltan.isNotEmpty
                ? null
                : () => _accion(
                    () => SupervisionService.enviar(
                      _token,
                      _armar(base),
                      plan,
                      contratista: widget.contratistaNombre,
                    ),
                    'Informe enviado a revisión.',
                  ),
            style: EstiloContractual.botonPrincipal(),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              base.estado == EstadoInforme.devuelto
                  ? 'Reenviar corregido'
                  : 'Enviar a revisión',
              style: EstiloContractual.etiquetaBoton,
            ),
          ),
        ],
      ),
    ];
  }
}

class _ChipMes extends StatelessWidget {
  const _ChipMes({
    required this.periodo,
    required this.estado,
    required this.seleccionado,
    required this.onTap,
  });

  final String periodo;
  final EstadoInforme estado;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mes = nombrePeriodo(periodo);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 132,
        height: 70,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: seleccionado ? EstiloContractual.navy : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado
                ? EstiloContractual.navy
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              mes[0].toUpperCase() + mes.substring(1),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: seleccionado ? Colors.white : EstiloContractual.navy,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color(estado.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    estado.etiqueta,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: seleccionado
                          ? Colors.white70
                          : EstiloContractual.gris,
                      fontSize: 11.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaDocumento extends StatelessWidget {
  const _FilaDocumento({
    required this.tipo,
    required this.documento,
    required this.subiendo,
    required this.onCargar,
    required this.onAbrir,
  });

  final DocumentoInformeTipo tipo;
  final DocumentoInforme? documento;
  final bool subiendo;
  final VoidCallback? onCargar;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final d = documento;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: d == null ? Colors.white : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: d == null ? const Color(0xFFE2E8F0) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            d == null ? Icons.upload_file_rounded : Icons.check_circle_rounded,
            color: d == null ? EstiloContractual.gris : const Color(0xFF16A34A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipo.etiqueta,
                  style: const TextStyle(
                    color: EstiloContractual.navy,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (d != null)
                  Text(
                    d.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: EstiloContractual.gris,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (d != null)
            IconButton(
              tooltip: 'Ver',
              onPressed: onAbrir,
              icon: const Icon(
                Icons.visibility_outlined,
                color: EstiloContractual.navy,
                size: 20,
              ),
            ),
          subiendo
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: onCargar,
                  style: TextButton.styleFrom(
                    foregroundColor: EstiloContractual.navy,
                  ),
                  child: Text(
                    d == null ? 'Adjuntar' : 'Cambiar',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
        ],
      ),
    );
  }
}
