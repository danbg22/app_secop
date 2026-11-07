import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Plan Anual de Adquisiciones (PAA) publicado en SECOP II, para que una
/// empresa vea qué piensa contratar cada entidad durante el año.
///
/// Fuentes de Datos Abiertos:
/// - Encabezado (b6m4-qgqv): una fila por plan, con su última versión y el
///   presupuesto general que declara la entidad.
/// - Detalle (9sue-ezhx): las compras del plan. Guarda varias cargas del
///   mismo ítem, así que se toma cada `id` una sola vez (la carga más
///   reciente). Con esa regla, la suma coincide con el presupuesto general del
///   encabezado (Regional Cesar 2026: $ 95.149.208.253,2 en los dos).
class PlanPaa {
  const PlanPaa({
    required this.encabezadoId,
    required this.codigoEntidad,
    required this.nombreEntidad,
    required this.anio,
    required this.version,
    required this.presupuestoGeneralCop,
    required this.menorCuantiaCop,
    required this.minimaCuantiaCop,
    required this.actualizadoIso,
    required this.municipio,
  });

  final String encabezadoId;
  final String codigoEntidad;
  final String nombreEntidad;
  final int anio;
  final int version;
  final double presupuestoGeneralCop;

  /// Topes de menor y mínima cuantía de la entidad para el año.
  final double menorCuantiaCop;
  final double minimaCuantiaCop;
  final String actualizadoIso;
  final String municipio;

  factory PlanPaa.fromMap(Map<String, dynamic> m) => PlanPaa(
    encabezadoId: '${m['identificador_unico'] ?? ''}',
    codigoEntidad: '${m['codigo_entidad'] ?? ''}',
    nombreEntidad: '${m['nombre_entidad'] ?? ''}'.trim(),
    anio: int.tryParse('${m['anno'] ?? ''}') ?? 0,
    version: int.tryParse('${m['version'] ?? ''}') ?? 0,
    presupuestoGeneralCop: PaaService._num(m['valor_presupuesto_general']),
    menorCuantiaCop: PaaService._num(m['presupuesto_menor_cuantia']),
    minimaCuantiaCop: PaaService._num(m['presupuesto_minima_cuantia']),
    actualizadoIso: '${m['fecha_de_ultima_modificacion'] ?? ''}',
    municipio: '${m['municipio_paa'] ?? ''}',
  );
}

class ItemPaa {
  const ItemPaa({
    required this.id,
    required this.descripcion,
    required this.mes,
    required this.duracion,
    required this.valorCop,
    required this.modalidad,
    required this.codigosUnspsc,
    required this.origenRecursos,
    required this.procesoRelacionado,
    required this.urlProceso,
    required this.contactoNombre,
    required this.contactoCorreo,
  });

  final String id;
  final String descripcion;

  /// Mes esperado de inicio (1–12) o 0 si la entidad no lo definió.
  final int mes;

  /// "8 meses", "30 días"…, o vacío.
  final String duracion;
  final double valorCop;
  final String modalidad;
  final List<String> codigosUnspsc;
  final String origenRecursos;

  /// Referencia del proceso en SECOP II si ya se publicó.
  final String procesoRelacionado;
  final String urlProceso;
  final String contactoNombre;
  final String contactoCorreo;

  bool get yaTieneProceso => procesoRelacionado.isNotEmpty;

  /// Modalidades en las que una empresa presenta oferta y compite. La
  /// contratación directa sin ofertas (casi siempre prestación de servicios
  /// de personas) no lo es.
  bool get esCompetitiva {
    final m = modalidad.toUpperCase();
    return m.contains('LICITACION') ||
        m.contains('SELECCION ABREVIADA') ||
        m.contains('CONCURSO DE MERITOS') ||
        m.contains('MINIMA CUANTIA') ||
        m.contains('CON OFERTAS') ||
        m.contains('SOLICITUD DE INFORMACION');
  }

