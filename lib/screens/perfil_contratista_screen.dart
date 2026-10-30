import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/favorites_service.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../services/sigep_service.dart';
import '../utils/anios_secop.dart';
import '../utils/contract_financial_calculator.dart';
import '../utils/secop_i.dart';
import '../widgets/collapsible_side_menu.dart';
import '../widgets/route_security_guard.dart';
import '../widgets/user_profile_header_action.dart';
import 'detalle_screen.dart';
import 'home_screen.dart';

class PerfilContratistaScreen extends StatefulWidget {
  final String? nombreContratista;
  final String? nombreBuscado;
  final String? nit;
  final String? documentoProveedor;
  final int? totalContractsSeed;
  final double? totalValueSeed;

  const PerfilContratistaScreen({
    super.key,
    this.nombreContratista,
    this.nombreBuscado,
    this.nit,
    this.documentoProveedor,
    this.totalContractsSeed,
    this.totalValueSeed,
  }) : assert(nombreContratista != null || nombreBuscado != null);

  @override
  State<PerfilContratistaScreen> createState() =>
      _PerfilContratistaScreenState();
}

class _PerfilContratistaScreenState extends State<PerfilContratistaScreen> {
  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _amarillo = Color(0xFFF5B82E);

  final NumberFormat formatoMoneda = NumberFormat.decimalPattern('es_CO');

  bool isLoading = true;
  bool _isSidebarCollapsed = false;
  bool _perfilFavoritoGuardado = false;
  Set<String> _contratosFavoritosIds = {};
  bool? esServidorPublico;
  String? errorSigep;
  String? errorCarga;
  double valorTotalAcumulado = 0;
  int cantidadContratos = 0;
  List<dynamic> historialContratos = [];
  String _filtroAnio = '';

  static List<String> get _aniosHistorial =>
      [for (final a in AniosSecop.disponibles) '$a'];

  String _anioContrato(dynamic c) {
    if (c is! Map) return '';
    final raw = (c['fecha_de_firma'] ??
            c['fecha_de_inicio_del_contrato'] ??
            c['anno_firma_contrato'] ??
            c['fecha_ini_ejec_contrato'] ??
            '')
        .toString();
    if (raw.length >= 4) {
      final y = raw.substring(0, 4);
      if (RegExp(r'^\d{4}$').hasMatch(y)) return y;
    }
    return '';
  }

  List<dynamic> get _contratosFiltrados {
    if (_filtroAnio.isEmpty) return historialContratos;
    return historialContratos
        .where((c) => _anioContrato(c) == _filtroAnio)
        .toList();
  }

  String get _nombreAuditar =>
      (widget.nombreBuscado ?? widget.nombreContratista ?? '').trim();

  String get _nombreMostrar {
    final raw = (widget.nombreContratista ?? widget.nombreBuscado ?? '').trim();
    return _toTitleCase(raw);
  }

  String get _idContratista => _nombreAuditar.toLowerCase();

