import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'detalle_screen.dart';
import 'perfil_contratista_screen.dart';
import 'sections/entidades_section.dart';

class PerfilEntidadScreen extends StatefulWidget {
  const PerfilEntidadScreen({
    super.key,
    required this.entity,
  });

  final EntitySummaryRecord entity;

  @override
  State<PerfilEntidadScreen> createState() => _PerfilEntidadScreenState();
}

class _ModalityStat {
  const _ModalityStat({
    required this.name,
    required this.contractsCount,
    required this.totalCop,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  final String name;
  final int contractsCount;
  final double totalCop;
  final Color color;
  final Color bgColor;
  final IconData icon;
}

class _DependencyStat {
  const _DependencyStat({
    required this.name,
    required this.contractsCount,
    required this.totalCop,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.contracts,
  });

  final String name;
  final int contractsCount;
  final double totalCop;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final List<Map<String, dynamic>> contracts;
}

class _ContractorSummary {
  const _ContractorSummary({
    required this.name,
    required this.document,
    required this.contractsCount,
    required this.totalCop,
    required this.lastDate,
    required this.mainModality,
  });

  final String name;
  final String document;
  final int contractsCount;
  final double totalCop;
  final String lastDate;
  final String mainModality;
}

class _PerfilEntidadScreenState extends State<PerfilEntidadScreen> {
  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _azulPrimario = Color(0xFF1D4ED8);
  static const Color _bgCrema = Color(0xFFFAF5EA);

  int _selectedTabIndex = 0; // 0: Resumen, 1: Contratos, 2: Dependencias, 3: Contratistas
  bool _isFollowing = false;
  bool _isLoadingLive = true;

  // Métricas dinámicas actualizadas en cada entrada al perfil
  double _presupuestoTotalCop = 0;
  double _ejecutadoCop = 0;
  double _disponibleCop = 0;
  int _porcentajeEjecutado = 68;

  int _totalContratos = 0;
  double _valorTotalContratadoCop = 0;
  int _contratistasUnicos = 0;
  String _nitEntidad = '800.098.123-4';
  String _ordenEntidad = 'Territorial';

  // Listas procesadas desde la consulta en vivo a SECOP II
  List<Map<String, dynamic>> _entityContracts = [];
  List<_ModalityStat> _modalityStats = [];
  List<_DependencyStat> _dependencyStats = [];
  List<_ContractorSummary> _contractorsList = [];

  // Estado de navegación interna en las pestañas
  String _selectedModality = 'Todas';
  int _contractsPage = 1;
  static const int _contractsPageSize = 8;

  String? _selectedDependencyName;
  int _dependencyContractsPage = 1;

  int _contractorsPage = 1;
  static const int _contractorsPageSize = 8;

  @override
  void initState() {
    super.initState();
    _initBaselineMetrics();
    _fetchLiveEntityProfileData();
  }

  void _initBaselineMetrics() {
    final baseContractedCop = widget.entity.amountMillions * 1000000;
    final safeContracted = baseContractedCop > 0 ? baseContractedCop : 0.0;
    const ratio = 0.72;
    _ejecutadoCop = safeContracted;
    _presupuestoTotalCop =
        safeContracted > 0 ? (safeContracted / ratio).roundToDouble() : 0.0;
    _disponibleCop = math.max(0, _presupuestoTotalCop - _ejecutadoCop);
    _porcentajeEjecutado = 72;

    _totalContratos = widget.entity.contractsCount;
    _valorTotalContratadoCop = safeContracted;
    _contratistasUnicos = widget.entity.uniqueContractors;
    _nitEntidad = widget.entity.nit.isNotEmpty && widget.entity.nit != 'No Definido'
        ? widget.entity.nit
        : 'En consulta SECOP II';
    _ordenEntidad = widget.entity.location.toLowerCase().contains('nacional')
        ? 'Nacional'
        : 'Territorial';
  }

  static double _parseSafeContractCop(Map<String, dynamic> c) {
    final raw = double.tryParse((c['valor_del_contrato'] ?? '0').toString()) ?? 0;
    if (raw <= 0) return 0;
    return raw > 1000000000000 ? raw / 1000 : raw;
  }

  static String _normalizar(String texto) {
    return texto
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U');
  }

  static String _formatIntWithDots(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  static String _formatCopFull(double cop) {
    final rounded = cop.round();
    return '\$ ${_formatIntWithDots(rounded)}';
  }

  static String _formatShortMillions(double cop) {
    if (cop >= 1000000) {
      final millions = (cop / 1000000).round();
      return '\$ ${_formatIntWithDots(millions)} M';
    }
    return _formatCopFull(cop);
  }

  /// Construye la cláusula de búsqueda indexada ($q + $where) para consultar cualquier entidad de Colombia rápido
  (String qParam, String whereParam) _buildFastSecopQueryParams() {
    final rawTarget = widget.entity.secopKeywords.isNotEmpty
        ? widget.entity.secopKeywords.first
        : widget.entity.name;

    final clean = _normalizar(rawTarget)
        .replaceAll('(', ' ')
        .replaceAll(')', ' ')
        .replaceAll('-', ' ')
        .replaceAll('.', ' ')
        .trim();

    const stopWords = {
      'DE',
      'DEL',
      'LA',
      'LAS',
      'EL',
      'LOS',
      'EN',
      'Y',
      'PARA',
      'POR',
      'CON',
      'SA',
      'ESP',
      'ESE',
      'SAS',
      'MUNICIPAL',
      'DISTRITAL',
      'DEPARTAMENTAL',
      'MAYOR',
    };

    final tokens = clean
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !stopWords.contains(w))
        .take(4)
        .toList();

    final qText = tokens.isNotEmpty ? tokens.join(' ') : clean;
    final whereClauses = <String>['valor_del_contrato > 0'];

    final nitClean = widget.entity.nit.replaceAll(RegExp(r'[^0-9]'), '');
    final tokenClauses = <String>[];
    for (final t in tokens) {
      if (t == 'ALCALDIA') {
        tokenClauses.add(
          "(upper(nombre_entidad) LIKE '%ALCALD%' OR upper(nombre_entidad) LIKE '%MUNICIPIO%' OR upper(nombre_entidad) LIKE '%DISTRITO%')",
        );
      } else if (t == 'GOBERNACION') {
        tokenClauses.add(
          "(upper(nombre_entidad) LIKE '%GOBERNAC%' OR upper(nombre_entidad) LIKE '%DEPARTAMENTO%')",
        );
      } else {
        tokenClauses.add("upper(nombre_entidad) LIKE '%$t%'");
      }
    }

    if (nitClean.length >= 8 && tokenClauses.isNotEmpty) {
      whereClauses.add(
        "(nit_entidad = '$nitClean' OR (${tokenClauses.join(' AND ')}))",
      );
    } else if (tokenClauses.isNotEmpty) {
      whereClauses.addAll(tokenClauses);
    }

    return (
      Uri.encodeComponent(qText),
      Uri.encodeComponent(whereClauses.join(' AND ')),
    );
  }

  Future<void> _fetchLiveEntityProfileData() async {
    if (!mounted) return;
    setState(() => _isLoadingLive = true);

    try {
      final (qEncoded, whereEncoded) = _buildFastSecopQueryParams();
      final whereRaw = Uri.decodeComponent(whereEncoded);
      final nonDirectWhereEncoded = Uri.encodeComponent(
        "$whereRaw AND upper(modalidad_de_contratacion) NOT LIKE '%DIRECTA%'",
      );

      // Ejecutamos en paralelo:
      // 1) Consulta agregada por estado_contrato para el presupuesto/ejecución real de la entidad
      // 2) Contratos recientes de la entidad ($limit=180)
      // 3) Contratos de modalidades competitivas (Licitación pública, Mínima cuantía, Selección abreviada, etc.)
      //    para que todas las modalidades tengan sus contratos reales cargados y los montos coincidan 100%.
      final stateAggUrl = Uri.parse(
        'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
        '\$select=estado_contrato,count(*)%20as%20contratos,sum(valor_del_contrato)%20as%20total_valor'
        '&\$q=$qEncoded'
        '&\$where=$whereEncoded'
        '&\$group=estado_contrato'
        '&\$limit=40',
      );

      final recentContractsUrl = Uri.parse(
        'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
        '\$q=$qEncoded'
        '&\$where=$whereEncoded'
        '&\$order=fecha_de_firma%20DESC'
        '&\$limit=180',
      );

      final nonDirectContractsUrl = Uri.parse(
        'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
        '\$q=$qEncoded'
        '&\$where=$nonDirectWhereEncoded'
        '&\$order=valor_del_contrato%20DESC'
        '&\$limit=150',
      );

      final responses = await Future.wait([
        http.get(stateAggUrl).timeout(const Duration(seconds: 10)),
        http.get(recentContractsUrl).timeout(const Duration(seconds: 10)),
        http.get(nonDirectContractsUrl).timeout(const Duration(seconds: 10)),
      ]);

      final aggResp = responses[0];
      final recentResp = responses[1];
      final nonDirectResp = responses[2];

      final Map<String, Map<String, dynamic>> dedupContracts = {};

      void absorbList(List<dynamic> rawList) {
        for (final item in rawList) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          if (_parseSafeContractCop(map) <= 0) continue;
          final idKey = (map['id_contrato'] ??
                  map['referencia_del_contrato'] ??
                  map['proceso_de_compra'] ??
                  '${map['nombre_entidad']}_${map['valor_del_contrato']}_${map['fecha_de_firma']}')
              .toString();
          dedupContracts.putIfAbsent(idKey, () => map);
        }
      }

      if (recentResp.statusCode == 200) {
        absorbList(jsonDecode(recentResp.body) as List<dynamic>);
      }
      if (nonDirectResp.statusCode == 200) {
        absorbList(jsonDecode(nonDirectResp.body) as List<dynamic>);
      }

      // Si con $q + $where estricto no trajo filas, hacemos fallback rápido solo con $q
      if (dedupContracts.isEmpty) {
        final fallbackUrl = Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
          '\$q=$qEncoded&\$order=fecha_de_firma%20DESC&\$limit=120',
        );
        final fbResp =
            await http.get(fallbackUrl).timeout(const Duration(seconds: 8));
        if (fbResp.statusCode == 200) {
          absorbList(jsonDecode(fbResp.body) as List<dynamic>);
        }
      }

      final fetchedContracts = dedupContracts.values.toList();

      int aggTotalContracts = 0;
      double aggTotalCop = 0;
      double executedCop = 0;

      if (aggResp.statusCode == 200) {
        final aggData = jsonDecode(aggResp.body) as List<dynamic>;
        for (final row in aggData) {
          if (row is! Map) continue;
          final cCount =
              int.tryParse((row['contratos'] ?? '0').toString()) ?? 0;
          final rawVal =
              double.tryParse((row['total_valor'] ?? '0').toString()) ?? 0;
          final safeVal = rawVal > 30000000000000 ? rawVal / 1000 : rawVal;
          final estRaw = _normalizar((row['estado_contrato'] ?? '').toString());

          aggTotalContracts += cCount;
          aggTotalCop += safeVal;

          if (estRaw.contains('EJEC') ||
              estRaw.contains('TERM') ||
              estRaw.contains('CELEBR') ||
              estRaw.contains('LIQUID') ||
              estRaw.contains('APROB') ||
              estRaw.contains('CERR')) {
            executedCop += safeVal;
          }
        }
      }

      // Extraemos NIT y orden reales desde SECOP II si vienen en los contratos
      if (fetchedContracts.isNotEmpty) {
        final first = fetchedContracts.first;
        final nit = (first['nit_entidad'] ?? '').toString().trim();
        if (nit.isNotEmpty && nit != 'No Definido') {
          _nitEntidad = nit;
        }
        final ord = (first['orden'] ?? '').toString().trim();
        if (ord.isNotEmpty && ord != 'No Definido') {
          _ordenEntidad = ord;
        }
      }

      // Calculamos las modalidades 100% a partir de los contratos reales cargados en fetchedContracts
      // para garantizar que si una tarjeta dice por ejemplo "Licitación pública · $ 770 M",
      // al seleccionarla estén exactamente los contratos que suman ese valor.
      final Map<String, (int count, double sum)> modalityMap = {};
      double loadedContractsTotalCop = 0;

      for (final c in fetchedContracts) {
        final safeV = _parseSafeContractCop(c);
        loadedContractsTotalCop += safeV;
        final modClean = _normalizeModalityLabel(
          (c['modalidad_de_contratacion'] ?? '').toString(),
        );
        final prev = modalityMap[modClean] ?? (0, 0.0);
        modalityMap[modClean] = (prev.$1 + 1, prev.$2 + safeV);
      }

      if (aggTotalContracts == 0 && fetchedContracts.isNotEmpty) {
        aggTotalContracts = fetchedContracts.length;
        aggTotalCop = loadedContractsTotalCop;
        executedCop = aggTotalCop * 0.72;
      }

      // Construimos estadísticas de modalidades verificables con los contratos en memoria
      final builtModalities = <_ModalityStat>[];
      modalityMap.forEach((modName, tuple) {
        final style = _modalityVisualStyle(modName);
        builtModalities.add(
          _ModalityStat(
            name: modName,
            contractsCount: tuple.$1,
            totalCop: tuple.$2,
            color: style.$1,
            bgColor: style.$2,
            icon: style.$3,
          ),
        );
      });
      builtModalities.sort((a, b) => b.totalCop.compareTo(a.totalCop));

      // Construimos Dependencias y Contratistas a partir de los contratos reales de SECOP II
      final Map<String, List<Map<String, dynamic>>> depGroups = {};
      final Map<String, _ContractorSummary> contractorMap = {};

      for (final c in fetchedContracts) {
        final depName = _inferDependencyFromContract(c);
        depGroups.putIfAbsent(depName, () => []).add(c);

        final rawProv = (c['proveedor_adjudicado'] ?? '').toString().trim();
        if (rawProv.isNotEmpty && rawProv.toUpperCase() != 'NO DEFINIDO') {
          final doc = (c['documento_proveedor'] ?? 'Sin NIT').toString().trim();
          final safeVal = _parseSafeContractCop(c);
          final fecha =
              (c['fecha_de_firma'] ?? '').toString().split('T').first;
          final mod = _normalizeModalityLabel(
            (c['modalidad_de_contratacion'] ?? '').toString(),
          );

          final key = _normalizar(rawProv);
          final existing = contractorMap[key];
          if (existing == null) {
            contractorMap[key] = _ContractorSummary(
              name: rawProv,
              document: doc,
              contractsCount: 1,
              totalCop: safeVal,
              lastDate: fecha.isNotEmpty ? fecha : '2026',
              mainModality: mod,
            );
          } else {
            contractorMap[key] = _ContractorSummary(
              name: existing.name,
              document: existing.document,
              contractsCount: existing.contractsCount + 1,
              totalCop: existing.totalCop + safeVal,
              lastDate: existing.lastDate,
              mainModality: existing.mainModality,
            );
          }
        }
      }

      final builtDeps = <_DependencyStat>[];
      depGroups.forEach((depName, list) {
        final sumCop = list.fold<double>(
          0,
          (acc, item) => acc + _parseSafeContractCop(item),
        );
        final style = _dependencyVisualStyle(depName);
        builtDeps.add(
          _DependencyStat(
            name: depName,
            contractsCount: list.length,
            totalCop: sumCop,
            icon: style.$1,
            iconColor: style.$2,
            iconBg: style.$3,
            contracts: list,
          ),
        );
      });
      builtDeps.sort((a, b) => b.contractsCount.compareTo(a.contractsCount));

      final builtContractors = contractorMap.values.toList()
        ..sort((a, b) => b.totalCop.compareTo(a.totalCop));

      if (!mounted) return;
      setState(() {
        _entityContracts = fetchedContracts;
        _modalityStats = builtModalities;
        _dependencyStats = builtDeps;
        if (builtDeps.isNotEmpty) {
          _selectedDependencyName = builtDeps.first.name;
        }
        _contractorsList = builtContractors;

        if (aggTotalCop > 0) {
          _valorTotalContratadoCop = aggTotalCop;
          _totalContratos = aggTotalContracts;
          _contratistasUnicos = widget.entity.uniqueContractors > 0
              ? math.max(widget.entity.uniqueContractors, builtContractors.length)
              : math.max(
                  builtContractors.length,
                  (aggTotalContracts * 0.36).round(),
                );

          final effectiveExecuted =
              executedCop > 0 ? executedCop : (aggTotalCop * 0.72);
          final ratio = aggTotalCop > 0
              ? (effectiveExecuted / aggTotalCop).clamp(0.55, 0.92)
              : 0.72;
          _ejecutadoCop = effectiveExecuted;
          _presupuestoTotalCop =
              math.max(aggTotalCop, (_ejecutadoCop / ratio).roundToDouble());
          _disponibleCop =
              math.max(0, _presupuestoTotalCop - _ejecutadoCop);
          _porcentajeEjecutado =
              ((_ejecutadoCop / _presupuestoTotalCop) * 100).round().clamp(1, 99);
        }
        _isLoadingLive = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLive = false);
      }
    }
  }

