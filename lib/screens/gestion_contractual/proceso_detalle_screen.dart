import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/modalidades_contratacion.dart';
import '../../services/borradores_proceso.dart';
import '../../services/equipo_juridico_service.dart';
import '../../services/juridico_contratacion_service.dart';
import '../../services/procesos_contratacion_service.dart';
import 'estilo_contractual.dart';

final NumberFormat _cop = NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$',
  decimalDigits: 0,
);

String _fechaLegible(DateTime? d) {
  if (d == null) return '—';
  const meses = [
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
  return '${d.day} ${meses[d.month - 1]} ${d.year}';
}

(Color, Color) _colorVerificacion(EstadoVerificacion e) => switch (e) {
  EstadoVerificacion.pendiente => (
    const Color(0xFF64748B),
    const Color(0xFFF1F5F9),
  ),
  EstadoVerificacion.cumple => (
    const Color(0xFF15803D),
    const Color(0xFFDCFCE7),
  ),
  EstadoVerificacion.subsanable => (
    const Color(0xFFB45309),
    const Color(0xFFFEF3C7),
  ),
  EstadoVerificacion.noCumple => (
    const Color(0xFFB91C1C),
    const Color(0xFFFEE2E2),
  ),
};

/// Tablero interno de un proceso que se adelanta en SECOP II: cronograma con
/// plazos legales, documentos y su publicación, observaciones, verificación
/// de ofertas, resultado y legalización. Ningún proponente entra aquí.
class ProcesoDetalleScreen extends StatefulWidget {
  const ProcesoDetalleScreen({super.key, required this.procesoId, this.stream});

  final String procesoId;

  /// Origen alterno de los datos, para pruebas.
  @visibleForTesting
  final Stream<ProcesoContratacion?>? stream;

  @override
  State<ProcesoDetalleScreen> createState() => _ProcesoDetalleScreenState();
}

enum _Pestana { cronograma, etapas, observaciones, verificacion, resultado }

class _ProcesoDetalleScreenState extends State<ProcesoDetalleScreen> {
  late final Stream<ProcesoContratacion?> _stream =
      widget.stream ??
      ProcesosContratacionService.escucharProceso(widget.procesoId);
  _Pestana _pestana = _Pestana.cronograma;
  int? _etapaVista;
  bool _ocupado = false;
  EstadoProcesoSecop? _secop;
  bool _consultandoSecop = false;

  bool get _puedeGestionar =>
      EquipoJuridicoService.tienePermiso(PermisoEquipo.crearContratos);
  bool get _puedeVerificar =>
      EquipoJuridicoService.tienePermiso(PermisoEquipo.verificarDocumentos);
  bool get _puedeResponder =>
      EquipoJuridicoService.tienePermiso(PermisoEquipo.pedirDocumentos);

  void _mensaje(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error
              ? const Color(0xFFB91C1C)
              : EstiloContractual.navy,
        ),
      );
  }

  Future<void> _ejecutar(
    Future<void> Function() accion, [
    String? exito,
  ]) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await accion();
      if (exito != null) _mensaje(exito);
    } on ProcesoContratacionException catch (e) {
      _mensaje(e.message, error: true);
    } catch (_) {
      _mensaje(
        'No fue posible completar la acción. Revisa tu conexión.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<DateTime?> _elegirFecha({DateTime? inicial, String ayuda = 'Fecha'}) {
    final hoy = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: inicial ?? hoy,
      firstDate: DateTime(hoy.year - 3),
      lastDate: DateTime(hoy.year + 3),
      helpText: ayuda,
    );
  }

  Future<void> _consultarSecop(ProcesoContratacion p) async {
    setState(() => _consultandoSecop = true);
    try {
      final r = await ProcesosContratacionService.consultarSecop(p);
      if (!mounted) return;
      setState(() => _secop = r);
      if (r == null) {
        _mensaje(
          'SECOP II aún no reporta este proceso en Datos Abiertos (se actualiza a diario).',
          error: true,
        );
      }
    } on ProcesoContratacionException catch (e) {
      _mensaje(e.message, error: true);
    } catch (_) {
      _mensaje(
        'No fue posible consultar SECOP II. Revisa tu conexión.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _consultandoSecop = false);
    }
  }

  String? _urlSecop(ProcesoContratacion p) {
    if (p.urlSecop.isNotEmpty) return p.urlSecop;
    if (_secop?.url.isNotEmpty ?? false) return _secop!.url;
    final id = p.idProcesoSecop;
    if (id.contains('.NTC.')) {
      return 'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=$id';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProcesoContratacion?>(
      stream: _stream,
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) {
          return PantallaContractual(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: PildoraVolver(
                  etiqueta: 'Gestión contractual',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 60),
              Center(
                child: snap.hasError
                    ? const Text('No tienes acceso a este proceso o no existe.')
                    : const CircularProgressIndicator(),
              ),
            ],
          );
        }
        final mobile = MediaQuery.sizeOf(context).width < 980;
        final contenido = <Widget>[
          _AvisoApoyo(esDirecta: p.esDirecta),
          const SizedBox(height: 14),
          _VinculoSecop(
            proceso: p,
            secop: _secop,
            consultando: _consultandoSecop,
            url: _urlSecop(p),
            puedeEditar: _puedeGestionar,
            onEditar: () => _editarVinculo(p),
            onConsultar: () => _consultarSecop(p),
          ),
          const SizedBox(height: 14),
          _Alertas(proceso: p, onIr: (t) => setState(() => _pestana = t)),
          _Pestanas(
            proceso: p,
            actual: _pestana,
            onCambiar: (t) => setState(() => _pestana = t),
          ),
          const SizedBox(height: 14),
          switch (_pestana) {
            _Pestana.cronograma => _panelCronograma(p),
            _Pestana.etapas => _panelEtapas(p),
            _Pestana.observaciones => _panelObservaciones(p),
            _Pestana.verificacion => _panelVerificacion(p),
            _Pestana.resultado => _panelResultado(p),
          },
        ];

        return PantallaContractual(
          anchoMaximo: 1240,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PildoraVolver(
                etiqueta: 'Gestión contractual',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 18),
            _Encabezado(proceso: p),
            const SizedBox(height: 14),
            if (mobile) ...[
              ...contenido,
              const SizedBox(height: 16),
              _Trazabilidad(proceso: p),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: contenido,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(flex: 3, child: _Trazabilidad(proceso: p)),
                ],
              ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // Cronograma
  // ===========================================================================

  Widget _panelCronograma(ProcesoContratacion p) {
    final estados = p.evaluarCronograma();
    if (estados.isEmpty) {
      return const _Vacio(
        texto: 'Esta modalidad no define hitos de cronograma.',
      );
    }
    return _Tarjeta(
      titulo: 'Cronograma y plazos legales',
      subtitulo:
          'Registra las fechas tal como quedaron en SECOP II. Los plazos se cuentan en días hábiles, '
          'sin fines de semana ni festivos de Colombia.',
      children: [
        for (final e in estados) ...[
          _FilaHito(
            estado: e,
            puedeEditar: _puedeGestionar && !_ocupado,
            onElegir: () async {
              final f = await _elegirFecha(
                inicial: e.fecha ?? e.limite,
                ayuda: e.hito.nombre,
              );
              if (f != null) {
                await _ejecutar(
                  () => ProcesosContratacionService.registrarFechaHito(
                    p,
                    e.hito,
                    f,
                  ),
                );
              }
            },
            onQuitar: e.fecha == null
                ? null
                : () => _ejecutar(
                    () => ProcesosContratacionService.registrarFechaHito(
                      p,
                      e.hito,
                      null,
                    ),
                  ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
      ],
    );
  }

  // ===========================================================================
  // Etapas y documentos internos
  // ===========================================================================

  Widget _panelEtapas(ProcesoContratacion p) {
    final etapas = p.modalidad.etapas;
    if (etapas.isEmpty) {
      return const _Vacio(texto: 'Esta modalidad no define etapas.');
    }
    final indice = (_etapaVista ?? p.etapaActual).clamp(0, etapas.length - 1);
    final etapa = etapas[indice];
    final hoy = DateTime.now();
    final enCurso = p.estado == EstadoProceso.enCurso;
    final responsable = p.responsables[etapa.id] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LineaEtapas(
          proceso: p,
          vista: indice,
          onElegir: (i) => setState(() => _etapaVista = i),
        ),
        const SizedBox(height: 14),
        _Tarjeta(
          titulo: 'Etapa ${indice + 1} · ${etapa.nombre}',
          subtitulo: etapa.descripcion,
          accion: _puedeGestionar
              ? TextButton.icon(
                  onPressed: () => _asignarResponsable(p, etapa),
                  icon: const Icon(Icons.person_outline_rounded, size: 17),
                  label: Text(
                    responsable.isEmpty
                        ? 'Asignar responsable'
                        : 'Responsable: $responsable',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: EstiloContractual.navy,
                  ),
                )
              : (responsable.isEmpty
                    ? null
                    : Text(
                        'Responsable: $responsable',
                        style: const TextStyle(color: EstiloContractual.gris),
                      )),
          children: [
            if (etapa.plazo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: Color(0xFFB45309),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        etapa.plazo!,
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final d in etapa.documentosEntidad) ...[
              _FilaDocumento(
                documento: d,
                cargado: p.documentosEntidad[d.id],
                hoy: hoy,
                puedeEditar: _puedeGestionar && !_ocupado && enCurso,
                onCargar: () => _ejecutar(
                  () =>
                      ProcesosContratacionService.cargarDocumentoEntidad(p, d),
                  '${d.nombre} cargado. Recuerda publicarlo en SECOP II.',
                ),
                onDescargar: () => _ejecutar(
                  () => ProcesosContratacionService.descargarDocumentoEntidad(
                    p,
                    d.id,
                  ),
                ),
                onPublicado: (publicado) async {
                  DateTime? fecha;
                  if (publicado) {
                    fecha = await _elegirFecha(
                      ayuda: 'Fecha de publicación en SECOP II',
                    );
                    if (fecha == null) return;
                  }
                  await _ejecutar(
                    () => ProcesosContratacionService.marcarPublicacion(
                      p,
                      d,
                      publicado: publicado,
                      fecha: fecha,
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ],
            if (indice == p.etapaActual && enCurso && _puedeGestionar) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  if (indice > 0)
                    OutlinedButton(
                      onPressed: _ocupado
                          ? null
                          : () => _ejecutar(() async {
                              await ProcesosContratacionService.retrocederEtapa(
                                p,
                              );
                              setState(() => _etapaVista = null);
                            }),
                      style: EstiloContractual.botonSecundario(),
                      child: const Text(
                        'Regresar etapa',
                        style: EstiloContractual.etiquetaBoton,
                      ),
                    ),
                  if (indice < etapas.length - 1)
                    FilledButton.icon(
                      onPressed: _ocupado
                          ? null
                          : () => _ejecutar(() async {
                              await ProcesosContratacionService.avanzarEtapa(p);
                              setState(() => _etapaVista = null);
                            }, 'Etapa completada.'),
                      style: EstiloContractual.botonPrincipal(),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text(
                        'Completar etapa',
                        style: EstiloContractual.etiquetaBoton,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // Observaciones y respuestas
  // ===========================================================================

  Widget _panelObservaciones(ProcesoContratacion p) {
    final etapas = {for (final e in p.modalidad.etapas) e.id: e.nombre};
    return _Tarjeta(
      titulo: 'Observaciones y respuestas',
      subtitulo:
          'Registra las observaciones recibidas en SECOP II y proyecta las respuestas. '
          'El documento de respuestas se publica en SECOP II.',
      accion: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (p.observaciones.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () =>
                  BorradoresProceso.descargarRespuestasObservaciones(p),
              style: EstiloContractual.botonSecundario(),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text(
                'Borrador de respuestas',
                style: EstiloContractual.etiquetaBoton,
              ),
            ),
          if (_puedeResponder)
            FilledButton.icon(
              onPressed: _ocupado ? null : () => _registrarObservacion(p),
              style: EstiloContractual.botonPrincipal(),
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: const Text(
                'Registrar observación',
                style: EstiloContractual.etiquetaBoton,
              ),
            ),
        ],
      ),
      children: [
        if (p.observaciones.isEmpty)
          const _TextoVacio('Aún no hay observaciones registradas.'),
        for (final o in p.observaciones) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      o.interesado.isEmpty ? 'Interesado' : o.interesado,
                      style: const TextStyle(
                        color: EstiloContractual.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${o.fechaIso} · ${etapas[o.etapaId] ?? ''}',
                      style: const TextStyle(
                        color: EstiloContractual.gris,
                        fontSize: 12,
                      ),
                    ),
                    EtiquetaColor(
                      texto: o.respondida ? 'Respondida' : 'Pendiente',
                      color: o.respondida
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                      fondo: o.respondida
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  o.texto,
                  style: const TextStyle(
                    color: EstiloContractual.texto,
                    fontSize: 13.2,
                  ),
                ),
                if (o.respondida) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'Respuesta${o.responsable.isEmpty ? '' : ' (${o.responsable})'}: ${o.respuesta}',
                      style: const TextStyle(
                        color: EstiloContractual.navy,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                if (_puedeResponder)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _ocupado
                          ? null
                          : () => _responderObservacion(p, o),
                      style: TextButton.styleFrom(
                        foregroundColor: EstiloContractual.navy,
                      ),
                      child: Text(
                        o.respondida
                            ? 'Editar respuesta'
                            : 'Proyectar respuesta',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
      ],
    );
  }

  // ===========================================================================
  // Verificación de ofertas (o del contratista)
  // ===========================================================================

  Widget _panelVerificacion(ProcesoContratacion p) {
    final requisitos = p.requisitosVerificacion;
    final ofertas = BorradoresProceso.ordenElegibilidad(p);
    final directa = p.esDirecta;
    return _Tarjeta(
      titulo: directa
          ? 'Verificación del contratista'
          : 'Verificación de ofertas',
      subtitulo: directa
          ? 'Verifica los documentos que el contratista aportó en SECOP II.'
          : 'Registra las ofertas recibidas en SECOP II y verifica cada requisito. '
                'Toca una celda para cambiar su estado. ${p.modalidad.criterioEvaluacion ?? ''}',
      accion: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (ofertas.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => BorradoresProceso.descargarInformeEvaluacion(p),
              style: EstiloContractual.botonSecundario(),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(
                directa ? 'Borrador de verificación' : 'Borrador del informe',
                style: EstiloContractual.etiquetaBoton,
              ),
            ),
          if (_puedeVerificar && (!directa || p.ofertas.isEmpty))
            FilledButton.icon(
              onPressed: _ocupado ? null : () => _registrarOferta(p),
              style: EstiloContractual.botonPrincipal(),
              icon: const Icon(Icons.post_add_rounded, size: 18),
              label: Text(
                directa ? 'Registrar contratista' : 'Registrar oferta',
                style: EstiloContractual.etiquetaBoton,
              ),
            ),
        ],
      ),
      children: [
        if (ofertas.isEmpty)
          _TextoVacio(
            directa ? 'Registra al contratista para verificar sus documentos.' : 'Aún no hay ofertas registradas. Regístralas cuando se reciban en SECOP II.',
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _Matriz(
              requisitos: requisitos,
              ofertas: ofertas,
              puedeEditar: _puedeVerificar && !_ocupado,
              onCelda: (o, r) => _verificarCelda(p, o, r),
              onCalificar: (o) => _calificar(p, o),
              onQuitar: (o) => _ejecutar(
                () => ProcesosContratacionService.quitarOferta(p, o),
              ),
              mostrarCalificacion: !directa,
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // Resultado y legalización
  // ===========================================================================

  Widget _panelResultado(ProcesoContratacion p) {
    final r = p.resultado;
    final directa = p.esDirecta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Tarjeta(
          titulo: directa
              ? 'Contrato suscrito en SECOP II'
              : 'Resultado publicado en SECOP II',
          subtitulo: 'La decisión se toma y se publica en SECOP II; aquí se deja constancia para el seguimiento interno.',
          accion: _puedeVerificar
              ? FilledButton.icon(
                  onPressed: _ocupado ? null : () => _registrarResultado(p),
                  style: EstiloContractual.botonPrincipal(),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(
                    r == null ? 'Registrar resultado' : 'Actualizar resultado',
                    style: EstiloContractual.etiquetaBoton,
                  ),
                )
              : null,
          children: [
            if (_secop != null && _secop!.adjudicado)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'SECOP II reporta adjudicación a ${_secop!.proveedorAdjudicado} por ${_cop.format(_secop!.valorAdjudicado)}.',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (r == null)
              const _TextoVacio('Aún no se ha registrado el resultado.')
            else
              Text(
                r.adjudicado
                    ? '${directa ? 'Contrato con' : 'Adjudicado a'} ${r.proponente}'
                          '${r.valorCop > 0 ? ' por ${_cop.format(r.valorCop)}' : ''} · '
                          '${r.actoNumero.isEmpty ? '' : 'Acto ${r.actoNumero} · '}${r.fechaIso}'
                    : 'Declarado desierto · ${r.actoNumero.isEmpty ? '' : 'Acto ${r.actoNumero} · '}${r.fechaIso}'
                          '${r.motivo.isEmpty ? '' : '\nMotivo: ${r.motivo}'}',
                style: const TextStyle(
                  color: EstiloContractual.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        if (r != null && r.adjudicado && !directa) ...[
          const SizedBox(height: 14),
          _Tarjeta(
            titulo: 'Legalización del contrato',
            subtitulo: 'Verifica en SECOP II los documentos de legalización del adjudicatario.',
            children: [
              for (final d in p.modalidad.documentosContrato) ...[
                _FilaLegalizacion(
                  requisito: d,
                  verificacion: p.legalizacion[d.id],
                  puedeEditar: _puedeVerificar && !_ocupado,
                  onTap: () async {
                    final v = await _dialogoVerificacion(
                      d,
                      p.legalizacion[d.id],
                    );
                    if (v != null) {
                      await _ejecutar(
                        () => ProcesosContratacionService.verificarLegalizacion(
                          p,
                          d,
                          v,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ],
            ],
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // Diálogos
  // ===========================================================================

  Future<void> _editarVinculo(ProcesoContratacion p) async {
    final id = TextEditingController(text: p.idProcesoSecop);
    final url = TextEditingController(text: p.urlSecop);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _Dialogo(
        titulo: 'Proceso en SECOP II',
        detalle: 'Copia el ID del proceso (p. ej. CO1.REQ.1234567 o CO1.NTC.1234567) y, si quieres, el enlace público.',
        accion: 'Guardar',
        campos: [
          _campo(id, 'ID del proceso en SECOP II'),
          _campo(url, 'Enlace del proceso (opcional)'),
        ],
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.actualizarVinculoSecop(
          p,
          idProceso: id.text,
          url: url.text,
        ),
        'Proceso vinculado.',
      );
    }
  }

  Future<void> _asignarResponsable(
    ProcesoContratacion p,
    EtapaProceso etapa,
  ) async {
    final c = TextEditingController(text: p.responsables[etapa.id] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _Dialogo(
        titulo: 'Responsable de "${etapa.nombre}"',
        detalle: 'Nombre del abogado del equipo que lleva esta etapa.',
        accion: 'Guardar',
        campos: [_campo(c, 'Nombre')],
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.asignarResponsable(p, etapa, c.text),
      );
    }
  }

  Future<void> _registrarObservacion(ProcesoContratacion p) async {
    final interesado = TextEditingController();
    final texto = TextEditingController();
    var etapaId = p.modalidad.etapas.isEmpty
        ? ''
        : p
              .modalidad
              .etapas[p.etapaActual.clamp(0, p.modalidad.etapas.length - 1)]
              .id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => _Dialogo(
          titulo: 'Registrar observación',
          detalle: 'Transcribe la observación tal como se recibió en SECOP II.',
          accion: 'Registrar',
          campos: [
            _campo(interesado, 'Interesado (persona o empresa)'),
            if (p.modalidad.etapas.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: etapaId,
                isExpanded: true,
                decoration: _decoracion('Etapa'),
                items: [
                  for (final e in p.modalidad.etapas)
                    DropdownMenuItem(
                      value: e.id,
                      child: Text(e.nombre, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setD(() => etapaId = v ?? etapaId),
              ),
            _campo(texto, 'Observación', lineas: 5),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.registrarObservacion(
          p,
          interesado: interesado.text,
          texto: texto.text,
          etapaId: etapaId,
        ),
        'Observación registrada.',
      );
    }
  }

  Future<void> _responderObservacion(
    ProcesoContratacion p,
    ObservacionProceso o,
  ) async {
    final respuesta = TextEditingController(text: o.respuesta);
    final responsable = TextEditingController(text: o.responsable);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _Dialogo(
        titulo:
            'Respuesta a ${o.interesado.isEmpty ? 'la observación' : o.interesado}',
        detalle: o.texto,
        accion: 'Guardar respuesta',
        campos: [
          _campo(respuesta, 'Respuesta de la entidad', lineas: 6),
          _campo(responsable, 'Abogado que la proyecta'),
        ],
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.responderObservacion(
          p,
          o,
          respuesta: respuesta.text,
          responsable: responsable.text,
        ),
        'Respuesta guardada.',
      );
    }
  }

  Future<void> _registrarOferta(ProcesoContratacion p) async {
    final nombre = TextEditingController();
    final nit = TextEditingController();
    final valor = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _Dialogo(
        titulo: p.esDirecta
            ? 'Registrar contratista'
            : 'Registrar oferta recibida en SECOP II',
        detalle: p.esDirecta
            ? 'Datos del contratista para verificar sus documentos.'
            : 'Copia los datos de la oferta tal como aparece en SECOP II.',
        accion: 'Registrar',
        campos: [
          _campo(nombre, p.esDirecta ? 'Contratista' : 'Proponente'),
          _campo(nit, 'NIT o cédula', numerico: true),
          _campo(
            valor,
            p.esDirecta ? 'Valor del contrato (COP)' : 'Valor ofertado (COP)',
            numerico: true,
          ),
        ],
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.registrarOferta(
          p,
          proponente: nombre.text,
          nit: nit.text,
          valorCop: int.tryParse(valor.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
          fechaRecepcion: p.fechaHito('cierre'),
        ),
        'Registrada. Ya puedes verificar sus requisitos.',
      );
    }
  }

  Future<VerificacionRequisito?> _dialogoVerificacion(
    DocumentoRequerido requisito,
    VerificacionRequisito? actual,
  ) async {
    var estado = actual?.estado ?? EstadoVerificacion.pendiente;
    final obs = TextEditingController(text: actual?.observacion ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => _Dialogo(
          titulo: requisito.nombre,
          detalle: requisito.descripcion,
          accion: 'Guardar',
          campos: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in EstadoVerificacion.values)
                  ChoiceChip(
                    label: Text(e.etiqueta),
                    selected: estado == e,
                    onSelected: (_) => setD(() => estado = e),
                    selectedColor: _colorVerificacion(e).$2,
                    labelStyle: TextStyle(
                      color: _colorVerificacion(e).$1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            _campo(obs, 'Observación (folio, motivo, qué falta)', lineas: 3),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    return VerificacionRequisito(estado: estado, observacion: obs.text);
  }

  Future<void> _verificarCelda(
    ProcesoContratacion p,
    OfertaRecibida o,
    DocumentoRequerido r,
  ) async {
    final v = await _dialogoVerificacion(r, o.verificaciones[r.id]);
    if (v != null) {
      await _ejecutar(
        () => ProcesosContratacionService.verificarRequisito(p, o, r, v),
      );
    }
  }

  Future<void> _calificar(ProcesoContratacion p, OfertaRecibida o) async {
    final valor = TextEditingController(
      text: o.valorCop > 0 ? '${o.valorCop}' : '',
    );
    final puntaje = TextEditingController(text: o.puntaje?.toString() ?? '');
    final nota = TextEditingController(text: o.nota);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _Dialogo(
        titulo: 'Calificación de ${o.proponente}',
        detalle: p.modalidad.criterioEvaluacion ?? '',
        accion: 'Guardar',
        campos: [
          _campo(valor, 'Valor ofertado (COP)', numerico: true),
          _campo(puntaje, 'Puntaje', numerico: true),
          _campo(nota, 'Observaciones de la evaluación', lineas: 3),
        ],
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.calificarOferta(
          p,
          o,
          valorCop: int.tryParse(valor.text.replaceAll(RegExp(r'\D'), '')),
          puntaje: double.tryParse(puntaje.text.replaceAll(',', '.')),
          nota: nota.text,
        ),
        'Calificación guardada.',
      );
    }
  }

  Future<void> _registrarResultado(ProcesoContratacion p) async {
    var adjudicado = true;
    OfertaRecibida? oferta =
        p.ofertaAdjudicada ??
        (p.ofertas.isEmpty
            ? null
            : BorradoresProceso.ordenElegibilidad(p).first);
    final acto = TextEditingController(text: p.resultado?.actoNumero ?? '');
    final motivo = TextEditingController();
    DateTime fecha = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => _Dialogo(
          titulo: p.esDirecta
              ? 'Contrato suscrito en SECOP II'
              : 'Resultado publicado en SECOP II',
          detalle: 'Registra la decisión tal como quedó publicada en SECOP II.',
          accion: 'Registrar',
          campos: [
            if (!p.esDirecta)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Adjudicado')),
                  ButtonSegment(value: false, label: Text('Desierto')),
                ],
                selected: {adjudicado},
                onSelectionChanged: (v) => setD(() => adjudicado = v.first),
              ),
            if (adjudicado && !p.esDirecta && p.ofertas.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: oferta?.id,
                isExpanded: true,
                decoration: _decoracion('Oferta adjudicada'),
                items: [
                  for (final o in p.ofertas)
                    DropdownMenuItem(
                      value: o.id,
                      child: Text(
                        o.proponente,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) =>
                    setD(() => oferta = p.ofertas.firstWhere((o) => o.id == v)),
              ),
            _campo(
              acto,
              p.esDirecta
                  ? 'Número del contrato'
                  : 'Número del acto administrativo',
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final f = await _elegirFecha(inicial: fecha);
                if (f != null) setD(() => fecha = f);
              },
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text('Fecha: ${_fechaLegible(fecha)}'),
            ),
            if (!adjudicado)
              _campo(motivo, 'Motivo de la declaratoria', lineas: 3),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.registrarResultado(
          p,
          adjudicado: adjudicado,
          actoNumero: acto.text,
          fecha: fecha,
          oferta: oferta,
          motivo: motivo.text,
        ),
        'Resultado registrado.',
      );
    }
  }

  static InputDecoration _decoracion(String etiqueta) => InputDecoration(
    labelText: etiqueta,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  static Widget _campo(
    TextEditingController c,
    String etiqueta, {
    bool numerico = false,
    int lineas = 1,
  }) => TextField(
    controller: c,
    maxLines: lineas,
    keyboardType: numerico ? TextInputType.number : TextInputType.text,
    decoration: _decoracion(etiqueta),
  );
}

// =============================================================================
// Componentes
// =============================================================================

class _AvisoApoyo extends StatelessWidget {
  const _AvisoApoyo({required this.esDirecta});

  final bool esDirecta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF1D4ED8)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Herramienta de apoyo interno del equipo jurídico. El proceso oficial se adelanta en SECOP II: '
              'allí se publican los documentos, se reciben las ofertas y se adjudica. Los proponentes no ingresan a Contrata Legal.',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 12.8,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.proceso});

  final ProcesoContratacion proceso;

  @override
  Widget build(BuildContext context) {
    final p = proceso;
    final m = p.modalidad;
    final (colorEstado, fondoEstado) = switch (p.estado) {
      EstadoProceso.enCurso => (
        const Color(0xFF1D4ED8),
        const Color(0xFFDBEAFE),
      ),
      EstadoProceso.adjudicado => (
        const Color(0xFF15803D),
        const Color(0xFFDCFCE7),
      ),
      EstadoProceso.desierto => (
        const Color(0xFFB91C1C),
        const Color(0xFFFEE2E2),
      ),
    };
    final datos = <(String, String)>[
      ('Entidad', p.entidadNombre),
      if (p.dependencia.isNotEmpty) ('Dependencia', p.dependencia),
      ('Presupuesto oficial', _cop.format(p.presupuestoCop)),
      ('Plazo', p.plazoEjecucion),
      for (final c in m.campos)
        if ((p.campos[c.id] ?? '').isNotEmpty) (c.etiqueta, p.campos[c.id]!),
    ];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: EstiloContractual.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              EtiquetaColor(
                texto: m.nombre,
                color: m.color,
                fondo: m.fondo,
                icono: m.icono,
              ),
              EtiquetaColor(
                texto: p.estado.etiqueta,
                color: colorEstado,
                fondo: fondoEstado,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            p.numeroProceso,
            style: EstiloContractual.titulo.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 6),
          Text(p.objeto, style: EstiloContractual.subtitulo),
          const SizedBox(height: 16),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              for (final (etiqueta, valor) in datos)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      etiqueta.toUpperCase(),
                      style: EstiloContractual.seccion.copyWith(fontSize: 10.5),
                    ),
                    const SizedBox(height: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        valor,
                        style: const TextStyle(
                          color: EstiloContractual.navy,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VinculoSecop extends StatelessWidget {
  const _VinculoSecop({
    required this.proceso,
    required this.secop,
    required this.consultando,
    required this.url,
    required this.puedeEditar,
    required this.onEditar,
    required this.onConsultar,
  });

  final ProcesoContratacion proceso;
  final EstadoProcesoSecop? secop;
  final bool consultando;
  final String? url;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onConsultar;

  @override
  Widget build(BuildContext context) {
    final id = proceso.idProcesoSecop;
    final s = secop;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EstiloContractual.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.link_rounded, color: EstiloContractual.navy),
              Text(
                id.isEmpty ? 'Sin vincular a SECOP II' : 'SECOP II · $id',
                style: const TextStyle(
                  color: EstiloContractual.navy,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (puedeEditar)
                TextButton(
                  onPressed: onEditar,
                  style: TextButton.styleFrom(
                    foregroundColor: EstiloContractual.navy,
                  ),
                  child: Text(
                    id.isEmpty ? 'Vincular' : 'Editar',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              if (url != null)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(url!),
                    mode: LaunchMode.externalApplication,
                  ),
                  style: EstiloContractual.botonSecundario(),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text(
                    'Abrir en SECOP II',
                    style: EstiloContractual.etiquetaBoton,
                  ),
                ),
              OutlinedButton.icon(
                onPressed: consultando ? null : onConsultar,
                style: EstiloContractual.botonSecundario(),
                icon: consultando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.travel_explore_rounded, size: 17),
                label: const Text(
                  'Consultar estado',
                  style: EstiloContractual.etiquetaBoton,
                ),
              ),
            ],
          ),
          if (s != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _dato('Fase', s.fase),
                _dato('Estado', s.estado),
                _dato('Modalidad en SECOP', s.modalidad),
                _dato('Ofertas recibidas', '${s.ofertasRecibidas}'),
                if (s.manifestacionesInteres > 0)
                  _dato(
                    'Manifestaciones de interés',
                    '${s.manifestacionesInteres}',
                  ),
                _dato(
                  'Adjudicación',
                  s.adjudicado
                      ? '${s.proveedorAdjudicado} · ${_cop.format(s.valorAdjudicado)}'
                      : 'Sin adjudicar',
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Fuente: Datos Abiertos SECOP II (se actualiza a diario; puede tener un día de rezago).',
              style: TextStyle(color: EstiloContractual.gris, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _dato(String etiqueta, String valor) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        etiqueta.toUpperCase(),
        style: EstiloContractual.seccion.copyWith(fontSize: 10.5),
      ),
      const SizedBox(height: 2),
      Text(
        valor.isEmpty ? '—' : valor,
        style: const TextStyle(
          color: EstiloContractual.navy,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _Alertas extends StatelessWidget {
  const _Alertas({required this.proceso, required this.onIr});

  final ProcesoContratacion proceso;
  final ValueChanged<_Pestana> onIr;

  @override
  Widget build(BuildContext context) {
    final p = proceso;
    final cronograma = p.alertasCronograma;
    final publicaciones = p.publicacionesVencidas(DateTime.now());
    final pendientes = p.observaciones.where((o) => !o.respondida).length;
    final alertas = <(String, _Pestana)>[
      for (final e in cronograma)
        ('"${e.hito.nombre}" incumple el plazo legal', _Pestana.cronograma),
      if (publicaciones.isNotEmpty)
        (
          '${publicaciones.length} ${publicaciones.length == 1 ? 'documento lleva' : 'documentos llevan'} más de '
              '$diasHabilesPublicacionSecop días hábiles sin publicarse en SECOP II',
          _Pestana.etapas,
        ),
      if (pendientes > 0)
        (
          '$pendientes ${pendientes == 1 ? 'observación' : 'observaciones'} sin respuesta',
          _Pestana.observaciones,
        ),
    ];
    if (alertas.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (texto, destino) in alertas)
              InkWell(
                onTap: () => onIr(destino),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFC2410C),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          texto,
                          style: const TextStyle(
                            color: Color(0xFF9A3412),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFFC2410C),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pestanas extends StatelessWidget {
  const _Pestanas({
    required this.proceso,
    required this.actual,
    required this.onCambiar,
  });

  final ProcesoContratacion proceso;
  final _Pestana actual;
  final ValueChanged<_Pestana> onCambiar;

  @override
  Widget build(BuildContext context) {
    final p = proceso;
    final pestanas = <(_Pestana, String, IconData)>[
      (_Pestana.cronograma, 'Cronograma', Icons.event_note_rounded),
      (_Pestana.etapas, 'Etapas y documentos', Icons.folder_open_rounded),
      (
        _Pestana.observaciones,
        'Observaciones (${p.observaciones.length})',
        Icons.forum_outlined,
      ),
      (
        _Pestana.verificacion,
        p.esDirecta
            ? 'Verificación del contratista'
            : 'Verificación de ofertas (${p.ofertas.length})',
        Icons.rule_rounded,
      ),
      (_Pestana.resultado, 'Resultado y contrato', Icons.verified_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (t, texto, icono) in pestanas) ...[
            ChoiceChip(
              avatar: Icon(
                icono,
                size: 17,
                color: t == actual ? Colors.white : EstiloContractual.navy,
              ),
              label: Text(texto),
              selected: t == actual,
              showCheckmark: false,
              onSelected: (_) => onCambiar(t),
              selectedColor: EstiloContractual.navy,
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFD8DEE8)),
              labelStyle: TextStyle(
                color: t == actual ? Colors.white : EstiloContractual.navy,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              shape: const StadiumBorder(),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.titulo,
    required this.children,
    this.subtitulo,
    this.accion,
  });

  final String titulo;
  final String? subtitulo;
  final Widget? accion;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: EstiloContractual.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: EstiloContractual.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ?accion,
            ],
          ),
          if (subtitulo != null && subtitulo!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitulo!,
              style: const TextStyle(
                color: EstiloContractual.texto,
                fontSize: 12.8,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: EstiloContractual.tarjeta(),
    child: _TextoVacio(texto),
  );
}

class _TextoVacio extends StatelessWidget {
  const _TextoVacio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: const TextStyle(color: EstiloContractual.gris, fontSize: 13),
    ),
  );
}

class _FilaHito extends StatelessWidget {
  const _FilaHito({
    required this.estado,
    required this.puedeEditar,
    required this.onElegir,
    required this.onQuitar,
  });

  final EstadoHito estado;
  final bool puedeEditar;
  final VoidCallback onElegir;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final e = estado;
    final regla = e.hito.regla;
    final (icono, color) = switch (e.cumple) {
      true => (Icons.check_circle_rounded, const Color(0xFF15803D)),
      false => (Icons.error_rounded, const Color(0xFFB91C1C)),
      null => (
        e.fecha != null
            ? Icons.event_available_rounded
            : Icons.radio_button_unchecked_rounded,
        e.fecha != null ? EstiloContractual.navy : const Color(0xFFCBD5E1),
      ),
    };
    String? limite;
    if (regla != null && e.limite != null) {
      limite = regla.minimo
          ? 'No antes del ${_fechaLegible(e.limite)}'
          : 'A más tardar el ${_fechaLegible(e.limite)}';
    }
    final boton = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: puedeEditar ? onElegir : null,
          icon: const Icon(Icons.event_rounded, size: 16),
          label: Text(
            e.fecha == null ? 'Registrar fecha' : _fechaLegible(e.fecha),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: EstiloContractual.navy,
            side: const BorderSide(color: Color(0xFFD8DEE8)),
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (onQuitar != null && puedeEditar)
          IconButton(
            tooltip: 'Quitar fecha',
            onPressed: onQuitar,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: EstiloContractual.gris,
            ),
          ),
      ],
    );
    final angosto = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.hito.obligatorio
                      ? e.hito.nombre
                      : '${e.hito.nombre} · si aplica',
                  style: const TextStyle(
                    color: EstiloContractual.navy,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (regla != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${regla.descripcion}${regla.fundamento == null ? '' : ' (${regla.fundamento})'}',
                    style: const TextStyle(
                      color: EstiloContractual.gris,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (limite != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    e.cumple == false
                        ? 'Incumple: ${limite.toLowerCase()}'
                        : limite,
                    style: TextStyle(
                      color: e.cumple == false
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFFB45309),
                      fontSize: 12.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (angosto) ...[const SizedBox(height: 8), boton],
              ],
            ),
          ),
          if (!angosto) ...[const SizedBox(width: 8), boton],
        ],
      ),
    );
  }
}

class _LineaEtapas extends StatelessWidget {
  const _LineaEtapas({
    required this.proceso,
    required this.vista,
    required this.onElegir,
  });

  final ProcesoContratacion proceso;
  final int vista;
  final ValueChanged<int> onElegir;

  @override
  Widget build(BuildContext context) {
    final etapas = proceso.modalidad.etapas;
    final color = proceso.modalidad.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: EstiloContractual.tarjeta(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < etapas.length; i++) ...[
              if (i > 0)
                Container(
                  width: 22,
                  height: 2,
                  color: i <= proceso.etapaActual
                      ? color
                      : EstiloContractual.borde,
                ),
              InkWell(
                onTap: () => onElegir(i),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                  decoration: BoxDecoration(
                    color: i == vista ? proceso.modalidad.fondo : null,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: i < proceso.etapaActual
                            ? color
                            : (i == proceso.etapaActual
                                  ? EstiloContractual.navy
                                  : const Color(0xFFE2E8F0)),
                        child: i < proceso.etapaActual
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: i == proceso.etapaActual
                                      ? Colors.white
                                      : EstiloContractual.gris,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        etapas[i].nombre,
                        style: TextStyle(
                          color: i <= proceso.etapaActual
                              ? EstiloContractual.navy
                              : EstiloContractual.gris,
                          fontSize: 12.8,
                          fontWeight: i == vista
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaDocumento extends StatelessWidget {
  const _FilaDocumento({
    required this.documento,
    required this.cargado,
    required this.hoy,
    required this.puedeEditar,
    required this.onCargar,
    required this.onDescargar,
    required this.onPublicado,
  });

  final DocumentoRequerido documento;
  final DocumentoEntidadCargado? cargado;
  final DateTime hoy;
  final bool puedeEditar;
  final VoidCallback onCargar;
  final VoidCallback onDescargar;
  final ValueChanged<bool> onPublicado;

  @override
  Widget build(BuildContext context) {
    final d = documento;
    final c = cargado;
    final vencido = c != null && c.publicacionVencida(hoy);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            c == null
                ? Icons.radio_button_unchecked_rounded
                : (c.publicadoSecop
                      ? Icons.cloud_done_rounded
                      : Icons.check_circle_rounded),
            color: c == null
                ? const Color(0xFFCBD5E1)
                : (c.publicadoSecop
                      ? const Color(0xFF15803D)
                      : const Color(0xFF1D4ED8)),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.obligatorio ? d.nombre : '${d.nombre} · si aplica',
                  style: const TextStyle(
                    color: EstiloContractual.navy,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c != null
                      ? '${c.archivoNombre} · ${c.cargadoPor} · ${JuridicoContratacionService.formatearFechaHumana(c.fechaIso)}'
                      : d.descripcion,
                  style: const TextStyle(
                    color: EstiloContractual.gris,
                    fontSize: 12.3,
                  ),
                ),
                if (c == null && d.fundamento != null)
                  Text(
                    d.fundamento!,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (c != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: c.publicadoSecop,
                          onChanged: puedeEditar
                              ? (v) => onPublicado(v ?? false)
                              : null,
                          activeColor: const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          c.publicadoSecop
                              ? 'Publicado en SECOP II el ${c.fechaPublicacionIso}'
                              : (vencido
                                    ? 'Sin publicar en SECOP II hace ${c.diasSinPublicar(hoy)} días hábiles (máximo $diasHabilesPublicacionSecop · $fundamentoPublicacionSecop)'
                                    : 'Pendiente de publicar en SECOP II'),
                          style: TextStyle(
                            color: c.publicadoSecop
                                ? const Color(0xFF15803D)
                                : (vencido
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFFB45309)),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (c != null)
            IconButton(
              tooltip: 'Descargar',
              onPressed: onDescargar,
              icon: const Icon(
                Icons.download_rounded,
                color: EstiloContractual.navy,
              ),
            ),
          if (puedeEditar)
            TextButton(
              onPressed: onCargar,
              style: TextButton.styleFrom(
                foregroundColor: EstiloContractual.navy,
              ),
              child: Text(
                c != null ? 'Reemplazar' : 'Cargar',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

/// Matriz requisitos × ofertas con el estado de cada verificación.
class _Matriz extends StatelessWidget {
  const _Matriz({
    required this.requisitos,
    required this.ofertas,
    required this.puedeEditar,
    required this.onCelda,
    required this.onCalificar,
    required this.onQuitar,
    required this.mostrarCalificacion,
  });

  final List<DocumentoRequerido> requisitos;
  final List<OfertaRecibida> ofertas;
  final bool puedeEditar;
  final void Function(OfertaRecibida, DocumentoRequerido) onCelda;
  final ValueChanged<OfertaRecibida> onCalificar;
  final ValueChanged<OfertaRecibida> onQuitar;
  final bool mostrarCalificacion;

  static const double _anchoRequisito = 250;
  static const double _anchoOferta = 170;

  @override
  Widget build(BuildContext context) {
    Widget fila(List<Widget> celdas) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: celdas,
      ),
    );

    Widget celda(Widget hijo, {double ancho = _anchoOferta, Color? fondo}) =>
        Container(
          width: ancho,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: fondo,
            border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          alignment: Alignment.centerLeft,
          child: hijo,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fila([
          celda(
            const Text(
              'Requisito',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: EstiloContractual.navy,
              ),
            ),
            ancho: _anchoRequisito,
            fondo: const Color(0xFFF8FAFC),
          ),
          for (final (i, o) in ofertas.indexed)
            celda(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${mostrarCalificacion ? '${i + 1}. ' : ''}${o.proponente}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: EstiloContractual.navy,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    o.nit,
                    style: const TextStyle(
                      color: EstiloContractual.gris,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              fondo: const Color(0xFFF8FAFC),
            ),
        ]),
        for (final r in requisitos)
          fila([
            celda(
              Text(
                r.obligatorio ? r.nombre : '${r.nombre} (si aplica)',
                style: const TextStyle(
                  color: EstiloContractual.navy,
                  fontSize: 12.3,
                ),
              ),
              ancho: _anchoRequisito,
            ),
            for (final o in ofertas)
              celda(
                _EstadoCelda(
                  verificacion: o.verificaciones[r.id],
                  onTap: puedeEditar ? () => onCelda(o, r) : null,
                ),
              ),
          ]),
        fila([
          celda(
            const Text(
              'Resultado',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: EstiloContractual.navy,
              ),
            ),
            ancho: _anchoRequisito,
            fondo: const Color(0xFFF8FAFC),
          ),
          for (final o in ofertas)
            celda(
              Text(
                ResultadoVerificacion.calcular(
                  requisitos,
                  o.verificaciones,
                ).etiqueta,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: EstiloContractual.navy,
                  fontSize: 12.5,
                ),
              ),
              fondo: const Color(0xFFF8FAFC),
            ),
        ]),
        if (mostrarCalificacion)
          fila([
            celda(
              const Text(
                'Valor y puntaje',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: EstiloContractual.navy,
                ),
              ),
              ancho: _anchoRequisito,
            ),
            for (final o in ofertas)
              celda(
                Text(
                  '${o.valorCop > 0 ? _cop.format(o.valorCop) : 'Sin valor'}\n'
                  '${o.puntaje == null ? 'Sin puntaje' : 'Puntaje ${o.puntaje! == o.puntaje!.roundToDouble() ? o.puntaje!.toInt() : o.puntaje}'}',
                  style: const TextStyle(
                    color: EstiloContractual.texto,
                    fontSize: 12,
                  ),
                ),
              ),
          ]),
        if (puedeEditar)
          fila([
            celda(const SizedBox.shrink(), ancho: _anchoRequisito),
            for (final o in ofertas)
              celda(
                Wrap(
                  spacing: 2,
                  children: [
                    if (mostrarCalificacion)
                      TextButton(
                        onPressed: () => onCalificar(o),
                        style: TextButton.styleFrom(
                          foregroundColor: EstiloContractual.navy,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'Calificar',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Quitar del registro',
                      onPressed: () => onQuitar(o),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: EstiloContractual.gris,
                      ),
                    ),
                  ],
                ),
              ),
          ]),
      ],
    );
  }
}

class _EstadoCelda extends StatelessWidget {
  const _EstadoCelda({required this.verificacion, required this.onTap});

  final VerificacionRequisito? verificacion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final estado = verificacion?.estado ?? EstadoVerificacion.pendiente;
    final (color, fondo) = _colorVerificacion(estado);
    final obs = verificacion?.observacion ?? '';
    return Tooltip(
      message: obs.isEmpty ? 'Toca para verificar' : obs,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                estado.etiqueta,
                style: TextStyle(
                  color: color,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (obs.isNotEmpty) ...[
                const SizedBox(width: 4),
                Icon(Icons.sticky_note_2_outlined, size: 13, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaLegalizacion extends StatelessWidget {
  const _FilaLegalizacion({
    required this.requisito,
    required this.verificacion,
    required this.puedeEditar,
    required this.onTap,
  });

  final DocumentoRequerido requisito;
  final VerificacionRequisito? verificacion;
  final bool puedeEditar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requisito.obligatorio
                      ? requisito.nombre
                      : '${requisito.nombre} · si aplica',
                  style: const TextStyle(
                    color: EstiloContractual.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  (verificacion?.observacion ?? '').isEmpty
                      ? requisito.descripcion
                      : verificacion!.observacion,
                  style: const TextStyle(
                    color: EstiloContractual.gris,
                    fontSize: 12.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _EstadoCelda(
            verificacion: verificacion,
            onTap: puedeEditar ? onTap : null,
          ),
        ],
      ),
    );
  }
}

class _Trazabilidad extends StatelessWidget {
  const _Trazabilidad({required this.proceso});

  final ProcesoContratacion proceso;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: EstiloContractual.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trazabilidad',
            style: TextStyle(
              color: EstiloContractual.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: proceso.avanceDocumentosEntidad,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: proceso.modalidad.color,
            backgroundColor: const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 4),
          Text(
            '${(proceso.avanceDocumentosEntidad * 100).round()} % de los documentos internos obligatorios',
            style: const TextStyle(
              color: EstiloContractual.gris,
              fontSize: 11.8,
            ),
          ),
          const SizedBox(height: 14),
          for (final e in proceso.trazabilidad.take(25))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: proceso.modalidad.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.titulo,
                          style: const TextStyle(
                            color: EstiloContractual.navy,
                            fontSize: 12.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${e.actorNombre} · ${JuridicoContratacionService.formatearFechaHumana(e.fechaIso)}',
                          style: const TextStyle(
                            color: EstiloContractual.gris,
                            fontSize: 11.5,
                          ),
                        ),
                        if (e.detalle.isNotEmpty)
                          Text(
                            e.detalle,
                            style: const TextStyle(
                              color: EstiloContractual.texto,
                              fontSize: 11.8,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Dialogo extends StatelessWidget {
  const _Dialogo({
    required this.titulo,
    required this.detalle,
    required this.accion,
    required this.campos,
  });

  final String titulo;
  final String detalle;
  final String accion;
  final List<Widget> campos;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFEFBF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: EstiloContractual.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (detalle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  detalle,
                  style: const TextStyle(
                    color: EstiloContractual.texto,
                    fontSize: 13.2,
                  ),
                ),
              ],
              for (final c in campos) ...[const SizedBox(height: 12), c],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: EstiloContractual.botonPrincipal(),
                    child: Text(accion, style: EstiloContractual.etiquetaBoton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
