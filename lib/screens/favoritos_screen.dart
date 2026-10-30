import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/favorites_service.dart';
import '../widgets/user_profile_header_action.dart';
import 'detalle_screen.dart';
import 'perfil_contratista_screen.dart';

class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  List<Map<String, dynamic>> contratosFavoritos = [];
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
    final contratos = await FavoritesService.contratos();
    final perfiles = await FavoritesService.contratistas();
    if (!mounted) return;
    setState(() {
      contratosFavoritos = contratos;
      contratistasFavoritos = perfiles;
      isLoading = false;
    });
  }

  Future<void> _eliminarFavorito(String idUnico) async {
    await FavoritesService.eliminarContrato(idUnico);
    if (!mounted) return;
    setState(() {
      contratosFavoritos.removeWhere(
        (contrato) => FavoritesService.idContrato(contrato) == idUnico,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contrato eliminado de favoritos')),
    );
  }

  Future<void> _eliminarContratista(String id) async {
    await FavoritesService.eliminarContratista(id);
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
                  builder: (context) => PerfilContratistaScreen(
                    nombreContratista: nombre,
                    documentoProveedor: documento,
                    nit: documento,
                  ),
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
        final idUnico = FavoritesService.idContrato(contrato);
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
                              final docProveedor =
                                  contrato['documento_proveedor']?.toString();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PerfilContratistaScreen(
                                    nombreContratista: proveedor,
                                    nombreBuscado: proveedor,
                                    documentoProveedor: docProveedor,
                                    nit: docProveedor,
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
                            color: colorEstado.withValues(alpha: 0.9),
                          ),
                        ),
                        backgroundColor: colorEstado.withValues(alpha: 0.1),
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
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return DefaultTabController(
      length: 2,
      child: ColoredBox(
        color: const Color(0xFFFFF8EE),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 32,
                isMobile ? 16 : 26,
                isMobile ? 16 : 32,
                12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis favoritos',
                          style: TextStyle(
                            color: const Color(0xFF1A2B4C),
                            fontWeight: FontWeight.w800,
                            fontSize: isMobile ? 22 : 30,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 36,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5B82E),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile && widget.onLogout != null)
                    UserProfileHeaderAction(onLogout: widget.onLogout!),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const TabBar(
                  labelColor: Color(0xFF1A2B4C),
                  unselectedLabelColor: Color(0xFF64748B),
                  indicatorColor: Color(0xFF1A2B4C),
                  dividerColor: Colors.transparent,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  tabs: [
                    Tab(text: 'Perfiles guardados'),
                    Tab(text: 'Contratos guardados'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _construirListaPerfiles(),
                        _construirListaContratos(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
