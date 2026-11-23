import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/expediente_contrato_service.dart';
import '../services/reporte_contratos_pdf_service.dart';
import '../services/reporte_seleccion_contratos.dart';
import '../tema/cristal.dart';

class SeleccionContratosReporte extends ChangeNotifier {
  final _contratos = <String, Map<String, dynamic>>{};
  bool _activa = false;
  int? _preparados;
  bool _cerrada = false;

  bool get activa => _activa;
  bool get preparando => _preparados != null;
  int get cantidad => _contratos.length;

  static String _clave(Map<String, dynamic> datos) {
    final fuente = ExpedienteContratoService.esSecopI(datos) ? 'I' : 'II';
    final id = (datos['id_contrato'] ?? '').toString().trim();
    if (id.isNotEmpty && id.toLowerCase() != 'no definido') {
      return '$fuente:$id';
    }
    return '$fuente:${jsonEncode([datos['nit_entidad'] ?? datos['nombre_entidad'], datos['referencia_del_contrato'], datos['proceso_de_compra'], datos['documento_proveedor'] ?? datos['proveedor_adjudicado'], datos['fecha_de_firma'] ?? datos['fecha_de_inicio_del_contrato'], datos['objeto_del_contrato'] ?? datos['descripcion_del_proceso']])}';
  }

  bool incluye(Map<String, dynamic> datos) =>
      _contratos.containsKey(_clave(datos));

  void iniciar() {
    _activa = true;
    notifyListeners();
  }

  void cancelar() {
    if (preparando) return;
    _contratos.clear();
    _activa = false;
    notifyListeners();
  }

  void alternar(Map<String, dynamic> datos) {
    if (!activa || preparando) return;
    final id = _clave(datos);
    if (_contratos.remove(id) == null) _contratos[id] = datos;
    notifyListeners();
  }

  Future<void> _descargar(
    BuildContext context,
    VoidCallback alDescargar,
  ) async {
    if (!activa || preparando || cantidad == 0) return;
    final seleccion = _contratos.values.toList();
    final mensajes = ScaffoldMessenger.of(context);
    _preparados = 0;
    notifyListeners();
    try {
      final contratos = <ContratoDelReporte>[];
      const lote = 3;
      for (var i = 0; i < seleccion.length; i += lote) {
        contratos.addAll(
          await Future.wait(
            seleccion.skip(i).take(lote).map(ContratoDelReporte.consultar),
          ),
        );
        if (_cerrada) return;
        _preparados = contratos.length;
        notifyListeners();
      }
      final bytes = await ReporteSeleccionContratos.generar(contratos);
      if (_cerrada) return;
      final nombre = ReporteContratosPdfService.nombreArchivo(
        'seleccionados',
        '',
        ReporteContratosPdfService.horaColombia(),
      );
      if (!ReporteContratosPdfService.descargar(bytes, nombre)) {
        mensajes.showSnackBar(
          const SnackBar(
            content: Text(
              'Abre la plataforma en el navegador para descargar el PDF.',
            ),
          ),
        );
        return;
      }
      _contratos.clear();
      _activa = false;
      alDescargar();
      mensajes.showSnackBar(
        const SnackBar(content: Text('Reporte de contratos descargado.')),
      );
    } catch (_) {
      if (!_cerrada) {
        mensajes.showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo generar el PDF. Puedes volver a descargar la selección.',
            ),
          ),
        );
      }
    } finally {
      if (!_cerrada) {
        _preparados = null;
        notifyListeners();
      }
    }
  }

  Future<void> _revisar(BuildContext context) => mostrarDialogoCristal<void>(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: this,
      builder: (ctx, _) {
        final contratos = _contratos.values.toList();
        return AlertDialog(
          title: Text('Contratos seleccionados ($cantidad)'),
          content: SizedBox(
            width: 500,
            child: cantidad == 0
                ? const Text('Marca contratos en los resultados de búsqueda.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: cantidad,
                    itemBuilder: (context, index) {
                      final datos = contratos[index];
                      final contrato = ContratoDelReporte(
                        datos: datos,
                        expedienteCompleto: false,
                        documentos: null,
                      );
                      return ListTile(
                        title: Text('Proceso: ${contrato.referencia}'),
                        subtitle: Text(
                          contrato.objeto,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar ${contrato.referencia} del reporte',
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          onPressed: () => alternar(datos),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Seguir seleccionando'),
            ),
          ],
        );
      },
    ),
  );

  @override
  void dispose() {
    _cerrada = true;
    super.dispose();
  }
}

class AccionesSeleccionContratos extends StatelessWidget {
  const AccionesSeleccionContratos({
    super.key,
    required this.seleccion,
    required this.alDescargar,
    required this.ayuda,
  });

  final SeleccionContratosReporte seleccion;
  final VoidCallback alDescargar;
  final String ayuda;

  @override
  Widget build(BuildContext context) {
    final cantidad = seleccion.cantidad;
    final progreso = seleccion._preparados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Cristal.doradoRelleno,
                foregroundColor: Cristal.tinta,
              ),
              onPressed: !seleccion.activa
                  ? seleccion.iniciar
                  : cantidad == 0 || seleccion.preparando
                  ? null
                  : () => seleccion._descargar(context, alDescargar),
              icon: Icon(
                seleccion.activa
                    ? Icons.download_rounded
                    : Icons.checklist_rounded,
                size: 17,
              ),
              label: Text(
                !seleccion.activa
                    ? 'Seleccionar contratos'
                    : progreso == null
                    ? 'Descargar reporte PDF'
                    : progreso == cantidad
                    ? 'Generando el PDF…'
                    : 'Preparando $progreso de $cantidad…',
              ),
            ),
            if (seleccion.activa) ...[
              TextButton(
                onPressed: seleccion.preparando ? null : seleccion.cancelar,
                child: const Text('Cancelar selección'),
              ),
              if (cantidad > 0 && !seleccion.preparando)
                OutlinedButton(
                  onPressed: () => seleccion._revisar(context),
                  child: Text(
                    '$cantidad ${cantidad == 1 ? 'seleccionado' : 'seleccionados'}',
                  ),
                ),
            ],
          ],
        ),
        if (seleccion.activa && cantidad == 0)
          Text(ayuda, style: TextStyle(color: Cristal.textoMedio)),
      ],
    );
  }
}

class CasillaContratoReporte extends StatelessWidget {
  const CasillaContratoReporte({
    super.key,
    required this.seleccion,
    required this.datos,
    required this.referencia,
  });

  final SeleccionContratosReporte seleccion;
  final Map<String, dynamic> datos;
  final String referencia;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seleccion,
    builder: (context, _) => Checkbox(
      value: seleccion.incluye(datos),
      onChanged: seleccion.preparando ? null : (_) => seleccion.alternar(datos),
      semanticLabel: 'Seleccionar $referencia para el reporte',
      activeColor: Cristal.doradoRelleno,
      checkColor: Cristal.tinta,
    ),
  );
}

class CabeceraSeleccionContratos extends StatelessWidget {
  const CabeceraSeleccionContratos({
    super.key,
    required this.resumen,
    required this.acciones,
    required this.ordenar,
  });

  final Widget resumen;
  final Widget acciones;
  final Widget ordenar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      resumen,
      const SizedBox(height: 6),
      LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 660
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  acciones,
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: ordenar),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: acciones),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ordenar,
                  ),
                ],
              ),
      ),
    ],
  );
}