  String? get _nitDetectado {
    if (widget.nit != null && widget.nit!.trim().isNotEmpty) {
      return widget.nit!.trim();
    }
    if (widget.documentoProveedor != null &&
        widget.documentoProveedor!.trim().isNotEmpty) {
      return widget.documentoProveedor!.trim();
    }
    for (final c in historialContratos) {
      if (c is Map && c['documento_proveedor'] != null) {
        final d = c['documento_proveedor'].toString().trim();
        if (d.isNotEmpty && d.toUpperCase() != 'NO DEFINIDO') {
          return d;
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _cargarEstadoFavorito();
    _cargarFavoritosContratosLocales();
    _cargarHistorialContratista();
    _consultarSigep();
  }

  String _toTitleCase(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return 'Contratista SECOP';
    const smallWords = {
      'de',
      'del',
      'la',
      'las',
      'el',
      'los',
      'y',
      'e',
      'en',
      'para',
      'por',
      'con',
    };
    final words = clean.toLowerCase().split(' ');
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;
      if (w == 's.a.s' || w == 's.a.s.' || w == 'sas') {
        out.add('S.A.S.');
      } else if (w == 'ltda' || w == 'ltda.') {
        out.add('LTDA');
      } else if (i > 0 && smallWords.contains(w)) {
        out.add(w);
      } else {
        out.add(w[0].toUpperCase() + w.substring(1));
      }
    }
    return out.join(' ');
  }

  Future<void> _consultarSigep() async {
    try {
      final resultado = await SigepService.verificarServidorPublico(
        _nombreAuditar,
      );
      if (!mounted) return;
      setState(() {
        esServidorPublico = resultado != null;
        errorSigep = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        esServidorPublico = false;
        errorSigep = null;
      });
    }
  }

  Future<void> _cargarEstadoFavorito() async {
    final estaGuardado =
        await FavoritesService.esContratistaFavorito(_idContratista);
    if (!mounted) return;
    setState(() => _perfilFavoritoGuardado = estaGuardado);
  }

  Future<void> _alternarFavorito() async {
    final guardado = await FavoritesService.alternarContratista(
      id: _idContratista,
      nombre: _nombreAuditar,
    );
    if (!mounted) return;
    setState(() => _perfilFavoritoGuardado = guardado);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          guardado
              ? 'Perfil guardado en favoritos'
              : 'Perfil eliminado de favoritos',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _cargarFavoritosContratosLocales() async {
    final ids = await FavoritesService.idsContratos();
    if (!mounted) return;
    setState(() => _contratosFavoritosIds = ids);
  }

  Future<void> _alternarFavoritoContrato(dynamic contrato) async {
    if (contrato is! Map) return;
    final idContrato = FavoritesService.idContrato(contrato);
    final guardado = await FavoritesService.alternarContrato(contrato);
    if (!mounted) return;
    setState(() {
      if (guardado) {
        _contratosFavoritosIds.add(idContrato);
      } else {
        _contratosFavoritosIds.remove(idContrato);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          guardado
              ? 'Contrato guardado en favoritos'
              : 'Contrato eliminado de favoritos',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  (int, double) _calcularResumen(List<dynamic> contratos) {
    var suma = 0.0;
    for (final contrato in contratos) {
      if (contrato is Map) {
        suma +=
            double.tryParse(contrato['valor_del_contrato']?.toString() ?? '') ??
                0;
      }
    }
    return (contratos.length, suma);
  }

  Future<void> _cargarHistorialContratista() async {
    try {
      final List<dynamic> allContracts = [];
      final Set<String> seenContractIds = {};

      // Un proceso de compra puede tener varios contratos con el mismo
      // proveedor, por eso se deduplica por el identificador del contrato.
      void addContractIfNew(dynamic c) {
        if (c is! Map) return;
        final id = FavoritesService.idContrato(c);
        if (seenContractIds.add(id.isNotEmpty ? id : jsonEncode(c))) {
          allContracts.add(c);
        }
      }

      Future<List<dynamic>> consultar(
        String dataset,
        Map<String, String> params,
      ) async {
        try {
          final res = await http
              .get(Uri.https('www.datos.gov.co', '/resource/$dataset.json', params))
              .timeout(const Duration(seconds: 15));
          if (res.statusCode != 200) return const [];
          final decoded = json.decode(utf8.decode(res.bodyBytes));
          return decoded is List ? decoded : const [];
        } catch (_) {
          return const [];
        }
      }


      final cleanDoc = (widget.documentoProveedor ?? widget.nit ?? '')
          .replaceAll(RegExp(r'[^0-9]'), '')
          .trim();

      // Las consultas son independientes: SECOP II por documento (índice
      // B-tree) y por nombre exacto, y SECOP I (2015-2019), en paralelo.
      final consultasSecopII = <Future<List<dynamic>>>[
        if (cleanDoc.length >= 5)
          consultar('jbjy-vk9h', {
            'documento_proveedor': cleanDoc,
            r'$order': 'fecha_de_firma DESC',
            r'$limit': '50000',
          }),
        if (_nombreAuditar.isNotEmpty)
          consultar('jbjy-vk9h', {
            'proveedor_adjudicado': _nombreAuditar,
            r'$order': 'fecha_de_firma DESC',
            r'$limit': '50000',
          }),
      ];
      final consultaSecopI = cleanDoc.length >= 5
          ? consultar(SecopI.dataset, {
              'identificacion_del_contratista': cleanDoc,
              r'$where': SecopI.filtroAnio(),
              r'$order': 'fecha_de_firma_del_contrato DESC',
              r'$limit': '2000',
            })
          : _nombreAuditar.isNotEmpty
              ? consultar(SecopI.dataset, {
                  'nom_razon_social_contratista': _nombreAuditar,
                  r'$where': SecopI.filtroAnio(),
                  r'$order': 'fecha_de_firma_del_contrato DESC',
                  r'$limit': '2000',
                })
              : Future.value(const <dynamic>[]);

      final resultados =
          await Future.wait([...consultasSecopII, consultaSecopI]);
      for (final lista in resultados.take(consultasSecopII.length)) {
        lista.forEach(addContractIfNew);
      }

      // Fallback tolerante por palabras del nombre si SECOP II no encontró nada
      if (allContracts.isEmpty && _nombreAuditar.isNotEmpty) {
        final tokens = SecurityService.sanitizeSoqlToken(
              _nombreAuditar
                  .toUpperCase()
                  .replaceAll('Á', 'A')
                  .replaceAll('É', 'E')
                  .replaceAll('Í', 'I')
                  .replaceAll('Ó', 'O')
                  .replaceAll('Ú', 'U'),
              maxLength: 100,
            )
            .split(RegExp(r'\s+'))
            .where((w) => w.length >= 2)
            .take(6)
            .toList();
        if (tokens.isNotEmpty) {
          final fallback = await consultar('jbjy-vk9h', {
            r'$where': tokens
                .map((t) => "upper(proveedor_adjudicado) LIKE '%$t%'")
                .join(' AND '),
            r'$order': 'fecha_de_firma DESC',
            r'$limit': '2000',
          });
          fallback.forEach(addContractIfNew);
        }
      }

      for (final raw in resultados.last) {
        if (raw is Map) {
          addContractIfNew(SecopI.normalizar(raw));
        }
      }

      // Ordenar contratos consolidados cronológicamente (más recientes primero)
      allContracts.sort((a, b) {
        final dateA = (a is Map ? (a['fecha_de_firma'] ?? a['fecha_de_inicio_del_contrato'] ?? '') : '').toString();
        final dateB = (b is Map ? (b['fecha_de_firma'] ?? b['fecha_de_inicio_del_contrato'] ?? '') : '').toString();
        return dateB.compareTo(dateA);
      });

      final resumen = _calcularResumen(allContracts);

      if (!mounted) return;
      setState(() {
        historialContratos = allContracts;
        cantidadContratos = allContracts.isNotEmpty
            ? resumen.$1
            : (widget.totalContractsSeed ?? 0);
        valorTotalAcumulado = allContracts.isNotEmpty
            ? resumen.$2
            : (widget.totalValueSeed ?? 0);
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorCarga = 'No fue posible cargar el historial de contratos.';
        isLoading = false;
      });
    }
  }

  String _fechaContrato(dynamic fecha) {
    if (fecha == null) return 'Fecha no disponible';
    final valor = fecha.toString();
    final parsed = DateTime.tryParse(valor);
    return parsed == null ? valor : DateFormat('dd/MM/yyyy').format(parsed);
  }

  void _onSidebarItemSelected(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => RouteSecurityGuard(
          child: HomeScreen(initialIndex: index),
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _cerrarSesion() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/portada', (route) => false);
  }

  Widget _buildHeaderRow(bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: isMobile ? 36 : 40,
            height: isMobile ? 36 : 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _azulOscuro.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back,
              color: _azulOscuro,
              size: isMobile ? 17 : 19,
            ),
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perfil Unificado',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: isMobile ? 22 : 32,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _amarillo,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: _perfilFavoritoGuardado
              ? 'Eliminar de favoritos'
              : 'Guardar en favoritos',
          child: InkWell(
            onTap: _alternarFavorito,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: isMobile ? 38 : 42,
              height: isMobile ? 38 : 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: _azulOscuro.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                _perfilFavoritoGuardado
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: _perfilFavoritoGuardado
                    ? Colors.amber.shade700
                    : _azulOscuro,
                size: isMobile ? 18 : 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        UserProfileHeaderAction(onLogout: _cerrarSesion),
      ],
    );
  }

  Widget _buildContractorIdentityCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 28,
        vertical: isMobile ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5F0FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 30,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nombreMostrar,
                            style: const TextStyle(
                              fontSize: 18.5,
                              fontWeight: FontWeight.w800,
                              color: _azulOscuro,
                              height: 1.2,
                            ),
                          ),
                          if (_nitDetectado != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              'NIT / C.C.: $_nitDetectado',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Pill 1: Contratista (SECOP)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Color(0xFF2E7D32),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Contratista (SECOP)',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pill 2: Estado SIGEP
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: esServidorPublico == true
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            esServidorPublico == true
                                ? Icons.verified_user_outlined
                                : Icons.info_outline,
                            size: 14,
                            color: esServidorPublico == true
                                ? const Color(0xFFB45309)
                                : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            esServidorPublico == true
                                ? 'Servidor Público (SIGEP)'
                                : 'No registra en SIGEP',
                            style: TextStyle(
                              color: esServidorPublico == true
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF475569),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5F0FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 44,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombreMostrar,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _azulOscuro,
                          height: 1.15,
                        ),
                      ),
                      if (_nitDetectado != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'NIT / C.C.: $_nitDetectado',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          // Pill 1: Contratista (SECOP)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4EA),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Color(0xFF2E7D32),
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Contratista (SECOP)',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Pill 2: Estado SIGEP
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: esServidorPublico == true
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFEEF2F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  esServidorPublico == true
                                      ? Icons.verified_user_outlined
                                      : Icons.info_outline,
                                  size: 16,
                                  color: esServidorPublico == true
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF475569),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  esServidorPublico == true
                                      ? 'Servidor Público (SIGEP)'
                                      : 'No registra en SIGEP',
                                  style: TextStyle(
                                    color: esServidorPublico == true
                                        ? const Color(0xFFB45309)
                                        : const Color(0xFF475569),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiSummaryRow(bool isMobile) {
    Widget kpiCard({
      required IconData icon,
      required Color iconColor,
      required Color iconBg,
      required String value,
      required String subtitle,
    }) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 22,
          vertical: isMobile ? 14 : 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _azulOscuro.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 42 : 48,
              height: isMobile ? 42 : 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: isMobile ? 22 : 25),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: isMobile ? 22 : 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return Column(
        children: [
          kpiCard(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFE8F1FF),
            value: formatoMoneda.format(cantidadContratos),
            subtitle: 'Contratos celebrados',
          ),
          const SizedBox(height: 10),
          kpiCard(
            icon: Icons.toll_outlined,
            iconColor: const Color(0xFF2E7D32),
            iconBg: const Color(0xFFE6F4EA),
            value: '\$ ${formatoMoneda.format(valorTotalAcumulado.round())}',
            subtitle: 'Valor total acumulado',
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: kpiCard(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFE8F1FF),
            value: formatoMoneda.format(cantidadContratos),
            subtitle: 'Contratos celebrados',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: kpiCard(
            icon: Icons.toll_outlined,
            iconColor: const Color(0xFF2E7D32),
            iconBg: const Color(0xFFE6F4EA),
            value: '\$ ${formatoMoneda.format(valorTotalAcumulado.round())}',
            subtitle: 'Valor total',
          ),
        ),
      ],
    );
  }

  Widget _buildHistorialContractCard(dynamic contrato, bool isMobile) {
    final entidad =
        (contrato['nombre_entidad']?.toString() ?? 'Entidad no especificada')
            .toUpperCase();
    final descripcion = (contrato['descripcion_del_proceso'] ??
            contrato['objeto_del_contrato'] ??
            'Sin descripción')
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
    final valor = double.tryParse(
          contrato['valor_del_contrato']?.toString() ?? '',
        ) ??
        0;
    final fecha = _fechaContrato(
      contrato['fecha_de_firma'] ?? contrato['fecha_de_inicio_del_contrato'],
    );
    final idContrato = FavoritesService.idContrato(contrato);
    final esFavorito = _contratosFavoritosIds.contains(idContrato);
    final analisis = ContractFinancialAnalysis.fromContract(contrato);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleContratoScreen(contrato: contrato),
            ),
          );
          if (mounted) {
            await _cargarFavoritosContratosLocales();
          }
        },
        child: Container(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF5D8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.request_quote_outlined,
                            color: Color(0xFFE5A000),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: esFavorito
                              ? 'Eliminar de favoritos'
                              : 'Guardar en favoritos',
                          onPressed: () => _alternarFavoritoContrato(contrato),
                          icon: Icon(
                            esFavorito
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: esFavorito
                                ? Colors.amber.shade700
                                : const Color(0xFF1E3A8A),
                            size: 23,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entidad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$ ${formatoMoneda.format(valor.round())}',
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (analisis.tienePlazo && analisis.valorTotal > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                analisis.esMenorAUnMes
                                    ? '${analisis.plazoDias} días total'
                                    : '≈ ${ContractFinancialAnalysis.formatCop(analisis.valorMensualEstimado)} / mes',
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 13,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  fecha,
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (analisis.tienePlazo) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${analisis.plazoDias}d · ${analisis.mesesDecimalTexto}',
                                style: const TextStyle(
                                  color: Color(0xFFB45309),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF5D8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.request_quote_outlined,
                        color: Color(0xFFE5A000),
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_outlined,
                                size: 15,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  entidad,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '\$ ${formatoMoneda.format(valor.round())}',
                                style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (analisis.tienePlazo && analisis.valorTotal > 0) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    analisis.esMenorAUnMes
                                        ? '${analisis.plazoDias} días'
                                        : '≈ ${ContractFinancialAnalysis.formatCop(analisis.valorMensualEstimado)} / mes (${analisis.mesesDecimalTexto})',
                                    style: const TextStyle(
                                      color: Color(0xFF1D4ED8),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 1,
                      height: 38,
                      color: const Color(0xFFE2E8F0),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            fecha,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 38,
                      color: const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: esFavorito
                          ? 'Eliminar de favoritos'
                          : 'Guardar en favoritos',
                      onPressed: () => _alternarFavoritoContrato(contrato),
                      icon: Icon(
                        esFavorito
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: esFavorito
                            ? Colors.amber.shade700
                            : const Color(0xFF1E3A8A),
                        size: 25,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 768;

    final bodyContent = Container(
      color: const Color(0xFFFAF5EA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPad = isMobile
              ? 16.0
              : (constraints.maxWidth > 1220 ? 32.0 : 24.0);
          return SingleChildScrollView(
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 215,
                  child: Image.asset(
                    'assets/images/fondo_valledupar.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.0, -0.38),
                    errorBuilder: (context, error, stackTrace) =>
                        Container(),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 215,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFFFAF5EA),
                          const Color(0xFFFAF5EA)
                              .withValues(alpha: 0.92),
                          const Color(0xFFFAF5EA)
                              .withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.36, 0.65],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 145,
                  left: 0,
                  right: 0,
                  height: 70,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFAF5EA)
                              .withValues(alpha: 0.0),
                          const Color(0xFFFAF5EA),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    isMobile ? 16 : 24,
                    horizontalPad,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderRow(isMobile),
                      SizedBox(height: isMobile ? 16 : 22),
                      _buildContractorIdentityCard(isMobile),
                      const SizedBox(height: 16),
                      _buildKpiSummaryRow(isMobile),
                      const SizedBox(height: 24),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Historial en SECOP',
                            style: TextStyle(
                              color: _azulOscuro,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 28,
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: _amarillo,
                              borderRadius:
                                  BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (historialContratos.isNotEmpty) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => setState(() => _filtroAnio = ''),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _filtroAnio.isEmpty
                                        ? _azulOscuro
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _filtroAnio.isEmpty
                                          ? _azulOscuro
                                          : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Text(
                                    'Todos (2015–2026): ${historialContratos.length}',
                                    style: TextStyle(
                                      color: _filtroAnio.isEmpty
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              for (final a in _aniosHistorial) ...[
                                const SizedBox(width: 8),
                                Builder(
                                  builder: (context) {
                                    final count = historialContratos
                                        .where((c) => _anioContrato(c) == a)
                                        .length;
                                    final isSelected = _filtroAnio == a;
                                    return InkWell(
                                      onTap: count > 0 || isSelected
                                          ? () => setState(() => _filtroAnio = isSelected ? '' : a)
                                          : null,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 11,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _azulOscuro
                                              : (count > 0 ? Colors.white : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected
                                                ? _azulOscuro
                                                : (count > 0
                                                    ? const Color(0xFFCBD5E1)
                                                    : const Color(0xFFE2E8F0)),
                                          ),
                                        ),
                                        child: Text(
                                          '$a ($count)',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : (count > 0
                                                    ? _azulOscuro
                                                    : const Color(0xFF94A3B8)),
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 48,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (errorCarga != null)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          child: Text(
                            errorCarga!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        )
                      else if (historialContratos.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'No se encontraron contratos registrados en SECOP para este contratista desde 2015.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13.5,
                            ),
                          ),
                        )
                      else if (_contratosFiltrados.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'No se registran contratos en el año $_filtroAnio para este contratista.',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        )
                      else
                        for (final contrato
                            in _contratosFiltrados)
                          _buildHistorialContractCard(contrato, isMobile),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF5EA),
        drawer: null,
        drawerEnableOpenDragGesture: false,
        body: SafeArea(child: bodyContent),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 3, // Contratistas tab
          onTap: (bottomIdx) {
            const mobileTabIndices = [0, 2, 3, 4, 7];
            if (bottomIdx >= 0 && bottomIdx < mobileTabIndices.length) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => HomeScreen(
                    initialIndex: mobileTabIndices[bottomIdx],
                  ),
                ),
                (route) => false,
              );
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: _azulOscuro,
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded, color: _amarillo),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description_rounded, color: _amarillo),
              label: 'Contratos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              activeIcon: Icon(Icons.account_balance_rounded, color: _amarillo),
              label: 'Entidades',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people_alt_rounded, color: _amarillo),
              label: 'Contratistas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_border_rounded),
              activeIcon: Icon(Icons.star_rounded, color: _amarillo),
              label: 'Favoritos',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EE),
      body: Row(
        children: [
          CollapsibleSideMenu(
            selectedIndex: -1,
            isCollapsed: _isSidebarCollapsed,
            onItemSelected: _onSidebarItemSelected,
            onToggleCollapse: () => setState(
              () => _isSidebarCollapsed = !_isSidebarCollapsed,
            ),
            onLogout: _cerrarSesion,
          ),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }
}

// =====================================================================
// PANTALLA SECUNDARIA DE CONTRATOS POR ENTIDAD Y PROVEEDOR
// =====================================================================

class ContratosPorEntidadScreen extends StatefulWidget {
  final String entidad;
  final String proveedor;
  final List<dynamic> contratos;

  const ContratosPorEntidadScreen({
    super.key,
    required this.entidad,
    required this.proveedor,
    required this.contratos,
  });

  @override
  State<ContratosPorEntidadScreen> createState() =>
      _ContratosPorEntidadScreenState();
}

class _ContratosPorEntidadScreenState extends State<ContratosPorEntidadScreen> {
  Set<String> favoritosIds = {};
  final formatoMoneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _cargarFavoritosLocales();
  }

  Future<void> _cargarFavoritosLocales() async {
    final ids = await FavoritesService.idsContratos();
    if (!mounted) return;
    setState(() => favoritosIds = ids);
  }

  Future<void> _toggleFavorito(dynamic contrato) async {
    if (contrato is! Map) return;
    final idUnico = FavoritesService.idContrato(contrato);
    final guardado = await FavoritesService.alternarContrato(contrato);
    if (!mounted) return;
    setState(() {
      if (guardado) {
        favoritosIds.add(idUnico);
      } else {
        favoritosIds.remove(idUnico);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(guardado ? 'Añadido a Favoritos ⭐' : 'Eliminado de Favoritos'),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contratos con Entidad',
              style: TextStyle(
                color: Color(0xFF1A2B4C),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.entidad,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A2B4C)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Mostrando ${widget.contratos.length} contratos de ${widget.proveedor} con esta entidad.',
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.contratos.length,
              itemBuilder: (context, index) {
                final contrato = widget.contratos[index];

                double valor = 0;
                if (contrato['valor_del_contrato'] != null) {
                  valor =
                      double.tryParse(
                        contrato['valor_del_contrato'].toString(),
                      ) ??
                      0;
                }
                final String valorFormateado = formatoMoneda.format(valor);
                final String estado =
                    contrato['estado_contrato'] ?? 'Desconocido';
                final Color colorEstado = _obtenerColorEstado(estado);

                final idUnico = FavoritesService.idContrato(contrato);
                final bool esFavorito = favoritosIds.contains(idUnico);

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
                      if (mounted) await _cargarFavoritosLocales();
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
                                  contrato['descripcion_del_proceso'] ??
                                      'Sin descripción',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A2B4C),
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _toggleFavorito(contrato),
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8.0,
                                    bottom: 8.0,
                                  ),
                                  child: Icon(
                                    esFavorito ? Icons.star : Icons.star_border,
                                    color: esFavorito
                                        ? Colors.orange
                                        : Colors.grey.shade400,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.gavel,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  contrato['modalidad_de_contratacion'] ??
                                      'Modalidad no definida',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                valorFormateado,
                                style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  estado,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorEstado.withValues(alpha: 0.9),
                                  ),
                                ),
                                backgroundColor: colorEstado.withValues(
                                  alpha: 0.1,
                                ),
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
            ),
          ),
        ],
      ),
    );
  }
}