  static const _meses = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPTIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE',
  ];

  static int mesDe(String t) {
    final m = t.trim().toUpperCase().replaceAll('SETIEMBRE', 'SEPTIEMBRE');
    return _meses.indexOf(m) + 1;
  }

  static String _duracion(String n, String unidad) {
    final v = int.tryParse(n.trim()) ?? 0;
    if (v <= 0) return '';
    final u = unidad.toLowerCase();
    final (uno, varios) = u.startsWith('mes')
        ? ('mes', 'meses')
        : u.startsWith('a')
        ? ('año', 'años')
        : u.startsWith('d')
        ? ('día', 'días')
        : ('', '');
    if (uno.isEmpty) return '';
    return '$v ${v == 1 ? uno : varios}';
  }

  factory ItemPaa.fromMap(Map<String, dynamic> m) {
    final proceso = '${m['procesos_relacionados'] ?? ''}'.trim();
    final url = m['url_proceso'];
    final modalidad = '${m['modalidad'] ?? ''}'.trim();
    return ItemPaa(
      id: '${m['id'] ?? ''}',
      // Las entidades anteponen su código interno ("20_9521_451 COMPRA…").
      descripcion: '${m['descripcion'] ?? ''}'.trim().replaceFirst(
        RegExp(r'^[0-9_\-]+\s+'),
        '',
      ),
      mes: mesDe('${m['fecha_esperada_de_inicio'] ?? ''}'),
      duracion: _duracion(
        '${m['duracion_esperada'] ?? ''}',
        '${m['unidad_de_duracion_esperada'] ?? ''}',
      ),
      valorCop: PaaService._num(m['valor_total_esperado']),
      modalidad: modalidad.toUpperCase() == 'NO DEFINIDO' ? '' : modalidad,
      codigosUnspsc: '${m['categorias_unspsc'] ?? ''}'
          .split(RegExp(r'[;,\s]+'))
          .where((c) => RegExp(r'^\d{8}$').hasMatch(c))
          .toList(),
      origenRecursos:
          '${m['origen_recursos'] ?? ''}'.trim().toUpperCase() == 'NO DEFINIDO'
          ? ''
          : '${m['origen_recursos'] ?? ''}'.trim(),
      procesoRelacionado: proceso.toUpperCase() == 'NO DEFINIDO' ? '' : proceso,
      urlProceso: proceso.toUpperCase() == 'NO DEFINIDO'
          ? ''
          : (url is Map ? '${url['url'] ?? ''}' : '${url ?? ''}'),
      contactoNombre: '${m['nombre_del_contacto'] ?? ''}'.trim(),
      contactoCorreo: '${m['correo_del_contacto'] ?? ''}'.trim(),
    );
  }
}

/// Contrato ya firmado por la entidad con los mismos códigos UNSPSC: sirve de
/// referencia de la experiencia y los valores que maneja.
class ContratoReferencia {
  const ContratoReferencia({
    required this.objeto,
    required this.valorCop,
    required this.fechaIso,
    required this.proveedor,
    required this.modalidad,
    required this.url,
  });

  final String objeto;
  final double valorCop;
  final String fechaIso;
  final String proveedor;
  final String modalidad;
  final String url;
}

class PaaService {
  PaaService._();

  static const String _encabezados =
      'https://www.datos.gov.co/resource/b6m4-qgqv.json';
  static const String _detalle =
      'https://www.datos.gov.co/resource/9sue-ezhx.json';
  static const String _contratos =
      'https://www.datos.gov.co/resource/jbjy-vk9h.json';
  static const int _maxFilas = 30000;

  static double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;
  static String _sql(String v) => v.replaceAll("'", "''");

