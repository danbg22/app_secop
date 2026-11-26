import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/novedades_proceso_service.dart';
import '../services/procesos_secop_service.dart';
import '../services/secop_document_intelligence_service.dart';
import '../services/security_service.dart';
import '../tema/cristal.dart';
import '../utils/banderas_control.dart';
import '../utils/compartir_enlace.dart';
import '../utils/enlace_proceso.dart';
import '../widgets/estado_proceso_chip.dart';

/// Detalle de un proceso de SECOP II en cualquier estado (borrador, abierto,
/// en evaluación, adjudicado o cancelado): sus datos, sus fases y los
/// documentos publicados (estudios previos, pliegos, CDP…), para revisarlo
/// antes de que se adjudique.
class DetalleProcesoScreen extends StatefulWidget {
  const DetalleProcesoScreen({super.key, required this.proceso});

  final ProcesoSecop proceso;

  @override
  State<DetalleProcesoScreen> createState() => _DetalleProcesoScreenState();
}

class _DetalleProcesoScreenState extends State<DetalleProcesoScreen> {
  ProcesoSecop get p => widget.proceso;

  late final Future<List<ProcesoSecop>> _fases = ProcesosSecopService.fasesDe(
    p,
  );
  late final Future<NovedadesProceso> _novedades = _fases
      .then<List<ProcesoSecop>>((f) => f, onError: (_) => [p])
      .then((fases) => NovedadesProcesoService.consultar(p, fases));
  late final Future<SecopExtractionResult?> _documentos =
      SecopDocumentIntelligenceService.obtenerDocumentosDatosAbiertos({
        'proceso_de_compra': p.portafolio,
        'fecha_de_firma': '${p.fila['fecha_de_publicacion_del'] ?? ''}',
        'urlproceso': p.fila['urlproceso'],
      });

