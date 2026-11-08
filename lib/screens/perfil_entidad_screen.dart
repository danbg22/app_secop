import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/reporte_contratos_modelo.dart';
import '../services/reporte_contratos_service.dart';
import '../utils/anios_secop.dart';
import '../widgets/presupuesto_dependencias_panel.dart';
import '../widgets/reporte_contratos_flujo.dart';
import 'detalle_screen.dart';
import 'perfil_contratista_screen.dart';
import 'sections/entidades_section.dart';

class PerfilEntidadScreen extends StatefulWidget {
  const PerfilEntidadScreen({super.key, required this.entity});

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

/// Unidad de contratación real de la entidad en SECOP II: cada cuenta
/// compradora (`nombre_entidad`) registrada con el mismo NIT, p. ej. las
/// regionales, centros y grupos de apoyo del SENA.
class _UnidadContratante {
  const _UnidadContratante({
    required this.nombre,
    required this.departamento,
    required this.contractsCount,
    required this.totalCop,
  });

  final String nombre;
  final String departamento;
  final int contractsCount;
  final double totalCop;
}

/// Dependencia interna inferida del objeto del contrato. SECOP II no publica
/// la dependencia que contrata, así que cada contrato se asigna a la primera
/// cuyas palabras clave aparecen en su objeto (orden de [_dependenciasInternas]);
/// la última recoge el resto. Así cada contrato cuenta una sola vez y los
/// totales cuadran con los de la entidad. En las palabras, `_` es comodín de
/// una letra para coincidir con o sin tilde.
class _DependenciaInterna {
  const _DependenciaInterna({
    required this.id,
    required this.nombreNacional,
    required this.nombreTerritorial,
    required this.macroproceso,
    required this.icon,
    required this.color,
    required this.bg,
    required this.palabras,
  });

  final String id;
  final String nombreNacional;
  final String nombreTerritorial;
  final String macroproceso;
  final IconData icon;
  final Color color;
  final Color bg;
  final List<String> palabras;
}

const List<String> _macroprocesos = [
  'Estratégicos y de dirección',
  'Misionales',
  'De apoyo',
  'Evaluación y control',
];

const List<_DependenciaInterna> _dependenciasInternas = [
  _DependenciaInterna(
    id: 'planeacion',
    nombreNacional: 'Oficina de Planeación y Direccionamiento',
    nombreTerritorial: 'Oficina de Planeación y Direccionamiento',
    macroproceso: 'Estratégicos y de dirección',
    icon: Icons.account_tree_rounded,
    color: Color(0xFF0369A1),
    bg: Color(0xFFE0F2FE),
    palabras: [
      'PLANEAC',
      'ESTAD_STIC',
      'DIRECCIONAMIENTO',
      'CALIDAD',
      'PROYECTO DE INVERSI_N',
    ],
  ),
  _DependenciaInterna(
    id: 'despacho',
    nombreNacional: 'Despacho de Dirección General / Regional',
    nombreTerritorial: 'Despacho del Alcalde / Gobernador',
    macroproceso: 'Estratégicos y de dirección',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF1E3A8A),
    bg: Color(0xFFDBEAFE),
    palabras: [
      'DESPACHO',
      'DIRECCI_N REGIONAL',
      'DIRECCI_N GENERAL',
      'COMUNICACI_N',
      'RELACIONES CORPORATIVAS',
    ],
  ),
  _DependenciaInterna(
    id: 'control',
    nombreNacional: 'Control Interno y Supervisión',
    nombreTerritorial: 'Control Interno y Supervisión',
    macroproceso: 'Evaluación y control',
    icon: Icons.verified_user_outlined,
    color: Color(0xFFB45309),
    bg: Color(0xFFFEF3C7),
    palabras: ['INTERVENTOR', 'SUPERVIS', 'AUDITOR', 'CONTROL INTERNO'],
  ),
  _DependenciaInterna(
    id: 'infraestructura',
    nombreNacional: 'Infraestructura Física y Obras',
    nombreTerritorial: 'Secretaría de Infraestructura y Obras',
    macroproceso: 'Misionales',
    icon: Icons.engineering_rounded,
    color: Color(0xFFD97706),
    bg: Color(0xFFFEF3C7),
    palabras: [
      'OBRA',
      'VIAL',
      'INFRAESTRUCTURA',
      'MANTENIMIENTO',
      'ADECUACI_N',
      'CONSTRUCCI_N',
    ],
  ),
  _DependenciaInterna(
    id: 'social',
    nombreNacional: 'Desarrollo Social, Salud y Bienestar',
    nombreTerritorial: 'Desarrollo Social, Salud y Bienestar',
    macroproceso: 'Misionales',
    icon: Icons.health_and_safety_rounded,
    color: Color(0xFF0284C7),
    bg: Color(0xFFE0F2FE),
    palabras: [
      'SALUD',
      'HOSPITAL',
      'M_DIC',
      'BIENESTAR',
      'PSICOLOG',
      'SOCIAL',
      'DEPORT',
    ],
  ),
  _DependenciaInterna(
    id: 'financiera',
    nombreNacional: 'Dirección Financiera y Presupuesto',
    nombreTerritorial: 'Secretaría de Hacienda',
    macroproceso: 'De apoyo',
    icon: Icons.receipt_long_outlined,
    color: Color(0xFF047857),
    bg: Color(0xFFD1FAE5),
    palabras: [
      'HACIENDA',
      'FINANC',
      'CONTABL',
      'TRIBUT',
      'TESORER',
      'PRESUPUEST',
    ],
  ),
  _DependenciaInterna(
    id: 'tic',
    nombreNacional: 'Tecnologías de la Información (TIC)',
    nombreTerritorial: 'Tecnologías de la Información (TIC)',
    macroproceso: 'De apoyo',
    icon: Icons.computer_rounded,
    color: Color(0xFF0F766E),
    bg: Color(0xFFCCFBF1),
    palabras: [
      'SISTEMA',
      'SOFTWARE',
      'TECNOLOG',
      'INFORM_TIC',
      'COMPUT',
      'CONECTIVIDAD',
    ],
  ),
  _DependenciaInterna(
    id: 'juridica',
    nombreNacional: 'Oficina Jurídica y Contratación',
    nombreTerritorial: 'Oficina Jurídica y Contratación',
    macroproceso: 'De apoyo',
    icon: Icons.gavel_rounded,
    color: Color(0xFF6D28D9),
    bg: Color(0xFFEDE9FE),
    palabras: ['JUR_DIC', 'ABOGAD', 'JUDICIAL', 'DEFENSA'],
  ),
  _DependenciaInterna(
    id: 'misional',
    nombreNacional: 'Formación y Ejecución Misional',
    nombreTerritorial: 'Secretaría de Educación y Cultura',
    macroproceso: 'Misionales',
    icon: Icons.school_rounded,
    color: Color(0xFF15803D),
    bg: Color(0xFFDCFCE7),
    palabras: [
      'EDUCACI',
      'ESCOLAR',
      'COLEGIO',
      'FORMACI',
      'INSTRUCTOR',
      'APRENDIZ',
      'PEDAG_G',
      'MISIONAL',
    ],
  ),
  _DependenciaInterna(
    id: 'apoyo',
    nombreNacional: 'Secretaría General y Apoyo Administrativo',
    nombreTerritorial: 'Secretaría General y Gestión Administrativa',
    macroproceso: 'De apoyo',
    icon: Icons.business_center_outlined,
    color: Color(0xFF475569),
    bg: Color(0xFFF1F5F9),
    palabras: [],
  ),
];

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

// Clases auxiliares sin `const` para compatibilidad total con Hot Reload
class _RegionalBreakdownItem {
  _RegionalBreakdownItem({
    required this.departmentRaw,
    required this.label,
    required this.contractsCount,
    required this.totalCop,
  });

  final String departmentRaw;
  final String label;
  final int contractsCount;
  final double totalCop;
}

class _PerfilEntidadScreenState extends State<PerfilEntidadScreen> {
  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _azulPrimario = Color(0xFF1D4ED8);
  static const Color _bgCrema = Color(0xFFFAF5EA);

  int _selectedTabIndex =
      0; // 0: Resumen, 1: Contratos, 2: Dependencias, 3: Contratistas
  bool _isFollowing = false;
  bool _isLoadingLive = true;
  bool _isLoadingContractsPage = false;

  // Vigencia anualizada (2026 por defecto; soporta 2015 a 2026 o historial completo)
  bool _onlyCurrentYear2026 = true;
  int _activeBudgetYear = AniosSecop.actual;
  int? _selectedContratosYear = AniosSecop.actual;
  static List<int> get _aniosDisponibles => AniosSecop.disponibles;

  // Selector de Regional / Seccional Territorial (null = Consolidado Nacional / Total Entidad)
  String? _selectedRegionalDept;
  List<_RegionalBreakdownItem> _regionalStats = [];

  // Métricas dinámicas anualizadas (Vigencia 2026) actualizadas en cada consulta
  double _presupuestoTotalCop = 0;
  double _ejecutadoCop = 0;
  double _disponibleCop = 0;
  int _porcentajeEjecutado = 0;

  int _totalContratos = 0;
  double _valorTotalContratadoCop = 0;
  int _contratistasUnicos = 0;
  String _nitEntidad = '800.098.123-4';
  String _ordenEntidad = 'Territorial';

  // Listas procesadas desde la consulta en vivo a SECOP II
  List<Map<String, dynamic>> _entityContracts = [];
  List<Map<String, dynamic>> _pagedContractsList = [];
  int _totalMatchingContractsForTable = 0;
  double _totalMatchingCopForTable = 0;

  List<_ModalityStat> _modalityStats = [];
  List<_UnidadContratante> _unidades = [];
  List<_ContractorSummary> _contractorsList = [];

  // Estado de navegación interna en las pestañas
  String _selectedModality = 'Todas';
  int _contractsPage = 1;
  static const int _contractsPageSize = 8;

  // Explorador de contratos. La búsqueda recorre toda la entidad (todas las
  // vigencias) e ignora regional, unidad y modalidad; elegir cualquiera de
  // esos filtros cancela la búsqueda.
  String? _selectedUnidad;
  String? _selectedDependencia;
  // Conteo real por dependencia interna: id -> (contratos, valor).
  Map<String, (int, double)> _conteoDependencias = {};
  // 0: presupuesto por dependencia, 1: por área temática, 2: cuentas SECOP II.
  int _vistaDependencias = 0;
  bool _cargandoDependencias = false;
  int _dependenciasRequestId = 0;
  String _busqueda = '';
  final TextEditingController _busquedaController = TextEditingController();
  bool _filtrosExpandidos = false;
  String _filtroUnidades = '';
  int _contratosRequestId = 0;
  bool _generandoReporte = false;

  int _contractorsPage = 1;
  static const int _contractorsPageSize = 8;

