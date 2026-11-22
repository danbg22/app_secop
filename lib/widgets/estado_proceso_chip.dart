import 'package:flutter/material.dart';

import '../services/procesos_secop_service.dart';
import '../tema/cristal.dart';

class EstadoProcesoChip extends StatelessWidget {
  const EstadoProcesoChip(this.proceso, {super.key});

  final ProcesoSecop proceso;

  @override
  Widget build(BuildContext context) {
    final (color, fondo) = switch (proceso.tipo) {
      TipoEstadoProceso.abierto => (Cristal.verde, Cristal.verdeVidrio),
      TipoEstadoProceso.preparacion => (Cristal.ambar, Cristal.ambarVidrio),
      TipoEstadoProceso.evaluacion => (Cristal.acentoClaro, Cristal.azulVidrio),
      TipoEstadoProceso.adjudicado => (Cristal.dorado, Cristal.doradoVidrio),
      TipoEstadoProceso.cancelado => (Cristal.rojo, Cristal.rojoVidrio),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        proceso.estado,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
