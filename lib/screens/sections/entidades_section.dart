import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../data/colombia_entities_database.dart';
import '../../services/auth_service.dart';
import '../../services/secop_i_procesos_service.dart';
import '../../services/security_service.dart';
import '../../utils/anios_secop.dart';
import '../../utils/app_scroll_behavior.dart';
import '../../widgets/user_profile_header_action.dart';
import '../perfil_entidad_screen.dart';
import '../procesos_secop_i_screen.dart';

enum EntityEmblemType {
  alcaldiaCoatOfArms,
  haciendaSeal,
  saludHeartEcg,
  obrasHardHat,
  educacionShield,
  deporteGreenLeaf,
  culturaMasks,
  serviciosWaterDrop,
}

class EntitySummaryRecord {
  const EntitySummaryRecord({
    required this.name,
    required this.nit,
    required this.location,
    required this.municipio,
    required this.departamento,
    required this.category,
    required this.emblemType,
    required this.contractsCount,
    required this.contractsFormatted,
    required this.amountMillions,
    required this.amountFormatted,
    required this.dependenciesCount,
    required this.uniqueContractors,
    required this.secopKeywords,
    this.isDependency = false,
    this.topShieldInRanking = false,
  });

  EntitySummaryRecord conContratistas(int contratistas) => EntitySummaryRecord(
        name: name,
        nit: nit,
        location: location,
        municipio: municipio,
        departamento: departamento,
        category: category,
        emblemType: emblemType,
        contractsCount: contractsCount,
        contractsFormatted: contractsFormatted,
        amountMillions: amountMillions,
        amountFormatted: amountFormatted,
        dependenciesCount: dependenciesCount,
        uniqueContractors: contratistas,
        secopKeywords: secopKeywords,
        isDependency: isDependency,
        topShieldInRanking: topShieldInRanking,
      );

  final String name;
  final String nit;
  final String location;
  final String municipio;
  final String departamento;
  final String category;
  final EntityEmblemType emblemType;
  final int contractsCount;
  final String contractsFormatted;
  final double amountMillions;
  final String amountFormatted;
  final int dependenciesCount;
  final int uniqueContractors;
  final List<String> secopKeywords;
  final bool isDependency;
  final bool topShieldInRanking;
}

class _CachedEntitiesBundle {
  const _CachedEntitiesBundle({
    required this.entities,
    required this.totalEntities,
    required this.totalContracts,
    required this.totalAmountMillions,
    required this.totalUniqueContractors,
    required this.periodo,
    required this.timestamp,
  });

  final List<EntitySummaryRecord> entities;
  final int totalEntities;
  final int totalContracts;
  final double totalAmountMillions;
  final int totalUniqueContractors;
  final String periodo;
  final DateTime timestamp;
}

class EntidadesSection extends StatelessWidget {
  const EntidadesSection({super.key});

  static const Color _azulOscuro = Color(0xFF1A2B4C);

  @override
  Widget build(BuildContext context) {
    return const _EntidadesSectionStateful();
  }
}

class _EntidadesSectionStateful extends StatefulWidget {
  const _EntidadesSectionStateful();

  @override
  State<_EntidadesSectionStateful> createState() =>
      _EntidadesSectionStatefulState();
}

class _EntidadesSectionStatefulState extends State<_EntidadesSectionStateful> {
  static const Color _azulOscuro = EntidadesSection._azulOscuro;
  static const Color _azulPrimario = Color(0xFF1D4ED8);
  static const Color _bgCrema = Color(0xFFFAF5EA);

  // Caché estática en memoria de consultas reales a SECOP II
  static final Map<String, _CachedEntitiesBundle> _queryCache = {};
  static final Map<String, Future<_CachedEntitiesBundle?>> _inFlightQueries =
      {};

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  String _selectedTab = 'Todas';
  String _sortBy = 'Más relevantes';

  // Todas las cifras salen de consultas agregadas a SECOP II. El catálogo
  // `ColombiaEntitiesDatabase` solo se usa como índice de nombres, siglas y
  // NIT para la búsqueda: sus cifras no corresponden a SECOP y no se muestran.
  bool _isLoadingLive = true;
  List<EntitySummaryRecord> _activeEntities = const [];
  List<EntitySummaryRecord> _topContractingEntities = const [];

  int _kpiTotalEntities = 0;
  int _kpiTotalContracts = 0;
  double _kpiTotalAmountMillions = 0;
  int _kpiUniqueContractors = 0;

  /// Entidades sin contratos en SECOP II que sí publicaron procesos en
  /// SECOP I (régimen especial). Solo se consultan si SECOP II no tiene nada.
  List<EntidadSecopI> _entidadesSecopI = const [];

  /// Periodo de las cifras mostradas (vigencia actual o histórico).
  String _kpiPeriodo = 'Vigencia ${AniosSecop.actual}';