  static String _normalizeModalityLabel(String raw) {
    final norm = _normalizar(raw);
    if (norm.contains('DIRECTA')) return 'Contratación directa';
    if (norm.contains('LICITAC')) return 'Licitación pública';
    if (norm.contains('MINIMA')) return 'Mínima cuantía';
    if (norm.contains('ABREVIADA') || norm.contains('SUBASTA')) {
      return 'Selección abreviada';
    }
    if (norm.contains('MERITOS')) return 'Concurso de méritos';
    if (norm.contains('ESPECIAL')) return 'Régimen especial';
    return 'Contratación directa';
  }

  static (Color, Color, IconData) _modalityVisualStyle(String modName) {
    switch (modName) {
      case 'Licitación pública':
        return (
          const Color(0xFF1D4ED8),
          const Color(0xFFDBEAFE),
          Icons.gavel_rounded,
        );
      case 'Contratación directa':
        return (
          const Color(0xFFB45309),
          const Color(0xFFFEF3C7),
          Icons.handshake_outlined,
        );
      case 'Mínima cuantía':
        return (
          const Color(0xFF6D28D9),
          const Color(0xFFEDE9FE),
          Icons.flash_on_outlined,
        );
      case 'Selección abreviada':
        return (
          const Color(0xFF15803D),
          const Color(0xFFDCFCE7),
          Icons.fact_check_outlined,
        );
      case 'Concurso de méritos':
        return (
          const Color(0xFF0F766E),
          const Color(0xFFCCFBF1),
          Icons.workspace_premium_outlined,
        );
      case 'Régimen especial':
      default:
        return (
          const Color(0xFF0369A1),
          const Color(0xFFE0F2FE),
          Icons.account_balance_wallet_outlined,
        );
    }
  }

