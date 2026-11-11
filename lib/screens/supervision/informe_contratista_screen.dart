import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/informe_pdf_service.dart';
import '../../services/juridico_contratacion_service.dart';
import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';
import 'componentes_supervision.dart';
import 'firma_pad.dart';
import '../../tema/cristal.dart';

/// Informe del periodo como asistente guiado: una pregunta a la vez y las
/// respuestas apiladas encima, editables. El contratista no diligencia Word
/// ni Excel: la app arma los documentos con lo que responde aquí.
class InformeContratistaScreen extends StatefulWidget {
  const InformeContratistaScreen({
    super.key,
    required this.expediente,
    required this.plan,
    required this.periodo,
    required this.todos,
    required this.contratistaNombre,
  });

  final ExpedienteContratoPs expediente;
  final PlanSupervision plan;
  final PeriodoInforme periodo;
  final Map<String, InformePeriodo> todos;
  final String contratistaNombre;

  @override
  State<InformeContratistaScreen> createState() =>
      _InformeContratistaScreenState();
}

/// Un paso del asistente.
class _Paso {
  const _Paso({
    required this.id,
    required this.etiqueta,
    required this.pregunta,
    this.ayuda = '',
    required this.listo,
    required this.resumen,
    this.devuelto = false,
    this.opcional = false,
  });

  final String id;
  final String etiqueta;
  final String pregunta;
  final String ayuda;
  final bool listo;
  final String resumen;
  final bool devuelto;
  final bool opcional;
}

class _InformeContratistaScreenState extends State<InformeContratistaScreen> {
  PlanSupervision get _plan => widget.plan;
  String get _token => widget.expediente.tokenInvitado;

  late InformePeriodo _inf;
  late final Stream<Uint8List?> _firmaStream = SupervisionService.escucharFirma(
    _token,
  );
  Uint8List? _firma;
  StreamSubscription<Uint8List?>? _subFirma;

  int _paso = 0;
  bool _verAnteriores = false;
  String _guardado = '';
  bool _guardando = false;
  bool _enviando = false;
  bool _subiendo = false;
  Timer? _debounce;

  final Map<String, TextEditingController> _ctrl = {};
  final _respuesta = TextEditingController();

  static const _noRequerido =
      'Durante el periodo reportado no se requirió por parte de la entidad ni de la supervisión el '
      'desarrollo de actividades relacionadas con esta obligación.';

