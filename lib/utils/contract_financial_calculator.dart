import 'dart:convert';

import 'package:intl/intl.dart';

/// Campo individual formateado para mostrar en la ficha técnica del contrato.
class ContractFieldEntry {
  const ContractFieldEntry({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final String value;
}

/// Sección agrupada de la ficha técnica (Identificación, Cronograma, etc.).
class ContractFieldSection {
  const ContractFieldSection({
    required this.id,
    required this.title,
    required this.entries,
  });

  final String id;
  final String title;
  final List<ContractFieldEntry> entries;
}

/// Motor de análisis financiero y de plazo para contratos SECOP II / SECOP I.
///
/// Convención usada (estándar en la contratación pública colombiana para
/// honorarios y prestación de servicios): **1 mes comercial = 30 días** y
/// el año comercial = 360 días. Cuando hay fechas de inicio y fin, el plazo
/// comercial se calcula con el método 30/360 (europeo), de modo que un
/// contrato del 1 de febrero al 30 de junio equivale exactamente a 5 meses.
class ContractFinancialAnalysis {
  ContractFinancialAnalysis._({
    required this.valorTotal,
    required this.fechaFirma,
    required this.fechaInicio,
    required this.fechaFin,
    required this.diasCalendario,
    required this.diasComerciales,
    required this.diasAdicionados,
    required this.fuentePlazo,
    required this.duracionReportada,
    required this.pagos,
    required this.fuentesRecursos,
  });

  /// Valor total del contrato (COP).
  final double valorTotal;
  final DateTime? fechaFirma;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  /// Días calendario reales entre inicio y fin (ambos inclusive).
  final int? diasCalendario;

  /// Días comerciales (base 30 días/mes) usados para el valor mensual.
  final int? diasComerciales;

  /// Días adicionados por prórrogas, según SECOP.
  final int diasAdicionados;

  /// Descripción de dónde se obtuvo el plazo (fechas o duración reportada).
  final String fuentePlazo;

  /// Texto de duración tal cual lo reporta SECOP (ej. "4 Mes(es)").
  final String duracionReportada;

  /// Ejecución de pagos reportada (etiqueta → valor), solo valores > 0.
  final Map<String, double> pagos;

  /// Fuentes de financiación reportadas (etiqueta → valor), solo valores > 0.
  final Map<String, double> fuentesRecursos;

  static final NumberFormat _cop = NumberFormat.decimalPattern('es_CO');
  static final NumberFormat _dec = NumberFormat('#,##0.##', 'es_CO');

  bool get tienePlazo => (diasComerciales ?? 0) > 0;

  /// Plazo efectivo (en días base 30) para cálculos de valor por día/mes.
  int get plazoDias => diasComerciales ?? 0;

  double get mesesEquivalentes => tienePlazo ? plazoDias / 30.0 : 0;
  int get mesesCompletos => tienePlazo ? plazoDias ~/ 30 : 0;
  int get diasRestantesDelMes => tienePlazo ? plazoDias % 30 : 0;

  double get valorDiario =>
      tienePlazo && valorTotal > 0 ? valorTotal / plazoDias : 0;

  /// Valor mensual estimado = (valor total ÷ días del plazo) × 30.
  double get valorMensualEstimado => valorDiario * 30.0;

  /// `true` si el contrato dura menos de un mes comercial.
  bool get esMenorAUnMes => tienePlazo && plazoDias < 30;

  bool get tieneDatosFinancieros => valorTotal > 0;

  /// Porcentaje de tiempo transcurrido (0.0 – 1.0) o `null` si no aplica.
  double? get avanceTemporal {
    final ini = fechaInicio;
    final fin = fechaFin;
    if (ini == null || fin == null || !fin.isAfter(ini)) return null;
    final now = DateTime.now();
    if (now.isBefore(ini)) return 0;
    if (now.isAfter(fin)) return 1;
    final total = fin.difference(ini).inMinutes;
    if (total <= 0) return null;
    return (now.difference(ini).inMinutes / total).clamp(0.0, 1.0);
  }

  String get estadoTemporal {
    final ini = fechaInicio;
    final fin = fechaFin;
    if (ini == null || fin == null) return 'Sin fechas de ejecución reportadas';
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    if (hoySinHora.isBefore(ini)) {
      final d = ini.difference(hoySinHora).inDays;
      return 'Inicia en $d ${d == 1 ? 'día' : 'días'}';
    }
    if (hoySinHora.isAfter(fin)) {
      return 'Plazo finalizado el ${formatFecha(fin)}';
    }
    final restantes = fin.difference(hoySinHora).inDays;
    return 'En ejecución · faltan $restantes ${restantes == 1 ? 'día' : 'días'}';
  }

  // ---------------------------------------------------------------------------
  // Formateadores públicos
  // ---------------------------------------------------------------------------

  static String formatCop(double value) => '\$ ${_cop.format(value.round())}';

  static String formatDecimal(double value) => _dec.format(value);

  static String formatFecha(DateTime? d) {
    if (d == null) return 'No reportada';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  /// Ej. "4,5 meses".
  String get mesesDecimalTexto {
    if (!tienePlazo) return 'No reportado';
    final m = mesesEquivalentes;
    return '${formatDecimal(m)} ${m == 1 ? 'mes' : 'meses'}';
  }

  /// Ej. "4 meses y 15 días".
  String get mesesDesglosadosTexto {
    if (!tienePlazo) return 'No reportado';
    final partes = <String>[];
    if (mesesCompletos > 0) {
      partes.add('$mesesCompletos ${mesesCompletos == 1 ? 'mes' : 'meses'}');
    }
    if (diasRestantesDelMes > 0) {
      partes.add(
        '$diasRestantesDelMes ${diasRestantesDelMes == 1 ? 'día' : 'días'}',
      );
    }
    return partes.isEmpty ? '0 días' : partes.join(' y ');
  }

  /// Ej. "135 días · equivale a 4,5 meses (4 meses y 15 días)".
  String get equivalenciaTexto {
    if (!tienePlazo) return 'Plazo no reportado en SECOP';
    final cal = diasCalendario;
    final calTxt = (cal != null && cal != plazoDias)
        ? ' ($cal días calendario)'
        : '';
    return '$plazoDias días$calTxt · equivale a $mesesDecimalTexto '
        '($mesesDesglosadosTexto)';
  }

  /// Texto corto para tarjetas/listados: "4,5 meses · \$ 3.200.000/mes".
  String get resumenCorto {
    if (!tienePlazo) return '';
    if (valorTotal <= 0) return mesesDecimalTexto;
    if (esMenorAUnMes) {
      return '$plazoDias días · ${formatCop(valorTotal)} total';
    }
    return '$mesesDecimalTexto · ${formatCop(valorMensualEstimado)}/mes';
  }

  // ---------------------------------------------------------------------------
  // Construcción
  // ---------------------------------------------------------------------------

  factory ContractFinancialAnalysis.fromContract(dynamic rawContract) {
    final Map<String, dynamic> c = rawContract is Map
        ? rawContract.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final valorTotal = _firstMoney(c, const [
      'valor_del_contrato',
      'cuantia_contrato',
      'valor_contrato_con_adiciones',
      'valor_total_adjudicacion',
    ]);

    final fechaFirma = _firstDate(c, const [
      'fecha_de_firma',
      'fecha_de_firma_del_contrato',
    ]);
    final fechaInicio = _firstDate(c, const [
      'fecha_de_inicio_del_contrato',
      'fecha_de_inicio_de_ejecucion',
      'fecha_ini_ejec_contrato',
    ]);
    final fechaFin = _firstDate(c, const [
      'fecha_de_fin_del_contrato',
      'fecha_de_fin_de_ejecucion',
      'fecha_fin_ejec_contrato',
    ]);

    final diasAdicionados = _firstInt(c, const [
          'dias_adicionados',
          'tiempo_adiciones_en_dias',
        ]) ??
        0;

    final duracionReportada = _firstText(c, const [
      'duraci_n_del_contrato',
      'duracion_del_contrato',
      'plazo_de_ejec_del_contrato',
    ]);

    int? diasCalendario;
    int? diasComerciales;
    String fuente = 'Sin información de plazo';

    if (fechaInicio != null &&
        fechaFin != null &&
        !fechaFin.isBefore(fechaInicio)) {
      diasCalendario = fechaFin.difference(fechaInicio).inDays + 1;
      diasComerciales = _days360(
        fechaInicio,
        fechaFin.add(const Duration(days: 1)),
      );
      if (diasComerciales <= 0) diasComerciales = diasCalendario;
      fuente = 'Calculado con fechas de inicio y fin reportadas en SECOP';
    } else {
      final parsed = _parseDuracion(c);
      if (parsed != null && parsed > 0) {
        diasComerciales = parsed;
        fuente = 'Calculado con la duración reportada en SECOP';
      }
    }

    final pagos = <String, double>{};
    void addPago(String label, String key) {
      final v = _money(c[key]);
      if (v > 0) pagos[label] = v;
    }

    addPago('Valor pagado', 'valor_pagado');
    addPago('Valor facturado', 'valor_facturado');
    addPago('Pendiente de pago', 'valor_pendiente_de_pago');
    addPago('Pendiente de ejecución', 'valor_pendiente_de_ejecucion');
    addPago('Pendiente de amortización', 'valor_pendiente_de_amortizacion');
    addPago('Amortizado', 'valor_amortizado');
    addPago('Pago adelantado', 'valor_de_pago_adelantado');
    addPago('Valor total de adiciones', 'valor_total_de_adiciones');

    final fuentes = <String, double>{};
    void addFuente(String label, String key) {
      final v = _money(c[key]);
      if (v > 0) fuentes[label] = v;
    }

    addFuente(
      'Presupuesto General de la Nación (PGN)',
      'presupuesto_general_de_la_nacion_pgn',
    );
    addFuente(
      'Sistema General de Participaciones (SGP)',
      'sistema_general_de_participaciones',
    );
    addFuente(
      'Sistema General de Regalías (SGR)',
      'sistema_general_de_regal_as',
    );
    addFuente(
      'Sistema General de Regalías (SGR)',
      'sistema_general_de_regalias',
    );
    addFuente(
      'Recursos propios (alcaldías, gobernaciones, resguardos)',
      'recursos_propios_alcald_as_gobernaciones_y_resguardos_ind_genas',
    );
    addFuente(
      'Recursos propios (alcaldías, gobernaciones, resguardos)',
      'recursos_propios_alcaldias_gobernaciones_y_resguardos_indigenas',
    );
    addFuente('Recursos de crédito', 'recursos_de_credito');
    addFuente('Recursos propios', 'recursos_propios');

    return ContractFinancialAnalysis._(
      valorTotal: valorTotal,
      fechaFirma: fechaFirma,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      diasCalendario: diasCalendario,
      diasComerciales: diasComerciales,
      diasAdicionados: diasAdicionados,
      fuentePlazo: fuente,
      duracionReportada: duracionReportada,
      pagos: pagos,
      fuentesRecursos: fuentes,
    );
  }

  /// Método 30/360 europeo (días comerciales) entre [start] y [endExclusive].
  static int _days360(DateTime start, DateTime endExclusive) {
    final d1 = start.day > 30 ? 30 : start.day;
    final d2 = endExclusive.day > 30 ? 30 : endExclusive.day;
    return (endExclusive.year - start.year) * 360 +
        (endExclusive.month - start.month) * 30 +
        (d2 - d1);
  }

  /// Interpreta "120 Dia(s)", "4 Mes(es)", "1 Año(s)", "2 Semana(s)" o el
  /// par SECOP I `plazo_de_ejec_del_contrato` + `rango_de_ejec_del_contrato`.
  static int? _parseDuracion(Map<String, dynamic> c) {
    final raw = (c['duraci_n_del_contrato'] ?? c['duracion_del_contrato'] ?? '')
        .toString()
        .trim();
    if (raw.isNotEmpty) {
      final m = RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*([A-Za-zÁÉÍÓÚáéíóúñÑ]*)')
          .firstMatch(raw);
      if (m != null) {
        final n = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
        final unidad = (m.group(2) ?? '').toLowerCase();
        final dias = _toDias(n, unidad);
        if (dias != null) return dias;
      }
    }

    final plazo = double.tryParse(
      (c['plazo_de_ejec_del_contrato'] ?? '').toString().replaceAll(',', '.'),
    );
    if (plazo != null && plazo > 0) {
      final rango = (c['rango_de_ejec_del_contrato'] ?? 'D')
          .toString()
          .toLowerCase();
      return _toDias(plazo, rango);
    }
    return null;
  }

  static int? _toDias(double n, String unidad) {
    if (n <= 0) return null;
    if (unidad.startsWith('m')) return (n * 30).round();
    if (unidad.startsWith('a')) return (n * 360).round();
    if (unidad.startsWith('s')) return (n * 7).round();
    if (unidad.startsWith('h')) return 1;
    return n.round();
  }

  // ---------------------------------------------------------------------------
  // Parsers tolerantes
  // ---------------------------------------------------------------------------

  static double _money(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    final s = raw.toString().trim();
    if (s.isEmpty) return 0;
    final direct = double.tryParse(s);
    if (direct != null) return direct;
    final cleaned = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    return double.tryParse(cleaned.replaceAll('.', '').replaceAll(',', '.')) ??
        0;
  }

  static double _firstMoney(Map<String, dynamic> c, List<String> keys) {
    for (final k in keys) {
      final v = _money(c[k]);
      if (v > 0) return v;
    }
    return 0;
  }

  static DateTime? parseDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final d = DateTime.tryParse(s);
    if (d == null) return null;
    // SECOP usa 1900-01-01 como marcador de "sin fecha".
    if (d.year < 2000 || d.year > 2100) return null;
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime? _firstDate(Map<String, dynamic> c, List<String> keys) {
    for (final k in keys) {
      final d = parseDate(c[k]);
      if (d != null) return d;
    }
    return null;
  }

  static int? _firstInt(Map<String, dynamic> c, List<String> keys) {
    for (final k in keys) {
      final v = int.tryParse((c[k] ?? '').toString().split('.').first.trim());
      if (v != null) return v;
    }
    return null;
  }

  static String _firstText(Map<String, dynamic> c, List<String> keys) {
    for (final k in keys) {
      final v = (c[k] ?? '').toString().trim();
      if (v.isNotEmpty) {
        if (k == 'plazo_de_ejec_del_contrato') {
          final r = (c['rango_de_ejec_del_contrato'] ?? '').toString().trim();
          final unidad = r.toUpperCase().startsWith('M') ? 'Mes(es)' : 'Día(s)';
          return '$v $unidad';
        }
        return v;
      }
    }
    return '';
  }
}

/// Catálogo de columnas oficiales SECOP II / SECOP I agrupadas por sección,
/// con etiquetas legibles y formateo seguro de valores.
class ContractFieldCatalog {
  ContractFieldCatalog._();

  static const List<(String, String, List<(String, String)>)> _sections = [
    (
      'identificacion',
      'Identificación, modalidad y clasificación',
      [
        ('id_contrato', 'ID del contrato'),
        ('referencia_del_contrato', 'Referencia del contrato'),
        ('numero_de_contrato', 'Número del contrato'),
        ('proceso_de_compra', 'Proceso de compra'),
        ('numero_de_proceso', 'Número de proceso'),
        ('tipo_de_contrato', 'Tipo de contrato'),
        ('modalidad_de_contratacion', 'Modalidad de contratación'),
        (
          'justificacion_modalidad_de_contratacion',
          'Justificación de la modalidad',
        ),
        ('codigo_de_categoria_principal', 'Categoría principal (UNSPSC)'),
        ('estado_contrato', 'Estado del contrato'),
        ('estado_del_proceso', 'Estado del proceso'),
        ('regimen_de_contratacion', 'Régimen de contratación'),
        ('codigo_bpin', 'Código BPIN'),
        ('anno_bpin', 'Año BPIN'),
        ('estado_bpin', 'Estado BPIN'),
        ('condiciones_de_entrega', 'Condiciones de entrega'),
        ('el_contrato_puede_ser_prorrogado', '¿Puede ser prorrogado?'),
        ('liquidacion', 'Liquidación'),
        ('obligacion_ambiental', 'Obligaciones ambientales'),
        ('obligaciones_ambientales', 'Obligaciones ambientales'),
        ('obligaciones_postconsumo', 'Obligaciones posconsumo'),
        ('reversion', 'Reversión'),
        ('espostconflicto', '¿Es posconflicto?'),
        ('puntos_del_acuerdo', 'Puntos del Acuerdo de Paz'),
        ('pilares_del_acuerdo', 'Pilares del Acuerdo de Paz'),
        ('objeto_del_contrato', 'Objeto del contrato'),
        ('detalle_del_objeto_a_contratar', 'Detalle del objeto'),
      ],
    ),
    (
      'cronograma',
      'Cronograma y vigencia contractual',
      [
        ('fecha_de_firma', 'Fecha de firma'),
        ('fecha_de_firma_del_contrato', 'Fecha de firma'),
        ('fecha_de_inicio_del_contrato', 'Inicio del contrato'),
        ('fecha_de_fin_del_contrato', 'Fin del contrato'),
        ('fecha_de_inicio_de_ejecucion', 'Inicio de ejecución'),
        ('fecha_de_fin_de_ejecucion', 'Fin de ejecución'),
        ('fecha_ini_ejec_contrato', 'Inicio de ejecución'),
        ('fecha_fin_ejec_contrato', 'Fin de ejecución'),
        ('duraci_n_del_contrato', 'Duración reportada'),
        ('plazo_de_ejec_del_contrato', 'Plazo de ejecución'),
        ('rango_de_ejec_del_contrato', 'Unidad del plazo'),
        ('dias_adicionados', 'Días adicionados'),
        ('tiempo_adiciones_en_dias', 'Días adicionados'),
        ('fecha_inicio_liquidacion', 'Inicio de liquidación'),
        ('fecha_fin_liquidacion', 'Fin de liquidación'),
        ('ultima_actualizacion', 'Última actualización en SECOP'),
        ('fecha_de_notificaci_n_de_prorrogaci_n', 'Notificación de prórroga'),
      ],
    ),
    (
      'entidad',
      'Entidad estatal contratante',
      [
        ('nombre_entidad', 'Entidad'),
        ('nit_entidad', 'NIT de la entidad'),
        ('nit_de_la_entidad', 'NIT de la entidad'),
        ('codigo_entidad', 'Código de la entidad'),
        ('c_digo_de_la_entidad', 'Código de la entidad'),
        ('orden', 'Orden'),
        ('orden_entidad', 'Orden'),
        ('sector', 'Sector'),
        ('rama', 'Rama'),
        ('entidad_centralizada', 'Centralización'),
        ('departamento', 'Departamento'),
        ('ciudad', 'Ciudad'),
        ('departamento_entidad', 'Departamento'),
        ('municipio_entidad', 'Municipio'),
        ('localizaci_n', 'Localización'),
        ('localizacion', 'Localización'),
      ],
    ),
    (
      'contratista',
      'Contratista adjudicado y representación legal',
      [
        ('proveedor_adjudicado', 'Contratista'),
        ('nom_razon_social_contratista', 'Contratista'),
        ('tipodocproveedor', 'Tipo de documento'),
        ('tipo_identifi_del_contratista', 'Tipo de documento'),
        ('documento_proveedor', 'Número de documento'),
        ('identificacion_del_contratista', 'Número de documento'),
        ('codigo_proveedor', 'Código del proveedor en SECOP'),
        ('es_pyme', '¿Es MiPyme?'),
        ('es_grupo', '¿Es consorcio / unión temporal?'),
        ('habilita_pago_adelantado', '¿Habilita pago adelantado?'),
        ('nombre_representante_legal', 'Representante legal'),
        ('nombre_del_represen_legal', 'Representante legal'),
        (
          'tipo_de_identificaci_n_representante_legal',
          'Tipo doc. representante',
        ),
        (
          'tipo_de_identificacion_representante_legal',
          'Tipo doc. representante',
        ),
        (
          'identificaci_n_representante_legal',
          'Documento del representante',
        ),
        (
          'identificacion_representante_legal',
          'Documento del representante',
        ),
        ('identific_representante_legal', 'Documento del representante'),
        ('nacionalidad_representante_legal', 'Nacionalidad del representante'),
        ('domicilio_representante_legal', 'Domicilio del representante'),
        ('g_nero_representante_legal', 'Género del representante'),
        ('genero_representante_legal', 'Género del representante'),
        ('nombre_del_banco', 'Banco'),
        ('tipo_de_cuenta', 'Tipo de cuenta'),
      ],
    ),
    (
      'supervision',
      'Supervisión, ordenadores del gasto y del pago',
      [
        ('nombre_supervisor', 'Supervisor'),
        ('tipo_de_documento_supervisor', 'Tipo doc. supervisor'),
        ('n_mero_de_documento_supervisor', 'Documento del supervisor'),
        ('numero_de_documento_supervisor', 'Documento del supervisor'),
        ('nombre_ordenador_del_gasto', 'Ordenador del gasto'),
        (
          'tipo_de_documento_ordenador_del_gasto',
          'Tipo doc. ordenador del gasto',
        ),
        (
          'n_mero_de_documento_ordenador_del_gasto',
          'Documento ordenador del gasto',
        ),
        (
          'numero_de_documento_ordenador_del_gasto',
          'Documento ordenador del gasto',
        ),
        ('nombre_ordenador_de_pago', 'Ordenador del pago'),
        (
          'tipo_de_documento_ordenador_de_pago',
          'Tipo doc. ordenador del pago',
        ),
        (
          'n_mero_de_documento_ordenador_de_pago',
          'Documento ordenador del pago',
        ),
        (
          'numero_de_documento_ordenador_de_pago',
          'Documento ordenador del pago',
        ),
        ('nombre_del_interventor', 'Interventor'),
      ],
    ),
    (
      'presupuesto',
      'Valores, pagos y recursos presupuestales',
      [
        ('valor_del_contrato', 'Valor del contrato'),
        ('cuantia_contrato', 'Cuantía del contrato'),
        ('valor_contrato_con_adiciones', 'Valor con adiciones'),
        ('valor_total_de_adiciones', 'Valor total de adiciones'),
        ('valor_de_pago_adelantado', 'Pago adelantado'),
        ('valor_facturado', 'Valor facturado'),
        ('valor_pagado', 'Valor pagado'),
        ('valor_pendiente_de_pago', 'Pendiente de pago'),
        ('valor_pendiente_de_ejecucion', 'Pendiente de ejecución'),
        ('valor_amortizado', 'Valor amortizado'),
        ('valor_pendiente_de_amortizacion', 'Pendiente de amortización'),
        ('saldo_cdp', 'Saldo CDP'),
        ('saldo_vigencia', 'Saldo de vigencia'),
        ('origen_de_los_recursos', 'Origen de los recursos'),
        ('destino_gasto', 'Destino del gasto'),
        ('presupuesto_general_de_la_nacion_pgn', 'Presupuesto General (PGN)'),
        ('sistema_general_de_participaciones', 'Sist. General Participaciones'),
        ('sistema_general_de_regal_as', 'Sist. General de Regalías'),
        ('sistema_general_de_regalias', 'Sist. General de Regalías'),
        (
          'recursos_propios_alcald_as_gobernaciones_y_resguardos_ind_genas',
          'Recursos propios territoriales',
        ),
        (
          'recursos_propios_alcaldias_gobernaciones_y_resguardos_indigenas',
          'Recursos propios territoriales',
        ),
        ('recursos_de_credito', 'Recursos de crédito'),
        ('recursos_propios', 'Recursos propios'),
      ],
    ),
  ];

  /// Claves que ya se muestran en el encabezado y no deben repetirse.
  static const Set<String> _excludedKeys = {
    'descripcion_del_proceso',
    'urlproceso',
    'ruta_proceso_en_secop_i',
  };

  static const Set<String> _moneyHints = {
    'valor',
    'cuantia',
    'saldo',
    'presupuesto_general',
    'sistema_general',
    'recursos_',
  };

  static bool _isMoneyKey(String key) {
    if (key.startsWith('valor_') || key == 'cuantia_contrato') return true;
    return _moneyHints.any((h) => key.startsWith(h));
  }

  /// Convierte cualquier valor crudo de Socrata en texto legible.
  static String formatValue(String key, dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      if (raw['url'] != null) return raw['url'].toString();
      if (raw['latitude'] != null && raw['longitude'] != null) {
        return '${raw['latitude']}, ${raw['longitude']}';
      }
      if (raw['coordinates'] is List) {
        return (raw['coordinates'] as List).join(', ');
      }
      return jsonEncode(raw);
    }
    if (raw is List) return raw.map((e) => e.toString()).join(', ');

    final s = raw.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return '';
    final lower = s.toLowerCase();
    if (lower == 'no definido' ||
        lower == 'no definida' ||
        lower == 'null' ||
        lower == 'n/a') {
      return '';
    }

    if (key.startsWith('fecha') || key == 'ultima_actualizacion') {
      final d = DateTime.tryParse(s);
      if (d != null) {
        if (d.year < 2000) return '';
        return DateFormat('dd/MM/yyyy').format(d);
      }
    }

    if (_isMoneyKey(key)) {
      final v = double.tryParse(s);
      if (v != null) {
        // Las fuentes presupuestales en cero solo agregan ruido visual.
        if (v == 0) return key.startsWith('valor_') ? '\$ 0' : '';
        return ContractFinancialAnalysis.formatCop(v);
      }
    }

    if (lower == 'true') return 'Sí';
    if (lower == 'false') return 'No';
    return s;
  }

  /// Convierte `fecha_de_inicio_del_contrato` → "Fecha de inicio del contrato".
  static String humanizeKey(String key) {
    final words = key
        .replaceAll(RegExp(r'_+'), ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return key;
    final text = words.join(' ');
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Agrupa **todas** las columnas no vacías del contrato en secciones.
  /// Las columnas no catalogadas se agregan en "Atributos adicionales".
  static List<ContractFieldSection> buildSections(dynamic rawContract) {
    if (rawContract is! Map) return const [];
    final c = rawContract.map((k, v) => MapEntry(k.toString(), v));
    final used = <String>{..._excludedKeys};
    final result = <ContractFieldSection>[];

    for (final (id, title, fields) in _sections) {
      final entries = <ContractFieldEntry>[];
      final labelsVistos = <String, String>{};
      for (final (key, label) in fields) {
        if (!c.containsKey(key)) continue;
        used.add(key);
        final value = formatValue(key, c[key]);
        if (value.isEmpty) continue;
        // Evita duplicar la misma etiqueta con el mismo valor (alias SECOP I/II).
        if (labelsVistos[label] == value) continue;
        labelsVistos[label] = value;
        entries.add(ContractFieldEntry(key: key, label: label, value: value));
      }
      if (entries.isNotEmpty) {
        result.add(ContractFieldSection(id: id, title: title, entries: entries));
      }
    }

    final extras = <ContractFieldEntry>[];
    final keys = c.keys.toList()..sort();
    for (final key in keys) {
      if (used.contains(key) || key.startsWith(':') || key.startsWith('_')) {
        continue;
      }
      final value = formatValue(key, c[key]);
      if (value.isEmpty) continue;
      extras.add(
        ContractFieldEntry(key: key, label: humanizeKey(key), value: value),
      );
    }
    if (extras.isNotEmpty) {
      result.add(
        ContractFieldSection(
          id: 'adicionales',
          title: 'Atributos adicionales del expediente',
          entries: extras,
        ),
      );
    }
    return result;
  }
}
