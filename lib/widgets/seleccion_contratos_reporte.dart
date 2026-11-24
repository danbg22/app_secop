import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/expediente_contrato_service.dart';
import '../services/reporte_contratos_pdf_service.dart';
import '../services/reporte_seleccion_contratos.dart';
import '../tema/cristal.dart';

abstract class SeleccionReporte<T> extends ChangeNotifier {
  final _elementos = <String, T>{};
  bool _activa = false;
  int? _preparados;
  bool _cerrada = false;

  bool get activa => _activa;
  bool get preparando => _preparados != null;
  int get cantidad => _elementos.length;

  String get singular;
  String get plural => '${singular}s';
  String clave(T datos);
  String titulo(T datos);
  String detalle(T datos);
  Future<Uint8List> generar(List<T> lista, ValueChanged<int> progreso);
  String nombreArchivo(DateTime fecha);

  bool incluye(T datos) => _elementos.containsKey(clave(datos));

  void iniciar() {
    _activa = true;
    notifyListeners();
  }

  void cancelar() {
    if (preparando) return;
    _elementos.clear();
    _activa = false;
    notifyListeners();
  }

  void alternar(T datos) {
    if (!activa || preparando) return;
    final id = clave(datos);
    if (_elementos.remove(id) == null) _elementos[id] = datos;
    notifyListeners();
  }

  Future<void> _descargar(
    BuildContext context,
    VoidCallback alDescargar,
  ) async {
    if (!activa || preparando || cantidad == 0) return;
    final seleccion = _elementos.values.toList();
    final mensajes = ScaffoldMessenger.of(context);
    _preparados = 0;
    notifyListeners();
    try {
      final bytes = await generar(seleccion, (cantidad) {
        if (_cerrada) return;
        _preparados = cantidad;
        notifyListeners();
      });
      if (_cerrada) return;
      final nombre = nombreArchivo(ReporteContratosPdfService.horaColombia());
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
      _elementos.clear();
      _activa = false;
      alDescargar();
      mensajes.showSnackBar(
        SnackBar(content: Text('Reporte de $plural descargado.')),
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
        final elementos = _elementos.values.toList();
        return AlertDialog(
          title: Text(
            '${plural[0].toUpperCase()}${plural.substring(1)} seleccionados ($cantidad)',
          ),
          content: SizedBox(
            width: 500,
            child: cantidad == 0
                ? Text('Marca $plural en los resultados de búsqueda.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: cantidad,
                    itemBuilder: (context, index) {
                      final datos = elementos[index];
                      return ListTile(
                        title: Text(titulo(datos)),
                        subtitle: Text(
                          detalle(datos),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar ${titulo(datos)} del reporte',
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

class SeleccionContratosReporte extends SeleccionReporte<Map<String, dynamic>> {
  @override
  String get singular => 'contrato';

  @override
  String clave(Map<String, dynamic> datos) {
    final fuente = ExpedienteContratoService.esSecopI(datos) ? 'I' : 'II';
    final id = (datos['id_contrato'] ?? '').toString().trim();
    if (id.isNotEmpty && id.toLowerCase() != 'no definido') {
      return '$fuente:$id';
    }
    return '$fuente:${jsonEncode([datos['nit_entidad'] ?? datos['nombre_entidad'], datos['referencia_del_contrato'], datos['proceso_de_compra'], datos['documento_proveedor'] ?? datos['proveedor_adjudicado'], datos['fecha_de_firma'] ?? datos['fecha_de_inicio_del_contrato'], datos['objeto_del_contrato'] ?? datos['descripcion_del_proceso']])}';
  }

  ContratoDelReporte _resumen(Map<String, dynamic> datos) => ContratoDelReporte(
    datos: datos,
    expedienteCompleto: false,
    documentos: null,
  );

  @override
  String titulo(Map<String, dynamic> datos) =>
      'Proceso: ${_resumen(datos).referencia}';

  @override
  String detalle(Map<String, dynamic> datos) => _resumen(datos).objeto;

  @override
  String nombreArchivo(DateTime fecha) =>
      ReporteContratosPdfService.nombreArchivo('seleccionados', '', fecha);

  @override
  Future<Uint8List> generar(
    List<Map<String, dynamic>> lista,
    ValueChanged<int> progreso,
  ) async {
    final contratos = <ContratoDelReporte>[];
    const lote = 3;
    for (var i = 0; i < lista.length; i += lote) {
      contratos.addAll(
        await Future.wait(
          lista.skip(i).take(lote).map(ContratoDelReporte.consultar),
        ),
      );
      if (_cerrada) return Uint8List(0);
      progreso(contratos.length);
    }
    return ReporteSeleccionContratos.generar(contratos);
  }
}

class AccionesSeleccionReporte<T> extends StatelessWidget {
  const AccionesSeleccionReporte({
    super.key,
    required this.seleccion,
    required this.alDescargar,
    required this.ayuda,
  });

  final SeleccionReporte<T> seleccion;
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
                    ? 'Seleccionar ${seleccion.plural}'
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

class CasillaSeleccionReporte<T> extends StatelessWidget {
  const CasillaSeleccionReporte({
    super.key,
    required this.seleccion,
    required this.datos,
    required this.referencia,
  });

  final SeleccionReporte<T> seleccion;
  final T datos;
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

class CabeceraSeleccionReporte extends StatelessWidget {
  const CabeceraSeleccionReporte({
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
