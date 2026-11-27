import 'package:flutter/material.dart';

import '../data/modalidades_contratacion.dart';
import '../services/etapas_proceso.dart';
import '../services/procesos_secop_service.dart';
import '../tema/cristal.dart';

/// Lo que exige la ley para la modalidad del proceso, comparado con lo que
/// la entidad publicó en Datos Abiertos. Es una ayuda de lectura: los
/// pliegos de cada proceso pueden fijar requisitos propios.
class RequisitosLeyProceso extends StatefulWidget {
  const RequisitosLeyProceso({
    super.key,
    required this.proceso,
    required this.archivos,
    this.plegable = false,
  });

  final ProcesoSecop proceso;

  /// Nombres de los archivos publicados (null mientras cargan o si la
  /// consulta falló).
  final Future<List<String>?> archivos;

  /// En celular empieza cerrada para no empujar el resto del detalle.
  final bool plegable;

  @override
  State<RequisitosLeyProceso> createState() => _RequisitosLeyProcesoState();
}

enum _Estado {
  publicado,
  noAparece,
  siAplica,
  masAdelante,
  conContrato,
  noAplica,
  sinDato,
}

class _RequisitosLeyProcesoState extends State<RequisitosLeyProceso> {
  late bool _abierta = !widget.plegable;

  int get _etapaComparable {
    final e = EtapasProceso.de(widget.proceso);
    if (identical(e.nombres, EtapasProceso.directas)) {
      return const [0, 1, 4][e.actual];
    }
    return e.actual;
  }

  _Estado _estado(
    String etapaCatalogo,
    DocumentoRequerido d,
    List<String>? archivos,
  ) {
    final etapa = RequisitosDeLey.etapaGeneral(etapaCatalogo);
    if (etapa >= 5) return _Estado.conContrato;
    final interrumpido = EtapasProceso.de(widget.proceso).interrumpido != null;
    if (etapa > _etapaComparable) {
      return interrumpido ? _Estado.noAplica : _Estado.masAdelante;
    }
    if (archivos == null) return _Estado.sinDato;
    return switch (RequisitosDeLey.publicado(d.id, archivos)) {
      true => _Estado.publicado,
      // Lo que la ley pide solo en algunos casos (sorteo, adendas…) no se
      // cuenta como faltante.
      false => d.obligatorio ? _Estado.noAparece : _Estado.siAplica,
      null => _Estado.sinDato,
    };
  }

