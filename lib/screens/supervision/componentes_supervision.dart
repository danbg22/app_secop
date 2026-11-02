import 'package:flutter/material.dart';

import '../../services/supervision_service.dart';
import '../gestion_contractual/estilo_contractual.dart';

/// Piezas visuales compartidas por las pantallas de supervisión.

void mensajeSupervision(
  BuildContext context,
  String texto, {
  bool error = false,
}) {
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

InputDecoration decoracionCampo(
  String etiqueta, {
  String? ayuda,
  String? prefijo,
}) => InputDecoration(
  labelText: etiqueta,
  helperText: ayuda,
  helperMaxLines: 3,
  prefixText: prefijo,
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: EstiloContractual.navy, width: 1.5),
  ),
);

class ChipEstadoInforme extends StatelessWidget {
  const ChipEstadoInforme(this.estado, {super.key});
  final EstadoInforme estado;

  @override
  Widget build(BuildContext context) => EtiquetaColor(
    texto: estado.etiqueta,
    color: Color(estado.color),
    fondo: Color(estado.fondo),
  );
}

/// Tarjeta blanca con título, subtítulo y acción opcional.
class TarjetaSupervision extends StatelessWidget {
  const TarjetaSupervision({
    super.key,
    required this.children,
    this.titulo,
    this.subtitulo,
    this.icono,
    this.accion,
    this.colorBorde,
  });

  final String? titulo;
  final String? subtitulo;
  final IconData? icono;
  final Widget? accion;
  final Color? colorBorde;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 680;
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 22),
      decoration: EstiloContractual.tarjeta(colorBorde: colorBorde),
      // Material propio para que las ListTile pinten su tinta sobre la tarjeta.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titulo != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icono != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icono,
                        size: 18,
                        color: EstiloContractual.navy,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo!,
                          style: const TextStyle(
                            color: EstiloContractual.navy,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitulo != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitulo!,
                            style: const TextStyle(
                              color: EstiloContractual.texto,
                              fontSize: 12.8,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (accion != null) ...[const SizedBox(width: 10), accion!],
                ],
              ),
              const SizedBox(height: 16),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Recorrido del informe: el contratista y cada etapa de aprobación de la
/// entidad, con quién aprobó y cuándo.
class RielEtapas extends StatelessWidget {
  const RielEtapas({
    super.key,
    required this.plan,
    required this.informe,
    this.vertical = false,
  });
  final PlanSupervision plan;
  final InformePeriodo informe;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final inf = informe;
    final aprobadoTodo =
        inf.estado == EstadoInforme.aprobado ||
        inf.estado == EstadoInforme.pagado;
    final pasos = <(String, String, _EstadoPaso)>[
      (
        'Contratista',
        inf.estado == EstadoInforme.devuelto
            ? 'Corrigiendo'
            : (inf.enviadoEnIso.isEmpty ? 'Elaborando' : 'Enviado'),
        inf.estado.editablePorContratista
            ? (inf.estado == EstadoInforme.devuelto
                  ? _EstadoPaso.devuelto
                  : _EstadoPaso.actual)
            : _EstadoPaso.hecho,
      ),
      for (final (i, e) in plan.etapas.indexed)
        () {
          final r = inf.revisiones
              .where((r) => r.etapaId == e.id && r.aprobado)
              .lastOrNull;
          final hecho = aprobadoTodo || (r != null && i < inf.etapaActual);
          final actual =
              inf.estado == EstadoInforme.enRevision && i == inf.etapaActual;
          return (
            e.nombre,
            hecho && r != null
                ? r.actor
                : (e.responsableNombre.isEmpty
                      ? 'Pendiente'
                      : e.responsableNombre),
            hecho
                ? _EstadoPaso.hecho
                : (actual ? _EstadoPaso.actual : _EstadoPaso.pendiente),
          );
        }(),
    ];

    Widget punto(_EstadoPaso e, int n) {
      final (fondo, icono) = switch (e) {
        _EstadoPaso.hecho => (const Color(0xFF16A34A), Icons.check_rounded),
        _EstadoPaso.actual => (EstiloContractual.navy, null),
        _EstadoPaso.devuelto => (const Color(0xFFD97706), Icons.undo_rounded),
        _EstadoPaso.pendiente => (const Color(0xFFE2E8F0), null),
      };
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
        child: icono != null
            ? Icon(icono, size: 16, color: Colors.white)
            : Text(
                '$n',
                style: TextStyle(
                  color: e == _EstadoPaso.pendiente
                      ? EstiloContractual.gris
                      : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
      );
    }

    Widget textos((String, String, _EstadoPaso) p, {bool centrado = false}) =>
        Column(
          crossAxisAlignment: centrado
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              p.$1,
              textAlign: centrado ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: p.$3 == _EstadoPaso.pendiente
                    ? EstiloContractual.gris
                    : EstiloContractual.navy,
                fontSize: 12.6,
                fontWeight: p.$3 == _EstadoPaso.actual
                    ? FontWeight.w800
                    : FontWeight.w700,
              ),
            ),
            Text(
              p.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: centrado ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                color: EstiloContractual.gris,
                fontSize: 11.3,
              ),
            ),
          ],
        );

    if (vertical) {
      return Column(
        children: [
          for (final (i, p) in pasos.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      punto(p.$3, i + 1),
                      if (i < pasos.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: p.$3 == _EstadoPaso.hecho
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 4,
                        bottom: i < pasos.length - 1 ? 14 : 0,
                      ),
                      child: textos(p),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, p) in pasos.indexed)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0
                            ? Colors.transparent
                            : (pasos[i - 1].$3 == _EstadoPaso.hecho
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    punto(p.$3, i + 1),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == pasos.length - 1
                            ? Colors.transparent
                            : (p.$3 == _EstadoPaso.hecho
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: textos(p, centrado: true),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _EstadoPaso { hecho, actual, devuelto, pendiente }

/// Resultado de la verificación automática.
class ListaVerificaciones extends StatelessWidget {
  const ListaVerificaciones({super.key, required this.verificaciones});
  final List<Verificacion> verificaciones;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final h in verificaciones)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  h.cumple ? Icons.check_circle_rounded : Icons.error_rounded,
                  size: 18,
                  color: h.cumple
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    h.texto,
                    style: TextStyle(
                      color: h.cumple
                          ? EstiloContractual.texto
                          : const Color(0xFFB91C1C),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: h.cumple ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Dato con etiqueta en mayúsculas pequeñas.
class DatoSupervision extends StatelessWidget {
  const DatoSupervision(this.etiqueta, this.valor, {super.key, this.color});
  final String etiqueta;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        etiqueta.toUpperCase(),
        style: EstiloContractual.seccion.copyWith(fontSize: 10.5),
      ),
      const SizedBox(height: 3),
      Text(
        valor,
        style: TextStyle(
          color: color ?? EstiloContractual.navy,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

/// Historial del informe (quién hizo qué y cuándo).
class HistorialInforme extends StatelessWidget {
  const HistorialInforme({
    super.key,
    required this.eventos,
    required this.formatoFecha,
  });
  final List<EventoInforme> eventos;
  final String Function(String) formatoFecha;

  @override
  Widget build(BuildContext context) {
    if (eventos.isEmpty) {
      return const Text(
        'Sin movimientos todavía.',
        style: TextStyle(color: EstiloContractual.gris, fontSize: 12.5),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in eventos.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: EstiloContractual.navy,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.accion,
                        style: const TextStyle(
                          color: EstiloContractual.navy,
                          fontSize: 12.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${e.actor} · ${formatoFecha(e.fechaIso)}',
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
                            fontSize: 12,
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
  }
}
