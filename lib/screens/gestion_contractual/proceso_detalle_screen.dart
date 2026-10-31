import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/modalidades_contratacion.dart';
import '../../services/equipo_juridico_service.dart';
import '../../services/juridico_contratacion_service.dart';
import '../../services/procesos_contratacion_service.dart';
import 'estilo_contractual.dart';

final NumberFormat _cop = NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$',
  decimalDigits: 0,
);

/// Proceso de contratación: etapas con sus documentos, oferentes (o el
/// contratista en contratación directa), evaluación, adjudicación y
/// trazabilidad. Se actualiza en tiempo real.
class ProcesoDetalleScreen extends StatefulWidget {
  const ProcesoDetalleScreen({
    super.key,
    required this.procesoId,
    this.onAbrirExpediente,
  });

  final String procesoId;
  final void Function(String tokenExpediente)? onAbrirExpediente;

  @override
  State<ProcesoDetalleScreen> createState() => _ProcesoDetalleScreenState();
}

class _ProcesoDetalleScreenState extends State<ProcesoDetalleScreen> {
  late final Stream<ProcesoContratacion?> _stream =
      ProcesosContratacionService.escucharProceso(widget.procesoId);
  int? _etapaVista;
  bool _ocupado = false;
  Map<String, ExpedienteContratoPs> _expedientes = {};

  @override
  void initState() {
    super.initState();
    JuridicoContratacionService.expedientesVersion.addListener(
      _cargarExpedientes,
    );
    _cargarExpedientes();
  }

  @override
  void dispose() {
    JuridicoContratacionService.expedientesVersion.removeListener(
      _cargarExpedientes,
    );
    super.dispose();
  }

