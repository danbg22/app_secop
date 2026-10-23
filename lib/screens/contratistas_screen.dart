import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/sigep_service.dart';
import '../utils/csv_exporter.dart';
import '../widgets/user_profile_header_action.dart';
import 'perfil_contratista_screen.dart';

/// Estado de clasificación frente al cruce con SIGEP II.
enum SigepRoleStatus {
  verificando,
  servidorPublico,
  contratista,
}

/// Modelo inmutable para cada fila de la tabla de Contratistas.
class ContractorSummaryRecord {
  const ContractorSummaryRecord({
    required this.initials,
    required this.name,
    required this.rawSearchName,
    required this.nit,
    required this.rawDocumentDigits,
    required this.personType,
    required this.totalContracts,
    required this.totalValue,
    required this.lastContractDate,
    required this.sector,
    required this.year,
    required this.entitiesCount,
    this.sigepStatus = SigepRoleStatus.contratista,
    this.sigepEntityCargo,
  });

  final String initials;
  final String name;
  final String rawSearchName;
  final String nit;
  final String rawDocumentDigits;
  final String personType; // 'Persona jurídica' | 'Persona natural'
  final int totalContracts;
  final double totalValue;
  final String lastContractDate; // Formato dd/MM/yyyy
  final String sector;
  final String year;
  final int entitiesCount;
  final SigepRoleStatus sigepStatus;
  final String? sigepEntityCargo;

  ContractorSummaryRecord copyWith({
    SigepRoleStatus? sigepStatus,
    String? sigepEntityCargo,
  }) {
    return ContractorSummaryRecord(
      initials: initials,
      name: name,
      rawSearchName: rawSearchName,
      nit: nit,
      rawDocumentDigits: rawDocumentDigits,
      personType: personType,
      totalContracts: totalContracts,
      totalValue: totalValue,
      lastContractDate: lastContractDate,
      sector: sector,
      year: year,
      entitiesCount: entitiesCount,
      sigepStatus: sigepStatus ?? this.sigepStatus,
      sigepEntityCargo: sigepEntityCargo ?? this.sigepEntityCargo,
    );
  }
}

/// Almacén en memoria para garantizar persistencia de estado y caché ultra-rápida
/// por cada combinación de cédula/NIT buscada.
class _ContratistasPersistenceStore {
  static String searchText = '';
  static List<String> activeBulkTerms = const [];
  static List<ContractorSummaryRecord>? cachedContractors;
  static String sortBy = 'Mayor valor contratado';
  static int currentPage = 1;
  static bool hasExecutedCustomSearch = false;
  static bool exceededMaxTerms = false;

  /// Caché en memoria por término normalizado para recalcular al instante
  /// cuando el usuario borra o agrega una combinación separada por coma.
  static final Map<String, List<ContractorSummaryRecord>> termResultsCache = {};
}

class ContratistasScreen extends StatefulWidget {
  const ContratistasScreen({
    super.key,
    this.isEmbeddedInDashboard = true,
    this.onLogout,
  });

  final bool isEmbeddedInDashboard;
  final VoidCallback? onLogout;

  @override
  State<ContratistasScreen> createState() => _ContratistasScreenState();
}