  Future<void> _compartir() async {
    final enlace = enlaceProcesoCompartido(p.idCompartido);
    if (await compartirEnNavegador(enlace)) return;
    if (!mounted) return;
    try {
      await Clipboard.setData(ClipboardData(text: enlace.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copiaste el enlace de la vista previa.')),
      );
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Compartir vista previa'),
          content: SelectableText(enlace.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _volver() async {
    final navegador = Navigator.of(context);
    if (await navegador.maybePop() || !mounted) return;
    navegador.pushReplacementNamed('/home');
  }

  String _t(String k) {
    final v = '${p.fila[k] ?? ''}'.trim();
    final l = v.toLowerCase();
    return l == 'no definido' || l == 'unspecified' || v == '0' ? '' : v;
  }

  static String _pesos(double v) {
    final s = v.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '\$ $s';
  }

  static String _fechaHora(DateTime? d) => d == null
      ? ''
      : '${fechaDiaMesAnio(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _abrir(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final angosto = MediaQuery.sizeOf(context).width < 700;
    final enlaceSecop = SecurityService.validateOfficialGovUrl(p.url);
    final sePuedeCompartir = ProcesosSecopService.idCompartible(p.idCompartido);
    final duracion = [
      _t('duracion'),
      _t('unidad_de_duracion'),
    ].where((x) => x.isNotEmpty).join(' ');
    final datos = <(String, String)>[
      ('Entidad', p.entidad),
      (
        'Unidad de contratación',
        [
          _t('nombre_de_la_unidad_de'),
          _t('ciudad_de_la_unidad_de'),
        ].where((x) => x.isNotEmpty).join(' · '),
      ),
      ('Departamento', p.departamento),
      ('Modalidad', p.modalidad),
      ('Justificación de la modalidad', _t('justificaci_n_modalidad_de')),
      ('Tipo de contrato', _t('tipo_de_contrato')),
      if (p.precioBase > 0) ('Presupuesto oficial', _pesos(p.precioBase)),
      ('Duración', duracion),
      ('Fase actual', p.fase),
      ('Publicado', _fechaHora(p.publicado)),
      ('Cierre de ofertas', _fechaHora(p.cierreOfertas)),
      (
        'Apertura de ofertas',
        _fechaHora(DateTime.tryParse(_t('fecha_de_apertura_de_respuesta'))),
      ),
      ('Código UNSPSC', _t('codigo_principal_de_categoria')),
      ('Proveedores invitados', _t('proveedores_invitados')),
      ('Ofertas o respuestas recibidas', _t('respuestas_al_procedimiento')),
      ('Veces que se ha visto en SECOP', _t('visualizaciones_del')),
      if (p.adjudicado) ...[
        ('Adjudicado a', p.proveedor),
        ('NIT del adjudicatario', _t('nit_del_proveedor_adjudicado')),
        if (p.valorAdjudicado > 0)
          ('Valor adjudicado', _pesos(p.valorAdjudicado)),
      ],
    ].where((d) => d.$2.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            angosto ? 16 : 32,
            angosto ? 14 : 22,
            angosto ? 16 : 32,
            36,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Volver',
                        onPressed: _volver,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Detalle del proceso',
                          style: TextStyle(
                            color: Cristal.texto,
                            fontSize: angosto ? 22 : 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (sePuedeCompartir)
                        angosto
                            ? IconButton(
                                tooltip: 'Compartir proceso',
                                onPressed: _compartir,
                                icon: const Icon(Icons.share_outlined),
                              )
                            : OutlinedButton.icon(
                                onPressed: _compartir,
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 18,
                                ),
                                label: const Text('Compartir proceso'),
                              ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          EstadoProcesoChip(p),
                          Text(
                            'SECOP II',
                            style: TextStyle(
                              color: Cristal.textoMedio,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (p.referencia.isNotEmpty)
                            SelectableText(
                              p.referencia,
                              style: TextStyle(
                                color: Cristal.textoSuave,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        p.nombre.isEmpty ? 'Proceso sin nombre' : p.nombre,
                        style: TextStyle(
                          color: Cristal.texto,
                          fontSize: angosto ? 18 : 22,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      if (p.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SelectableText(
                          p.descripcion,
                          style: TextStyle(
                            color: Cristal.textoCuerpo,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (enlaceSecop != null) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () => _abrir(enlaceSecop.toString()),
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                            ),
                            label: const Text('Abrir en SECOP II'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    titulo: 'Datos del proceso',
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final (clave, valor) in datos)
                            SizedBox(
                              width: angosto ? double.infinity : 300,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clave,
                                    style: TextStyle(
                                      color: Cristal.textoSuave,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  SelectableText(
                                    valor,
                                    style: TextStyle(
                                      color: Cristal.texto,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    titulo: 'Observaciones y novedades',
                    subtitulo: 'Lo que la entidad ha publicado durante el proceso: adendas, informes de evaluación, respuestas a observaciones, proponentes y adjudicación.',
                    children: [
                      _NovedadesProceso(
                        futuro: _novedades,
                        fechaHora: _fechaHora,
                        abrir: _abrir,
                      ),
                      const SizedBox(height: 16),
                      _AvisoMensajesSecop(
                        onAbrir: enlaceSecop == null
                            ? null
                            : () => _abrir(enlaceSecop.toString()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    titulo: 'Documentos publicados',
                    subtitulo: 'Estudios previos, pliegos, CDP, anexos y formatos que la entidad cargó en SECOP II.',
                    children: [
                      FutureBuilder<SecopExtractionResult?>(
                        future: _documentos,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snap.hasError) {
                            return Text(
                              'No pudimos consultar los documentos. Puedes revisarlos en SECOP II.',
                              style: TextStyle(color: Cristal.textoMedio),
                            );
                          }
                          final docs =
                              snap.data?.documents ??
                              const <SecopExtractedDocument>[];
                          if (docs.isEmpty) {
                            // Datos Abiertos no exporta todos los archivos:
                            // a veces faltan los de procesos recién
                            // publicados o los de nuevas ventanas.
                            return Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Datos Abiertos no tiene los documentos de este proceso; SECOP II sí los muestra.',
                                  style: TextStyle(color: Cristal.textoMedio),
                                ),
                                if (enlaceSecop != null)
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _abrir(enlaceSecop.toString()),
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'Ver documentos en SECOP II',
                                    ),
                                  ),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                docs.length == 1
                                    ? '1 documento'
                                    : '${docs.length} documentos',
                                style: TextStyle(
                                  color: Cristal.textoSuave,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final d in docs)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.description_outlined,
                                        size: 18,
                                        color: Cristal.textoMedio,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              d.name,
                                              style: TextStyle(
                                                color: Cristal.texto,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              d.category,
                                              style: TextStyle(
                                                color: Cristal.textoSuave,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (d.downloadUrl != null)
                                        TextButton.icon(
                                          onPressed: () =>
                                              _abrir(d.downloadUrl!),
                                          icon: const Icon(
                                            Icons.download_rounded,
                                            size: 17,
                                          ),
                                          label: const Text('Descargar'),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    titulo: 'Fases del proceso',
                    subtitulo: 'SECOP II publica cada fase por separado (observaciones, manifestación de interés, ofertas…).',
                    children: [
                      FutureBuilder<List<ProcesoSecop>>(
                        future: _fases,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snap.hasError) {
                            return Text(
                              'No pudimos consultar el historial de fases.',
                              style: TextStyle(color: Cristal.textoMedio),
                            );
                          }
                          final fases = snap.data ?? [p];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (i, f) in fases.indexed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Cristal.vidrioSuave,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Cristal.borde,
                                          ),
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            color: Cristal.texto,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${f.fase.isEmpty ? 'Fase' : f.fase} · ${f.estado}',
                                              style: TextStyle(
                                                color: Cristal.texto,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              [
                                                if (f.publicado != null)
                                                  'Publicada ${_fechaHora(f.publicado)}',
                                                if (f.cierreOfertas != null)
                                                  'cierre ${_fechaHora(f.cierreOfertas)}',
                                              ].join(' · '),
                                              style: TextStyle(
                                                color: Cristal.textoSuave,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Fuente · Datos Abiertos de SECOP II',
                    style: TextStyle(color: Cristal.textoSuave, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children, this.titulo, this.subtitulo});

  final List<Widget> children;
  final String? titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Cristal.vidrio,
        borderRadius: BorderRadius.circular(Cristal.radioTarjeta),
        border: Border.all(color: Cristal.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titulo != null) ...[
            Text(
              titulo!,
              style: TextStyle(
                color: Cristal.texto,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitulo!,
                style: TextStyle(color: Cristal.textoSuave, fontSize: 12.8),
              ),
            ],
            const SizedBox(height: 14),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// Novedades (documentos clave por fecha) y proponentes del proceso.
class _NovedadesProceso extends StatelessWidget {
  const _NovedadesProceso({
    required this.futuro,
    required this.fechaHora,
    required this.abrir,
  });

  final Future<NovedadesProceso> futuro;
  final String Function(DateTime?) fechaHora;
  final void Function(String) abrir;

  static IconData _icono(TipoNovedad t) => switch (t) {
    TipoNovedad.desierto => Icons.block_rounded,
    TipoNovedad.revocatoria => Icons.cancel_outlined,
    TipoNovedad.suspension => Icons.pause_circle_outline_rounded,
    TipoNovedad.adjudicacion => Icons.gavel_rounded,
    TipoNovedad.evaluacion => Icons.fact_check_outlined,
    TipoNovedad.observaciones => Icons.question_answer_outlined,
    TipoNovedad.adenda => Icons.edit_note_rounded,
    TipoNovedad.modificacion => Icons.event_repeat_rounded,
    TipoNovedad.oferentes => Icons.groups_2_outlined,
    TipoNovedad.apertura => Icons.flag_outlined,
    TipoNovedad.convocatoria => Icons.campaign_outlined,
  };

  /// Las novedades que cambian el rumbo del proceso se resaltan.
  static Color _color(TipoNovedad t) => switch (t) {
    TipoNovedad.desierto ||
    TipoNovedad.revocatoria ||
    TipoNovedad.suspension => Cristal.rojo,
    TipoNovedad.adjudicacion || TipoNovedad.evaluacion => Cristal.dorado,
    TipoNovedad.adenda || TipoNovedad.modificacion => Cristal.acentoClaro,
    _ => Cristal.textoMedio,
  };

  Widget _rotulo(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: TextStyle(
        color: Cristal.textoSuave,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NovedadesProceso>(
      future: futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text(
            'No pudimos consultar las novedades del proceso. Puedes revisarlas en SECOP II.',
            style: TextStyle(color: Cristal.textoMedio),
          );
        }
        final datos = snap.data!;
        if (datos.vacio) {
          return Text(
            'Datos Abiertos todavía no tiene adendas, evaluaciones, respuestas a observaciones ni proponentes de este proceso.',
            style: TextStyle(color: Cristal.textoMedio),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (datos.novedades.isNotEmpty) ...[
              _rotulo('PUBLICADO POR LA ENTIDAD'),
              for (final n in datos.novedades)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _color(n.tipo).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          _icono(n.tipo),
                          size: 18,
                          color: _color(n.tipo),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.tipo.titulo,
                              style: TextStyle(
                                color: Cristal.texto,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              [
                                if (n.fecha != null) fechaDiaMesAnio(n.fecha!),
                                n.archivo,
                              ].join(' · '),
                              style: TextStyle(
                                color: Cristal.textoSuave,
                                fontSize: 12.3,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (n.url != null)
                        IconButton(
                          tooltip: 'Descargar',
                          onPressed: () => abrir(n.url!),
                          icon: const Icon(Icons.download_rounded, size: 19),
                        ),
                    ],
                  ),
                ),
            ],
            if (datos.proponentes.isNotEmpty) ...[
              if (datos.novedades.isNotEmpty) const SizedBox(height: 6),
              _rotulo(
                datos.proponentes.length == 1
                    ? '1 PROPONENTE'
                    : '${datos.proponentes.length} PROPONENTES',
              ),
              for (final o in datos.proponentes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 17,
                        color: Cristal.textoMedio,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          o.nit.isEmpty
                              ? o.nombre
                              : '${o.nombre} · NIT ${o.nit}',
                          style: TextStyle(
                            color: Cristal.texto,
                            fontSize: 13.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Los mensajes de SECOP II no se publican en Datos Abiertos: se explica y se
/// lleva a la página del proceso, donde están completos.
class _AvisoMensajesSecop extends StatelessWidget {
  const _AvisoMensajesSecop({this.onAbrir});

  final VoidCallback? onAbrir;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cristal.vidrioSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Cristal.borde),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.forum_outlined, size: 20, color: Cristal.textoMedio),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Los mensajes de los interesados, las observaciones y las notificaciones de la entidad solo se ven en la página del proceso en SECOP II; no se publican en Datos Abiertos.',
                    style: TextStyle(
                      color: Cristal.textoMedio,
                      fontSize: 12.8,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onAbrir != null)
            OutlinedButton.icon(
              onPressed: onAbrir,
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Ver mensajes en SECOP II'),
            ),
        ],
      ),
    );
  }
}
