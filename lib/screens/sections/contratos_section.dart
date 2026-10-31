import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../data/colombia_secop_catalog.dart';
import '../../services/favorites_service.dart';
import '../../services/security_service.dart';
import '../../utils/anios_secop.dart';
import '../../utils/app_scroll_behavior.dart';
import '../../utils/contract_financial_calculator.dart';
import '../../utils/csv_exporter.dart';
import '../../utils/secop_i.dart';
import '../../widgets/user_profile_header_action.dart';
import '../detalle_screen.dart';
import '../perfil_contratista_screen.dart';

class ContractRecord {
  const ContractRecord({
    required this.title,
    required this.processCode,
    required this.valueFormatted,
    required this.numericValue,
    required this.entity,
    required this.department,
    required this.contractor,
    required this.contractorId,
    required this.startDate,
    required this.endDate,
    required this.year,
    required this.modality,
    required this.status,
    required this.location,
    required this.orden,
    required this.color,
    required this.iconBg,
    required this.icon,
    required this.rawSecopJson,
  });

  final String title;
  final String processCode;
  final String valueFormatted;
  final double numericValue;
  final String entity;
  final String department;
  final String contractor;
  final String contractorId;
  final String startDate;
  final String endDate;
  final String year;
  final String modality;
  final String status;
  final String location;
  final String orden;
  final Color color;
  final Color iconBg;
  final IconData icon;
  final Map<String, dynamic> rawSecopJson;

  Map<String, dynamic> toSecopMap() => rawSecopJson;
}

class ContratosSection extends StatefulWidget {
  const ContratosSection({
    super.key,
    required this.topSearchController,
    required this.onTopSearchSubmitted,
    required this.onLogout,
  });

  final TextEditingController topSearchController;
  final ValueChanged<String> onTopSearchSubmitted;
  final VoidCallback onLogout;

  @override
  State<ContratosSection> createState() => _ContratosSectionState();
}

class _ContratosSectionState extends State<ContratosSection> {
  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _azulPrimario = Color(0xFF1D4ED8);
  static const Color _doradoPlataforma = Color(0xFFF5B82E);
  static const Color _cremaFondo = Color(0xFFFAF5EA);
  static const Color _cremaTarjeta = Color(0xFFFFFDF8);
  static const Color _bordeCalido = Color(0xFFE6DEC8);
  static const int _pageSize = 10;
  static const int _initialResultsLimit = 250;
  static const int _searchResultsLimit = 600;
  static final Map<String, List<ContractRecord>> _fastContractsQueryCache = {};
  static const String _secopSelectFields =
      'id_contrato,referencia_del_contrato,proceso_de_compra,nombre_entidad,'
      'nit_entidad,orden,departamento,ciudad,sector,estado_contrato,'
      'modalidad_de_contratacion,tipo_de_contrato,valor_del_contrato,'
      'proveedor_adjudicado,tipodocproveedor,documento_proveedor,'
      'fecha_de_firma,fecha_de_inicio_del_contrato,fecha_de_fin_del_contrato,'
      'objeto_del_contrato,descripcion_del_proceso,urlproceso';

  final TextEditingController _contractsSearchController =
      TextEditingController();
  Timer? _searchDebounce;
  int _latestRequestId = 0;

  // Todos los filtros inician en blanco para que el usuario elija libremente qué consultar
  String _selectedSector = '';
  String _selectedOrden = '';
  String _selectedDepartamento = '';
  String _selectedMunicipio = '';
  String _selectedEntidad = '';
  String _selectedDependencia = '';
  String _selectedModalidad = '';
  String _selectedEstado = '';
  String _selectedAnio = '';

  double? _minValueFilter;
  double? _maxValueFilter;
  String _sortBy = 'Más recientes';
  int _currentPage = 1;
  bool _isLoadingSecop = false;
  List<ContractRecord> _secopContracts = [];
  Set<String> _favoriteIds = {};

  static const List<
      ({
        String id,
        String label,
        String subtitle,
        IconData icon,
        Color accentColor,
        Color softBg,
        List<String> soqlKeywords,
      })> _sectorMacroOptions = [
    (
      id: '',
      label: 'Todos',
      subtitle: 'Todos los sectores',
      icon: Icons.apps_rounded,
      accentColor: Color(0xFFF5B82E),
      softBg: Color(0xFFFFF4D6),
      soqlKeywords: [],
    ),
    (
      id: 'Salud',
      label: 'Salud',
      subtitle: 'Hospitales y salud pública',
      icon: Icons.local_hospital_outlined,
      accentColor: Color(0xFFDC2626),
      softBg: Color(0xFFFEE2E2),
      soqlKeywords: [
        'SALUD',
        'HOSPITAL',
        'CLINICA',
        'MEDICAMENT',
        'SANIDAD',
        'ENFERMER',
        'ODONTOLOG',
        'EPIDEMIOLOG',
        'E.S.E',
      ],
    ),
    (
      id: 'Educación',
      label: 'Educación',
      subtitle: 'Colegios, PAE y universidades',
      icon: Icons.school_outlined,
      accentColor: Color(0xFF2563EB),
      softBg: Color(0xFFDBEAFE),
      soqlKeywords: [
        'EDUCACION',
        'EDUCACIÓN',
        'ESCOLAR',
        'COLEGIO',
        'UNIVERSIDAD',
        'SENA',
        'DOCENTE',
        'ESTUDIANT',
        'ALIMENTACION ESCOLAR',
        'INSTITUCION EDUCATIVA',
      ],
    ),
    (
      id: 'Obras',
      label: 'Obras',
      subtitle: 'Infraestructura y vías',
      icon: Icons.construction_rounded,
      accentColor: Color(0xFFD97706),
      softBg: Color(0xFFFEF3C7),
      soqlKeywords: [
        'OBRA',
        'INFRAESTRUCTURA',
        'PAVIMENT',
        'MALLA VIAL',
        'CONSTRUCCION',
        'CONSTRUCCIÓN',
        'ADECUACION',
        'ADECUACIÓN',
        'MANTENIMIENTO VIAL',
        'ALCANTARILLADO',
        'ACUEDUCTO',
        'INTERVENTORIA',
      ],
    ),
    (
      id: 'Seguridad',
      label: 'Seguridad',
      subtitle: 'Defensa, policía y convivencia',
      icon: Icons.shield_outlined,
      accentColor: Color(0xFF1E3A8A),
      softBg: Color(0xFFE0E7FF),
      soqlKeywords: [
        'SEGURIDAD',
        'DEFENSA',
        'POLICIA',
        'POLICÍA',
        'EJERCITO',
        'EJÉRCITO',
        'CONVIVENCIA',
        'VIGILANCIA',
        'JUSTICIA',
        'BOMBEROS',
        'RIESGO',
        'TRANSITO',
        'TRÁNSITO',
      ],
    ),
    (
      id: 'Tecnología',
      label: 'Tecnología',
      subtitle: 'TIC, software y sistemas',
      icon: Icons.computer_rounded,
      accentColor: Color(0xFF7C3AED),
      softBg: Color(0xFFF3E8FF),
      soqlKeywords: [
        'TECNOLOG',
        'SISTEMAS',
        'SOFTWARE',
        'COMPUTO',
        'CÓMPUTO',
        'CONECTIVIDAD',
        'INTERNET',
        'DIGITAL',
        'INFORMATIC',
        'INFORMÁTIC',
      ],
    ),
    (
      id: 'Ambiente',
      label: 'Ambiente',
      subtitle: 'Sostenibilidad y agro',
      icon: Icons.eco_outlined,
      accentColor: Color(0xFF16A34A),
      softBg: Color(0xFFDCFCE7),
      soqlKeywords: [
        'AMBIENT',
        'SOSTENIBLE',
        'FORESTAL',
        'ARBORIZACION',
        'ZONAS VERDES',
        'AGROPECUARI',
        'GANADER',
        'AGRICOL',
        'AGRÍCOL',
        'DAGMA',
        'CORPO',
      ],
    ),
    (
      id: 'Social y Cultura',
      label: 'Social y Cultura',
      subtitle: 'Deporte, cultura y bienestar',
      icon: Icons.diversity_3_rounded,
      accentColor: Color(0xFFDB2777),
      softBg: Color(0xFFFCE7F3),
      soqlKeywords: [
        'SOCIAL',
        'CULTUR',
        'DEPORT',
        'RECREAC',
        'FAMILIA',
        'ICBF',
        'JUVENTUD',
        'VICTIMAS',
        'VÍCTIMAS',
        'MUJER',
        'ADULTO MAYOR',
      ],
    ),
  ];

  static const List<String> _dependenciaOptions = [
    'Secretaría General',
    'Secretaría de Obras Públicas',
    'Secretaría de Educación',
    'Secretaría de Salud',
    'Secretaría de Hacienda',
    'Secretaría de Gobierno',
    'Secretaría de Tránsito y Transporte',
    'Secretaría de Desarrollo Económico',
    'Secretaría de Ambiente',
    'Oficina de Planeación',
    'Oficina Asesora Jurídica',
    'Gestión Social y Comunitaria',
    'Cultura, Deporte y Recreación',
    'Tecnologías de la Información (TIC)',
    'Servicios Públicos y Saneamiento',
    'Vivienda e Infraestructura',
    'Defensa y Seguridad',
    'Control Interno y Vigilancia',
  ];

  static const List<String> _modalidadOptions = [
    'Contratación directa',
    'Mínima cuantía',
    'Selección abreviada menor cuantía',
    'Selección abreviada subasta inversa',
    'Licitación pública',
    'Concurso de méritos',
    'Contratación régimen especial',
  ];

  static const List<String> _estadoOptions = [
    'En ejecución',
    'Aprobado',
    'Modificado',
    'Terminado',
    'Cerrado',
    'Liquidado',
  ];

  static List<String> get _anioOptions =>
      [for (final a in AniosSecop.disponibles) '$a'];