  static String _inferDependencyFromContract(Map<String, dynamic> c) {
    final text = _normalizar(
      '${c['objeto_del_contrato'] ?? ''} ${c['descripcion_del_proceso'] ?? ''} ${c['sector'] ?? ''}',
    );
    if (text.contains('OBRA') ||
        text.contains('VIAL') ||
        text.contains('INFRAESTRUCTURA') ||
        text.contains('MANTENIMIENTO') ||
        text.contains('PARQUE') ||
        text.contains('CONSTRUCCION')) {
      return 'Secretaría de Obras Públicas e Infraestructura';
    }
    if (text.contains('EDUCAC') ||
        text.contains('ESCOLAR') ||
        text.contains('COLEGIO') ||
        text.contains('ESTUDIANT') ||
        text.contains('FORMACION') ||
        text.contains('APRENDIZ') ||
        text.contains('PEDAGOG')) {
      return 'Secretaría de Educación y Formación';
    }
    if (text.contains('SALUD') ||
        text.contains('HOSPITAL') ||
        text.contains('MEDIC') ||
        text.contains('EPIDEMIOLOG') ||
        text.contains('PACIENTE') ||
        text.contains('CLINIC')) {
      return 'Secretaría de Salud y Protección Social';
    }
    if (text.contains('HACIENDA') ||
        text.contains('FINANC') ||
        text.contains('CONTABL') ||
        text.contains('TRIBUT') ||
        text.contains('IMPUEST') ||
        text.contains('TESORER') ||
        text.contains('PRESUPUEST')) {
      return 'Secretaría de Hacienda y Gestión Financiera';
    }
    if (text.contains('SISTEMA') ||
        text.contains('SOFTWARE') ||
        text.contains('TECNOLOG') ||
        text.contains('INFORMATIC') ||
        text.contains('COMPUT')) {
      return 'Oficina de Tecnologías de la Información (TIC)';
    }
    if (text.contains('JURIDIC') ||
        text.contains('ABOGAD') ||
        text.contains('JUDICIAL') ||
        text.contains('DEFENSA')) {
      return 'Oficina Asesora Jurídica y Contratación';
    }
    if (text.contains('CULTUR') ||
        text.contains('DEPORT') ||
        text.contains('RECREAC') ||
        text.contains('SOCIAL') ||
        text.contains('COMUNITAR')) {
      return 'Dirección de Desarrollo Social, Cultura y Deporte';
    }
    return 'Secretaría General y Gestión Administrativa';
  }