  @override
  void initState() {
    super.initState();
    _fetchLiveTopEntitiesAcrossColombia();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isEmptySearch => _searchController.text.trim().isEmpty;

  void _recalculateKpisFromList(
    List<EntitySummaryRecord> list, {
    int? contratistasUnicos,
  }) {
    _kpiTotalEntities = list.length;
    _kpiTotalContracts = list.fold<int>(0, (s, e) => s + e.contractsCount);
    _kpiTotalAmountMillions = list.fold<double>(
      0,
      (s, e) => s + e.amountMillions,
    );
    _kpiUniqueContractors = contratistasUnicos ??
        list.fold<int>(0, (s, e) => s + e.uniqueContractors);
  }

  static String _normalizar(String texto) {
    return texto
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('À', 'A')
        .replaceAll('È', 'E')
        .replaceAll('Ì', 'I')
        .replaceAll('Ò', 'O')
        .replaceAll('Ù', 'U');
  }

  static String _formatIntWithDots(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  static String _formatMillions(double millions) {
    if (millions >= 1) {
      final rounded = millions.round();
      return '\$ ${_formatIntWithDots(rounded)} M';
    }
    final cop = (millions * 1000000).round();
    return '\$ ${_formatIntWithDots(cop)}';
  }

  /// Verifica si un nombre crudo de SECOP II corresponde a una Secretaría o dependencia interna
  /// para NO tratarla nunca como una entidad independiente con perfil propio.
  static bool _isSecretariaOrDependency(String rawName) {
    final norm = _normalizar(rawName).trim();
    if (norm.startsWith('SENA ') || norm == 'SENA') {
      return false; // Se consolida en Servicio Nacional de Aprendizaje - SENA
    }
    if (norm.contains('ALCALDIA MAYOR DE BOGOTA') ||
        norm.contains('ALCALDÍA MAYOR DE BOGOTÁ') ||
        norm.contains('DISTRITO CAPITAL DE BOGOTA') ||
        norm.contains('ALCALDIA DE BOGOTA') ||
        norm.contains('SECRETARIA GENERAL DE LA ALCALDIA MAYOR DE BOGOTA') ||
        norm.contains('ALCALDÍA DE BOGOTÁ')) {
      return false; // Es la Alcaldía Mayor de Bogotá D.C.
    }
    if (norm.contains('MINISTERIO DEL TRABAJO') ||
        norm.contains('MINISTERIO DE TRABAJO') ||
        norm.contains('MINTRABAJO')) {
      return false; // Ministerio del Trabajo y territoriales
    }
    if (norm.contains('UNIVERSIDAD INDUSTRIAL DE SANTANDER') ||
        norm.contains('UIS')) {
      return false; // Universidad Industrial de Santander
    }
    if (norm.contains('UNIVERSIDAD') ||
        norm.contains('INSTITUCION UNIVERSITARIA')) {
      return false; // Universidades públicas colombianas
    }
    if (norm.contains('SECRETARIA') ||
        norm.contains('SUBSECRETARIA') ||
        norm.startsWith('(SECRETARIA') ||
        norm.contains('GRUPO DE APOYO')) {
      return true;
    }
    return false;
  }

  static EntityEmblemType _classifyEmblem(String rawName) {
    final norm = _normalizar(rawName);
    if (norm.contains('ALCALDIA') ||
        norm.contains('MUNICIPIO') ||
        norm.contains('DISTRITO') ||
        norm.contains('GOBERNACION') ||
        norm.contains('DEPARTAMENTO')) {
      return EntityEmblemType.alcaldiaCoatOfArms;
    }
    if (norm.contains('SALUD') ||
        norm.contains('HOSPITAL') ||
        norm.contains('E.S.E') ||
        norm.contains('ESE ') ||
        norm.contains('CLINIC') ||
        norm.contains('SUBRED') ||
        norm.contains('INVIMA')) {
      return EntityEmblemType.saludHeartEcg;
    }
    if (norm.contains('OBRAS') ||
        norm.contains('INFRAESTRUCTURA') ||
        norm.contains('INVIAS') ||
        norm.contains('VIVIENDA') ||
        norm.contains('FONVISOCIAL') ||
        norm.contains('IDU') ||
        norm.contains('ANI') ||
        norm.contains('TRANSPORTE')) {
      return EntityEmblemType.obrasHardHat;
    }
    if (norm.contains('EDUCACION') ||
        norm.contains('UNIVERSIDAD') ||
        norm.contains('INSTITUCION UNIVERSITARIA') ||
        norm.contains('SENA') ||
        norm.contains('COLEGIO') ||
        norm.contains('ICBF') ||
        norm.contains('APRENDIZAJE')) {
      return EntityEmblemType.educacionShield;
    }
    if (norm.contains('DEPORTE') ||
        norm.contains('RECREACION') ||
        norm.contains('INDUPAL') ||
        norm.contains('AMBIENT') ||
        norm.contains('CORPO') ||
        norm.contains('TIERRAS') ||
        norm.contains('CAR ') ||
        norm.contains('CVC')) {
      return EntityEmblemType.deporteGreenLeaf;
    }
    if (norm.contains('CULTURA') ||
        norm.contains('TURISMO') ||
        norm.contains('ARTES')) {
      return EntityEmblemType.culturaMasks;
    }
    if (norm.contains('SERVICIOS PUBLICOS') ||
        norm.contains('EMDUPAR') ||
        norm.contains('ACUEDUCTO') ||
        norm.contains('AGUAS') ||
        norm.contains('EMCALI')) {
      return EntityEmblemType.serviciosWaterDrop;
    }
    return EntityEmblemType.haciendaSeal;
  }

  static String _beautifyEntityName(String raw) {
    final clean = raw
        .replaceAll('*', '')
        .replaceAll('(OFICIAL)', '')
        .replaceAll('- OFICIAL', '')
        .trim();
    if (clean.isEmpty) return 'Entidad Pública';
    final upper = _normalizar(clean);

    if (upper.startsWith('SENA ') ||
        upper == 'SENA' ||
        upper.contains('SERVICIO NACIONAL DE APRENDIZAJE')) {
      return 'Servicio Nacional de Aprendizaje - SENA';
    }
    if (upper.startsWith('ICBF ') ||
        upper == 'ICBF' ||
        upper.contains('BIENESTAR FAMILIAR')) {
      return 'Instituto Colombiano de Bienestar Familiar - ICBF';
    }
    if (upper == 'INVIAS' || upper.contains('INSTITUTO NACIONAL DE VIAS')) {
      return 'Instituto Nacional de Vías - INVIAS';
    }
    if (upper.contains('BOGOTA') &&
        (upper.contains('ALCALDIA') ||
            upper.contains('DISTRITO CAPITAL') ||
            upper.contains('SECRETARIA GENERAL'))) {
      return 'Alcaldía Mayor de Bogotá D.C.';
    }
    if (upper.contains('UNIVERSIDAD INDUSTRIAL DE SANTANDER') ||
        upper == 'UIS') {
      return 'Universidad Industrial de Santander - UIS';
    }
    if (upper.contains('MINISTERIO DEL TRABAJO') ||
        upper.contains('MINTRABAJO') ||
        upper.contains('MINISTERIO DE TRABAJO')) {
      if (upper.contains('ANTIOQUIA')) {
        return 'Ministerio del Trabajo - Dirección Territorial Antioquia';
      }
      if (upper.contains('VALLE')) {
        return 'Ministerio del Trabajo - Dirección Territorial Valle del Cauca';
      }
      if (upper.contains('ATLANTICO')) {
        return 'Ministerio del Trabajo - Dirección Territorial Atlántico';
      }
      if (upper.contains('SANTANDER')) {
        return 'Ministerio del Trabajo - Dirección Territorial Santander';
      }
      if (upper.contains('BOLIVAR')) {
        return 'Ministerio del Trabajo - Dirección Territorial Bolívar';
      }
      if (upper.contains('CESAR')) {
        return 'Ministerio del Trabajo - Dirección Territorial Cesar';
      }
      return 'Ministerio del Trabajo';
    }
    if (upper.contains(
          'DISTRITO ESPECIAL INDUSTRIAL Y PORTUARIO DE BARRANQUILLA',
        ) ||
        upper.contains('ALCALDIA DISTRITAL DE BARRANQUILLA')) {
      return 'Alcaldía Distrital de Barranquilla';
    }
    if (upper.contains('DISTRITO TURISTICO Y CULTURAL DE CARTAGENA') ||
        upper.contains('ALCALDIA MAYOR DE CARTAGENA')) {
      return 'Alcaldía Distrital de Cartagena de Indias';
    }
    if (upper.contains('ALCALDIA DISTRITAL DE SANTA MARTA') ||
        upper.contains('ALCALDIA DE SANTA MARTA')) {
      return 'Alcaldía Distrital de Santa Marta';
    }
    if (upper == 'ALCALDIA MUNICIPAL DE VALLEDUPAR' ||
        upper == 'MUNICIPIO DE VALLEDUPAR') {
      return 'Alcaldía Municipal de Valledupar';
    }

    const lowercaseWords = {
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
    const acronyms = {
      'S.A.',
      'S.A.S.',
      'E.S.P.',
      'E.S.E.',
      'ESE',
      'SENA',
      'ICBF',
      'INVIAS',
      'ANI',
      'ANT',
      'DIAN',
      'DNP',
      'DANE',
      'UNP',
      'UIS',
      'ITM',
      'CAR',
      'IPS',
      'EPS',
      'IDU',
      'IDRD',
      'DPS',
      'ICA',
      'IGAC',
      'INVIMA',
      'INPEC',
      'USPEC',
      'UNGRD',
      'MINTIC',
      'CVC',
      'CRA',
      'CAM',
      'CVS',
      'CAS',
      'CDMB',
      'CRQ',
      'CDA',
      'D.C.',
    };
    final words = clean.split(RegExp(r'\s+'));
    final formatted = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;
      final wUp = w.toUpperCase();
      if (acronyms.contains(wUp)) {
        formatted.add(wUp);
        continue;
      }
      final wLow = w.toLowerCase();
      if (i > 0 && lowercaseWords.contains(wLow)) {
        formatted.add(wLow);
      } else {
        formatted.add(wLow[0].toUpperCase() + wLow.substring(1));
      }
    }
    return formatted.join(' ');
  }

  /// Actualiza en segundo plano las entidades más contratantes reales de Colombia desde SECOP II (Vigencia 2026)
  // Excluye valores atípicos por errores de digitación en SECOP (contratos
  // individuales de 500 mil millones o más).
  static const String _filtroValorValido =
      'valor_del_contrato > 0 AND valor_del_contrato < 500000000000';
  static const String _selectAgregadoEntidad =
      'nombre_entidad,nit_entidad,ciudad,departamento,orden,'
      'count(*) as contratos,sum(valor_del_contrato) as total_valor';
  static const String _groupAgregadoEntidad =
      'nombre_entidad,nit_entidad,ciudad,departamento,orden';

  static String _filtroPeriodo({required bool soloVigencia}) {
    if (!soloVigencia) {
      return "fecha_de_firma >= '${AniosSecop.primero}-01-01T00:00:00.000'";
    }
    final anio = AniosSecop.actual;
    return "fecha_de_firma >= '$anio-01-01T00:00:00.000' AND "
        "fecha_de_firma < '${anio + 1}-01-01T00:00:00.000'";
  }

  static Future<List<dynamic>> _consultarSecop(
    Map<String, String> params,
  ) async {
    try {
      final resp = await http
          .get(Uri.https('www.datos.gov.co', '/resource/jbjy-vk9h.json', params))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return const [];
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  /// Totales reales por entidad (contratos, valor y contratistas distintos).
  static Future<List<dynamic>> _consultarAgregadoEntidades(
    String condicion, {
    required bool soloVigencia,
    int limite = 20,
  }) {
    return _consultarSecop({
      r'$select': _selectAgregadoEntidad,
      r'$where':
          '$_filtroValorValido AND ${_filtroPeriodo(soloVigencia: soloVigencia)} AND ($condicion)',
      r'$group': _groupAgregadoEntidad,
      r'$order': 'total_valor DESC',
      r'$limit': '$limite',
    });
  }

  /// Contratistas distintos por NIT y en total (sin contar dos veces a quien
  /// contrata con varias entidades). Se consulta aparte porque dentro del
  /// agregado por entidad `count(distinct)` hace la consulta 10 veces más lenta.
  static Future<(Map<String, int>, int?)> _contarContratistas(
    List<EntitySummaryRecord> entidades, {
    required bool soloVigencia,
  }) async {
    final nits = entidades
        .map((e) => e.nit.replaceAll(RegExp(r'[^0-9]'), ''))
        .where((n) => n.length >= 6)
        .toSet()
        .toList();
    if (nits.isEmpty) return (const <String, int>{}, null);
    final where =
        '$_filtroValorValido AND ${_filtroPeriodo(soloVigencia: soloVigencia)} '
        'AND nit_entidad in (${nits.join(',')})';
    final resultados = await Future.wait([
      _consultarSecop({
        r'$select': 'nit_entidad,count(distinct documento_proveedor) as contratistas',
        r'$where': where,
        r'$group': 'nit_entidad',
        r'$limit': '${nits.length}',
      }),
      _consultarSecop({
        r'$select': 'count(distinct documento_proveedor) as contratistas',
        r'$where': where,
      }),
    ]);
    final porNit = <String, int>{
      for (final r in resultados[0].whereType<Map>())
        '${r['nit_entidad']}': int.tryParse('${r['contratistas']}') ?? 0,
    };
    final total = resultados[1].isNotEmpty && resultados[1].first is Map
        ? int.tryParse('${(resultados[1].first as Map)['contratistas']}')
        : null;
    return (porNit, total);
  }

  static List<EntitySummaryRecord> _aplicarContratistas(
    List<EntitySummaryRecord> entidades,
    Map<String, int> porNit,
  ) =>
      [
        for (final e in entidades)
          e.conContratistas(
            porNit[e.nit.replaceAll(RegExp(r'[^0-9]'), '')] ?? e.uniqueContractors,
          ),
      ];

  Future<void> _fetchLiveTopEntitiesAcrossColombia() async {
    final rawList = await _consultarAgregadoEntidades(
      "upper(nombre_entidad) NOT LIKE '%SECRETAR%'",
      soloVigencia: true,
    );
    final ranking = _parseAndConsolidateSecopEntities(rawList, '')
      ..sort((a, b) => b.amountMillions.compareTo(a.amountMillions));
    // Solo las entidades visibles muestran contratistas; el panel lateral
    // del ranking usa contratos y valor.
    final (porNit, unicos) = await _contarContratistas(
      ranking.take(10).toList(),
      soloVigencia: true,
    );
    final visibles = _aplicarContratistas(ranking.take(10).toList(), porNit);
    if (!mounted) return;

    setState(() {
      _topContractingEntities = ranking;
      if (_isEmptySearch) {
        _activeEntities = visibles;
        _recalculateKpisFromList(visibles, contratistasUnicos: unicos);
        _kpiPeriodo = 'Vigencia ${AniosSecop.actual}';
        _isLoadingLive = false;
      }
    });
  }

  /// Busca en el catálogo de nombres y siglas para obtener los NIT candidatos.
  List<EntidadCatalogo> _buscarEnCatalogo(String rawQuery) {
    final clean = _normalizar(rawQuery.trim());
    if (clean.isEmpty) return const [];

    const connectors = {
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
      'MUNICIPAL',
      'DISTRITAL',
      'DEPARTAMENTAL',
    };

    final rawTokens = clean
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final sigTokens = rawTokens.where((t) => !connectors.contains(t)).toList();
    final tokens = sigTokens.isNotEmpty ? sigTokens : rawTokens;

    final pool = ColombiaEntitiesDatabase.allEntities;

    return pool.where((entity) {
      final searchable = _normalizar(
        '${entity.name} ${entity.municipio} ${entity.departamento} ${entity.nit} ${entity.category} ${entity.secopKeywords.join(" ")}',
      );
      if (clean.length == 1) {
        return _normalizar(entity.name).startsWith(clean) ||
            entity.secopKeywords.any((k) => _normalizar(k).startsWith(clean)) ||
            _normalizar(entity.municipio).startsWith(clean) ||
            _normalizar(entity.departamento).startsWith(clean);
      }
      return tokens.every((t) => searchable.contains(t));
    }).toList();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      _mostrarRankingNacional();
      return;
    }

    setState(() => _isLoadingLive = true);

    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      _runFastEntitiesQuery();
    });
  }

  void _mostrarRankingNacional() {
    if (_topContractingEntities.isEmpty) {
      setState(() => _isLoadingLive = true);
      _fetchLiveTopEntitiesAcrossColombia();
      return;
    }
    final visibles = _topContractingEntities.take(10).toList();
    setState(() {
      _entidadesSecopI = const [];
      _activeEntities = visibles;
      _recalculateKpisFromList(visibles);
      _kpiPeriodo = 'Vigencia ${AniosSecop.actual}';
      _isLoadingLive = false;
    });
  }

  Future<void> _runFastEntitiesQuery({bool forceRefresh = false}) async {
    final queryText = _searchController.text.trim();

    if (queryText.isEmpty) {
      if (!mounted) return;
      _mostrarRankingNacional();
      return;
    }

    final cacheKey = _normalizar(queryText);

    if (!forceRefresh && _queryCache.containsKey(cacheKey)) {
      final cached = _queryCache[cacheKey]!;
      if (!mounted) return;
      setState(() {
        _entidadesSecopI = const [];
        _activeEntities = cached.entities;
        _kpiTotalEntities = cached.totalEntities;
        _kpiTotalContracts = cached.totalContracts;
        _kpiTotalAmountMillions = cached.totalAmountMillions;
        _kpiUniqueContractors = cached.totalUniqueContractors;
        _kpiPeriodo = cached.periodo;
        _isLoadingLive = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoadingLive = true);

    try {
      Future<_CachedEntitiesBundle?> future;
      if (_inFlightQueries.containsKey(cacheKey)) {
        future = _inFlightQueries[cacheKey]!;
      } else {
        future = _executeUnfilteredSecopEntitySearch(queryText);
        _inFlightQueries[cacheKey] = future;
      }

      final bundle = await future;
      _inFlightQueries.remove(cacheKey);

      if (!mounted) return;
      if (_searchController.text.trim() != queryText) return;

      if (bundle != null && bundle.entities.isNotEmpty) {
        _queryCache[cacheKey] = bundle;
        setState(() {
          _entidadesSecopI = const [];
          _activeEntities = bundle.entities;
          _kpiTotalEntities = bundle.totalEntities;
          _kpiTotalContracts = bundle.totalContracts;
          _kpiTotalAmountMillions = bundle.totalAmountMillions;
          _kpiUniqueContractors = bundle.totalUniqueContractors;
          _kpiPeriodo = bundle.periodo;
          _isLoadingLive = false;
        });
      } else {
        // Sin contratos en SECOP II: puede ser una entidad de régimen
        // especial con procesos publicados en SECOP I.
        final secopI = await SecopIProcesosService.buscarEntidades(
          queryText,
          nitsCatalogo: _buscarEnCatalogo(queryText).map((e) => e.nit).toList(),
        );
        if (!mounted || _searchController.text.trim() != queryText) return;
        setState(() {
          _activeEntities = const [];
          _entidadesSecopI = secopI;
          _recalculateKpisFromList(const []);
          _isLoadingLive = false;
        });
      }
    } catch (_) {
      _inFlightQueries.remove(cacheKey);
      if (mounted) {
        setState(() => _isLoadingLive = false);
      }
    }
  }

  List<EntitySummaryRecord> _parseAndConsolidateSecopEntities(
    List<dynamic> rawList,
    String cleanQuery,
  ) {
    final Map<String, EntitySummaryRecord> consolidated = {};

    // Si el usuario escribe en la búsqueda una regional específica (ej. "sena atlantico", "sena cesar", "icbf guajira"),
    // mostramos también las regionales desglosadas por departamento.
    final bool queryAsksForRegional =
        cleanQuery.contains('REGIONAL') ||
        cleanQuery.contains('SECCIONAL') ||
        cleanQuery.contains('ATLANTICO') ||
        cleanQuery.contains('CESAR') ||
        cleanQuery.contains('GUAJIRA') ||
        cleanQuery.contains('BOLIVAR') ||
        cleanQuery.contains('MAGDALENA') ||
        cleanQuery.contains('ANTIOQUIA') ||
        cleanQuery.contains('VALLE') ||
        cleanQuery.contains('SANTANDER') ||
        cleanQuery.contains('CORDOBA') ||
        cleanQuery.contains('SUCRE') ||
        cleanQuery.contains('TOLIMA') ||
        cleanQuery.contains('HUILA') ||
        cleanQuery.contains('META') ||
        cleanQuery.contains('BOYACA') ||
        cleanQuery.contains('CAUCA') ||
        cleanQuery.contains('NARINO') ||
        cleanQuery.contains('RISARALDA') ||
        cleanQuery.contains('QUINDIO') ||
        cleanQuery.contains('CALDAS');

    for (final item in rawList) {
      if (item is! Map) continue;
      final rawName = (item['nombre_entidad'] ?? '').toString().trim();
      final nitRaw = (item['nit_entidad'] ?? '').toString().trim();

      final entityEffectiveName = rawName;
      final entityEffectiveNit = nitRaw;

      if (entityEffectiveName.isEmpty) continue;

      if (_isSecretariaOrDependency(entityEffectiveName)) {
        continue;
      }

      final cityRaw = (item['ciudad'] ?? '').toString().trim();
      final deptRaw = (item['departamento'] ?? '').toString().trim();
      final ordenRaw = (item['orden'] ?? '').toString().trim();

      final city = (cityRaw.isEmpty || cityRaw == 'No Definido')
          ? 'Colombia'
          : cityRaw;
      final dept = (deptRaw.isEmpty || deptRaw == 'No Definido')
          ? (ordenRaw.isNotEmpty ? ordenRaw : 'Colombia')
          : deptRaw;

      // Soporta tanto respuestas agrupadas ($group) como contratos individuales ($q)
      final int contracts;
      final double rawVal;
      final int contractors;

      if (item.containsKey('contratos')) {
        contracts = int.tryParse(item['contratos'].toString()) ?? 1;
        rawVal = double.tryParse((item['total_valor'] ?? '0').toString()) ?? 0;
        contractors =
            int.tryParse((item['contratistas'] ?? '0').toString()) ?? 0;
      } else {
        contracts = 1;
        rawVal =
            double.tryParse((item['valor_del_contrato'] ?? '0').toString()) ??
            0;
        contractors = 1;
      }

      if (contracts <= 0 || rawVal <= 0) continue;

      final millions = rawVal / 1000000;

      String prettyName = _beautifyEntityName(entityEffectiveName);
      final isMultiRegionalRoot =
          prettyName == 'Servicio Nacional de Aprendizaje - SENA' ||
          prettyName == 'Instituto Colombiano de Bienestar Familiar - ICBF' ||
          prettyName == 'Instituto Nacional de Vías - INVIAS' ||
          prettyName == 'Ministerio del Trabajo';

      if (isMultiRegionalRoot &&
          queryAsksForRegional &&
          dept != 'Colombia' &&
          dept.isNotEmpty) {
        if (prettyName == 'Ministerio del Trabajo') {
          prettyName = 'Ministerio del Trabajo (Dirección Territorial $dept)';
        } else {
          final shortRoot = prettyName.contains('SENA')
              ? 'Servicio Nacional de Aprendizaje - SENA'
              : (prettyName.contains('ICBF')
                    ? 'Instituto Colombiano de Bienestar Familiar - ICBF'
                    : 'Instituto Nacional de Vías - INVIAS');
          prettyName = '$shortRoot (Regional $dept)';
        }
      }

      final normPretty = _normalizar(prettyName);
      final existing = consolidated[normPretty];

      if (existing == null) {
        final isConsolidationRoot =
            isMultiRegionalRoot && !queryAsksForRegional;
        final emblem = _classifyEmblem(entityEffectiveName);

        consolidated[normPretty] = EntitySummaryRecord(
          name: prettyName,
          nit:
              entityEffectiveNit.isNotEmpty && entityEffectiveNit != 'No Definido'
              ? (entityEffectiveNit == '8999990341'
                    ? '899999034'
                    : entityEffectiveNit)
              : 'Verificado SECOP II',
          location: isConsolidationRoot
              ? 'Colombia · Orden Nacional (Regionales)'
              : (city != 'Colombia' && dept != 'Colombia'
                    ? '$city, $dept · ${ordenRaw.isNotEmpty ? ordenRaw : "Territorial"}'
                    : '$dept · ${ordenRaw.isNotEmpty ? ordenRaw : "Nacional"}'),
          municipio: isConsolidationRoot ? 'Bogotá' : city,
          departamento: isConsolidationRoot
              ? 'Distrito Capital de Bogotá'
              : dept,
          category: ordenRaw.isNotEmpty ? 'Orden $ordenRaw' : 'Entidad Pública',
          emblemType: emblem,
          contractsCount: contracts,
          contractsFormatted: _formatIntWithDots(contracts),
          amountMillions: millions,
          amountFormatted: _formatMillions(millions),
          // SECOP II no publica dependencias de la entidad.
          dependenciesCount: 0,
          uniqueContractors: contractors,
          secopKeywords: isMultiRegionalRoot
              ? [
                  prettyName.contains('SENA') ? 'SENA' : 'ICBF',
                  entityEffectiveName,
                ]
              : [entityEffectiveName],
        );
      } else {
        final mergedContracts = existing.contractsCount + contracts;
        final mergedMillions = existing.amountMillions + millions;
        final mergedContractors = existing.uniqueContractors + contractors;
        consolidated[normPretty] = EntitySummaryRecord(
          name: existing.name,
          nit: existing.nit,
          location: existing.location,
          municipio: existing.municipio,
          departamento: existing.departamento,
          category: existing.category,
          emblemType: existing.emblemType,
          contractsCount: mergedContracts,
          contractsFormatted: _formatIntWithDots(mergedContracts),
          amountMillions: mergedMillions,
          amountFormatted: _formatMillions(mergedMillions),
          dependenciesCount: existing.dependenciesCount,
          uniqueContractors: mergedContractors,
          secopKeywords: existing.secopKeywords,
        );
      }
    }

    return consolidated.values.toList();
  }

  /// Consulta rápida y sin bloqueos a SECOP II integrando base de datos oficial y API en vivo.
  Future<_CachedEntitiesBundle?> _executeUnfilteredSecopEntitySearch(
    String queryText,
  ) async {
    final clean = _normalizar(queryText.trim());
    if (clean.isEmpty) return null;

    const conectores = {
      'DE', 'DEL', 'LA', 'LAS', 'EL', 'LOS', 'EN', 'Y', 'PARA', 'POR',
    };
    final tokens = SecurityService.sanitizeSoqlToken(clean, maxLength: 100)
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^A-Z0-9Ñ]'), ''))
        .where((t) => t.length >= 2 && !conectores.contains(t))
        .take(5)
        .toList();

    // Siglas y nombres conocidos ("SENA", "UIS", "ICBF") se traducen al NIT
    // con el catálogo; el texto se busca en el nombre registrado en SECOP.
    final nitsCatalogo = _buscarEnCatalogo(queryText)
        .map((e) => e.nit.replaceAll(RegExp(r'[^0-9]'), ''))
        .where((n) => n.length >= 8)
        .toSet()
        .take(5)
        .toList();

    final condiciones = <String>[
      if (tokens.isNotEmpty)
        '(${tokens.map((t) => "upper(nombre_entidad) LIKE '%$t%'").join(' AND ')})',
      if (nitsCatalogo.isNotEmpty) 'nit_entidad in (${nitsCatalogo.join(',')})',
    ];
    if (condiciones.isEmpty) return null;
    final condicion = condiciones.join(' OR ');

    // Límite amplio: entidades como el SENA tienen decenas de regionales y
    // grupos que se consolidan en una sola tarjeta.
    var soloVigencia = true;
    var rawList = await _consultarAgregadoEntidades(
      condicion,
      soloVigencia: true,
      limite: 500,
    );
    if (rawList.isEmpty) {
      // Sin contratos en la vigencia actual: se consulta el histórico.
      soloVigencia = false;
      rawList = await _consultarAgregadoEntidades(
        condicion,
        soloVigencia: false,
        limite: 500,
      );
    }

    final consolidado = _parseAndConsolidateSecopEntities(rawList, clean);
    if (consolidado.isEmpty) return null;
    final (porNit, unicos) = await _contarContratistas(
      consolidado.take(60).toList(),
      soloVigencia: soloVigencia,
    );
    final finalEntities = _aplicarContratistas(consolidado, porNit)
      ..sort((a, b) => b.amountMillions.compareTo(a.amountMillions));

    return _CachedEntitiesBundle(
      entities: finalEntities,
      totalEntities: finalEntities.length,
      totalContracts:
          finalEntities.fold<int>(0, (acc, e) => acc + e.contractsCount),
      totalAmountMillions:
          finalEntities.fold<double>(0, (acc, e) => acc + e.amountMillions),
      totalUniqueContractors: unicos ??
          finalEntities.fold<int>(0, (acc, e) => acc + e.uniqueContractors),
      periodo: soloVigencia
          ? 'Vigencia ${AniosSecop.actual}'
          : 'Histórico desde ${AniosSecop.primero}',
      timestamp: DateTime.now(),
    );
  }

  List<EntitySummaryRecord> get _filteredAndSortedEntities {
    final list = List<EntitySummaryRecord>.from(_activeEntities);

    switch (_sortBy) {
      case 'Mayor valor':
        list.sort((a, b) => b.amountMillions.compareTo(a.amountMillions));
        break;
      case 'Más contratos':
        list.sort((a, b) => b.contractsCount.compareTo(a.contractsCount));
        break;
      case 'Nombre A-Z':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Más relevantes':
      default:
        break;
    }
    return list;
  }

  /// Entidades más contratantes reales de cualquier orden en Colombia.
  /// Se mantiene fija con el ranking nacional incluso cuando el usuario realiza una búsqueda en la barra.
  List<EntitySummaryRecord> get _top5Entities {
    final sorted = List<EntitySummaryRecord>.from(_topContractingEntities)
      ..sort((a, b) => b.amountMillions.compareTo(a.amountMillions));
    return sorted.take(5).toList();
  }

  // ===========================================================================
  // NAVEGACIÓN AL PERFIL DE CADA ENTIDAD Y COMPARADOR SIN FILTROS
  // ===========================================================================

  void _openEntityProfile(EntitySummaryRecord entity) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PerfilEntidadScreen(entity: entity)),
    );
  }

  void _showCompareEntitiesModal() {
    final pool = _topContractingEntities.isNotEmpty
        ? _topContractingEntities
        : _activeEntities;
    if (pool.isEmpty && _activeEntities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Espera a que carguen las entidades para compararlas.'),
        ),
      );
      return;
    }
    final initialA = _activeEntities.isNotEmpty
        ? _activeEntities.first
        : pool.first;
    final initialB = _activeEntities.length > 1
        ? _activeEntities[1]
        : pool.firstWhere(
            (e) => e.name != initialA.name,
            orElse: () => pool.first,
          );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _CompareEntitiesUnfilteredDialog(
          initialEntityA: initialA,
          initialEntityB: initialB,
          searchSeedEntities: (_) => const <EntitySummaryRecord>[],
          fetchLiveSearchBundle: _executeUnfilteredSecopEntitySearch,
          ensureCatalogReady: () async {},
          getCatalog: () => _topContractingEntities,
          onOpenProfile: (selectedEntity) {
            Navigator.pop(dialogContext);
            _openEntityProfile(selectedEntity);
          },
        );
      },
    );
  }

  // ===========================================================================
  // WIDGETS DE INTERFAZ DE LA SECCIÓN ENTIDADES
  // ===========================================================================

  Future<void> _handleLogout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/portada', (route) => false);
  }

  Widget _buildTopRightProfileBar() {
    return UserProfileHeaderAction(onLogout: _handleLogout);
  }

  Widget _buildHeaderLeftWithCallout() {
    final bool isMobile = MediaQuery.sizeOf(context).width < 750;
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entidades',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Explora las entidades que contratan con el Estado y descubre cómo se distribuyen los recursos públicos.',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 122,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Entidades',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 37,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Explora las entidades que contratan con el Estado y descubre\ncómo se distribuyen los recursos públicos.',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 13.8,
                      fontWeight: FontWeight.w500,
                      height: 1.36,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 45,
            top: 12,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.11,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Conoce quién contrata,\nqué contrata y en qué\nse invierte',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        height: 1.24,
                      ),
                    ),
                    const SizedBox(height: 3),
                    CustomPaint(
                      size: const Size(68, 7),
                      painter: _YellowSwooshPainter(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Barra única de consulta general de entidades verificables en SECOP II (sin filtros de ubicación ni año).
  Widget _buildSearchAndFiltersCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
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
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _runFastEntitiesQuery(forceRefresh: true),
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 13.2,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar entidad verificada en SECOP II (ej. SENA, Alcaldía de Santa Marta, INVIAS, ICBF...)',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.8,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  suffixIcon: _isLoadingLive
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _azulPrimario,
                            ),
                          ),
                        )
                      : (_searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Limpiar búsqueda',
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            : null),
                  filled: true,
                  fillColor: const Color(0xFFF4F6F9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(
                      color: Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryRow() {
    Widget kpiCard({
      required Widget iconCircle,
      required String title,
      String? subtitleUnderTitle,
      required String mainValue,
      required String trendPercent,
      required String trendComparison,
      double valueFontSize = 25,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _azulOscuro.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            iconCircle,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  if (subtitleUnderTitle != null)
                    Text(
                      subtitleUnderTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                    ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      mainValue,
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: trendPercent,
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: ' $trendComparison',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget doubleRingIcon({
      required Color outerColor,
      required Color innerColor,
      required Widget child,
    }) {
      return Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: outerColor, shape: BoxShape.circle),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: innerColor, shape: BoxShape.circle),
          child: child,
        ),
      );
    }

    final card1 = kpiCard(
      iconCircle: doubleRingIcon(
        outerColor: const Color(0xFFE0EEFF),
        innerColor: const Color(0xFFC7DFFF),
        child: const Icon(
          Icons.account_balance_rounded,
          color: Color(0xFF1E3A8A),
          size: 20,
        ),
      ),
      title: 'Entidades',
      subtitleUnderTitle: 'mostradas · $_kpiPeriodo',
      mainValue: '$_kpiTotalEntities',
      trendPercent: 'SECOP II',
      trendComparison: 'Datos Abiertos',
    );
    final card2 = kpiCard(
      iconCircle: doubleRingIcon(
        outerColor: const Color(0xFFE0EEFF),
        innerColor: const Color(0xFFC7DFFF),
        child: const Icon(
          Icons.description_outlined,
          color: Color(0xFF1D4ED8),
          size: 20,
        ),
      ),
      title: 'Total de contratos',
      mainValue: _formatIntWithDots(_kpiTotalContracts),
      trendPercent: 'SECOP II',
      trendComparison: 'registrados',
    );
    final card3 = kpiCard(
      iconCircle: doubleRingIcon(
        outerColor: const Color(0xFFDCFCE7),
        innerColor: const Color(0xFFBBF7D0),
        child: Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF15803D),
            shape: BoxShape.circle,
          ),
          child: const Text(
            '\$',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
      title: 'Valor contratado',
      mainValue: _formatMillions(_kpiTotalAmountMillions),
      valueFontSize: 21,
      trendPercent: 'SECOP II',
      trendComparison: 'consolidado',
    );
    final card4 = kpiCard(
      iconCircle: doubleRingIcon(
        outerColor: const Color(0xFFEDE9FE),
        innerColor: const Color(0xFFDDD6FE),
        child: const Icon(
          Icons.people_outline_rounded,
          color: Color(0xFF4338CA),
          size: 20,
        ),
      ),
      title: 'Contratistas únicos',
      mainValue: _formatIntWithDots(_kpiUniqueContractors),
      trendPercent: 'SECOP II',
      trendComparison: 'adjudicados',
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, kpiConstraints) {
          if (kpiConstraints.maxWidth >= 860) {
            return Row(
              children: [
                Expanded(child: card1),
                const SizedBox(width: 10),
                Expanded(child: card2),
                const SizedBox(width: 10),
                Expanded(child: card3),
                const SizedBox(width: 10),
                Expanded(child: card4),
              ],
            );
          }

          return HorizontalWebScroll(
            child: Row(
              children: [
                SizedBox(width: 228, child: card1),
                const SizedBox(width: 10),
                SizedBox(width: 228, child: card2),
                const SizedBox(width: 10),
                SizedBox(width: 228, child: card3),
                const SizedBox(width: 10),
                SizedBox(width: 228, child: card4),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryTab({required IconData icon, required String label}) {
    final bool selected = _selectedTab == label;
    return InkWell(
      onTap: () => setState(() => _selectedTab = label),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(right: 22, top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? _azulOscuro : const Color(0xFF64748B),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? _azulOscuro : const Color(0xFF64748B),
                    fontSize: 12.8,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: selected ? 68 : 0,
              decoration: BoxDecoration(
                color: _azulOscuro,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityRowItem(EntitySummaryRecord entity) {
    Widget metricCell({
      required IconData icon,
      required String value,
      required String subtitle,
      int flex = 2,
    }) {
      return Expanded(
        flex: flex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: const Color(0xFF475569)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _azulOscuro,
                      fontSize: 13.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 21),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool isMobileRow = MediaQuery.sizeOf(context).width < 700;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEntityProfile(entity),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobileRow ? 14 : 20,
            vertical: 14,
          ),
          child: isMobileRow
              ? Row(
                  children: [
                    EntityBrandScope(
                      entityName: entity.name,
                      nit: entity.nit,
                      child: EntityEmblemWidget(
                        type: entity.emblemType,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entity.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${entity.location} · NIT ${entity.nit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${entity.contractsFormatted} cont. · ${entity.amountFormatted}',
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF475569),
                      size: 20,
                    ),
                  ],
                )
              : Row(
                  children: [
                    EntityBrandScope(
                      entityName: entity.name,
                      nit: entity.nit,
                      child: EntityEmblemWidget(
                        type: entity.emblemType,
                        size: 44,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entity.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${entity.location} · NIT ${entity.nit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    metricCell(
                      icon: Icons.account_balance_outlined,
                      value: entity.contractsFormatted,
                      subtitle: 'Contratos',
                      flex: 2,
                    ),
                    const SizedBox(width: 10),
                    metricCell(
                      icon: Icons.monetization_on_outlined,
                      value: entity.amountFormatted,
                      subtitle: 'Valor contratado',
                      flex: 3,
                    ),
                    const SizedBox(width: 10),
                    metricCell(
                      icon: Icons.person_outline_rounded,
                      value: _formatIntWithDots(entity.uniqueContractors),
                      subtitle: 'Contratistas',
                      flex: 2,
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF475569),
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Tarjeta principal de entidades con únicamente la pestaña "Todas" (sin Alcaldías, Secretarías ni Institutos).
  Widget _buildEntitiesMainTableCard() {
    final entities = _filteredAndSortedEntities;

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: HorizontalWebScroll(
                    child: Row(
                      children: [
                        _buildCategoryTab(
                          icon: Icons.account_balance_outlined,
                          label: 'Todas',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Ordenar por:',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            isDense: true,
                            icon: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: Color(0xFF475569),
                              ),
                            ),
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Más relevantes',
                                child: Text('Más relevantes'),
                              ),
                              DropdownMenuItem(
                                value: 'Mayor valor',
                                child: Text('Mayor valor'),
                              ),
                              DropdownMenuItem(
                                value: 'Más contratos',
                                child: Text('Más contratos'),
                              ),
                              DropdownMenuItem(
                                value: 'Nombre A-Z',
                                child: Text('Nombre A-Z'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _sortBy = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingLive)
            const LinearProgressIndicator(
              minHeight: 2,
              color: _azulPrimario,
              backgroundColor: Color(0xFFE2E8F0),
            )
          else
            const Divider(height: 1, color: Color(0xFFEEF2F6)),
          if (entities.isEmpty && !_isLoadingLive && _entidadesSecopI.isNotEmpty)
            _buildEntidadesSecopI()
          else if (entities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
              child: Column(
                children: [
                  const Icon(
                    Icons.account_balance_outlined,
                    size: 40,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isLoadingLive
                        ? 'Consultando entidades verificadas en SECOP II...'
                        : 'No se encontraron entidades en SECOP II ni en SECOP I con ese criterio.',
                    style: const TextStyle(
                      color: _azulOscuro,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!_isLoadingLive && !_isEmptySearch) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Si es una entidad de régimen especial (por ejemplo, una universidad pública), puede publicar su contratación en su propio portal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (!_isLoadingLive)
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Restaurar vista de entidades'),
                    ),
                ],
              ),
            )
          else
            for (var i = 0; i < entities.length; i++) ...[
              _buildEntityRowItem(entities[i]),
              if (i < entities.length - 1)
                const Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFFF1F5F9),
                ),
            ],
        ],
      ),
    );
  }

  Widget _buildEntidadesSecopI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Procesos publicados en SECOP I (régimen especial)',
                style: TextStyle(
                  color: Color(0xFF78350F),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Esta entidad no registra contratos en SECOP II. Estos son procesos que convocó en SECOP I: muestran la cuantía estimada, no el contratista ni el valor del contrato firmado.',
                style: TextStyle(color: Color(0xFF92400E), fontSize: 12.5),
              ),
            ],
          ),
        ),
        for (final e in _entidadesSecopI)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: const Icon(Icons.account_balance_outlined, color: _azulOscuro),
            title: Text(
              e.nombre,
              style: const TextStyle(
                color: _azulOscuro,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              '${_formatIntWithDots(e.procesos)} procesos · '
              '${_formatMillions(e.valorEstimado / 1000000)} estimados · ${e.periodo}'
              '${e.nit.isNotEmpty ? ' · NIT ${e.nit}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProcesosSecopIScreen(entidad: e),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Columna derecha: Entidades más contratantes (de cualquier orden en Colombia) + Comparar entidades
  Widget _buildRightSideColumn() {
    final top5 = _top5Entities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TARJETA 1: Entidades más contratantes (Reales de SECOP II en cualquier orden)
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Entidades más contratantes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _sortBy = 'Mayor valor';
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Ver todas →',
                        style: TextStyle(
                          color: Color(0xFF1E40AF),
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (top5.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _isLoadingLive
                        ? 'Consultando el ranking en SECOP II...'
                        : 'No fue posible cargar el ranking de SECOP II.',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              for (var index = 0; index < top5.length; index++) ...[
                if (index > 0)
                  const Divider(height: 14, color: Color(0xFFF1F5F9)),
                InkWell(
                  onTap: () => _openEntityProfile(top5[index]),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: index == 0
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        EntityBrandScope(
                          entityName: top5[index].name,
                          nit: top5[index].nit,
                          child: EntityEmblemWidget(
                            type: top5[index].emblemType,
                            size: 35,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                top5[index].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _azulOscuro,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    '${top5[index].contractsFormatted} contratos',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Flexible(
                                    child: Text(
                                      top5[index].amountFormatted,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _azulOscuro,
                                        fontSize: 12.2,
                                        fontWeight: FontWeight.w900,
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
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // TARJETA 2: Comparar entidades
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.compare_arrows_rounded,
                      color: _azulOscuro,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Comparar entidades',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'SECOP II',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Busca sin filtros cualquier par de entidades verificadas de SECOP II y compara su valor contratado, contratos y contratistas.',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 11.6,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: _showCompareEntitiesModal,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _azulOscuro,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(
                              Icons.analytics_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Seleccionar entidades →',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const _EntityBarIllustration(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: _bgCrema,
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 195,
                child: Row(
                  children: [
                    const Expanded(flex: 3, child: SizedBox()),
                    Expanded(
                      flex: 7,
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.25, 0.78, 0.99],
                        ).createShader(bounds),
                        child: Image.asset(
                          'assets/images/fondo_valledupar.jpg',
                          fit: BoxFit.cover,
                          alignment: const Alignment(0.2, -0.28),
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, _, _) => const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 130,
                left: 0,
                right: 0,
                height: 68,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_bgCrema.withValues(alpha: 0.0), _bgCrema],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width < 900 ? 14 : 26,
                  16,
                  MediaQuery.sizeOf(context).width < 900 ? 14 : 26,
                  28,
                ),
                child: MediaQuery.sizeOf(context).width < 900
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (MediaQuery.sizeOf(context).width >= 768) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildTopRightProfileBar(),
                            ),
                            const SizedBox(height: 6),
                          ],
                          _buildHeaderLeftWithCallout(),
                          const SizedBox(height: 10),
                          _buildSearchAndFiltersCard(),
                          const SizedBox(height: 12),
                          _buildKpiSummaryRow(),
                          const SizedBox(height: 14),
                          _buildEntitiesMainTableCard(),
                          const SizedBox(height: 18),
                          _buildRightSideColumn(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 69,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeaderLeftWithCallout(),
                                const SizedBox(height: 10),
                                _buildSearchAndFiltersCard(),
                                const SizedBox(height: 14),
                                _buildKpiSummaryRow(),
                                const SizedBox(height: 14),
                                _buildEntitiesMainTableCard(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 31,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _buildTopRightProfileBar(),
                                ),
                                const SizedBox(height: 36),
                                _buildRightSideColumn(),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EMBLEMAS Y ESCUDOS INSTITUCIONALES EN HD (DISEÑO FIEL A CADA ENTIDAD)
// =============================================================================

class EntityBrandScope extends InheritedWidget {
  const EntityBrandScope({
    super.key,
    required this.entityName,
    this.nit = '',
    required super.child,
  });

  final String entityName;
  final String nit;

  static EntityBrandScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<EntityBrandScope>();
  }

  @override
  bool updateShouldNotify(covariant EntityBrandScope oldWidget) =>
      oldWidget.entityName != entityName || oldWidget.nit != nit;
}

class EntityEmblemWidget extends StatelessWidget {
  const EntityEmblemWidget({super.key, required this.type, this.size = 42});

  final EntityEmblemType type;
  final double size;

  static String _norm(String s) {
    return s
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U');
  }

  @override
  Widget build(BuildContext context) {
    final scope = EntityBrandScope.maybeOf(context);
    final normName = _norm(scope?.entityName ?? '');
    final nitClean = (scope?.nit ?? '').replaceAll(RegExp(r'[^0-9]'), '');

    if (normName.contains('SENA') ||
        normName.contains('APRENDIZAJE') ||
        nitClean.startsWith('899999034')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SenaOfficialHdPainter()),
      );
    }

    if (normName.contains('ICBF') ||
        normName.contains('BIENESTAR FAMILIAR') ||
        nitClean.startsWith('899999239')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _IcbfOfficialHdPainter()),
      );
    }

    if (normName.contains('INVIAS') ||
        normName.contains('NACIONAL DE VIAS') ||
        nitClean.startsWith('800215807')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _InviasOfficialHdPainter()),
      );
    }

    if (normName.contains('AGENCIA NACIONAL DE TIERRAS') ||
        normName.endsWith(' - ANT') ||
        nitClean.startsWith('900948953')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _AntOfficialHdPainter()),
      );
    }

    if (normName.contains('BARRANQUILLA') || nitClean.startsWith('890102018')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BarranquillaCoatOfArmsHdPainter()),
      );
    }

    if (normName.contains('CARTAGENA') || nitClean.startsWith('890480184')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _CartagenaCoatOfArmsHdPainter()),
      );
    }

    if (normName.contains('SANTA MARTA') || nitClean.startsWith('891780009')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SantaMartaCoatOfArmsHdPainter()),
      );
    }

    if (normName.contains('VALLEDUPAR') || nitClean.startsWith('800098911')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _ValleduparCoatOfArmsHdPainter()),
      );
    }

    if (normName.contains('MINISTERIO') ||
        normName.contains('NACIONAL') ||
        normName.contains('POLICIA') ||
        normName.contains('FISCALIA') ||
        normName.contains('CONTRALORIA') ||
        normName.contains('PROCURADURIA') ||
        normName.contains('DIAN') ||
        normName.contains('DNP') ||
        normName.contains('DANE') ||
        normName.contains('UNGRD')) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ColombiaNationalEntityHdPainter(label: normName),
        ),
      );
    }

    switch (type) {
      case EntityEmblemType.alcaldiaCoatOfArms:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _CoatOfArmsPainter()),
        );
      case EntityEmblemType.haciendaSeal:
        return Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.08),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1A2B4C), width: 2.2),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A2B4C),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF93C5FD), width: 1.4),
            ),
            child: Icon(
              Icons.account_balance_rounded,
              color: const Color(0xFFFDE68A),
              size: size * 0.42,
            ),
          ),
        );
      case EntityEmblemType.saludHeartEcg:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF1A2B4C),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.monitor_heart_rounded,
              color: Colors.white,
              size: size * 0.56,
            ),
          ),
        );
      case EntityEmblemType.obrasHardHat:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _InviasOfficialHdPainter()),
        );
      case EntityEmblemType.educacionShield:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _NavyGoldShieldPainter()),
        );
      case EntityEmblemType.deporteGreenLeaf:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _AntOfficialHdPainter()),
        );
      case EntityEmblemType.culturaMasks:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFFE0F2FE),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.theater_comedy_rounded,
              color: const Color(0xFF1A2B4C),
              size: size * 0.58,
            ),
          ),
        );
      case EntityEmblemType.serviciosWaterDrop:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFFE0F2FE),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.water_drop_rounded,
              color: const Color(0xFF0284C7),
              size: size * 0.56,
            ),
          ),
        );
    }
  }
}

