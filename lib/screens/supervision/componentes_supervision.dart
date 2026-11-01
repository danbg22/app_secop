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
                    child: Icon(icono, size: 18, color: EstiloContractual.navy),
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
    );
  }
}

/// Los cuatro pasos del mes: contratista → revisión → supervisor → pago.
class LineaPasosInforme extends StatelessWidget {
  const LineaPasosInforme({super.key, required this.estado});
  final EstadoInforme estado;

  @override
  Widget build(BuildContext context) {
    final pasos = [
      ('Informe del contratista', Icons.edit_note_rounded),
      ('Revisión documental', Icons.fact_check_outlined),
      ('Aprobación del supervisor', Icons.verified_user_outlined),
      ('Pago', Icons.payments_outlined),
    ];
    final actual = switch (estado) {
      EstadoInforme.pendiente ||
      EstadoInforme.borrador ||
      EstadoInforme.devuelto => 0,
      EstadoInforme.enviado => 1,
      EstadoInforme.revisado => 2,
      EstadoInforme.aprobado => 3,
      EstadoInforme.pagado => 4,
    };
    final mobile = MediaQuery.sizeOf(context).width < 680;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pasos.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= actual
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < actual
                            ? const Color(0xFF16A34A)
                            : (i == actual
                                  ? (estado == EstadoInforme.devuelto
                                        ? const Color(0xFFD97706)
                                        : EstiloContractual.navy)
                                  : const Color(0xFFF1F5F9)),
                      ),
                      child: Icon(
                        i < actual ? Icons.check_rounded : pasos[i].$2,
                        size: 18,
                        color: i <= actual
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == pasos.length - 1
                            ? Colors.transparent
                            : (i < actual
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pasos[i].$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: i <= actual
                        ? EstiloContractual.navy
                        : EstiloContractual.gris,
                    fontSize: mobile ? 10.5 : 12,
                    fontWeight: i == actual ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Resultado de la verificación automática de la planilla.
class ListaHallazgos extends StatelessWidget {
  const ListaHallazgos({super.key, required this.hallazgos});
  final List<HallazgoPlanilla> hallazgos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final h in hallazgos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  h.cumple ? Icons.check_circle_rounded : Icons.error_rounded,
                  size: 17,
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
                      fontSize: 12.8,
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