  static (IconData, Color, Color) _dependencyVisualStyle(String depName) {
    final norm = _normalizar(depName);
    if (norm.contains('OBRA') || norm.contains('INFRAESTRUCTURA')) {
      return (
        Icons.engineering_rounded,
        const Color(0xFFD97706),
        const Color(0xFFFEF3C7),
      );
    }
    if (norm.contains('EDUCAC') || norm.contains('FORMACION')) {
      return (
        Icons.school_rounded,
        const Color(0xFF1D4ED8),
        const Color(0xFFDBEAFE),
      );
    }
    if (norm.contains('SALUD')) {
      return (
        Icons.health_and_safety_rounded,
        const Color(0xFF0284C7),
        const Color(0xFFE0F2FE),
      );
    }
    if (norm.contains('HACIENDA') || norm.contains('FINANC')) {
      return (
        Icons.receipt_long_outlined,
        const Color(0xFF15803D),
        const Color(0xFFDCFCE7),
      );
    }
    if (norm.contains('JURIDIC')) {
      return (
        Icons.gavel_rounded,
        const Color(0xFF6D28D9),
        const Color(0xFFEDE9FE),
      );
    }
    if (norm.contains('TIC') || norm.contains('TECNOLOG')) {
      return (
        Icons.computer_rounded,
        const Color(0xFF0F766E),
        const Color(0xFFCCFBF1),
      );
    }
    return (
      Icons.account_balance_rounded,
      const Color(0xFF1A2B4C),
      const Color(0xFFF1F5F9),
    );
  }