/// Logo institucional HD del SENA (triada geométrica naranja/verde oficial + tipografía SENA)
class _SenaOfficialHdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    canvas.drawCircle(center, w / 2, Paint()..color = const Color(0xFFFFFBF5));
    canvas.drawCircle(
      center,
      (w / 2) - 1.2,
      Paint()
        ..color = const Color(0xFFEA580C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045,
    );

    const senaOrange = Color(0xFFFF671F);
    const senaGreen = Color(0xFF00843D);

    // Punto superior (cabeza del isotipo SENA)
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.21),
      w * 0.075,
      Paint()..color = senaOrange,
    );

    // Tres brazos geométricos del isotipo SENA con apertura central
    final leftWing = Path()
      ..moveTo(w * 0.46, h * 0.30)
      ..lineTo(w * 0.20, h * 0.30)
      ..lineTo(w * 0.33, h * 0.43)
      ..lineTo(w * 0.24, h * 0.64)
      ..lineTo(w * 0.46, h * 0.47)
      ..close();
    canvas.drawPath(leftWing, Paint()..color = senaOrange);

    final rightWing = Path()
      ..moveTo(w * 0.54, h * 0.30)
      ..lineTo(w * 0.80, h * 0.30)
      ..lineTo(w * 0.67, h * 0.43)
      ..lineTo(w * 0.76, h * 0.64)
      ..lineTo(w * 0.54, h * 0.47)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = senaOrange);

    final bottomTriangle = Path()
      ..moveTo(w * 0.50, h * 0.51)
      ..lineTo(w * 0.31, h * 0.67)
      ..lineTo(w * 0.69, h * 0.67)
      ..close();
    canvas.drawPath(bottomTriangle, Paint()..color = senaGreen);

    // Sigla SENA en la base
    final tp = TextPainter(
      text: TextSpan(
        text: 'SENA',
        style: TextStyle(
          color: senaGreen,
          fontSize: w * 0.19,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.71));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo institucional HD del ICBF (Bienestar Familiar: arco protector verde y figuras familiares)
class _IcbfOfficialHdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    canvas.drawCircle(center, w / 2, Paint()..color = const Color(0xFFF0FDF4));
    canvas.drawCircle(
      center,
      (w / 2) - 1.2,
      Paint()
        ..color = const Color(0xFF16A34A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045,
    );

    // Techo / arco de hogar verde institucional
    final roof = Path()
      ..moveTo(w * 0.22, h * 0.42)
      ..quadraticBezierTo(w * 0.50, h * 0.14, w * 0.78, h * 0.42);
    canvas.drawPath(
      roof,
      Paint()
        ..color = const Color(0xFF009640)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round,
    );

    // Dos figuras humanas cálidas (rojo/naranja y verde)
    canvas.drawCircle(
      Offset(w * 0.39, h * 0.41),
      w * 0.065,
      Paint()..color = const Color(0xFFE11D48),
    );
    canvas.drawCircle(
      Offset(w * 0.61, h * 0.43),
      w * 0.058,
      Paint()..color = const Color(0xFFF59E0B),
    );

    final bodyLeft = Path()
      ..moveTo(w * 0.28, h * 0.64)
      ..quadraticBezierTo(w * 0.39, h * 0.48, w * 0.50, h * 0.64)
      ..close();
    canvas.drawPath(bodyLeft, Paint()..color = const Color(0xFF009640));

    final bodyRight = Path()
      ..moveTo(w * 0.49, h * 0.64)
      ..quadraticBezierTo(w * 0.61, h * 0.50, w * 0.72, h * 0.64)
      ..close();
    canvas.drawPath(bodyRight, Paint()..color = const Color(0xFFE11D48));

    final tp = TextPainter(
      text: TextSpan(
        text: 'ICBF',
        style: TextStyle(
          color: const Color(0xFF065F46),
          fontSize: w * 0.185,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.70));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo institucional HD del INVÍAS (perspectiva vial naranja/azul oscuro + sigla INVÍAS)
class _InviasOfficialHdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    canvas.drawCircle(center, w / 2, Paint()..color = const Color(0xFFFFF7ED));
    canvas.drawCircle(
      center,
      (w / 2) - 1.2,
      Paint()
        ..color = const Color(0xFFEA580C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045,
    );

    // Sol / horizonte naranja
    canvas.drawArc(
      Rect.fromLTWH(w * 0.24, h * 0.18, w * 0.52, h * 0.42),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFF97316),
    );

    // Vía en perspectiva azul oscuro con línea central blanca/amarilla
    final road = Path()
      ..moveTo(w * 0.44, h * 0.34)
      ..lineTo(w * 0.56, h * 0.34)
      ..lineTo(w * 0.76, h * 0.66)
      ..lineTo(w * 0.24, h * 0.66)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF1A2B4C));

    canvas.drawLine(
      Offset(w * 0.50, h * 0.37),
      Offset(w * 0.50, h * 0.64),
      Paint()
        ..color = const Color(0xFFFACC15)
        ..strokeWidth = w * 0.038
        ..strokeCap = StrokeCap.round,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'INVÍAS',
        style: TextStyle(
          color: const Color(0xFF1A2B4C),
          fontSize: w * 0.16,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.71));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo institucional HD de la Agencia Nacional de Tierras - ANT
class _AntOfficialHdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    canvas.drawCircle(center, w / 2, Paint()..color = const Color(0xFFF0FDF4));
    canvas.drawCircle(
      center,
      (w / 2) - 1.2,
      Paint()
        ..color = const Color(0xFF15803D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045,
    );

    // Sol dorado
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.31),
      w * 0.12,
      Paint()..color = const Color(0xFFFBBF24),
    );

    // Surcos de tierra verdes
    final hillLeft = Path()
      ..moveTo(w * 0.18, h * 0.58)
      ..quadraticBezierTo(w * 0.38, h * 0.38, w * 0.62, h * 0.64)
      ..lineTo(w * 0.18, h * 0.64)
      ..close();
    canvas.drawPath(hillLeft, Paint()..color = const Color(0xFF16A34A));

    final hillRight = Path()
      ..moveTo(w * 0.36, h * 0.64)
      ..quadraticBezierTo(w * 0.62, h * 0.40, w * 0.82, h * 0.64)
      ..close();
    canvas.drawPath(hillRight, Paint()..color = const Color(0xFF15803D));

    final tp = TextPainter(
      text: TextSpan(
        text: 'ANT',
        style: TextStyle(
          color: const Color(0xFF14532D),
          fontSize: w * 0.19,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.70));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Escudo heráldico HD de Barranquilla (bandera cuadrilonga verde, roja y amarilla con estrella de 8 puntas)
class _BarranquillaCoatOfArmsHdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    canvas.drawCircle(center, w / 2, Paint()..color = const Color(0xFFFFFBEB));

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.20, w * 0.68, h * 0.60),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF15803D));

    final midRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.25, h * 0.29, w * 0.50, h * 0.42),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(midRect, Paint()..color = const Color(0xFFDC2626));

    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.37, w * 0.32, h * 0.26),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(innerRect, Paint()..color = const Color(0xFFFACC15));

    // Estrella blanca central
    canvas.drawCircle(center, w * 0.08, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Escudo heráldico HD de Cartagena de Indias
class _CartagenaCoatOfArmsHdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    canvas.drawCircle(center, w / 2, Paint()..color = const Color(0xFFFFFBEB));

    final shield = Path()
      ..moveTo(w * 0.22, h * 0.22)
      ..lineTo(w * 0.78, h * 0.22)
      ..lineTo(w * 0.78, h * 0.54)
      ..quadraticBezierTo(w * 0.78, h * 0.78, w * 0.50, h * 0.88)
      ..quadraticBezierTo(w * 0.22, h * 0.78, w * 0.22, h * 0.54)
      ..close();

    canvas.drawPath(shield, Paint()..color = const Color(0xFFFEF3C7));
    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05,
    );

    // Cruz colonial e insignia verde/roja/amarilla
    canvas.drawLine(
      Offset(w * 0.50, h * 0.30),
      Offset(w * 0.50, h * 0.75),
      Paint()
        ..color = const Color(0xFFB45309)
        ..strokeWidth = w * 0.07
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(w * 0.33, h * 0.45),
      Offset(w * 0.67, h * 0.45),
      Paint()
        ..color = const Color(0xFF15803D)
        ..strokeWidth = w * 0.065
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Escudo heráldico HD de Santa Marta (azul celeste y blanco con torre dorada)
class _SantaMartaCoatOfArmsHdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shield = Path()
      ..moveTo(w * 0.22, h * 0.18)
      ..lineTo(w * 0.78, h * 0.18)
      ..lineTo(w * 0.78, h * 0.54)
      ..quadraticBezierTo(w * 0.78, h * 0.79, w * 0.50, h * 0.89)
      ..quadraticBezierTo(w * 0.22, h * 0.79, w * 0.22, h * 0.54)
      ..close();

    canvas.save();
    canvas.clipPath(shield);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.53),
      Paint()..color = const Color(0xFF0284C7),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.53, w, h * 0.47),
      Paint()..color = Colors.white,
    );
    // Torre dorada central
    canvas.drawRect(
      Rect.fromLTWH(w * 0.41, h * 0.34, w * 0.18, h * 0.34),
      Paint()..color = const Color(0xFFF59E0B),
    );
    canvas.restore();

    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFF0369A1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Escudo heráldico HD de Valledupar (azul, blanco y rojo con corona mural dorada)
class _ValleduparCoatOfArmsHdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shield = Path()
      ..moveTo(w * 0.22, h * 0.22)
      ..lineTo(w * 0.78, h * 0.22)
      ..lineTo(w * 0.78, h * 0.54)
      ..quadraticBezierTo(w * 0.78, h * 0.79, w * 0.50, h * 0.89)
      ..quadraticBezierTo(w * 0.22, h * 0.79, w * 0.22, h * 0.54)
      ..close();

    canvas.save();
    canvas.clipPath(shield);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.44),
      Paint()..color = const Color(0xFF1D4ED8),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.44, w, h * 0.18),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.62, w, h * 0.38),
      Paint()..color = const Color(0xFFDC2626),
    );
    canvas.restore();

    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Escudo institucional HD de Entidades del Orden Nacional (Tricolor República de Colombia)
class _ColombiaNationalEntityHdPainter extends CustomPainter {
  _ColombiaNationalEntityHdPainter({required this.label});

  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    canvas.drawCircle(center, w / 2, Paint()..color = const Color(0xFFF8FAFC));

    final shield = Path()
      ..moveTo(w * 0.22, h * 0.18)
      ..lineTo(w * 0.78, h * 0.18)
      ..lineTo(w * 0.78, h * 0.54)
      ..quadraticBezierTo(w * 0.78, h * 0.79, w * 0.50, h * 0.89)
      ..quadraticBezierTo(w * 0.22, h * 0.79, w * 0.22, h * 0.54)
      ..close();