  // Semilla inicial con contratos reales de SECOP II de distintos órdenes y regiones del país
  static final List<Map<String, dynamic>> _verifiedInitialSecopRaw = [
    {
      'id_contrato': 'CO1.PCCNTR.10083619',
      'referencia_del_contrato': '4133.010.26.1.2234-2026',
      'proceso_de_compra': 'CO1.BDOS.11036736',
      'nombre_entidad':
          'DEPARTAMENTO ADMINISTRATIVO DE GESTION DEL MEDIO AMBIENTE DAGMA',
      'orden': 'Territorial',
      'departamento': 'Valle del Cauca',
      'ciudad': 'Cali',
      'sector': 'Ambiente y Desarrollo Sostenible',
      'estado_contrato': 'Aprobado',
      'modalidad_de_contratacion': 'Contratación directa',
      'tipo_de_contrato': 'Prestación de servicios',
      'valor_del_contrato': '21108000',
      'proveedor_adjudicado': 'SANDRA MILENA ERAZO PULGARIN',
      'tipodocproveedor': 'Cédula de Ciudadanía',
      'documento_proveedor': '66900091',
      'fecha_de_firma': '2026-10-17T00:00:00.000',
      'fecha_de_inicio_del_contrato': '2026-10-17T00:00:00.000',
      'fecha_de_fin_del_contrato': '2026-12-31T00:00:00.000',
      'objeto_del_contrato':
          'PRESTAR LOS SERVICIOS PROFESIONALES ESPECIALIZADOS CON EL FIN DE BRINDAR SOPORTE A LAS ACTIVIDADES ADELANTADAS EN EL DEPARTAMENTO ADMINISTRATIVO DE GESTIÓN DEL MEDIO AMBIENTE - DAGMA EN LA EJECUCIÓN DEL PROYECTO FORTALECIMIENTO INSTITUCIONAL DE SANTIAGO DE CALI.',
      'descripcion_del_proceso':
          'PRESTAR LOS SERVICIOS PROFESIONALES ESPECIALIZADOS CON EL FIN DE BRINDAR SOPORTE A LAS ACTIVIDADES ADELANTADAS EN EL DEPARTAMENTO ADMINISTRATIVO DE GESTIÓN DEL MEDIO AMBIENTE - DAGMA EN LA EJECUCIÓN DEL PROYECTO FORTALECIMIENTO INSTITUCIONAL DE SANTIAGO DE CALI.',
      'urlproceso': {
        'url':
            'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.11079240&isFromPublicArea=True&isModal=true&asPopupView=true',
      },
    },
    {
      'id_contrato': 'CO1.PCCNTR.10084005',
      'referencia_del_contrato': 'PSP-93-2026',
      'proceso_de_compra': 'CO1.BDOS.11036511',
      'nombre_entidad': 'MUNICIPIO DE GUADALUPE ANTIOQUIA',
      'orden': 'Territorial',
      'departamento': 'Antioquia',
      'ciudad': 'Guadalupe',
      'sector': 'Servicio Público',
      'estado_contrato': 'En ejecución',
      'modalidad_de_contratacion': 'Contratación directa',
      'tipo_de_contrato': 'Prestación de servicios',
      'valor_del_contrato': '12000000',
      'proveedor_adjudicado': 'Maure Micel Hidalgo Arenas',
      'tipodocproveedor': 'Cédula de Ciudadanía',
      'documento_proveedor': '1047964017',
      'fecha_de_firma': '2026-10-17T00:00:00.000',
      'fecha_de_inicio_del_contrato': '2026-10-17T00:00:00.000',
      'fecha_de_fin_del_contrato': '2026-12-31T00:00:00.000',
      'objeto_del_contrato':
          'APOYO A LA GESTIÓN ADMINISTRATIVA EN LA EJECUCIÓN DE ACTIVIDADES TÉCNICAS Y OPERATIVAS EN EL ÁREA DE PAGOS EN LA TESORERÍA DEL MUNICIPIO DE GUADALUPE, ANTIOQUIA',
      'descripcion_del_proceso':
          'APOYO A LA GESTIÓN ADMINISTRATIVA EN LA EJECUCIÓN DE ACTIVIDADES TÉCNICAS Y OPERATIVAS EN EL ÁREA DE PAGOS EN LA TESORERÍA DEL MUNICIPIO DE GUADALUPE, ANTIOQUIA',
      'urlproceso': {
        'url':
            'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.11079312&isFromPublicArea=True&isModal=true&asPopupView=true',
      },
    },
    {
      'id_contrato': 'CO1.PCCNTR.10081844',
      'referencia_del_contrato': 'CONTRATO 5149-26',
      'proceso_de_compra': 'CO1.BDOS.11034734',
      'nombre_entidad': 'ALCALDIA DISTRITAL BARRANCABERMEJA',
      'orden': 'Territorial',
      'departamento': 'Santander',
      'ciudad': 'Barrancabermeja',
      'sector': 'Servicio Público',
      'estado_contrato': 'Aprobado',
      'modalidad_de_contratacion': 'Contratación directa',
      'tipo_de_contrato': 'Prestación de servicios',
      'valor_del_contrato': '9000000',
      'proveedor_adjudicado': 'DANIEL PUENTES',
      'tipodocproveedor': 'Cédula de Ciudadanía',
      'documento_proveedor': '1098821514',
      'fecha_de_firma': '2026-10-17T00:00:00.000',
      'fecha_de_inicio_del_contrato': '2026-10-17T00:00:00.000',
      'fecha_de_fin_del_contrato': '2026-12-18T00:00:00.000',
      'objeto_del_contrato':
          'PRESTACIÓN DE SERVICIOS PROFESIONALES COMO ABOGADO ESPECIALIZADO PARA APOYAR LOS PROCESOS JURÍDICOS Y ADMINISTRATIVOS EN LA DIRECCIÓN DE JUVENTUDES DEL DISTRITO DE BARRANCABERMEJA, SANTANDER.',
      'descripcion_del_proceso':
          'PRESTACIÓN DE SERVICIOS PROFESIONALES COMO ABOGADO ESPECIALIZADO PARA APOYAR LOS PROCESOS JURÍDICOS Y ADMINISTRATIVOS EN LA DIRECCIÓN DE JUVENTUDES DEL DISTRITO DE BARRANCABERMEJA, SANTANDER.',
      'urlproceso': {
        'url':
            'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.11077424&isFromPublicArea=True&isModal=true&asPopupView=true',
      },
    },
    {
      'id_contrato': 'CO1.PCCNTR.10081126',
      'referencia_del_contrato': 'PRESTACION DE SERVICIOS N.055 DE 2026',
      'proceso_de_compra': 'CO1.BDOS.11033349',
      'nombre_entidad': 'MUNICIPIO DE VITERBO',
      'orden': 'Territorial',
      'departamento': 'Caldas',
      'ciudad': 'Viterbo',
      'sector': 'Transporte',
      'estado_contrato': 'En ejecución',
      'modalidad_de_contratacion': 'Contratación directa',
      'tipo_de_contrato': 'Prestación de servicios',
      'valor_del_contrato': '7400000',
      'proveedor_adjudicado': 'DANIELA IDARRAGA PATIÑO',
      'tipodocproveedor': 'Cédula de Ciudadanía',
      'documento_proveedor': '1061371525',
      'fecha_de_firma': '2026-10-17T00:00:00.000',
      'fecha_de_inicio_del_contrato': '2026-10-17T00:00:00.000',
      'fecha_de_fin_del_contrato': '2026-12-30T00:00:00.000',
      'objeto_del_contrato':
          'PRESTAR LOS SERVICIOS COMO AGENTE DE TRÁNSITO EN EL MUNICIPIO DE VITERBO, CALDAS, PARA REGULAR LA CIRCULACIÓN VEHICULAR Y PEATONAL Y REALIZAR ACTIVIDADES DE PREVENCIÓN, SEGURIDAD Y EDUCACIÓN VIAL.',
      'descripcion_del_proceso':
          'PRESTAR LOS SERVICIOS COMO AGENTE DE TRÁNSITO EN EL MUNICIPIO DE VITERBO, CALDAS, PARA REGULAR LA CIRCULACIÓN VEHICULAR Y PEATONAL Y REALIZAR ACTIVIDADES DE PREVENCIÓN, SEGURIDAD Y EDUCACIÓN VIAL.',
      'urlproceso': {
        'url':
            'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.11076238&isFromPublicArea=True&isModal=true&asPopupView=true',
      },
    },
    {
      'id_contrato': 'CO1.PCCNTR.10034547',
      'referencia_del_contrato': '3378-SGR DE 2026',
      'proceso_de_compra': 'CO1.BDOS.10822006',
      'nombre_entidad': 'ALCALDIA MUNICIPAL DE VALLEDUPAR',
      'orden': 'Territorial',
      'departamento': 'Cesar',
      'ciudad': 'Valledupar',
      'sector': 'Salud y Protección Social',
      'estado_contrato': 'En ejecución',
      'modalidad_de_contratacion': 'Selección Abreviada de Menor Cuantía',
      'tipo_de_contrato': 'Prestación de servicios',
      'valor_del_contrato': '194300000',
      'proveedor_adjudicado': 'FUNDACION SEMBREMOS PAZ',
      'tipodocproveedor': 'NIT',
      'documento_proveedor': '9001960987',
      'fecha_de_firma': '2026-10-06T00:00:00.000',
      'fecha_de_inicio_del_contrato': '2026-10-08T00:00:00.000',
      'fecha_de_fin_del_contrato': '2026-12-31T00:00:00.000',
      'objeto_del_contrato':
          'PRESTACIÓN DE SERVICIOS PARA EL APOYO A LOS PROCESOS DE DESARROLLO DE CAPACIDADES Y PARTICIPACIÓN SOCIAL EN EL MARCO DEL PAS 2026 DE LA SECRETARÍA LOCAL DE SALUD DEL MUNICIPIO DE VALLEDUPAR CESAR',
      'descripcion_del_proceso':
          'PRESTACIÓN DE SERVICIOS PARA EL APOYO A LOS PROCESOS DE DESARROLLO DE CAPACIDADES Y PARTICIPACIÓN SOCIAL EN EL MARCO DEL PAS 2026 DE LA SECRETARÍA LOCAL DE SALUD DEL MUNICIPIO DE VALLEDUPAR CESAR',
      'urlproceso': {
        'url':
            'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.10942578&isFromPublicArea=True&isModal=true&asPopupView=true',
      },
    },
    {
      'id_contrato': 'CO1.PCCNTR.10043923',
      'referencia_del_contrato': '2026 03 0318',
      'proceso_de_compra': 'CO1.BDOS.10926280',
      'nombre_entidad': 'GOBERNACION DEL DEPARTAMENTO DEL CESAR',
      'orden': 'Territorial',
      'departamento': 'Cesar',
      'ciudad': 'Valledupar',
      'sector': 'Servicio Público',
      'estado_contrato': 'Aprobado',
      'modalidad_de_contratacion':
          'Contratación régimen especial (con ofertas)',
      'tipo_de_contrato': 'Decreto 092 de 2017',
      'valor_del_contrato': '2869923407',
      'proveedor_adjudicado':
          'ASOCIACION COLOMBIANA DE LA MICRO PEQUEÑA Y MEDIANA EMPRESA REGIONAL NDS',
      'tipodocproveedor': 'NIT',
      'documento_proveedor': '890506617',
      'fecha_de_firma': '2026-10-09T00:00:00.000',
      'fecha_de_inicio_del_contrato': '2026-10-09T00:00:00.000',
      'fecha_de_fin_del_contrato': '2027-02-07T00:00:00.000',
      'objeto_del_contrato':
          'AUNAR ESFUERZOS PARA EL FORTALECIMIENTO DE LAS CAPACIDADES SOCIOEMPRESARIALES COMO ALTERNATIVA DE RECONVERSIÓN LABORAL POST-MINERÍA EN EL DEPARTAMENTO DEL CESAR',
      'descripcion_del_proceso':
          'AUNAR ESFUERZOS PARA EL FORTALECIMIENTO DE LAS CAPACIDADES SOCIOEMPRESARIALES COMO ALTERNATIVA DE RECONVERSIÓN LABORAL POST-MINERÍA EN EL DEPARTAMENTO DEL CESAR',
      'urlproceso': {
        'url':
            'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.10969795&isFromPublicArea=True&isModal=true&asPopupView=true',
      },
    },
    {
      'id_contrato': 'CO1.PCCNTR.10055924',
      'referencia_del_contrato': '295-2026',
      'proceso_de_compra': 'CO1.BDOS.10820008',
      'nombre_entidad': 'INSTITUTO DE DEPORTE, RECREACIÓN Y ACTIVIDAD FÍSICA',
      'orden': 'Territorial',
      'departamento': 'Cesar',
      'ciudad': 'Valledupar',
      'sector': 'deportes',
      'estado_contrato': 'En ejecución',
      'modalidad_de_contratacion': 'Selección Abreviada de Menor Cuantía',
      'tipo_de_contrato': 'Obra',
      'valor_del_contrato': '453721485',
      'proveedor_adjudicado': 'TAICO SAS',
      'tipodocproveedor': 'NIT',
      'documento_proveedor': '901037937',
      'fecha_de_firma': '2026-10-09T00:00:00.000',
      'fecha_de_inicio_del_contrato': '2026-10-09T00:00:00.000',
      'fecha_de_fin_del_contrato': '2026-12-31T00:00:00.000',
      'objeto_del_contrato':
          'MANTENIMIENTO Y ADECUACIÓN DE LA CAPA DE RODADURA PISTA BMX, BARRIO VILLA DARIANA MUNICIPIO DE VALLEDUPAR.',
      'descripcion_del_proceso':
          'MANTENIMIENTO Y ADECUACIÓN DE LA CAPA DE RODADURA PISTA BMX, BARRIO VILLA DARIANA MUNICIPIO DE VALLEDUPAR.',
      'urlproceso': {
        'url':
            'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.10954195&isFromPublicArea=True&isModal=true&asPopupView=true',
      },
    },
    {
      'id_contrato': 'CO1.PCCNTR.10027994',
      'referencia_del_contrato': 'CMA-001-2026 EICE AMV',
      'proceso_de_compra': 'CO1.BDOS.10844433',
      'nombre_entidad':
          'EMPRESA INDUSTRIAL Y COMERCIAL DEL ESTADO AREA METROPOLITANA DE VALLEDUPAR E.I.C.E. AMV',
      'orden': 'Territorial',
      'departamento': 'Cesar',
      'ciudad': 'Valledupar',
      'sector': 'Ambiente y Desarrollo Sostenible',
      'estado_contrato': 'Aprobado',
      'modalidad_de_contratacion': 'Concurso de méritos abierto',
      'tipo_de_contrato': 'Interventoría',
      'valor_del_contrato': '261665046',
      'proveedor_adjudicado': 'INGENIERIAS Y OBRAS MQ S.A.S',
      'tipodocproveedor': 'NIT',
      'documento_proveedor': '901006399',
      'fecha_de_firma': '2026-10-09T00:00:00.000',
      'fecha_de_inicio_del_contrato': '2026-10-09T00:00:00.000',
      'fecha_de_fin_del_contrato': '2027-03-19T00:00:00.000',
      'objeto_del_contrato':
          'INTERVENTORÍA TÉCNICA, ADMINISTRATIVA, FINANCIERA Y JURÍDICA AL FORTALECIMIENTO DEL SECTOR DE LA GANADERÍA BOVINA MEDIANTE LA IMPLEMENTACIÓN DE UN SISTEMA INTEGRAL DE PRODUCCIÓN DE SILO DE MAÍZ',
      'descripcion_del_proceso':
          'INTERVENTORÍA TÉCNICA, ADMINISTRATIVA, FINANCIERA Y JURÍDICA AL FORTALECIMIENTO DEL SECTOR DE LA GANADERÍA BOVINA MEDIANTE LA IMPLEMENTACIÓN DE UN SISTEMA INTEGRAL DE PRODUCCIÓN DE SILO DE MAÍZ',
      'urlproceso': {
        'url':
            'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.10934269&isFromPublicArea=True&isModal=true&asPopupView=true',
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _secopContracts = _buildContractsFromRawList(_verifiedInitialSecopRaw);
    _loadFavorites();
    _fetchLiveSecopContracts(silent: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _contractsSearchController.dispose();
    super.dispose();
  }

  int get _activeFiltersCount {
    var count = 0;
    if (_selectedSector.isNotEmpty) count++;
    if (_selectedOrden.isNotEmpty) count++;
    if (_selectedDepartamento.isNotEmpty) count++;
    if (_selectedMunicipio.isNotEmpty) count++;
    if (_selectedEntidad.isNotEmpty) count++;
    if (_selectedDependencia.isNotEmpty) count++;
    if (_selectedModalidad.isNotEmpty) count++;
    if (_selectedEstado.isNotEmpty) count++;
    if (_selectedAnio.isNotEmpty) count++;
    if (_minValueFilter != null) count++;
    if (_maxValueFilter != null) count++;
    return count;
  }

  String? _buildSectorSoqlClause(String sectorId) {
    if (sectorId.isEmpty) return null;
    final match =
        _sectorMacroOptions.where((s) => s.id == sectorId).firstOrNull;
    if (match == null || match.soqlKeywords.isEmpty) return null;

    final conditions = <String>[];
    for (final kw in match.soqlKeywords) {
      conditions.add("upper(sector) LIKE '%$kw%'");
      conditions.add("upper(objeto_del_contrato) LIKE '%$kw%'");
      conditions.add("upper(nombre_entidad) LIKE '%$kw%'");
    }
    if (sectorId == 'Obras') {
      conditions.add("upper(tipo_de_contrato) LIKE '%OBRA%'");
    }
    return '(${conditions.join(' OR ')})';
  }

  bool _matchesSectorMacroFilter(ContractRecord contract, String sectorId) {
    if (sectorId.isEmpty) return true;
    final match =
        _sectorMacroOptions.where((s) => s.id == sectorId).firstOrNull;
    if (match == null || match.soqlKeywords.isEmpty) return true;

    final raw = contract.rawSecopJson;
    final combined = _normalizar(
      '${contract.title} ${contract.entity} ${contract.department} '
      '${raw['sector'] ?? ''} ${raw['tipo_de_contrato'] ?? ''} '
      '${raw['objeto_del_contrato'] ?? ''} ${raw['descripcion_del_proceso'] ?? ''}',
    );
    for (final kw in match.soqlKeywords) {
      if (combined.contains(_normalizar(kw))) {
        return true;
      }
    }
    return false;
  }

  List<ContractRecord> _buildContractsFromRawList(
    List<Map<String, dynamic>> rawList,
  ) {
    final result = <ContractRecord>[];
    for (var i = 0; i < rawList.length; i++) {
      final record = _parseSecopJsonToRecord(rawList[i], i);
      if (record != null) {
        result.add(record);
      }
    }
    return result;
  }

  static Map<String, dynamic> _normalizarSecopIRaw(Map<String, dynamic> c) {
    final m = SecopI.normalizar(c);
    final rawVal = (m['valor_del_contrato'] ?? '').toString();
    final cleanVal = rawVal.replaceAll(r'$', '').replaceAll(' ', '').replaceAll(',', '');
    m['valor_del_contrato'] = cleanVal.isNotEmpty ? cleanVal : rawVal;
    m['estado_contrato'] ??= 'Celebrado';
    m['orden'] ??= 'Territorial';
    return m;
  }

  ContractRecord? _parseSecopJsonToRecord(
    Map<String, dynamic> raw,
    int index,
  ) {
    final double val =
        double.tryParse(raw['valor_del_contrato']?.toString() ?? '0') ?? 0;
    if (val <= 0) return null;

    final rawContractor =
        (raw['proveedor_adjudicado'] ?? '').toString().trim();
    if (rawContractor.isEmpty ||
        rawContractor.toUpperCase() == 'NO DEFINIDO') {
      return null;
    }

    final rawDoc = (raw['documento_proveedor'] ?? '').toString().trim();
    final rawTipoDoc = (raw['tipodocproveedor'] ?? '').toString();
    final formattedDoc = _formatContractorDocument(rawTipoDoc, rawDoc);

    final rawStatus = (raw['estado_contrato'] ?? 'En ejecución').toString();
    final normalizedStatus = _mapSecopStatus(rawStatus);

    final rawSignDate = raw['fecha_de_firma']?.toString() ??
        raw['fecha_de_inicio_del_contrato']?.toString() ??
        '';
    final rawStartDate =
        raw['fecha_de_inicio_del_contrato']?.toString() ?? rawSignDate;
    final rawEndDate =
        raw['fecha_de_fin_del_contrato']?.toString() ?? rawSignDate;
    final year =
        rawSignDate.length >= 4 ? rawSignDate.substring(0, 4) : '';

    final rawEntity = (raw['nombre_entidad'] ?? 'Entidad Pública').toString();
    final displayEntity = _beautifyEntityName(rawEntity);

    final rawObjeto = (raw['objeto_del_contrato'] ??
            raw['descripcion_del_proceso'] ??
            'Contrato estatal SECOP II')
        .toString()
        .trim();
    final displayTitle = _beautifyContractTitle(rawObjeto);

    final inferredDepartment = _inferDependency(
      objeto: rawObjeto,
      entidad: rawEntity,
      sector: (raw['sector'] ?? '').toString(),
    );

    final rawDepto = (raw['departamento'] ?? '').toString().trim();
    final rawCiudad = (raw['ciudad'] ?? '').toString().trim();
    final cleanDepto =
        rawDepto.toUpperCase() == 'NO DEFINIDO' ? '' : rawDepto;
    final cleanCiudad =
        rawCiudad.toUpperCase() == 'NO DEFINIDO' ? '' : rawCiudad;
    final locationLabel = cleanDepto.isNotEmpty &&
            cleanCiudad.isNotEmpty &&
            cleanDepto != cleanCiudad
        ? '$cleanDepto · $cleanCiudad'
        : (cleanCiudad.isNotEmpty
            ? cleanCiudad
            : (cleanDepto.isNotEmpty ? cleanDepto : 'Colombia'));

    final rawOrden = (raw['orden'] ?? 'Territorial').toString().trim();

    final refCode = (raw['referencia_del_contrato'] ??
            raw['proceso_de_compra'] ??
            raw['id_contrato'] ??
            'SECOP-${index + 1}')
        .toString()
        .trim();

    final style = _pickVisualStyle(
      inferredDepartment,
      (raw['tipo_de_contrato'] ?? '').toString(),
      index,
    );

    final enrichedRaw = Map<String, dynamic>.from(raw);
    enrichedRaw['descripcion_del_proceso'] ??= rawObjeto;
    enrichedRaw['objeto_del_contrato'] ??= rawObjeto;
    enrichedRaw['proceso_de_compra'] ??= raw['id_contrato'] ?? refCode;

    return ContractRecord(
      title: displayTitle,
      processCode: 'Proceso: $refCode',
      valueFormatted: _formatCop(val),
      numericValue: val,
      entity: displayEntity,
      department: inferredDepartment,
      contractor: _beautifyPersonOrCompanyName(rawContractor),
      contractorId: formattedDoc,
      startDate: _shortDate(rawStartDate),
      endDate: _shortDate(rawEndDate),
      year: year,
      modality: (raw['modalidad_de_contratacion'] ?? 'Contratación directa')
          .toString(),
      status: normalizedStatus,
      location: locationLabel,
      orden: rawOrden,
      color: style.color,
      iconBg: style.bg,
      icon: style.icon,
      rawSecopJson: enrichedRaw,
    );
  }

  String _formatContractorDocument(String tipoDoc, String rawDoc) {
    final cleanDigits = rawDoc.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      return rawDoc.isNotEmpty ? rawDoc : 'Registrado en SECOP II';
    }
    final isNit = tipoDoc.toUpperCase().contains('NIT') ||
        (cleanDigits.length >= 9 &&
            (cleanDigits.startsWith('8') || cleanDigits.startsWith('9')));

    if (isNit && cleanDigits.length == 10) {
      final base = cleanDigits.substring(0, 9);
      final dv = cleanDigits.substring(9);
      final formattedBase = base.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
      return 'NIT $formattedBase-$dv';
    }

    final formattedNumber = cleanDigits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return isNit ? 'NIT $formattedNumber' : 'C.C. $formattedNumber';
  }

  String _beautifyEntityName(String raw) {
    return _toSentenceTitle(raw.trim());
  }

  String _beautifyContractTitle(String raw) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return 'Contrato estatal SECOP II';
    final lower = clean.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  String _beautifyPersonOrCompanyName(String raw) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return 'Contratista Adjudicado';
    return _toSentenceTitle(clean)
        .replaceAll('S.a.s.', 'S.A.S.')
        .replaceAll('S.a.s', 'S.A.S.')
        .replaceAll('Sas', 'S.A.S.')
        .replaceAll('Ltda', 'LTDA')
        .replaceAll('E.s.p.', 'E.S.P.');
  }

  String _toSentenceTitle(String text) {
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
      'a',
      'al',
    };
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final buffer = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;
      if (i > 0 && smallWords.contains(w)) {
        buffer.add(w);
      } else {
        buffer.add(w[0].toUpperCase() + w.substring(1));
      }
    }
    return buffer.join(' ');
  }

  String _inferDependency({
    required String objeto,
    required String entidad,
    required String sector,
  }) {
    final combined = _normalizar('$objeto $entidad $sector');
    if (combined.contains('SECRETARIA GENERAL') ||
        combined.contains('APOYO A LA GESTION ADMINISTRATIVA') ||
        combined.contains('ATENCION AL CIUDADANO') ||
        combined.contains('ARCHIVO')) {
      return 'Secretaría General';
    }
    if (combined.contains('OBRA') ||
        combined.contains('INFRAESTRUCTURA') ||
        combined.contains('PAVIMENT') ||
        combined.contains('MALLA VIAL') ||
        combined.contains('ALCANTARILLADO') ||
        combined.contains('ADECUACION') ||
        combined.contains('PARQUE')) {
      return 'Secretaría de Obras Públicas';
    }
    if (combined.contains('EDUCACION') ||
        combined.contains('INSTITUCION EDUCATIVA') ||
        combined.contains('ESCOLAR') ||
        combined.contains('PAE') ||
        combined.contains('SENA') ||
        combined.contains('UNIVERSIDAD')) {
      return 'Secretaría de Educación';
    }
    if (combined.contains('SALUD') ||
        combined.contains('HOSPITAL') ||
        combined.contains('SANIDAD') ||
        combined.contains('ENFERMER') ||
        combined.contains('MEDIC') ||
        combined.contains('ODONTOLOG') ||
        combined.contains('EPIDEMIOLOG')) {
      return 'Secretaría de Salud';
    }
    if (combined.contains('AMBIENT') ||
        combined.contains('DAGMA') ||
        combined.contains('CORPO') ||
        combined.contains('ZONAS VERDES') ||
        combined.contains('PODAS') ||
        combined.contains('ARBORIZACION') ||
        combined.contains('FORESTAL') ||
        combined.contains('SILO DE MAIZ')) {
      return 'Secretaría de Ambiente';
    }
    if (combined.contains('HACIENDA') ||
        combined.contains('TESORERIA') ||
        combined.contains('TRIBUT') ||
        combined.contains('IMPUESTO') ||
        combined.contains('FINANCIER') ||
        combined.contains('CONTABLE') ||
        combined.contains('CATASTR')) {
      return 'Secretaría de Hacienda';
    }
    if (combined.contains('TRANSITO') ||
        combined.contains('TRANSPORTE') ||
        combined.contains('MOVILIDAD') ||
        combined.contains('SEMAFOR') ||
        combined.contains('VIAL')) {
      return 'Secretaría de Tránsito y Transporte';
    }
    if (combined.contains('DEPORT') ||
        combined.contains('RECREAC') ||
        combined.contains('INDUPAL') ||
        combined.contains('CULTUR') ||
        combined.contains('TURISMO') ||
        combined.contains('MARATON')) {
      return 'Cultura, Deporte y Recreación';
    }
    if (combined.contains('PLANEACION') ||
        combined.contains('REGALIAS') ||
        combined.contains('SGR') ||
        combined.contains('BANCO DE PROYECTOS')) {
      return 'Oficina de Planeación';
    }
    if (combined.contains('TECNOLOG') ||
        combined.contains('SISTEMAS') ||
        combined.contains('SOFTWARE') ||
        combined.contains('COMPUTO') ||
        combined.contains('REDES SOCIALES') ||
        combined.contains('CONECTIVIDAD') ||
        combined.contains('TIC')) {
      return 'Tecnologías de la Información (TIC)';
    }
    if (combined.contains('JURIDIC') ||
        combined.contains('ABOGAD') ||
        combined.contains('DEFENSA JUDICIAL')) {
      return 'Oficina Asesora Jurídica';
    }
    if (combined.contains('GOBIERNO') ||
        combined.contains('ESPACIO PUBLICO') ||
        combined.contains('CONVIVENCIA') ||
        combined.contains('SEGURIDAD') ||
        combined.contains('INTERIOR')) {
      return 'Secretaría de Gobierno';
    }
    if (combined.contains('VIVIENDA') || combined.contains('FONVISOCIAL')) {
      return 'Vivienda e Infraestructura';
    }
    if (combined.contains('EMDUPAR') ||
        combined.contains('ACUEDUCTO') ||
        combined.contains('SERVICIOS PUBLICOS')) {
      return 'Servicios Públicos y Saneamiento';
    }
    if (combined.contains('DESARROLLO ECONOMICO') ||
        combined.contains('EMPRENDIMIENTO') ||
        combined.contains('SOCIOEMPRESARIAL') ||
        combined.contains('AGROPECUARI')) {
      return 'Secretaría de Desarrollo Económico';
    }
    if (combined.contains('POLICIA') ||
        combined.contains('EJERCITO') ||
        combined.contains('CENAC') ||
        combined.contains('DEFENSA')) {
      return 'Defensa y Seguridad';
    }
    if (combined.contains('CONTRALORIA') ||
        combined.contains('PERSONERIA') ||
        combined.contains('CONTROL INTERNO')) {
      return 'Control Interno y Vigilancia';
    }
    if (combined.contains('SOCIAL') ||
        combined.contains('FAMILIA') ||
        combined.contains('ICBF') ||
        combined.contains('JUVENTUD') ||
        combined.contains('MUJER') ||
        combined.contains('VICTIMAS') ||
        combined.contains('PSICOLOG')) {
      return 'Gestión Social y Comunitaria';
    }
    return 'Secretaría General';
  }

  ({Color color, Color bg, IconData icon}) _pickVisualStyle(
    String department,
    String tipoContrato,
    int index,
  ) {
    if (department.contains('Obras') || tipoContrato.contains('Obra')) {
      return (
        color: const Color(0xFF2563EB),
        bg: const Color(0xFFDBEAFE),
        icon: Icons.add_road,
      );
    }
    if (department.contains('TIC') || department.contains('Educación')) {
      return (
        color: const Color(0xFF7C3AED),
        bg: const Color(0xFFF3E8FF),
        icon: Icons.desktop_windows_outlined,
      );
    }
    if (department.contains('Ambiente') || department.contains('Salud')) {
      return (
        color: const Color(0xFF16A34A),
        bg: const Color(0xFFDCFCE7),
        icon: department.contains('Ambiente')
            ? Icons.eco
            : Icons.medical_services_outlined,
      );
    }
    final fallbackPalette = [
      (
        color: const Color(0xFFD97706),
        bg: const Color(0xFFFEF3C7),
        icon: Icons.description,
      ),
      (
        color: const Color(0xFF2563EB),
        bg: const Color(0xFFDBEAFE),
        icon: Icons.add_road,
      ),
      (
        color: const Color(0xFF7C3AED),
        bg: const Color(0xFFF3E8FF),
        icon: Icons.desktop_windows_outlined,
      ),
      (
        color: const Color(0xFF16A34A),
        bg: const Color(0xFFDCFCE7),
        icon: Icons.eco,
      ),
    ];
    return fallbackPalette[index % fallbackPalette.length];
  }

  Future<void> _loadFavorites() async {
    final ids = await FavoritesService.idsContratos();
    if (mounted) {
      setState(() => _favoriteIds = ids);
    }
  }

  Future<void> _toggleFavorite(ContractRecord record) async {
    final map = record.toSecopMap();
    final contractId = FavoritesService.idContrato(map);
    final guardado = await FavoritesService.alternarContrato(map);
    if (guardado) {
      _favoriteIds.add(contractId);
    } else {
      _favoriteIds.remove(contractId);
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          guardado
              ? 'Contrato guardado en Favoritos ⭐'
              : 'Contrato eliminado de Favoritos',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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

  String _conTildeComun(String tokenSinTilde) {
    return tokenSinTilde
        .replaceAll('ACION', 'ACIÓN')
        .replaceAll('UCION', 'UCIÓN')
        .replaceAll('ISION', 'ISIÓN')
        .replaceAll('ESION', 'ESIÓN')
        .replaceAll('PUBLIC', 'PÚBLIC')
        .replaceAll('TECNIC', 'TÉCNIC')
        .replaceAll('JURIDIC', 'JURÍDIC')
        .replaceAll('MEDICO', 'MÉDICO')
        .replaceAll('MEDICA', 'MÉDICA')
        .replaceAll('RAMIREZ', 'RAMÍREZ')
        .replaceAll('DIAZ', 'DÍAZ')
        .replaceAll('GOMEZ', 'GÓMEZ')
        .replaceAll('LOPEZ', 'LÓPEZ')
        .replaceAll('PEREZ', 'PÉREZ')
        .replaceAll('RODRIGUEZ', 'RODRÍGUEZ')
        .replaceAll('MARTINEZ', 'MARTÍNEZ')
        .replaceAll('HERNANDEZ', 'HERNÁNDEZ')
        .replaceAll('GONZALEZ', 'GONZÁLEZ')
        .replaceAll('SANCHEZ', 'SÁNCHEZ')
        .replaceAll('JIMENEZ', 'JIMÉNEZ')
        .replaceAll('GUTIERREZ', 'GUTIÉRREZ')
        .replaceAll('SUAREZ', 'SUÁREZ')
        .replaceAll('ALVAREZ', 'ÁLVAREZ')
        .replaceAll('VASQUEZ', 'VÁSQUEZ')
        .replaceAll('VELASQUEZ', 'VELÁSQUEZ')
        .replaceAll('CORDOBA', 'CÓRDOBA')
        .replaceAll('BOLIVAR', 'BOLÍVAR')
        .replaceAll('BOGOTA', 'BOGOTÁ')
        .replaceAll('MEDELLIN', 'MEDELLÍN')
        .replaceAll('CUCUTA', 'CÚCUTA')
        .replaceAll('IBAGUE', 'IBAGUÉ')
        .replaceAll('POPAYAN', 'POPAYÁN')
        .replaceAll('NARINO', 'NARIÑO')
        .replaceAll('BOLANO', 'BOLAÑO')
        .replaceAll('MUNOZ', 'MUÑOZ')
        .replaceAll('PENA', 'PEÑA')
        .replaceAll('CASTANO', 'CASTAÑO')
        .replaceAll('PATINO', 'PATIÑO');
  }

  String _formatCop(double val) {
    final intVal = val.round();
    final str = intVal.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return '\$ $str';
  }

  String? _buildEntitySoqlClause(String entidad) {
    final clean = SecurityService.sanitizeSoqlToken(entidad, maxLength: 100);
    if (clean.isEmpty) return null;

    final norm = _normalizar(clean);
    final words = norm
        .replaceAll('(', ' ')
        .replaceAll(')', ' ')
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .map((w) => SecurityService.sanitizeSoqlToken(w, maxLength: 40))
        .where(
          (w) =>
              w.length > 2 &&
              !{'DEL', 'LAS', 'LOS', 'PARA', 'POR', 'CON', 'E.S.E.'}
                  .contains(w),
        )
        .take(10)
        .toList();

    if (words.isEmpty) {
      return "upper(nombre_entidad) LIKE '%$norm%'";
    }
    return words.map((w) {
      final wTilde = _conTildeComun(w);
      if (wTilde != w) {
        return "(upper(nombre_entidad) LIKE '%$w%' OR upper(nombre_entidad) LIKE '%$wTilde%')";
      }
      return "upper(nombre_entidad) LIKE '%$w%'";
    }).join(' AND ');
  }

  List<String> _extractCommaGroups(String rawQuery) {
    return rawQuery
        .split(',')
        .map((g) => SecurityService.sanitizeSoqlToken(g, maxLength: 80))
        .where((g) => g.isNotEmpty)
        .take(5)
        .toList();
  }

  List<String> _extractSearchTokens(String rawQuery) {
    final cleaned = SecurityService.sanitizeSoqlToken(
      rawQuery.replaceAll(',', ' '),
      maxLength: 120,
    );
    if (cleaned.isEmpty) return const [];
    return cleaned
        .split(RegExp(r'\s+'))
        .map((t) => SecurityService.sanitizeSoqlToken(t, maxLength: 40))
        .where(
          (t) =>
              t.isNotEmpty &&
              !{'C.C.', 'CC', 'C.C', 'NIT', 'NIT.'}.contains(t.toUpperCase()),
        )
        .take(8)
        .toList();
  }

  String? _buildFastEntityOrDocIndexClause(String rawQuery) {
    final groups = _extractCommaGroups(rawQuery);
    if (groups.isEmpty) return null;

    final groupClauses = <String>[];
    for (final group in groups) {
      final digitsOnly = group.replaceAll(RegExp(r'[^0-9]'), '');
      final normGroup = _normalizar(group);
      final isNumericDoc =
          digitsOnly.length >= 3 &&
          RegExp(r'^[0-9.\-\s]+$').hasMatch(
            group.replaceAll(
              RegExp(r'(C\.?C\.?|NIT\.?)', caseSensitive: false),
              '',
            ),
          );

      if (isNumericDoc) {
        final docSub = <String>[
          "starts_with(documento_proveedor, '$digitsOnly')",
          "starts_with(nit_entidad, '$digitsOnly')",
          if (digitsOnly.length == 10 &&
              (digitsOnly.startsWith('8') || digitsOnly.startsWith('9'))) ...[
            "starts_with(documento_proveedor, '${digitsOnly.substring(0, 9)}')",
            "starts_with(nit_entidad, '${digitsOnly.substring(0, 9)}')",
          ],
          if (digitsOnly.length >= 4)
            "starts_with(referencia_del_contrato, '$digitsOnly')",
        ];
        groupClauses.add('(${docSub.join(' OR ')})');
        continue;
      }

      // Siglas de entidades nacionales con NIT indexado en SECOP II (respuesta en <200ms)
      if (normGroup == 'SENA' || normGroup.contains('SERVICIO NACIONAL DE APRENDIZAJE')) {
        groupClauses.add("(nit_entidad = '899999034' OR starts_with(nit_entidad, '899999034'))");
        continue;
      }
      if (normGroup == 'ICBF' || normGroup.contains('BIENESTAR FAMILIAR')) {
        groupClauses.add("(nit_entidad = '899999239' OR starts_with(nit_entidad, '899999239'))");
        continue;
      }
      if (normGroup == 'INVIAS' || normGroup.contains('INSTITUTO NACIONAL DE VIAS')) {
        groupClauses.add("(nit_entidad = '800215807' OR starts_with(nit_entidad, '800215807'))");
        continue;
      }
      if (normGroup == 'UNGRD') {
        groupClauses.add("(nit_entidad = '900476364' OR starts_with(nit_entidad, '900476364'))");
        continue;
      }
    }

    if (groupClauses.length == groups.length && groupClauses.isNotEmpty) {
      return '(${groupClauses.join(' OR ')})';
    }
    return null;
  }

  String? _buildSearchSoqlClause(String rawQuery) {
    final groups = _extractCommaGroups(rawQuery);
    if (groups.isEmpty) return null;

    final groupClauses = <String>[];
    for (final group in groups) {
      final tokens = _extractSearchTokens(group);
      if (tokens.isEmpty) continue;

      final tokenClauses = <String>[];
      for (final rawToken in tokens) {
        final hasDigits = RegExp(r'\d').hasMatch(rawToken);
        final digitsOnly = rawToken.replaceAll(RegExp(r'[^0-9]'), '');
        final isFormattedDoc =
            hasDigits &&
            digitsOnly.length >= 3 &&
            RegExp(r'^[0-9.\-]+$').hasMatch(rawToken);

        final tNorm = _normalizar(rawToken);
        final tOrig = rawToken.toUpperCase();
        final tTilde = _conTildeComun(tNorm);

        if (isFormattedDoc) {
          final docChecks = <String>[
            "starts_with(documento_proveedor, '$digitsOnly')",
            "starts_with(nit_entidad, '$digitsOnly')",
            if (digitsOnly.length == 10 &&
                (digitsOnly.startsWith('8') || digitsOnly.startsWith('9')))
              "starts_with(documento_proveedor, '${digitsOnly.substring(0, 9)}')",
            "upper(referencia_del_contrato) LIKE '%$digitsOnly%'",
            "upper(id_contrato) LIKE '%$digitsOnly%'",
          ];
          tokenClauses.add('(${docChecks.join(' OR ')})');
          continue;
        }

        final variants = <String>{
          tNorm,
          tOrig,
          tTilde,
        }.where((v) => v.isNotEmpty).toList();

        final fieldChecks = <String>[];
        for (final v in variants) {
          if (hasDigits) {
            fieldChecks.addAll([
              if (digitsOnly.length >= 3)
                "starts_with(documento_proveedor, '$digitsOnly')",
              "upper(referencia_del_contrato) LIKE '%$v%'",
              "upper(proceso_de_compra) LIKE '%$v%'",
              "upper(id_contrato) LIKE '%$v%'",
              "upper(proveedor_adjudicado) LIKE '%$v%'",
              "upper(nombre_entidad) LIKE '%$v%'",
            ]);
          } else {
            fieldChecks.addAll([
              "upper(proveedor_adjudicado) LIKE '%$v%'",
              "upper(nombre_entidad) LIKE '%$v%'",
              "upper(objeto_del_contrato) LIKE '%$v%'",
            ]);
          }
        }
        tokenClauses.add('(${fieldChecks.join(' OR ')})');
      }
      if (tokenClauses.isNotEmpty) {
        groupClauses.add('(${tokenClauses.join(' AND ')})');
      }
    }

    if (groupClauses.isEmpty) return null;
    return '(${groupClauses.join(' OR ')})';
  }

  bool _matchesSearchQuery(Map<String, dynamic> raw, String rawQuery) {
    final groups = _extractCommaGroups(rawQuery);
    if (groups.isEmpty) return true;

    final searchableText = _normalizar(
      '${raw['proveedor_adjudicado'] ?? ''} '
      '${raw['documento_proveedor'] ?? ''} '
      '${raw['nit_entidad'] ?? ''} '
      '${raw['nombre_entidad'] ?? ''} '
      '${raw['objeto_del_contrato'] ?? ''} '
      '${raw['descripcion_del_proceso'] ?? ''} '
      '${raw['referencia_del_contrato'] ?? ''} '
      '${raw['proceso_de_compra'] ?? ''} '
      '${raw['id_contrato'] ?? ''} '
      '${raw['ciudad'] ?? ''} '
      '${raw['departamento'] ?? ''}',
    );
    final rawDocDigits = (raw['documento_proveedor'] ?? '')
        .toString()
        .replaceAll(RegExp(r'[^0-9]'), '');
    final rawEntityNitDigits = (raw['nit_entidad'] ?? '')
        .toString()
        .replaceAll(RegExp(r'[^0-9]'), '');

    for (final group in groups) {
      final tokens = _extractSearchTokens(group);
      if (tokens.isEmpty) continue;
      bool allGroupTokensMatch = true;
      for (final token in tokens) {
        final tNorm = _normalizar(token);
        final digitsOnly = token.replaceAll(RegExp(r'[^0-9]'), '');
        final matchesText = searchableText.contains(tNorm);
        final matchesDigits =
            digitsOnly.length >= 3 &&
            (rawDocDigits.contains(digitsOnly) ||
                rawEntityNitDigits.contains(digitsOnly) ||
                (digitsOnly.length == 10 &&
                    rawDocDigits.startsWith(digitsOnly.substring(0, 9))));
        if (!matchesText && !matchesDigits) {
          allGroupTokensMatch = false;
          break;
        }
      }
      if (allGroupTokensMatch) return true;
    }
    return false;
  }

  String _contractUniqueKey(ContractRecord record) {
    final raw = record.rawSecopJson;
    final idContrato = (raw['id_contrato'] ?? '').toString().trim();
    if (idContrato.isNotEmpty) return idContrato;
    final proceso = (raw['proceso_de_compra'] ?? '').toString().trim();
    final ref = (raw['referencia_del_contrato'] ?? '').toString().trim();
    if (proceso.isNotEmpty || ref.isNotEmpty) {
      return '$proceso|$ref|${record.contractorId}';
    }
    return '${record.processCode}|${record.contractor}|${record.numericValue}';
  }

  String _contractRawIsoDate(ContractRecord record) {
    final raw = record.rawSecopJson;
    return (raw['fecha_de_firma'] ??
            raw['fecha_de_inicio_del_contrato'] ??
            '')
        .toString();
  }

  List<ContractRecord> _mergeAndDeduplicateRecords(
    List<ContractRecord> primary,
    List<ContractRecord> secondary,
  ) {
    final map = <String, ContractRecord>{};
    for (final item in primary) {
      map[_contractUniqueKey(item)] = item;
    }
    for (final item in secondary) {
      map.putIfAbsent(_contractUniqueKey(item), () => item);
    }
    final merged = map.values.toList()
      ..sort(
        (a, b) => _contractRawIsoDate(b).compareTo(_contractRawIsoDate(a)),
      );
    return merged;
  }

  String _buildQueryCacheKey(String queryText) {
    return '${_normalizar(queryText)}|$_selectedSector|$_selectedOrden|'
        '$_selectedDepartamento|$_selectedMunicipio|$_selectedEntidad|'
        '$_selectedModalidad|$_selectedEstado|$_selectedAnio|'
        '$_minValueFilter|$_maxValueFilter';
  }

  Future<void> _fetchLiveSecopContracts({
    String? customQuery,
    bool silent = false,
  }) async {
    if (!mounted) return;
    final queryText = (customQuery ?? _contractsSearchController.text).trim();
    final cacheKey = _buildQueryCacheKey(queryText);

    // Respuesta en 0ms si esta consulta ya está en la caché en memoria
    final cachedList = _fastContractsQueryCache[cacheKey];
    if (cachedList != null && cachedList.isNotEmpty) {
      setState(() {
        _secopContracts = cachedList;
        _isLoadingSecop = false;
        _currentPage = 1;
      });
      return;
    }

    final int requestId = ++_latestRequestId;
    setState(() {
      _isLoadingSecop = true;
    });

    try {
      final bool hasSearchOrFilter =
          queryText.isNotEmpty || _activeFiltersCount > 0;
      final int queryLimit =
          hasSearchOrFilter ? _searchResultsLimit : _initialResultsLimit;

      List<String> buildBaseWhereClauses({
        required bool applyYearFilter,
        required bool requireFechaFirma,
      }) {
        final whereClauses = <String>[
          if (requireFechaFirma) 'fecha_de_firma IS NOT NULL',
          'valor_del_contrato > 0',
          "proveedor_adjudicado != 'No Definido'",
          "documento_proveedor != 'No Definido'",
        ];

        // Filtro por Orden (Nacional, Departamental, Municipal, Corporación Autónoma)
        if (_selectedOrden.isNotEmpty) {
          if (_selectedOrden == 'Nacional') {
            whereClauses.add("orden = 'Nacional'");
          } else if (_selectedOrden == 'Corporación Autónoma') {
            whereClauses.add("upper(orden) LIKE '%CORPORAC%'");
          } else if (_selectedOrden == 'Departamental') {
            whereClauses.add(
              "orden = 'Territorial' AND (upper(nombre_entidad) LIKE '%GOBERNAC%' OR upper(nombre_entidad) LIKE '%DEPARTAMENT%' OR upper(nombre_entidad) LIKE '%ASAMBLEA%' OR upper(nombre_entidad) LIKE '%UNIVERSIDAD%')",
            );
          } else if (_selectedOrden == 'Municipal') {
            whereClauses.add("orden = 'Territorial'");
          }
        }

        // Filtro por Departamento
        if (_selectedDepartamento.isNotEmpty) {
          final safeDep = SecurityService.sanitizeSoqlToken(
            _selectedDepartamento,
            maxLength: 60,
          );
          final dNorm = _normalizar(safeDep);
          final dOrig = safeDep.toUpperCase();
          if (dNorm == 'BOGOTA D.C.') {
            whereClauses.add(
              "(upper(departamento) LIKE '%BOGOT%' OR upper(ciudad) LIKE '%BOGOT%')",
            );
          } else if (dNorm.contains('SAN ANDRES')) {
            whereClauses.add("upper(departamento) LIKE '%SAN ANDR%'");
          } else if (dNorm.isNotEmpty && dNorm != dOrig) {
            whereClauses.add(
              "(upper(departamento) LIKE '%$dNorm%' OR upper(departamento) LIKE '%$dOrig%')",
            );
          } else if (dNorm.isNotEmpty) {
            whereClauses.add("upper(departamento) LIKE '%$dNorm%'");
          }
        }

        // Filtro por Municipio
        if (_selectedMunicipio.isNotEmpty) {
          final safeMun = SecurityService.sanitizeSoqlToken(
            _selectedMunicipio,
            maxLength: 60,
          );
          final mNorm = _normalizar(safeMun);
          final mOrig = safeMun.toUpperCase();
          if (mNorm == 'BOGOTA D.C.') {
            whereClauses.add("upper(ciudad) LIKE '%BOGOT%'");
          } else if (mNorm.isNotEmpty && mNorm != mOrig) {
            whereClauses.add(
              "(upper(ciudad) LIKE '%$mNorm%' OR upper(ciudad) LIKE '%$mOrig%' OR upper(nombre_entidad) LIKE '%$mNorm%')",
            );
          } else if (mNorm.isNotEmpty) {
            whereClauses.add(
              "(upper(ciudad) LIKE '%$mNorm%' OR upper(nombre_entidad) LIKE '%$mNorm%')",
            );
          }
        }

        // Filtro por Entidad
        if (_selectedEntidad.isNotEmpty) {
          final entClause = _buildEntitySoqlClause(_selectedEntidad);
          if (entClause != null) whereClauses.add(entClause);
        }

        // Macrofiltro por Sector (Salud, Educación, Obras, Seguridad, etc.)
        if (_selectedSector.isNotEmpty) {
          final sectorClause = _buildSectorSoqlClause(_selectedSector);
          if (sectorClause != null) whereClauses.add(sectorClause);
        }

        // Filtro por Año (cobertura completa 2015 a 2026 en fecha de firma o fecha de inicio)
        if (applyYearFilter && RegExp(r'^\d{4}$').hasMatch(_selectedAnio)) {
          whereClauses.add(
            "((fecha_de_firma >= '$_selectedAnio-01-01T00:00:00.000' AND fecha_de_firma <= '$_selectedAnio-12-31T23:59:59.999') OR "
            "(fecha_de_firma IS NULL AND fecha_de_inicio_del_contrato >= '$_selectedAnio-01-01T00:00:00.000' AND fecha_de_inicio_del_contrato <= '$_selectedAnio-12-31T23:59:59.999'))",
          );
        } else if (_selectedAnio.isEmpty) {
          // Cobertura histórica oficial desde 2015 en adelante
          whereClauses.add(
            "(fecha_de_firma >= '2015-01-01T00:00:00.000' OR fecha_de_inicio_del_contrato >= '2015-01-01T00:00:00.000')",
          );
        }

        // Filtro por Modalidad
        if (_selectedModalidad.isNotEmpty) {
          final modNorm = _normalizar(_selectedModalidad);
          if (modNorm.contains('DIRECTA')) {
            whereClauses.add(
              "(upper(modalidad_de_contratacion) LIKE '%DIRECTA%')",
            );
          } else if (modNorm.contains('MINIMA')) {
            whereClauses.add(
              "(upper(modalidad_de_contratacion) LIKE '%MINIMA%' OR upper(modalidad_de_contratacion) LIKE '%MÍNIMA%')",
            );
          } else if (modNorm.contains('SUBASTA')) {
            whereClauses.add(
              "upper(modalidad_de_contratacion) LIKE '%SUBASTA%'",
            );
          } else if (modNorm.contains('ABREVIADA')) {
            whereClauses.add(
              "upper(modalidad_de_contratacion) LIKE '%ABREVIADA%'",
            );
          } else if (modNorm.contains('LICITACION')) {
            whereClauses.add(
              "(upper(modalidad_de_contratacion) LIKE '%LICITACION%' OR upper(modalidad_de_contratacion) LIKE '%LICITACIÓN%')",
            );
          } else if (modNorm.contains('MERITOS')) {
            whereClauses.add(
              "(upper(modalidad_de_contratacion) LIKE '%MERITOS%' OR upper(modalidad_de_contratacion) LIKE '%MÉRITOS%')",
            );
          } else if (modNorm.contains('ESPECIAL')) {
            whereClauses.add(
              "upper(modalidad_de_contratacion) LIKE '%ESPECIAL%'",
            );
          }
        }

        // Filtro por Estado
        if (_selectedEstado.isNotEmpty) {
          final estNorm = _normalizar(_selectedEstado);
          if (estNorm.contains('EJECUCION')) {
            whereClauses.add(
              "(upper(estado_contrato) LIKE '%EJECUCION%' OR upper(estado_contrato) LIKE '%EJECUCIÓN%')",
            );
          } else if (estNorm.contains('APROB')) {
            whereClauses.add("upper(estado_contrato) LIKE '%APROB%'");
          } else if (estNorm.contains('MODIFIC')) {
            whereClauses.add("upper(estado_contrato) LIKE '%MODIFIC%'");
          } else if (estNorm.contains('TERMIN')) {
            whereClauses.add("upper(estado_contrato) LIKE '%TERMIN%'");
          } else if (estNorm.contains('CERRAD')) {
            whereClauses.add("upper(estado_contrato) LIKE '%CERRAD%'");
          } else if (estNorm.contains('LIQUID')) {
            whereClauses.add("upper(estado_contrato) LIKE '%LIQUID%'");
          }
        }

        if (_minValueFilter != null && _minValueFilter! > 0) {
          whereClauses.add(
            'valor_del_contrato >= ${_minValueFilter!.toStringAsFixed(0)}',
          );
        }
        if (_maxValueFilter != null && _maxValueFilter! > 0) {
          whereClauses.add(
            'valor_del_contrato <= ${_maxValueFilter!.toStringAsFixed(0)}',
          );
        }

        return whereClauses;
      }

      List<ContractRecord> parseJsonResponse(
        String responseBody, {
        bool verifyQueryTokens = false,
      }) {
        final List<dynamic> data = jsonDecode(responseBody) as List<dynamic>;
        final parsed = <ContractRecord>[];
        for (var i = 0; i < data.length; i++) {
          final raw = Map<String, dynamic>.from(data[i] as Map);
          if (verifyQueryTokens && !_matchesSearchQuery(raw, queryText)) {
            continue;
          }
          final record = _parseSecopJsonToRecord(raw, i);
          if (record != null) {
            parsed.add(record);
          }
        }
        return parsed;
      }

      Future<List<ContractRecord>> runSoqlQuery({
        required bool applyYearFilter,
      }) async {
        // 1. Sin texto de búsqueda: consulta directa indexada con límite ágil
        if (queryText.isEmpty) {
          final baseClauses = buildBaseWhereClauses(
            applyYearFilter: applyYearFilter,
            requireFechaFirma: true,
          );
          final uri = Uri.https(
            'www.datos.gov.co',
            '/resource/jbjy-vk9h.json',
            <String, String>{
              r'$select': _secopSelectFields,
              r'$limit': '$queryLimit',
              r'$order': 'fecha_de_firma DESC',
              r'$where': baseClauses.join(' AND '),
            },
          );
          final response =
              await http.get(uri).timeout(const Duration(seconds: 10));
          if (response.statusCode != 200) return [];
          return parseJsonResponse(response.body);
        }

        final baseClauses = buildBaseWhereClauses(
          applyYearFilter: applyYearFilter,
          requireFechaFirma: false,
        );

        // 2. Ruta ultra-rápida por índice B-tree si busca Cédula, NIT o siglas conocidas (< 250ms)
        final fastBtreeClause = _buildFastEntityOrDocIndexClause(queryText);
        if (fastBtreeClause != null) {
          try {
            final indexedWhere = <String>[...baseClauses, fastBtreeClause];
            final uri = Uri.https(
              'www.datos.gov.co',
              '/resource/jbjy-vk9h.json',
              <String, String>{
                r'$select': _secopSelectFields,
                r'$limit': '$queryLimit',
                r'$order': 'fecha_de_firma DESC',
                r'$where': indexedWhere.join(' AND '),
              },
            );
            final response =
                await http.get(uri).timeout(const Duration(seconds: 8));
            if (response.statusCode == 200) {
              final indexedParsed = parseJsonResponse(response.body);
              if (indexedParsed.isNotEmpty) {
                return indexedParsed;
              }
            }
          } catch (_) {}
        }

        // 3. Ruta rápida por índice Full-Text ($q) de Socrata (~250ms)
        // Si hay varias combinaciones separadas por coma, las consultamos en paralelo con $q
        final commaGroups = _extractCommaGroups(queryText);
        Future<List<ContractRecord>> fetchSingleGroupQ(String groupText) async {
          try {
            final cleanQ = _extractSearchTokens(groupText).join(' ');
            final uri = Uri.https(
              'www.datos.gov.co',
              '/resource/jbjy-vk9h.json',
              <String, String>{
                r'$select': _secopSelectFields,
                r'$limit': '${(queryLimit / commaGroups.length.clamp(1, 5)).ceil().clamp(50, 160)}',
                r'$order': 'fecha_de_firma DESC',
                r'$q': cleanQ.isNotEmpty ? cleanQ : groupText,
                r'$where': baseClauses.join(' AND '),
              },
            );
            final response =
                await http.get(uri).timeout(const Duration(seconds: 8));
            if (response.statusCode != 200) return [];
            return parseJsonResponse(
              response.body,
              verifyQueryTokens: true,
            );
          } catch (_) {
            return [];
          }
        }

        final groupLists = await Future.wait(
          commaGroups.map(fetchSingleGroupQ),
        );
        var fastCombined = <ContractRecord>[];
        for (final list in groupLists) {
          fastCombined = _mergeAndDeduplicateRecords(fastCombined, list);
        }

        // Si el índice rápido $q encontró resultados, respondemos de inmediato sin esperar escaneos lentos
        if (fastCombined.isNotEmpty) {
          return fastCombined;
        }

        // 4. Fallback ligero SoQL ($limit=80) solo si $q no arrojó coincidencias (ej. fragmentos de palabra)
        final searchClause = _buildSearchSoqlClause(queryText);
        if (searchClause != null) {
          try {
            final likeClauses = <String>[...baseClauses, searchClause];
            final uri = Uri.https(
              'www.datos.gov.co',
              '/resource/jbjy-vk9h.json',
              <String, String>{
                r'$select': _secopSelectFields,
                r'$limit': '300',
                r'$order': 'fecha_de_firma DESC',
                r'$where': likeClauses.join(' AND '),
              },
            );
            final response =
                await http.get(uri).timeout(const Duration(seconds: 10));
            if (response.statusCode == 200) {
              return parseJsonResponse(response.body);
            }
          } catch (_) {}
        }

        return [];
      }

      Future<List<ContractRecord>> fetchSecopIContracts({
        bool applyYearFilter = true,
      }) async {
        try {
          final whereClauses = <String>[];
          whereClauses.add(
            SecopI.filtroAnio(applyYearFilter ? _selectedAnio : null),
          );

          if (_selectedDepartamento.isNotEmpty) {
            final safeDep = SecurityService.sanitizeSoqlToken(_selectedDepartamento, maxLength: 60);
            final dNorm = _normalizar(safeDep);
            if (dNorm.isNotEmpty) {
              whereClauses.add("upper(departamento_entidad) LIKE '%$dNorm%'");
            }
          }

          if (_selectedMunicipio.isNotEmpty) {
            final safeMun = SecurityService.sanitizeSoqlToken(_selectedMunicipio, maxLength: 60);
            final mNorm = _normalizar(safeMun);
            if (mNorm.isNotEmpty) {
              whereClauses.add("upper(municipio_entidad) LIKE '%$mNorm%'");
            }
          }

          if (_selectedEntidad.isNotEmpty) {
            final safeEnt = SecurityService.sanitizeSoqlToken(_selectedEntidad, maxLength: 60);
            final eNorm = _normalizar(safeEnt);
            if (eNorm.isNotEmpty) {
              whereClauses.add("upper(nombre_entidad) LIKE '%$eNorm%'");
            }
          }

          if (queryText.isNotEmpty) {
            final cleanQ = SecurityService.sanitizeSoqlToken(queryText, maxLength: 80);
            final digits = cleanQ.replaceAll(RegExp(r'[^0-9]'), '');
            final qNorm = _normalizar(cleanQ);
            if (digits.length >= 4) {
              whereClauses.add("(starts_with(identificacion_del_contratista, '$digits') OR upper(numero_de_contrato) LIKE '%$digits%')");
            } else if (qNorm.isNotEmpty) {
              whereClauses.add("(upper(nom_razon_social_contratista) LIKE '%$qNorm%' OR upper(detalle_del_objeto_a_contratar) LIKE '%$qNorm%')");
            }
          }

          final uri = Uri.https(
            'www.datos.gov.co',
            '/resource/${SecopI.dataset}.json',
            <String, String>{
              r'$limit': '$queryLimit',
              r'$order': 'fecha_de_firma_del_contrato DESC',
              r'$where': whereClauses.join(' AND '),
            },
          );

          final response = await http.get(uri).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final decoded = json.decode(utf8.decode(response.bodyBytes));
            if (decoded is List) {
              final list = <ContractRecord>[];
              for (var i = 0; i < decoded.length; i++) {
                if (decoded[i] is Map) {
                  final norm = _normalizarSecopIRaw(
                    Map<String, dynamic>.from(decoded[i] as Map),
                  );
                  final record = _parseSecopJsonToRecord(norm, i);
                  if (record != null) list.add(record);
                }
              }
              return list;
            }
          }
        } catch (_) {}
        return [];
      }

      var results = await runSoqlQuery(applyYearFilter: true);
      if (!mounted || requestId != _latestRequestId) return;

      final anioNum = int.tryParse(_selectedAnio);
      final esAnioHistoricoSecop1 = anioNum != null && anioNum <= 2019;
      final necesitaSecop1 = esAnioHistoricoSecop1 ||
          (_selectedAnio.isNotEmpty && results.length < 20) ||
          (_selectedAnio.isEmpty && results.length < 60 && queryText.isNotEmpty);

      if (necesitaSecop1) {
        final secop1Results = await fetchSecopIContracts();
        if (secop1Results.isNotEmpty) {
          results = _mergeAndDeduplicateRecords(results, secop1Results);
        }
      }

      if (!mounted || requestId != _latestRequestId) return;
      if (results.isNotEmpty) {
        _fastContractsQueryCache[cacheKey] = results;
      }
      setState(() {
        if (results.isNotEmpty ||
            queryText.isNotEmpty ||
            _activeFiltersCount > 0) {
          _secopContracts = results;
        }
        _isLoadingSecop = false;
        _currentPage = 1;
      });

      if (!silent && mounted && requestId == _latestRequestId) {
        final sourceMsg = esAnioHistoricoSecop1
            ? 'desde SECOP I y SECOP II'
            : 'desde SECOP';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              results.isNotEmpty
                  ? 'Se cargaron ${results.length} contratos $sourceMsg.'
                  : 'No se encontraron contratos con ese criterio.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted && requestId == _latestRequestId) {
        setState(() => _isLoadingSecop = false);
      }
    }
  }

  String _mapSecopStatus(String raw) {
    final up = _normalizar(raw);
    if (up.contains('EJEC')) return 'En ejecución';
    if (up.contains('MODIFIC')) return 'Modificado';
    if (up.contains('APROB') || up.contains('CELEBR')) return 'Aprobado';
    if (up.contains('CERR')) return 'Cerrado';
    if (up.contains('LIQUID')) return 'Liquidado';
    if (up.contains('TERM') || up.contains('FIN')) return 'Terminado';
    return 'En ejecución';
  }

  String _shortDate(String raw) {
    final clean = raw.split('T').first;
    final parts = clean.split('-');
    if (parts.length == 3) {
      const months = [
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ];
      final m = int.tryParse(parts[1]) ?? 1;
      final monthName = months[(m - 1).clamp(0, 11)];
      return '${parts[2]} $monthName ${parts[0]}';
    }
    return clean;
  }

  // La lista filtrada se consulta varias veces por build (tabla, paginación,
  // contadores): se memoriza mientras no cambien los datos ni los filtros.
  List<ContractRecord>? _filteredCache;
  String _filteredCacheKey = '';

  List<ContractRecord> get _filteredContracts {
    final key = '${identityHashCode(_secopContracts)}|${_secopContracts.length}|'
        '$_selectedSector|$_selectedDependencia|$_selectedEstado|$_selectedAnio|'
        '$_minValueFilter|$_maxValueFilter|$_sortBy';
    if (_filteredCache != null && key == _filteredCacheKey) {
      return _filteredCache!;
    }
    _filteredCacheKey = key;
    return _filteredCache = _calcularContratosFiltrados();
  }

  List<ContractRecord> _calcularContratosFiltrados() {
    final list = _secopContracts.where((c) {
      if (_selectedSector.isNotEmpty &&
          !_matchesSectorMacroFilter(c, _selectedSector)) {
        return false;
      }
      if (_selectedDependencia.isNotEmpty &&
          !_normalizar(c.department).contains(_normalizar(_selectedDependencia))) {
        return false;
      }
      if (_selectedEstado.isNotEmpty && c.status != _selectedEstado) {
        return false;
      }
      if (_selectedAnio.isNotEmpty && c.year != _selectedAnio) {
        return false;
      }
      if (_minValueFilter != null && c.numericValue < _minValueFilter!) {
        return false;
      }
      if (_maxValueFilter != null && c.numericValue > _maxValueFilter!) {
        return false;
      }
      return true;
    }).toList();

    if (_sortBy == 'Mayor valor') {
      list.sort((a, b) => b.numericValue.compareTo(a.numericValue));
    } else if (_sortBy == 'Menor valor') {
      list.sort((a, b) => a.numericValue.compareTo(b.numericValue));
    }
    return list;
  }

  int get _totalPages {
    final total = _filteredContracts.length;
    if (total == 0) return 1;
    return (total / _pageSize).ceil();
  }

  List<ContractRecord> get _currentPageContracts {
    final all = _filteredContracts;
    if (all.isEmpty) return [];
    final safePage = _currentPage.clamp(1, _totalPages);
    final startIndex = ((safePage - 1) * _pageSize).clamp(0, all.length - 1);
    final endIndex = (startIndex + _pageSize).clamp(0, all.length);
    return all.sublist(startIndex, endIndex);
  }

  void _executeContractSearch({bool silent = false}) {
    _searchDebounce?.cancel();
    setState(() => _currentPage = 1);
    _fetchLiveSecopContracts(
      customQuery: _contractsSearchController.text.trim(),
      silent: silent,
    );
  }

  void _resetAllFilters() {
    _searchDebounce?.cancel();
    setState(() {
      _selectedSector = '';
      _selectedOrden = '';
      _selectedDepartamento = '';
      _selectedMunicipio = '';
      _selectedEntidad = '';
      _selectedDependencia = '';
      _selectedModalidad = '';
      _selectedEstado = '';
      _selectedAnio = '';
      _minValueFilter = null;
      _maxValueFilter = null;
      _sortBy = 'Más recientes';
      _currentPage = 1;
      _contractsSearchController.clear();
    });
    _fetchLiveSecopContracts(silent: true);
  }

  void _exportFilteredToCsv() {
    final list = _filteredContracts;
    final rows = <List<dynamic>>[
      [
        'Proceso',
        'Orden',
        'Ubicación',
        'Entidad',
        'Dependencia',
        'Objeto del Contrato',
        'Contratista',
        'Identificación',
        'Estado',
        'Modalidad',
        'Valor del Contrato',
        'Plazo Días',
        'Equivalencia Meses',
        'Valor Mensual Estimado',
        'Fecha de Inicio',
        'Fecha de Fin',
      ],
      for (final contract in list)
        () {
          final an = ContractFinancialAnalysis.fromContract(contract.rawSecopJson);
          return [
            contract.processCode,
            contract.orden,
            contract.location,
            contract.entity,
            contract.department,
            contract.title.replaceAll('\n', ' ').replaceAll(';', ','),
            contract.contractor.replaceAll(';', ','),
            contract.contractorId,
            contract.status,
            contract.modality,
            contract.valueFormatted,
            an.tienePlazo ? '${an.plazoDias}' : 'N/R',
            an.tienePlazo ? an.mesesDecimalTexto : 'N/R',
            an.tienePlazo && an.valorTotal > 0
                ? ContractFinancialAnalysis.formatCop(an.valorMensualEstimado)
                : 'N/R',
            contract.startDate,
            contract.endDate,
          ];
        }(),
    ];

    exportCsv(
      context: context,
      rows: rows,
      fileName: 'Reporte_Contratos_SECOP.csv',
    );
  }

  void _openContractDetail(ContractRecord contract) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleContratoScreen(contrato: contract.toSecopMap()),
      ),
    ).then((_) => _loadFavorites());
  }

  void _openContractorProfile(ContractRecord contract) {
    final rawContractorName =
        contract.rawSecopJson['proveedor_adjudicado']?.toString().trim() ??
            contract.contractor;
    final docProveedor =
        contract.rawSecopJson['documento_proveedor']?.toString().trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilContratistaScreen(
          nombreContratista: contract.contractor,
          nombreBuscado: rawContractorName,
          documentoProveedor: docProveedor,
          nit: docProveedor,
        ),
      ),
    );
  }

  void _showQuickViewModal(ContractRecord contract) {
    final map = contract.toSecopMap();
    final contractId = FavoritesService.idContrato(map);
    final isFav = _favoriteIds.contains(contractId);
    final secopUrl = (map['urlproceso'] is Map
            ? map['urlproceso']['url']?.toString()
            : null) ??
        'https://community.secop.gov.co/Public/Tendering/ContractNoticeManagement/Index';
    final analisis = ContractFinancialAnalysis.fromContract(contract.rawSecopJson);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: contract.iconBg,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(contract.icon, color: contract.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${contract.processCode} · ${contract.location}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contract.entity,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isFav
                          ? 'Quitar de Favoritos'
                          : 'Guardar en Favoritos',
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _toggleFavorite(contract);
                      },
                      icon: Icon(
                        isFav ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isFav ? Colors.amber.shade700 : _azulOscuro,
                        size: 26,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  contract.title.replaceAll('\n', ' '),
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _quickInfoTile(
                      'Valor total del contrato',
                      contract.valueFormatted,
                    ),
                    if (analisis.tienePlazo && analisis.valorTotal > 0)
                      _quickInfoTile(
                        analisis.esMenorAUnMes
                            ? 'Pago por ${analisis.plazoDias} días'
                            : 'Valor mensual estimado a recibir',
                        analisis.esMenorAUnMes
                            ? ContractFinancialAnalysis.formatCop(analisis.valorTotal)
                            : '${ContractFinancialAnalysis.formatCop(analisis.valorMensualEstimado)} / mes',
                        caption: '(Valor total ÷ ${analisis.plazoDias} días) × 30 días',
                        highlight: true,
                      ),
                    if (analisis.tienePlazo)
                      _quickInfoTile(
                        'Plazo (base 30 días = 1 mes)',
                        '${analisis.plazoDias} días · ${analisis.mesesDecimalTexto}',
                        caption: analisis.mesesDesglosadosTexto,
                      ),
                    _quickInfoTile('Estado', contract.status),
                    _quickInfoTile('Dependencia / Sector', contract.department),
                    _quickInfoTile('Modalidad', contract.modality),
                    _quickInfoTile(
                      'Vigencia de ejecución',
                      '${contract.startDate} → ${contract.endDate}',
                    ),
                    _quickInfoTile('Ubicación', contract.location),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _openContractorProfile(contract);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_search_outlined,
                          color: _azulPrimario,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contract.contractor,
                                style: const TextStyle(
                                  color: _azulOscuro,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${contract.contractorId} · Clic para auditar historial SECOP + SIGEP',
                                style: const TextStyle(
                                  color: _azulPrimario,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: _azulPrimario,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(secopUrl);
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('Ver en SECOP II'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _openContractDetail(contract);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _azulOscuro,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Ver expediente y Copiloto IA ✨'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickInfoTile(
    String label,
    String value, {
    String? caption,
    bool highlight = false,
  }) {
    return SizedBox(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFF1D4ED8) : _azulOscuro,
              fontSize: highlight ? 14 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAdvancedFiltersDialog() {
    String tempSector = _selectedSector;
    String tempOrden = _selectedOrden;
    String tempDepto = _selectedDepartamento;
    String tempMuni = _selectedMunicipio;
    String tempEntidad = _selectedEntidad;
    String tempDependencia = _selectedDependencia;
    String tempEstado = _selectedEstado;
    String tempModalidad = _selectedModalidad;
    String tempAnio = _selectedAnio;

    final entitySearchCtrl = TextEditingController(text: tempEntidad);
    final minCtrl = TextEditingController(
      text: _minValueFilter?.toStringAsFixed(0) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: _maxValueFilter?.toStringAsFixed(0) ?? '',
    );

    List<String> dynamicEntities = ColombiaSecopCatalog.obtenerEntidadesSugeridas(
      orden: tempOrden.isEmpty ? null : tempOrden,
      departamento: tempDepto.isEmpty ? null : tempDepto,
      municipio: tempMuni.isEmpty ? null : tempMuni,
    );
    bool isLoadingEntities = false;
    bool initializedLiveEntities = false;

    Future<void> refreshSecopEntities(StateSetter setDialogState) async {
      setDialogState(() => isLoadingEntities = true);
      final localSuggested = ColombiaSecopCatalog.obtenerEntidadesSugeridas(
        orden: tempOrden.isEmpty ? null : tempOrden,
        departamento: tempDepto.isEmpty ? null : tempDepto,
        municipio: tempMuni.isEmpty ? null : tempMuni,
      );
      final remoteNames =
          await ColombiaSecopCatalog.consultarEntidadesRealesSecop(
        orden: tempOrden.isEmpty ? null : tempOrden,
        departamento: tempDepto.isEmpty ? null : tempDepto,
        municipio: tempMuni.isEmpty ? null : tempMuni,
        textoBusqueda: entitySearchCtrl.text.trim(),
      );
      final combined = <String>{
        ...remoteNames,
        ...localSuggested,
      }.toList();
      setDialogState(() {
        dynamicEntities = combined;
        isLoadingEntities = false;
      });
    }

    Widget sectionCard({
      required String number,
      required String title,
      required String subtitle,
      required IconData icon,
      required Widget child,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _bordeCalido),
          boxShadow: [
            BoxShadow(
              color: _azulOscuro.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _azulOscuro,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: _doradoPlataforma,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(icon, size: 17, color: _azulOscuro),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFEDE6D6)),
            ),
            child,
          ],
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!initializedLiveEntities) {
            initializedLiveEntities = true;
            Future.microtask(() => refreshSecopEntities(setDialogState));
          }

          final deptoItems = <String>[
            '',
            ...ColombiaSecopCatalog.departamentos,
          ];
          final muniItems = tempDepto.isEmpty
              ? <String>['']
              : <String>[
                  '',
                  ...(ColombiaSecopCatalog
                          .municipiosPorDepartamento[tempDepto] ??
                      const []),
                ];
          if (!muniItems.contains(tempMuni)) {
            tempMuni = '';
          }

          final filterQuery = _normalizar(entitySearchCtrl.text.trim());
          final visibleEntities = filterQuery.isEmpty
              ? dynamicEntities
              : dynamicEntities
                  .where((e) => _normalizar(e).contains(filterQuery))
                  .toList();

          final sectorNames = <String>[
            '',
            for (final s in _sectorMacroOptions)
              if (s.id.isNotEmpty) s.id,
          ];

          return Dialog(
            backgroundColor: _cremaFondo,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: _bordeCalido, width: 1.2),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera con paleta institucional (Azul profundo + Dorado)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    decoration: const BoxDecoration(
                      color: _azulOscuro,
                      border: Border(
                        bottom: BorderSide(color: _doradoPlataforma, width: 2.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _doradoPlataforma.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _doradoPlataforma.withValues(alpha: 0.6),
                            ),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: _doradoPlataforma,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filtros Avanzados · SECOP II',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Organiza tu búsqueda por ubicación, entidad, sector o condiciones contractuales',
                                style: TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              tempSector = '';
                              tempOrden = '';
                              tempDepto = '';
                              tempMuni = '';
                              tempEntidad = '';
                              entitySearchCtrl.clear();
                              tempDependencia = '';
                              tempEstado = '';
                              tempModalidad = '';
                              tempAnio = '';
                              minCtrl.clear();
                              maxCtrl.clear();
                            });
                            refreshSecopEntities(setDialogState);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: _doradoPlataforma,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.restart_alt, size: 15),
                          label: const Text(
                            'Limpiar todo',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(
                            Icons.close,
                            size: 19,
                            color: Colors.white,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  // Cuerpo organizado por tarjetas temáticas
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          sectionCard(
                            number: '1',
                            title: 'Nivel Territorial y Ubicación Geográfica',
                            subtitle:
                                'Filtra por orden administrativo, departamento y municipio',
                            icon: Icons.location_on_outlined,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Orden de la entidad',
                                  style: TextStyle(
                                    color: _azulOscuro,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final item in <String>[
                                      '',
                                      ...ColombiaSecopCatalog.ordenesEntidad,
                                    ])
                                      InkWell(
                                        onTap: () {
                                          setDialogState(() => tempOrden = item);
                                          refreshSecopEntities(setDialogState);
                                        },
                                        borderRadius: BorderRadius.circular(9),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tempOrden == item
                                                ? _azulOscuro
                                                : _cremaFondo,
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            border: Border.all(
                                              color: tempOrden == item
                                                  ? _doradoPlataforma
                                                  : _bordeCalido,
                                              width: tempOrden == item ? 1.4 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (tempOrden == item) ...[
                                                const Icon(
                                                  Icons.check_circle,
                                                  size: 13,
                                                  color: _doradoPlataforma,
                                                ),
                                                const SizedBox(width: 5),
                                              ],
                                              Text(
                                                item.isEmpty
                                                    ? 'Todos los órdenes'
                                                    : 'Orden $item',
                                                style: TextStyle(
                                                  color: tempOrden == item
                                                      ? Colors.white
                                                      : _azulOscuro,
                                                  fontSize: 11.5,
                                                  fontWeight: tempOrden == item
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _dialogOptionalDropdown(
                                        label: 'Departamento',
                                        placeholder: 'Todos los departamentos',
                                        value: tempDepto,
                                        items: deptoItems,
                                        onChanged: (v) {
                                          setDialogState(() {
                                            tempDepto = v ?? '';
                                            tempMuni = '';
                                          });
                                          refreshSecopEntities(setDialogState);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _dialogOptionalDropdown(
                                        label: 'Municipio / Ciudad',
                                        placeholder: tempDepto.isEmpty
                                            ? 'Selecciona un departamento'
                                            : 'Todo $tempDepto',
                                        value: tempMuni,
                                        items: muniItems,
                                        onChanged: (v) {
                                          setDialogState(
                                            () => tempMuni = v ?? '',
                                          );
                                          refreshSecopEntities(setDialogState);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          sectionCard(
                            number: '2',
                            title: 'Entidad Pública, Sector y Dependencia',
                            subtitle:
                                'Selecciona una entidad oficial de SECOP II o segmenta por sector',
                            icon: Icons.account_balance_outlined,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _dialogOptionalDropdown(
                                        label: 'Sector (Macrofiltro)',
                                        placeholder: 'Todos los sectores',
                                        value: tempSector,
                                        items: sectorNames,
                                        onChanged: (v) => setDialogState(
                                          () => tempSector = v ?? '',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _dialogOptionalDropdown(
                                        label: 'Dependencia / Secretaría',
                                        placeholder: 'Todas las dependencias',
                                        value: tempDependencia,
                                        items: const ['', ..._dependenciaOptions],
                                        onChanged: (v) => setDialogState(
                                          () => tempDependencia = v ?? '',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Entidad compradora en SECOP II',
                                        style: TextStyle(
                                          color: _azulOscuro,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (isLoadingEntities)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _doradoPlataforma,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: entitySearchCtrl,
                                        onChanged: (val) {
                                          setDialogState(
                                            () => tempEntidad = val.trim(),
                                          );
                                        },
                                        onSubmitted: (_) =>
                                            refreshSecopEntities(setDialogState),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _azulOscuro,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Escribe el nombre de la alcaldía, gobernación, hospital o ministerio...',
                                          hintStyle: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          isDense: true,
                                          filled: true,
                                          fillColor: _cremaFondo,
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            size: 17,
                                            color: _azulOscuro,
                                          ),
                                          suffixIcon:
                                              entitySearchCtrl.text.isNotEmpty
                                                  ? IconButton(
                                                      onPressed: () {
                                                        entitySearchCtrl.clear();
                                                        setDialogState(
                                                          () => tempEntidad = '',
                                                        );
                                                        refreshSecopEntities(
                                                          setDialogState,
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.clear,
                                                        size: 15,
                                                      ),
                                                    )
                                                  : null,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 11,
                                            vertical: 9,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: _bordeCalido,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: _bordeCalido,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: _azulOscuro,
                                              width: 1.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 36,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            refreshSecopEntities(setDialogState),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFFFF4D6),
                                          foregroundColor: _azulOscuro,
                                          elevation: 0,
                                          side: const BorderSide(
                                            color: _doradoPlataforma,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.cloud_sync_outlined,
                                          size: 15,
                                          color: _azulOscuro,
                                        ),
                                        label: const Text(
                                          'Buscar entidad',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 115,
                                  decoration: BoxDecoration(
                                    color: _cremaTarjeta,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _bordeCalido),
                                  ),
                                  child: visibleEntities.isEmpty
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(12),
                                            child: Text(
                                              'Pulsa "Buscar entidad" para consultar en SECOP II o escribe libremente el nombre.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Color(0xFF64748B),
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          itemCount: visibleEntities.length,
                                          separatorBuilder: (_, _) =>
                                              const Divider(
                                            height: 1,
                                            color: Color(0xFFEDE6D6),
                                          ),
                                          itemBuilder: (context, idx) {
                                            final entName = visibleEntities[idx];
                                            final isSelected =
                                                _normalizar(tempEntidad) ==
                                                    _normalizar(entName);
                                            return InkWell(
                                              onTap: () {
                                                setDialogState(() {
                                                  tempEntidad = entName;
                                                  entitySearchCtrl.text =
                                                      entName;
                                                });
                                              },
                                              child: Container(
                                                color: isSelected
                                                    ? const Color(0xFFFFF4D6)
                                                    : Colors.transparent,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      isSelected
                                                          ? Icons.check_circle
                                                          : Icons
                                                              .account_balance_outlined,
                                                      size: 14,
                                                      color: isSelected
                                                          ? _azulOscuro
                                                          : const Color(
                                                              0xFF64748B,
                                                            ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        entName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color: _azulOscuro,
                                                          fontSize: 11.5,
                                                          fontWeight: isSelected
                                                              ? FontWeight.w800
                                                              : FontWeight.w500,
                                                        ),
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
                            ),
                          ),
                          sectionCard(
                            number: '3',
                            title: 'Condiciones Contractuales y Cuantía',
                            subtitle:
                                'Modalidad de selección, estado actual, vigencia y rango de valor',
                            icon: Icons.gavel_rounded,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _dialogOptionalDropdown(
                                        label: 'Modalidad de contratación',
                                        placeholder: 'Todas las modalidades',
                                        value: tempModalidad,
                                        items: const ['', ..._modalidadOptions],
                                        onChanged: (v) => setDialogState(
                                          () => tempModalidad = v ?? '',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _dialogOptionalDropdown(
                                        label: 'Estado',
                                        placeholder: 'Todos',
                                        value: tempEstado,
                                        items: const ['', ..._estadoOptions],
                                        onChanged: (v) => setDialogState(
                                          () => tempEstado = v ?? '',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _dialogOptionalDropdown(
                                        label: 'Año de firma',
                                        placeholder: 'Todos',
                                        value: tempAnio,
                                        items: ['', ..._anioOptions],
                                        onChanged: (v) => setDialogState(
                                          () => tempAnio = v ?? '',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Rango de valor del contrato en COP (Opcional)',
                                  style: TextStyle(
                                    color: _azulOscuro,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: minCtrl,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _azulOscuro,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Valor mínimo (ej. 10000000)',
                                          hintStyle: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.attach_money,
                                            size: 16,
                                            color: _azulOscuro,
                                          ),
                                          isDense: true,
                                          filled: true,
                                          fillColor: _cremaFondo,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 9,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: _bordeCalido,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: _bordeCalido,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: maxCtrl,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _azulOscuro,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Valor máximo (ej. 500000000)',
                                          hintStyle: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.attach_money,
                                            size: 16,
                                            color: _azulOscuro,
                                          ),
                                          isDense: true,
                                          filled: true,
                                          fillColor: _cremaFondo,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 9,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: _bordeCalido,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: _bordeCalido,
                                            ),
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
                  ),
                  // Pie de diálogo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: _bordeCalido),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _azulOscuro,
                            side: const BorderSide(color: _bordeCalido),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedSector = tempSector;
                              _selectedOrden = tempOrden;
                              _selectedDepartamento = tempDepto;
                              _selectedMunicipio = tempMuni;
                              _selectedEntidad = entitySearchCtrl.text.trim();
                              _selectedDependencia = tempDependencia;
                              _selectedEstado = tempEstado;
                              _selectedModalidad = tempModalidad;
                              _selectedAnio = tempAnio;
                              _minValueFilter =
                                  double.tryParse(minCtrl.text.trim());
                              _maxValueFilter =
                                  double.tryParse(maxCtrl.text.trim());
                              _currentPage = 1;
                            });
                            Navigator.pop(dialogContext);
                            _fetchLiveSecopContracts();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _azulOscuro,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          icon: const Icon(
                            Icons.search,
                            size: 16,
                            color: _doradoPlataforma,
                          ),
                          label: const Text(
                            'Aplicar filtros y consultar SECOP II',
                            style: TextStyle(
                              fontSize: 12.5,
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
          );
        },
      ),
    );
  }

  Widget _dialogOptionalDropdown({
    required String label,
    required String placeholder,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = items.contains(value) ? value : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _azulOscuro,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            key: ValueKey('$label-$safeValue-${items.length}'),
            initialValue: safeValue,
            isDense: true,
            isExpanded: true,
            style: const TextStyle(color: _azulOscuro, fontSize: 12),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 8,
              ),
              filled: true,
              fillColor: _cremaFondo,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _bordeCalido),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _bordeCalido),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: _azulOscuro, width: 1.3),
              ),
            ),
            items: [
              for (final item in items)
                DropdownMenuItem(
                  value: item,
                  child: Text(
                    item.isEmpty ? placeholder : item,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: item.isEmpty
                          ? const Color(0xFF94A3B8)
                          : _azulOscuro,
                      fontSize: 12,
                      fontWeight: item.isEmpty
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final isMobile = MediaQuery.sizeOf(context).width < 768;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 32,
          decoration: BoxDecoration(
            color: _doradoPlataforma,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Contratos',
          style: TextStyle(
            color: _azulOscuro,
            fontSize: isMobile ? 22 : 26,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 12),
          Container(
            width: 1.5,
            height: 18,
            color: _bordeCalido,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Explora, filtra por sector y consulta procesos contractuales en tiempo real desde SECOP II.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          UserProfileHeaderAction(onLogout: widget.onLogout),
        ] else
          const Spacer(),
      ],
    );
  }

  Widget _buildSectoresMacroFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _doradoPlataforma.withValues(alpha: 0.65),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 12.5,
                    color: _azulOscuro,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Sectores',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Selecciona un sector como macrofiltro para ver todos sus contratos relacionados:',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_selectedSector.isNotEmpty)
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedSector = '';
                    _currentPage = 1;
                  });
                  _fetchLiveSecopContracts(silent: true);
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Ver todos los sectores',
                    style: TextStyle(
                      color: _azulPrimario,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        HorizontalWebScroll(
          child: Row(
            children: [
              for (var i = 0; i < _sectorMacroOptions.length; i++) ...[
                Builder(
                  builder: (context) {
                    final sec = _sectorMacroOptions[i];
                    final bool isSelected = _selectedSector == sec.id;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (_selectedSector == sec.id && sec.id.isNotEmpty) {
                            _selectedSector = '';
                          } else {
                            _selectedSector = sec.id;
                          }
                          _currentPage = 1;
                        });
                        _fetchLiveSecopContracts(silent: true);
                      },
                      borderRadius: BorderRadius.circular(11),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        constraints: const BoxConstraints(minWidth: 132),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? _azulOscuro : _cremaTarjeta,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: isSelected ? _doradoPlataforma : _bordeCalido,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _azulOscuro.withValues(alpha: 0.14),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _doradoPlataforma.withValues(alpha: 0.2)
                                    : sec.softBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                sec.icon,
                                size: 16,
                                color: isSelected
                                    ? _doradoPlataforma
                                    : sec.accentColor,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      sec.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : _azulOscuro,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.check_circle,
                                        size: 12,
                                        color: _doradoPlataforma,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  sec.subtitle,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF64748B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (i < _sectorMacroOptions.length - 1)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    final activeCount = _activeFiltersCount;
    final hasAnyFilter =
        activeCount > 0 || _contractsSearchController.text.trim().isNotEmpty;

    Widget activeFilterChip(String text, VoidCallback onRemove) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4D6),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: _doradoPlataforma.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            InkWell(
              onTap: onRemove,
              child: const Icon(
                Icons.close,
                size: 13,
                color: _azulOscuro,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bordeCalido.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de búsqueda rápida en tiempo real + Botón Buscar + Filtros avanzados
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 230, maxWidth: 460),
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _contractsSearchController,
                    onChanged: (_) {
                      // Sin setState por tecla: reconstruía toda la sección.
                      // La búsqueda (y su setState) se lanza al dejar de escribir.
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 350),
                        () => _executeContractSearch(silent: true),
                      );
                    },
                    onSubmitted: (_) => _executeContractSearch(silent: false),
                    style: const TextStyle(fontSize: 12, color: _azulOscuro),
                    decoration: InputDecoration(
                      hintText:
                          'Buscar proceso, contratista, NIT/Cédula o entidad (o separa por coma)...',
                      hintStyle: TextStyle(
                        color: Colors.blueGrey.shade400,
                        fontSize: 12,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: _cremaFondo,
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _azulOscuro,
                        size: 18,
                      ),
                      suffixIcon: _contractsSearchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _contractsSearchController.clear();
                                _executeContractSearch(silent: true);
                              },
                              icon: const Icon(Icons.clear, size: 15),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: _bordeCalido),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: _bordeCalido),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color: _azulOscuro,
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: () => _executeContractSearch(silent: false),
                  icon: _isLoadingSecop
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _doradoPlataforma,
                          ),
                        )
                      : const Icon(
                          Icons.search,
                          size: 15,
                          color: _doradoPlataforma,
                        ),
                  label: const Text(
                    'Buscar',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azulOscuro,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ),
              // Selector rápido de Vigencia (2015 a 2026)
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _selectedAnio.isNotEmpty
                      ? const Color(0xFFFFF4D6)
                      : _cremaFondo,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: _selectedAnio.isNotEmpty
                        ? _doradoPlataforma
                        : _bordeCalido,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedAnio.isEmpty ? '' : _selectedAnio,
                    icon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: _azulOscuro,
                    ),
                    isDense: true,
                    style: const TextStyle(
                      color: _azulOscuro,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Vigencia: Todas (2015–2026)'),
                      ),
                      for (final anio in _anioOptions)
                        DropdownMenuItem(
                          value: anio,
                          child: Text('Año $anio'),
                        ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedAnio = val ?? '';
                        _currentPage = 1;
                      });
                      _fetchLiveSecopContracts(silent: true);
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: _showAdvancedFiltersDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _azulOscuro,
                    backgroundColor: activeCount > 0
                        ? const Color(0xFFFFF4D6)
                        : _cremaFondo,
                    side: BorderSide(
                      color: activeCount > 0 ? _doradoPlataforma : _bordeCalido,
                      width: activeCount > 0 ? 1.4 : 1,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 15,
                        color: _azulOscuro,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        activeCount > 0
                            ? 'Filtros avanzados ($activeCount)'
                            : 'Filtros avanzados',
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: _azulOscuro,
                      ),
                    ],
                  ),
                ),
              ),
              if (hasAnyFilter)
                TextButton.icon(
                  onPressed: _resetAllFilters,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(
                    Icons.refresh,
                    size: 14,
                    color: _azulOscuro,
                  ),
                  label: const Text(
                    'Limpiar todo',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Tarjetas de Sectores (Macrofiltro)
          _buildSectoresMacroFilter(),
          if (hasAnyFilter) ...[
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 5,
              children: [
                const Text(
                  'Activos:',
                  style: TextStyle(
                    color: _azulOscuro,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_selectedSector.isNotEmpty)
                  activeFilterChip(
                    'Sector: $_selectedSector',
                    () {
                      setState(() => _selectedSector = '');
                      _fetchLiveSecopContracts(silent: true);
                    },
                  ),
                if (_selectedOrden.isNotEmpty)
                  activeFilterChip(
                    'Orden: $_selectedOrden',
                    () {
                      setState(() => _selectedOrden = '');
                      _fetchLiveSecopContracts(silent: true);
                    },
                  ),
                if (_selectedDepartamento.isNotEmpty)
                  activeFilterChip(
                    'Depto: $_selectedDepartamento',
                    () {
                      setState(() {
                        _selectedDepartamento = '';
                        _selectedMunicipio = '';
                      });
                      _fetchLiveSecopContracts(silent: true);
                    },
                  ),
                if (_selectedMunicipio.isNotEmpty)
                  activeFilterChip(
                    'Municipio: $_selectedMunicipio',
                    () {
                      setState(() => _selectedMunicipio = '');
                      _fetchLiveSecopContracts(silent: true);
                    },
                  ),
                if (_selectedEntidad.isNotEmpty)
                  activeFilterChip(
                    'Entidad: $_selectedEntidad',
                    () {
                      setState(() => _selectedEntidad = '');
                      _fetchLiveSecopContracts(silent: true);
                    },
                  ),
                if (_selectedAnio.isNotEmpty)
                  activeFilterChip(
                    'Año: $_selectedAnio',
                    () {
                      setState(() => _selectedAnio = '');
                      _fetchLiveSecopContracts(silent: true);
                    },
                  ),
                if (_selectedModalidad.isNotEmpty)
                  activeFilterChip(
                    'Modalidad: $_selectedModalidad',
                    () {
                      setState(() => _selectedModalidad = '');
                      _fetchLiveSecopContracts(silent: true);
                    },
                  ),
                if (_selectedEstado.isNotEmpty)
                  activeFilterChip(
                    'Estado: $_selectedEstado',
                    () {
                      setState(() => _selectedEstado = '');
                      _fetchLiveSecopContracts(silent: true);
                    },
                  ),
                if (_selectedDependencia.isNotEmpty)
                  activeFilterChip(
                    'Dependencia: $_selectedDependencia',
                    () {
                      setState(() => _selectedDependencia = '');
                    },
                  ),
                if (_contractsSearchController.text.trim().isNotEmpty)
                  activeFilterChip(
                    'Búsqueda: "${_contractsSearchController.text.trim()}"',
                    () {
                      _contractsSearchController.clear();
                      _executeContractSearch();
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKPIsRow() {
    final filtered = _filteredContracts;
    final totalSum = filtered.fold<double>(
      0,
      (sum, item) => sum + item.numericValue,
    );
    final uniqueContractors =
        filtered.map((e) => e.contractor.toUpperCase()).toSet().length;
    final uniqueEntities =
        filtered.map((e) => e.entity.toUpperCase()).toSet().length;

    final String totalContractsText = '${filtered.length}';
    final String totalValueText = _formatShortMillions(totalSum);
    final String contractorsCountText = '$uniqueContractors';
    final String entitiesCountText = '$uniqueEntities';

    Widget kpiCardBox({
      required IconData icon,
      required Color iconColor,
      required Color iconBackground,
      required String label,
      required String value,
      String? subtitleText,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _bordeCalido.withValues(alpha: 0.65)),
          boxShadow: [
            BoxShadow(
              color: _azulOscuro.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 9),
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
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (subtitleText != null) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            subtitleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final kpiCardBoxes = [
      kpiCardBox(
        icon: Icons.description_outlined,
        iconColor: const Color(0xFF2B7DE9),
        iconBackground: const Color(0xFFEAF3FF),
        label: 'Total contratos',
        value: totalContractsText,
        subtitleText: 'SECOP II',
      ),
      kpiCardBox(
        icon: Icons.monetization_on_outlined,
        iconColor: const Color(0xFF22A05B),
        iconBackground: const Color(0xFFE6F6EC),
        label: 'Valor contratado',
        value: totalValueText,
        subtitleText: 'acumulado',
      ),
      kpiCardBox(
        icon: Icons.people_outline,
        iconColor: const Color(0xFF2563EB),
        iconBackground: const Color(0xFFEBF1FF),
        label: 'Contratistas',
        value: contractorsCountText,
        subtitleText: 'verificados',
      ),
      kpiCardBox(
        icon: Icons.account_balance_outlined,
        iconColor: const Color(0xFFE5A024),
        iconBackground: const Color(0xFFFFF6DA),
        label: 'Entidades',
        value: entitiesCountText,
        subtitleText: 'en consulta',
      ),
    ];

    return LayoutBuilder(
      builder: (context, kpiConstraints) {
        if (kpiConstraints.maxWidth >= 980) {
          return Row(
            children: [
              Expanded(child: kpiCardBoxes[0]),
              const SizedBox(width: 10),
              Expanded(child: kpiCardBoxes[1]),
              const SizedBox(width: 10),
              Expanded(child: kpiCardBoxes[2]),
              const SizedBox(width: 10),
              Expanded(child: kpiCardBoxes[3]),
            ],
          );
        }

        return HorizontalWebScroll(
          child: Row(
            children: [
              SizedBox(width: 235, child: kpiCardBoxes[0]),
              const SizedBox(width: 10),
              SizedBox(width: 235, child: kpiCardBoxes[1]),
              const SizedBox(width: 10),
              SizedBox(width: 235, child: kpiCardBoxes[2]),
              const SizedBox(width: 10),
              SizedBox(width: 235, child: kpiCardBoxes[3]),
            ],
          ),
        );
      },
    );
  }

  String _formatShortMillions(double value) {
    if (value >= 1000000) {
      final millions = (value / 1000000).round();
      final formatted = millions.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
      return '\$$formatted M';
    }
    return _formatCop(value);
  }

  Widget _buildTableHeader() {
    final count = _filteredContracts.length;
    final countText = _isLoadingSecop
        ? 'Consultando SECOP II en tiempo real...'
        : '$count contratos encontrados';

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            const Text(
              'Resultados de búsqueda',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _doradoPlataforma.withValues(alpha: 0.65),
                ),
              ),
              child: Text(
                countText,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text(
              'Ordenar por:',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _bordeCalido),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  isDense: true,
                  icon: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: _azulOscuro,
                    ),
                  ),
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Más recientes',
                      child: Text('Más recientes'),
                    ),
                    DropdownMenuItem(
                      value: 'Mayor valor',
                      child: Text('Mayor valor'),
                    ),
                    DropdownMenuItem(
                      value: 'Menor valor',
                      child: Text('Menor valor'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                        _currentPage = 1;
                      });
                    }
                  },
                ),
              ),
            ),
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                onPressed: _exportFilteredToCsv,
                icon: const Icon(
                  Icons.download_rounded,
                  size: 15,
                  color: _azulOscuro,
                ),
                label: const Text(
                  'Exportar',
                  style: TextStyle(
                    color: _azulOscuro,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _azulOscuro,
                  side: const BorderSide(color: _bordeCalido),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColumnTitles() {
    const titles = [
      'Proceso / Objeto contractual',
      'Entidad / Ubicación',
      'Contratista',
      'Valor',
      'Estado',
      'Fechas',
    ];
    const flexes = [3, 2, 2, 1, 1, 1];

    return Container(
      color: const Color(0xFFEEF3F8),
      child: Row(
        children: [
          for (var index = 0; index < titles.length; index++)
            Expanded(
              flex: flexes[index],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Text(
                  titles[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          const SizedBox(
            width: 148,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Text(
                'Acciones',
                maxLines: 1,
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(ContractRecord contract) {
    final analisis = ContractFinancialAnalysis.fromContract(contract.rawSecopJson);
    final Color statusColor = switch (contract.status) {
      'En ejecución' => const Color(0xFF15803D),
      'Aprobado' || 'En aprobación' => const Color(0xFFB45309),
      'Modificado' => const Color(0xFF6D28D9),
      'Terminado' || 'Cerrado' => const Color(0xFF0369A1),
      'Liquidado' => const Color(0xFFB91C1C),
      _ => Colors.blueGrey,
    };
    final Color statusBackground = switch (contract.status) {
      'En ejecución' => const Color(0xFFDCFCE7),
      'Aprobado' || 'En aprobación' => const Color(0xFFFEF3C7),
      'Modificado' => const Color(0xFFEDE9FE),
      'Terminado' || 'Cerrado' => const Color(0xFFE0F2FE),
      'Liquidado' => const Color(0xFFFEE2E2),
      _ => const Color(0xFFF1F5F9),
    };

    Widget cell(int flex, Widget child) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: child,
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        cell(
          3,
          InkWell(
            onTap: () => _openContractDetail(contract),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: contract.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    contract.icon,
                    color: contract.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Número de proceso en negrilla arriba (prioridad visual)
                      Text(
                        contract.processCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Objeto contractual abajo más pequeño
                      Text(
                        contract.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                          fontSize: 10.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        cell(
          2,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                contract.entity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${contract.location} · ${contract.department}',
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
        cell(
          2,
          InkWell(
            onTap: () => _openContractorProfile(contract),
            borderRadius: BorderRadius.circular(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contract.contractor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contract.contractorId,
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
        ),
        cell(
          1,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                contract.valueFormatted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (analisis.tienePlazo && analisis.valorTotal > 0) ...[
                const SizedBox(height: 1),
                Text(
                  analisis.esMenorAUnMes
                      ? '${analisis.plazoDias}d total'
                      : '≈ ${ContractFinancialAnalysis.formatCop(analisis.valorMensualEstimado)}/m',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        cell(
          1,
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
              decoration: BoxDecoration(
                color: statusBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                contract.status,
                maxLines: 1,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        cell(
          1,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${contract.startDate}\n${contract.endDate}',
                maxLines: 2,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 10.5,
                  height: 1.25,
                ),
              ),
              if (analisis.tienePlazo) ...[
                const SizedBox(height: 1),
                Text(
                  '${analisis.plazoDias}d · ${analisis.mesesDecimalTexto}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          width: 148,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Tooltip(
                  message: 'Vista rápida del contrato',
                  child: InkWell(
                    onTap: () => _showQuickViewModal(contract),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 30,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: _azulOscuro,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _openContractDetail(contract),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.only(left: 10, right: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver detalle',
                          style: TextStyle(
                            color: _azulPrimario,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          size: 15,
                          color: _azulPrimario,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContractsTable() {
    final rows = _currentPageContracts;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, tableConstraints) {
          final tableBody = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildColumnTitles(),
              if (_isLoadingSecop)
                const LinearProgressIndicator(
                  minHeight: 2.5,
                  color: _azulPrimario,
                  backgroundColor: Color(0xFFE2E8F0),
                )
              else
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No se encontraron contratos con los filtros seleccionados.',
                        style: TextStyle(
                          color: _azulOscuro,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _resetAllFilters,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text(
                          'Limpiar filtros y consultar SECOP II',
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (var index = 0; index < rows.length; index++) ...[
                  _buildTableRow(rows[index]),
                  if (index < rows.length - 1)
                    const Divider(height: 1, color: Color(0xFFEFF3F8)),
                ],
            ],
          );

          if (tableConstraints.maxWidth < 820) {
            return HorizontalWebScroll(
              child: SizedBox(width: 880, child: tableBody),
            );
          }
          return tableBody;
        },
      ),
    );
  }

  Widget _buildPaginationRow() {
    final all = _filteredContracts;
    final totalCount = all.length;
    final totalPages = _totalPages;
    final safePage = _currentPage.clamp(1, totalPages);

    final startItem = totalCount == 0 ? 0 : ((safePage - 1) * _pageSize) + 1;
    final endItem = totalCount == 0
        ? 0
        : (startItem + _pageSize - 1).clamp(1, totalCount);

    Widget pageNumber(String label, {int? pageTarget}) {
      final bool selected = pageTarget != null && safePage == pageTarget;
      return InkWell(
        onTap: pageTarget == null
            ? null
            : () {
                setState(() {
                  _currentPage = pageTarget.clamp(1, totalPages);
                });
              },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minWidth: 28),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _azulOscuro : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _azulOscuro,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    Widget arrowButton(IconData icon, VoidCallback? onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(
            icon,
            color: onTap != null ? _azulOscuro : const Color(0xFFCBD5E1),
            size: 17,
          ),
        ),
      );
    }

    final pageButtons = <Widget>[];
    if (totalPages <= 7) {
      for (var p = 1; p <= totalPages; p++) {
        pageButtons.add(pageNumber('$p', pageTarget: p));
      }
    } else {
      pageButtons.add(pageNumber('1', pageTarget: 1));
      if (safePage > 3) {
        pageButtons.add(pageNumber('...'));
      }
      final startMid = (safePage - 1).clamp(2, totalPages - 3);
      final endMid = (safePage + 1).clamp(4, totalPages - 1);
      for (var p = startMid; p <= endMid; p++) {
        pageButtons.add(pageNumber('$p', pageTarget: p));
      }
      if (safePage < totalPages - 2) {
        pageButtons.add(pageNumber('...'));
      }
      pageButtons.add(pageNumber('$totalPages', pageTarget: totalPages));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4, left: 4, right: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            'Mostrando $startItem - $endItem de $totalCount resultados (Página $safePage de $totalPages)',
            style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              arrowButton(
                Icons.chevron_left,
                safePage > 1
                    ? () => setState(() => _currentPage = safePage - 1)
                    : null,
              ),
              ...pageButtons,
              arrowButton(
                Icons.chevron_right,
                safePage < totalPages
                    ? () => setState(() => _currentPage = safePage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: _cremaFondo,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double horizontalPad =
                constraints.maxWidth > 1220 ? 24.0 : 18.0;
            return SingleChildScrollView(
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 150,
                    child: Image.asset(
                      'assets/images/fondo_valledupar.jpg',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.0, -0.38),
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) => Container(),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 150,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            _cremaFondo,
                            _cremaFondo.withValues(alpha: 0.92),
                            _cremaFondo.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.36, 0.65],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    height: 50,
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
                      12,
                      horizontalPad,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeaderSection(),
                        const SizedBox(height: 8),
                        _buildFiltersPanel(),
                        const SizedBox(height: 8),
                        _buildKPIsRow(),
                        const SizedBox(height: 9),
                        _buildTableHeader(),
                        const SizedBox(height: 7),
                        _buildContractsTable(),
                        _buildPaginationRow(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
