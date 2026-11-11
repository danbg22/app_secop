import 'package:flutter/material.dart';

import '../../services/secop_importacion_service.dart';
import 'estilo_contractual.dart';
import '../../tema/cristal.dart';

/// Grupo visual del estado de un proceso en SECOP II.
enum GrupoEstadoSecop {
  preparacion(
    'En preparación',
    Icons.edit_note_rounded,
    Cristal.textoMedio,
    Cristal.borde,
  ),
  publicado(
    'Publicado',
    Icons.campaign_outlined,
    Cristal.acentoClaro,
    Cristal.azulVidrio,
  ),
  evaluacion(
    'En evaluación',
    Icons.rule_rounded,
    Color(0xFFA78BFA),
    Color(0x248B5CF6),
  ),
  adjudicado(
    'Adjudicado',
    Icons.verified_rounded,
    Cristal.verde,
    Cristal.verdeVidrio,
  ),
  terminado(
    'Cancelado o desierto',
    Icons.block_rounded,
    Cristal.rojo,
    Cristal.rojoVidrio,
  ),
  sinSincronizar(
    'Sin sincronizar',
    Icons.cloud_off_rounded,
    Cristal.textoSuave,
    Cristal.vidrioSuave,
  );

  const GrupoEstadoSecop(this.etiqueta, this.icono, this.color, this.fondo);
  final String etiqueta;
  final IconData icono;
  final Color color;
  final Color fondo;

  static GrupoEstadoSecop de(ProcesoSecop? s) {
    if (s == null) return sinSincronizar;
    if (s.adjudicado) return adjudicado;
    final e = '${s.estado} ${s.fase}'.toLowerCase();
    if (e.contains('cancelad') ||
        e.contains('desiert') ||
        e.contains('suspendid')) {
      return terminado;
    }
    if (e.contains('seleccionado') ||
        e.contains('adjudicad') ||
        e.contains('celebrado')) {
      return adjudicado;
    }
    if (e.contains('evaluaci')) return evaluacion;
    if (e.contains('borrador') ||
        e.contains('aprobaci') ||
        e.contains('aprobado')) {
      return preparacion;
    }
    return publicado;
  }
}

/// Chip con el estado tal como lo reporta SECOP II.
class ChipEstadoSecop extends StatelessWidget {
  const ChipEstadoSecop({super.key, required this.secop});
  final ProcesoSecop? secop;

  @override
  Widget build(BuildContext context) {
    final g = GrupoEstadoSecop.de(secop);
    final texto = secop == null
        ? g.etiqueta
        : (secop!.adjudicado
              ? 'Adjudicado'
              : (secop!.estado.isEmpty ? g.etiqueta : secop!.estado));
    return EtiquetaColor(
      texto: texto,
      color: g.color,
      fondo: g.fondo,
      icono: g.icono,
    );
  }
}

/// "hace 5 min", "hace 2 h", "hace 3 días".
String haceCuanto(String iso) {
  final f = DateTime.tryParse(iso);
  if (f == null) return 'nunca';
  final d = DateTime.now().difference(f.toLocal());
  if (d.inMinutes < 1) return 'hace un momento';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} día${d.inDays == 1 ? '' : 's'}';
}

String copMillones(int v) {
  if (v >= 1000000) {
    final m = (v / 1000000)
        .toStringAsFixed(v >= 100000000 ? 0 : 1)
        .replaceAll('.', ',');
    return '\$ $m M';
  }
  return '\$ ${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
}

/// Lista de documentos publicados en SECOP II con enlace de descarga.
class ListaDocumentosSecop extends StatefulWidget {
  const ListaDocumentosSecop({
    super.key,
    required this.documentos,
    required this.abrir,
    this.visiblesIniciales = 6,
  });

  final List<DocumentoSecop> documentos;
  final void Function(String url) abrir;
  final int visiblesIniciales;

  @override
  State<ListaDocumentosSecop> createState() => _ListaDocumentosSecopState();
}

class _ListaDocumentosSecopState extends State<ListaDocumentosSecop> {
  bool _todos = false;

  IconData _icono(String ext) => switch (ext) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'doc' || 'docx' => Icons.description_outlined,
    'xls' || 'xlsx' => Icons.table_chart_outlined,
    'zip' || 'rar' => Icons.folder_zip_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final docs = widget.documentos.reversed.toList();
    if (docs.isEmpty) {
      return const Text(
        'Aún no hay documentos publicados en SECOP II (o Datos Abiertos no los ha reportado).',
        style: TextStyle(color: Cristal.textoSuave, fontSize: 12.8),
      );
    }
    final visibles = _todos
        ? docs
        : docs.take(widget.visiblesIniciales).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in visibles)
          InkWell(
            hoverDuration: Cristal.micro,
            onTap: d.url.isEmpty ? null : () => widget.abrir(d.url),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
              child: Row(
                children: [
                  Icon(_icono(d.extension), size: 20, color: Cristal.texto),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Cristal.texto,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (d.descripcion.isNotEmpty &&
                            d.descripcion != d.nombre)
                          Text(
                            d.descripcion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Cristal.textoSuave,
                              fontSize: 11.8,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    d.fechaIso,
                    style: const TextStyle(
                      color: Cristal.textoSuave,
                      fontSize: 11.8,
                    ),
                  ),
                  if (d.url.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: Cristal.textoSuave,
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (docs.length > widget.visiblesIniciales)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _todos = !_todos),
              style: TextButton.styleFrom(foregroundColor: Cristal.texto),
              child: Text(
                _todos ? 'Ver menos' : 'Ver los ${docs.length} documentos',
              ),
            ),
          ),
      ],
    );
  }
}