    canvas.save();
    canvas.clipPath(shield);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.50),
      Paint()..color = const Color(0xFFFACC15),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.50, w, h * 0.20),
      Paint()..color = const Color(0xFF1D4ED8),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.70, w, h * 0.30),
      Paint()..color = const Color(0xFFDC2626),
    );
    canvas.restore();

    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFF1A2B4C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoatOfArmsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgPaint = Paint()..color = const Color(0xFFFFFBEB);
    canvas.drawCircle(Offset(w / 2, h / 2), w / 2, bgPaint);

    final laurelPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.14, h * 0.18, w * 0.72, h * 0.68),
      0.3,
      math.pi - 0.6,
      false,
      laurelPaint,
    );

    final crownPaint = Paint()..color = const Color(0xFFF59E0B);
    final crownPath = Path()
      ..moveTo(w * 0.28, h * 0.26)
      ..lineTo(w * 0.24, h * 0.13)
      ..lineTo(w * 0.38, h * 0.20)
      ..lineTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.62, h * 0.20)
      ..lineTo(w * 0.76, h * 0.13)
      ..lineTo(w * 0.72, h * 0.26)
      ..close();
    canvas.drawPath(crownPath, crownPaint);

    final leftShield = Path()
      ..moveTo(w * 0.50, h * 0.27)
      ..lineTo(w * 0.27, h * 0.27)
      ..lineTo(w * 0.27, h * 0.55)
      ..quadraticBezierTo(w * 0.27, h * 0.76, w * 0.50, h * 0.84)
      ..close();
    canvas.drawPath(leftShield, Paint()..color = const Color(0xFFDC2626));

    final rightShield = Path()
      ..moveTo(w * 0.50, h * 0.27)
      ..lineTo(w * 0.73, h * 0.27)
      ..lineTo(w * 0.73, h * 0.55)
      ..quadraticBezierTo(w * 0.73, h * 0.76, w * 0.50, h * 0.84)
      ..close();
    canvas.drawPath(rightShield, Paint()..color = const Color(0xFFFBBF24));

    final blueBand = Path()
      ..moveTo(w * 0.50, h * 0.52)
      ..lineTo(w * 0.73, h * 0.52)
      ..lineTo(w * 0.70, h * 0.67)
      ..lineTo(w * 0.50, h * 0.67)
      ..close();
    canvas.drawPath(blueBand, Paint()..color = const Color(0xFF1D4ED8));

    final fullShield = Path()
      ..moveTo(w * 0.27, h * 0.27)
      ..lineTo(w * 0.73, h * 0.27)
      ..lineTo(w * 0.73, h * 0.55)
      ..quadraticBezierTo(w * 0.73, h * 0.76, w * 0.50, h * 0.84)
      ..quadraticBezierTo(w * 0.27, h * 0.76, w * 0.27, h * 0.55)
      ..close();
    canvas.drawPath(
      fullShield,
      Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavyGoldShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shield = Path()
      ..moveTo(w * 0.20, h * 0.14)
      ..lineTo(w * 0.80, h * 0.14)
      ..lineTo(w * 0.80, h * 0.54)
      ..quadraticBezierTo(w * 0.80, h * 0.79, w * 0.50, h * 0.90)
      ..quadraticBezierTo(w * 0.20, h * 0.79, w * 0.20, h * 0.54)
      ..close();

    canvas.drawPath(shield, Paint()..color = const Color(0xFF1A2B4C));
    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    final goldPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.50, h * 0.26),
      Offset(w * 0.50, h * 0.74),
      goldPaint,
    );
    canvas.drawCircle(Offset(w * 0.50, h * 0.44), w * 0.13, goldPaint);
    canvas.drawLine(
      Offset(w * 0.35, h * 0.34),
      Offset(w * 0.65, h * 0.34),
      goldPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _YellowSwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFACC15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(2, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.5,
        0,
        size.width - 2,
        size.height * 0.65,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// ILUSTRACIONES (SE PRESERVAN CLASES CONST PARA HOT RELOAD SEGURO)
// =============================================================================

// ignore: unused_element
class _EntityNetworkIllustration extends StatelessWidget {
  const _EntityNetworkIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(112, 112),
            painter: _NetworkOrbitLinesPainter(),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFFACC15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Color(0xFF1A2B4C),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkOrbitLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbitPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, 37, orbitPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EntityBarIllustration extends StatelessWidget {
  const _EntityBarIllustration();

  @override
  Widget build(BuildContext context) {
    const heights = [24.0, 38.0, 50.0, 62.0];
    const colors = [
      Color(0xFFDBEAFE),
      Color(0xFFBFDBFE),
      Color(0xFFFDE68A),
      Color(0xFFFACC15),
    ];

    return SizedBox(
      width: 96,
      height: 68,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (_) => Container(height: 1, color: const Color(0xFFF1F5F9)),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < heights.length; i++)
                Container(
                  width: 14,
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: colors[i],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL FUNCIONAL DE COMPARAR ENTIDADES (SOLO ENTIDADES VERIFICABLES SECOP II)
// =============================================================================

class _CompareEntitiesUnfilteredDialog extends StatefulWidget {
  const _CompareEntitiesUnfilteredDialog({
    required this.initialEntityA,
    required this.initialEntityB,
    required this.searchSeedEntities,
    required this.fetchLiveSearchBundle,
    required this.onOpenProfile,
    this.ensureCatalogReady,
    this.getCatalog,
  });

  final EntitySummaryRecord initialEntityA;
  final EntitySummaryRecord initialEntityB;
  final List<EntitySummaryRecord> Function(String query) searchSeedEntities;
  final Future<_CachedEntitiesBundle?> Function(String query)
  fetchLiveSearchBundle;
  final void Function(EntitySummaryRecord entity) onOpenProfile;
  // Campos preservados para compatibilidad con Hot Reload en la VM de Dart
  final Future<void> Function()? ensureCatalogReady;
  final List<EntitySummaryRecord>? Function()? getCatalog;

  @override
  State<_CompareEntitiesUnfilteredDialog> createState() =>
      _CompareEntitiesUnfilteredDialogState();
}

class _CompareEntitiesUnfilteredDialogState
    extends State<_CompareEntitiesUnfilteredDialog> {
  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _azulPrimario = Color(0xFF1D4ED8);
  static const Color _ambarComparador = Color(0xFFD97706);

  late EntitySummaryRecord _entityA;
  late EntitySummaryRecord _entityB;

  final TextEditingController _searchCtrlA = TextEditingController();
  final TextEditingController _searchCtrlB = TextEditingController();

  List<EntitySummaryRecord> _suggestionsA = [];
  List<EntitySummaryRecord> _suggestionsB = [];
  bool _loadingLiveA = false;
  bool _loadingLiveB = false;
  Timer? _debounceA;
  Timer? _debounceB;

  @override
  void initState() {
    super.initState();
    _entityA = widget.initialEntityA;
    _entityB = widget.initialEntityB;
  }

  @override
  void dispose() {
    _debounceA?.cancel();
    _debounceB?.cancel();
    _searchCtrlA.dispose();
    _searchCtrlB.dispose();
    super.dispose();
  }

  static String _formatIntWithDots(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  void _onSearchQuerySlotA(String text) {
    _debounceA?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _suggestionsA = [];
        _loadingLiveA = false;
      });
      return;
    }

    final local = widget.searchSeedEntities(trimmed);
    setState(() {
      _suggestionsA = local.take(6).toList();
      _loadingLiveA = true;
    });

    _debounceA = Timer(const Duration(milliseconds: 280), () async {
      final bundle = await widget.fetchLiveSearchBundle(trimmed);
      if (!mounted || _searchCtrlA.text.trim() != trimmed) return;
      setState(() {
        if (bundle != null && bundle.entities.isNotEmpty) {
          _suggestionsA = bundle.entities.take(8).toList();
        }
        _loadingLiveA = false;
      });
    });
  }

  void _onSearchQuerySlotB(String text) {
    _debounceB?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _suggestionsB = [];
        _loadingLiveB = false;
      });
      return;
    }

    final local = widget.searchSeedEntities(trimmed);
    setState(() {
      _suggestionsB = local.take(6).toList();
      _loadingLiveB = true;
    });

    _debounceB = Timer(const Duration(milliseconds: 280), () async {
      final bundle = await widget.fetchLiveSearchBundle(trimmed);
      if (!mounted || _searchCtrlB.text.trim() != trimmed) return;
      setState(() {
        if (bundle != null && bundle.entities.isNotEmpty) {
          _suggestionsB = bundle.entities.take(8).toList();
        }
        _loadingLiveB = false;
      });
    });
  }

  Widget _buildEntitySelectorColumn({
    required String slotLabel,
    required Color accentColor,
    required Color softBgColor,
    required EntitySummaryRecord selectedEntity,
    required TextEditingController controller,
    required List<EntitySummaryRecord> suggestions,
    required bool isLoading,
    required ValueChanged<String> onQueryChanged,
    required ValueChanged<EntitySummaryRecord> onSelectEntity,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                slotLabel,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                EntityBrandScope(
                  entityName: selectedEntity.name,
                  nit: selectedEntity.nit,
                  child: EntityEmblemWidget(
                    type: selectedEntity.emblemType,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedEntity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 12.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${selectedEntity.location} · NIT ${selectedEntity.nit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 36,
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 12.2,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar otra entidad en SECOP II (ej. SENA, Santa Marta...)',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11.5,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 17),
                suffixIcon: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (controller.text.isNotEmpty
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                controller.clear();
                                onQueryChanged('');
                              },
                              icon: const Icon(Icons.close, size: 15),
                            )
                          : null),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, idx) {
                  final item = suggestions[idx];
                  return InkWell(
                    onTap: () {
                      controller.clear();
                      onSelectEntity(item);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          EntityBrandScope(
                            entityName: item.name,
                            nit: item.nit,
                            child: EntityEmblemWidget(
                              type: item.emblemType,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _azulOscuro,
                                    fontSize: 11.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${item.location} · ${item.amountFormatted}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonMetricCard({
    required String title,
    required IconData icon,
    required String valueA,
    required String valueB,
    required double ratioA,
    required double ratioB,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _azulOscuro),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 135,
                child: Text(
                  _entityA.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratioA.clamp(0.06, 1.0),
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: _azulPrimario,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: Text(
                  valueA,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _azulPrimario,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 135,
                child: Text(
                  _entityB.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratioB.clamp(0.06, 1.0),
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: Text(
                  valueB,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _ambarComparador,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxAmount = math.max(
      _entityA.amountMillions,
      _entityB.amountMillions,
    );
    final maxContracts = math.max(
      _entityA.contractsCount,
      _entityB.contractsCount,
    );
    final maxContractors = math.max(
      _entityA.uniqueContractors,
      _entityB.uniqueContractors,
    );

    final avgA = _entityA.contractsCount > 0
        ? (_entityA.amountMillions / _entityA.contractsCount)
        : 0.0;
    final avgB = _entityB.contractsCount > 0
        ? (_entityB.amountMillions / _entityB.contractsCount)
        : 0.0;
    final maxAvg = math.max(avgA, avgB);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.compare_arrows_rounded,
                      color: _azulOscuro,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comparador nacional y territorial de entidades (SECOP II)',
                          style: TextStyle(
                            color: _azulOscuro,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Busca cualquier entidad verificada en SECOP II sin filtros y compara sus indicadores reales.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildEntitySelectorColumn(
                              slotLabel: 'ENTIDAD 1',
                              accentColor: _azulPrimario,
                              softBgColor: const Color(0xFFEFF6FF),
                              selectedEntity: _entityA,
                              controller: _searchCtrlA,
                              suggestions: _suggestionsA,
                              isLoading: _loadingLiveA,
                              onQueryChanged: _onSearchQuerySlotA,
                              onSelectEntity: (entity) {
                                setState(() {
                                  _entityA = entity;
                                  _suggestionsA = [];
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildEntitySelectorColumn(
                              slotLabel: 'ENTIDAD 2',
                              accentColor: _ambarComparador,
                              softBgColor: const Color(0xFFFFFBEB),
                              selectedEntity: _entityB,
                              controller: _searchCtrlB,
                              suggestions: _suggestionsB,
                              isLoading: _loadingLiveB,
                              onQueryChanged: _onSearchQuerySlotB,
                              onSelectEntity: (entity) {
                                setState(() {
                                  _entityB = entity;
                                  _suggestionsB = [];
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildComparisonMetricCard(
                        title: 'Valor total contratado en SECOP II',
                        icon: Icons.monetization_on_outlined,
                        valueA: _entityA.amountFormatted,
                        valueB: _entityB.amountFormatted,
                        ratioA: maxAmount > 0
                            ? _entityA.amountMillions / maxAmount
                            : 0.5,
                        ratioB: maxAmount > 0
                            ? _entityB.amountMillions / maxAmount
                            : 0.5,
                      ),
                      _buildComparisonMetricCard(
                        title: 'Total de contratos suscritos',
                        icon: Icons.description_outlined,
                        valueA: '${_entityA.contractsFormatted} cont.',
                        valueB: '${_entityB.contractsFormatted} cont.',
                        ratioA: maxContracts > 0
                            ? _entityA.contractsCount / maxContracts
                            : 0.5,
                        ratioB: maxContracts > 0
                            ? _entityB.contractsCount / maxContracts
                            : 0.5,
                      ),
                      _buildComparisonMetricCard(
                        title: 'Contratistas únicos adjudicados',
                        icon: Icons.people_outline_rounded,
                        valueA:
                            '${_formatIntWithDots(_entityA.uniqueContractors)} prov.',
                        valueB:
                            '${_formatIntWithDots(_entityB.uniqueContractors)} prov.',
                        ratioA: maxContractors > 0
                            ? _entityA.uniqueContractors / maxContractors
                            : 0.5,
                        ratioB: maxContractors > 0
                            ? _entityB.uniqueContractors / maxContractors
                            : 0.5,
                      ),
                      _buildComparisonMetricCard(
                        title: 'Valor promedio por contrato',
                        icon: Icons.calculate_outlined,
                        valueA: '\$ ${avgA.toStringAsFixed(1)} M',
                        valueB: '\$ ${avgB.toStringAsFixed(1)} M',
                        ratioA: maxAvg > 0 ? avgA / maxAvg : 0.5,
                        ratioB: maxAvg > 0 ? avgB / maxAvg : 0.5,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _azulOscuro,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
