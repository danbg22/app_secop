import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/datos_abiertos.dart';
import '../services/procesos_secop_service.dart';
import '../services/secop_document_intelligence_service.dart';
import '../tema/cristal.dart';
import '../utils/banderas_control.dart';

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

  late final Future<List<ProcesoSecop>> _fases = _cargarFases();
  late final Future<SecopExtractionResult?> _documentos =
      SecopDocumentIntelligenceService.obtenerDocumentosDatosAbiertos({
        'proceso_de_compra': p.portafolio,
        'fecha_de_firma': '${p.fila['fecha_de_publicacion_del'] ?? ''}',
        'urlproceso': p.fila['urlproceso'],
      });

  /// Todas las fases del proceso (una fila por fase en SECOP II).
  Future<List<ProcesoSecop>> _cargarFases() async {
    if (p.portafolio.isEmpty) return [p];
    final filas = await DatosAbiertos.filas('p6dx-8zbt', {
      r'$where': "id_del_portafolio = '${p.portafolio.replaceAll("'", "''")}'",
      r'$order': 'fecha_de_publicacion_del',
      r'$limit': '50',
    });
    return [for (final f in filas) ProcesoSecop(f)];
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
    final (color, fondo) = switch (p.tipo) {
      TipoEstadoProceso.abierto => (Cristal.verde, Cristal.verdeVidrio),
      TipoEstadoProceso.preparacion => (Cristal.ambar, Cristal.ambarVidrio),
      TipoEstadoProceso.evaluacion => (
        Cristal.acentoClaro,
        Cristal.acentoVidrio,
      ),
      TipoEstadoProceso.adjudicado => (
        Cristal.legible(const Color(0xFFA78BFA)),
        const Color(0x248B5CF6),
      ),
      TipoEstadoProceso.cancelado => (Cristal.rojo, Cristal.rojoVidrio),
    };
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
                        onPressed: () => Navigator.of(context).maybePop(),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: fondo,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              p.estado,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
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
                      if (p.url.startsWith('http')) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () => _abrir(p.url),
                            style: FilledButton.styleFrom(
                              backgroundColor: Cristal.acento,
                              foregroundColor: Cristal.blanco,
                            ),
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 18,
                            ),
                            label: const Text('Abrir el proceso en SECOP II'),
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
                          final docs =
                              snap.data?.documents ??
                              const <SecopExtractedDocument>[];
                          if (docs.isEmpty) {
                            return Text(
                              'Datos Abiertos todavía no tiene documentos de este proceso. Ábrelo en SECOP II para verlos.',
                              style: TextStyle(color: Cristal.textoMedio),
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
                    'Fuente: Datos Abiertos de SECOP II (con 1 a 3 días de retraso). Lo vigente es lo que muestra SECOP II.',
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
