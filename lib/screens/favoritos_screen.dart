import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'detalle_screen.dart';
import 'perfil_contratista_screen.dart';

class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  static const _claveContratos = 'contratos_favoritos';
  static const _claveContratistas = 'favoritos_contratistas';

  List<dynamic> contratosFavoritos = [];
  List<Map<String, dynamic>> contratistasFavoritos = [];
  bool isLoading = true;
  final formatoMoneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  Future<void> _cargarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    final contratosGuardados = prefs.getStringList(_claveContratos) ?? [];
    final perfilesGuardados = prefs.getStringList(_claveContratistas) ?? [];

    if (!mounted) return;
    setState(() {
      contratosFavoritos = contratosGuardados
          .map((contrato) => json.decode(contrato))
          .toList();
      contratistasFavoritos = perfilesGuardados
          .map(
            (perfil) => Map<String, dynamic>.from(json.decode(perfil) as Map),
          )
          .toList();
      isLoading = false;
    });
  }

  Future<void> _eliminarFavorito(String idUnico) async {
    final prefs = await SharedPreferences.getInstance();
    final listaStrings = prefs.getStringList(_claveContratos) ?? [];

    listaStrings.removeWhere((contrato) {
      final map = json.decode(contrato);
      final mapId =
          map['proceso_de_compra'] ??
          '${map['nombre_entidad']}${map['descripcion_del_proceso']}';
      return mapId.toString() == idUnico;
    });

    await prefs.setStringList(_claveContratos, listaStrings);
    if (!mounted) return;
    setState(() {
      contratosFavoritos.removeWhere((contrato) {
        final mapId =
            contrato['proceso_de_compra'] ??
            '${contrato['nombre_entidad']}${contrato['descripcion_del_proceso']}';
        return mapId.toString() == idUnico;
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contrato eliminado de favoritos')),
    );
  }

  Future<void> _eliminarContratista(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final listaStrings = prefs.getStringList(_claveContratistas) ?? [];

    listaStrings.removeWhere((perfil) {
      final datos = Map<String, dynamic>.from(json.decode(perfil) as Map);
      return datos['id']?.toString() == id;
    });

    await prefs.setStringList(_claveContratistas, listaStrings);
    if (!mounted) return;
    setState(() {
      contratistasFavoritos.removeWhere(
        (perfil) => perfil['id']?.toString() == id,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil eliminado de favoritos')),
    );
  }

  Color _obtenerColorEstado(String estado) {
    final estadoLower = estado.toLowerCase();
    if (estadoLower.contains('celebrado') ||
        estadoLower.contains('liquidado') ||
        estadoLower.contains('terminado')) {
      return Colors.green;
    }
    if (estadoLower.contains('enviado') ||
        estadoLower.contains('convocado') ||
        estadoLower.contains('adjudicado')) {
      return Colors.orange;
    }
    if (estadoLower.contains('borrador') || estadoLower.contains('cancelado')) {
      return Colors.grey;
    }
    return Colors.blue;
  }

  String? _obtenerDocumento(Map<String, dynamic> perfil) {
    for (final campo in ['documento', 'nit', 'numero_documento']) {
      final valor = perfil[campo]?.toString().trim();
      if (valor != null && valor.isNotEmpty) return valor;
    }
    return null;
  }

  Widget _construirListaPerfiles() {
    if (contratistasFavoritos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border_rounded,
                size: 76,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Aún no tienes perfiles guardados. Empieza a explorar para añadirlos aquí',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contratistasFavoritos.length,
      itemBuilder: (context, index) {
        final perfil = contratistasFavoritos[index];
        final nombre = perfil['nombre']?.toString() ?? 'Contratista';
        final id = perfil['id']?.toString() ?? nombre.trim().toLowerCase();
        final documento = _obtenerDocumento(perfil);

        return Card(
          color: Colors.white,
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Icon(Icons.person, color: Colors.blue.shade800),
            ),
            title: Text(
              nombre,
              style: const TextStyle(
                color: Color(0xFF17365D),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: documento == null ? null : Text('Documento: $documento'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PerfilContratistaScreen(nombreContratista: nombre),
                ),
              );
              if (mounted) await _cargarFavoritos();
            },
            trailing: IconButton(
              tooltip: 'Eliminar de favoritos',
              onPressed: () => _eliminarContratista(id),
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
            ),
          ),
        );
      },
    );
  }

  Widget _construirListaContratos() {
    if (contratosFavoritos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No tienes contratos guardados',
              style: TextStyle(
                fontSize: 18,
                color: Colors.blueGrey.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca la estrella en los resultados para hacer seguimiento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contratosFavoritos.length,
      itemBuilder: (context, index) {
        final contrato = contratosFavoritos[index];
        final colorEstado = _obtenerColorEstado(
          contrato['estado_contrato']?.toString() ?? '',
        );
        final idUnico =
            (contrato['proceso_de_compra'] ??
                    '${contrato['nombre_entidad']}${contrato['descripcion_del_proceso']}')
                .toString();
        final valor =
            double.tryParse(contrato['valor_del_contrato']?.toString() ?? '') ??
            0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DetalleContratoScreen(contrato: contrato),
                ),
              );
              if (mounted) await _cargarFavoritos();
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          contrato['nombre_entidad']?.toString() ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Eliminar de favoritos',
                        onPressed: () => _eliminarFavorito(idUnico),
                        icon: const Icon(
                          Icons.star,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contrato['descripcion_del_proceso']?.toString() ?? '',
                    style: const TextStyle(fontSize: 16),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            final proveedor = contrato['proveedor_adjudicado']
                                ?.toString();
                            if (proveedor != null && proveedor.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PerfilContratistaScreen(
                                    nombreContratista: proveedor,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            contrato['proveedor_adjudicado']?.toString() ??
                                'Por definir',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatoMoneda.format(valor),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Chip(
                        label: Text(
                          contrato['estado_contrato']?.toString() ??
                              'Desconocido',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorEstado.withOpacity(0.9),
                          ),
                        ),
                        backgroundColor: colorEstado.withOpacity(0.1),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text(
            'Mis Favoritos',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: Color(0xFF17365D),
            unselectedLabelColor: Colors.blueGrey,
            tabs: [
              Tab(text: 'Perfiles'),
              Tab(text: 'Contratos'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _construirListaPerfiles(),
                  _construirListaContratos(),
                ],
              ),
      ),
    );
  }
}