  @override
  void initState() {
    super.initState();
    final existente = widget.todos[widget.periodo.id];
    final anterior = widget.todos.values
        .where((i) => i.numero == widget.periodo.numero - 1)
        .firstOrNull;
    _inf =
        existente ??
        InformePeriodo.nuevo(widget.periodo, _plan, anterior: anterior);
    _subFirma = _firmaStream.listen((f) {
      if (mounted) setState(() => _firma = f);
    });
    // Un informe devuelto abre en lo primero que hay que corregir.
    if (_inf.estado == EstadoInforme.devuelto) {
      final i = _pasos.indexWhere((p) => p.devuelto);
      if (i >= 0) _paso = i;
    } else if (existente != null) {
      final i = _pasos.indexWhere((p) => !p.listo && !p.opcional);
      _paso = i < 0 ? _pasos.length - 1 : i;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subFirma?.cancel();
    for (final c in _ctrl.values) {
      c.dispose();
    }
    _respuesta.dispose();
    super.dispose();
  }

  TextEditingController _c(String clave, String inicial) =>
      _ctrl.putIfAbsent(clave, () => TextEditingController(text: inicial));

  bool get _editable => _inf.estado.editablePorContratista;

  // ---------------------------------------------------------------------------
  // Guardado
  // ---------------------------------------------------------------------------

  void _cambiar(InformePeriodo nuevo, {bool guardarYa = false}) {
    setState(() {
      _inf = nuevo;
      _guardado = 'Cambios sin guardar';
    });
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: guardarYa ? 0 : 1600), _guardar);
  }

  Future<void> _guardar() async {
    if (!_editable || _guardando) return;
    setState(() => _guardando = true);
    try {
      await SupervisionService.guardarBorrador(_token, _inf);
      if (_inf.estado == EstadoInforme.pendiente) {
        _inf = _inf.copyWith(estado: EstadoInforme.borrador);
      }
      if (mounted) setState(() => _guardado = 'Guardado');
    } on SupervisionException catch (e) {
      if (mounted) {
        setState(() => _guardado = 'No se pudo guardar');
        mensajeSupervision(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<ArchivoAdjunto?> _subir() async {
    setState(() => _subiendo = true);
    try {
      return await SupervisionService.subirArchivo(_token, _inf);
    } on SupervisionException catch (e) {
      if (mounted) mensajeSupervision(context, e.message, error: true);
      return null;
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Pasos
  // ---------------------------------------------------------------------------

  List<_Paso> get _pasos {
    final inf = _inf;
    final docs = inf.documentosDelPeriodo(_plan);
    final docsPendientes = docs
        .where(
          (d) =>
              d.origen == OrigenDocumento.contratista &&
              (inf.documentos[d.id] ?? const []).isEmpty,
        )
        .length;
    final planillas = inf.planillas.where((p) => p.diligenciada).toList();
    return [
      _Paso(
        id: 'datos',
        etiqueta: 'Datos del contrato',
        pregunta: '¿Los datos del contrato y del periodo están bien?',
        ayuda: 'Se llenan solos con lo que registró la entidad. Si algo está mal, avísale a tu supervisor.',
        listo: inf.valorCobradoCop > 0,
        resumen:
            'Periodo ${fechaLegible(inf.desde, conDia: false)} – ${fechaLegible(inf.hasta, conDia: false)}',
      ),
      for (final (i, o) in _plan.obligaciones.indexed)
        _Paso(
          id: 'obligacion:${o.id}',
          etiqueta: 'Obligación ${i + 1}',
          pregunta: '¿Qué hiciste para cumplir la obligación ${i + 1}?',
          ayuda: 'Sé concreto: qué hiciste, cuántos, en qué fechas y qué entregaste.',
          listo: (inf.actividades[o.id] ?? '').trim().length >= 15,
          resumen: (inf.actividades[o.id] ?? '').trim().isEmpty
              ? 'Sin responder'
              : inf.actividades[o.id]!.trim(),
          devuelto: inf.estaDevuelto('obligacion:${o.id}'),
        ),
      _Paso(
        id: 'anexos',
        etiqueta: 'Anexos',
        pregunta: '¿Tienes soportes de tus actividades?',
        ayuda:
            'Listados, pantallazos, actas, correos o fotos. Son opcionales. Cada anexo lleva un título, '
            'una descripción y sus archivos.',
        listo: true,
        opcional: true,
        resumen: inf.anexos.isEmpty
            ? 'Sin anexos'
            : '${inf.anexos.length} anexo${inf.anexos.length == 1 ? '' : 's'} · '
                  '${inf.anexos.fold<int>(0, (s, a) => s + a.archivos.length)} archivos',
        devuelto: inf.estaDevuelto('anexos'),
      ),
      _Paso(
        id: 'aportes',
        etiqueta: 'Seguridad social',
        pregunta: '¿Cuánto pagaste de seguridad social?',
        ayuda:
            'Copia los datos de tu planilla PILA. Se reporta mes vencido: en este informe va el aporte de '
            '${nombreMes(periodoMes(inf.desde))}.',
        listo: planillas.isNotEmpty,
        resumen: planillas.isEmpty
            ? 'Sin planilla'
            : planillas
                  .map(
                    (p) => 'Planilla ${p.numero} · ${formatoCop(p.valorCop)}',
                  )
                  .join(' · '),
        devuelto: inf.estaDevuelto('aportes'),
      ),
      if (inf.pideEstampilla(_plan))
        _Paso(
          id: 'estampilla',
          etiqueta: 'Estampilla departamental',
          pregunta: '¿Ya pagaste la estampilla departamental?',
          ayuda: 'Se paga una vez por contrato y se registra en el primer informe.',
          listo: inf.estampilla.diligenciada,
          resumen: inf.estampilla.diligenciada
              ? '${formatoCop(inf.estampilla.valorPagadoCop)} · liquidación ${inf.estampilla.liquidacion}'
              : 'Sin registrar',
          devuelto: inf.estaDevuelto('estampilla'),
        ),
      _Paso(
        id: 'cobro',
        etiqueta: 'Cobro y pago',
        pregunta: '¿Cuánto cobras y a qué cuenta te pagan?',
        ayuda: 'Con esto la app arma tu cuenta de cobro. Quedan guardados para los siguientes informes.',
        listo: inf.valorCobradoCop > 0 && inf.datosCobro.completos,
        resumen:
            '${formatoCop(inf.valorCobradoCop)} · ${inf.datosCobro.banco.isEmpty ? 'sin cuenta' : '${inf.datosCobro.banco} ${inf.datosCobro.numeroCuenta}'}',
        devuelto: inf.estaDevuelto('cobro'),
      ),
      _Paso(
        id: 'documentos',
        etiqueta: 'Documentos',
        pregunta: 'Adjunta los documentos de este informe',
        ayuda:
            'En PDF. Los que arma la app van al final; esos no los adjuntas.',
        listo: docsPendientes == 0,
        resumen: docsPendientes == 0
            ? '${docs.length} documentos listos'
            : 'Faltan $docsPendientes de ${docs.where((d) => d.origen == OrigenDocumento.contratista).length}',
        devuelto: docs.any((d) => inf.estaDevuelto('documento:${d.id}')),
      ),
      _Paso(
        id: 'firma',
        etiqueta: 'Firma y envío',
        pregunta: 'Revisa, firma y envía tu informe',
        listo: false,
        resumen: '',
      ),
    ];
  }

  void _ir(int i) {
    unawaited(_guardar());
    setState(() {
      _paso = i.clamp(0, _pasos.length - 1);
      _verAnteriores = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Construcción
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pasos = _pasos;
    final mobile = MediaQuery.sizeOf(context).width < 720;
    if (!_editable) return _soloLectura(mobile);
    final actual = pasos[_paso];
    final anteriores = [for (var i = 0; i < _paso; i++) (i, pasos[i])];
    final visibles = _verAnteriores || anteriores.length <= 3
        ? anteriores
        : anteriores.sublist(anteriores.length - 3);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _barraSuperior(pasos, mobile),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  mobile ? 14 : 24,
                  18,
                  mobile ? 14 : 24,
                  40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_inf.devolucion != null) ...[
                          _avisoDevolucion(pasos),
                          const SizedBox(height: 16),
                        ],
                        if (anteriores.length > visibles.length)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _verAnteriores = true),
                              icon: const Icon(
                                Icons.unfold_more_rounded,
                                size: 18,
                              ),
                              label: Text(
                                anteriores.length - visibles.length == 1
                                    ? 'Ver la respuesta anterior'
                                    : 'Ver las ${anteriores.length - visibles.length} respuestas anteriores',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Cristal.texto,
                              ),
                            ),
                          ),
                        for (final (i, p) in visibles)
                          _RespuestaApilada(paso: p, onEditar: () => _ir(i)),
                        if (visibles.isNotEmpty) const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 0.03),
                                end: Offset.zero,
                              ).animate(a),
                              child: child,
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(actual.id),
                            child: _tarjetaPaso(actual, pasos, mobile),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_paso < pasos.length - 1)
                          Text(
                            '${pasos.length - _paso - 1 == 1 ? 'Sigue 1 paso' : 'Siguen ${pasos.length - _paso - 1} pasos'}.'
                            ' Lo que escribes se guarda automáticamente.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Cristal.textoSuave,
                              fontSize: 12.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraSuperior(List<_Paso> pasos, bool mobile) {
    final listos = pasos.where((p) => p.listo).length;
    final vencido = DateTime.now().isAfter(
      DateTime(_inf.hasta.year, _inf.hasta.month, _inf.hasta.day, 23, 59),
    );
    return Container(
      color: Cristal.vidrio,
      padding: EdgeInsets.fromLTRB(mobile ? 10 : 20, 10, mobile ? 10 : 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                onPressed: () async {
                  await _guardar();
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Cristal.texto,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informe ${_plan.periodicidad.adjetivo} N.º ${_inf.numero}',
                      style: const TextStyle(
                        color: Cristal.texto,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${fechaLegible(_inf.desde, conDia: false)} – ${fechaLegible(_inf.hasta, conDia: false)}'
                      '${mobile ? '' : ' · Contrato ${widget.expediente.numeroContrato}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Cristal.textoSuave,
                        fontSize: 12.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!mobile) ...[
                EtiquetaColor(
                  texto: vencido
                      ? 'Venció el ${fechaLegible(_inf.hasta)}'
                      : 'Vence el ${fechaLegible(_inf.hasta)}',
                  color: vencido ? Cristal.rojo : Cristal.acentoClaro,
                  fondo: vencido ? Cristal.rojoVidrio : Cristal.azulVidrio,
                  icono: Icons.event_rounded,
                ),
                const SizedBox(width: 10),
              ],
              PopupMenuButton<int>(
                tooltip: 'Ir a un paso',
                onSelected: _ir,
                itemBuilder: (_) => [
                  for (final (i, p) in pasos.indexed)
                    PopupMenuItem(
                      value: i,
                      child: Row(
                        children: [
                          Icon(
                            p.devuelto
                                ? Icons.undo_rounded
                                : (p.listo
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded),
                            size: 18,
                            color: p.devuelto
                                ? Cristal.ambar
                                : (p.listo
                                      ? Cristal.verde
                                      : Cristal.textoTenue),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            p.etiqueta,
                            style: TextStyle(
                              fontWeight: i == _paso
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Cristal.borde),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.format_list_numbered_rounded,
                        size: 17,
                        color: Cristal.texto,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Paso ${_paso + 1} de ${pasos.length}',
                        style: const TextStyle(
                          color: Cristal.texto,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: listos / pasos.length,
                    minHeight: 5,
                    color: Cristal.verde,
                    backgroundColor: Cristal.vidrioFuerte,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                [
                  '$listos de ${pasos.length} listos',
                  if (_guardando)
                    'Guardando…'
                  else if (_guardado.isNotEmpty)
                    _guardado,
                ].join(' · '),
                style: const TextStyle(
                  color: Cristal.textoSuave,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _avisoDevolucion(List<_Paso> pasos) {
    final d = _inf.devolucion!;
    final primero = pasos.indexWhere((p) => p.devuelto);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cristal.ambarVidrio,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Cristal.ambarBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${d.etapaNombre} devolvió tu informe',
            style: const TextStyle(
              color: Cristal.ambar,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            d.observacion,
            style: const TextStyle(
              color: Cristal.ambar,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${d.actor} · ${JuridicoContratacionService.formatearFechaHumana(d.fechaIso)}',
            style: const TextStyle(color: Cristal.ambar, fontSize: 11.8),
          ),
          if (primero >= 0 && primero != _paso) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _ir(primero),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text('Ir a corregir: ${pasos[primero].etiqueta}'),
              style: TextButton.styleFrom(foregroundColor: Cristal.ambar),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaPaso(_Paso p, List<_Paso> pasos, bool mobile) {
    final esUltimo = p.id == 'firma';
    return Container(
      padding: EdgeInsets.all(mobile ? 18 : 26),
      decoration: EstiloContractual.tarjeta(
        colorBorde: p.devuelto ? Cristal.ambarBorde : Cristal.bordeFuerte,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.pregunta,
            style: TextStyle(
              color: Cristal.texto,
              fontSize: mobile ? 19 : 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
          if (p.ayuda.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.ayuda,
              style: const TextStyle(
                color: Cristal.textoMedio,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _contenido(p),
          if (!esUltimo) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                if (_paso > 0)
                  TextButton.icon(
                    onPressed: () => _ir(_paso - 1),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Anterior'),
                    style: TextButton.styleFrom(foregroundColor: Cristal.texto),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _ir(_paso + 1),
                  style: EstiloContractual.botonPrincipal(),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    p.opcional && !_inf.anexos.isNotEmpty
                        ? 'No tengo, seguir'
                        : 'Siguiente',
                    style: EstiloContractual.etiquetaBoton,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _contenido(_Paso p) {
    if (p.id == 'datos') return _pasoDatos();
    if (p.id.startsWith('obligacion:')) {
      return _pasoObligacion(p.id.substring('obligacion:'.length));
    }
    return switch (p.id) {
      'anexos' => _pasoAnexos(),
      'aportes' => _pasoAportes(),
      'estampilla' => _pasoEstampilla(),
      'cobro' => _pasoCobro(),
      'documentos' => _pasoDocumentos(),
      _ => _pasoFirma(),
    };
  }

  // ---------------------------------------------------------------------------
  // Contenido de cada paso
  // ---------------------------------------------------------------------------

  Widget _pasoDatos() {
    final e = widget.expediente;
    final p = _plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 28,
          runSpacing: 14,
          children: [
            DatoSupervision('Contrato', e.numeroContrato),
            DatoSupervision('Contratista', e.contratistaNombreEsperado),
            DatoSupervision('Plazo', e.plazoEjecucion),
            DatoSupervision('Valor total', formatoCop(e.valorContratoCop)),
            DatoSupervision(
              'Inicio y terminación',
              '${fechaNumerica(p.fechaInicio)} – ${fechaNumerica(p.fechaFin)}',
            ),
            DatoSupervision(
              'Periodo de este informe',
              '${fechaNumerica(_inf.desde)} – ${fechaNumerica(_inf.hasta)}',
            ),
            DatoSupervision(
              'CDP',
              p.cdp.registrado ? 'N.º ${p.cdp.numero}' : 'Sin registrar',
            ),
            DatoSupervision(
              'RP',
              p.rp.registrado ? 'N.º ${p.rp.numero}' : 'Sin registrar',
            ),
            DatoSupervision('Supervisor', p.supervisorNombre),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          e.objetoContrato,
          style: const TextStyle(
            color: Cristal.textoMedio,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _pasoObligacion(String id) {
    final i = _plan.obligaciones.indexWhere((o) => o.id == id);
    final o = _plan.obligaciones[i];
    final c = _c('obl:$id', _inf.actividades[id] ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Cristal.vidrioSuave,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            o.texto,
            style: const TextStyle(
              color: Cristal.texto,
              fontSize: 13.6,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: c,
          minLines: 5,
          maxLines: 14,
          autofocus: c.text.isEmpty,
          onChanged: (v) => _cambiar(
            _inf.copyWith(actividades: {..._inf.actividades, id: v}),
          ),
          decoration: decoracionCampo('Actividades realizadas'),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ActionChip(
              avatar: const Icon(Icons.short_text_rounded, size: 18),
              label: const Text('No se requirió en este periodo'),
              onPressed: () {
                c.text = _noRequerido;
                _cambiar(
                  _inf.copyWith(
                    actividades: {..._inf.actividades, id: _noRequerido},
                  ),
                );
              },
            ),
            Text(
              '${c.text.trim().length} caracteres',
              style: const TextStyle(color: Cristal.textoSuave, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pasoAnexos() {
    final anexos = _inf.anexos;
    void actualizar(int i, Anexo a) {
      final lista = [...anexos]..[i] = a;
      _cambiar(_inf.copyWith(anexos: lista));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, a) in anexos.indexed) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Cristal.vidrioSuave,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Cristal.borde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Anexo ${i + 1}',
                      style: const TextStyle(
                        color: Cristal.texto,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _cambiar(
                        _inf.copyWith(anexos: [...anexos]..removeAt(i)),
                        guardarYa: true,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Quitar anexo'),
                      style: TextButton.styleFrom(
                        foregroundColor: Cristal.rojo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _c('anx:${a.id}:t', a.titulo),
                  onChanged: (v) =>
                      actualizar(i, anexos[i].copyWith(titulo: v)),
                  decoration: decoracionCampo(
                    'Título',
                    ayuda: 'Ej.: Listado de expedientes revisados',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _c('anx:${a.id}:d', a.descripcion),
                  minLines: 2,
                  maxLines: 5,
                  onChanged: (v) =>
                      actualizar(i, anexos[i].copyWith(descripcion: v)),
                  decoration: decoracionCampo('¿Qué demuestra este anexo?'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Respalda las obligaciones',
                  style: TextStyle(
                    color: Cristal.texto,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.8,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (j, o) in _plan.obligaciones.indexed)
                      FilterChip(
                        label: Text('${j + 1}'),
                        tooltip: o.texto,
                        selected: a.obligaciones.contains(o.id),
                        onSelected: (s) => actualizar(
                          i,
                          anexos[i].copyWith(
                            obligaciones: s
                                ? [...a.obligaciones, o.id]
                                : a.obligaciones
                                      .where((x) => x != o.id)
                                      .toList(),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final f in a.archivos)
                  _FilaArchivo(
                    archivo: f,
                    onAbrir: () =>
                        SupervisionService.abrirArchivo(_token, _inf.id, f),
                    onQuitar: () => actualizar(
                      i,
                      anexos[i].copyWith(
                        archivos: a.archivos
                            .where((x) => x.id != f.id)
                            .toList(),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _subiendo
                        ? null
                        : () async {
                            final f = await _subir();
                            if (f != null) {
                              actualizar(
                                i,
                                _inf.anexos[i].copyWith(
                                  archivos: [..._inf.anexos[i].archivos, f],
                                ),
                              );
                            }
                          },
                    style: EstiloContractual.botonSecundario(),
                    icon: _subiendo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file_rounded, size: 18),
                    label: const Text(
                      'Adjuntar archivo',
                      style: EstiloContractual.etiquetaBoton,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _cambiar(
              _inf.copyWith(
                anexos: [
                  ...anexos,
                  Anexo(id: 'a${DateTime.now().microsecondsSinceEpoch}'),
                ],
              ),
            ),
            style: EstiloContractual.botonSecundario(),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: Text(
              anexos.isEmpty ? 'Agregar un anexo' : 'Agregar otro anexo',
              style: EstiloContractual.etiquetaBoton,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pasoAportes() {
    final inf = _inf;
    final aporte = AporteEsperado.calcular(
      valorMensualCop: _plan.periodicidad == Periodicidad.quincenal
          ? inf.valorCobradoCop * 2
          : inf.valorCobradoCop,
      claseRiesgo: _plan.claseRiesgo,
      anio: inf.desde.year,
    );
    final meses = <String>{
      for (var k = -2; k <= 1; k++)
        periodoMes(DateTime(inf.desde.year, inf.desde.month + k)),
      for (final p in inf.planillas)
        if (p.periodo.isNotEmpty) p.periodo,
    }.toList()..sort();

    void actualizar(int i, PlanillaAporte p) =>
        _cambiar(inf.copyWith(planillas: [...inf.planillas]..[i] = p));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Cristal.azulVidrio,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Con tus honorarios debes cotizar sobre un IBC de al menos ${formatoCop(aporte.ibc)}: '
            'salud ${formatoCop(aporte.salud)}${inf.pensionado ? '' : ', pensión ${formatoCop(aporte.pension)}'}'
            '${aporte.arlLaPagaLaEntidad ? ' (la ARL la paga la entidad)' : ' y ARL ${formatoCop(aporte.arl)}'}. '
            'Total mínimo: ${formatoCop(aporte.totalContratista(pensionado: inf.pensionado))}.',
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final (i, p) in inf.planillas.indexed) ...[
          if (inf.planillas.length > 1)
            Row(
              children: [
                Text(
                  'Planilla ${i + 1}',
                  style: const TextStyle(
                    color: Cristal.texto,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (i > 0)
                  TextButton(
                    onPressed: () => _cambiar(
                      inf.copyWith(planillas: [...inf.planillas]..removeAt(i)),
                    ),
                    child: const Text('Quitar'),
                  ),
              ],
            ),
          _Fila([
            DropdownButtonFormField<String>(
              initialValue: meses.contains(p.periodo) ? p.periodo : null,
              isExpanded: true,
              decoration: decoracionCampo('Mes cotizado'),
              items: [
                for (final m in meses)
                  DropdownMenuItem(value: m, child: Text(nombreMes(m))),
              ],
              onChanged: (v) => actualizar(i, p.copyWith(periodo: v)),
            ),
            _CampoFecha(
              etiqueta: 'Fecha de pago',
              valorIso: p.fechaPagoIso,
              onCambio: (iso) =>
                  actualizar(i, inf.planillas[i].copyWith(fechaPagoIso: iso)),
            ),
          ]),
          const SizedBox(height: 12),
          _Fila([
            TextField(
              controller: _c('pl$i:n', p.numero),
              onChanged: (v) =>
                  actualizar(i, inf.planillas[i].copyWith(numero: v.trim())),
              decoration: decoracionCampo('N.º de planilla (PILA)'),
            ),
            _CampoDinero(
              controlador: _c(
                'pl$i:ibc',
                p.ibcCop == 0 ? '' : milesCop(p.ibcCop),
              ),
              etiqueta: 'IBC',
              onCambio: (v) =>
                  actualizar(i, inf.planillas[i].copyWith(ibcCop: v)),
            ),
            _CampoDinero(
              controlador: _c(
                'pl$i:v',
                p.valorCop == 0 ? '' : milesCop(p.valorCop),
              ),
              etiqueta: 'Total pagado',
              onCambio: (v) =>
                  actualizar(i, inf.planillas[i].copyWith(valorCop: v)),
            ),
          ]),
          const SizedBox(height: 14),
        ],
        if (inf.planillas.length < 2)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _cambiar(
                inf.copyWith(
                  planillas: [...inf.planillas, const PlanillaAporte()],
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar otra planilla'),
              style: TextButton.styleFrom(foregroundColor: Cristal.texto),
            ),
          ),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: inf.pensionado,
            onChanged: (v) => _cambiar(inf.copyWith(pensionado: v ?? false)),
            title: const Text(
              'No cotizo a pensión (pensionado o exceptuado)',
              style: TextStyle(fontSize: 13.5),
            ),
          ),
        ),
        if (inf.pensionado)
          TextField(
            controller: _c('motivoPension', inf.motivoNoPension),
            onChanged: (v) => _cambiar(inf.copyWith(motivoNoPension: v)),
            decoration: decoracionCampo(
              'Motivo',
              ayuda: 'Sale en el informe de supervisión.',
            ),
          ),
        if (inf.planillas.any((p) => p.diligenciada)) ...[
          const SizedBox(height: 14),
          ListaVerificaciones(
            verificaciones: inf
                .verificar(_plan)
                .where((v) => v.texto.startsWith('Aporte'))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _pasoEstampilla() {
    final e = _inf.estampilla;
    final base = widget.expediente.valorContratoCop;
    final calculada = (base * e.tarifaPct / 100).round();
    void act(EstampillaDepartamental n) =>
        _cambiar(_inf.copyWith(estampilla: n));
    EstampillaDepartamental con({
      String? f,
      double? t,
      int? v,
      int? i,
      String? l,
    }) => EstampillaDepartamental(
      fechaPagoIso: f ?? e.fechaPagoIso,
      tarifaPct: t ?? e.tarifaPct,
      valorPagadoCop: v ?? e.valorPagadoCop,
      interesesCop: i ?? e.interesesCop,
      liquidacion: l ?? e.liquidacion,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 28,
          runSpacing: 10,
          children: [
            DatoSupervision('Base (valor del contrato)', formatoCop(base)),
            DatoSupervision(
              'Tarifa',
              '${e.tarifaPct.toString().replaceAll('.', ',')} %',
            ),
            DatoSupervision(
              'Estampilla',
              formatoCop(calculada),
              color: const Color(0xFF38BDF8),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Fila([
          _CampoFecha(
            etiqueta: 'Fecha de pago',
            valorIso: e.fechaPagoIso,
            onCambio: (iso) => act(con(f: iso)),
          ),
          TextField(
            controller: _c('est:l', e.liquidacion),
            onChanged: (v) => act(con(l: v.trim())),
            decoration: decoracionCampo('N.º de liquidación'),
          ),
        ]),
        const SizedBox(height: 12),
        _Fila([
          _CampoDinero(
            controlador: _c(
              'est:v',
              e.valorPagadoCop == 0 ? '' : milesCop(e.valorPagadoCop),
            ),
            etiqueta: 'Valor pagado (total del recibo)',
            onCambio: (v) => act(con(v: v)),
          ),
          _CampoDinero(
            controlador: _c(
              'est:i',
              e.interesesCop == 0 ? '' : milesCop(e.interesesCop),
            ),
            etiqueta: 'Intereses pagados (si hubo)',
            onCambio: (v) => act(con(i: v)),
          ),
        ]),
        const SizedBox(height: 10),
        const Text(
          'El soporte de pago se adjunta en el paso de Documentos, como "Impuesto departamental".',
          style: TextStyle(color: Cristal.textoSuave, fontSize: 12.3),
        ),
      ],
    );
  }

  Widget _pasoCobro() {
    final inf = _inf;
    final d = inf.datosCobro;
    final pagado = widget.todos.values
        .where(
          (i) =>
              i.numero < inf.numero &&
              (i.estado == EstadoInforme.aprobado ||
                  i.estado == EstadoInforme.pagado),
        )
        .fold<int>(0, (s, i) => s + i.valorCobradoCop);
    final saldo = widget.expediente.valorContratoCop - pagado;
    void act(DatosCobro n) => _cambiar(inf.copyWith(datosCobro: n));
    Widget sn(String t, bool v, ValueChanged<bool> f) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: v,
      onChanged: f,
      title: Text(t, style: const TextStyle(fontSize: 13.3)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CampoDinero(
          controlador: _c(
            'cobro:v',
            inf.valorCobradoCop == 0 ? '' : milesCop(inf.valorCobradoCop),
          ),
          etiqueta: 'Valor a cobrar en este informe',
          ayuda:
              'Saldo del contrato: ${formatoCop(saldo)}. No puede pasar del saldo.',
          error: inf.valorCobradoCop > saldo && saldo > 0
              ? 'Supera el saldo del contrato'
              : null,
          onCambio: (v) => _cambiar(inf.copyWith(valorCobradoCop: v)),
        ),
        const SizedBox(height: 18),
        _Fila([
          TextField(
            controller: _c('dc:dir', d.direccion),
            onChanged: (v) => act(d.copyWith(direccion: v)),
            decoration: decoracionCampo('Dirección de residencia'),
          ),
          TextField(
            controller: _c('dc:ciu', d.ciudad),
            onChanged: (v) => act(inf.datosCobro.copyWith(ciudad: v)),
            decoration: decoracionCampo('Barrio y ciudad'),
          ),
        ]),
        const SizedBox(height: 12),
        _Fila([
          TextField(
            controller: _c('dc:cel', d.celular),
            keyboardType: TextInputType.phone,
            onChanged: (v) => act(inf.datosCobro.copyWith(celular: v)),
            decoration: decoracionCampo('Celular'),
          ),
          TextField(
            controller: _c('dc:banco', d.banco),
            onChanged: (v) => act(inf.datosCobro.copyWith(banco: v)),
            decoration: decoracionCampo('Entidad bancaria'),
          ),
        ]),
        const SizedBox(height: 12),
        _Fila([
          DropdownButtonFormField<String>(
            initialValue: const ['Ahorros', 'Corriente'].contains(d.tipoCuenta)
                ? d.tipoCuenta
                : 'Ahorros',
            decoration: decoracionCampo('Tipo de cuenta'),
            items: const [
              DropdownMenuItem(
                value: 'Ahorros',
                child: Text('Cuenta de ahorros'),
              ),
              DropdownMenuItem(
                value: 'Corriente',
                child: Text('Cuenta corriente'),
              ),
            ],
            onChanged: (v) => act(inf.datosCobro.copyWith(tipoCuenta: v)),
          ),
          TextField(
            controller: _c('dc:num', d.numeroCuenta),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => act(inf.datosCobro.copyWith(numeroCuenta: v)),
            decoration: decoracionCampo('Número de cuenta'),
          ),
        ]),
        const SizedBox(height: 10),
        const Text(
          'Según tu RUT',
          style: TextStyle(
            color: Cristal.texto,
            fontWeight: FontWeight.w800,
            fontSize: 13.3,
          ),
        ),
        Material(
          color: Colors.transparent,
          child: Column(
            children: [
              sn(
                'Soy responsable de IVA',
                d.responsableIva,
                (v) => act(inf.datosCobro.copyWith(responsableIva: v)),
              ),
              sn(
                'Soy declarante de renta',
                d.declaranteRenta,
                (v) => act(inf.datosCobro.copyWith(declaranteRenta: v)),
              ),
              sn(
                'Soy facturador electrónico',
                d.facturadorElectronico,
                (v) => act(inf.datosCobro.copyWith(facturadorElectronico: v)),
              ),
              sn(
                'Estoy en el régimen simple de tributación',
                d.regimenSimple,
                (v) => act(inf.datosCobro.copyWith(regimenSimple: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pasoDocumentos() {
    final docs = _inf.documentosDelPeriodo(_plan);
    final propios = docs
        .where((d) => d.origen == OrigenDocumento.contratista)
        .toList();
    final generados = docs
        .where((d) => d.origen == OrigenDocumento.sistema)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, d) in propios.indexed) ...[
          if (i > 0) const Divider(height: 1, color: Cristal.borde),
          _FilaDocumento(
            documento: d,
            archivos: _inf.documentos[d.id] ?? const [],
            devuelto: _inf.estaDevuelto('documento:${d.id}'),
            subiendo: _subiendo,
            onAdjuntar: () async {
              final f = await _subir();
              if (f == null) return;
              final actuales =
                  _inf.documentos[d.id] ?? const <ArchivoAdjunto>[];
              // Lo devuelto se reemplaza; si no, se agrega hasta el máximo.
              final nuevos =
                  _inf.estaDevuelto('documento:${d.id}') ||
                      actuales.length >= d.maxArchivos
                  ? [f]
                  : [...actuales, f];
              _cambiar(
                _inf.copyWith(documentos: {..._inf.documentos, d.id: nuevos}),
                guardarYa: true,
              );
            },
            onQuitar: (f) => _cambiar(
              _inf.copyWith(
                documentos: {
                  ..._inf.documentos,
                  d.id: (_inf.documentos[d.id] ?? const [])
                      .where((x) => x.id != f.id)
                      .toList(),
                },
              ),
              guardarYa: true,
            ),
            onAbrir: (f) => SupervisionService.abrirArchivo(_token, _inf.id, f),
          ),
        ],
        if (generados.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            decoration: BoxDecoration(
              color: Cristal.vidrioSuave,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: Cristal.verde,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        generados.length == 1
                            ? '1 lo arma la app con tus respuestas'
                            : '${generados.length} los arma la app con tus respuestas',
                        style: const TextStyle(
                          color: Cristal.verde,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                for (final d in generados)
                  Row(
                    children: [
                      const SizedBox(width: 26),
                      Expanded(
                        child: Text(
                          d.regla == ReglaDocumento.cadaPeriodo
                              ? d.nombre
                              : '${d.nombre} · ${d.regla.etiqueta.toLowerCase()}',
                          style: const TextStyle(
                            color: Cristal.texto,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _verGenerado(d.id),
                        style: TextButton.styleFrom(
                          foregroundColor: Cristal.texto,
                        ),
                        child: const Text('Ver cómo queda'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _verGenerado(String id) async {
    final bytes = await InformePdfService.documentoSistema(
      id,
      expediente: widget.expediente,
      plan: _plan,
      informe: _inf,
      todos: widget.todos,
      firma: _firma,
    );
    if (bytes != null) InformePdfService.abrir(bytes);
  }

  Widget _pasoFirma() {
    final faltan = _inf.faltantes(_plan, firmaRegistrada: _firma != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tu firma',
          style: TextStyle(
            color: Cristal.texto,
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'La app la usa en el informe, la cuenta de cobro y la solicitud de estampillas. Se registra una sola vez.',
          style: TextStyle(color: Cristal.textoMedio, fontSize: 12.8),
        ),
        const SizedBox(height: 10),
        if (_firma != null)
          Row(
            children: [
              Container(
                height: 70,
                width: 220,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Cristal.vidrio,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Cristal.borde),
                ),
                child: Image.memory(_firma!, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => setState(() => _firma = null),
                style: TextButton.styleFrom(foregroundColor: Cristal.texto),
                child: const Text('Cambiar firma'),
              ),
            ],
          )
        else
          FirmaPad(
            guardando: _guardando,
            onGuardar: (png) async {
              try {
                await SupervisionService.guardarFirma(_token, png);
                if (mounted) setState(() => _firma = png);
              } on SupervisionException catch (e) {
                if (mounted) {
                  mensajeSupervision(context, e.message, error: true);
                }
              }
            },
          ),
        const SizedBox(height: 22),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _inf.declaracion,
            onChanged: (v) => _cambiar(
              _inf.copyWith(declaracion: v ?? false),
              guardarYa: true,
            ),
            title: Text(
              _plan.plantilla.declaracion,
              style: const TextStyle(fontSize: 13.2, height: 1.45),
            ),
            subtitle: Text(
              'Al enviar, el informe queda firmado electrónicamente por ${widget.expediente.contratistaNombreEsperado}.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        if (_inf.estado == EstadoInforme.devuelto) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _respuesta,
            minLines: 2,
            maxLines: 4,
            decoration: decoracionCampo(
              '¿Qué corregiste? (opcional)',
              ayuda: 'Se muestra al revisor junto a su observación.',
            ),
          ),
        ],
        if (faltan.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Cristal.vidrioSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Antes de enviar te falta:',
                  style: const TextStyle(
                    color: Cristal.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                for (final f in faltan.take(6))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.radio_button_unchecked_rounded,
                            size: 14,
                            color: Cristal.textoSuave,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(
                              color: Cristal.textoMedio,
                              fontSize: 12.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _ir(_paso - 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Anterior'),
              style: TextButton.styleFrom(foregroundColor: Cristal.texto),
            ),
            OutlinedButton.icon(
              onPressed: () async => InformePdfService.abrir(
                await InformePdfService.informeEjecucion(
                  expediente: widget.expediente,
                  plan: _plan,
                  informe: _inf,
                  firma: _firma,
                ),
              ),
              style: EstiloContractual.botonSecundario(),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text(
                'Vista previa',
                style: EstiloContractual.etiquetaBoton,
              ),
            ),
            FilledButton.icon(
              onPressed: faltan.isNotEmpty || _enviando ? null : _enviar,
              style: EstiloContractual.botonPrincipal(),
              icon: _enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Cristal.texto,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _inf.estado == EstadoInforme.devuelto
                    ? 'Reenviar corregido'
                    : 'Firmar y enviar',
                style: EstiloContractual.etiquetaBoton,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      await SupervisionService.enviar(
        _token,
        _inf,
        _plan,
        contratista: widget.contratistaNombre.isEmpty
            ? widget.expediente.contratistaNombreEsperado
            : widget.contratistaNombre,
        firmaRegistrada: _firma != null,
        respuesta: _respuesta.text,
      );
      if (!mounted) return;
      mensajeSupervision(
        context,
        'Informe enviado. Pasa a ${_plan.etapas.first.nombre.toLowerCase()}.',
      );
      Navigator.pop(context);
    } on SupervisionException catch (e) {
      if (mounted) mensajeSupervision(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Informe ya enviado
  // ---------------------------------------------------------------------------

  Widget _soloLectura(bool mobile) {
    final texto = switch (_inf.estado) {
      EstadoInforme.enRevision =>
        'Tu informe está en revisión: ${_plan.etapas[_inf.etapaActual.clamp(0, _plan.etapas.length - 1)].nombre}.',
      EstadoInforme.aprobado =>
        'Tu informe fue aprobado. Está en trámite de pago.',
      EstadoInforme.pagado => 'El pago de este informe fue registrado.',
      _ => '',
    };
    return PantallaContractual(
      anchoMaximo: 820,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: PildoraVolver(
            etiqueta: 'Volver',
            onTap: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Informe ${_plan.periodicidad.adjetivo} N.º ${_inf.numero}',
          style: EstiloContractual.titulo.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 4),
        Text(
          '${fechaLegible(_inf.desde, conDia: false)} – ${fechaLegible(_inf.hasta, conDia: false)} · ${formatoCop(_inf.valorCobradoCop)}',
          style: EstiloContractual.subtitulo,
        ),
        const SizedBox(height: 18),
        TarjetaSupervision(
          titulo: texto,
          children: [
            RielEtapas(plan: _plan, informe: _inf, vertical: mobile),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async => InformePdfService.abrir(
                  await InformePdfService.informeEjecucion(
                    expediente: widget.expediente,
                    plan: _plan,
                    informe: _inf,
                    firma: _firma,
                  ),
                ),
                style: EstiloContractual.botonSecundario(),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text(
                  'Ver el informe en PDF',
                  style: EstiloContractual.etiquetaBoton,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Piezas
// =============================================================================

class _RespuestaApilada extends StatelessWidget {
  const _RespuestaApilada({required this.paso, required this.onEditar});
  final _Paso paso;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final color = paso.devuelto
        ? Cristal.ambar
        : (paso.listo ? Cristal.verde : Cristal.textoTenue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Cristal.vidrio,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          hoverDuration: Cristal.micro,
          onTap: onEditar,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
            child: Row(
              children: [
                Icon(
                  paso.devuelto
                      ? Icons.undo_rounded
                      : (paso.listo
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded),
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width < 640 ? 108 : 150,
                  child: Text(
                    paso.etiqueta,
                    style: const TextStyle(
                      color: Cristal.texto,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    paso.resumen,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Cristal.textoSuave,
                      fontSize: 12.8,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onEditar,
                  style: TextButton.styleFrom(
                    foregroundColor: Cristal.texto,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Editar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dos o tres campos en fila en escritorio; uno debajo del otro en celular.
class _Fila extends StatelessWidget {
  const _Fila(this.hijos);
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 640) {
      return Column(
        children: [
          for (final (i, h) in hijos.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            h,
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, h) in hijos.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: h),
        ],
      ],
    );
  }
}

class _CampoDinero extends StatelessWidget {
  const _CampoDinero({
    required this.controlador,
    required this.etiqueta,
    required this.onCambio,
    this.ayuda,
    this.error,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final ValueChanged<int> onCambio;
  final String? ayuda;
  final String? error;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controlador,
    keyboardType: TextInputType.number,
    inputFormatters: const [FormatoMilesCop()],
    onChanged: (v) => onCambio(FormatoMilesCop.leer(v)),
    decoration: decoracionCampo(
      etiqueta,
      ayuda: ayuda,
      prefijo: '\$ ',
    ).copyWith(errorText: error),
  );
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.etiqueta,
    required this.valorIso,
    required this.onCambio,
  });
  final String etiqueta;
  final String valorIso;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    final f = DateTime.tryParse(valorIso);
    return InkWell(
      hoverDuration: Cristal.micro,
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final hoy = DateTime.now();
        final r = await showDatePicker(
          context: context,
          initialDate: f ?? hoy,
          firstDate: DateTime(hoy.year - 2),
          lastDate: hoy,
          helpText: etiqueta,
        );
        if (r != null) onCambio(fechaIsoCorta(r));
      },
      child: InputDecorator(
        decoration: decoracionCampo(etiqueta)
            .copyWith(suffixIcon: const Icon(Icons.event_rounded)),
        child: Text(
          f == null ? 'dd/mm/aaaa' : fechaNumerica(f),
          style: TextStyle(
            color: f == null ? Cristal.textoTenue : Cristal.texto,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _FilaArchivo extends StatelessWidget {
  const _FilaArchivo({
    required this.archivo,
    required this.onAbrir,
    required this.onQuitar,
  });
  final ArchivoAdjunto archivo;
  final VoidCallback onAbrir;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(
          archivo.esPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
          size: 19,
          color: Cristal.texto,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            hoverDuration: Cristal.micro,
            onTap: onAbrir,
            child: Text(
              '${archivo.nombre} · ${archivo.tamanoLegible}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Cristal.texto,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Quitar',
          onPressed: onQuitar,
          icon: const Icon(
            Icons.close_rounded,
            size: 18,
            color: Cristal.textoSuave,
          ),
        ),
      ],
    ),
  );
}

class _FilaDocumento extends StatelessWidget {
  const _FilaDocumento({
    required this.documento,
    required this.archivos,
    required this.devuelto,
    required this.subiendo,
    required this.onAdjuntar,
    required this.onQuitar,
    required this.onAbrir,
  });

  final DocumentoPlantilla documento;
  final List<ArchivoAdjunto> archivos;
  final bool devuelto;
  final bool subiendo;
  final VoidCallback onAdjuntar;
  final ValueChanged<ArchivoAdjunto> onQuitar;
  final ValueChanged<ArchivoAdjunto> onAbrir;

  @override
  Widget build(BuildContext context) {
    final d = documento;
    final listo = archivos.isNotEmpty;
    // Fila plana; solo lo devuelto se resalta para que se vea qué reemplazar.
    return Container(
      padding: EdgeInsets.fromLTRB(devuelto ? 10 : 0, 12, 0, 12),
      decoration: devuelto
          ? BoxDecoration(
              color: Cristal.ambarVidrio,
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  devuelto
                      ? Icons.undo_rounded
                      : (listo
                            ? Icons.check_circle_rounded
                            : Icons.upload_file_rounded),
                  size: 20,
                  color: devuelto
                      ? Cristal.ambar
                      : (listo ? Cristal.verde : Cristal.textoSuave),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          d.nombre,
                          style: const TextStyle(
                            color: Cristal.texto,
                            fontSize: 13.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (d.regla != ReglaDocumento.cadaPeriodo)
                          EtiquetaColor(
                            texto: d.regla.etiqueta,
                            color: Cristal.acentoClaro,
                            fondo: Cristal.azulVidrio,
                          ),
                        if (devuelto)
                          const EtiquetaColor(
                            texto: 'Devuelto: reemplázalo',
                            color: Cristal.ambar,
                            fondo: Cristal.ambarVidrio,
                          ),
                      ],
                    ),
                    if (d.descripcion.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          d.descripcion,
                          style: const TextStyle(
                            color: Cristal.textoMedio,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    if (d.nota.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          d.nota,
                          style: const TextStyle(
                            color: Cristal.ambar,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: subiendo ? null : onAdjuntar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Cristal.texto,
                  side: const BorderSide(color: Cristal.borde),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  archivos.isEmpty
                      ? 'Adjuntar'
                      : (devuelto || archivos.length >= d.maxArchivos
                            ? 'Reemplazar'
                            : 'Agregar otro'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          for (final f in archivos)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 6),
              child: _FilaArchivo(
                archivo: f,
                onAbrir: () => onAbrir(f),
                onQuitar: () => onQuitar(f),
              ),
            ),
        ],
      ),
    );
  }
}