  static Future<List<dynamic>> _get(String base, String query) async {
    final uri = Uri.parse(base).replace(queryParameters: {r'$query': query});
    for (var intento = 1; ; intento++) {
      try {
        final r = await http.get(uri).timeout(const Duration(seconds: 45));
        if (r.statusCode == 200) {
          return jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
        }
        if (r.statusCode < 500 && r.statusCode != 429) {
          throw PaaException(
            'Datos Abiertos respondió con error ${r.statusCode}.',
          );
        }
      } on PaaException {
        rethrow;
      } catch (_) {
        if (intento >= 3) {
          throw const PaaException(
            'No fue posible consultar Datos Abiertos. Revisa tu conexión.',
          );
        }
      }
      if (intento >= 3) {
        throw const PaaException(
          'Datos Abiertos no respondió. Intenta de nuevo en un momento.',
        );
      }
      await Future<void>.delayed(Duration(milliseconds: 700 * intento));
    }
  }

  /// Planes publicados del año cuyo nombre de entidad contiene [texto].
  static Future<List<PlanPaa>> buscarPlanes(String texto, int anio) async {
    final t = _sql(texto.trim().toUpperCase());
    if (t.length < 3) return const [];
    final filas = await _get(
      _encabezados,
      'SELECT identificador_unico, codigo_entidad, nombre_entidad, anno, '
      'version, valor_presupuesto_general, presupuesto_menor_cuantia, '
      'presupuesto_minima_cuantia, fecha_de_ultima_modificacion, municipio_paa '
      "WHERE anno=$anio AND upper(nombre_entidad) like '%$t%' "
      'ORDER BY valor_presupuesto_general DESC LIMIT 200',
    );
    // Una entidad, un plan: el de versión más alta.
    final porEntidad = <String, PlanPaa>{};
    for (final f in filas.cast<Map<String, dynamic>>()) {
      final p = PlanPaa.fromMap(f);
      final previo = porEntidad[p.codigoEntidad];
      if (previo == null || p.version > previo.version) {
        porEntidad[p.codigoEntidad] = p;
      }
    }
    return porEntidad.values.toList()..sort(
      (a, b) => b.presupuestoGeneralCop.compareTo(a.presupuestoGeneralCop),
    );
  }

  /// Compras del plan, cada una una sola vez y en su carga más reciente.
  static Future<List<ItemPaa>> items(PlanPaa plan) async {
    final filas = await _get(
      _detalle,
      'SELECT id, descripcion, fecha_esperada_de_inicio, duracion_esperada, '
      'unidad_de_duracion_esperada, valor_total_esperado, modalidad, '
      'categorias_unspsc, origen_recursos, procesos_relacionados, url_proceso, '
      'nombre_del_contacto, correo_del_contacto '
      "WHERE id_paa_encabezado='${_sql(plan.encabezadoId)}' "
      'ORDER BY fecha_version DESC LIMIT $_maxFilas',
    );
    final vistos = <String>{};
    return [
      for (final f in filas.cast<Map<String, dynamic>>())
        if (vistos.add('${f['id']}')) ItemPaa.fromMap(f),
    ];
  }

  /// Contratos recientes de la misma entidad con el código UNSPSC (a nivel
  /// de clase, 6 dígitos) del ítem.
  static Future<List<ContratoReferencia>> contratosParecidos({
    required String nombreEntidad,
    required String codigoUnspsc,
  }) async {
    final clase = codigoUnspsc.length >= 6
        ? codigoUnspsc.substring(0, 6)
        : codigoUnspsc;
    final filas = await _get(
      _contratos,
      'SELECT objeto_del_contrato, valor_del_contrato, fecha_de_firma, '
      'proveedor_adjudicado, modalidad_de_contratacion, urlproceso '
      "WHERE nombre_entidad='${_sql(nombreEntidad)}' "
      "AND codigo_de_categoria_principal like 'V1.${_sql(clase)}%' "
      'AND fecha_de_firma IS NOT NULL '
      'ORDER BY fecha_de_firma DESC LIMIT 5',
    );
    return [
      for (final f in filas.cast<Map<String, dynamic>>())
        ContratoReferencia(
          objeto: '${f['objeto_del_contrato'] ?? ''}'.trim(),
          valorCop: _num(f['valor_del_contrato']),
          fechaIso: '${f['fecha_de_firma'] ?? ''}',
          proveedor: '${f['proveedor_adjudicado'] ?? ''}'.trim(),
          modalidad: '${f['modalidad_de_contratacion'] ?? ''}'.trim(),
          url: f['urlproceso'] is Map ? '${f['urlproceso']['url'] ?? ''}' : '',
        ),
    ];
  }
}

