import 'package:flutter/material.dart';

import '../screens/procesos_secop_i_screen.dart';
import '../services/secop_i_procesos_service.dart';

class ArchivoEntidadSecopI extends StatefulWidget {
  const ArchivoEntidadSecopI({
    super.key,
    required this.nit,
    required this.nombre,
  });

  final String nit;
  final String nombre;

  @override
  State<ArchivoEntidadSecopI> createState() => _ArchivoEntidadSecopIState();
}

class _ArchivoEntidadSecopIState extends State<ArchivoEntidadSecopI> {
  late final _archivo = SecopIProcesosService.archivoPorNit(
    widget.nit,
    widget.nombre,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<EntidadSecopI?>(
    future: _archivo,
    builder: (context, estado) {
      final archivo = estado.data;
      if (archivo == null) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProcesosSecopIScreen(entidad: archivo),
            ),
          ),
          icon: const Icon(Icons.history_rounded),
          label: Text('Ver archivo de SECOP I · ${archivo.procesos} registros'),
        ),
      );
    },
  );
}