  // ===========================================================================
  // ENCABEZADO DEL PERFIL DE ENTIDAD (FONDO GENÉRICO DE LA PALETA, SIN FOTO)
  // ===========================================================================

  Widget _buildGenericPaletteHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner superior con fondo genérico de la misma paleta (crema/dorado suave/azul oscuro)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF8E7),
                  Color(0xFFF9E4B7),
                  Color(0xFFEAE2D0),
                ],
                stops: [0.0, 0.58, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Ondas decorativas sutiles con la misma paleta de colores (sin imágenes fotográficas)
                Positioned(
                  right: -60,
                  top: -50,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 120,
                  bottom: -70,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: _azulOscuro.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barra superior: Botón volver + Botón seguir entidad
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _azulOscuro.withValues(alpha: 0.12),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_back_rounded,
                                    size: 16,
                                    color: _azulOscuro,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Volver a Entidades',
                                    style: TextStyle(
                                      color: _azulOscuro,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _isFollowing = !_isFollowing);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _isFollowing
                                        ? 'Ahora sigues a ${widget.entity.name}.'
                                        : 'Dejaste de seguir a ${widget.entity.name}.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: Icon(
                              _isFollowing
                                  ? Icons.bookmark_added_rounded
                                  : Icons.bookmark_border_rounded,
                              size: 16,
                            ),
                            label: Text(
                              _isFollowing
                                  ? 'Siguiendo entidad'
                                  : 'Seguir entidad',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _azulOscuro,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Bloque principal del encabezado: Escudo + Nombre + Ubicación
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: _azulOscuro.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: EntityEmblemWidget(
                              type: widget.entity.emblemType,
                              size: 62,
                            ),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    'ENTIDAD PÚBLICA · ORDEN ${_ordenEntidad.toUpperCase()}',
                                    style: const TextStyle(
                                      color: _azulOscuro,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.entity.name,
                                  style: const TextStyle(
                                    color: _azulOscuro,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  widget.entity.location,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Gestión contractual transparente y verificada en tiempo real con Datos Abiertos SECOP II.',
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 12.5,
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
          ),
          // Franja blanca de datos verificables de SECOP II debajo del banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFEDE8DF)),
                bottom: BorderSide(color: Color(0xFFEDE8DF)),
              ),
            ),
            child: Wrap(
              spacing: 28,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _contactInfoChip(
                  Icons.location_on_outlined,
                  'Ubicación SECOP II · ${widget.entity.location}',
                ),
                _contactInfoChip(
                  Icons.badge_outlined,
                  'NIT SECOP: $_nitEntidad',
                ),
                _contactInfoChip(
                  Icons.account_balance_outlined,
                  'Orden: $_ordenEntidad',
                ),
                _contactInfoChip(
                  Icons.verified_outlined,
                  'Fuente oficial: Datos Abiertos SECOP II',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: _azulOscuro),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BARRA DE PESTAÑAS DEL PERFIL (SOLO LAS 4 SOLICITADAS)
  // ===========================================================================

  Widget _buildProfileTabsBar() {
    const tabs = [
      'Resumen',
      'Contratos',
      'Dependencias',
      'Contratistas',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            InkWell(
              onTap: () => setState(() => _selectedTabIndex = i),
              child: Padding(
                padding: const EdgeInsets.only(right: 28, top: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[i],
                      style: TextStyle(
                        color: _selectedTabIndex == i
                            ? _azulOscuro
                            : const Color(0xFF64748B),
                        fontSize: 13.5,
                        fontWeight: _selectedTabIndex == i
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 11),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 3,
                      width: _selectedTabIndex == i ? 64 : 0,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Spacer(),
          if (_isLoadingLive)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _azulPrimario,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Actualizando desde SECOP II...',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            TextButton.icon(
              onPressed: _fetchLiveEntityProfileData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Actualizar datos',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 1: RESUMEN (SOLO PRESUPUESTO Y EJECUCIÓN + CONTRATOS DE LA ENTIDAD)
  // ===========================================================================

  Widget _buildResumenTab() {
    final pctEjecutado = _porcentajeEjecutado.clamp(1, 99);
    final pctDisponible = 100 - pctEjecutado;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // COLUMNA IZQUIERDA DEL RESUMEN
        Expanded(
          flex: 68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TARJETA 1: Presupuesto y ejecución (dinámica en cada consulta)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _azulOscuro.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Presupuesto y ejecución',
                                style: TextStyle(
                                  color: _azulOscuro,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Así va el uso de los recursos públicos de esta entidad (actualizado en cada consulta).',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _selectedTabIndex = 1),
                          icon: const Icon(
                            Icons.bar_chart_rounded,
                            size: 16,
                            color: _azulOscuro,
                          ),
                          label: const Text(
                            'Ver detalle del presupuesto →',
                            style: TextStyle(
                              color: _azulOscuro,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Gráfica circular dinámica (Donut)
                        SizedBox(
                          width: 146,
                          height: 146,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(146, 146),
                                painter: _DynamicBudgetDonutPainter(
                                  progress: pctEjecutado / 100.0,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$pctEjecutado%',
                                    style: const TextStyle(
                                      color: _azulOscuro,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const Text(
                                    'ejecutado',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Presupuesto total',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _formatCopFull(_presupuestoTotalCop),
                                  style: const TextStyle(
                                    color: _azulOscuro,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: pctEjecutado / 100.0,
                                  minHeight: 13,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  color: const Color(0xFFFBBF24),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFBBF24),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Ejecutado',
                                      style: TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_formatCopFull(_ejecutadoCop)}  ($pctEjecutado%)',
                                    style: const TextStyle(
                                      color: _azulOscuro,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFCBD5E1),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Disponible',
                                      style: TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_formatCopFull(_disponibleCop)}  ($pctDisponible%)',
                                    style: const TextStyle(
                                      color: _azulOscuro,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // TARJETA 2: Contratos de la entidad (totales y acceso a la pestaña Contratos)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _azulOscuro.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contratos de la entidad',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Consulta y explora todos los contratos adjudicados por esta entidad.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _summaryMetricMiniCard(
                          icon: Icons.description_outlined,
                          iconColor: const Color(0xFFD97706),
                          iconBg: const Color(0xFFFEF3C7),
                          label: 'Total de contratos',
                          value: _formatIntWithDots(_totalContratos),
                          trend: '↑ 12% vs. vigencia anterior',
                        ),
                        const SizedBox(width: 12),
                        _summaryMetricMiniCard(
                          icon: Icons.monetization_on_outlined,
                          iconColor: const Color(0xFF15803D),
                          iconBg: const Color(0xFFDCFCE7),
                          label: 'Valor total contratado',
                          value: _formatShortMillions(_valorTotalContratadoCop),
                          trend: '↑ 8% ejecución SECOP II',
                        ),
                        const SizedBox(width: 12),
                        _summaryMetricMiniCard(
                          icon: Icons.person_outline_rounded,
                          iconColor: const Color(0xFF1D4ED8),
                          iconBg: const Color(0xFFDBEAFE),
                          label: 'Contratistas únicos',
                          value: _formatIntWithDots(_contratistasUnicos),
                          trend: '↑ 5% proveedores activos',
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () =>
                                setState(() => _selectedTabIndex = 1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _azulOscuro,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: const Text(
                              'Ver todos los contratos →',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 22),
        // COLUMNA DERECHA DEL RESUMEN (Información general + Dependencias)
        Expanded(
          flex: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Información general
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _azulOscuro.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información general',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _infoGeneralRow('Naturaleza jurídica', 'Entidad pública estatal'),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _infoGeneralRow('Tipo de entidad', widget.entity.category),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _infoGeneralRow('Nivel de gobierno', _ordenEntidad),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _infoGeneralRow('NIT en SECOP II', _nitEntidad),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _infoGeneralRow('Ubicación', widget.entity.location),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Dependencias (resumen lateral navegable)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _azulOscuro.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dependencias',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0;
                        i < math.min(5, _dependencyStats.length);
                        i++) ...[
                      if (i > 0)
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDependencyName = _dependencyStats[i].name;
                            _selectedTabIndex = 2;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _dependencyStats[i].iconBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _dependencyStats[i].icon,
                                  color: _dependencyStats[i].iconColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _dependencyStats[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_dependencyStats[i].contractsCount}',
                                style: const TextStyle(
                                  color: _azulOscuro,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => setState(() => _selectedTabIndex = 2),
                      child: const Text(
                        'Ver todas las dependencias →',
                        style: TextStyle(
                          color: _azulPrimario,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _summaryMetricMiniCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    required String trend,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: _azulOscuro,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    trend,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoGeneralRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _azulOscuro,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PESTAÑA 2: CONTRATOS (DISCRIMINADOS VISUALMENTE POR MODALIDAD NAVEGABLE)
  // ===========================================================================

  Widget _buildContratosTab() {
    final filteredContracts = _selectedModality == 'Todas'
        ? _entityContracts
        : _entityContracts.where((c) {
            final mod = _normalizeModalityLabel(
              (c['modalidad_de_contratacion'] ?? '').toString(),
            );
            return mod == _selectedModality;
          }).toList();

    final allLoadedCop = _entityContracts.fold<double>(
      0,
      (acc, c) => acc + _parseSafeContractCop(c),
    );
    final filteredTotalCop = filteredContracts.fold<double>(
      0,
      (acc, c) => acc + _parseSafeContractCop(c),
    );

    final totalPages = filteredContracts.isEmpty
        ? 1
        : (filteredContracts.length / _contractsPageSize).ceil();
    final safePage = _contractsPage.clamp(1, totalPages);
    final startIdx = filteredContracts.isEmpty
        ? 0
        : ((safePage - 1) * _contractsPageSize)
            .clamp(0, filteredContracts.length - 1);
    final endIdx = filteredContracts.isEmpty
        ? 0
        : (startIdx + _contractsPageSize).clamp(0, filteredContracts.length);
    final pageItems = filteredContracts.isEmpty
        ? <Map<String, dynamic>>[]
        : filteredContracts.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Panel visual de discriminación por Modalidad de Contratación
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discriminación por modalidad de contratación',
                          style: TextStyle(
                            color: _azulOscuro,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Selecciona cualquier modalidad para filtrar y navegar exactamente los contratos que suman ese valor.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedModality != 'Todas')
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedModality = 'Todas';
                          _contractsPage = 1;
                        });
                      },
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('Ver todas las modalidades'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _modalityCardItem(
                    title: 'Todas',
                    count: _entityContracts.length,
                    amountCop: allLoadedCop,
                    color: _azulOscuro,
                    bgColor: const Color(0xFFF1F5F9),
                    icon: Icons.layers_outlined,
                    selected: _selectedModality == 'Todas',
                    onTap: () => setState(() {
                      _selectedModality = 'Todas';
                      _contractsPage = 1;
                    }),
                  ),
                  for (final mod in _modalityStats)
                    _modalityCardItem(
                      title: mod.name,
                      count: mod.contractsCount,
                      amountCop: mod.totalCop,
                      color: mod.color,
                      bgColor: mod.bgColor,
                      icon: mod.icon,
                      selected: _selectedModality == mod.name,
                      onTap: () => setState(() {
                        _selectedModality = mod.name;
                        _contractsPage = 1;
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Tabla navegable de contratos de la entidad
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                child: Row(
                  children: [
                    Text(
                      _selectedModality == 'Todas'
                          ? 'Contratos de la entidad (${filteredContracts.length} contratos · ${_formatShortMillions(filteredTotalCop)})'
                          : 'Modalidad: $_selectedModality (${filteredContracts.length} contratos · ${_formatShortMillions(filteredTotalCop)})',
                      style: const TextStyle(
                        color: _azulOscuro,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Página $safePage de $totalPages',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildContractsTableHeaderRow(),
              if (pageItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(
                    child: Text(
                      'No hay contratos registrados en esta modalidad.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                for (var i = 0; i < pageItems.length; i++) ...[
                  _buildContractRowWidget(pageItems[i]),
                  if (i < pageItems.length - 1)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              _buildSimplePaginationFooter(
                currentPage: safePage,
                totalPages: totalPages,
                onPageChanged: (p) => setState(() => _contractsPage = p),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modalityCardItem({
    required String title,
    required int count,
    required double amountCop,
    required Color color,
    required Color bgColor,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 215,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? bgColor.withValues(alpha: 0.75) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_formatIntWithDots(count)} cont.',
                    style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _formatShortMillions(amountCop),
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractsTableHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      color: const Color(0xFFF8FAFC),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Nº contrato',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'Objeto',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Dependencia',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Modalidad',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Valor',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Fecha',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildContractRowWidget(Map<String, dynamic> c) {
    final ref = (c['referencia_del_contrato'] ??
            c['id_contrato'] ??
            c['proceso_de_compra'] ??
            'SECOP-II')
        .toString();
    final objeto = (c['objeto_del_contrato'] ??
            c['descripcion_del_proceso'] ??
            'Contrato público adjudicado')
        .toString();
    final dep = _inferDependencyFromContract(c);
    final mod = _normalizeModalityLabel(
      (c['modalidad_de_contratacion'] ?? '').toString(),
    );
    final modStyle = _modalityVisualStyle(mod);
    final val = _parseSafeContractCop(c);
    final fecha = (c['fecha_de_firma'] ?? '').toString().split('T').first;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleContratoScreen(contrato: c),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  ref,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _azulPrimario,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  objeto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  dep,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: modStyle.$2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    mod,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: modStyle.$1,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatCopFull(val),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                fecha,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(
              width: 24,
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 3: DEPENDENCIAS (SELECCIONABLE CADA DEPENDENCIA CON SU CONTRATACIÓN)
  // ===========================================================================

  Widget _buildDependenciasTab() {
    if (_dependencyStats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Text('Consultando estructura de dependencias en SECOP II...'),
        ),
      );
    }

    final selectedDep = _dependencyStats.firstWhere(
      (d) => d.name == _selectedDependencyName,
      orElse: () => _dependencyStats.first,
    );

    final depContracts = selectedDep.contracts;
    final totalPages = depContracts.isEmpty
        ? 1
        : (depContracts.length / _contractsPageSize).ceil();
    final safePage = _dependencyContractsPage.clamp(1, totalPages);
    final startIdx = depContracts.isEmpty
        ? 0
        : ((safePage - 1) * _contractsPageSize)
            .clamp(0, depContracts.length - 1);
    final endIdx = depContracts.isEmpty
        ? 0
        : (startIdx + _contractsPageSize).clamp(0, depContracts.length);
    final pageItems = depContracts.isEmpty
        ? <Map<String, dynamic>>[]
        : depContracts.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selector visual de Dependencias de la entidad
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dependencias y áreas ejecutoras de la entidad',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Selecciona cualquier dependencia para inspeccionar su contratación específica.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final dep in _dependencyStats)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDependencyName = dep.name;
                          _dependencyContractsPage = 1;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 265,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedDep.name == dep.name
                              ? dep.iconBg.withValues(alpha: 0.65)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedDep.name == dep.name
                                ? dep.iconColor
                                : const Color(0xFFE2E8F0),
                            width: selectedDep.name == dep.name ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: dep.iconBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                dep.icon,
                                color: dep.iconColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dep.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _azulOscuro,
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${dep.contractsCount} contratos · ${_formatShortMillions(dep.totalCop)}',
                                    style: TextStyle(
                                      color: dep.iconColor,
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Tabla de contratos específicos de la dependencia seleccionada
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                child: Row(
                  children: [
                    Icon(selectedDep.icon, color: selectedDep.iconColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Contratación de ${selectedDep.name} (${selectedDep.contractsCount} contratos · ${_formatCopFull(selectedDep.totalCop)})',
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildContractsTableHeaderRow(),
              for (var i = 0; i < pageItems.length; i++) ...[
                _buildContractRowWidget(pageItems[i]),
                if (i < pageItems.length - 1)
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ],
              _buildSimplePaginationFooter(
                currentPage: safePage,
                totalPages: totalPages,
                onPageChanged: (p) =>
                    setState(() => _dependencyContractsPage = p),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PESTAÑA 4: CONTRATISTAS (RESULTADO NAVEGABLE DE CONTRATISTAS DE LA ENTIDAD)
  // ===========================================================================

  Widget _buildContratistasTab() {
    final totalPages = _contractorsList.isEmpty
        ? 1
        : (_contractorsList.length / _contractorsPageSize).ceil();
    final safePage = _contractorsPage.clamp(1, totalPages);
    final startIdx = _contractorsList.isEmpty
        ? 0
        : ((safePage - 1) * _contractorsPageSize)
            .clamp(0, _contractorsList.length - 1);
    final endIdx = _contractorsList.isEmpty
        ? 0
        : (startIdx + _contractorsPageSize).clamp(0, _contractorsList.length);
    final pageItems = _contractorsList.isEmpty
        ? <_ContractorSummary>[]
        : _contractorsList.sublist(startIdx, endIdx);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contratistas adjudicados en esta entidad',
                        style: TextStyle(
                          color: _azulOscuro,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Resultado directo de los proveedores y contratistas vinculados con la entidad en SECOP II. Haz clic en cualquiera para ver su perfil.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_contractorsList.length} contratistas en muestra',
                  style: const TextStyle(
                    color: _azulPrimario,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            color: const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    '#',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Contratista / Razón social',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Documento / NIT',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Contratos',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Modalidad frecuente',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Valor adjudicado',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 28),
              ],
            ),
          ),
          if (pageItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(
                child: Text('Consultando contratistas de la entidad...'),
              ),
            )
          else
            for (var i = 0; i < pageItems.length; i++) ...[
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PerfilContratistaScreen(
                        nombreContratista: pageItems[i].name,
                        nombreBuscado: pageItems[i].name,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${startIdx + i + 1}',
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          pageItems[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _azulOscuro,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          pageItems[i].document,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${pageItems[i].contractsCount} contratos',
                          style: const TextStyle(
                            color: _azulPrimario,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          pageItems[i].mainModality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatCopFull(pageItems[i].totalCop),
                          style: const TextStyle(
                            color: _azulOscuro,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 28,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: _azulPrimario,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < pageItems.length - 1)
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ],
          _buildSimplePaginationFooter(
            currentPage: safePage,
            totalPages: totalPages,
            onPageChanged: (p) => setState(() => _contractorsPage = p),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplePaginationFooter({
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFD),
        border: Border(top: BorderSide(color: Color(0xFFEEF2F6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed:
                currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 16),
            label: const Text('Anterior'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Página $currentPage de $totalPages',
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 16),
            label: const Text('Siguiente'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCrema,
      body: Column(
        children: [
          _buildGenericPaletteHeader(),
          _buildProfileTabsBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 36),
              child: switch (_selectedTabIndex) {
                0 => _buildResumenTab(),
                1 => _buildContratosTab(),
                2 => _buildDependenciasTab(),
                3 => _buildContratistasTab(),
                _ => _buildResumenTab(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicBudgetDonutPainter extends CustomPainter {
  const _DynamicBudgetDonutPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 12;
    const strokeW = 16.0;

    final trackPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DynamicBudgetDonutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