  @override
  Widget build(BuildContext context) {
    final m = RequisitosDeLey.modalidad(widget.proceso.modalidad);
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
          InkWell(
            onTap: widget.plegable
                ? () => setState(() => _abierta = !_abierta)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(Icons.gavel_rounded, size: 20, color: Cristal.dorado),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requisitos de ley',
                        style: TextStyle(
                          color: Cristal.texto,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        m?.nombre ?? widget.proceso.modalidad,
                        style: TextStyle(
                          color: Cristal.textoMedio,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.plegable)
                  Icon(
                    _abierta
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Cristal.textoMedio,
                  ),
              ],
            ),
          ),
          if (_abierta) ...[
            const SizedBox(height: 14),
            if (m == null)
              Text(
                'Esta modalidad no está en nuestra guía de requisitos. Revisa los documentos del proceso en SECOP II.',
                style: TextStyle(color: Cristal.textoMedio, fontSize: 13.5),
              )
            else
              FutureBuilder<List<String>?>(
                future: widget.archivos,
                builder: (context, snap) => _contenido(
                  m,
                  snap.connectionState == ConnectionState.done
                      ? snap.data
                      : null,
                  cargando: snap.connectionState != ConnectionState.done,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _contenido(
    ModalidadContratacion m,
    List<String>? archivos, {
    required bool cargando,
  }) {
    final filas = <(String, DocumentoRequerido, _Estado)>[
      for (final e in m.etapas)
        for (final d in e.documentosEntidad)
          (e.nombre, d, _estado(e.id, d, archivos)),
    ];
    final esperados = filas.where(
      (f) => f.$3 == _Estado.publicado || f.$3 == _Estado.noAparece,
    );
    final publicados = esperados.where((f) => f.$3 == _Estado.publicado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          m.resumen,
          style: TextStyle(
            color: Cristal.textoCuerpo,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          m.fundamento,
          style: TextStyle(
            color: Cristal.textoSuave,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        _Titulo('Lo que debe publicar la entidad'),
        const SizedBox(height: 4),
        Text(
          cargando
              ? 'Comparando con lo publicado en Datos Abiertos…'
              : archivos == null
              ? 'No pudimos consultar los documentos publicados; la lista muestra lo que exige la ley.'
              : esperados.isEmpty
              ? 'Todavía no corresponde publicar documentos en esta etapa.'
              : '${publicados.length} de ${esperados.length} documentos que ya deberían estar aparecen en Datos Abiertos.',
          style: TextStyle(
            color: Cristal.textoMedio,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        for (final (i, (etapa, d, estado)) in filas.indexed) ...[
          if (i == 0 || filas[i - 1].$1 != etapa)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 2 : 12, bottom: 6),
              child: Text(
                etapa,
                style: TextStyle(
                  color: Cristal.textoSuave,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          _FilaDocumento(documento: d, estado: estado),
        ],
        if (m.documentosOferente.isNotEmpty) ...[
          const SizedBox(height: 18),
          _Titulo('Requisitos habilitantes del oferente'),
          const SizedBox(height: 4),
          Text(
            'La entidad los verifica en cada oferta; no se publican en Datos Abiertos.',
            style: TextStyle(
              color: Cristal.textoMedio,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          for (final d in m.documentosOferente)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_box_outline_blank_rounded,
                      size: 15,
                      color: Cristal.textoSuave,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: d.nombre,
                        children: [
                          if (!d.obligatorio)
                            TextSpan(
                              text: ' · si el pliego lo pide',
                              style: TextStyle(color: Cristal.textoSuave),
                            ),
                        ],
                      ),
                      style: TextStyle(
                        color: Cristal.textoCuerpo,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (m.criterioEvaluacion != null) ...[
          const SizedBox(height: 14),
          _Titulo('Cómo se escoge la oferta'),
          const SizedBox(height: 4),
          Text(
            m.criterioEvaluacion!,
            style: TextStyle(
              color: Cristal.textoCuerpo,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Guía general de la ley: el pliego de cada proceso puede fijar requisitos propios. '
          'La comparación usa los nombres de los archivos en Datos Abiertos, que a veces está incompleto; '
          'confirma en SECOP II antes de concluir que falta un documento.',
          style: TextStyle(
            color: Cristal.textoSuave,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: TextStyle(
      color: Cristal.texto,
      fontSize: 14.5,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _FilaDocumento extends StatelessWidget {
  const _FilaDocumento({required this.documento, required this.estado});

  final DocumentoRequerido documento;
  final _Estado estado;

  @override
  Widget build(BuildContext context) {
    final (icono, color, texto) = switch (estado) {
      _Estado.publicado => (
        Icons.check_circle_rounded,
        Cristal.verde,
        'Publicado',
      ),
      _Estado.noAparece => (
        Icons.error_outline_rounded,
        Cristal.ambar,
        'No aparece',
      ),
      _Estado.siAplica => (
        Icons.radio_button_unchecked_rounded,
        Cristal.textoSuave,
        'Si aplica',
      ),
      _Estado.masAdelante => (
        Icons.schedule_rounded,
        Cristal.textoSuave,
        'Más adelante',
      ),
      _Estado.conContrato => (
        Icons.description_outlined,
        Cristal.textoSuave,
        'Con el contrato',
      ),
      _Estado.noAplica => (
        Icons.remove_circle_outline_rounded,
        Cristal.textoSuave,
        'No aplica',
      ),
      _Estado.sinDato => (
        Icons.help_outline_rounded,
        Cristal.textoSuave,
        'Revisar en SECOP',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icono, size: 17, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  documento.nombre,
                  style: TextStyle(
                    color: Cristal.texto,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                if (documento.fundamento != null)
                  Text(
                    documento.fundamento!,
                    style: TextStyle(
                      color: Cristal.textoSuave,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
