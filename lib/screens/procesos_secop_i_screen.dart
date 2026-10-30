import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/secop_i_procesos_service.dart';
import '../services/security_service.dart';

/// Procesos que una entidad de régimen especial publicó en SECOP I.
class ProcesosSecopIScreen extends StatefulWidget {
  const ProcesosSecopIScreen({super.key, required this.entidad});

  final EntidadSecopI entidad;

  @override
  State<ProcesosSecopIScreen> createState() => _ProcesosSecopIScreenState();
}

class _ProcesosSecopIScreenState extends State<ProcesosSecopIScreen> {
  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _crema = Color(0xFFFAF5EA);

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  late Future<List<Map<String, dynamic>>> _procesos;

  @override
  void initState() {
    super.initState();
    _procesos = SecopIProcesosService.procesosDeEntidad(widget.entidad);
  }

  String _fecha(dynamic raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    return d == null ? 'Sin fecha' : DateFormat('dd/MM/yyyy').format(d);
  }

  Future<void> _abrir(dynamic ruta) async {
    final url = ruta is Map ? ruta['url']?.toString() : ruta?.toString();
    final uri = SecurityService.validateOfficialGovUrl(url);
    final abierto = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fue posible abrir el proceso en SECOP I.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entidad;
    return Scaffold(
      backgroundColor: _crema,
      appBar: AppBar(
        backgroundColor: _azulOscuro,
        foregroundColor: Colors.white,
        title: const Text('Procesos en SECOP I'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  e.nombre,
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (e.nit.isNotEmpty) 'NIT ${e.nit}',
                    if (e.municipio.isNotEmpty) e.municipio,
                    if (e.departamento.isNotEmpty) e.departamento,
                  ].join(' · '),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  '${NumberFormat.decimalPattern('es_CO').format(e.procesos)} procesos '
                  'publicados (${e.periodo}) · ${_moneda.format(e.valorEstimado)} '
                  'de cuantía estimada',
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Esta entidad no publica en SECOP II (régimen especial). En SECOP I '
                    'registró procesos convocados: muestran el objeto y la cuantía '
                    'estimada, pero no el contratista ni el valor del contrato firmado. '
                    'Su contratación más reciente puede estar en su propio portal.',
                    style: TextStyle(color: Color(0xFF92400E), fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _procesos,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final procesos = snapshot.data ?? const [];
              if (procesos.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No fue posible cargar los procesos. Inténtalo de nuevo.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Column(
                children: [
                  for (final p in procesos)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          (p['detalle_del_objeto_a_contratar'] ?? 'Sin objeto')
                              .toString(),
                          style: const TextStyle(
                            color: _azulOscuro,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            [
                              (p['numero_de_proceso'] ?? '').toString(),
                              (p['modalidad_de_contratacion'] ?? '').toString(),
                              _moneda.format(
                                double.tryParse(
                                      (p['cuantia_proceso'] ?? '').toString(),
                                    ) ??
                                    0,
                              ),
                              _fecha(p['fecha_de_cargue_en_el_secop']),
                            ].where((t) => t.isNotEmpty).join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Ver en SECOP I',
                          icon: const Icon(Icons.open_in_new_rounded),
                          onPressed: () => _abrir(p['ruta_proceso_en_secop_i']),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
