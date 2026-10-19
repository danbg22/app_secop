import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/colombia_secop_catalog.dart';
import '../../utils/csv_exporter.dart';
import '../../widgets/dashboard_top_bar.dart';
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
  static const int _pageSize = 4;

  final TextEditingController _contractsSearchController =
      TextEditingController();

  // Todos los filtros inician en blanco para que el usuario elija libremente qué consultar
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

  static const List<String> _anioOptions = [
    '2026',
    '2025',
    '2024',
    '2023',
    '2022',
  ];

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
    _contractsSearchController.dispose();
    super.dispose();
  }

  int get _activeFiltersCount {
    var count = 0;
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
        '2026-01-15';
    final rawStartDate =
        raw['fecha_de_inicio_del_contrato']?.toString() ?? rawSignDate;
    final rawEndDate =
        raw['fecha_de_fin_del_contrato']?.toString() ?? rawSignDate;
    final year =
        rawSignDate.length >= 4 ? rawSignDate.substring(0, 4) : '2026';

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
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('contratos_favoritos') ?? [];
    final ids = <String>{};
    for (final item in favs) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        final id = decoded['proceso_de_compra']?.toString() ??
            decoded['id_contrato']?.toString() ??
            decoded['referencia_del_contrato']?.toString() ??
            '';
        if (id.isNotEmpty) ids.add(id);
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _favoriteIds = ids);
    }
  }

  Future<void> _toggleFavorite(ContractRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('contratos_favoritos') ?? [];
    final map = record.toSecopMap();
    final contractId = map['proceso_de_compra']?.toString() ??
        map['id_contrato']?.toString() ??
        record.processCode;

    final isSaved = _favoriteIds.contains(contractId);
    if (isSaved) {
      favs.removeWhere((item) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          final savedId = decoded['proceso_de_compra']?.toString() ??
              decoded['id_contrato']?.toString() ??
              '';
          return savedId == contractId;
        } catch (_) {
          return false;
        }
      });
      _favoriteIds.remove(contractId);
    } else {
      favs.add(jsonEncode(map));
      _favoriteIds.add(contractId);
    }

    await prefs.setStringList('contratos_favoritos', favs);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSaved
              ? 'Contrato eliminado de Favoritos'
              : 'Contrato guardado en Favoritos ⭐',
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
        .replaceAll('Ü', 'U');
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
        .replaceAll('MEDICA', 'MÉDICA');
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
    final clean = entidad.replaceAll("'", '').trim();
    if (clean.isEmpty) return null;

    final norm = _normalizar(clean);
    final words = norm
        .replaceAll('(', ' ')
        .replaceAll(')', ' ')
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where(
          (w) =>
              w.length > 2 &&
              !{'DEL', 'LAS', 'LOS', 'PARA', 'POR', 'CON', 'E.S.E.'}
                  .contains(w),
        )
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

  String? _buildSearchSoqlClause(String rawQuery) {
    final cleaned = rawQuery.replaceAll("'", '').trim();
    if (cleaned.isEmpty) return null;

    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.trim().isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;

    final tokenClauses = <String>[];
    for (final rawToken in tokens) {
      final tNorm = _normalizar(rawToken);
      final tOrig = rawToken.toUpperCase();
      final tTilde = _conTildeComun(tNorm);

      final variants = <String>{tNorm, tOrig, tTilde}
          .where((v) => v.isNotEmpty)
          .toList();
      final fieldChecks = <String>[];
      for (final v in variants) {
        fieldChecks.addAll([
          "upper(descripcion_del_proceso) LIKE '%$v%'",
          "upper(objeto_del_contrato) LIKE '%$v%'",
          "upper(proveedor_adjudicado) LIKE '%$v%'",
          "upper(documento_proveedor) LIKE '%$v%'",
          "upper(nombre_entidad) LIKE '%$v%'",
          "upper(referencia_del_contrato) LIKE '%$v%'",
          "upper(proceso_de_compra) LIKE '%$v%'",
          "upper(id_contrato) LIKE '%$v%'",
        ]);
      }
      tokenClauses.add('(${fieldChecks.join(' OR ')})');
    }

    return tokenClauses.join(' AND ');
  }

  Future<void> _fetchLiveSecopContracts({
    String? customQuery,
    bool silent = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _isLoadingSecop = true;
    });

    try {
      final queryText =
          (customQuery ?? _contractsSearchController.text).trim();

      Future<List<ContractRecord>> runSoqlQuery({
        required bool applyYearFilter,
      }) async {
        final whereClauses = <String>[
          'fecha_de_firma IS NOT NULL',
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
          final dNorm = _normalizar(_selectedDepartamento);
          final dOrig = _selectedDepartamento.toUpperCase();
          if (dNorm == 'BOGOTA D.C.') {
            whereClauses.add(
              "(upper(departamento) LIKE '%BOGOT%' OR upper(ciudad) LIKE '%BOGOT%')",
            );
          } else if (dNorm.contains('SAN ANDRES')) {
            whereClauses.add("upper(departamento) LIKE '%SAN ANDR%'");
          } else if (dNorm != dOrig) {
            whereClauses.add(
              "(upper(departamento) LIKE '%$dNorm%' OR upper(departamento) LIKE '%$dOrig%')",
            );
          } else {
            whereClauses.add("upper(departamento) LIKE '%$dNorm%'");
          }
        }

        // Filtro por Municipio
        if (_selectedMunicipio.isNotEmpty) {
          final mNorm = _normalizar(_selectedMunicipio);
          final mOrig = _selectedMunicipio.toUpperCase();
          if (mNorm == 'BOGOTA D.C.') {
            whereClauses.add("upper(ciudad) LIKE '%BOGOT%'");
          } else if (mNorm != mOrig) {
            whereClauses.add(
              "(upper(ciudad) LIKE '%$mNorm%' OR upper(ciudad) LIKE '%$mOrig%' OR upper(nombre_entidad) LIKE '%$mNorm%')",
            );
          } else {
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

        // Filtro por Año
        if (applyYearFilter && _selectedAnio.isNotEmpty) {
          whereClauses.add(
            "(fecha_de_firma >= '$_selectedAnio-01-01T00:00:00.000' AND fecha_de_firma <= '$_selectedAnio-12-31T23:59:59.999')",
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

        if (queryText.isNotEmpty) {
          final searchClause = _buildSearchSoqlClause(queryText);
          if (searchClause != null) {
            whereClauses.add(searchClause);
          }
        }

        final whereParam = Uri.encodeComponent(whereClauses.join(' AND '));
        final url = Uri.parse(
          'https://www.datos.gov.co/resource/jbjy-vk9h.json?\$limit=120&\$order=fecha_de_firma%20DESC&\$where=$whereParam',
        );

        final response =
            await http.get(url).timeout(const Duration(seconds: 14));
        if (response.statusCode != 200) return [];

        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final parsed = <ContractRecord>[];
        for (var i = 0; i < data.length; i++) {
          final raw = Map<String, dynamic>.from(data[i] as Map);
          final record = _parseSecopJsonToRecord(raw, i);
          if (record != null) {
            parsed.add(record);
          }
        }
        return parsed;
      }

      var results = await runSoqlQuery(applyYearFilter: true);

      if (results.isEmpty && _selectedAnio.isNotEmpty) {
        results = await runSoqlQuery(applyYearFilter: false);
        if (results.isNotEmpty && mounted) {
          setState(() => _selectedAnio = '');
        }
      }

      if (!mounted) return;
      setState(() {
        if (results.isNotEmpty ||
            queryText.isNotEmpty ||
            _activeFiltersCount > 0) {
          _secopContracts = results;
        }
        _isLoadingSecop = false;
        _currentPage = 1;
      });

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              results.isNotEmpty
                  ? 'Se cargaron ${results.length} contratos desde SECOP II.'
                  : 'No se encontraron contratos en SECOP II con ese criterio.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
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

  List<ContractRecord> get _filteredContracts {
    final list = _secopContracts.where((c) {
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

  void _executeContractSearch() {
    setState(() => _currentPage = 1);
    _fetchLiveSecopContracts(
      customQuery: _contractsSearchController.text.trim(),
    );
  }

  void _resetAllFilters() {
    setState(() {
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
        'Fecha de Inicio',
        'Fecha de Fin',
      ],
      for (final contract in list)
        [
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
          contract.startDate,
          contract.endDate,
        ],
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilContratistaScreen(
          nombreContratista: contract.contractor,
          nombreBuscado: rawContractorName,
        ),
      ),
    );
  }

  void _showQuickViewModal(ContractRecord contract) {
    final map = contract.toSecopMap();
    final contractId = map['proceso_de_compra']?.toString() ??
        map['id_contrato']?.toString() ??
        contract.processCode;
    final isFav = _favoriteIds.contains(contractId);
    final secopUrl = (map['urlproceso'] is Map
            ? map['urlproceso']['url']?.toString()
            : null) ??
        'https://community.secop.gov.co/Public/Tendering/ContractNoticeManagement/Index';

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
                      'Valor del contrato',
                      contract.valueFormatted,
                    ),
                    _quickInfoTile('Estado', contract.status),
                    _quickInfoTile('Dependencia / Sector', contract.department),
                    _quickInfoTile('Modalidad', contract.modality),
                    _quickInfoTile(
                      'Plazo de ejecución',
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

  Widget _quickInfoTile(String label, String value) {
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
            style: const TextStyle(
              color: _azulOscuro,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdvancedFiltersDialog() {
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

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_outlined,
                          color: _azulPrimario,
                          size: 21,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Filtros avanzados · Base de Entidades SECOP II',
                            style: TextStyle(
                              color: _azulOscuro,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
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
                          child: const Text(
                            'Dejar en blanco',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, size: 19),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '1. Orden de la entidad',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Todos los órdenes'),
                          selected: tempOrden.isEmpty,
                          selectedColor: const Color(0xFFEAF2FF),
                          labelStyle: TextStyle(
                            color: tempOrden.isEmpty
                                ? _azulPrimario
                                : _azulOscuro,
                            fontSize: 11.5,
                            fontWeight: tempOrden.isEmpty
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          onSelected: (_) {
                            setDialogState(() => tempOrden = '');
                            refreshSecopEntities(setDialogState);
                          },
                        ),
                        for (final ord in ColombiaSecopCatalog.ordenesEntidad)
                          ChoiceChip(
                            label: Text('Orden $ord'),
                            selected: tempOrden == ord,
                            selectedColor: const Color(0xFFEAF2FF),
                            labelStyle: TextStyle(
                              color: tempOrden == ord
                                  ? _azulPrimario
                                  : _azulOscuro,
                              fontSize: 11.5,
                              fontWeight: tempOrden == ord
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            onSelected: (_) {
                              setDialogState(() => tempOrden = ord);
                              refreshSecopEntities(setDialogState);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _dialogOptionalDropdown(
                            label: '2. Departamento (Opcional)',
                            placeholder: 'En blanco (Cualquier departamento)',
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
                            label: '3. Municipio / Ciudad (Opcional)',
                            placeholder: tempDepto.isEmpty
                                ? 'Selecciona primero un depto.'
                                : 'En blanco (Todo $tempDepto)',
                            value: tempMuni,
                            items: muniItems,
                            onChanged: (v) {
                              setDialogState(() => tempMuni = v ?? '');
                              refreshSecopEntities(setDialogState);
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '4. Entidad pública (Nacional, Departamental o Municipal)',
                            style: TextStyle(
                              color: _azulOscuro,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isLoadingEntities)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                              setDialogState(() => tempEntidad = val.trim());
                            },
                            onSubmitted: (_) =>
                                refreshSecopEntities(setDialogState),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: _azulOscuro,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'En blanco o escribe el nombre de cualquier entidad de Colombia...',
                              hintStyle: const TextStyle(fontSize: 12),
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFFBFCFD),
                              prefixIcon: const Icon(
                                Icons.account_balance_outlined,
                                size: 17,
                                color: _azulOscuro,
                              ),
                              suffixIcon: entitySearchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      onPressed: () {
                                        entitySearchCtrl.clear();
                                        setDialogState(() => tempEntidad = '');
                                        refreshSecopEntities(setDialogState);
                                      },
                                      icon: const Icon(Icons.clear, size: 16),
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 38,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                refreshSecopEntities(setDialogState),
                            icon: const Icon(Icons.cloud_sync_outlined, size: 16),
                            label: const Text(
                              'Consultar SECOP',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 135,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: visibleEntities.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'Pulsa "Consultar SECOP" para buscar ese nombre directamente en SECOP II o escribe libremente la entidad.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: visibleEntities.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: Color(0xFFEEF2F6),
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
                                      entitySearchCtrl.text = entName;
                                    });
                                  },
                                  child: Container(
                                    color: isSelected
                                        ? const Color(0xFFEAF2FF)
                                        : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.account_balance_outlined,
                                          size: 14,
                                          color: isSelected
                                              ? _azulPrimario
                                              : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            entName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _azulOscuro,
                                              fontSize: 11.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _dialogOptionalDropdown(
                            label: 'Dependencia / Área (Opcional)',
                            placeholder: 'En blanco (Todas)',
                            value: tempDependencia,
                            items: const ['', ..._dependenciaOptions],
                            onChanged: (v) => setDialogState(
                              () => tempDependencia = v ?? '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dialogOptionalDropdown(
                            label: 'Modalidad (Opcional)',
                            placeholder: 'En blanco (Todas)',
                            value: tempModalidad,
                            items: const ['', ..._modalidadOptions],
                            onChanged: (v) =>
                                setDialogState(() => tempModalidad = v ?? ''),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _dialogOptionalDropdown(
                            label: 'Estado del contrato (Opcional)',
                            placeholder: 'En blanco (Todos)',
                            value: tempEstado,
                            items: const ['', ..._estadoOptions],
                            onChanged: (v) =>
                                setDialogState(() => tempEstado = v ?? ''),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dialogOptionalDropdown(
                            label: 'Año de firma (Opcional)',
                            placeholder: 'En blanco (Todos los años)',
                            value: tempAnio,
                            items: const ['', ..._anioOptions],
                            onChanged: (v) =>
                                setDialogState(() => tempAnio = v ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Valor contratado en COP (Opcional)',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 12,
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
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Mínimo (ej. 10000000)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Máximo (ej. 500000000)',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.search, size: 17),
                        label: const Text(
                          'Consultar en SECOP II',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _azulOscuro,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('$label-$safeValue-${items.length}'),
            initialValue: safeValue,
            isDense: true,
            isExpanded: true,
            style: const TextStyle(color: _azulOscuro, fontSize: 12.5),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 9,
              ),
              filled: true,
              fillColor: const Color(0xFFFBFCFD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFE3E8EE)),
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
                      fontSize: 12.5,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFF5B82E),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Contratos',
          style: TextStyle(
            color: _azulOscuro,
            fontSize: 38,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Explora y consulta todos los contratos del sector público.',
          style: TextStyle(color: Color(0xFF475569), fontSize: 15.5),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _azulOscuro.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _contractsSearchController,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _executeContractSearch(),
                    style: const TextStyle(fontSize: 12.5, color: _azulOscuro),
                    decoration: InputDecoration(
                      hintText:
                          'Buscar por objeto, número de proceso, entidad, contratista o NIT/Cédula...',
                      hintStyle: TextStyle(
                        color: Colors.blueGrey.shade400,
                        fontSize: 12.5,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF3F6FA),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _azulOscuro,
                        size: 19,
                      ),
                      suffixIcon: _contractsSearchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _contractsSearchController.clear();
                                _executeContractSearch();
                              },
                              icon: const Icon(Icons.clear, size: 16),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: _azulOscuro),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: _executeContractSearch,
                  icon: _isLoadingSecop
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search, size: 16, color: Colors.white),
                  label: const Text(
                    'Buscar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13294B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 38,
                child: TextButton(
                  onPressed: _showAdvancedFiltersDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: _azulOscuro,
                    backgroundColor: const Color(0xFFEDF2F9),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.filter_alt_outlined,
                        size: 16,
                        color: _azulPrimario,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        activeCount > 0
                            ? 'Filtros avanzados ($activeCount)'
                            : 'Filtros avanzados',
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 17,
                        color: _azulOscuro,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (hasAnyFilter) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Text(
                        'Filtros activos:',
                        style: TextStyle(
                          color: _azulOscuro,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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
                ),
                TextButton.icon(
                  onPressed: _resetAllFilters,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(
                    Icons.refresh,
                    size: 15,
                    color: _azulPrimario,
                  ),
                  label: const Text(
                    'Limpiar filtros',
                    style: TextStyle(
                      color: _azulPrimario,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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

    Widget kpi({
      required IconData icon,
      required Color iconColor,
      required Color iconBackground,
      required String label,
      required String value,
      String? trendText,
      String? subtitleText,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 25),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (trendText != null)
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: trendText,
                              style: const TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: ' ${subtitleText ?? 'SECOP II'}',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (subtitleText != null)
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
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

    return Row(
      children: [
        kpi(
          icon: Icons.description_outlined,
          iconColor: const Color(0xFF2B7DE9),
          iconBackground: const Color(0xFFEAF3FF),
          label: 'Total de contratos',
          value: totalContractsText,
          trendText: 'SECOP II',
          subtitleText: 'en esta consulta',
        ),
        const SizedBox(width: 14),
        kpi(
          icon: Icons.monetization_on,
          iconColor: const Color(0xFF22A05B),
          iconBackground: const Color(0xFFE6F6EC),
          label: 'Valor contratado',
          value: totalValueText,
          trendText: '100% real',
          subtitleText: 'acumulado',
        ),
        const SizedBox(width: 14),
        kpi(
          icon: Icons.people,
          iconColor: const Color(0xFF2563EB),
          iconBackground: const Color(0xFFEBF1FF),
          label: 'Contratistas',
          value: contractorsCountText,
          trendText: 'Verificados',
          subtitleText: 'con NIT / C.C.',
        ),
        const SizedBox(width: 14),
        kpi(
          icon: Icons.account_balance,
          iconColor: const Color(0xFFE5A024),
          iconBackground: const Color(0xFFFFF6DA),
          label: 'Entidades',
          value: entitiesCountText,
          subtitleText: 'en los resultados',
        ),
      ],
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resultados de búsqueda',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                countText,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        const Text(
          'Ordenar por:',
          style: TextStyle(
            color: Color(0xFF475569),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortBy,
              isDense: true,
              icon: const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: _azulOscuro,
                ),
              ),
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
        const SizedBox(width: 10),
        SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            onPressed: _exportFilteredToCsv,
            icon: const Icon(
              Icons.download_rounded,
              size: 16,
              color: _azulOscuro,
            ),
            label: const Text(
              'Exportar',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _azulOscuro,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColumnTitles() {
    const titles = [
      'Objeto del contrato',
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
                  vertical: 10,
                ),
                child: Text(
                  titles[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          const SizedBox(
            width: 148,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Text(
                'Acciones',
                maxLines: 1,
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(ContractRecord contract) {
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: contract.iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    contract.icon,
                    color: contract.color,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        contract.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contract.processCode,
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
          Text(
            '${contract.startDate}\n${contract.endDate}',
            maxLines: 2,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 10.5,
              height: 1.3,
            ),
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
      child: Column(
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
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
                    label: const Text('Limpiar filtros y consultar SECOP II'),
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Mostrando $startItem - $endItem de $totalCount resultados (Página $safePage de $totalPages)',
              style: const TextStyle(color: Color(0xFF475569), fontSize: 12),
            ),
          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          DashboardTopBar(
            searchController: widget.topSearchController,
            onSearchSubmitted: (value) {
              _contractsSearchController.text = value;
              _executeContractSearch();
            },
            onLogout: widget.onLogout,
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFFAF5EA),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double horizontalPad =
                      constraints.maxWidth > 1220 ? 28.0 : 24.0;
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
                            18,
                            horizontalPad,
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeaderSection(),
                              const SizedBox(height: 14),
                              _buildFiltersPanel(),
                              const SizedBox(height: 12),
                              _buildKPIsRow(),
                              const SizedBox(height: 14),
                              _buildTableHeader(),
                              const SizedBox(height: 10),
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
          ),
        ],
      ),
    );
  }
}