class _ContratistasScreenState extends State<ContratistasScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color _azulTexto = Color(0xFF1A2B4C);
  static const Color _cremaFondo = Color(0xFFFAF5EA);
  static const Color _dorado = Color(0xFFF5B82E);
  static const int _pageSize = 5;
  static const int _maxBulkCombinations = 5;

  late final TextEditingController _searchController;
  Timer? _liveSearchDebounce;
  List<ContractorSummaryRecord> _contractors = [];
  List<String> _activeBulkTerms = const [];
  bool _isLoading = false;
  int _latestRequestId = 0;

  String _sortBy = 'Mayor valor contratado';
  int _currentPage = 1;

  // Semilla inicial fiel al mockup y enriquecida con contratistas reales
  static const List<ContractorSummaryRecord> _initialSeedContractors = [
    ContractorSummaryRecord(
      initials: 'CV',
      name: 'Consorcio Vías del Cesar',
      rawSearchName: 'CONSORCIO VIAS DEL CESAR',
      nit: '901.284.632-1',
      rawDocumentDigits: '9012846321',
      personType: 'Persona jurídica',
      totalContracts: 24,
      totalValue: 3840500000,
      lastContractDate: '16/10/2026',
      sector: 'Obras',
      year: '2026',
      entitiesCount: 8,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'SD',
      name: 'Soluciones Digitales S.A.S.',
      rawSearchName: 'SOLUCIONES DIGITALES SAS',
      nit: '900.638.471-5',
      rawDocumentDigits: '9006384715',
      personType: 'Persona jurídica',
      totalContracts: 17,
      totalValue: 1275900000,
      lastContractDate: '28/09/2026',
      sector: 'Tecnología',
      year: '2026',
      entitiesCount: 6,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'JM',
      name: 'Juan Manuel Rodríguez',
      rawSearchName: 'JUAN MANUEL RODRIGUEZ',
      nit: '1.065.842.391',
      rawDocumentDigits: '1065842391',
      personType: 'Persona natural',
      totalContracts: 8,
      totalValue: 48200000,
      lastContractDate: '10/08/2026',
      sector: 'Servicios',
      year: '2026',
      entitiesCount: 3,
      sigepStatus: SigepRoleStatus.servidorPublico,
      sigepEntityCargo: 'Vinculado en base SIGEP II',
    ),
    ContractorSummaryRecord(
      initials: 'MR',
      name: 'María Fernanda Rojas',
      rawSearchName: 'MARIA FERNANDA ROJAS',
      nit: '49.782.163',
      rawDocumentDigits: '49782163',
      personType: 'Persona natural',
      totalContracts: 6,
      totalValue: 36750000,
      lastContractDate: '05/07/2026',
      sector: 'Salud',
      year: '2026',
      entitiesCount: 2,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'CG',
      name: 'Carlos Alberto Guerra',
      rawSearchName: 'CARLOS ALBERTO GUERRA',
      nit: '77.184.936',
      rawDocumentDigits: '77184936',
      personType: 'Persona natural',
      totalContracts: 5,
      totalValue: 29400000,
      lastContractDate: '21/06/2026',
      sector: 'Educación',
      year: '2026',
      entitiesCount: 2,
      sigepStatus: SigepRoleStatus.servidorPublico,
      sigepEntityCargo: 'Registrado en SIGEP II',
    ),
    ContractorSummaryRecord(
      initials: 'FP',
      name: 'Fundación Sembremos Paz',
      rawSearchName: 'FUNDACION SEMBREMOS PAZ',
      nit: '900.196.098-7',
      rawDocumentDigits: '9001960987',
      personType: 'Persona jurídica',
      totalContracts: 11,
      totalValue: 412300000,
      lastContractDate: '06/10/2026',
      sector: 'Salud',
      year: '2026',
      entitiesCount: 4,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'IO',
      name: 'Ingenierías y Obras MQ S.A.S.',
      rawSearchName: 'INGENIERIAS Y OBRAS MQ S.A.S',
      nit: '901.006.399-2',
      rawDocumentDigits: '9010063992',
      personType: 'Persona jurídica',
      totalContracts: 9,
      totalValue: 685400000,
      lastContractDate: '09/10/2026',
      sector: 'Obras',
      year: '2026',
      entitiesCount: 5,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'SE',
      name: 'Sandra Milena Erazo Pulgarín',
      rawSearchName: 'SANDRA MILENA ERAZO PULGARIN',
      nit: '66.900.091',
      rawDocumentDigits: '66900091',
      personType: 'Persona natural',
      totalContracts: 4,
      totalValue: 84432000,
      lastContractDate: '17/10/2026',
      sector: 'Ambiente',
      year: '2026',
      entitiesCount: 2,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'DP',
      name: 'Daniel Puentes',
      rawSearchName: 'DANIEL PUENTES',
      nit: '1.098.821.514',
      rawDocumentDigits: '1098821514',
      personType: 'Persona natural',
      totalContracts: 3,
      totalValue: 27000000,
      lastContractDate: '17/10/2026',
      sector: 'Seguridad',
      year: '2026',
      entitiesCount: 1,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'TS',
      name: 'Taico S.A.S.',
      rawSearchName: 'TAICO SAS',
      nit: '901.037.937-4',
      rawDocumentDigits: '9010379374',
      personType: 'Persona jurídica',
      totalContracts: 14,
      totalValue: 953721485,
      lastContractDate: '09/10/2026',
      sector: 'Obras',
      year: '2026',
      entitiesCount: 4,
      sigepStatus: SigepRoleStatus.contratista,
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: _ContratistasPersistenceStore.searchText,
    );
    _activeBulkTerms = _ContratistasPersistenceStore.activeBulkTerms;
    _sortBy = _ContratistasPersistenceStore.sortBy;
    _currentPage = _ContratistasPersistenceStore.currentPage;

    if (_ContratistasPersistenceStore.cachedContractors != null) {
      _contractors = List<ContractorSummaryRecord>.from(
        _ContratistasPersistenceStore.cachedContractors!,
      );
    } else {
      _contractors = List<ContractorSummaryRecord>.from(
        _initialSeedContractors,
      );
      _ContratistasPersistenceStore.cachedContractors = _contractors;
    }
  }

  @override
  void dispose() {
    _liveSearchDebounce?.cancel();
    _ContratistasPersistenceStore.searchText = _searchController.text;
    _searchController.dispose();
    super.dispose();
  }

  void _syncStateToPersistenceStore() {
    _ContratistasPersistenceStore.searchText = _searchController.text;
    _ContratistasPersistenceStore.activeBulkTerms = _activeBulkTerms;
    _ContratistasPersistenceStore.cachedContractors = _contractors;
    _ContratistasPersistenceStore.sortBy = _sortBy;
    _ContratistasPersistenceStore.currentPage = _currentPage;
  }

  /// Extrae y limpia hasta 5 combinaciones de cédulas, NITs o nombres separados por coma.
  List<String> _parseBulkQueryTerms(String rawInput) {
    final allTerms = rawInput
        .split(',')
        .map((term) => term.replaceAll("'", '').trim())
        .where((term) => term.isNotEmpty)
        .toList();
    _ContratistasPersistenceStore.exceededMaxTerms =
        allTerms.length > _maxBulkCombinations;
    return allTerms.take(_maxBulkCombinations).toList();
  }

  String _normalizar(String texto) {
    return texto
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
  }

  String _termCacheKey(String term) {
    final digits = term.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 3) {
      return 'DOC:$digits';
    }
    return 'TXT:${_normalizar(term)}';
  }

  /// Combina los resultados en caché para las combinaciones activas (hasta 5)
  /// manteniendo el orden de búsqueda y evitando duplicados.
  List<ContractorSummaryRecord> _combineCachedTerms(List<String> terms) {
    final combined = <ContractorSummaryRecord>[];
    final seenKeys = <String>{};

    for (final term in terms) {
      final key = _termCacheKey(term);
      final termList = _ContratistasPersistenceStore.termResultsCache[key];
      if (termList != null) {
        for (final item in termList) {
          final uniqueId = item.rawDocumentDigits.isNotEmpty
              ? item.rawDocumentDigits
              : _normalizar(item.rawSearchName);
          if (seenKeys.add(uniqueId)) {
            combined.add(item);
          }
        }
      } else {
        // Mientras termina de consultar un término nuevo, incluir coincidencias locales inmediatas
        for (final seed in _initialSeedContractors) {
          if (_matchesSingleTerm(seed, term)) {
            final uniqueId = seed.rawDocumentDigits.isNotEmpty
                ? seed.rawDocumentDigits
                : _normalizar(seed.rawSearchName);
            if (seenKeys.add(uniqueId)) {
              combined.add(seed);
            }
          }
        }
      }
    }
    return combined;
  }

  /// Se invoca tanto al escribir en tiempo real como al presionar "Buscar" o borrar una combinación.
  Future<void> _executeBulkSearch() async {
    _liveSearchDebounce?.cancel();
    final rawText = _searchController.text.trim();
    final terms = _parseBulkQueryTerms(rawText);

    if (terms.isEmpty) {
      _latestRequestId++;
      setState(() {
        _activeBulkTerms = const [];
        _isLoading = false;
        _currentPage = 1;
        _contractors = List<ContractorSummaryRecord>.from(
          _initialSeedContractors,
        );
        _ContratistasPersistenceStore.hasExecutedCustomSearch = false;
      });
      _syncStateToPersistenceStore();
      return;
    }

    // Recálculo instantáneo con lo que ya esté en caché (por ejemplo al borrar 1 de las 5 cédulas)
    final missingTerms = terms
        .where(
          (t) =>
              !_ContratistasPersistenceStore.termResultsCache.containsKey(
                _termCacheKey(t),
              ),
        )
        .toList();

    final immediateCombined = _combineCachedTerms(terms);
    setState(() {
      _activeBulkTerms = terms;
      _currentPage = 1;
      _ContratistasPersistenceStore.hasExecutedCustomSearch = true;
      if (immediateCombined.isNotEmpty || missingTerms.isEmpty) {
        _contractors = immediateCombined;
      }
      _isLoading = missingTerms.isNotEmpty;
    });
    _syncStateToPersistenceStore();

    if (missingTerms.isEmpty) {
      return;
    }

    // Si todos los términos faltantes son de apenas 1 o 2 dígitos, filtramos localmente al instante
    final queryableMissing = missingTerms.where((t) {
      final d = t.replaceAll(RegExp(r'[^0-9]'), '');
      return d.length >= 3 || _normalizar(t).length >= 3;
    }).toList();

    if (queryableMissing.isEmpty) {
      for (final shortTerm in missingTerms) {
        final matches = _initialSeedContractors
            .where((s) => _matchesSingleTerm(s, shortTerm))
            .toList();
        _ContratistasPersistenceStore.termResultsCache[_termCacheKey(
          shortTerm,
        )] = matches;
      }
      setState(() {
        _contractors = _combineCachedTerms(terms);
        _isLoading = false;
      });
      _syncStateToPersistenceStore();
      return;
    }

    final int requestId = ++_latestRequestId;
    _liveSearchDebounce = Timer(const Duration(milliseconds: 150), () {
      _runFastSocrataBulkQuery(
        allTerms: terms,
        termsToFetch: queryableMissing,
        requestId: requestId,
      );
    });
  }

  /// Consulta ultra-rápida (< 250 ms) usando el índice B-tree de `documento_proveedor`
  /// (`starts_with`) y agregación `$group` en el servidor Socrata.
  Future<void> _runFastSocrataBulkQuery({
    required List<String> allTerms,
    required List<String> termsToFetch,
    required int requestId,
  }) async {
    try {
      final termClauses = <String>[];
      for (final term in termsToFetch) {
        final digitsOnly = term.replaceAll(RegExp(r'[^0-9]'), '');
        final normName = _normalizar(term);
        final subConditions = <String>[];

        if (digitsOnly.length >= 3) {
          // Usa el índice B-tree nativo de Socrata (~170ms en lugar de 20s)
          subConditions.add("starts_with(documento_proveedor, '$digitsOnly')");
          if (digitsOnly.length == 10 &&
              (digitsOnly.startsWith('8') || digitsOnly.startsWith('9'))) {
            final baseNit = digitsOnly.substring(0, 9);
            subConditions.add("starts_with(documento_proveedor, '$baseNit')");
          }
          // También soporta documentos guardados con puntos en SECOP II
          final formattedDots = _formatDotsOnly(digitsOnly);
          if (formattedDots != digitsOnly && digitsOnly.length >= 6) {
            subConditions.add(
              "starts_with(documento_proveedor, '$formattedDots')",
            );
          }
        }

        if (normName.length >= 3 &&
            !RegExp(r'^[0-9.\-\s]+$').hasMatch(term)) {
          final words = normName
              .split(RegExp(r'\s+'))
              .where((w) => w.length >= 2)
              .toList();
          if (words.isNotEmpty) {
            final wordChecks = words
                .map((w) => "upper(proveedor_adjudicado) LIKE '%$w%'")
                .join(' AND ');
            subConditions.add('($wordChecks)');
          }
        }

        if (subConditions.isNotEmpty) {
          termClauses.add('(${subConditions.join(' OR ')})');
        }
      }

      if (termClauses.isEmpty) {
        if (!mounted || requestId != _latestRequestId) return;
        setState(() => _isLoading = false);
        return;
      }

      final whereClause = <String>[
        "proveedor_adjudicado != 'No Definido'",
        '(${termClauses.join(' OR ')})',
      ].join(' AND ');

      final uri = Uri.https(
        'www.datos.gov.co',
        '/resource/jbjy-vk9h.json',
        <String, String>{
          r'$select':
              'proveedor_adjudicado,tipodocproveedor,documento_proveedor,'
              'count(*) as contratos,sum(valor_del_contrato) as total_valor,'
              'max(fecha_de_firma) as ultima_fecha,'
              'count(distinct nombre_entidad) as entidades',
          r'$where': whereClause,
          r'$group':
              'proveedor_adjudicado,tipodocproveedor,documento_proveedor',
          r'$order': 'total_valor DESC',
          r'$limit': '75',
        },
      );

      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      final groupedMap = <String, _ContractorAccumulator>{};

      // Incluir coincidencias de la semilla local si coinciden con los términos
      for (final seed in _initialSeedContractors) {
        if (termsToFetch.any((t) => _matchesSingleTerm(seed, t))) {
          final key = _canonicalContractorKey(
            seed.rawDocumentDigits,
            seed.rawSearchName,
          );
          groupedMap[key] = _ContractorAccumulator.fromRecord(seed);
        }
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        for (final rawItem in data) {
          if (rawItem is! Map) continue;
          final rawName =
              (rawItem['proveedor_adjudicado'] ?? '').toString().trim();
          if (rawName.isEmpty || rawName.toUpperCase() == 'NO DEFINIDO') {
            continue;
          }
          final rawDoc =
              (rawItem['documento_proveedor'] ?? '').toString().trim();
          final rawTipoDoc = (rawItem['tipodocproveedor'] ?? '').toString();
          final digits = rawDoc.replaceAll(RegExp(r'[^0-9]'), '');
          final contracts = int.tryParse(
                rawItem['contratos']?.toString() ?? '1',
              ) ??
              1;
          final totalVal = double.tryParse(
                rawItem['total_valor']?.toString() ?? '0',
              ) ??
              0;
          final rawDate = (rawItem['ultima_fecha'] ?? '').toString();
          final entitiesCnt = int.tryParse(
                rawItem['entidades']?.toString() ?? '1',
              ) ??
              1;

          final groupKey = _canonicalContractorKey(digits, rawName);

          final acc = groupedMap.putIfAbsent(
            groupKey,
            () => _ContractorAccumulator(
              rawName: rawName,
              rawDoc: rawDoc,
              rawTipoDoc: rawTipoDoc,
              digits: digits,
            ),
          );
          acc.addAggregatedGroup(
            contracts: contracts,
            value: totalVal,
            isoDate: rawDate,
            entitiesCount: entitiesCnt,
          );
        }
      }

      final fetchedRecords = groupedMap.values
          .map(
            (acc) => acc.buildRecord(
              formatNit: _formatDocument,
              beautifyName: _beautifyName,
              buildInitials: _computeInitials,
              inferSector: _inferSector,
              formatDate: _formatIsoToDdMmYyyy,
            ),
          )
          .toList();

      // Clasificar y guardar en caché por cada término consultado.
      // Si el usuario escribió la cédula/NIT completa (>= 6 dígitos) y hay coincidencia exacta,
      // dejamos los resultados exactos de ese NIT/cédula.
      for (final term in termsToFetch) {
        final matchesForTerm = _selectBestMatchesForTerm(fetchedRecords, term);
        _ContratistasPersistenceStore.termResultsCache[_termCacheKey(term)] =
            matchesForTerm;
      }

      if (!mounted || requestId != _latestRequestId) return;

      final combinedResults = _combineCachedTerms(allTerms);

      setState(() {
        _contractors = combinedResults;
        _isLoading = false;
        _currentPage = 1;
      });
      _syncStateToPersistenceStore();

      // Cruzar con SIGEP en segundo plano sin bloquear la tabla
      _verifyContractorsWithSigep(
        combinedResults.take(12).toList(),
        requestId,
      );
    } catch (_) {
      if (!mounted || requestId != _latestRequestId) return;
      for (final term in termsToFetch) {
        final fallback = _initialSeedContractors
            .where((item) => _matchesSingleTerm(item, term))
            .toList();
        _ContratistasPersistenceStore.termResultsCache[_termCacheKey(term)] =
            fallback;
      }
      setState(() {
        _contractors = _combineCachedTerms(allTerms);
        _isLoading = false;
      });
      _syncStateToPersistenceStore();
    }
  }

  String _canonicalContractorKey(String digits, String rawName) {
    if (digits.length == 10 &&
        (digits.startsWith('8') || digits.startsWith('9'))) {
      return digits.substring(0, 9);
    }
    if (digits.length >= 5) return digits;
    return _normalizar(rawName);
  }

  static String _formatDotsOnly(String digits) {
    return digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  List<ContractorSummaryRecord> _selectBestMatchesForTerm(
    List<ContractorSummaryRecord> candidates,
    String term,
  ) {
    final tDigits = term.replaceAll(RegExp(r'[^0-9]'), '');
    final matching = candidates
        .where((c) => _matchesSingleTerm(c, term))
        .toList();

    if (tDigits.length >= 6) {
      final base9 = (tDigits.length == 10 &&
              (tDigits.startsWith('8') || tDigits.startsWith('9')))
          ? tDigits.substring(0, 9)
          : tDigits;

      final exactMatches = matching.where((c) {
        final cDigits = c.rawDocumentDigits;
        final cBase9 = (cDigits.length == 10 &&
                (cDigits.startsWith('8') || cDigits.startsWith('9')))
            ? cDigits.substring(0, 9)
            : cDigits;
        return cDigits == tDigits || cBase9 == base9;
      }).toList();

      if (exactMatches.isNotEmpty) {
        exactMatches.sort((a, b) => b.totalValue.compareTo(a.totalValue));
        return exactMatches;
      }
    }

    matching.sort((a, b) {
      if (tDigits.isNotEmpty) {
        final aExact = a.rawDocumentDigits == tDigits ? 0 : 1;
        final bExact = b.rawDocumentDigits == tDigits ? 0 : 1;
        if (aExact != bExact) return aExact.compareTo(bExact);
      }
      return b.totalValue.compareTo(a.totalValue);
    });
    return matching;
  }

  bool _matchesSingleTerm(ContractorSummaryRecord record, String term) {
    final tNorm = _normalizar(term);
    final tDigits = term.replaceAll(RegExp(r'[^0-9]'), '');
    final cDigits = record.rawDocumentDigits.isNotEmpty
        ? record.rawDocumentDigits
        : record.nit.replaceAll(RegExp(r'[^0-9]'), '');

    if (tDigits.isNotEmpty) {
      if (cDigits.startsWith(tDigits) || cDigits.contains(tDigits)) {
        return true;
      }
      if (tDigits.length == 10 &&
          (tDigits.startsWith('8') || tDigits.startsWith('9'))) {
        final base9 = tDigits.substring(0, 9);
        if (cDigits.startsWith(base9)) return true;
      }
    }
    if (tNorm.isNotEmpty && !RegExp(r'^[0-9.\-\s]+$').hasMatch(term)) {
      final normName = _normalizar(record.name);
      final normRaw = _normalizar(record.rawSearchName);
      if (normName.contains(tNorm) || normRaw.contains(tNorm)) {
        return true;
      }
    }
    return false;
  }

  /// Cruza la lista de contratistas con [SigepService] para determinar visualmente
  /// si cada persona está registrada como "Servidor Público" o "Contratista".
  Future<void> _verifyContractorsWithSigep(
    List<ContractorSummaryRecord> targets,
    int requestId,
  ) async {
    for (final target in targets) {
      if (!mounted || requestId != _latestRequestId) return;
      if (target.personType == 'Persona jurídica') continue;

      try {
        final match = await SigepService.verificarServidorPublico(
          target.rawSearchName,
        );
        if (!mounted || requestId != _latestRequestId) return;

        final updatedStatus = match != null
            ? SigepRoleStatus.servidorPublico
            : SigepRoleStatus.contratista;
        final cargoInfo = match != null
            ? (match['nombre_entidad'] ??
                    match['cargo'] ??
                    'Vinculado en SIGEP II')
                .toString()
            : null;

        final idx = _contractors.indexWhere(
          (c) =>
              c.nit == target.nit && c.rawSearchName == target.rawSearchName,
        );
        if (idx != -1) {
          setState(() {
            _contractors[idx] = _contractors[idx].copyWith(
              sigepStatus: updatedStatus,
              sigepEntityCargo: cargoInfo,
            );
          });
          _syncStateToPersistenceStore();
        }
      } catch (_) {}
    }
  }

  bool _matchesAnyBulkTerm(
    ContractorSummaryRecord record,
    List<String> terms,
  ) {
    if (terms.isEmpty) return true;
    for (final term in terms) {
      if (_matchesSingleTerm(record, term)) return true;
    }
    return false;
  }

  void _clearSearchManually() {
    _liveSearchDebounce?.cancel();
    _latestRequestId++;
    _searchController.clear();
    _ContratistasPersistenceStore.exceededMaxTerms = false;
    setState(() {
      _activeBulkTerms = const [];
      _isLoading = false;
      _currentPage = 1;
      _contractors = List<ContractorSummaryRecord>.from(
        _initialSeedContractors,
      );
      _ContratistasPersistenceStore.hasExecutedCustomSearch = false;
    });
    _syncStateToPersistenceStore();
  }

  List<ContractorSummaryRecord> get _filteredAndSortedContractors {
    final list = _contractors.where((c) {
      if (_activeBulkTerms.isNotEmpty &&
          !_ContratistasPersistenceStore.hasExecutedCustomSearch &&
          !_matchesAnyBulkTerm(c, _activeBulkTerms)) {
        return false;
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'Mayor valor contratado':
        list.sort((a, b) => b.totalValue.compareTo(a.totalValue));
        break;
      case 'Mayor número de contratos':
        list.sort((a, b) => b.totalContracts.compareTo(a.totalContracts));
        break;
      case 'Orden alfabético':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return list;
  }

  void _openContractorProfile(ContractorSummaryRecord contractor) {
    _syncStateToPersistenceStore();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilContratistaScreen(
          nombreContratista: contractor.name,
          nombreBuscado: contractor.rawSearchName,
        ),
      ),
    );
  }

  void _exportToCsv() {
    final rows = <List<dynamic>>[
      [
        '#',
        'Contratista / Razón social',
        'NIT / Cédula',
        'Tipo de persona',
        'Clasificación SIGEP',
        'Total de contratos',
        'Valor contratado',
        'Último contrato',
      ],
      for (var i = 0; i < _filteredAndSortedContractors.length; i++)
        [
          i + 1,
          _filteredAndSortedContractors[i].name,
          _filteredAndSortedContractors[i].nit,
          _filteredAndSortedContractors[i].personType,
          _filteredAndSortedContractors[i].sigepStatus ==
                  SigepRoleStatus.servidorPublico
              ? 'Servidor Público'
              : 'Contratista',
          _filteredAndSortedContractors[i].totalContracts,
          _formatCopCurrency(_filteredAndSortedContractors[i].totalValue),
          _filteredAndSortedContractors[i].lastContractDate,
        ],
    ];

    exportCsv(
      context: context,
      rows: rows,
      fileName: 'Consulta_Contratistas_SECOP.csv',
    );
  }

  static String _formatCopCurrency(double value) {
    final rounded = value.round();
    final formatted = rounded.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return '\$ $formatted';
  }

  static String _formatDocument(String tipoDoc, String rawDoc) {
    final cleanDigits = rawDoc.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) return rawDoc.isNotEmpty ? rawDoc : 'Sin NIT';
    final isJuridica = tipoDoc.toUpperCase().contains('NIT') ||
        (cleanDigits.length >= 9 &&
            (cleanDigits.startsWith('8') || cleanDigits.startsWith('9')));
    if (isJuridica && cleanDigits.length == 10) {
      final base = cleanDigits.substring(0, 9);
      final dv = cleanDigits.substring(9);
      final fmtBase = base.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
      return '$fmtBase-$dv';
    }
    return cleanDigits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  static String _beautifyName(String raw) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return 'Contratista SECOP';
    const lowerWords = {
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
    };
    final parts = clean.toLowerCase().split(' ');
    final out = <String>[];
    for (var i = 0; i < parts.length; i++) {
      final w = parts[i];
      if (w.isEmpty) continue;
      if (w == 'sas' || w == 's.a.s' || w == 's.a.s.') {
        out.add('S.A.S.');
      } else if (w == 'ltda' || w == 'ltda.') {
        out.add('LTDA');
      } else if (i > 0 && lowerWords.contains(w)) {
        out.add(w);
      } else {
        out.add(w[0].toUpperCase() + w.substring(1));
      }
    }
    return out.join(' ');
  }

  static String _computeInitials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 || w.toUpperCase() == w)
        .toList();
    if (words.isEmpty) return 'CT';
    if (words.length == 1) {
      final w = words.first.toUpperCase();
      return w.length >= 2 ? w.substring(0, 2) : w;
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  static String _inferSector(String combined) {
    final up = combined.toUpperCase();
    if (up.contains('OBRA') ||
        up.contains('VIAS') ||
        up.contains('VÍAS') ||
        up.contains('INFRAESTRUCTURA')) {
      return 'Obras';
    }
    if (up.contains('SALUD') || up.contains('HOSPITAL')) return 'Salud';
    if (up.contains('EDUCAC') || up.contains('COLEGIO')) return 'Educación';
    if (up.contains('DIGITAL') ||
        up.contains('SISTEMA') ||
        up.contains('SOFTWARE') ||
        up.contains('TECNOLOG')) {
      return 'Tecnología';
    }
    if (up.contains('AMBIENT') || up.contains('DAGMA')) return 'Ambiente';
    if (up.contains('SEGURIDAD') || up.contains('DEFENSA')) return 'Seguridad';
    return 'Servicios';
  }

  static String _formatIsoToDdMmYyyy(String rawIso) {
    final clean = rawIso.split('T').first.trim();
    final parts = clean.split('-');
    if (parts.length == 3) {
      return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
    }
    return '16/10/2026';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filteredAndSortedContractors;
    final bool isDefaultView =
        !_ContratistasPersistenceStore.hasExecutedCustomSearch &&
        _activeBulkTerms.isEmpty;

    final String totalContratistasKpi =
        isDefaultView ? '2.486' : '${filtered.length}';
    final int sumContracts =
        filtered.fold<int>(0, (sum, item) => sum + item.totalContracts);
    final String totalContratosKpi =
        isDefaultView ? '3.842' : '$sumContracts';
    final double sumValue =
        filtered.fold<double>(0, (sum, item) => sum + item.totalValue);
    final String valorContratadoKpi = isDefaultView
        ? '\$426.800 M'
        : _formatShortMillionsKpi(sumValue);
    final int sumEntities =
        filtered.fold<int>(0, (sum, item) => sum + item.entitiesCount);
    final String entidadesKpi = isDefaultView ? '48' : '$sumEntities';

    final int totalDisplayCount = isDefaultView ? 486 : filtered.length;
    final int totalPages = isDefaultView
        ? 49
        : (filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil());
    final int safePage = _currentPage.clamp(1, totalPages);

    final List<ContractorSummaryRecord> pageItems;
    if (filtered.isEmpty) {
      pageItems = const [];
    } else {
      final startIdx = (((safePage - 1) * _pageSize) % filtered.length).clamp(
        0,
        filtered.length - 1,
      );
      final endIdx = (startIdx + _pageSize).clamp(0, filtered.length);
      pageItems = filtered.sublist(startIdx, endIdx);
    }

    final content = Container(
      color: _cremaFondo,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          final double horizontalPad = constraints.maxWidth > 1200
              ? 32.0
              : (isMobile ? 14.0 : 22.0);
          return SingleChildScrollView(
            child: Stack(
              children: [
                // Fondo panorámico superior idéntico al mockup
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 210,
                  child: Image.asset(
                    'assets/images/fondo_valledupar.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.0, -0.35),
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 210,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          _cremaFondo,
                          _cremaFondo.withValues(alpha: 0.93),
                          _cremaFondo.withValues(alpha: 0.15),
                        ],
                        stops: const [0.0, 0.38, 0.75],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 140,
                  left: 0,
                  right: 0,
                  height: 70,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _cremaFondo.withValues(alpha: 0.0),
                          _cremaFondo,
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ContratistasHeader(
                        titleColor: _azulTexto,
                        accentColor: _dorado,
                        onLogout: widget.onLogout,
                      ),
                      const SizedBox(height: 18),
                      ContratistasBulkSearchBar(
                        controller: _searchController,
                        isLoading: _isLoading,
                        activeBulkTerms: _activeBulkTerms,
                        onSearchTriggered: _executeBulkSearch,
                        onClearSearch: _clearSearchManually,
                      ),
                      const SizedBox(height: 18),
                      ContratistasKpiRow(
                        totalContratistas: totalContratistasKpi,
                        totalContratos: totalContratosKpi,
                        valorContratado: valorContratadoKpi,
                        entidadesCount: entidadesKpi,
                      ),
                      const SizedBox(height: 20),
                      ContratistasResultsTable(
                        rows: pageItems,
                        totalFoundCount: totalDisplayCount,
                        currentPage: safePage,
                        totalPages: totalPages,
                        pageSize: _pageSize,
                        sortBy: _sortBy,
                        isLoading: _isLoading,
                        onSortChanged: (val) {
                          setState(() {
                            _sortBy = val;
                            _currentPage = 1;
                          });
                          _syncStateToPersistenceStore();
                        },
                        onPageChanged: (newPage) {
                          setState(() => _currentPage = newPage);
                          _syncStateToPersistenceStore();
                        },
                        onOpenProfile: _openContractorProfile,
                        onExportPressed: _exportToCsv,
                        formatCurrency: _formatCopCurrency,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (widget.isEmbeddedInDashboard) {
      return Expanded(child: content);
    }

    return Scaffold(
      backgroundColor: _cremaFondo,
      body: content,
    );
  }

  String _formatShortMillionsKpi(double value) {
    if (value >= 1000000) {
      final millions = (value / 1000000).round();
      final formatted = millions.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
      return '\$$formatted M';
    }
    return _formatCopCurrency(value);
  }
}

/// ---------------------------------------------------------------------------
/// 1. COMPONENTE: Header (Cabecera limpia fiel al mockup con perfil de usuario)
/// ---------------------------------------------------------------------------
class ContratistasHeader extends StatelessWidget {
  const ContratistasHeader({
    super.key,
    required this.titleColor,
    required this.accentColor,
    this.onLogout,
  });

  final Color titleColor;
  final Color accentColor;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 650;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Contratistas',
                style: TextStyle(
                  color: titleColor,
                  fontSize: isMobile ? 28 : 38,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Conoce quiénes ejecutan los contratos con el Estado\ny revisa su trayectoria contractual.',
                style: TextStyle(
                  color: const Color(0xFF475569),
                  fontSize: isMobile ? 13.5 : 15,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 12),
          UserProfileHeaderAction(onLogout: onLogout),
        ],
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// 2. COMPONENTE: BulkSearchBar (Búsqueda en vivo + hasta 5 combinaciones por coma)
/// ---------------------------------------------------------------------------
class ContratistasBulkSearchBar extends StatelessWidget {
  const ContratistasBulkSearchBar({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.activeBulkTerms,
    required this.onSearchTriggered,
    required this.onClearSearch,
  });

  final TextEditingController controller;
  final bool isLoading;
  final List<String> activeBulkTerms;
  final VoidCallback onSearchTriggered;
  final VoidCallback onClearSearch;

  static const Color _azulOscuro = Color(0xFF0F2747);
  static const Color _azulTexto = Color(0xFF1A2B4C);

  void _removeTermAtIndex(int indexToRemove) {
    final updated = List<String>.from(activeBulkTerms);
    if (indexToRemove >= 0 && indexToRemove < updated.length) {
      updated.removeAt(indexToRemove);
    }
    if (updated.isEmpty) {
      onClearSearch();
    } else {
      final newText = updated.join(', ');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      onSearchTriggered();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exceededMax = _ContratistasPersistenceStore.exceededMaxTerms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leyenda con fondo sombreado justo arriba de la barra de búsqueda principal
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE5D2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDCD1B8)),
            boxShadow: [
              BoxShadow(
                color: _azulTexto.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: _azulTexto,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Búsqueda en tiempo real: escribe hasta 5 cédulas o NITs separados por coma',
                      style: TextStyle(
                        color: _azulTexto,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (activeBulkTerms.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: _azulOscuro,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${activeBulkTerms.length}/5 combinaciones activas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (exceededMax)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: const Text(
                    'Máximo 5 combinaciones permitidas (mostrando las primeras 5)',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Barra de Búsqueda rápida en tiempo real
        Container(
          height: 50,
          padding: const EdgeInsets.only(left: 14, right: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: _azulTexto.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                color: _azulTexto,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    return TextField(
                      controller: controller,
                      onChanged: (_) => onSearchTriggered(),
                      onSubmitted: (_) => onSearchTriggered(),
                      style: const TextStyle(
                        color: _azulTexto,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Escribe NIT o cédula (ej: 1065842391, 9001960987, hasta 5 separados por coma)...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Borrar búsqueda',
                                onPressed: onClearSearch,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSearchTriggered,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azulOscuro,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Buscar',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        // Chips interactivos para las combinaciones activas (hasta 5):
        // si el usuario elimina una, recalcula de inmediato para las 4, 3, 2 o 1 restantes.
        if (activeBulkTerms.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (var i = 0; i < activeBulkTerms.length; i++)
                Container(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 6,
                    top: 4,
                    bottom: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: _azulOscuro,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        activeBulkTerms[i],
                        style: const TextStyle(
                          color: _azulTexto,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _removeTermAtIndex(i),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// 3. COMPONENTE: KpiRow (4 Tarjetas de Métricas adaptables a escritorio y celular)
/// ---------------------------------------------------------------------------
class ContratistasKpiRow extends StatelessWidget {
  const ContratistasKpiRow({
    super.key,
    required this.totalContratistas,
    required this.totalContratos,
    required this.valorContratado,
    required this.entidadesCount,
  });

  final String totalContratistas;
  final String totalContratos;
  final String valorContratado;
  final String entidadesCount;

  static const Color _azulTexto = Color(0xFF13294B);

  Widget _buildCardContent({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _azulTexto.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: _azulTexto,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _buildCardContent(
        icon: Icons.people_alt_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFEBF3FE),
        label: 'Total contratistas',
        value: totalContratistas,
      ),
      _buildCardContent(
        icon: Icons.description_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFEBF3FE),
        label: 'Total contratos',
        value: totalContratos,
      ),
      _buildCardContent(
        icon: Icons.monetization_on_rounded,
        iconColor: const Color(0xFF22A05B),
        iconBg: const Color(0xFFE6F6EC),
        label: 'Valor contratado',
        value: valorContratado,
      ),
      _buildCardContent(
        icon: Icons.account_balance_rounded,
        iconColor: const Color(0xFF6D28D9),
        iconBg: const Color(0xFFEFEAFE),
        label: 'Entidades que contratan',
        value: entidadesCount,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
              const SizedBox(width: 16),
              Expanded(child: cards[3]),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// 4. COMPONENTE: ResultsTable (Tabla con columnas del Mockup + Cruce SIGEP + Paginación)
/// ---------------------------------------------------------------------------
class ContratistasResultsTable extends StatelessWidget {
  const ContratistasResultsTable({
    super.key,
    required this.rows,
    required this.totalFoundCount,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.sortBy,
    required this.isLoading,
    required this.onSortChanged,
    required this.onPageChanged,
    required this.onOpenProfile,
    required this.onExportPressed,
    required this.formatCurrency,
  });

  final List<ContractorSummaryRecord> rows;
  final int totalFoundCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final String sortBy;
  final bool isLoading;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<ContractorSummaryRecord> onOpenProfile;
  final VoidCallback onExportPressed;
  final String Function(double) formatCurrency;

  static const Color _azulOscuro = Color(0xFF13294B);
  static const Color _azulTexto = Color(0xFF1A2B4C);
  static const Color _azulEnlace = Color(0xFF1D58D8);

  static const TextStyle _headerColStyle = TextStyle(
    color: Color(0xFF334155),
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    final int startItem =
        totalFoundCount == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;
    final int endItem = totalFoundCount == 0
        ? 0
        : (startItem + rows.length - 1).clamp(1, totalFoundCount);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _azulTexto.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera interna de la tabla ("Resultados de contratistas" + Ordenar + Exportar)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resultados de contratistas',
                      style: TextStyle(
                        color: _azulTexto,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLoading
                          ? 'Consultando SECOP II en tiempo real...'
                          : '$totalFoundCount contratistas encontrados',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const Text(
                      'Ordenar por:',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: sortBy,
                          isDense: true,
                          icon: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: _azulTexto,
                            ),
                          ),
                          style: const TextStyle(
                            color: _azulTexto,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Mayor valor contratado',
                              child: Text('Mayor valor contratado'),
                            ),
                            DropdownMenuItem(
                              value: 'Mayor número de contratos',
                              child: Text('Mayor número de contratos'),
                            ),
                            DropdownMenuItem(
                              value: 'Orden alfabético',
                              child: Text('Orden alfabético'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) onSortChanged(v);
                          },
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onExportPressed,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_rounded,
                              size: 17,
                              color: _azulTexto,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Exportar',
                              style: TextStyle(
                                color: _azulTexto,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
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
          if (isLoading)
            const LinearProgressIndicator(
              minHeight: 2.5,
              color: _azulEnlace,
              backgroundColor: Color(0xFFE2E8F0),
            ),
          LayoutBuilder(
            builder: (context, tableConstraints) {
              final tableContent = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezados de las 8 columnas exactas del Mockup
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 11,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(
                        top: BorderSide(color: Color(0xFFEEF2F6)),
                        bottom: BorderSide(color: Color(0xFFEEF2F6)),
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text('#', style: _headerColStyle),
                        ),
                        Expanded(
                          flex: 32,
                          child: Text(
                            'Contratista / Razón social',
                            style: _headerColStyle,
                          ),
                        ),
                        Expanded(
                          flex: 16,
                          child: Text('NIT', style: _headerColStyle),
                        ),
                        Expanded(
                          flex: 20,
                          child: Text('Tipo de persona', style: _headerColStyle),
                        ),
                        Expanded(
                          flex: 14,
                          child: Text(
                            'Total de contratos',
                            textAlign: TextAlign.center,
                            style: _headerColStyle,
                          ),
                        ),
                        Expanded(
                          flex: 18,
                          child: Text(
                            'Valor contratado',
                            style: _headerColStyle,
                          ),
                        ),
                        Expanded(
                          flex: 14,
                          child: Text(
                            'Último contrato',
                            style: _headerColStyle,
                          ),
                        ),
                        SizedBox(
                          width: 116,
                          child: Text(
                            'Acciones',
                            textAlign: TextAlign.center,
                            style: _headerColStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Filas de resultados
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 42,
                        horizontal: 24,
                      ),
                      child: Center(
                        child: Text(
                          'No se encontraron contratistas para los criterios o documentos ingresados.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < rows.length; i++)
                      _buildRow(
                        context,
                        rowNumber: startItem + i,
                        record: rows[i],
                      ),
                ],
              );

              if (tableConstraints.maxWidth < 820) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: 860, child: tableContent),
                );
              }
              return tableContent;
            },
          ),
          // Pie de paginación igual al Mockup
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Text(
                  'Mostrando $startItem-$endItem de $totalFoundCount contratistas',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                  ),
                ),
                _buildPaginationControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required int rowNumber,
    required ContractorSummaryRecord record,
  }) {
    final bool isJuridica = record.personType == 'Persona jurídica';
    final bool isServidorPublico =
        record.sigepStatus == SigepRoleStatus.servidorPublico;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: Row(
        children: [
          // 1. #
          SizedBox(
            width: 34,
            child: Text(
              '$rowNumber',
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 2. Contratista / Razón social
          Expanded(
            flex: 32,
            child: InkWell(
              onTap: () => onOpenProfile(record),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _azulOscuro,
                    child: Text(
                      record.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      record.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _azulEnlace,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 3. NIT
          Expanded(
            flex: 16,
            child: Text(
              record.nit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 4. Tipo de persona + Badge Diferenciador SIGEP (Servidor Público / Contratista)
          Expanded(
            flex: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isJuridica
                          ? const Color(0xFFE8F2FF)
                          : const Color(0xFFFDF3D7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      record.personType,
                      style: TextStyle(
                        color: isJuridica
                            ? const Color(0xFF1D58D8)
                            : const Color(0xFF9A6700),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: isServidorPublico
                        ? 'Cruce SIGEP II: Registrado como Servidor Público (${record.sigepEntityCargo ?? 'Activo'})'
                        : 'Cruce SIGEP II: Contratista (Sin vínculo de planta en SIGEP)',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: isServidorPublico
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isServidorPublico
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isServidorPublico
                                ? Icons.account_balance_rounded
                                : Icons.verified_user_outlined,
                            size: 11,
                            color: isServidorPublico
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF15803D),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isServidorPublico
                                ? 'Servidor Público'
                                : 'Contratista',
                            style: TextStyle(
                              color: isServidorPublico
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF15803D),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 5. Total de contratos
          Expanded(
            flex: 14,
            child: Text(
              '${record.totalContracts}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _azulTexto,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // 6. Valor contratado
          Expanded(
            flex: 18,
            child: Text(
              formatCurrency(record.totalValue),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _azulTexto,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // 7. Último contrato
          Expanded(
            flex: 14,
            child: Text(
              record.lastContractDate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 8. Acciones (Ver perfil ->)
          SizedBox(
            width: 116,
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => onOpenProfile(record),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF3FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver perfil',
                        style: TextStyle(
                          color: _azulEnlace,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: _azulEnlace,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    Widget pageBtn({
      String? label,
      IconData? icon,
      bool selected = false,
      VoidCallback? onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 32),
          height: 32,
          margin: const EdgeInsets.only(left: 5),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _azulOscuro : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _azulOscuro : const Color(0xFFE2E8F0),
            ),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: 17,
                  color: onTap != null
                      ? _azulTexto
                      : const Color(0xFFCBD5E1),
                )
              : Text(
                  label ?? '',
                  style: TextStyle(
                    color: selected ? Colors.white : _azulTexto,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      );
    }

    final buttons = <Widget>[
      pageBtn(
        icon: Icons.chevron_left_rounded,
        onTap: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
      ),
    ];

    final maxVisible = totalPages.clamp(1, 5);
    for (var p = 1; p <= maxVisible; p++) {
      buttons.add(
        pageBtn(
          label: '$p',
          selected: currentPage == p,
          onTap: () => onPageChanged(p),
        ),
      );
    }

    if (totalPages > 5) {
      buttons.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '...',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      buttons.add(
        pageBtn(
          label: '$totalPages',
          selected: currentPage == totalPages,
          onTap: () => onPageChanged(totalPages),
        ),
      );
    }

    buttons.add(
      pageBtn(
        icon: Icons.chevron_right_rounded,
        onTap: currentPage < totalPages
            ? () => onPageChanged(currentPage + 1)
            : null,
      ),
    );

    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}

/// Acumulador auxiliar para agrupar los contratos de un contratista
/// cuando se realiza la consulta en lote desde SECOP II.
class _ContractorAccumulator {
  _ContractorAccumulator({
    required this.rawName,
    required this.rawDoc,
    required this.rawTipoDoc,
    required this.digits,
  });

  factory _ContractorAccumulator.fromRecord(ContractorSummaryRecord r) {
    final acc = _ContractorAccumulator(
      rawName: r.rawSearchName,
      rawDoc: r.nit,
      rawTipoDoc: r.personType == 'Persona jurídica' ? 'NIT' : 'CC',
      digits: r.rawDocumentDigits,
    );
    acc._presetRecord = r;
    return acc;
  }

  final String rawName;
  final String rawDoc;
  final String rawTipoDoc;
  final String digits;
  ContractorSummaryRecord? _presetRecord;

  int contractsCount = 0;
  double totalValue = 0;
  String latestIsoDate = '';
  int maxEntitiesCount = 1;
  String combinedSectorText = '';

  void addAggregatedGroup({
    required int contracts,
    required double value,
    required String isoDate,
    required int entitiesCount,
  }) {
    _presetRecord = null;
    contractsCount += contracts;
    totalValue += value;
    if (isoDate.compareTo(latestIsoDate) > 0) {
      latestIsoDate = isoDate;
    }
    if (entitiesCount > maxEntitiesCount) {
      maxEntitiesCount = entitiesCount;
    }
  }

  ContractorSummaryRecord buildRecord({
    required String Function(String, String) formatNit,
    required String Function(String) beautifyName,
    required String Function(String) buildInitials,
    required String Function(String) inferSector,
    required String Function(String) formatDate,
  }) {
    if (_presetRecord != null) return _presetRecord!;
    final displayName = beautifyName(rawName);
    final isJuridica = rawTipoDoc.toUpperCase().contains('NIT') ||
        rawName.toUpperCase().contains('S.A.S') ||
        rawName.toUpperCase().contains('SAS') ||
        rawName.toUpperCase().contains('LTDA') ||
        rawName.toUpperCase().contains('CONSORCIO') ||
        rawName.toUpperCase().contains('UNION TEMPORAL') ||
        rawName.toUpperCase().contains('FUNDACION') ||
        (digits.length >= 9 &&
            (digits.startsWith('8') || digits.startsWith('9')));

    final year = latestIsoDate.length >= 4
        ? latestIsoDate.substring(0, 4)
        : '2026';

    return ContractorSummaryRecord(
      initials: buildInitials(displayName),
      name: displayName,
      rawSearchName: rawName,
      nit: formatNit(rawTipoDoc, rawDoc),
      rawDocumentDigits: digits,
      personType: isJuridica ? 'Persona jurídica' : 'Persona natural',
      totalContracts: contractsCount,
      totalValue: totalValue,
      lastContractDate: formatDate(latestIsoDate),
      sector: inferSector('$rawName $combinedSectorText'),
      year: year,
      entitiesCount: maxEntitiesCount,
      sigepStatus: SigepRoleStatus.contratista,
    );
  }
}