class PaaException implements Exception {
  const PaaException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Segmentos UNSPSC (dos primeros dígitos) para agrupar por sector.
const Map<String, String> segmentosUnspsc = {
  '10': 'Material vivo vegetal y animal',
  '11': 'Minerales, textiles y materiales no comestibles',
  '12': 'Químicos y gases',
  '13': 'Resinas, cauchos y elastómeros',
  '14': 'Papel y productos de papel',
  '15': 'Combustibles y lubricantes',
  '20': 'Maquinaria de minería y perforación',
  '21': 'Maquinaria agrícola, pesquera y forestal',
  '22': 'Maquinaria para construcción',
  '23': 'Maquinaria industrial y de manufactura',
  '24': 'Manejo de materiales, embalaje y almacenaje',
  '25': 'Vehículos y sus accesorios',
  '26': 'Maquinaria y equipos de energía',
  '27': 'Herramientas y maquinaria general',
  '30': 'Materiales y estructuras de construcción',
  '31': 'Componentes y suministros de manufactura',
  '32': 'Componentes electrónicos',
  '39': 'Iluminación y equipos eléctricos',
  '40': 'Equipos de climatización, fluidos y tuberías',
  '41': 'Equipos de laboratorio, medición y prueba',
  '42': 'Equipos y suministros médicos',
  '43': 'Tecnología de la información y telecomunicaciones',
  '44': 'Equipos y suministros de oficina',
  '45': 'Impresión, fotografía y audiovisuales',
  '46': 'Seguridad, vigilancia y defensa (equipos)',
  '47': 'Equipos y suministros de limpieza',
  '48': 'Equipos de servicio, cocina y recreación',
  '49': 'Deportes y recreación',
  '50': 'Alimentos y bebidas',
  '51': 'Medicamentos y productos farmacéuticos',
  '52': 'Electrodomésticos y muebles domésticos',
  '53': 'Ropa, calzado y dotación',
  '54': 'Relojería y joyería',
  '55': 'Publicaciones impresas y electrónicas',
  '56': 'Muebles y mobiliario',
  '60': 'Material educativo, instrumentos musicales y juegos',
  '64': 'Instrumentos financieros',
  '70': 'Servicios agrícolas, pesqueros y forestales',
  '71': 'Servicios de minería, petróleo y gas',
  '72': 'Servicios de construcción, edificación y mantenimiento',
  '73': 'Servicios de producción industrial',
  '76': 'Servicios de limpieza industrial',
  '77': 'Servicios medioambientales',
  '78': 'Transporte, almacenaje y correo',
  '80': 'Servicios de gestión, administración y personal',
  '81': 'Servicios de ingeniería, investigación y tecnología',
  '82': 'Servicios editoriales, de diseño y publicidad',
  '83': 'Servicios públicos (agua, energía, telecomunicaciones)',
  '84': 'Servicios financieros y seguros',
  '85': 'Servicios de salud',
  '86': 'Servicios educativos y de formación',
  '90': 'Viajes, alimentación, alojamiento y eventos',
  '91': 'Servicios personales y domésticos',
  '92': 'Servicios de seguridad y vigilancia',
  '93': 'Servicios políticos y de asuntos cívicos',
  '94': 'Organizaciones y clubes',
  '95': 'Terrenos, edificios y estructuras',
};

String sectorUnspsc(String codigo) =>
    codigo.length >= 2 ? (segmentosUnspsc[codigo.substring(0, 2)] ?? '') : '';