  @override
  void initState() {
    super.initState();
    _initBaselineMetrics();
    _detectInitialRegionalFromEntityCard();
    _fetchLiveEntityProfileData();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _initBaselineMetrics() {
    final baseContractedCop = widget.entity.amountMillions * 1000000;
    final safeContracted = baseContractedCop > 0 ? baseContractedCop : 0.0;
    _presupuestoTotalCop = safeContracted;
    _ejecutadoCop = 0;
    _disponibleCop = 0;
    _porcentajeEjecutado = 0;

    _totalContratos = widget.entity.contractsCount;
    _valorTotalContratadoCop = safeContracted;
    _contratistasUnicos = widget.entity.uniqueContractors;
    _nitEntidad =
        widget.entity.nit.isNotEmpty && widget.entity.nit != 'No Definido'
        ? widget.entity.nit
        : 'En consulta SECOP II';
    _ordenEntidad =
        widget.entity.location.toLowerCase().contains('nacional') ||
            _isNationalMultiRegionalEntity()
        ? 'Nacional'
        : 'Territorial';
  }

  /// Si el usuario entró desde una tarjeta de Regional específica (ej. "SENA - Regional Atlántico"),
  /// preseleccionamos esa regional pero cargamos todas las regionales para que pueda cambiar entre ellas.
  void _detectInitialRegionalFromEntityCard() {
    final locNorm = _normalizar(
      '${widget.entity.name} ${widget.entity.location}',
    );
    if (!locNorm.contains('REGIONAL') &&
        !locNorm.contains('SECCIONAL') &&
        !locNorm.contains('TERRITORIAL')) {
      return;
    }
    const knownDepts = <String, String>{
      'ATLANTICO': 'Atlántico',
      'CESAR': 'Cesar',
      'GUAJIRA': 'La Guajira',
      'MAGDALENA': 'Magdalena',
      'BOLIVAR': 'Bolívar',
      'ANTIOQUIA': 'Antioquia',
      'VALLE': 'Valle del Cauca',
      'SANTANDER': 'Santander',
      'BOGOTA': 'Distrito Capital de Bogotá',
      'CUNDINAMARCA': 'Cundinamarca',
      'CORDOBA': 'Córdoba',
      'SUCRE': 'Sucre',
      'NORTE DE SANTANDER': 'Norte de Santander',
      'TOLIMA': 'Tolima',
      'HUILA': 'Huila',
      'META': 'Meta',
      'BOYACA': 'Boyacá',
      'CALDAS': 'Caldas',
      'RISARALDA': 'Risaralda',
      'QUINDIO': 'Quindío',
      'CAUCA': 'Cauca',
      'NARINO': 'Nariño',
    };
    for (final entry in knownDepts.entries) {
      if (locNorm.contains(entry.key)) {
        _selectedRegionalDept = entry.value;
        break;
      }
    }
  }

  bool _isNationalMultiRegionalEntity() {
    final nitDigits = _nitEntidad.replaceAll(RegExp(r'[^0-9]'), '');
    final text = _normalizar('${widget.entity.name} ${widget.entity.location}');
    const multiRegionalNits = {
      '899999034', // SENA
      '899999239', // ICBF
      '800215807', // INVIAS
      '900948958', // ANT
      '830115226', // MINISTERIO DEL TRABAJO
      '800141397', // POLICIA
      '800150868', // FISCALIA
      '800197268', // DIAN
      '899999003', // EJERCITO / MINDEFENSA
      '899999068', // UNAL
      '800093816', // RAMA JUDICIAL
      '899999119', // REGISTRADURIA
      '899999094', // PROCURADURIA
      '899999067', // CONTRALORIA
    };
    if (multiRegionalNits.contains(nitDigits)) return true;
    return text.contains('SERVICIO NACIONAL DE APRENDIZAJE') ||
        text.contains('SENA') ||
        text.contains('BIENESTAR FAMILIAR') ||
        text.contains('ICBF') ||
        text.contains('INVIAS') ||
        text.contains('MINISTERIO DEL TRABAJO') ||
        text.contains('MINTRABAJO') ||
        text.contains('AGENCIA NACIONAL') ||
        text.contains('POLICIA NACIONAL') ||
        text.contains('FISCALIA') ||
        text.contains('NACIONAL');
  }

  static double _parseSafeContractCop(Map<String, dynamic> c) {
    final raw =
        double.tryParse((c['valor_del_contrato'] ?? '0').toString()) ?? 0;
    if (raw <= 0) return 0;
    return raw > 500000000000 ? raw / 1000 : raw;
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
    if (cop >= 1000000000000) {
      final billones = cop / 1000000000000;
      final formatted = billones.toStringAsFixed(2).replaceAll('.', ',');
      final millions = (cop / 1000000).round();
      return '\$ $formatted Billones (${_formatIntWithDots(millions)} M)';
    }
    if (cop >= 1000000) {
      final millions = (cop / 1000000).round();
      return '\$ ${_formatIntWithDots(millions)} M';
    }
    return _formatCopFull(cop);
  }

  static String _formatCompactCardMillions(double cop) {
    if (cop >= 1000000000000) {
      final billones = cop / 1000000000000;
      return '\$ ${billones.toStringAsFixed(2).replaceAll('.', ',')} B';
    }
    if (cop >= 1000000) {
      final millions = (cop / 1000000).round();
      return '\$ ${_formatIntWithDots(millions)} M';
    }
    return _formatCopFull(cop);
  }

  /// Construye la cláusula SoQL `$where` exacta y sin el filtro `$q` restrictivo cuando se tiene el NIT.
  /// Filtra por el año en curso (2026) cuando `onlyYear2026` es true y por la Regional seleccionada si aplica.
  String _buildEntityWhereClause({
    required bool onlyYear2026,
    required bool includeRegionalFilter,
    String? customModalityName,
    String? unidad,
    String? dependencia,
    String? busqueda,
    int? forceYear,
    ({int desde, DateTime corte})? rango,
    bool soloPrestacionServicios = false,
  }) {
    final clauses = <String>[
      'valor_del_contrato > 0',
      'valor_del_contrato < 500000000000',
    ];

    final targetYear = forceYear ?? _selectedContratosYear;
    if (rango != null) {
      // Periodo del reporte: firmados desde el 1 de enero hasta el corte.
      clauses.add(ReporteContratosService.filtroFechas(rango.desde, rango.corte));
      if (soloPrestacionServicios) {
        clauses.add(ReporteContratosService.filtroPrestacionServicios);
      }
    } else if (onlyYear2026 && targetYear != null) {
      clauses.add(
        "((fecha_de_firma >= '$targetYear-01-01T00:00:00.000' AND fecha_de_firma <= '$targetYear-12-31T23:59:59.999') OR "
        "(fecha_de_firma IS NULL AND fecha_de_inicio_del_contrato >= '$targetYear-01-01T00:00:00.000' AND fecha_de_inicio_del_contrato <= '$targetYear-12-31T23:59:59.999'))",
      );
    } else {
      // Cobertura completa histórica desde 2015 en adelante
      clauses.add(
        "(fecha_de_firma >= '2015-01-01T00:00:00.000' OR fecha_de_inicio_del_contrato >= '2015-01-01T00:00:00.000')",
      );
    }

    final nitClean =
        (widget.entity.nit.isNotEmpty && widget.entity.nit != 'No Definido')
        ? widget.entity.nit.replaceAll(RegExp(r'[^0-9]'), '')
        : _nitEntidad.replaceAll(RegExp(r'[^0-9]'), '');

    if (nitClean.length >= 8) {
      clauses.add("nit_entidad = '$nitClean'");
    } else {
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
        'REGIONAL',
        'SECCIONAL',
      };
      final tokens = clean
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3 && !stopWords.contains(w))
          .take(4)
          .toList();
      for (final t in tokens) {
        if (t == 'ALCALDIA') {
          clauses.add(
            "(upper(nombre_entidad) LIKE '%ALCALD%' OR upper(nombre_entidad) LIKE '%MUNICIPIO%' OR upper(nombre_entidad) LIKE '%DISTRITO%')",
          );
        } else if (t == 'GOBERNACION') {
          clauses.add(
            "(upper(nombre_entidad) LIKE '%GOBERNAC%' OR upper(nombre_entidad) LIKE '%DEPARTAMENTO%')",
          );
        } else {
          clauses.add("upper(nombre_entidad) LIKE '%$t%'");
        }
      }
    }

    if (includeRegionalFilter &&
        _selectedRegionalDept != null &&
        _selectedRegionalDept!.trim().isNotEmpty) {
      final deptSafe = _selectedRegionalDept!.replaceAll("'", "''");
      clauses.add("departamento = '$deptSafe'");
    }

    if (customModalityName != null && customModalityName != 'Todas') {
      final modClause = _buildSoqlModalityFilter(customModalityName);
      if (modClause.isNotEmpty) {
        clauses.add(modClause);
      }
    }

    if (dependencia != null) {
      final filtro = _buildSoqlDependenciaFilter(dependencia);
      if (filtro.isNotEmpty) clauses.add(filtro);
    }

    if (unidad != null && unidad.isNotEmpty) {
      clauses.add("nombre_entidad = '${unidad.replaceAll("'", "''")}'");
    }

    if (busqueda != null && busqueda.trim().isNotEmpty) {
      final filtro = _buildSoqlSearchFilter(busqueda);
      if (filtro.isNotEmpty) clauses.add(filtro);
    }

    return clauses.join(' AND ');
  }

  static String _buildSoqlModalityFilter(String modName) {
    switch (modName) {
      case 'Contratación directa':
        return "upper(modalidad_de_contratacion) LIKE '%DIRECTA%'";
      case 'Mínima cuantía':
        return "(upper(modalidad_de_contratacion) LIKE '%MINIMA%' OR upper(modalidad_de_contratacion) LIKE '%MÍNIMA%')";
      case 'Selección abreviada':
        return "(upper(modalidad_de_contratacion) LIKE '%ABREVIADA%' OR upper(modalidad_de_contratacion) LIKE '%SUBASTA%')";
      case 'Licitación pública':
        return "(upper(modalidad_de_contratacion) LIKE '%LICITAC%')";
      case 'Concurso de méritos':
        return "(upper(modalidad_de_contratacion) LIKE '%MERITO%' OR upper(modalidad_de_contratacion) LIKE '%MÉRITO%')";
      case 'Régimen especial':
        return "(upper(modalidad_de_contratacion) LIKE '%ESPECIAL%')";
      default:
        return '';
    }
  }

