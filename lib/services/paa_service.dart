import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/texto_profesional.dart';

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
    this.departamento = '',
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
  final String departamento;

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
    departamento: '${m['departamento_paa'] ?? ''}',
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
      descripcion: TextoProfesional.oracion('${m['descripcion'] ?? ''}'),
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

/// Una cuenta compradora con su PAA (p. ej. "SENA REGIONAL CESAR Grupo de
/// Apoyo Administrativo Mixto").
class CuentaPaa {
  const CuentaPaa({required this.plan});

  final PlanPaa plan;
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

  static Future<List<dynamic>> _get(
    String base,
    String query, {
    Duration espera = const Duration(seconds: 45),
  }) async {
    final uri = Uri.parse(base).replace(queryParameters: {r'$query': query});
    for (var intento = 1; ; intento++) {
      try {
        final r = await http.get(uri).timeout(espera);
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

  /// Ejecuta [tareas] de a [n] a la vez. En Datos Abiertos, muchas consultas
  /// por igualdad (indexadas, ~1 s) son mucho más rápidas que una con `in`
  /// (de 20 s a 2 min).
  static Future<List<T>> _deA<T>(
    int n,
    List<Future<T> Function()> tareas,
  ) async {
    final r = List<T?>.filled(tareas.length, null);
    var siguiente = 0;
    Future<void> trabajador() async {
      while (siguiente < tareas.length) {
        final i = siguiente++;
        r[i] = await tareas[i]();
      }
    }

    await Future.wait([for (var k = 0; k < n; k++) trabajador()]);
    return r.cast<T>();
  }

  static const String _procesos =
      'https://www.datos.gov.co/resource/p6dx-8zbt.json';

  /// NIT sin dígito de verificación (algunas cuentas lo registran con él).
  static String nit9(String nit) {
    final d = nit.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length > 9 ? d.substring(0, 9) : d;
  }

  /// Código de cuenta → NIT. Sale del dataset de procesos de SECOP II, que
  /// responde en menos de un segundo; el detalle del PAA tarda minutos.
  static Future<Map<String, String>> _nitsDe(Iterable<String> codigos) async {
    final lista = codigos.toSet().toList();
    final r = <String, String>{};
    for (var i = 0; i < lista.length; i += 100) {
      final lote = lista.sublist(i, (i + 100).clamp(0, lista.length));
      final filas = await _get(
        _procesos,
        'SELECT codigo_entidad, nit_entidad, count(*) AS n '
        "WHERE codigo_entidad in (${lote.map((c) => "'${_sql(c)}'").join(',')}) "
        'GROUP BY codigo_entidad, nit_entidad LIMIT 1000',
      );
      for (final f in filas.cast<Map<String, dynamic>>()) {
        final nit = nit9('${f['nit_entidad'] ?? ''}');
        if (nit.length >= 8) r['${f['codigo_entidad']}'] = nit;
      }
    }
    return r;
  }

  /// Entidades (NIT) con PAA del año cuyo nombre contiene [texto], con las
  /// cuentas encontradas de cada una.
  static Future<Map<String, List<PlanPaa>>> buscarEntidades(
    String texto,
    int anio,
  ) async {
    final planes = await buscarPlanes(texto, anio);
    if (planes.isEmpty) return const {};
    final nits = await _nitsDe(planes.map((p) => p.codigoEntidad));
    final r = <String, List<PlanPaa>>{};
    for (final p in planes) {
      final nit = nits[p.codigoEntidad] ?? '';
      if (nit.length >= 8) r.putIfAbsent(nit, () => []).add(p);
    }
    return r;
  }

  /// Cuentas con PAA del año cuyo nombre contiene alguno de [patrones]
  /// (mayúsculas, sin tildes). Para entidades cuyas seccionales tienen NIT
  /// propio, como las direcciones territoriales de MinTrabajo.
  static Future<List<CuentaPaa>> cuentasPorNombre(
    List<String> patrones,
    int anio,
  ) async {
    String tildes(String p) => p
        .replaceAll('POLICIA', 'POLICÍA')
        .replaceAll('ADMINISTRACION', 'ADMINISTRACIÓN');
    final condiciones = {
      for (final p in patrones) ...[p, tildes(p)],
    }.map((p) => "upper(nombre_entidad) like '%${_sql(p)}%'");
    final filas = await _get(
      _encabezados,
      'SELECT identificador_unico, codigo_entidad, nombre_entidad, anno, '
      'version, valor_presupuesto_general, presupuesto_menor_cuantia, '
      'presupuesto_minima_cuantia, fecha_de_ultima_modificacion, '
      'municipio_paa, departamento_paa '
      'WHERE anno=$anio AND (${condiciones.join(' OR ')}) LIMIT 2000',
    );
    final porCodigo = <String, PlanPaa>{};
    for (final f in filas.cast<Map<String, dynamic>>()) {
      final p = PlanPaa.fromMap(f);
      final previo = porCodigo[p.codigoEntidad];
      if (previo == null || p.version > previo.version) {
        porCodigo[p.codigoEntidad] = p;
      }
    }
    return [for (final p in porCodigo.values) CuentaPaa(plan: p)];
  }

  /// Todas las cuentas de la entidad [nit] con PAA del año: sus cuentas en
  /// SECOP II (por NIT, en el dataset de procesos) y el plan de cada una.
  static Future<List<CuentaPaa>> cuentasDe(String nit, int anio) async {
    final n = nit9(nit);
    final filas = await _get(
      _procesos,
      'SELECT codigo_entidad, count(*) AS n '
      "WHERE starts_with(nit_entidad, '${_sql(n)}') "
      'GROUP BY codigo_entidad LIMIT 2000',
    );
    final codigos = [
      for (final f in filas.cast<Map<String, dynamic>>())
        '${f['codigo_entidad'] ?? ''}',
    ].where((c) => c.isNotEmpty).toList();
    final porCodigo = <String, PlanPaa>{};
    for (var i = 0; i < codigos.length; i += 100) {
      final lote = codigos.sublist(i, (i + 100).clamp(0, codigos.length));
      final r = await _get(
        _encabezados,
        'SELECT identificador_unico, codigo_entidad, nombre_entidad, anno, '
        'version, valor_presupuesto_general, presupuesto_menor_cuantia, '
        'presupuesto_minima_cuantia, fecha_de_ultima_modificacion, '
        'municipio_paa, departamento_paa '
        "WHERE anno=$anio AND codigo_entidad in (${lote.map((c) => "'${_sql(c)}'").join(',')}) "
        'LIMIT 1000',
      );
      for (final f in r.cast<Map<String, dynamic>>()) {
        final p = PlanPaa.fromMap(f);
        final previo = porCodigo[p.codigoEntidad];
        if (previo == null || p.version > previo.version) {
          porCodigo[p.codigoEntidad] = p;
        }
      }
    }
    return [for (final p in porCodigo.values) CuentaPaa(plan: p)];
  }

  /// Compras y valor de cada cuenta, contando cada compra una vez, a medida
  /// que llegan (las cuentas grandes tardan ~30 s). El valor que declara el
  /// encabezado no se usa: en varias cuentas del SENA no coincide con sus
  /// compras (Cundinamarca 2026: declara $ 217.934 M y sus compras suman
  /// $ 152.197 M).
  static Stream<(String, ({int compras, double total}))> totalesDe(
    List<CuentaPaa> cuentas,
  ) {
    final control = StreamController<(String, ({int compras, double total}))>();
    // Las que declaran menos primero: la pantalla se llena rápido.
    final conDetalle = [...cuentas]
      ..sort(
        (a, b) => a.plan.presupuestoGeneralCop.compareTo(
          b.plan.presupuestoGeneralCop,
        ),
      );
    Future<void> uno(CuentaPaa c) async {
      try {
        final f = await _get(
          _detalle,
          'SELECT id, max(valor_total_esperado) AS v '
          "WHERE id_paa_encabezado='${_sql(c.plan.encabezadoId)}' "
          'GROUP BY id |> SELECT count(*) AS compras, sum(v) AS total',
          espera: const Duration(seconds: 120),
        );
        final m = f.isEmpty
            ? const <String, dynamic>{}
            : f.first as Map<String, dynamic>;
        control.add((
          c.plan.encabezadoId,
          (
            compras: int.tryParse('${m['compras'] ?? 0}') ?? 0,
            total: _num(m['total']),
          ),
        ));
      } catch (e) {
        control.addError(e);
      }
    }

    _deA(6, [
      for (final c in conDetalle) () => uno(c),
    ]).whenComplete(control.close);
    return control.stream;
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
