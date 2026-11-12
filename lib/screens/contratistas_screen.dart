import 'dart:async';

import 'package:flutter/material.dart';

import '../services/busqueda_personas.dart';
import '../widgets/directorio_sigep.dart';
import '../utils/app_scroll_behavior.dart';
import '../utils/csv_exporter.dart';
import '../widgets/user_profile_header_action.dart';
import 'perfil_contratista_screen.dart';
import '../tema/cristal.dart';

/// Estado de clasificación frente al cruce con SIGEP II.
enum SigepRoleStatus { verificando, servidorPublico, contratista }

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
    this.idSigep,
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

  /// Hoja de vida en el directorio del SIGEP.
  final String? idSigep;

  ContractorSummaryRecord copyWith({
    SigepRoleStatus? sigepStatus,
    String? sigepEntityCargo,
    String? idSigep,
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
      idSigep: idSigep ?? this.idSigep,
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

  /// Cuándo se guardó cada término; pasados [vigencia] se vuelve a consultar.
  static final Map<String, DateTime> termResultsTime = {};

  /// Términos cuya consulta no terminó o falló: se reintentan en la
  /// siguiente búsqueda en lugar de quedarse con la lista incompleta.
  static final Set<String> incompleteTerms = {};

  static const Duration vigencia = Duration(minutes: 12);

  static bool tieneVigente(String key) {
    final momento = termResultsTime[key];
    return termResultsCache.containsKey(key) &&
        !incompleteTerms.contains(key) &&
        momento != null &&
        DateTime.now().difference(momento) < vigencia;
  }
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
  static const int _pageSize = 5;
  static const int _maxBulkCombinations = 5;

  late final TextEditingController _searchController;
  Timer? _liveSearchDebounce;
  List<ContractorSummaryRecord> _contractors = [];
  List<String> _activeBulkTerms = const [];
  bool _isLoading = false;
  int _latestRequestId = 0;

  /// Aviso cuando alguna fuente no respondió (null: todo bien).
  String? _avisoBusqueda;

  String _sortBy = 'Mayor valor contratado';
  int _currentPage = 1;

  // Semilla inicial 100% verificada contra SECOP II (datos.gov.co)
  static const List<ContractorSummaryRecord> _initialSeedContractors = [
    ContractorSummaryRecord(
      initials: 'CV',
      name: 'Consorcio Vías del Cesar',
      rawSearchName: 'CONSORCIO VIAS DEL CESAR',
      nit: '901.541.760',
      rawDocumentDigits: '901541760',
      personType: 'Persona jurídica',
      totalContracts: 1,
      totalValue: 9533236406.48,
      lastContractDate: '31/12/2021',
      sector: 'Infraestructura vial',
      year: '2021',
      entitiesCount: 1,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'IO',
      name: 'Ingenierías y Obras MQ S.A.S.',
      rawSearchName: 'INGENIERIAS Y OBRAS MQ S.A.S',
      nit: '901.006.399-2',
      rawDocumentDigits: '901006399',
      personType: 'Persona jurídica',
      totalContracts: 1,
      totalValue: 261665045.88,
      lastContractDate: '09/10/2026',
      sector: 'Obras civiles',
      year: '2026',
      entitiesCount: 1,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'TS',
      name: 'Taico S.A.S.',
      rawSearchName: 'TAICO S.A.S.',
      nit: '901.037.937-4',
      rawDocumentDigits: '901037937',
      personType: 'Persona jurídica',
      totalContracts: 1,
      totalValue: 453721485.00,
      lastContractDate: '09/10/2026',
      sector: 'Deporte y recreación',
      year: '2026',
      entitiesCount: 1,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'SE',
      name: 'Sandra Milena Erazo Pulgarín',
      rawSearchName: 'SANDRA MILENA ERAZO PULGARIN',
      nit: '66.900.091',
      rawDocumentDigits: '66900091',
      personType: 'Persona natural',
      totalContracts: 21,
      totalValue: 445261981.00,
      lastContractDate: '17/10/2026',
      sector: 'Ambiente y servicios',
      year: '2026',
      entitiesCount: 1,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'DP',
      name: 'Daniel Puentes',
      rawSearchName: 'DANIEL PUENTES',
      nit: '1.098.821.514',
      rawDocumentDigits: '1098821514',
      personType: 'Persona natural',
      totalContracts: 10,
      totalValue: 102173333.00,
      lastContractDate: '17/10/2026',
      sector: 'Seguridad y servicios',
      year: '2026',
      entitiesCount: 3,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'SE',
      name: 'Seguros del Estado S.A.',
      rawSearchName: 'SEGUROS DEL ESTADO S.A.',
      nit: '860.009.578-0',
      rawDocumentDigits: '860009578',
      personType: 'Persona jurídica',
      totalContracts: 880,
      totalValue: 170572348852.91,
      lastContractDate: '15/10/2026',
      sector: 'Seguros y pólizas estatales',
      year: '2026',
      entitiesCount: 331,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'BC',
      name: 'Bancolombia S.A.',
      rawSearchName: 'BANCOLOMBIA',
      nit: '890.903.938-8',
      rawDocumentDigits: '890903938',
      personType: 'Persona jurídica',
      totalContracts: 219,
      totalValue: 5371612705366.02,
      lastContractDate: '20/10/2026',
      sector: 'Servicios financieros y crédito',
      year: '2026',
      entitiesCount: 121,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'CL',
      name: 'COMCEL S.A. (Claro)',
      rawSearchName: 'COMCEL S.A.',
      nit: '800.153.993-7',
      rawDocumentDigits: '800153993',
      personType: 'Persona jurídica',
      totalContracts: 221,
      totalValue: 1644976022240.18,
      lastContractDate: '09/10/2026',
      sector: 'Telecomunicaciones y conectividad',
      year: '2026',
      entitiesCount: 88,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'PS',
      name: 'Positiva Compañía de Seguros S.A.',
      rawSearchName: 'POSITIVA COMPAÑIA DE SEGUROS S.A',
      nit: '860.011.153-6',
      rawDocumentDigits: '860011153',
      personType: 'Persona jurídica',
      totalContracts: 347,
      totalValue: 304335987647.36,
      lastContractDate: '14/10/2026',
      sector: 'Seguros laborales y salud',
      year: '2026',
      entitiesCount: 162,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'ET',
      name: 'Empresa de Telecomunicaciones de Bogotá (ETB)',
      rawSearchName: 'ETB SA ESP',
      nit: '899.999.115-8',
      rawDocumentDigits: '899999115',
      personType: 'Persona jurídica',
      totalContracts: 787,
      totalValue: 3107364400561.47,
      lastContractDate: '15/10/2026',
      sector: 'Telecomunicaciones y conectividad',
      year: '2026',
      entitiesCount: 150,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'SP',
      name: 'Servicios Postales Nacionales S.A.S. (4-72)',
      rawSearchName: 'SERVICIOS POSTALES NACIONALES S.A.S',
      nit: '900.062.917-9',
      rawDocumentDigits: '900062917',
      personType: 'Persona jurídica',
      totalContracts: 2391,
      totalValue: 2032997706204.07,
      lastContractDate: '19/10/2026',
      sector: 'Logística y correspondencia estatal',
      year: '2026',
      entitiesCount: 621,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'FD',
      name: 'Financiera de Desarrollo Territorial S.A. (FINDETER)',
      rawSearchName: 'FINANCIERA DE DESARROLLO TERRITORIAL S.A.',
      nit: '800.096.329-7',
      rawDocumentDigits: '800096329',
      personType: 'Persona jurídica',
      totalContracts: 259,
      totalValue: 9188302307404.87,
      lastContractDate: '06/03/2026',
      sector: 'Banca y desarrollo territorial',
      year: '2026',
      entitiesCount: 135,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'UA',
      name: 'Universidad de Antioquia',
      rawSearchName: 'UNIVERSIDAD DE ANTIOQUIA',
      nit: '890.980.040-8',
      rawDocumentDigits: '890980040',
      personType: 'Persona jurídica',
      totalContracts: 1236,
      totalValue: 2235468942774.55,
      lastContractDate: '13/10/2026',
      sector: 'Educación superior e investigación',
      year: '2026',
      entitiesCount: 145,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'BB',
      name: 'Banco Bilbao Vizcaya Argentaria (BBVA Colombia)',
      rawSearchName: 'BANCO BILBAO VIZCAYA ARGENTARIA S.A. (OFICIAL)',
      nit: '860.003.020-1',
      rawDocumentDigits: '860003020',
      personType: 'Persona jurídica',
      totalContracts: 212,
      totalValue: 2626175624131.86,
      lastContractDate: '08/10/2026',
      sector: 'Banca y servicios financieros',
      year: '2026',
      entitiesCount: 79,
      sigepStatus: SigepRoleStatus.contratista,
    ),
    ContractorSummaryRecord(
      initials: 'MS',
      name: 'ESE Metrosalud',
      rawSearchName: 'ESE METROSALUD',
      nit: '800.058.016-0',
      rawDocumentDigits: '800058016',
      personType: 'Persona jurídica',
      totalContracts: 223,
      totalValue: 1766348078094.00,
      lastContractDate: '16/10/2026',
      sector: 'Salud pública hospitalaria',
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
    final clean = term.trim();
    if (RegExp(r'^[0-9.\-\s]+$').hasMatch(clean)) {
      final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        return 'DOC:$digits';
      }
    }
    return 'TXT:${_normalizar(clean).replaceAll(RegExp(r'\s+'), ' ')}';
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
        // tanto de la semilla inicial como de resultados previamente cacheados en memoria.
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
        for (final cachedList
            in _ContratistasPersistenceStore.termResultsCache.values) {
          for (final cachedItem in cachedList) {
            if (_matchesSingleTerm(cachedItem, term)) {
              final uniqueId = cachedItem.rawDocumentDigits.isNotEmpty
                  ? cachedItem.rawDocumentDigits
                  : _normalizar(cachedItem.rawSearchName);
              if (seenKeys.add(uniqueId)) {
                combined.add(cachedItem);
              }
            }
          }
        }
      }
    }
    return combined;
  }

  /// Se invoca tanto al escribir en tiempo real (desde la primera letra o dígito)
  /// como al presionar "Buscar" o borrar una combinación.
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

    // Recálculo instantáneo con lo que ya esté en caché (por ejemplo al borrar 1 de las 5 combinaciones)
    final missingTerms = terms
        .where(
          (t) => !_ContratistasPersistenceStore.tieneVigente(_termCacheKey(t)),
        )
        .toList();

    final immediateCombined = _combineCachedTerms(terms);
    setState(() {
      _activeBulkTerms = terms;
      _currentPage = 1;
      _ContratistasPersistenceStore.hasExecutedCustomSearch = true;
      _contractors = immediateCombined;
      _isLoading = missingTerms.isNotEmpty;
      if (missingTerms.isEmpty) _avisoBusqueda = null;
    });
    _syncStateToPersistenceStore();

    if (missingTerms.isEmpty) {
      return;
    }

    // Consulta en tiempo real desde la primera letra o el primer dígito escrito
    final queryableMissing = missingTerms.where((t) {
      final d = t.replaceAll(RegExp(r'[^0-9]'), '');
      final norm = _normalizar(t).replaceAll(RegExp(r'[^A-Z0-9]'), '');
      return d.isNotEmpty || norm.isNotEmpty;
    }).toList();

    if (queryableMissing.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final int requestId = ++_latestRequestId;
    // Espera a que el usuario haga una pausa al escribir: evita una consulta
    // por cada letra (las respuestas viejas igual se descartan).
    _liveSearchDebounce = Timer(const Duration(milliseconds: 320), () {
      _runFastSocrataBulkQuery(
        allTerms: terms,
        termsToFetch: queryableMissing,
        requestId: requestId,
      );
    });
  }

  /// Consulta cada término en SECOP II, SECOP I y las fuentes abiertas de
  /// servidores públicos ([BusquedaPersonas]), todos en paralelo. La tabla
  /// se actualiza cada vez que responde una fuente; las respuestas de una
  /// búsqueda anterior se descartan.
  ///
  /// Un término solo queda en caché si la consulta terminó y al menos una
  /// fuente de contratos respondió: una falla nunca se guarda como "sin
  /// resultados" (se reintenta en la siguiente búsqueda y se avisa).
  Future<void> _runFastSocrataBulkQuery({
    required List<String> allTerms,
    required List<String> termsToFetch,
    required int requestId,
  }) async {
    final fallidas = <FuentePersona>{};
    var fallaTotal = false;

    await Future.wait(
      termsToFetch.map((term) async {
        final key = _termCacheKey(term);
        try {
          await for (final r in BusquedaPersonas.buscarProgresivo(term)) {
            if (!mounted || requestId != _latestRequestId) return;
            final records = _selectBestMatchesForTerm(
              r.personas.map(_recordFromPersona).toList(),
              term,
              alreadyFiltered: true,
            );
            final store = _ContratistasPersistenceStore.termResultsCache;
            // Mientras faltan fuentes, no se pisa un resultado completo
            // anterior con uno parcial más corto.
            if (r.completo || records.length >= (store[key]?.length ?? 0)) {
              store[key] = records;
            }
            if (r.completo) {
              fallidas.addAll(r.fuentesFallidas);
              if (r.fallo) fallaTotal = true;
              // Si alguna fuente no respondió, el resultado se muestra pero
              // no se guarda: la siguiente búsqueda vuelve a consultar.
              if (r.parcial) {
                _ContratistasPersistenceStore.incompleteTerms.add(key);
              } else {
                _ContratistasPersistenceStore.incompleteTerms.remove(key);
                _ContratistasPersistenceStore.termResultsTime[key] =
                    DateTime.now();
              }
            } else {
              _ContratistasPersistenceStore.incompleteTerms.add(key);
            }
            setState(() => _contractors = _combineCachedTerms(allTerms));
          }
        } catch (_) {
          fallaTotal = true;
          _ContratistasPersistenceStore.incompleteTerms.add(key);
        }
      }),
    );

    if (!mounted || requestId != _latestRequestId) return;
    setState(() {
      _contractors = _combineCachedTerms(allTerms);
      _isLoading = false;
      _currentPage = 1;
      _avisoBusqueda = fallaTotal
          ? 'SECOP no respondió a tiempo. Los resultados pueden estar '
                'incompletos.'
          : fallidas.isEmpty
          ? null
          : '${_nombresFuentes(fallidas)} no respondió a tiempo; los '
                'resultados pueden estar incompletos.';
    });
    _syncStateToPersistenceStore();
  }

  static String _nombresFuentes(Set<FuentePersona> fuentes) => fuentes
      .map(
        (f) => switch (f) {
          FuentePersona.secopII => 'SECOP II',
          FuentePersona.secopI => 'SECOP I',
          FuentePersona.servidores => 'La fuente de servidores públicos',
          FuentePersona.sigep => 'El directorio del SIGEP',
        },
      )
      .join(' y ');

  /// Vuelve a consultar los términos activos sin usar la caché.
  void _reintentarBusqueda() {
    for (final term in _activeBulkTerms) {
      _ContratistasPersistenceStore.incompleteTerms.add(_termCacheKey(term));
    }
    _executeBulkSearch();
  }

  ContractorSummaryRecord _recordFromPersona(PersonaEncontrada p) {
    final acc = _ContractorAccumulator(
      rawName: p.nombre,
      rawDoc: p.documento,
      rawTipoDoc: p.tipoDocumento,
      digits: p.documento,
    );
    if (p.contratos > 0) {
      acc.addAggregatedGroup(
        contracts: p.contratos,
        value: p.valor,
        isoDate: p.ultimaFecha,
        entitiesCount: p.entidades,
      );
    }
    final record = acc.buildRecord(
      formatNit: _formatDocument,
      beautifyName: _beautifyName,
      buildInitials: _computeInitials,
      inferSector: _inferSector,
      formatDate: _formatIsoToDdMmYyyy,
    );
    return record.copyWith(
      sigepStatus: p.servidorPublico ? SigepRoleStatus.servidorPublico : null,
      sigepEntityCargo:
          p.cargoEntidad ?? (p.servidorPublico ? 'Servidor público' : null),
      idSigep: p.idSigep,
    );
  }

  List<ContractorSummaryRecord> _selectBestMatchesForTerm(
    List<ContractorSummaryRecord> candidates,
    String term, {
    bool alreadyFiltered = false,
  }) {
    final tDigits = term.replaceAll(RegExp(r'[^0-9]'), '');
    final tNorm = _normalizar(term).replaceAll(RegExp(r'\s+'), ' ').trim();
    final matching = alreadyFiltered
        ? List<ContractorSummaryRecord>.of(candidates)
        : candidates.where((c) => _matchesSingleTerm(c, term)).toList();

    if (tDigits.length >= 6 && RegExp(r'^[0-9.\-\s]+$').hasMatch(term)) {
      final base9 =
          (tDigits.length == 10 &&
              (tDigits.startsWith('8') || tDigits.startsWith('9')))
          ? tDigits.substring(0, 9)
          : tDigits;

      final exactMatches = matching.where((c) {
        final cDigits = c.rawDocumentDigits;
        final cBase9 =
            (cDigits.length == 10 &&
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
      if (tDigits.isNotEmpty && RegExp(r'^[0-9.\-\s]+$').hasMatch(term)) {
        final aExact = a.rawDocumentDigits == tDigits ? 0 : 1;
        final bExact = b.rawDocumentDigits == tDigits ? 0 : 1;
        if (aExact != bExact) return aExact.compareTo(bExact);
      } else if (tNorm.isNotEmpty) {
        final aName = _normalizar(a.rawSearchName);
        final bName = _normalizar(b.rawSearchName);
        final aStarts = aName.startsWith(tNorm) ? 0 : 1;
        final bStarts = bName.startsWith(tNorm) ? 0 : 1;
        if (aStarts != bStarts) return aStarts.compareTo(bStarts);
      }
      return b.totalValue.compareTo(a.totalValue);
    });
    return matching;
  }

  bool _matchesSingleTerm(ContractorSummaryRecord record, String term) {
    final tNorm = _normalizar(term).replaceAll(RegExp(r'\s+'), ' ').trim();
    final tDigits = term.replaceAll(RegExp(r'[^0-9]'), '');
    final cDigits = record.rawDocumentDigits.isNotEmpty
        ? record.rawDocumentDigits
        : record.nit.replaceAll(RegExp(r'[^0-9]'), '');

    if (tDigits.isNotEmpty && RegExp(r'^[0-9.\-\s]+$').hasMatch(term)) {
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
      // Coincidencia por palabras (Nombre + Apellido, ej. "Sandra Erazo" en "Sandra Milena Erazo Pulgarín")
      final words = tNorm.split(' ').where((w) => w.isNotEmpty).toList();
      if (words.isNotEmpty &&
          words.every((w) => normName.contains(w) || normRaw.contains(w))) {
        return true;
      }
    }
    return false;
  }

  bool _matchesAnyBulkTerm(ContractorSummaryRecord record, List<String> terms) {
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
      _avisoBusqueda = null;
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
          nit: contractor.nit,
          documentoProveedor: contractor.rawDocumentDigits,
          totalContractsSeed: contractor.totalContracts,
          totalValueSeed: contractor.totalValue,
          idSigep: contractor.idSigep,
          servidorPublico:
              contractor.sigepStatus == SigepRoleStatus.servidorPublico,
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
    final isJuridica =
        tipoDoc.toUpperCase().contains('NIT') ||
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
    return 'Sin fecha';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filteredAndSortedContractors;
    final bool isDefaultView =
        !_ContratistasPersistenceStore.hasExecutedCustomSearch &&
        _activeBulkTerms.isEmpty;

    final String totalContratistasKpi = isDefaultView
        ? '+280.000'
        : '${filtered.length}';
    final int sumContracts = filtered.fold<int>(
      0,
      (sum, item) => sum + item.totalContracts,
    );
    final String totalContratosKpi = isDefaultView ? '+4.5M' : '$sumContracts';
    final double sumValue = filtered.fold<double>(
      0,
      (sum, item) => sum + item.totalValue,
    );
    final String valorContratadoKpi = isDefaultView
        ? '+\$850 Billones'
        : _formatShortMillionsKpi(sumValue);
    final int sumEntities = filtered.fold<int>(
      0,
      (sum, item) => sum + item.entitiesCount,
    );
    final String entidadesKpi = isDefaultView ? '+3.200' : '$sumEntities';

    final int totalDisplayCount = filtered.length;
    final int totalPages = filtered.isEmpty
        ? 1
        : (filtered.length / _pageSize).ceil();
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

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final double horizontalPad = constraints.maxWidth > 1200
            ? 32.0
            : (isMobile ? 14.0 : 22.0);
        return SingleChildScrollView(
          child: Stack(
            children: [
              // Fondo panorámico superior idéntico al mockup
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 210,
                child: FotoAmbiente.cabecera(),
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
                      titleColor: Cristal.texto,
                      accentColor: Cristal.dorado,
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
                      isDefaultView: isDefaultView,
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
                      aviso: _avisoBusqueda,
                      onRetry: _reintentarBusqueda,
                      terminoSigep: isDefaultView
                          ? null
                          : _activeBulkTerms
                                .where((t) => !BusquedaPersonas.esDocumento(t))
                                .firstOrNull,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.isEmbeddedInDashboard) {
      return Expanded(child: content);
    }

    return Scaffold(backgroundColor: Colors.transparent, body: content);
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
    final isMobile = MediaQuery.sizeOf(context).width < 768;
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
                  color: Cristal.textoMedio,
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
            color: Cristal.vidrioFuerte,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Cristal.borde),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: Cristal.texto),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Búsqueda en tiempo real: escribe nombre y apellido, razón social, cédula o NIT (hasta 5 separados por coma)',
                      style: TextStyle(
                        color: Cristal.texto,
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
                    color: Cristal.acentoVidrio,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${activeBulkTerms.length}/5 combinaciones activas',
                    style: const TextStyle(
                      color: Cristal.texto,
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
                    color: Cristal.rojoVidrio,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Cristal.rojoBorde),
                  ),
                  child: const Text(
                    'Máximo 5 combinaciones permitidas (mostrando las primeras 5)',
                    style: TextStyle(
                      color: Cristal.rojo,
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
            color: Cristal.vidrio,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Cristal.borde),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Cristal.texto, size: 21),
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
                        color: Cristal.texto,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Escribe nombre y apellido, NIT o cédula (ej: Sandra Erazo, Daniel Puentes, 1065842391, hasta 5 por coma)...',
                        hintStyle: const TextStyle(
                          color: Cristal.textoTenue,
                          fontSize: 13,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        isDense: true,
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Borrar búsqueda',
                                onPressed: onClearSearch,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Cristal.textoSuave,
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
                    backgroundColor: Cristal.acento,
                    foregroundColor: Cristal.texto,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                            color: Cristal.texto,
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
                    color: Cristal.vidrio,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Cristal.bordeFuerte),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Cristal.acento,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Cristal.texto,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        activeBulkTerms[i],
                        style: const TextStyle(
                          color: Cristal.texto,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        hoverDuration: Cristal.micro,
                        onTap: () => _removeTermAtIndex(i),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: Cristal.textoSuave,
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
        color: Cristal.vidrio,
        borderRadius: BorderRadius.circular(16),
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
                    color: Cristal.textoSuave,
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
                      color: Cristal.texto,
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
        iconColor: Cristal.acentoClaro,
        iconBg: Cristal.vidrioSuave,
        label: 'Total contratistas',
        value: totalContratistas,
      ),
      _buildCardContent(
        icon: Icons.description_rounded,
        iconColor: Cristal.acentoClaro,
        iconBg: Cristal.vidrioSuave,
        label: 'Total contratos',
        value: totalContratos,
      ),
      _buildCardContent(
        icon: Icons.monetization_on_rounded,
        iconColor: Cristal.verde,
        iconBg: Cristal.verdeVidrio,
        label: 'Valor contratado',
        value: valorContratado,
      ),
      _buildCardContent(
        icon: Icons.account_balance_rounded,
        iconColor: const Color(0xFFA78BFA),
        iconBg: const Color(0x1F8B5CF6),
        label: 'Entidades que contratan',
        value: entidadesCount,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 920) {
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
        return HorizontalWebScroll(
          child: Row(
            children: [
              SizedBox(width: 242, child: cards[0]),
              const SizedBox(width: 12),
              SizedBox(width: 242, child: cards[1]),
              const SizedBox(width: 12),
              SizedBox(width: 242, child: cards[2]),
              const SizedBox(width: 12),
              SizedBox(width: 242, child: cards[3]),
            ],
          ),
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
    this.isDefaultView = false,
    required this.onSortChanged,
    required this.onPageChanged,
    required this.onOpenProfile,
    required this.onExportPressed,
    required this.formatCurrency,
    this.aviso,
    this.onRetry,
    this.terminoSigep,
  });

  final List<ContractorSummaryRecord> rows;
  final int totalFoundCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final String sortBy;
  final bool isLoading;
  final bool isDefaultView;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<ContractorSummaryRecord> onOpenProfile;
  final VoidCallback onExportPressed;
  final String Function(double) formatCurrency;

  /// Alguna fuente no respondió: se avisa en lugar de callar.
  final String? aviso;
  final VoidCallback? onRetry;

  /// Nombre buscado (búsquedas por nombre): se ofrece buscarlo en el
  /// directorio del SIGEP, que tiene a todos los servidores públicos.
  final String? terminoSigep;

  Widget _notaServidores(BuildContext context, String termino) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Cristal.vidrioSuave,
        borderRadius: BorderRadius.circular(Cristal.radioCampo),
        border: Border.all(color: Cristal.borde),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: const Text(
              '¿Buscas a un servidor público que no aparece? Datos Abiertos solo '
              'publica con nombre a los de alto nivel y a quienes declaran bienes '
              'y rentas. Todos los demás están en el directorio del SIGEP de '
              'Función Pública: el botón abre ahí la misma búsqueda.',
              style: TextStyle(
                color: Cristal.textoMedio,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => DirectorioSigep.buscar(context, termino),
            icon: const Icon(Icons.travel_explore_rounded, size: 18),
            label: Text('Buscar "$termino" en el SIGEP'),
          ),
        ],
      ),
    );
  }

  static const TextStyle _headerColStyle = TextStyle(
    color: Cristal.textoCuerpo,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    final int startItem = totalFoundCount == 0
        ? 0
        : ((currentPage - 1) * pageSize) + 1;
    final int endItem = totalFoundCount == 0
        ? 0
        : (startItem + rows.length - 1).clamp(1, totalFoundCount);

    return Container(
      decoration: BoxDecoration(
        color: Cristal.vidrio,
        borderRadius: BorderRadius.circular(18),
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
                    Text(
                      isDefaultView
                          ? 'Contratistas representativos en SECOP II'
                          : 'Resultados de contratistas',
                      style: const TextStyle(
                        color: Cristal.texto,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLoading
                          ? 'Consultando SECOP II en tiempo real...'
                          : isDefaultView
                          ? 'Mostrando $totalFoundCount contratistas verificados a nivel nacional (ingresa NIT o razón social para buscar cualquier otro)'
                          : '$totalFoundCount contratistas encontrados para la consulta',
                      style: const TextStyle(
                        color: Cristal.textoSuave,
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
                        color: Cristal.textoSuave,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Cristal.vidrioSuave,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Cristal.borde),
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
                              color: Cristal.texto,
                            ),
                          ),
                          style: const TextStyle(
                            color: Cristal.texto,
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
                      hoverDuration: Cristal.micro,
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
                              color: Cristal.texto,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Exportar',
                              style: TextStyle(
                                color: Cristal.texto,
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
              color: Cristal.acentoClaro,
              backgroundColor: Cristal.vidrioFuerte,
            ),
          if (aviso != null && !isLoading)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: Cristal.ambarVidrio,
                borderRadius: BorderRadius.circular(Cristal.radioCampo),
                border: Border.all(color: Cristal.ambarBorde),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Cristal.ambar,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      aviso!,
                      style: const TextStyle(
                        color: Cristal.textoCuerpo,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onRetry != null)
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Reintentar'),
                    ),
                ],
              ),
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
                      color: Cristal.vidrioSuave,
                      border: Border(
                        top: BorderSide(color: Cristal.borde),
                        bottom: BorderSide(color: Cristal.borde),
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
                          child: Text(
                            'Tipo de persona',
                            style: _headerColStyle,
                          ),
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
                            color: Cristal.textoSuave,
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
                  if (terminoSigep != null)
                    _notaServidores(context, terminoSigep!),
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
                    color: Cristal.textoSuave,
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
        border: Border(bottom: BorderSide(color: Cristal.borde)),
      ),
      child: Row(
        children: [
          // 1. #
          SizedBox(
            width: 34,
            child: Text(
              '$rowNumber',
              style: const TextStyle(
                color: Cristal.textoMedio,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 2. Contratista / Razón social
          Expanded(
            flex: 32,
            child: InkWell(
              hoverDuration: Cristal.micro,
              onTap: () => onOpenProfile(record),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Cristal.acentoVidrio,
                    child: Text(
                      record.initials,
                      style: const TextStyle(
                        color: Cristal.texto,
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
                        color: Cristal.acentoClaro,
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
                color: Cristal.textoMedio,
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
                          ? Cristal.azulVidrio
                          : Cristal.doradoVidrio,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      record.personType,
                      style: TextStyle(
                        color: isJuridica ? Cristal.acentoClaro : Cristal.ambar,
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
                            ? Cristal.rojoVidrio
                            : Cristal.verdeVidrio,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isServidorPublico
                              ? Cristal.rojoBorde
                              : Cristal.verdeBorde,
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
                                ? Cristal.rojo
                                : Cristal.verde,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isServidorPublico
                                ? 'Servidor Público'
                                : 'Contratista',
                            style: TextStyle(
                              color: isServidorPublico
                                  ? Cristal.rojo
                                  : Cristal.verde,
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
                color: Cristal.texto,
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
                color: Cristal.texto,
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
                color: Cristal.textoMedio,
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
                hoverDuration: Cristal.micro,
                onTap: () => onOpenProfile(record),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Cristal.vidrioSuave,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver perfil',
                        style: TextStyle(
                          color: Cristal.acentoClaro,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Cristal.acentoClaro,
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
        hoverDuration: Cristal.micro,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 32),
          height: 32,
          margin: const EdgeInsets.only(left: 5),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Cristal.acento : Cristal.vidrio,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Cristal.acentoClaro : Cristal.borde,
            ),
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: 17,
                  color: onTap != null ? Cristal.texto : Cristal.textoApagado,
                )
              : Text(
                  label ?? '',
                  style: TextStyle(
                    color: selected ? Cristal.texto : Cristal.texto,
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
              color: Cristal.textoSuave,
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

  final String rawName;
  final String rawDoc;
  final String rawTipoDoc;
  final String digits;

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
    final displayName = beautifyName(rawName);
    final isJuridica =
        rawTipoDoc.toUpperCase().contains('NIT') ||
        rawName.toUpperCase().contains('S.A.S') ||
        rawName.toUpperCase().contains('SAS') ||
        rawName.toUpperCase().contains('LTDA') ||
        rawName.toUpperCase().contains('CONSORCIO') ||
        rawName.toUpperCase().contains('UNION TEMPORAL') ||
        rawName.toUpperCase().contains('FUNDACION') ||
        (digits.length >= 9 &&
            (digits.startsWith('8') || digits.startsWith('9')));

    final year = latestIsoDate.length >= 4 ? latestIsoDate.substring(0, 4) : '';

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