  /// Cada palabra debe aparecer en el número del contrato o del proceso, el
  /// objeto o el contratista. SECOP II guarda textos con y sin tilde y SoQL
  /// no las ignora, así que en los campos de texto cada palabra se busca
  /// también con una tilde en cada vocal ("GESTION" → "GESTIÓN"). Solo se
  /// conservan letras, dígitos y `-./`, así que no admite inyección.
  static String _buildSoqlSearchFilter(String query) {
    const camposCodigo = [
      'referencia_del_contrato',
      'id_contrato',
      'proceso_de_compra',
      'documento_proveedor',
    ];
    const camposTexto = ['objeto_del_contrato', 'proveedor_adjudicado'];
    final palabras = _normalizar(query)
        .replaceAll(RegExp(r'[^A-Z0-9Ñ\-./]'), ' ')
        .split(RegExp(r'\s+'))
        .where((p) => p.length >= 2)
        .toSet()
        .take(5);
    return [
      for (final palabra in palabras)
        '(${[
          for (final c in camposCodigo) "upper($c) LIKE '%$palabra%'",
          for (final c in camposTexto)
            for (final v in _variantesConTilde(palabra))
              "upper($c) LIKE '%$v%'",
        ].join(' OR ')})',
    ].join(' AND ');
  }

  static String _soqlCoincideDependencia(_DependenciaInterna d) => d.palabras
      .map((w) => "upper(objeto_del_contrato) LIKE '%$w%'")
      .join(' OR ');

  /// Contratos de una dependencia: coinciden con sus palabras y con ninguna de
  /// las dependencias anteriores (la misma regla de [_soqlClasificacionDependencias]).
  static String _buildSoqlDependenciaFilter(String id) {
    final idx = _dependenciasInternas.indexWhere((d) => d.id == id);
    if (idx < 0) return '';
    final propia = _dependenciasInternas[idx];
    return [
      if (propia.palabras.isNotEmpty) '(${_soqlCoincideDependencia(propia)})',
      for (final previa in _dependenciasInternas.take(idx))
        if (previa.palabras.isNotEmpty)
          'NOT (${_soqlCoincideDependencia(previa)})',
    ].join(' AND ');
  }

  /// `case()` de SoQL: asigna cada contrato a la primera dependencia que
  /// coincide, o a la última si no coincide ninguna.
  static String _soqlClasificacionDependencias() {
    final ramas = [
      for (final d in _dependenciasInternas)
        if (d.palabras.isNotEmpty) "${_soqlCoincideDependencia(d)}, '${d.id}'",
    ];
    return "case(${ramas.join(', ')}, true, '${_dependenciasInternas.last.id}')";
  }

  String _nombreDependencia(_DependenciaInterna d) {
    final nacional =
        _ordenEntidad.toUpperCase().contains('NACIONAL') ||
        _isNationalMultiRegionalEntity();
    if (!nacional) return d.nombreTerritorial;
    if (d.id == 'despacho' && _selectedRegionalDept != null) {
      return 'Despacho de la Dirección Regional';
    }
    return d.nombreNacional;
  }

  _DependenciaInterna? get _dependenciaSeleccionada {
    for (final d in _dependenciasInternas) {
      if (d.id == _selectedDependencia) return d;
    }
    return null;
  }

  static List<String> _variantesConTilde(String palabra) {
    const tildes = {'A': 'Á', 'E': 'É', 'I': 'Í', 'O': 'Ó', 'U': 'Ú'};
    final variantes = <String>[palabra];
    if (palabra.length < 4 || RegExp(r'^[0-9\-./]+$').hasMatch(palabra)) {
      return variantes;
    }
    for (var i = 0; i < palabra.length; i++) {
      final tilde = tildes[palabra[i]];
      if (tilde != null) {
        variantes.add(
          palabra.substring(0, i) + tilde + palabra.substring(i + 1),
        );
      }
    }
    return variantes;
  }

  static String _formatRegionalDisplayName(String deptRaw) {
    final clean = deptRaw.trim();
    if (clean.isEmpty || clean.toUpperCase() == 'NO DEFINIDO') {
      return 'Sede Central / Consolidado';
    }
    if (clean.toUpperCase().contains('BOGOT')) {
      return 'Regional Bogotá D.C. / Dirección General';
    }
    return 'Regional $clean';
  }

  /// GET a Datos Abiertos con un reintento: datos.gov.co a veces corta la
  /// conexión o responde 429/5xx de forma transitoria, y sin reintento una
  /// sola consulta fallida deja la página sin datos.
  static Future<http.Response> _getSecop(
    Uri uri, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final resp = await http.get(uri).timeout(timeout);
      if (resp.statusCode != 429 && resp.statusCode < 500) return resp;
    } catch (_) {
      // Se reintenta abajo; si vuelve a fallar, el error sube al llamador.
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return http.get(uri).timeout(timeout);
  }

  Future<void> _fetchLiveEntityProfileData() async {
    if (!mounted) return;
    setState(() => _isLoadingLive = true);

    try {
      int yearToUse = _selectedContratosYear ?? AniosSecop.actual;
      String whereEntityYear = _buildEntityWhereClause(
        onlyYear2026: _onlyCurrentYear2026,
        includeRegionalFilter: true,
        forceYear: yearToUse,
      );
      String whereNationalYear = _buildEntityWhereClause(
        onlyYear2026: _onlyCurrentYear2026,
        includeRegionalFilter: false,
        forceYear: yearToUse,
      );

      // 1) Consulta en paralelo a SECOP II (jbjy-vk9h.json):
      //    a) Valor contratado y ejecución por estado_contrato (vigencia activa)
      //    b) Discriminación exacta por modalidad_de_contratacion (todos los contratos reales en SECOP II)
      //    c) Distribución nacional por Regionales / Departamentos ($group=departamento)
      //    d) Primera página de contratos + muestra amplia para dependencias y contratistas
      Future<List<http.Response>> runQueries(
        String wRegional,
        String wNational,
      ) {
        final wRegEnc = Uri.encodeComponent(wRegional);
        final wNatEnc = Uri.encodeComponent(wNational);

        final stateAggUrl = Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
          '\$select=estado_contrato,count(*)%20as%20contratos,sum(valor_del_contrato)%20as%20total_valor'
          '&\$where=$wRegEnc'
          '&\$group=estado_contrato'
          '&\$limit=40',
        );

        final modalityAggUrl = Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
          '\$select=modalidad_de_contratacion,count(*)%20as%20contratos,sum(valor_del_contrato)%20as%20total_valor'
          '&\$where=$wRegEnc'
          '&\$group=modalidad_de_contratacion'
          '&\$order=total_valor%20DESC'
          '&\$limit=30',
        );

        final regionalAggUrl = Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
          '\$select=departamento,count(*)%20as%20contratos,sum(valor_del_contrato)%20as%20total_valor'
          '&\$where=$wNatEnc'
          '&\$group=departamento'
          '&\$order=contratos%20DESC'
          '&\$limit=40',
        );

        final sampleContractsUrl = Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
          '\$where=$wRegEnc'
          '&\$order=fecha_de_firma%20DESC'
          '&\$limit=200',
        );

        // Unidades de contratación reales: cuentas compradoras con el NIT.
        final unidadesUrl = Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
          '\$select=nombre_entidad,departamento,count(*)%20as%20contratos,sum(valor_del_contrato)%20as%20total_valor'
          '&\$where=$wRegEnc'
          '&\$group=nombre_entidad,departamento'
          '&\$order=contratos%20DESC'
          '&\$limit=400',
        );

        final uniqueContractorsUrl = Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
          '\$select=count(distinct%20documento_proveedor)%20as%20contratistas'
          '&\$where=$wRegEnc',
        );

        return Future.wait([
          _getSecop(stateAggUrl),
          _getSecop(modalityAggUrl),
          _getSecop(regionalAggUrl),
          _getSecop(sampleContractsUrl),
          _getSecop(uniqueContractorsUrl),
          _getSecop(unidadesUrl),
        ]);
      }

      var responses = await runQueries(whereEntityYear, whereNationalYear);

      // Verificamos si en 2026 hay contratos; si una entidad pequeña aún no registra en 2026, probamos 2025
      int checkCount = 0;
      if (responses[0].statusCode == 200) {
        final list = jsonDecode(responses[0].body) as List<dynamic>;
        for (final r in list) {
          if (r is Map) {
            checkCount += int.tryParse((r['contratos'] ?? '0').toString()) ?? 0;
          }
        }
      }
      if (checkCount == 0 &&
          _onlyCurrentYear2026 &&
          _selectedContratosYear == AniosSecop.actual) {
        yearToUse = AniosSecop.actual - 1;
        whereEntityYear = _buildEntityWhereClause(
          onlyYear2026: true,
          includeRegionalFilter: true,
          forceYear: yearToUse,
        );
        whereNationalYear = _buildEntityWhereClause(
          onlyYear2026: true,
          includeRegionalFilter: false,
          forceYear: yearToUse,
        );
        responses = await runQueries(whereEntityYear, whereNationalYear);

        // Si tampoco hay en 2025, consultamos el consolidado histórico de SECOP II
        int checkCount2 = 0;
        if (responses[0].statusCode == 200) {
          final list2 = jsonDecode(responses[0].body) as List<dynamic>;
          for (final r in list2) {
            if (r is Map) {
              checkCount2 +=
                  int.tryParse((r['contratos'] ?? '0').toString()) ?? 0;
            }
          }
        }
        if (checkCount2 == 0) {
          _onlyCurrentYear2026 = false;
          whereEntityYear = _buildEntityWhereClause(
            onlyYear2026: false,
            includeRegionalFilter: true,
          );
          whereNationalYear = _buildEntityWhereClause(
            onlyYear2026: false,
            includeRegionalFilter: false,
          );
          responses = await runQueries(whereEntityYear, whereNationalYear);
        }
      }

      final aggResp = responses[0];
      final modResp = responses[1];
      final regResp = responses[2];
      final sampleResp = responses[3];
      final uniqueResp = responses[4];
      final unidadesResp = responses[5];
      int? uniqueContractors;
      if (uniqueResp.statusCode == 200) {
        final uniqueList = jsonDecode(uniqueResp.body);
        if (uniqueList is List && uniqueList.isNotEmpty && uniqueList.first is Map) {
          uniqueContractors =
              int.tryParse('${uniqueList.first['contratistas'] ?? ''}');
        }
      }

      // 1. Procesamos Regionales / Seccionales Territoriales ($group=departamento)
      final builtRegionals = <_RegionalBreakdownItem>[];
      if (regResp.statusCode == 200) {
        final regList = jsonDecode(regResp.body) as List<dynamic>;
        for (final row in regList) {
          if (row is! Map) continue;
          final dept = (row['departamento'] ?? '').toString().trim();
          if (dept.isEmpty || dept.toUpperCase() == 'NO DEFINIDO') continue;
          final cCount =
              int.tryParse((row['contratos'] ?? '0').toString()) ?? 0;
          final rawVal =
              double.tryParse((row['total_valor'] ?? '0').toString()) ?? 0;
          if (cCount <= 0 || rawVal <= 0) continue;
          builtRegionals.add(
            _RegionalBreakdownItem(
              departmentRaw: dept,
              label: _formatRegionalDisplayName(dept),
              contractsCount: cCount,
              totalCop: rawVal,
            ),
          );
        }
      }

      // 2. Procesamos valor contratado y ejecución real por estado de contrato
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
          if (cCount <= 0 || rawVal <= 0) continue;
          final estRaw = _normalizar((row['estado_contrato'] ?? '').toString());

          aggTotalContracts += cCount;
          aggTotalCop += rawVal;

          if (estRaw.contains('EJEC') ||
              estRaw.contains('TERM') ||
              estRaw.contains('CELEBR') ||
              estRaw.contains('LIQUID') ||
              estRaw.contains('APROB') ||
              estRaw.contains('MODIF') ||
              estRaw.contains('CERR')) {
            executedCop += rawVal;
          }
        }
      }

      // 3. Procesamos Discriminación Real por Modalidad de Contratación ($group=modalidad_de_contratacion)
      final Map<String, (int count, double sum)> modalityAggMap = {};
      if (modResp.statusCode == 200) {
        final modData = jsonDecode(modResp.body) as List<dynamic>;
        for (final row in modData) {
          if (row is! Map) continue;
          final rawModName = (row['modalidad_de_contratacion'] ?? '')
              .toString();
          final normModName = _normalizeModalityLabel(rawModName);
          final cCount =
              int.tryParse((row['contratos'] ?? '0').toString()) ?? 0;
          final rawVal =
              double.tryParse((row['total_valor'] ?? '0').toString()) ?? 0;
          if (cCount <= 0 || rawVal <= 0) continue;
          final prev = modalityAggMap[normModName] ?? (0, 0.0);
          modalityAggMap[normModName] = (prev.$1 + cCount, prev.$2 + rawVal);
        }
      }

      // 4. Procesamos los contratos de muestra cargados
      final fetchedContracts = <Map<String, dynamic>>[];
      if (sampleResp.statusCode == 200) {
        final rawList = jsonDecode(sampleResp.body) as List<dynamic>;
        for (final item in rawList) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          if (_parseSafeContractCop(map) <= 0) continue;
          fetchedContracts.add(map);
        }
      }

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

      // Si por alguna razón modalityAggMap vino vacío pero tenemos contratos en memoria, respaldamos
      if (modalityAggMap.isEmpty && fetchedContracts.isNotEmpty) {
        for (final c in fetchedContracts) {
          final v = _parseSafeContractCop(c);
          final modClean = _normalizeModalityLabel(
            (c['modalidad_de_contratacion'] ?? '').toString(),
          );
          final prev = modalityAggMap[modClean] ?? (0, 0.0);
          modalityAggMap[modClean] = (prev.$1 + 1, prev.$2 + v);
        }
      }

      final builtModalities = <_ModalityStat>[];
      modalityAggMap.forEach((modName, tuple) {
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

      // 5. Unidades de contratación reales ($group=nombre_entidad)
      final builtUnidades = <_UnidadContratante>[];
      if (unidadesResp.statusCode == 200) {
        final unidadesData = jsonDecode(unidadesResp.body) as List<dynamic>;
        for (final row in unidadesData) {
          if (row is! Map) continue;
          final nombre = (row['nombre_entidad'] ?? '').toString().trim();
          final cCount =
              int.tryParse((row['contratos'] ?? '0').toString()) ?? 0;
          if (nombre.isEmpty || cCount <= 0) continue;
          builtUnidades.add(
            _UnidadContratante(
              nombre: nombre,
              departamento: (row['departamento'] ?? '').toString().trim(),
              contractsCount: cCount,
              totalCop:
                  double.tryParse((row['total_valor'] ?? '0').toString()) ??
                  0,
            ),
          );
        }
      }

      final Map<String, _ContractorSummary> contractorMap = {};
      for (final c in fetchedContracts) {
        final rawProv = (c['proveedor_adjudicado'] ?? '').toString().trim();
        if (rawProv.isNotEmpty && rawProv.toUpperCase() != 'NO DEFINIDO') {
          final doc = (c['documento_proveedor'] ?? 'Sin NIT').toString().trim();
          final safeVal = _parseSafeContractCop(c);
          final fecha = (c['fecha_de_firma'] ?? '').toString().split('T').first;
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
              lastDate: fecha.isNotEmpty ? fecha : '$yearToUse',
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

      final builtContractors = contractorMap.values.toList()
        ..sort((a, b) => b.totalCop.compareTo(a.totalCop));

      if (!mounted) return;
      setState(() {
        _activeBudgetYear = yearToUse;
        _regionalStats = builtRegionals;
        _entityContracts = fetchedContracts;
        _pagedContractsList = fetchedContracts
            .take(_contractsPageSize)
            .toList();
        _modalityStats = builtModalities;
        _unidades = builtUnidades;
        if (_selectedUnidad != null &&
            !builtUnidades.any((u) => u.nombre == _selectedUnidad)) {
          _selectedUnidad = null;
        }
        _selectedContratosYear = _onlyCurrentYear2026 ? yearToUse : null;
        _contractorsList = builtContractors;

        if (aggTotalCop > 0 && aggTotalContracts > 0) {
          _valorTotalContratadoCop = aggTotalCop;
          _totalContratos = aggTotalContracts;
          _totalMatchingContractsForTable = aggTotalContracts;
          _totalMatchingCopForTable = aggTotalCop;

          _contratistasUnicos =
              uniqueContractors ?? builtContractors.length;

          // Cifras reales de SECOP II: valor contratado y la parte que
          // corresponde a contratos celebrados, en ejecución o terminados.
          _presupuestoTotalCop = aggTotalCop;
          _ejecutadoCop = executedCop;
          _disponibleCop = math.max(0, aggTotalCop - executedCop);
          _porcentajeEjecutado =
              ((executedCop / aggTotalCop) * 100).round().clamp(0, 100);
        }
        _selectedModality = 'Todas';
        _contractsPage = 1;
        _isLoadingLive = false;
      });
      // La clasificación por dependencias es la consulta más pesada: va
      // aparte para no retrasar ni tumbar la carga principal.
      _fetchConteoDependencias(whereEntityYear);
      // La muestra inicial solo sirve sin filtros; con unidad o búsqueda
      // activas se consulta la página exacta.
      if (_selectedUnidad != null ||
          _selectedDependencia != null ||
          _busqueda.isNotEmpty) {
        _fetchContractsPageFromSecop(page: 1);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLive = false);
      }
    }
  }

  Future<void> _fetchConteoDependencias(String whereClause) async {
    final requestId = ++_dependenciasRequestId;
    setState(() {
      _conteoDependencias = {};
      _cargandoDependencias = true;
    });
    final conteo = <String, (int, double)>{};
    try {
      final resp = await _getSecop(
            Uri.parse(
              'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
              '\$select=${Uri.encodeComponent(_soqlClasificacionDependencias())}%20as%20dependencia,count(*)%20as%20contratos,sum(valor_del_contrato)%20as%20total_valor'
              '&\$where=${Uri.encodeComponent(whereClause)}'
              '&\$group=dependencia',
            ),
            timeout: const Duration(seconds: 25),
          );
      if (resp.statusCode == 200) {
        for (final row in jsonDecode(resp.body) as List<dynamic>) {
          if (row is! Map) continue;
          conteo[(row['dependencia'] ?? '').toString()] = (
            int.tryParse('${row['contratos'] ?? 0}') ?? 0,
            double.tryParse('${row['total_valor'] ?? 0}') ?? 0,
          );
        }
      }
    } catch (_) {
      // Sin conteo: la sección muestra el aviso y el resto de la página sigue.
    }
    if (!mounted || requestId != _dependenciasRequestId) return;
    setState(() {
      _conteoDependencias = conteo;
      _cargandoDependencias = false;
    });
  }

  bool get _hayFiltrosContratos =>
      _busqueda.isNotEmpty ||
      _selectedUnidad != null ||
      _selectedDependencia != null ||
      _selectedModality != 'Todas';

  bool get _hayFiltrosActivos =>
      _selectedRegionalDept != null ||
      _selectedUnidad != null ||
      _selectedDependencia != null ||
      _selectedModality != 'Todas';

  bool get _tieneRegionales => _regionalStats.length > 1;

  /// Página de contratos con los filtros activos, paginada en el servidor
  /// (`$limit` + `$offset`). El total sale de un conteo con el mismo filtro,
  /// así que siempre coincide con lo listado. Las respuestas de consultas
  /// anteriores se descartan.
  Future<void> _fetchContractsPageFromSecop({
    required int page,
    String? modalityOverride,
  }) async {
    if (!mounted) return;
    final requestId = ++_contratosRequestId;
    setState(() {
      if (modalityOverride != null) _selectedModality = modalityOverride;
      _contractsPage = page;
      _isLoadingContractsPage = true;
    });

    final whereClause = _busqueda.isNotEmpty
        ? _buildEntityWhereClause(
            onlyYear2026: false,
            includeRegionalFilter: false,
            busqueda: _busqueda,
          )
        : _buildEntityWhereClause(
            onlyYear2026: _onlyCurrentYear2026,
            includeRegionalFilter: true,
            customModalityName: _selectedModality,
            unidad: _selectedUnidad,
            dependencia: _selectedDependencia,
            forceYear: _activeBudgetYear,
          );
    final whereEnc = Uri.encodeComponent(whereClause);
    final offset = math.max(0, (page - 1) * _contractsPageSize);

    try {
      final responses = await Future.wait([
        _getSecop(
          Uri.parse(
            'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
            '\$select=count(*)%20as%20contratos,sum(valor_del_contrato)%20as%20total_valor'
            '&\$where=$whereEnc',
          ),
          timeout: const Duration(seconds: 15),
        ),
        _getSecop(
          Uri.parse(
            'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
            '\$where=$whereEnc'
            '&\$order=fecha_de_firma%20DESC'
            '&\$limit=$_contractsPageSize'
            '&\$offset=$offset',
          ),
          timeout: const Duration(seconds: 15),
        ),
      ]);
      if (!mounted || requestId != _contratosRequestId) return;
      if (responses[1].statusCode != 200) {
        throw StateError('SECOP II respondió ${responses[1].statusCode}');
      }

      var total = 0;
      var totalCop = 0.0;
      if (responses[0].statusCode == 200) {
        final agg = jsonDecode(responses[0].body);
        if (agg is List && agg.isNotEmpty && agg.first is Map) {
          total = int.tryParse('${agg.first['contratos'] ?? 0}') ?? 0;
          totalCop = double.tryParse('${agg.first['total_valor'] ?? 0}') ?? 0;
        }
      }
      final rows = <Map<String, dynamic>>[
        for (final item in jsonDecode(responses[1].body) as List<dynamic>)
          if (item is Map) Map<String, dynamic>.from(item),
      ];

      setState(() {
        _pagedContractsList = rows;
        _totalMatchingContractsForTable = total;
        _totalMatchingCopForTable = totalCop;
        _isLoadingContractsPage = false;
      });
    } catch (_) {
      if (mounted && requestId == _contratosRequestId) {
        setState(() => _isLoadingContractsPage = false);
      }
    }
  }

  void _cancelarBusqueda() {
    _busquedaController.clear();
    _busqueda = '';
  }

  void _aplicarBusqueda(String texto) {
    final consulta = texto.trim();
    if (consulta.isEmpty) {
      if (_busqueda.isNotEmpty) _limpiarBusqueda();
      return;
    }
    // La búsqueda anula la navegación: unidad, dependencia y modalidad dejan
    // de aplicar.
    setState(() {
      _busqueda = consulta;
      _selectedUnidad = null;
      _selectedDependencia = null;
      _selectedTabIndex = 1;
    });
    _fetchContractsPageFromSecop(page: 1, modalityOverride: 'Todas');
  }

  void _limpiarBusqueda() {
    setState(_cancelarBusqueda);
    _fetchContractsPageFromSecop(page: 1);
  }

  void _seleccionarUnidad(String? unidad, {bool irAContratos = false}) {
    setState(() {
      _cancelarBusqueda();
      _selectedUnidad = unidad;
      if (irAContratos) _selectedTabIndex = 1;
    });
    _fetchContractsPageFromSecop(page: 1);
  }

  void _seleccionarDependencia(String? id, {bool irAContratos = false}) {
    setState(() {
      _cancelarBusqueda();
      _selectedDependencia = id;
      if (irAContratos) _selectedTabIndex = 1;
    });
    _fetchContractsPageFromSecop(page: 1);
  }

  void _seleccionarModalidad(String modalidad) {
    setState(() {
      _cancelarBusqueda();
      _selectedTabIndex = 1;
    });
    _fetchContractsPageFromSecop(page: 1, modalityOverride: modalidad);
  }

  void _seleccionarRegional(String? departamento) {
    if (departamento == _selectedRegionalDept) return;
    setState(() {
      _cancelarBusqueda();
      _selectedRegionalDept = departamento;
      _selectedUnidad = null;
    });
    _fetchLiveEntityProfileData();
  }

  void _seleccionarVigencia(int? anio) {
    setState(() {
      _cancelarBusqueda();
      _selectedContratosYear = anio;
      _onlyCurrentYear2026 = anio != null;
    });
    _fetchLiveEntityProfileData();
  }

  void _limpiarFiltros() {
    final recargarTodo = _selectedRegionalDept != null;
    setState(() {
      _cancelarBusqueda();
      _selectedRegionalDept = null;
      _selectedUnidad = null;
      _selectedDependencia = null;
    });
    if (recargarTodo) {
      _fetchLiveEntityProfileData();
    } else {
      _fetchContractsPageFromSecop(page: 1, modalityOverride: 'Todas');
    }
  }

  void _alternarSeguir() {
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
  }

  static String _normalizeModalityLabel(String raw) {
    final norm = _normalizar(raw);
    if (norm.contains('DIRECTA')) return 'Contratación directa';
    if (norm.contains('LICITAC')) return 'Licitación pública';
    if (norm.contains('MINIMA')) return 'Mínima cuantía';
    if (norm.contains('ABREVIADA') || norm.contains('SUBASTA')) {
      return 'Selección abreviada';
    }
    if (norm.contains('MERITOS') || norm.contains('MERITO')) {
      return 'Concurso de méritos';
    }
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

  // ===========================================================================
  // ENCABEZADO COMPACTO: IDENTIDAD + METADATOS EN UNA LÍNEA
  // ===========================================================================

  Widget _buildCompactHeader() {
    final mobile = _isMobile;
    final metadatos = <(IconData, String)>[
      (Icons.badge_outlined, 'NIT $_nitEntidad'),
      (Icons.account_balance_outlined, 'Orden $_ordenEntidad'),
      (
        Icons.event_outlined,
        _onlyCurrentYear2026
            ? 'Vigencia $_activeBudgetYear'
            : 'Historial 2015–${AniosSecop.actual}',
      ),
      (
        Icons.description_outlined,
        '${_formatIntWithDots(_totalContratos)} contratos · ${_formatCompactCardMillions(_valorTotalContratadoCop)}',
      ),
      if (_selectedRegionalDept != null)
        (
          Icons.place_outlined,
          _formatRegionalDisplayName(_selectedRegionalDept!),
        ),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 4 : 20,
        mobile ? 8 : 12,
        mobile ? 8 : 32,
        mobile ? 10 : 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDE8DF))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Volver a Entidades',
            icon: const Icon(Icons.arrow_back_rounded, color: _azulOscuro),
          ),
          const SizedBox(width: 4),
          Container(
            width: mobile ? 40 : 48,
            height: mobile ? 40 : 48,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _azulOscuro.withValues(alpha: 0.10)),
            ),
            child: EntityBrandScope(
              entityName: widget.entity.name,
              nit: _nitEntidad,
              child: EntityEmblemWidget(
                type: widget.entity.emblemType,
                size: mobile ? 30 : 38,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.entity.name,
                  maxLines: mobile ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _azulOscuro,
                    fontSize: mobile ? 15.5 : 20,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                if (mobile)
                  Text(
                    metadatos.map((m) => m.$2).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Wrap(
                    spacing: 14,
                    runSpacing: 3,
                    children: [
                      for (final (icono, texto) in metadatos)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icono, size: 14, color: const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              texto,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (mobile)
            IconButton(
              onPressed: _alternarSeguir,
              tooltip: _isFollowing ? 'Dejar de seguir' : 'Seguir entidad',
              icon: Icon(
                _isFollowing
                    ? Icons.bookmark_added_rounded
                    : Icons.bookmark_border_rounded,
                color: _azulOscuro,
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _alternarSeguir,
              icon: Icon(
                _isFollowing
                    ? Icons.bookmark_added_rounded
                    : Icons.bookmark_border_rounded,
                size: 16,
              ),
              label: Text(
                _isFollowing ? 'Siguiendo' : 'Seguir entidad',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _azulOscuro,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BARRA FIJA DE EXPLORACIÓN: BÚSQUEDA DIRECTA + SELECTORES + FILTROS
  // ===========================================================================

  Widget _buildBarraExploracion() {
    final mobile = _isMobile;
    final secundarios =
        (_selectedUnidad != null ? 1 : 0) +
        (_selectedDependencia != null ? 1 : 0) +
        (_selectedModality != 'Todas' ? 1 : 0) +
        (mobile && _selectedRegionalDept != null ? 1 : 0);

    final buscador = TextField(
      controller: _busquedaController,
      onSubmitted: _aplicarBusqueda,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: _azulOscuro),
      decoration: InputDecoration(
        hintText: mobile
            ? 'Número, objeto o contratista'
            : 'Buscar contrato en toda la entidad: número, palabra del objeto o contratista…',
        hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.search_rounded, color: _azulOscuro),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _busquedaController,
          builder: (context, valor, _) =>
              valor.text.isEmpty && _busqueda.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Limpiar búsqueda',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: _limpiarBusqueda,
                ),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _azulPrimario, width: 1.6),
        ),
      ),
    );

    final etiquetaFiltros = secundarios > 0 ? 'Filtros ($secundarios)' : 'Filtros';

    return Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 32,
        12,
        mobile ? 12 : 32,
        12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mobile)
            Row(
              children: [
                Expanded(child: buscador),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: secundarios > 0,
                  label: Text('$secundarios'),
                  child: IconButton.outlined(
                    onPressed: _abrirFiltrosMovil,
                    tooltip: etiquetaFiltros,
                    icon: const Icon(Icons.tune_rounded, color: _azulOscuro),
                    style: IconButton.styleFrom(
                      fixedSize: const Size(48, 48),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: buscador),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => _aplicarBusqueda(_busquedaController.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: _azulOscuro,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 17,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Buscar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 16),
                if (_tieneRegionales) ...[
                  SizedBox(width: 270, child: _selectorRegional()),
                  const SizedBox(width: 10),
                ],
                SizedBox(width: 200, child: _selectorVigencia()),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _filtrosExpandidos = !_filtrosExpandidos),
                  icon: Icon(
                    _filtrosExpandidos
                        ? Icons.expand_less_rounded
                        : Icons.tune_rounded,
                    size: 18,
                  ),
                  label: Text(
                    etiquetaFiltros,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _azulOscuro,
                    backgroundColor: _filtrosExpandidos || secundarios > 0
                        ? const Color(0xFFEFF6FF)
                        : null,
                    side: BorderSide(
                      color: secundarios > 0
                          ? _azulPrimario
                          : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          if (_filtrosExpandidos && !mobile) ...[
            const SizedBox(height: 12),
            _buildPanelFiltros(),
          ],
          if (_busqueda.isNotEmpty ||
              (_hayFiltrosActivos && (mobile || !_filtrosExpandidos))) ...[
            const SizedBox(height: 10),
            _buildFiltrosActivos(),
          ],
        ],
      ),
    );
  }

  /// Contenedor común de los selectores desplegables de la barra.
  Widget _selectorCompacto<T>({
    required IconData icono,
    required String ayuda,
    required T valor,
    required List<DropdownMenuItem<T>> opciones,
    required ValueChanged<T?> alCambiar,
  }) {
    final estilo = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: _azulOscuro,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    );
    return Tooltip(
      message: ayuda,
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(icono, size: 16, color: _azulOscuro),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: valor,
                  items: opciones,
                  onChanged: alCambiar,
                  isExpanded: true,
                  isDense: true,
                  menuMaxHeight: 420,
                  borderRadius: BorderRadius.circular(12),
                  style: estilo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectorRegional({VoidCallback? alElegir}) {
    final totalNacional = _regionalStats.fold<int>(
      0,
      (acc, r) => acc + r.contractsCount,
    );
    final valido =
        _selectedRegionalDept == null ||
        _regionalStats.any((r) => r.departmentRaw == _selectedRegionalDept);
    return _selectorCompacto<String?>(
      icono: Icons.public_rounded,
      ayuda: 'Cambiar entre el consolidado y una regional',
      valor: valido ? _selectedRegionalDept : null,
      opciones: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'Consolidado nacional · ${_formatIntWithDots(totalNacional)}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final r in _regionalStats)
          DropdownMenuItem<String?>(
            value: r.departmentRaw,
            child: Text(
              '${r.label} · ${_formatIntWithDots(r.contractsCount)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      alCambiar: (v) {
        alElegir?.call();
        _seleccionarRegional(v);
      },
    );
  }

  Widget _selectorVigencia({VoidCallback? alElegir}) {
    return _selectorCompacto<int?>(
      icono: Icons.event_outlined,
      ayuda: 'Vigencia de los contratos',
      valor: _selectedContratosYear,
      opciones: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text('Todas (2015–${AniosSecop.actual})'),
        ),
        for (final anio in _aniosDisponibles)
          DropdownMenuItem<int?>(value: anio, child: Text('Vigencia $anio')),
      ],
      alCambiar: (v) {
        alElegir?.call();
        _seleccionarVigencia(v);
      },
    );
  }

  Widget _selectorDependencia({VoidCallback? alElegir}) {
    return _selectorCompacto<String?>(
      icono: Icons.account_tree_rounded,
      ayuda: 'Dependencia interna (clasificada por el objeto del contrato)',
      valor: _selectedDependencia,
      opciones: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Todas las dependencias'),
        ),
        for (final d in _dependenciasInternas)
          DropdownMenuItem<String?>(
            value: d.id,
            child: Text(
              _conteoDependencias[d.id] == null
                  ? _nombreDependencia(d)
                  : '${_nombreDependencia(d)} · ${_formatIntWithDots(_conteoDependencias[d.id]!.$1)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      alCambiar: (v) {
        alElegir?.call();
        _seleccionarDependencia(v, irAContratos: true);
      },
    );
  }

  Widget _selectorUnidad({VoidCallback? alElegir}) {
    return _selectorCompacto<String?>(
      icono: Icons.apartment_rounded,
      ayuda: 'Unidad de contratación (cuenta en SECOP II)',
      valor: _selectedUnidad,
      opciones: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('Todas las unidades (${_unidades.length})'),
        ),
        for (final u in _unidades)
          DropdownMenuItem<String?>(
            value: u.nombre,
            child: Text(
              '${u.nombre} · ${_formatIntWithDots(u.contractsCount)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      alCambiar: (v) {
        alElegir?.call();
        _seleccionarUnidad(v, irAContratos: true);
      },
    );
  }

  /// Filtros secundarios. En escritorio se despliega bajo la barra; en
  /// celular se abre como hoja inferior e incluye regional y vigencia.
  Widget _buildPanelFiltros({VoidCallback? alElegir}) {
    Widget etiqueta(String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );

    final modalidades = <(String, int)>[
      ('Todas', _totalContratos),
      for (final m in _modalityStats) (m.name, m.contractsCount),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isMobile) ...[
            if (_tieneRegionales) ...[
              etiqueta('Regional'),
              _selectorRegional(alElegir: alElegir),
              const SizedBox(height: 12),
            ],
            etiqueta('Vigencia'),
            _selectorVigencia(alElegir: alElegir),
            const SizedBox(height: 12),
          ],
          etiqueta('Dependencia interna'),
          if (_isMobile)
            _selectorDependencia(alElegir: alElegir)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 520,
                child: _selectorDependencia(alElegir: alElegir),
              ),
            ),
          const SizedBox(height: 12),
          if (_unidades.length > 1) ...[
            etiqueta('Unidad de contratación'),
            if (_isMobile)
              _selectorUnidad(alElegir: alElegir)
            else
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 520,
                  child: _selectorUnidad(alElegir: alElegir),
                ),
              ),
            const SizedBox(height: 12),
          ],
          etiqueta('Modalidad'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (nombre, cantidad) in modalidades)
                ChoiceChip(
                  label: Text('$nombre · ${_formatIntWithDots(cantidad)}'),
                  selected: _selectedModality == nombre,
                  onSelected: (_) {
                    alElegir?.call();
                    _seleccionarModalidad(nombre);
                  },
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _selectedModality == nombre
                        ? Colors.white
                        : _azulOscuro,
                  ),
                  selectedColor: _azulOscuro,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _abrirFiltrosMovil() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: _buildPanelFiltros(
            alElegir: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    );
  }

  /// Resumen de lo que está filtrando la vista, con opción de quitar cada
  /// filtro de un clic.
  Widget _buildFiltrosActivos() {
    Widget chip(String texto, VoidCallback alQuitar, {bool busqueda = false}) =>
        InputChip(
          label: Text(texto),
          onDeleted: alQuitar,
          deleteIcon: const Icon(Icons.close_rounded, size: 15),
          labelStyle: const TextStyle(
            color: _azulOscuro,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: busqueda
              ? const Color(0xFFFFF7E0)
              : const Color(0xFFEFF6FF),
          side: BorderSide(
            color: busqueda ? const Color(0xFFF5C032) : const Color(0xFFBFDBFE),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );

    final chips = <Widget>[
      if (_busqueda.isNotEmpty)
        chip(
          'Búsqueda: "$_busqueda" · toda la entidad, todas las vigencias',
          _limpiarBusqueda,
          busqueda: true,
        )
      else ...[
        if (_selectedRegionalDept != null)
          chip(
            _formatRegionalDisplayName(_selectedRegionalDept!),
            () => _seleccionarRegional(null),
          ),
        if (_dependenciaSeleccionada != null)
          chip(
            'Dependencia: ${_nombreDependencia(_dependenciaSeleccionada!)}',
            () => _seleccionarDependencia(null),
          ),
        if (_selectedUnidad != null)
          chip('Unidad: $_selectedUnidad', () => _seleccionarUnidad(null)),
        if (_selectedModality != 'Todas')
          chip(
            'Modalidad: $_selectedModality',
            () => _seleccionarModalidad('Todas'),
          ),
      ],
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...chips,
        if (chips.length > 1)
          TextButton(
            onPressed: _limpiarFiltros,
            child: const Text(
              'Limpiar todo',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // BARRA DE PESTAÑAS DEL PERFIL (SOLO LAS 4 SOLICITADAS)
  // ===========================================================================

  Widget _buildProfileTabsBar() {
    const tabs = ['Resumen', 'Contratos', 'Dependencias', 'Contratistas'];

    final tabsRow = Row(
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
        if (_isMobile) const SizedBox(width: 12) else const Spacer(),
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
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: _isMobile ? 12 : 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: _isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: tabsRow,
            )
          : tabsRow,
    );
  }

  // ===========================================================================
  // PESTAÑA 1: RESUMEN (EJECUCIÓN CONTRACTUAL + CONTRATOS DE LA ENTIDAD)
  // ===========================================================================

  Widget _buildResumenTab() {
    final pctEjecutado = _porcentajeEjecutado.clamp(0, 100);
    final pctDisponible = 100 - pctEjecutado;
    final scopeSuffix = _selectedRegionalDept != null
        ? ' (${_formatRegionalDisplayName(_selectedRegionalDept!)})'
        : '';

    return Flex(
      direction: _isMobile ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _isMobile
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        // COLUMNA IZQUIERDA DEL RESUMEN
        _flexOrFull(
          68,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TARJETA 1: Ejecución contractual de la vigencia (cifras reales de SECOP II)
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ejecución contractual · Vigencia $_activeBudgetYear$scopeSuffix',
                                style: const TextStyle(
                                  color: _azulOscuro,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Valor contratado en $_activeBudgetYear según Datos Abiertos SECOP II y su estado de ejecución.',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_isMobile)
                          OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _selectedTabIndex = 1),
                            icon: const Icon(
                              Icons.bar_chart_rounded,
                              size: 16,
                              color: _azulOscuro,
                            ),
                            label: const Text(
                              'Ver contratos →',
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
                    Flex(
                      direction: _isMobile ? Axis.vertical : Axis.horizontal,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: _isMobile
                          ? CrossAxisAlignment.stretch
                          : CrossAxisAlignment.center,
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
                                    'en ejecución',
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
                        const SizedBox(width: 28, height: 18),
                        _flexOrFull(
                          1,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Valor total contratado · vigencia $_activeBudgetYear$scopeSuffix',
                                style: const TextStyle(
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
                                  Expanded(
                                    child: Text(
                                      'Celebrados, en ejecución o terminados',
                                      style: const TextStyle(
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
                                  Expanded(
                                    child: Text(
                                      'Otros estados (borrador, suspendido, cancelado…)',
                                      style: const TextStyle(
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
              // TARJETA 2: Contratos de la entidad (totales verificados y acceso a la pestaña Contratos)
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
                    Text(
                      'Contratos de la entidad · Vigencia $_activeBudgetYear$scopeSuffix',
                      style: const TextStyle(
                        color: _azulOscuro,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Consulta y navega la totalidad de los contratos adjudicados por esta entidad en SECOP II.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Flex(
                      direction: _isMobile ? Axis.vertical : Axis.horizontal,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: _isMobile
                          ? CrossAxisAlignment.stretch
                          : CrossAxisAlignment.center,
                      children: [
                        _summaryMetricMiniCard(
                          icon: Icons.description_outlined,
                          iconColor: const Color(0xFFD97706),
                          iconBg: const Color(0xFFFEF3C7),
                          label: 'Total contratos ($_activeBudgetYear)',
                          value: _formatIntWithDots(_totalContratos),
                          trend:
                              '${(_totalContratos / _contractsPageSize).ceil()} páginas en SECOP II',
                        ),
                        const SizedBox(width: 12, height: 10),
                        _summaryMetricMiniCard(
                          icon: Icons.monetization_on_outlined,
                          iconColor: const Color(0xFF15803D),
                          iconBg: const Color(0xFFDCFCE7),
                          label: 'Valor contratado ($_activeBudgetYear)',
                          value: _formatCompactCardMillions(
                            _valorTotalContratadoCop,
                          ),
                          trend: '100% verificado SECOP II',
                        ),
                        const SizedBox(width: 12, height: 10),
                        _summaryMetricMiniCard(
                          icon: Icons.person_outline_rounded,
                          iconColor: const Color(0xFF1D4ED8),
                          iconBg: const Color(0xFFDBEAFE),
                          label: 'Contratistas únicos',
                          value: _formatIntWithDots(_contratistasUnicos),
                          trend: 'Proveedores adjudicados',
                        ),
                        const SizedBox(width: 14, height: 12),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () =>
                                setState(() => _selectedTabIndex = 1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _azulOscuro,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
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
        const SizedBox(width: 22, height: 18),
        // COLUMNA DERECHA DEL RESUMEN (Información general + Mapa de Procesos / Dependencias)
        _flexOrFull(
          32,
          Column(
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
                    _infoGeneralRow(
                      'Naturaleza jurídica',
                      'Entidad pública estatal',
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _infoGeneralRow('Tipo de entidad', widget.entity.category),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _infoGeneralRow('Nivel de gobierno', _ordenEntidad),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _infoGeneralRow('NIT en SECOP II', _nitEntidad),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _infoGeneralRow(
                      'Alcance / Regional',
                      _selectedRegionalDept == null
                          ? 'Consolidado Nacional'
                          : _formatRegionalDisplayName(_selectedRegionalDept!),
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _infoGeneralRow(
                      'Vigencia presupuestal',
                      'Año $_activeBudgetYear (Anualizado)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Dependencias internas con conteo real en SECOP II
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
                      'Dependencias internas',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_conteoDependencias.isEmpty)
                      Text(
                        _cargandoDependencias || _isLoadingLive
                            ? 'Clasificando contratos por dependencia…'
                            : 'No fue posible clasificar los contratos de este alcance.',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.2,
                        ),
                      ),
                    for (final (i, d) in _dependenciasOrdenadas().take(6).indexed) ...[
                      if (i > 0)
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      InkWell(
                        onTap: () =>
                            _seleccionarDependencia(d.id, irAContratos: true),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: d.bg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(d.icon, color: d.color, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _nombreDependencia(d),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 12.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatIntWithDots(
                                  _conteoDependencias[d.id]?.$1 ?? 0,
                                ),
                                style: const TextStyle(
                                  color: _azulOscuro,
                                  fontSize: 12,
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
                      onTap: () => setState(() {
                        _vistaDependencias = 1;
                        _selectedTabIndex = 2;
                      }),
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
    return _flexOrFull(
      1,
      Container(
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
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
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
  // PESTAÑA 2: CONTRATOS (DISCRIMINADOS POR MODALIDAD + HISTORIAL COMPLETO PAGINADO)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Reporte de contratos (PDF y hoja de cálculo)
  // ---------------------------------------------------------------------------

  /// Unidades de contratación por regional, para el criterio exacto.
  final Map<String, Future<List<UnidadContratacion>>> _unidadesReporte = {};

  Future<List<UnidadContratacion>> _unidadesPara(String? regional) =>
      _unidadesReporte.putIfAbsent(
        regional ?? '',
        () => ReporteContratosService.unidades(
          nit: _nitEntidad.replaceAll(RegExp(r'[^0-9]'), ''),
          departamento: regional,
        ),
      );

  /// Unidad que corresponde al filtro de dependencia activo (el despacho de
  /// la regional elegida en el SENA).
  UnidadContratacion? _unidadSugerida(List<UnidadContratacion> unidades) {
    if (_selectedDependencia != 'despacho' || _selectedRegionalDept == null) {
      return null;
    }
    for (final u in unidades) {
      if (u.esDespacho) return u;
    }
    return null;
  }

  /// Lo que contiene el reporte, tal como se lista en el PDF y en la hoja.
  List<(String, String)> _criteriosReporte(
    OpcionesReporte o,
    UnidadContratacion? unidad,
  ) {
    final nit = _nitEntidad.replaceAll(RegExp(r'[^0-9]'), '');
    return [
      ('Entidad', widget.entity.name),
      if (nit.isNotEmpty) ('NIT', nit),
      if (unidad != null) ...[
        if (_selectedRegionalDept != null)
          ('Regional', _formatRegionalDisplayName(_selectedRegionalDept!)),
        ('Unidad de contratación (SECOP II)', unidad.etiqueta),
      ] else if (_busqueda.isEmpty) ...[
        if (_selectedRegionalDept != null)
          ('Regional', _formatRegionalDisplayName(_selectedRegionalDept!)),
        if (_selectedUnidad != null) ('Cuenta en SECOP II', _selectedUnidad!),
        if (_dependenciaSeleccionada != null)
          (
            'Dependencia (por palabras del objeto)',
            _nombreDependencia(_dependenciaSeleccionada!),
          ),
        if (_selectedModality != 'Todas') ('Modalidad', _selectedModality),
      ] else
        ('Búsqueda', '"$_busqueda"'),
      ('Periodo (fecha de firma)', periodoTexto(o.desde, o.corte)),
      if (o.soloPrestacionServicios)
        ('Tipo', 'Prestación de servicios profesionales y de apoyo a la gestión'),
    ];
  }

  /// Contratos con los filtros de la pantalla, todas las páginas.
  Future<List<ContratoReporte>> _contratosConFiltros(
    OpcionesReporte o,
    void Function(String) progreso,
  ) async {
    final rango = (desde: o.desde, corte: o.corte);
    final where = _busqueda.isNotEmpty
        ? _buildEntityWhereClause(
            onlyYear2026: false,
            includeRegionalFilter: false,
            busqueda: _busqueda,
            rango: rango,
            soloPrestacionServicios: o.soloPrestacionServicios,
          )
        : _buildEntityWhereClause(
            onlyYear2026: false,
            includeRegionalFilter: true,
            customModalityName: _selectedModality,
            unidad: _selectedUnidad,
            dependencia: _selectedDependencia,
            rango: rango,
            soloPrestacionServicios: o.soloPrestacionServicios,
          );
    final whereEnc = Uri.encodeComponent(where);
    final conteo = await _getSecop(
      Uri.parse(
        'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
        '\$select=count(*)%20as%20n&\$where=$whereEnc',
      ),
      timeout: const Duration(seconds: 30),
    );
    final agg = jsonDecode(conteo.body);
    final total = agg is List && agg.isNotEmpty
        ? int.tryParse('${agg.first['n'] ?? 0}') ?? 0
        : 0;
    if (total > maxFilasXlsx) {
      throw ReporteException(
        'Son ${_formatIntWithDots(total)} contratos. Acota el reporte (regional, dependencia, '
        'modalidad o menos años): el máximo es ${_formatIntWithDots(maxFilasXlsx)}.',
      );
    }
    const lote = 1000;
    final filas = <ContratoReporte>[];
    final vistos = <String>{};
    for (var offset = 0; offset < total; offset += lote) {
      progreso(
        'Consultando contratos en SECOP II… ${_formatIntWithDots(math.min(offset + lote, total))} de ${_formatIntWithDots(total)}',
      );
      final r = await _getSecop(
        Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?'
          '\$select=${ReporteContratosService.campos}&\$where=$whereEnc'
          '&\$order=fecha_de_firma%20DESC,id_contrato'
          '&\$limit=$lote&\$offset=$offset',
        ),
        timeout: const Duration(seconds: 40),
      );
      if (r.statusCode != 200) {
        throw StateError('SECOP II respondió ${r.statusCode}');
      }
      for (final m in jsonDecode(r.body) as List<dynamic>) {
        if (m is! Map) continue;
        final c = ContratoReporte.fromSecop(Map<String, dynamic>.from(m));
        // Datos Abiertos a veces repite un contrato.
        if (vistos.add('${m['id_contrato'] ?? c.numero}')) filas.add(c);
      }
    }
    return filas;
  }

  Future<void> _exportarReportePdf() async {
    if (_generandoReporte) return;
    final porPalabras = _dependenciaSeleccionada != null && _busqueda.isEmpty;
    final o = await showDialog<OpcionesReporte>(
      context: context,
      builder: (_) => DialogoReporte(
        criterios: _criteriosReporte,
        unidades: _busqueda.isEmpty ? _unidadesPara(_selectedRegionalDept) : null,
        sugerida: _unidadSugerida,
        exactoPorDefecto: porPalabras,
        vigencia: _onlyCurrentYear2026 ? _activeBudgetYear : null,
        descripcionFiltros: porPalabras
            ? 'La dependencia se identifica por palabras clave del objeto del contrato: es una '
                  'aproximación y puede dejar contratos por fuera.'
            : 'Regional, modalidad, cuenta o búsqueda que tienes aplicados en la lista.',
      ),
    );
    if (o == null || !mounted) return;
    final unidad = o.unidad as UnidadContratacion?;
    final nit = _nitEntidad.replaceAll(RegExp(r'[^0-9]'), '');
    final anexo = o.formato == FormatoReporte.anexoDirectiva018;
    final nombre = unidad?.etiqueta ??
        (porPalabras ? _nombreDependencia(_dependenciaSeleccionada!) : '');
    setState(() => _generandoReporte = true);
    await generarReporteContratos(
      context,
      opciones: o,
      obtener: unidad != null
          ? (progreso) => ReporteContratosService.contratosDeUnidad(
              nit: nit,
              unidad: unidad,
              desde: o.desde,
              corte: o.corte,
              soloPrestacionServicios: o.soloPrestacionServicios,
              progreso: progreso,
            )
          : (progreso) => _contratosConFiltros(o, progreso),
      entidad: widget.entity.name,
      nit: nit,
      titulo: [
        anexo
            ? 'Anexo 1 · Relación de contratos de prestación de servicios'
            : 'Relación de contratos',
        if (nombre.isNotEmpty) nombre,
      ].join(' · '),
      criterios: _criteriosReporte(o, unidad),
      notas: notasReporte(
        o: o,
        unidad: unidad,
        dependenciaPorPalabras: unidad == null && porPalabras,
      ),
      alcanceArchivo: [
        if (anexo) 'Anexo 1',
        if (nombre.isNotEmpty) nombre else ?_selectedRegionalDept,
        '${o.desde}-${o.corte.year}',
      ].join(' '),
    );
    if (mounted) setState(() => _generandoReporte = false);
  }

  Widget _buildContratosTab() {
    final filtrado = _hayFiltrosContratos;
    final total = filtrado || _totalMatchingContractsForTable > 0
        ? _totalMatchingContractsForTable
        : _totalContratos;
    final totalCop = filtrado || _totalMatchingCopForTable > 0
        ? _totalMatchingCopForTable
        : _valorTotalContratadoCop;

    final totalPages = total <= 0 ? 1 : (total / _contractsPageSize).ceil();
    final safePage = _contractsPage.clamp(1, totalPages);
    final pageItems = filtrado || _pagedContractsList.isNotEmpty
        ? _pagedContractsList
        : _entityContracts.take(_contractsPageSize).toList();

    final buscando = _busqueda.isNotEmpty;
    final titulo = buscando
        ? 'Resultados para "$_busqueda"'
        : (_selectedUnidad ??
              (_dependenciaSeleccionada != null
                  ? _nombreDependencia(_dependenciaSeleccionada!)
                  : (_selectedModality != 'Todas'
                        ? _selectedModality
                        : 'Contratos de la entidad')));
    final alcance = buscando
        ? 'Toda la entidad · todas las vigencias'
        : [
            _selectedRegionalDept == null
                ? 'Consolidado nacional'
                : _formatRegionalDisplayName(_selectedRegionalDept!),
            _onlyCurrentYear2026
                ? 'Vigencia $_activeBudgetYear'
                : 'Historial 2015–${AniosSecop.actual}',
            if (_selectedUnidad != null && _dependenciaSeleccionada != null)
              _nombreDependencia(_dependenciaSeleccionada!),
            if ((_selectedUnidad != null || _selectedDependencia != null) &&
                _selectedModality != 'Todas')
              _selectedModality,
          ].join(' · ');

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$alcance · ${_formatIntWithDots(total)} contrato${total == 1 ? '' : 's'} · ${_formatShortMillions(totalCop)}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingContractsPage)
                  const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _azulPrimario,
                      ),
                    ),
                  ),
                if (!_isMobile)
                  Text(
                    'Página ${_formatIntWithDots(safePage)} de ${_formatIntWithDots(totalPages)}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(width: 12),
                _isMobile
                    ? IconButton(
                        tooltip: 'Exportar reporte (Excel o PDF)',
                        onPressed: _generandoReporte || total == 0
                            ? null
                            : _exportarReportePdf,
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: _azulOscuro,
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _generandoReporte || total == 0
                            ? null
                            : _exportarReportePdf,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _azulOscuro,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text(
                          'Exportar reporte',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
              ],
            ),
          ),
          _responsiveTable([
            _buildContractsTableHeaderRow(),
            if (pageItems.isEmpty)
              Padding(
                padding: const EdgeInsets.all(36),
                child: Center(
                  child: Text(
                    _isLoadingContractsPage
                        ? 'Consultando SECOP II…'
                        : buscando
                        ? 'Ningún contrato de la entidad coincide con "$_busqueda". Prueba con el número exacto, otra palabra del objeto o el nombre del contratista.'
                        : 'No hay contratos con estos filtros.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
          ]),
          _buildFullHistoryPaginationFooter(
            currentPage: safePage,
            totalPages: totalPages,
            totalRecords: total,
            onPageChanged: (p) => _fetchContractsPageFromSecop(page: p),
          ),
        ],
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
              'Unidad / Departamento',
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
    final ref =
        (c['referencia_del_contrato'] ??
                c['id_contrato'] ??
                c['proceso_de_compra'] ??
                'SECOP-II')
            .toString();
    final objeto =
        (c['objeto_del_contrato'] ??
                c['descripcion_del_proceso'] ??
                'Contrato público adjudicado')
            .toString();
    final unidad = (c['nombre_entidad'] ?? '').toString().trim();
    final dept = (c['departamento'] ?? '').toString().trim();
    final depWithRegional = [
      if (unidad.isNotEmpty) unidad,
      if (dept.isNotEmpty && dept.toUpperCase() != 'NO DEFINIDO') dept,
    ].join(' · ');

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
          MaterialPageRoute(builder: (_) => DetalleContratoScreen(contrato: c)),
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
                  depWithRegional,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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
  // PESTAÑA 3: DEPENDENCIAS Y MAPA DE PROCESOS (REGIONAL -> DESPACHO/PLANEACIÓN)
  // ===========================================================================

  /// Dependencias con contratos en el alcance actual, de mayor a menor.
  List<_DependenciaInterna> _dependenciasOrdenadas() =>
      _dependenciasInternas
          .where((d) => (_conteoDependencias[d.id]?.$1 ?? 0) > 0)
          .toList()
        ..sort(
          (a, b) => _conteoDependencias[b.id]!.$1.compareTo(
            _conteoDependencias[a.id]!.$1,
          ),
        );

  Widget _buildDependenciasTab() {
    final selector = SegmentedButton<int>(
      segments: [
        const ButtonSegment(
          value: 0,
          icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
          label: Text('Presupuesto por dependencia'),
        ),
        const ButtonSegment(
          value: 1,
          icon: Icon(Icons.account_tree_rounded, size: 18),
          label: Text('Por área temática'),
        ),
        ButtonSegment(
          value: 2,
          icon: const Icon(Icons.apartment_rounded, size: 18),
          label: Text('Cuentas en SECOP II (${_unidades.length})'),
        ),
      ],
      selected: {_vistaDependencias},
      showSelectedIcon: false,
      onSelectionChanged: (v) => setState(() => _vistaDependencias = v.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: _azulOscuro,
        selectedForegroundColor: Colors.white,
        foregroundColor: _azulOscuro,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _isMobile
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: selector,
                )
              : selector,
        ),
        const SizedBox(height: 14),
        switch (_vistaDependencias) {
          0 => PresupuestoDependenciasPanel(
            nit: _nitEntidad.replaceAll(RegExp(r'[^0-9]'), ''),
            entidad: widget.entity.name,
            anio: _onlyCurrentYear2026 ? _activeBudgetYear : null,
            departamento: _selectedRegionalDept,
            cuentaSecop: _selectedUnidad,
            alcance: [
              _selectedUnidad ??
                  (_selectedRegionalDept == null
                      ? 'Consolidado nacional'
                      : _formatRegionalDisplayName(_selectedRegionalDept!)),
              _onlyCurrentYear2026
                  ? 'vigencia $_activeBudgetYear'
                  : 'historial 2015–${AniosSecop.actual}',
            ].join(', '),
          ),
          2 => _buildUnidadesSecop(),
          _ => _buildDependenciasInternas(),
        },
      ],
    );
  }

  /// Mapa de procesos: dependencias internas agrupadas por macroproceso, con
  /// contratos y valor reales del alcance activo (regional y vigencia).
  Widget _buildDependenciasInternas() {
    final alcance = [
      _selectedRegionalDept == null
          ? 'consolidado nacional'
          : _formatRegionalDisplayName(_selectedRegionalDept!),
      _onlyCurrentYear2026
          ? 'vigencia $_activeBudgetYear'
          : 'historial 2015–${AniosSecop.actual}',
    ].join(', ');
    final totalClasificado = _conteoDependencias.values.fold<int>(
      0,
      (acc, c) => acc + c.$1,
    );

    Widget fila(_DependenciaInterna d) {
      final (contratos, valor) = _conteoDependencias[d.id] ?? (0, 0.0);
      final participacion = totalClasificado == 0
          ? 0.0
          : contratos / totalClasificado;
      final seleccionada = d.id == _selectedDependencia;
      return InkWell(
        onTap: contratos == 0
            ? null
            : () => _seleccionarDependencia(d.id, irAContratos: true),
        child: Container(
          color: seleccionada ? const Color(0xFFEFF6FF) : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: d.bg, shape: BoxShape.circle),
                child: Icon(d.icon, color: d.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nombreDependencia(d),
                      style: TextStyle(
                        color: contratos == 0
                            ? const Color(0xFF94A3B8)
                            : _azulOscuro,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: participacion,
                        minHeight: 5,
                        color: d.color,
                        backgroundColor: const Color(0xFFF1F5F9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: _isMobile ? 64 : 110,
                child: Text(
                  '${_formatIntWithDots(contratos)}\n${(participacion * 100).toStringAsFixed(participacion < 0.1 ? 1 : 0)} %',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
              if (!_isMobile)
                SizedBox(
                  width: 130,
                  child: Text(
                    _formatCompactCardMillions(valor),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(
                width: 32,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mapa de procesos y dependencias internas',
                  style: TextStyle(
                    color: _azulOscuro,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Contratos y valor reales de SECOP II ($alcance). SECOP II no publica la dependencia que contrata: '
                  'cada contrato se asigna a una sola dependencia según las palabras de su objeto. Haz clic en una para ver sus contratos.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (_conteoDependencias.isEmpty)
            Padding(
              padding: const EdgeInsets.all(36),
              child: Center(
                child: Text(
                  _cargandoDependencias || _isLoadingLive
                      ? 'Clasificando contratos por dependencia…'
                      : 'No fue posible clasificar los contratos de este alcance. Intenta “Actualizar datos”.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            for (final macro in _macroprocesos) ...[
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.fromLTRB(20, 9, 20, 9),
                child: Text(
                  'PROCESOS ${macro.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              for (final d in _dependenciasInternas.where(
                (d) => d.macroproceso == macro,
              )) ...[
                fila(d),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ],
            ],
        ],
      ),
    );
  }

  Widget _buildUnidadesSecop() {
    final consulta = _normalizar(_filtroUnidades.trim());
    final visibles = consulta.isEmpty
        ? _unidades
        : _unidades
              .where(
                (u) => _normalizar(
                  '${u.nombre} ${u.departamento}',
                ).contains(consulta),
              )
              .toList();
    final alcance = [
      _selectedRegionalDept == null
          ? 'consolidado nacional'
          : _formatRegionalDisplayName(_selectedRegionalDept!),
      _onlyCurrentYear2026
          ? 'vigencia $_activeBudgetYear'
          : 'historial 2015–${AniosSecop.actual}',
    ].join(', ');

    const estiloCabecera = TextStyle(
      color: _azulOscuro,
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
    );

    final filtro = SizedBox(
      width: _isMobile ? double.infinity : 300,
      child: TextField(
        onChanged: (v) => setState(() => _filtroUnidades = v),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Filtrar unidades (ej. Cesar, centro, apoyo)…',
          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.filter_list_rounded, size: 18),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unidades de contratación (${_unidades.length})',
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Cuentas que contratan en SECOP II con el NIT de la entidad ($alcance). '
                        'Haz clic en una para ver sus contratos.',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_unidades.length > 8) filtro,
              ],
            ),
          ),
          if (_unidades.isEmpty)
            Padding(
              padding: const EdgeInsets.all(36),
              child: Center(
                child: Text(
                  _isLoadingLive
                      ? 'Consultando unidades en SECOP II…'
                      : 'SECOP II no reporta unidades para este alcance.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            _responsiveTable([
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Text('Unidad', style: estiloCabecera),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('Departamento', style: estiloCabecera),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Contratos',
                        textAlign: TextAlign.right,
                        style: estiloCabecera,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Valor',
                        textAlign: TextAlign.right,
                        style: estiloCabecera,
                      ),
                    ),
                    SizedBox(width: 36),
                  ],
                ),
              ),
              if (visibles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      'Ninguna unidad coincide con el filtro.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              for (var i = 0; i < visibles.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildFilaUnidad(visibles[i]),
              ],
            ]),
          if (_unidades.length == 1)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                'Esta entidad contrata desde una sola cuenta en SECOP II, así que no tiene unidades separadas.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilaUnidad(_UnidadContratante u) {
    final seleccionada = u.nombre == _selectedUnidad;
    return InkWell(
      onTap: () => _seleccionarUnidad(u.nombre, irAContratos: true),
      child: Container(
        color: seleccionada ? const Color(0xFFEFF6FF) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Text(
                u.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                u.departamento.isEmpty ? '—' : u.departamento,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatIntWithDots(u.contractsCount),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _formatCompactCardMillions(u.totalCop),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(
              width: 36,
              child: Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
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
        : ((safePage - 1) * _contractorsPageSize).clamp(
            0,
            _contractorsList.length - 1,
          );
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
                if (!_isMobile)
                  Text(
                    '${_contractorsList.length} contratistas en muestra activa',
                    style: const TextStyle(
                      color: _azulPrimario,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          _responsiveTable([
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
                          nit: pageItems[i].document,
                          documentoProveedor: pageItems[i].document,
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
          ]),
          _buildFullHistoryPaginationFooter(
            currentPage: safePage,
            totalPages: totalPages,
            totalRecords: _contractorsList.length,
            onPageChanged: (p) => setState(() => _contractorsPage = p),
          ),
        ],
      ),
    );
  }

  /// Paginador completo que permite navegar entre miles de páginas (Primera, Anterior, Salto directo, Siguiente, Última)
  Widget _buildFullHistoryPaginationFooter({
    required int currentPage,
    required int totalPages,
    required int totalRecords,
    required ValueChanged<int> onPageChanged,
  }) {
    final summary = Text(
      'Total en SECOP II: ${_formatIntWithDots(totalRecords)} registros (${_formatIntWithDots(totalPages)} páginas)',
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
    final controls = <Widget>[
      OutlinedButton(
        onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: const Text('« Primera', style: TextStyle(fontSize: 11.5)),
      ),
      const SizedBox(width: 6),
      OutlinedButton.icon(
        onPressed: currentPage > 1
            ? () => onPageChanged(currentPage - 1)
            : null,
        icon: const Icon(Icons.chevron_left_rounded, size: 16),
        label: const Text('Anterior', style: TextStyle(fontSize: 11.5)),
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: InkWell(
          onTap: totalPages > 1
              ? () => _showJumpToPageDialog(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPageChanged: onPageChanged,
                )
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pág. ${_formatIntWithDots(currentPage)} de ${_formatIntWithDots(totalPages)}',
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.edit_location_alt_outlined,
                  size: 13,
                  color: _azulPrimario,
                ),
              ],
            ),
          ),
        ),
      ),
      OutlinedButton.icon(
        onPressed: currentPage < totalPages
            ? () => onPageChanged(currentPage + 1)
            : null,
        icon: const Icon(Icons.chevron_right_rounded, size: 16),
        label: const Text('Siguiente', style: TextStyle(fontSize: 11.5)),
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
      const SizedBox(width: 6),
      OutlinedButton(
        onPressed: currentPage < totalPages
            ? () => onPageChanged(math.min(totalPages, 6000))
            : null,
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: const Text('Última »', style: TextStyle(fontSize: 11.5)),
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 12 : 22,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFD),
        border: Border(top: BorderSide(color: Color(0xFFEEF2F6))),
      ),
      child: _isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summary,
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: controls),
                ),
              ],
            )
          : Row(children: [summary, const Spacer(), ...controls]),
    );
  }

  void _showJumpToPageDialog({
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    final controller = TextEditingController(text: '$currentPage');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Ir a una página de contratos',
          style: TextStyle(
            color: _azulOscuro,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingresa un número de página entre 1 y ${_formatIntWithDots(totalPages)}:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ej: 150',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(controller.text.trim()) ?? currentPage;
              Navigator.pop(ctx);
              onPageChanged(p.clamp(1, totalPages));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _azulOscuro,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ir a página'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contenido = switch (_selectedTabIndex) {
      1 => _buildContratosTab(),
      2 => _buildDependenciasTab(),
      3 => _buildContratistasTab(),
      _ => _buildResumenTab(),
    };

    // Encabezado, pestañas y búsqueda quedan fijos (≈ 20 % del alto en
    // escritorio); solo el contenido de la pestaña se desplaza.
    return Scaffold(
      backgroundColor: _bgCrema,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCompactHeader(),
            _buildProfileTabsBar(),
            _buildBarraExploracion(),
            Expanded(
              child: SingleChildScrollView(
                padding: _isMobile
                    ? const EdgeInsets.fromLTRB(12, 14, 12, 28)
                    : const EdgeInsets.fromLTRB(32, 20, 32, 36),
                child: contenido,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // UTILIDADES RESPONSIVE (CELULAR)
  // ===========================================================================

  bool get _isMobile => MediaQuery.sizeOf(context).width < 800;

  /// En escritorio envuelve en `Expanded`; en celular devuelve el widget a ancho completo.
  Widget _flexOrFull(int flex, Widget child) =>
      _isMobile ? child : Expanded(flex: flex, child: child);

  /// Tablas anchas: en celular se desplazan horizontalmente para no desbordarse.
  Widget _responsiveTable(List<Widget> rows) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
    if (!_isMobile) return column;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: 880, child: column),
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
