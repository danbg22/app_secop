import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../perfil_entidad_screen.dart';

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
    required this.timestamp,
  });

  final List<EntitySummaryRecord> entities;
  final int totalEntities;
  final int totalContracts;
  final double totalAmountMillions;
  final int totalUniqueContractors;
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

  bool _isLoadingLive = false;
  List<EntitySummaryRecord> _activeEntities = _verifiedSecopDefaultEntities;
  List<EntitySummaryRecord> _topContractingEntities =
      _verifiedSecopDefaultEntities;

  int _kpiTotalEntities = 8;
  int _kpiTotalContracts = 102772;
  double _kpiTotalAmountMillions = 16419218;
  int _kpiUniqueContractors = 41890;

  /// Entidades reales y verificadas directamente en SECOP II (datos.gov.co/resource/jbjy-vk9h.json)
  /// con sus cifras anualizadas para la vigencia en curso (2026).
  /// Ninguna Secretaría ni dependencia aparece aquí como entidad independiente.
  static const List<EntitySummaryRecord> _verifiedSecopDefaultEntities = [
    EntitySummaryRecord(
      name: 'Instituto Nacional de Vías - INVIAS',
      nit: '800215807',
      location: 'Colombia · Orden Nacional (26 Territoriales)',
      municipio: 'Bogotá',
      departamento: 'Distrito Capital de Bogotá',
      category: 'Orden Nacional',
      emblemType: EntityEmblemType.obrasHardHat,
      contractsCount: 1529,
      contractsFormatted: '1.529',
      amountMillions: 6053551,
      amountFormatted: '\$ 6.053.551 M',
      dependenciesCount: 26,
      uniqueContractors: 1120,
      secopKeywords: ['INVIAS'],
    ),
    EntitySummaryRecord(
      name: 'Instituto Colombiano de Bienestar Familiar - ICBF',
      nit: '899999239',
      location: 'Colombia · Orden Nacional (33 Regionales)',
      municipio: 'Bogotá',
      departamento: 'Distrito Capital de Bogotá',
      category: 'Orden Nacional',
      emblemType: EntityEmblemType.educacionShield,
      contractsCount: 19817,
      contractsFormatted: '19.817',
      amountMillions: 3335406,
      amountFormatted: '\$ 3.335.406 M',
      dependenciesCount: 33,
      uniqueContractors: 8420,
      secopKeywords: ['ICBF SEDE NACIONAL', 'ICBF'],
    ),
    EntitySummaryRecord(
      name: 'Servicio Nacional de Aprendizaje - SENA',
      nit: '899999034',
      location: 'Colombia · Orden Nacional (33 Regionales)',
      municipio: 'Bogotá',
      departamento: 'Distrito Capital de Bogotá',
      category: 'Orden Nacional',
      emblemType: EntityEmblemType.educacionShield,
      contractsCount: 43251,
      contractsFormatted: '43.251',
      amountMillions: 2610893,
      amountFormatted: '\$ 2.610.893 M',
      dependenciesCount: 33,
      uniqueContractors: 16840,
      secopKeywords: ['SENA'],
    ),
    EntitySummaryRecord(
      name: 'Alcaldía Distrital de Barranquilla',
      nit: '890102018',
      location: 'Barranquilla, Atlántico · Territorial',
      municipio: 'Barranquilla',
      departamento: 'Atlántico',
      category: 'Orden Territorial',
      emblemType: EntityEmblemType.alcaldiaCoatOfArms,
      contractsCount: 11939,
      contractsFormatted: '11.939',
      amountMillions: 2039416,
      amountFormatted: '\$ 2.039.416 M',
      dependenciesCount: 18,
      uniqueContractors: 5412,
      secopKeywords: [
        'DISTRITO ESPECIAL INDUSTRIAL Y PORTUARIO DE BARRANQUILLA',
      ],
    ),
    EntitySummaryRecord(
      name: 'Alcaldía Distrital de Cartagena de Indias',
      nit: '890480184',
      location: 'Cartagena, Bolívar · Territorial',
      municipio: 'Cartagena',
      departamento: 'Bolívar',
      category: 'Orden Territorial',
      emblemType: EntityEmblemType.alcaldiaCoatOfArms,
      contractsCount: 11086,
      contractsFormatted: '11.086',
      amountMillions: 1140009,
      amountFormatted: '\$ 1.140.009 M',
      dependenciesCount: 16,
      uniqueContractors: 4980,
      secopKeywords: [
        'ALCALDÍA DEL DISTRITO TURÍSTICO Y CULTURAL DE CARTAGENA DE INDIAS',
      ],
    ),
    EntitySummaryRecord(
      name: 'Agencia Nacional de Tierras - ANT',
      nit: '900948953',
      location: 'Colombia · Orden Nacional (UGT Regionales)',
      municipio: 'Bogotá',
      departamento: 'Distrito Capital de Bogotá',
      category: 'Orden Nacional',
      emblemType: EntityEmblemType.deporteGreenLeaf,
      contractsCount: 9532,
      contractsFormatted: '9.532',
      amountMillions: 588669,
      amountFormatted: '\$ 588.669 M',
      dependenciesCount: 15,
      uniqueContractors: 4310,
      secopKeywords: ['AGENCIA NACIONAL DE TIERRAS - ANT'],
    ),
    EntitySummaryRecord(
      name: 'Alcaldía Distrital de Santa Marta',
      nit: '891780009',
      location: 'Santa Marta, Magdalena · Territorial',
      municipio: 'Santa Marta',
      departamento: 'Magdalena',
      category: 'Orden Territorial',
      emblemType: EntityEmblemType.alcaldiaCoatOfArms,
      contractsCount: 2438,
      contractsFormatted: '2.438',
      amountMillions: 384308,
      amountFormatted: '\$ 384.308 M',
      dependenciesCount: 14,
      uniqueContractors: 1412,
      secopKeywords: ['ALCALDÍA DISTRITAL DE SANTA MARTA'],
    ),
    EntitySummaryRecord(
      name: 'Alcaldía Municipal de Valledupar',
      nit: '800098911',
      location: 'Valledupar, Cesar · Territorial',
      municipio: 'Valledupar',
      departamento: 'Cesar',
      category: 'Orden Territorial',
      emblemType: EntityEmblemType.alcaldiaCoatOfArms,
      contractsCount: 3180,
      contractsFormatted: '3.180',
      amountMillions: 266973,
      amountFormatted: '\$ 266.973 M',
      dependenciesCount: 12,
      uniqueContractors: 1396,
      secopKeywords: ['ALCALDIA MUNICIPAL DE VALLEDUPAR'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _recalculateKpisFromList(_verifiedSecopDefaultEntities);
    _fetchLiveTopEntitiesAcrossColombia();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isEmptySearch => _searchController.text.trim().isEmpty;

  void _recalculateKpisFromList(List<EntitySummaryRecord> list) {
    _kpiTotalEntities = list.length;
    _kpiTotalContracts = list.fold<int>(0, (s, e) => s + e.contractsCount);
    _kpiTotalAmountMillions =
        list.fold<double>(0, (s, e) => s + e.amountMillions);
    _kpiUniqueContractors =
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
    if (norm.contains('SECRETARIA') ||
        norm.contains('SUBSECRETARIA') ||
        norm.startsWith('(SECRETARIA') ||
        norm.contains('DIRECCION SECCIONAL') ||
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
    if (upper.contains('DISTRITO ESPECIAL INDUSTRIAL Y PORTUARIO DE BARRANQUILLA') ||
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
  Future<void> _fetchLiveTopEntitiesAcrossColombia() async {
    try {
      final url = Uri.parse(
        'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
        '\$select=nombre_entidad,nit_entidad,ciudad,departamento,orden,count(*)%20as%20contratos,sum(valor_del_contrato)%20as%20total_valor,count(distinct%20documento_proveedor)%20as%20contratistas'
        "&\$where=valor_del_contrato%20%3E%200%20AND%20valor_del_contrato%20%3C%20500000000000%20AND%20fecha_de_firma%20%3E=%20'2026-01-01T00:00:00.000'%20AND%20upper(nombre_entidad)%20NOT%20LIKE%20'%25SECRETAR%25'"
        '&\$group=nombre_entidad,nit_entidad,ciudad,departamento,orden'
        '&\$order=total_valor%20DESC'
        '&\$limit=20',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 9));
      if (resp.statusCode != 200 || !mounted) return;

      final rawList = jsonDecode(resp.body) as List<dynamic>;
      final parsed = _parseAndConsolidateSecopEntities(rawList, '');
      if (parsed.isEmpty || !mounted) return;

      // Combinamos las entidades semillas verificadas de SECOP II con el ranking en vivo
      final mergedMap = <String, EntitySummaryRecord>{};
      for (final item in _verifiedSecopDefaultEntities) {
        mergedMap[_normalizar(item.name)] = item;
      }
      for (final live in parsed) {
        mergedMap.putIfAbsent(_normalizar(live.name), () => live);
      }

      final combined = mergedMap.values.toList()
        ..sort((a, b) => b.amountMillions.compareTo(a.amountMillions));

      setState(() {
        _topContractingEntities = combined;
        if (_isEmptySearch) {
          _activeEntities = combined.take(10).toList();
          _recalculateKpisFromList(_activeEntities);
        }
      });
    } catch (_) {
      // Mantiene las entidades verificadas de SECOP II por defecto
    }
  }

  /// Filtra únicamente entre entidades reales verificadas de SECOP II mientras responde la API
  List<EntitySummaryRecord> _filterVerifiedSeedEntities(String rawQuery) {
    final clean = _normalizar(rawQuery.trim());
    if (clean.isEmpty) return _verifiedSecopDefaultEntities;

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

    final rawTokens =
        clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final sigTokens =
        rawTokens.where((t) => !connectors.contains(t)).toList();
    final tokens = sigTokens.isNotEmpty ? sigTokens : rawTokens;

    final pool = _topContractingEntities.isNotEmpty
        ? _topContractingEntities
        : _verifiedSecopDefaultEntities;

    return pool.where((entity) {
      final searchable = _normalizar(
        '${entity.name} ${entity.municipio} ${entity.departamento} ${entity.secopKeywords.join(" ")}',
      );
      if (clean.length == 1) {
        return _normalizar(entity.name).startsWith(clean) ||
            entity.secopKeywords.any((k) => _normalizar(k).startsWith(clean));
      }
      return tokens.every((t) => searchable.contains(t));
    }).toList();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      final defaultList = _topContractingEntities.isNotEmpty
          ? _topContractingEntities.take(10).toList()
          : _verifiedSecopDefaultEntities;
      setState(() {
        _activeEntities = defaultList;
        _recalculateKpisFromList(defaultList);
        _isLoadingLive = false;
      });
      return;
    }

    // Mientras consulta SECOP II en vivo desde la primera letra, muestra coincidencias verificadas si existen
    final seedMatches = _filterVerifiedSeedEntities(trimmed);
    setState(() {
      _activeEntities = seedMatches;
      if (seedMatches.isNotEmpty) {
        _recalculateKpisFromList(seedMatches);
      }
      _isLoadingLive = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      _runFastEntitiesQuery();
    });
  }

  Future<void> _runFastEntitiesQuery({bool forceRefresh = false}) async {
    final queryText = _searchController.text.trim();

    if (queryText.isEmpty) {
      if (!mounted) return;
      final defaultList = _topContractingEntities.isNotEmpty
          ? _topContractingEntities.take(10).toList()
          : _verifiedSecopDefaultEntities;
      setState(() {
        _activeEntities = defaultList;
        _recalculateKpisFromList(defaultList);
        _isLoadingLive = false;
      });
      return;
    }

    final cacheKey = _normalizar(queryText);

    if (!forceRefresh && _queryCache.containsKey(cacheKey)) {
      final cached = _queryCache[cacheKey]!;
      if (!mounted) return;
      setState(() {
        _activeEntities = cached.entities;
        _kpiTotalEntities = cached.totalEntities;
        _kpiTotalContracts = cached.totalContracts;
        _kpiTotalAmountMillions = cached.totalAmountMillions;
        _kpiUniqueContractors = cached.totalUniqueContractors;
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
          _activeEntities = bundle.entities;
          _kpiTotalEntities = bundle.totalEntities;
          _kpiTotalContracts = bundle.totalContracts;
          _kpiTotalAmountMillions = bundle.totalAmountMillions;
          _kpiUniqueContractors = bundle.totalUniqueContractors;
          _isLoadingLive = false;
        });
      } else {
        setState(() => _isLoadingLive = false);
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
    final bool queryAsksForRegional = cleanQuery.contains('REGIONAL') ||
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
      if (rawName.isEmpty) continue;

      // Excluimos Secretarías o dependencias sueltas para no confundirlas con entidades
      if (_isSecretariaOrDependency(rawName)) {
        continue;
      }

      final nitRaw = (item['nit_entidad'] ?? '').toString().trim();
      final cityRaw = (item['ciudad'] ?? '').toString().trim();
      final deptRaw = (item['departamento'] ?? '').toString().trim();
      final ordenRaw = (item['orden'] ?? '').toString().trim();

      final city = (cityRaw.isEmpty || cityRaw == 'No Definido')
          ? 'Colombia'
          : cityRaw;
      final dept = (deptRaw.isEmpty || deptRaw == 'No Definido')
          ? (ordenRaw.isNotEmpty ? ordenRaw : 'Colombia')
          : deptRaw;

      final contracts =
          int.tryParse((item['contratos'] ?? '0').toString()) ?? 0;
      final rawVal =
          double.tryParse((item['total_valor'] ?? '0').toString()) ?? 0;
      if (contracts <= 0 || rawVal <= 0) continue;

      final safeVal = rawVal > 50000000000000 ? rawVal / 1000 : rawVal;
      final millions = safeVal / 1000000;
      final contractors =
          int.tryParse((item['contratistas'] ?? '1').toString()) ?? 1;

      String prettyName = _beautifyEntityName(rawName);
      final isMultiRegionalRoot =
          prettyName == 'Servicio Nacional de Aprendizaje - SENA' ||
              prettyName ==
                  'Instituto Colombiano de Bienestar Familiar - ICBF' ||
              prettyName == 'Instituto Nacional de Vías - INVIAS';

      if (isMultiRegionalRoot &&
          queryAsksForRegional &&
          dept != 'Colombia' &&
          dept.isNotEmpty) {
        final shortRoot = prettyName.contains('SENA')
            ? 'Servicio Nacional de Aprendizaje - SENA'
            : (prettyName.contains('ICBF')
                ? 'Instituto Colombiano de Bienestar Familiar - ICBF'
                : 'Instituto Nacional de Vías - INVIAS');
        prettyName = '$shortRoot (Regional $dept)';
      }

      final normPretty = _normalizar(prettyName);
      final existing = consolidated[normPretty];

      if (existing == null) {
        final isConsolidationRoot = isMultiRegionalRoot && !queryAsksForRegional;
        final emblem = _classifyEmblem(rawName);
        final estDeps = isConsolidationRoot
            ? 33
            : math.max(4, math.min(20, (contracts / 110).ceil()));

        consolidated[normPretty] = EntitySummaryRecord(
          name: prettyName,
          nit: nitRaw.isNotEmpty && nitRaw != 'No Definido'
              ? (nitRaw == '8999990341' ? '899999034' : nitRaw)
              : 'Verificado SECOP II',
          location: isConsolidationRoot
              ? 'Colombia · Orden Nacional (33 Regionales)'
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
          dependenciesCount: estDeps,
          uniqueContractors: contractors,
          secopKeywords: isMultiRegionalRoot
              ? [prettyName.contains('SENA') ? 'SENA' : 'ICBF', rawName]
              : [rawName],
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

  /// Consulta en vivo a SECOP II (Vigencia anualizada 2026, cualquier orden de Colombia, desde la primera letra).
  Future<_CachedEntitiesBundle?> _executeUnfilteredSecopEntitySearch(
    String queryText,
  ) async {
    final clean = _normalizar(queryText.trim());
    if (clean.isEmpty) return null;

    List<dynamic> rawList = [];

    // Caso A: El usuario escribió la primera letra (1 carácter)
    if (clean.length == 1) {
      try {
        final whereClause =
            "nombre_entidad IS NOT NULL AND valor_del_contrato > 0 AND valor_del_contrato < 500000000000 AND fecha_de_firma >= '2026-01-01T00:00:00.000' AND upper(nombre_entidad) LIKE '$clean%' AND upper(nombre_entidad) NOT LIKE '%SECRETAR%'";
        final url = Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
          '\$select=nombre_entidad,nit_entidad,ciudad,departamento,orden,count(*)%20as%20contratos,sum(valor_del_contrato)%20as%20total_valor,count(distinct%20documento_proveedor)%20as%20contratistas'
          '&\$where=${Uri.encodeComponent(whereClause)}'
          '&\$group=nombre_entidad,nit_entidad,ciudad,departamento,orden'
          '&\$order=contratos%20DESC'
          '&\$limit=25',
        );
        final resp = await http.get(url).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          rawList = jsonDecode(resp.body) as List<dynamic>;
        }
      } catch (_) {
        rawList = [];
      }
    } else {
      // Caso B: 2 o más caracteres (ej. "sena", "sena atlantico", "alcaldia de santa marta", "invias", "gobernacion")
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
        'REGIONAL',
        'SECCIONAL',
      };

      final rawTokens = clean
          .replaceAll("'", '')
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      final sigTokens =
          rawTokens.where((t) => !connectors.contains(t)).toList();
      final tokens = sigTokens.isNotEmpty ? sigTokens : rawTokens;

      final whereClauses = <String>[
        'nombre_entidad IS NOT NULL',
        'valor_del_contrato > 0',
        'valor_del_contrato < 500000000000',
        "fecha_de_firma >= '2026-01-01T00:00:00.000'",
      ];

      if (!tokens.contains('SENA')) {
        whereClauses.add("upper(nombre_entidad) NOT LIKE '%SECRETAR%'");
      }

      for (final t in tokens) {
        if (t.startsWith('ALCALD')) {
          whereClauses.add(
            "(upper(nombre_entidad) LIKE '%ALCALD%' OR upper(nombre_entidad) LIKE '%MUNICIPIO%' OR upper(nombre_entidad) LIKE '%DISTRITO%')",
          );
        } else if (t.startsWith('GOBERNAC')) {
          whereClauses.add(
            "(upper(nombre_entidad) LIKE '%GOBERNAC%' OR upper(nombre_entidad) LIKE '%DEPARTAMENTO%')",
          );
        } else {
          whereClauses.add(
            "(upper(nombre_entidad) LIKE '%$t%' OR upper(departamento) LIKE '%$t%' OR upper(ciudad) LIKE '%$t%')",
          );
        }
      }

      final whereParam = Uri.encodeComponent(whereClauses.join(' AND '));

      try {
        final url = Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
          '\$select=nombre_entidad,nit_entidad,ciudad,departamento,orden,count(*)%20as%20contratos,sum(valor_del_contrato)%20as%20total_valor,count(distinct%20documento_proveedor)%20as%20contratistas'
          '&\$where=$whereParam'
          '&\$group=nombre_entidad,nit_entidad,ciudad,departamento,orden'
          '&\$order=contratos%20DESC'
          '&\$limit=45',
        );
        final response =
            await http.get(url).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          rawList = jsonDecode(response.body) as List<dynamic>;
        }
      } catch (_) {
        rawList = [];
      }
    }

    var finalEntities = _parseAndConsolidateSecopEntities(rawList, clean);

    // Integramos también coincidencias de las entidades verificadas de SECOP II si corresponden
    for (final seed in _filterVerifiedSeedEntities(queryText)) {
      final normSeed = _normalizar(seed.name);
      if (!finalEntities.any((e) => _normalizar(e.name) == normSeed)) {
        finalEntities.insert(0, seed);
      } else {
        // Si es SENA, ICBF o INVIAS consolidado, preferimos la cifra nacional anualizada 2026 completa
        final idx =
            finalEntities.indexWhere((e) => _normalizar(e.name) == normSeed);
        if (idx >= 0 && seed.contractsCount > finalEntities[idx].contractsCount) {
          finalEntities[idx] = seed;
        }
      }
    }

    if (clean == 'SENA' || clean == 'SERVICIO NACIONAL DE APRENDIZAJE') {
      final onlySena = finalEntities
          .where((e) => _normalizar(e.name).contains('SENA'))
          .toList();
      if (onlySena.isNotEmpty) {
        finalEntities = onlySena;
      }
    } else if (clean.contains('ALCALD')) {
      final cityTokens = clean
          .split(RegExp(r'\s+'))
          .where(
            (t) =>
                t.length >= 3 &&
                !t.startsWith('ALCALD') &&
                !{'DEL', 'LAS', 'LOS', 'MUNICIPAL', 'DISTRITAL'}.contains(t),
          )
          .toList();
      if (cityTokens.isNotEmpty) {
        final exactAlcaldias = finalEntities.where((e) {
          final n = _normalizar(e.name);
          return (n.contains('ALCALDIA') ||
                  n.contains('MUNICIPIO') ||
                  n.contains('DISTRITO')) &&
              cityTokens.every(
                (ct) => n.contains(ct) || _normalizar(e.municipio).contains(ct),
              );
        }).toList();
        if (exactAlcaldias.isNotEmpty) {
          finalEntities = exactAlcaldias;
        }
      }
    }

    if (finalEntities.isEmpty) return null;

    final sumContracts =
        finalEntities.fold<int>(0, (acc, e) => acc + e.contractsCount);
    final sumMillions =
        finalEntities.fold<double>(0, (acc, e) => acc + e.amountMillions);
    final sumContractors =
        finalEntities.fold<int>(0, (acc, e) => acc + e.uniqueContractors);

    return _CachedEntitiesBundle(
      entities: finalEntities,
      totalEntities: finalEntities.length,
      totalContracts: sumContracts,
      totalAmountMillions: sumMillions,
      totalUniqueContractors: sumContractors,
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
      case 'Más dependencias':
        list.sort((a, b) => b.dependenciesCount.compareTo(a.dependenciesCount));
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
    final source = _topContractingEntities.isNotEmpty
        ? _topContractingEntities
        : _verifiedSecopDefaultEntities;
    final sorted = List<EntitySummaryRecord>.from(source)
      ..sort((a, b) => b.amountMillions.compareTo(a.amountMillions));
    return sorted.take(5).toList();
  }

  // ===========================================================================
  // NAVEGACIÓN AL PERFIL DE CADA ENTIDAD Y COMPARADOR SIN FILTROS
  // ===========================================================================

  void _openEntityProfile(EntitySummaryRecord entity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilEntidadScreen(entity: entity),
      ),
    );
  }

  void _showCompareEntitiesModal() {
    final pool = _topContractingEntities.isNotEmpty
        ? _topContractingEntities
        : _verifiedSecopDefaultEntities;
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
          searchSeedEntities: _filterVerifiedSeedEntities,
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
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('usuarioActivo');
    await prefs.remove('userEmail');
  }

  Widget _buildTopRightProfileBar() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String rawName = currentUser?.displayName?.trim() ?? '';
    final String firstName = rawName.isNotEmpty
        ? rawName.split(' ').first
        : 'Valentina';
    final String? photoURL = currentUser?.photoURL;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Tienes 3 alertas activas de contratación pública en SECOP II.',
                ),
                duration: Duration(seconds: 2),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: _azulOscuro,
                  size: 24,
                ),
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        PopupMenuButton<String>(
          tooltip: 'Opciones del perfil',
          onSelected: (value) {
            if (value == 'logout') {
              _handleLogout();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'logout',
              child: Text('Cerrar sesión'),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 19,
                  backgroundImage:
                      photoURL != null ? NetworkImage(photoURL) : null,
                  backgroundColor: const Color(0xFF334155),
                  child: photoURL == null
                      ? const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 21,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hola, $firstName',
                    style: const TextStyle(
                      color: _azulOscuro,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Consulta ciudadana',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF475569),
                size: 19,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderLeftWithCallout() {
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
                  hintText:
                      'Buscar entidad verificada en SECOP II (ej. SENA, Alcaldía de Santa Marta, INVIAS, ICBF...)',
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
      return Expanded(
        child: Container(
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
        decoration: BoxDecoration(
          color: outerColor,
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: innerColor,
            shape: BoxShape.circle,
          ),
          child: child,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          kpiCard(
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
            subtitleUnderTitle: 'en Colombia (SECOP II)',
            mainValue: '$_kpiTotalEntities',
            trendPercent: 'Verificadas',
            trendComparison: 'Datos Abiertos',
          ),
          const SizedBox(width: 10),
          kpiCard(
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
          ),
          const SizedBox(width: 10),
          kpiCard(
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
          ),
          const SizedBox(width: 10),
          kpiCard(
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
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab({
    required IconData icon,
    required String label,
  }) {
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
                Icon(
                  icon,
                  size: 15,
                  color: const Color(0xFF475569),
                ),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEntityProfile(entity),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              EntityBrandScope(
                entityName: entity.name,
                nit: entity.nit,
                child: EntityEmblemWidget(type: entity.emblemType, size: 44),
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
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
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
          if (entities.isEmpty)
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
                        : 'No se encontraron entidades en SECOP II con ese criterio.',
                    style: const TextStyle(
                      color: _azulOscuro,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                          'Busca sin filtros cualquier par de entidades verificadas de SECOP II y compara su presupuesto, contratos y contratistas.',
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
                      colors: [
                        _bgCrema.withValues(alpha: 0.0),
                        _bgCrema,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 16, 26, 28),
                child: Row(
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
  const EntityEmblemWidget({
    super.key,
    required this.type,
    this.size = 42,
  });

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

    canvas.drawCircle(
      center,
      w / 2,
      Paint()..color = const Color(0xFFFFFBF5),
    );
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
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.44),
      w * 0.13,
      goldPaint,
    );
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
              (_) => Container(
                height: 1,
                color: const Color(0xFFF1F5F9),
              ),
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
    final maxAmount =
        math.max(_entityA.amountMillions, _entityB.amountMillions);
    final maxContracts =
        math.max(_entityA.contractsCount, _entityB.contractsCount);
    final maxContractors =
        math.max(_entityA.uniqueContractors, _entityB.uniqueContractors);

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
