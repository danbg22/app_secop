import 'package:flutter/material.dart';

import '../services/busqueda_personas.dart';
import '../services/historial_contratista_service.dart';
import '../services/reporte_seleccion_contratos.dart';
import '../utils/contract_financial_calculator.dart';
import 'seleccion_contratos_reporte.dart';

class SeleccionarContratosContratista extends StatefulWidget {
  const SeleccionarContratosContratista({
    super.key,
    required this.nombre,
    required this.nombreBusqueda,
    required this.documento,
    required this.seleccion,
  });

  final String nombre;
  final String nombreBusqueda;
  final String documento;
  final SeleccionContratosReporte seleccion;

  @override
  State<SeleccionarContratosContratista> createState() =>
      _SeleccionarContratosContratistaState();
}

class _SeleccionarContratosContratistaState
    extends State<SeleccionarContratosContratista> {
  late var _historial = _consultar();
  String _filtro = '';

  Future<({List<Map<String, dynamic>> contratos, bool parcial})> _consultar() =>
      HistorialContratistaService.consultar(
        nombre: widget.nombreBusqueda,
        documento: widget.documento,
      );

  ContratoDelReporte _ficha(Map<String, dynamic> datos) => ContratoDelReporte(
    datos: datos,
    expedienteCompleto: false,
    documentos: null,
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Contratos de ${widget.nombre}'),
    content: SizedBox(
      width: 580,
      height: (MediaQuery.sizeOf(context).height * .48).clamp(120.0, 480.0),
      child: FutureBuilder(
        future: _historial,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final historial = snapshot.data;
          if (historial == null ||
              (historial.parcial && historial.contratos.isEmpty)) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo consultar el historial.'),
                  TextButton(
                    onPressed: () => setState(() => _historial = _consultar()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (historial.contratos.isEmpty) {
            return const Center(
              child: Text('SECOP no devolvió contratos para este contratista.'),
            );
          }
          final visibles = _filtro.isEmpty
              ? historial.contratos
              : historial.contratos.where((datos) {
                  final contrato = _ficha(datos);
                  return BusquedaPersonas.normalizar(
                    '${contrato.referencia} ${contrato.entidad} ${contrato.objeto}',
                  ).contains(_filtro);
                }).toList();
          return Column(
            children: [
              TextField(
                onChanged: (valor) => setState(
                  () => _filtro = BusquedaPersonas.normalizar(valor).trim(),
                ),
                decoration: const InputDecoration(
                  labelText: 'Buscar por referencia, entidad u objeto',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              if (historial.parcial)
                const Text('Algunas fuentes de SECOP no respondieron.'),
              const SizedBox(height: 8),
              Expanded(
                child: visibles.isEmpty
                    ? const Center(
                        child: Text('Ningún contrato coincide con el filtro.'),
                      )
                    : ListView.builder(
                        itemCount: visibles.length,
                        itemBuilder: (context, indice) {
                          final contrato = _ficha(visibles[indice]);
                          final valor = ContractFinancialAnalysis.fromContract(
                            contrato.datos,
                          );
                          return ListTile(
                            onTap: () =>
                                widget.seleccion.alternar(contrato.datos),
                            leading: CasillaContratoReporte(
                              seleccion: widget.seleccion,
                              datos: contrato.datos,
                              referencia: contrato.referencia,
                            ),
                            title: Text(
                              contrato.referencia.isEmpty
                                  ? 'Contrato sin referencia'
                                  : contrato.referencia,
                            ),
                            subtitle: Text(
                              [
                                if (contrato.entidad.isNotEmpty)
                                  contrato.entidad,
                                if (valor.tieneDatosFinancieros)
                                  ContractFinancialAnalysis.formatCop(
                                    valor.valorTotal,
                                  ),
                                if (contrato.objeto.isNotEmpty) contrato.objeto,
                              ].join(' · '),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      ListenableBuilder(
        listenable: widget.seleccion,
        builder: (context, _) =>
            Text('${widget.seleccion.cantidad} en el reporte'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Volver a contratistas'),
      ),
    ],
  );
}