  Future<void> _cargarExpedientes() async {
    final lista = await JuridicoContratacionService.listarExpedientes(
      releerAlmacenamiento: false,
    );
    if (!mounted) return;
    setState(() => _expedientes = {for (final e in lista) e.tokenInvitado: e});
  }

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
    } on ArgumentError catch (e) {
      _mensaje('${e.message}', error: true);
    } on StateError catch (e) {
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
        final mobile = MediaQuery.sizeOf(context).width < 900;
        final etapas = p.modalidad.etapas;
        final vista = (_etapaVista ?? p.etapaActual).clamp(
          0,
          etapas.isEmpty ? 0 : etapas.length - 1,
        );

        final principal = <Widget>[
          if (etapas.isNotEmpty) ...[
            _Etapas(
              proceso: p,
              etapaVista: vista,
              onElegir: (i) => setState(() => _etapaVista = i),
            ),
            const SizedBox(height: 16),
            _PanelEtapa(
              proceso: p,
              indice: vista,
              ocupado: _ocupado,
              onCargar: (d) => _ejecutar(
                () => ProcesosContratacionService.cargarDocumentoEntidad(p, d),
                '${d.nombre} cargado.',
              ),
              onDescargar: (d) => _ejecutar(
                () => ProcesosContratacionService.descargarDocumentoEntidad(
                  p,
                  d.id,
                ),
              ),
              onAvanzar: () => _ejecutar(() async {
                await ProcesosContratacionService.avanzarEtapa(p);
                setState(() => _etapaVista = null);
              }, 'Etapa completada.'),
              onRegresar: () => _ejecutar(() async {
                await ProcesosContratacionService.retrocederEtapa(p);
                setState(() => _etapaVista = null);
              }),
            ),
            const SizedBox(height: 16),
          ],
          _PanelOferentes(
            proceso: p,
            expedientes: _expedientes,
            ocupado: _ocupado,
            onRegistrar: () => _registrarOferente(p),
            onEvaluar: (o) => _evaluar(p, o),
            onAdjudicar: (o) => _confirmarAdjudicacion(p, o),
            onDesierto: () => _declararDesierto(p),
            onCopiarEnlace: (o) {
              Clipboard.setData(
                ClipboardData(
                  text: ProcesosContratacionService.enlaceOferente(o),
                ),
              );
              _mensaje(
                'Enlace de ${o.nombre} copiado. Compártelo junto con su número de documento.',
              );
            },
            onVerDocumentos: widget.onAbrirExpediente == null
                ? null
                : (o) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    widget.onAbrirExpediente!(o.tokenExpediente);
                  },
          ),
        ];

        return PantallaContractual(
          anchoMaximo: 1180,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PildoraVolver(
                etiqueta: 'Gestión contractual',
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ),
            const SizedBox(height: 20),
            _Encabezado(proceso: p),
            const SizedBox(height: 18),
            if (mobile) ...[
              ...principal,
              _Trazabilidad(proceso: p),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: principal,
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

  // ---------------------------------------------------------------------------
  // Diálogos
  // ---------------------------------------------------------------------------

  Future<void> _registrarOferente(ProcesoContratacion p) async {
    final directo = !p.modalidad.esCompetitiva;
    final nombre = TextEditingController();
    final documento = TextEditingController();
    final correo = TextEditingController();
    final telefono = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _Dialogo(
        titulo: directo ? 'Registrar contratista' : 'Registrar oferente',
        detalle: directo
            ? 'Se crea su enlace para cargar los documentos del contrato.'
            : 'Se crea su enlace para cargar la oferta y los ${p.modalidad.documentosOferente.length} requisitos habilitantes.',
        accion: 'Registrar y crear enlace',
        campos: [
          _campo(nombre, 'Nombre o razón social'),
          _campo(documento, 'NIT o cédula', numerico: true),
          _campo(correo, 'Correo electrónico'),
          _campo(telefono, 'Teléfono (opcional)'),
        ],
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.agregarOferente(
          p,
          nombre: nombre.text,
          documento: documento.text,
          correo: correo.text,
          telefono: telefono.text,
        ),
        directo
            ? 'Contratista registrado.'
            : 'Oferente registrado. Copia su enlace para enviárselo.',
      );
    }
  }

  Future<void> _evaluar(ProcesoContratacion p, OferenteProceso o) async {
    final valor = TextEditingController(
      text: o.valorOfertaCop > 0 ? '${o.valorOfertaCop}' : '',
    );
    final puntaje = TextEditingController(text: o.puntaje?.toString() ?? '');
    final observacion = TextEditingController(text: o.observacion);
    var habilitado = o.estado != EstadoOferente.noHabilitado;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => _Dialogo(
          titulo: 'Evaluar a ${o.nombre}',
          detalle: p.modalidad.criterioEvaluacion ?? '',
          accion: 'Guardar evaluación',
          campos: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Habilitado')),
                ButtonSegment(value: false, label: Text('No habilitado')),
              ],
              selected: {habilitado},
              onSelectionChanged: (v) => setD(() => habilitado = v.first),
            ),
            _campo(valor, 'Valor de la oferta (COP)', numerico: true),
            _campo(puntaje, 'Puntaje (opcional)', numerico: true),
            _campo(observacion, 'Observación', lineas: 3),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.evaluarOferente(
          p,
          o,
          habilitado: habilitado,
          valorOfertaCop: int.tryParse(
            valor.text.replaceAll(RegExp(r'\D'), ''),
          ),
          puntaje: double.tryParse(puntaje.text.replaceAll(',', '.')),
          observacion: observacion.text,
        ),
        'Evaluación guardada.',
      );
    }
  }

  Future<void> _confirmarAdjudicacion(
    ProcesoContratacion p,
    OferenteProceso o,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _Dialogo(
        titulo: 'Adjudicar a ${o.nombre}',
        detalle:
            'Los demás oferentes quedan como no adjudicados y a ${o.nombre} se le piden por su '
            'mismo enlace los ${p.modalidad.documentosContrato.length} documentos de legalización del contrato. '
            'Esta acción cierra el proceso.',
        accion: 'Adjudicar',
        campos: const [],
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.adjudicar(p, o),
        'Proceso adjudicado a ${o.nombre}.',
      );
    }
  }

  Future<void> _declararDesierto(ProcesoContratacion p) async {
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _Dialogo(
        titulo: 'Declarar desierto',
        detalle: 'Procede cuando no hay ofertas o ninguna cumple. El motivo queda en la trazabilidad.',
        accion: 'Declarar desierto',
        peligro: true,
        campos: [_campo(motivo, 'Motivo', lineas: 3)],
      ),
    );
    if (ok == true) {
      await _ejecutar(
        () => ProcesosContratacionService.declararDesierto(p, motivo.text),
        'Proceso declarado desierto.',
      );
    }
  }

  static Widget _campo(
    TextEditingController c,
    String etiqueta, {
    bool numerico = false,
    int lineas = 1,
  }) => TextField(
    controller: c,
    maxLines: lineas,
    keyboardType: numerico ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(
      labelText: etiqueta,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// =============================================================================
// Componentes
// =============================================================================

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

/// Línea de etapas: completadas, en curso y pendientes.
class _Etapas extends StatelessWidget {
  const _Etapas({
    required this.proceso,
    required this.etapaVista,
    required this.onElegir,
  });

  final ProcesoContratacion proceso;
  final int etapaVista;
  final ValueChanged<int> onElegir;

  @override
  Widget build(BuildContext context) {
    final etapas = proceso.modalidad.etapas;
    final color = proceso.modalidad.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: EstiloContractual.tarjeta(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < etapas.length; i++) ...[
              if (i > 0)
                Container(
                  width: 26,
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
                    color: i == etapaVista ? proceso.modalidad.fondo : null,
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
                          fontWeight: i == etapaVista
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

class _PanelEtapa extends StatelessWidget {
  const _PanelEtapa({
    required this.proceso,
    required this.indice,
    required this.ocupado,
    required this.onCargar,
    required this.onDescargar,
    required this.onAvanzar,
    required this.onRegresar,
  });

  final ProcesoContratacion proceso;
  final int indice;
  final bool ocupado;
  final ValueChanged<DocumentoRequerido> onCargar;
  final ValueChanged<DocumentoRequerido> onDescargar;
  final VoidCallback onAvanzar;
  final VoidCallback onRegresar;

  @override
  Widget build(BuildContext context) {
    final etapa = proceso.modalidad.etapas[indice];
    final enCurso = proceso.estado == EstadoProceso.enCurso;
    final esActual = indice == proceso.etapaActual;
    final ultima = indice == proceso.modalidad.etapas.length - 1;
    final puedeEditar =
        enCurso &&
        EquipoJuridicoService.tienePermiso(PermisoEquipo.crearContratos);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: EstiloContractual.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Etapa ${indice + 1} · ${etapa.nombre}',
            style: const TextStyle(
              color: EstiloContractual.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            etapa.descripcion,
            style: const TextStyle(
              color: EstiloContractual.texto,
              fontSize: 13,
            ),
          ),
          if (etapa.plazo != null) ...[
            const SizedBox(height: 8),
            Row(
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
          ],
          const SizedBox(height: 14),
          for (final d in etapa.documentosEntidad) ...[
            _FilaDocumento(
              documento: d,
              cargado: proceso.documentosEntidad[d.id],
              puedeEditar: puedeEditar && !ocupado,
              onCargar: () => onCargar(d),
              onDescargar: () => onDescargar(d),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ],
          if (esActual && enCurso) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                if (indice > 0)
                  OutlinedButton(
                    onPressed: ocupado || !puedeEditar ? null : onRegresar,
                    style: EstiloContractual.botonSecundario(),
                    child: const Text(
                      'Regresar etapa',
                      style: EstiloContractual.etiquetaBoton,
                    ),
                  ),
                if (!ultima)
                  FilledButton.icon(
                    onPressed: ocupado || !puedeEditar ? null : onAvanzar,
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
    );
  }
}

class _FilaDocumento extends StatelessWidget {
  const _FilaDocumento({
    required this.documento,
    required this.cargado,
    required this.puedeEditar,
    required this.onCargar,
    required this.onDescargar,
  });

  final DocumentoRequerido documento;
  final DocumentoEntidadCargado? cargado;
  final bool puedeEditar;
  final VoidCallback onCargar;
  final VoidCallback onDescargar;

  @override
  Widget build(BuildContext context) {
    final d = documento;
    final c = cargado;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            c != null
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: c != null
                ? const Color(0xFF15803D)
                : const Color(0xFFCBD5E1),
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
                if (d.fundamento != null && c == null) ...[
                  const SizedBox(height: 2),
                  Text(
                    d.fundamento!,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    ),
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

class _PanelOferentes extends StatelessWidget {
  const _PanelOferentes({
    required this.proceso,
    required this.expedientes,
    required this.ocupado,
    required this.onRegistrar,
    required this.onEvaluar,
    required this.onAdjudicar,
    required this.onDesierto,
    required this.onCopiarEnlace,
    required this.onVerDocumentos,
  });

  final ProcesoContratacion proceso;
  final Map<String, ExpedienteContratoPs> expedientes;
  final bool ocupado;
  final VoidCallback onRegistrar;
  final ValueChanged<OferenteProceso> onEvaluar;
  final ValueChanged<OferenteProceso> onAdjudicar;
  final VoidCallback onDesierto;
  final ValueChanged<OferenteProceso> onCopiarEnlace;
  final ValueChanged<OferenteProceso>? onVerDocumentos;

  @override
  Widget build(BuildContext context) {
    final p = proceso;
    final directo = !p.modalidad.esCompetitiva;
    final enCurso = p.estado == EstadoProceso.enCurso;
    // Orden de elegibilidad: mayor puntaje y, a igualdad, menor valor.
    final oferentes = [...p.oferentes]
      ..sort((a, b) {
        final pa = a.puntaje ?? -1, pb = b.puntaje ?? -1;
        if (pa != pb) return pb.compareTo(pa);
        final va = a.valorOfertaCop == 0 ? 1 << 62 : a.valorOfertaCop;
        final vb = b.valorOfertaCop == 0 ? 1 << 62 : b.valorOfertaCop;
        return va.compareTo(vb);
      });
    final puedeRegistrar =
        enCurso &&
        (!directo || p.oferentes.isEmpty) &&
        EquipoJuridicoService.tienePermiso(PermisoEquipo.pedirDocumentos);
    final puedeEvaluar =
        enCurso &&
        EquipoJuridicoService.tienePermiso(PermisoEquipo.verificarDocumentos);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: EstiloContractual.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                directo ? 'Contratista' : 'Oferentes (${p.oferentes.length})',
                style: const TextStyle(
                  color: EstiloContractual.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (!directo && puedeEvaluar)
                    TextButton(
                      onPressed: ocupado ? null : onDesierto,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                      ),
                      child: const Text(
                        'Declarar desierto',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (puedeRegistrar)
                    FilledButton.icon(
                      onPressed: ocupado ? null : onRegistrar,
                      style: EstiloContractual.botonPrincipal(),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: Text(
                        directo
                            ? 'Registrar contratista'
                            : 'Registrar oferente',
                        style: EstiloContractual.etiquetaBoton,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (!directo && p.modalidad.criterioEvaluacion != null) ...[
            const SizedBox(height: 4),
            Text(
              'Criterio: ${p.modalidad.criterioEvaluacion}',
              style: const TextStyle(
                color: EstiloContractual.gris,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (oferentes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text(
                directo
                    ? 'Registra al contratista para enviarle su enlace de documentos.'
                    : 'Aún no hay oferentes. Regístralos para que carguen su oferta y requisitos por su enlace.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: EstiloContractual.gris,
                  fontSize: 13,
                ),
              ),
            ),
          for (final o in oferentes) ...[
            _FilaOferente(
              oferente: o,
              expediente: expedientes[o.tokenExpediente],
              directo: directo,
              puedeEvaluar: puedeEvaluar && !ocupado,
              onEvaluar: () => onEvaluar(o),
              onAdjudicar: () => onAdjudicar(o),
              onCopiarEnlace: () => onCopiarEnlace(o),
              onVerDocumentos: onVerDocumentos == null
                  ? null
                  : () => onVerDocumentos!(o),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ],
        ],
      ),
    );
  }
}

class _FilaOferente extends StatelessWidget {
  const _FilaOferente({
    required this.oferente,
    required this.expediente,
    required this.directo,
    required this.puedeEvaluar,
    required this.onEvaluar,
    required this.onAdjudicar,
    required this.onCopiarEnlace,
    required this.onVerDocumentos,
  });

  final OferenteProceso oferente;
  final ExpedienteContratoPs? expediente;
  final bool directo;
  final bool puedeEvaluar;
  final VoidCallback onEvaluar;
  final VoidCallback onAdjudicar;
  final VoidCallback onCopiarEnlace;
  final VoidCallback? onVerDocumentos;

  @override
  Widget build(BuildContext context) {
    final o = oferente;
    final e = expediente;
    final (color, fondo) = switch (o.estado) {
      EstadoOferente.inscrito => (
        const Color(0xFF1D4ED8),
        const Color(0xFFDBEAFE),
      ),
      EstadoOferente.habilitado => (
        const Color(0xFF0F766E),
        const Color(0xFFCCFBF1),
      ),
      EstadoOferente.noHabilitado => (
        const Color(0xFFB91C1C),
        const Color(0xFFFEE2E2),
      ),
      EstadoOferente.adjudicado => (
        const Color(0xFF15803D),
        const Color(0xFFDCFCE7),
      ),
      EstadoOferente.noAdjudicado => (
        const Color(0xFF64748B),
        const Color(0xFFF1F5F9),
      ),
    };
    final documentos = e == null
        ? 'Documentos: sincronizando…'
        : 'Documentos: ${e.totalCargados} de ${e.totalApartados} cargados · ${e.totalAprobados} verificados';
    final datos = [
      'Doc. ${o.documento}',
      if (o.valorOfertaCop > 0) 'Oferta ${_cop.format(o.valorOfertaCop)}',
      if (o.puntaje != null)
        'Puntaje ${o.puntaje! == o.puntaje!.roundToDouble() ? o.puntaje!.toInt() : o.puntaje}',
    ].join(' · ');

    return Padding(
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
                o.nombre,
                style: const TextStyle(
                  color: EstiloContractual.navy,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!directo)
                EtiquetaColor(
                  texto: o.estado.etiqueta,
                  color: color,
                  fondo: fondo,
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            datos,
            style: const TextStyle(
              color: EstiloContractual.texto,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            documentos,
            style: const TextStyle(
              color: EstiloContractual.gris,
              fontSize: 12.3,
            ),
          ),
          if (o.observacion.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              o.observacion,
              style: const TextStyle(
                color: EstiloContractual.gris,
                fontSize: 12.3,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _accion(Icons.link_rounded, 'Copiar enlace', onCopiarEnlace),
              if (onVerDocumentos != null)
                _accion(
                  Icons.fact_check_outlined,
                  'Verificar documentos',
                  onVerDocumentos!,
                ),
              if (!directo && puedeEvaluar)
                _accion(Icons.rule_rounded, 'Evaluar', onEvaluar),
              if (!directo &&
                  puedeEvaluar &&
                  o.estado == EstadoOferente.habilitado)
                FilledButton.icon(
                  onPressed: onAdjudicar,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    shape: const StadiumBorder(),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.emoji_events_outlined, size: 16),
                  label: const Text(
                    'Adjudicar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _accion(IconData icono, String texto, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icono, size: 16),
        label: Text(
          texto,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: EstiloContractual.navy,
          side: const BorderSide(color: Color(0xFFD8DEE8)),
          shape: const StadiumBorder(),
          visualDensity: VisualDensity.compact,
        ),
      );
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
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: proceso.avanceDocumentosEntidad,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: proceso.modalidad.color,
            backgroundColor: const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 4),
          Text(
            '${(proceso.avanceDocumentosEntidad * 100).round()} % de los documentos obligatorios de la entidad',
            style: const TextStyle(
              color: EstiloContractual.gris,
              fontSize: 11.8,
            ),
          ),
          const SizedBox(height: 14),
          for (final e in proceso.trazabilidad.take(20))
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
    this.peligro = false,
  });

  final String titulo;
  final String detalle;
  final String accion;
  final List<Widget> campos;
  final bool peligro;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFEFBF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                    style: EstiloContractual.botonPrincipal().copyWith(
                      backgroundColor: peligro
                          ? const WidgetStatePropertyAll(Color(0xFFB91C1C))
                          : null,
                    ),
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
