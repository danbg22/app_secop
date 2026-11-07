import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Presupuesto por dependencia con datos públicos de SECOP II.
///
/// SECOP II registra en cada proceso la "unidad de contratación" que lo
/// adelanta (p. ej. "Despacho Regional" del SENA Regional Cesar). Con ella:
/// - Asignado: presupuesto oficial (precio base) de los procesos de la
///   dependencia, sin cancelados ni borradores (dataset p6dx-8zbt).
/// - Contratado y ejecutado: valor y pagos de los contratos que nacieron de
///   esos procesos (dataset jbjy-vk9h, enlazado por el portafolio).
class DependenciaPresupuesto {
  const DependenciaPresupuesto({
    required this.clave,
    required this.nombre,
    required this.cuentaSecop,
    required this.variantes,
    required this.procesos,
    required this.asignadoCop,
    this.departamento = '',
    this.partes = const [],
  });

  /// Une varias unidades de SECOP II que son la misma dependencia (p. ej.
  /// un centro del SENA que contrata desde dos cuentas).
  factory DependenciaPresupuesto.agrupada({
    required String clave,
    required String nombre,
    required List<DependenciaPresupuesto> partes,
  }) => DependenciaPresupuesto(
    clave: clave,
    nombre: nombre,
    cuentaSecop: partes.map((p) => p.cuentaSecop).toSet().length == 1
        ? partes.first.cuentaSecop
        : '',
    variantes: [for (final p in partes) ...p.variantes],
    procesos: partes.fold(0, (s, p) => s + p.procesos),
    asignadoCop: partes.fold(0.0, (s, p) => s + p.asignadoCop),
    partes: partes,
  );

  /// Cuenta de SECOP II + nombre normalizado.
  final String clave;
  final String nombre;

  /// Cuenta compradora en SECOP II (`entidad`), p. ej. "SENA REGIONAL CESAR…".
  final String cuentaSecop;

  /// Nombres tal como se escribieron en SECOP II ("…DESPACHO REGIONAL ok").
  final List<String> variantes;
  final int procesos;
  final double asignadoCop;

  /// `departamento_entidad` de la cuenta en SECOP II.
  final String departamento;

  /// Unidades que forman una dependencia agrupada.
  final List<DependenciaPresupuesto> partes;
}

class EjecucionDependencia {
  const EjecucionDependencia({
    required this.contratos,
    required this.contratadoCop,
    required this.pagadoCop,
    required this.facturadoCop,
    required this.pendienteCop,
    required this.procesosConsultados,
    required this.procesosTotales,
  });

  final int contratos;
  final double contratadoCop;
  final double pagadoCop;
  final double facturadoCop;
  final double pendienteCop;

  /// Si la dependencia tiene muchísimos procesos se consulta una muestra.
  final int procesosConsultados;
  final int procesosTotales;

  bool get completa => procesosConsultados >= procesosTotales;
}

class PresupuestoDependenciasService {
  PresupuestoDependenciasService._();

  static const String _procesos =
      'https://www.datos.gov.co/resource/p6dx-8zbt.json';
  static const String _contratos =
      'https://www.datos.gov.co/resource/jbjy-vk9h.json';
  static const int _maxProcesosDetalle = 4000;
  static const int _lote = 80;

  static String _sinTildes(String t) => t
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll('Ñ', 'N')
      .replaceAll('À', 'A')
      .replaceAll('È', 'E')
      .replaceAll('Ì', 'I')
      .replaceAll('Ò', 'O')
      .replaceAll('Ù', 'U');

  /// Limpia lo que cada entidad escribe distinto para la misma dependencia:
  /// "UNIDAD DE CONTRATACIÓN DESPACHO REGIONAL ok", "…CBC..", "…CAE***".
  static String normalizarUnidad(String raw) {
    var t = _sinTildes(raw).replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceFirst(RegExp(r'^UNIDAD(ES)? DE CONTRATACION( DEL?)?\b'), '');
    t = t.replaceFirst(RegExp(r'\bOK$'), '');
    t = t.trim();
    return t.isEmpty ? 'SIN UNIDAD REGISTRADA' : t;
  }

  /// Nombre para mostrar: mayúscula inicial salvo siglas cortas (CBC, CAE).
  /// Nombre limpio y legible de una unidad tal como viene de SECOP II.
  static String nombreParaMostrar(String raw) =>
      nombreVisible(_limpiarConTildes(raw));

  /// Como [normalizarUnidad] pero conservando las tildes, para mostrar.
  static String _limpiarConTildes(String raw) {
    var t = raw
        .toUpperCase()
        .replaceAll('À', 'Á')
        .replaceAll('È', 'É')
        .replaceAll('Ì', 'Í')
        .replaceAll('Ò', 'Ó')
        .replaceAll('Ù', 'Ú')
        .replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÜÑ0-9 ]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceFirst(
      RegExp(r'^UNIDAD(ES)? DE CONTRATACI[OÓ]N( DEL?)?(?=\s|$)'),
      '',
    );
    t = t.replaceFirst(RegExp(r'(^|\s)OK$'), '').trim();
    return t.isEmpty ? 'SIN UNIDAD REGISTRADA' : t;
  }

  static const Set<String> _conectores = {
    'DE',
    'DEL',
    'LA',
    'LAS',
    'LOS',
    'Y',
    'EL',
    'EN',
    'E',
    'A',
    'PARA',
    'POR',
  };

  /// Palabras cortas comunes que no son siglas.
  static const Set<String> _palabrasCortas = {
    'SEDE',
    'AREA',
    'AREAS',
    'GRUPO',
    'OBRAS',
    'PLAN',
    'SALUD',
    'CASA',
    'FONDO',
    'RED',
    'MIXTO',
    'APOYO',
    'CENTRO',
    'ZONA',
    'OTROS',
    'TODAS',
    'NORTE',
    'SUR',
    'ORIENTE',
    'BIENES',
    'COMPRAS',
    'LEGAL',
    'GENERAL',
  };

  /// Nombre para mostrar: siglas en mayúscula (CBC, CIGEC) y el resto con
  /// mayúscula inicial.
  static String nombreVisible(String normalizado) => normalizado
      .split(' ')
      .indexed
      .map((e) {
        final (i, p) = e;
        if (p.isEmpty) return p;
        final sinTildes = _sinTildes(p);
        if (i > 0 && _conectores.contains(sinTildes)) return p.toLowerCase();
        final esSigla =
            p.length <= 5 &&
            !_palabrasCortas.contains(sinTildes) &&
            !_conectores.contains(sinTildes) &&
            !RegExp(r'^\d+$').hasMatch(p);
        if (esSigla) return p;
        return p[0] + p.substring(1).toLowerCase();
      })
      .join(' ');

  static String _sql(String v) => v.replaceAll("'", "''");

  static String _filtroBase({
    required String nit,
    int? anio,
    String? departamento,
    String? cuentaSecop,
  }) => [
    // Con o sin dígito de verificación, según cómo lo registró la entidad.
    nit.length > 9
        ? "starts_with(nit_entidad, '${_sql(nit.substring(0, 9))}')"
        : "starts_with(nit_entidad, '${_sql(nit)}')",
    "estado_del_procedimiento not in ('Cancelado','Borrador')",
    if (anio != null) 'date_extract_y(fecha_de_ultima_publicaci)=$anio',
    if (departamento != null && departamento.isNotEmpty)
      "departamento_entidad='${_sql(departamento)}'",
    if (cuentaSecop != null && cuentaSecop.isNotEmpty)
      "entidad='${_sql(cuentaSecop)}'",
  ].join(' AND ');

  /// GET con dos reintentos: Datos Abiertos a veces corta la conexión o
  /// responde 5xx/429 cuando recibe varias consultas seguidas.
  static Future<List<dynamic>> _get(String base, String query) async {
    final uri = Uri.parse(base).replace(queryParameters: {r'$query': query});
    const intentos = 3;
    for (var intento = 1; ; intento++) {
      String motivo;
      try {
        final r = await http.get(uri).timeout(const Duration(seconds: 40));
        if (r.statusCode == 200) {
          return jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
        }
        motivo = 'Datos Abiertos respondió con error ${r.statusCode}.';
        if (r.statusCode < 500 && r.statusCode != 429) {
          throw PresupuestoDependenciasException(motivo);
        }
      } on PresupuestoDependenciasException {
        rethrow;
      } on TimeoutException {
        motivo =
            'Datos Abiertos tardó demasiado en responder. Intenta de nuevo.';
      } catch (_) {
        motivo =
            'No fue posible conectar con Datos Abiertos. Revisa tu conexión.';
      }
      if (intento >= intentos) throw PresupuestoDependenciasException(motivo);
      await Future<void>.delayed(Duration(milliseconds: 700 * intento));
    }
  }

  static double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

  /// Dependencias de la entidad con su presupuesto asignado, de mayor a menor.
  static Future<List<DependenciaPresupuesto>> dependencias({
    required String nit,
    int? anio,
    String? departamento,
    String? cuentaSecop,
  }) async {
    final filas = await _get(
      _procesos,
      // Datos Abiertos repite un proceso en varias filas (una convocatoria
      // del SENA aparece 1.617 veces): primero se toma cada proceso una vez
      // con su precio y después se suma por unidad.
      'SELECT entidad, departamento_entidad, nombre_de_la_unidad_de, '
      'id_del_proceso, max(precio_base) AS pb '
      'WHERE ${_filtroBase(nit: nit, anio: anio, departamento: departamento, cuentaSecop: cuentaSecop)} '
      'GROUP BY entidad, departamento_entidad, nombre_de_la_unidad_de, id_del_proceso '
      '|> SELECT entidad, departamento_entidad, nombre_de_la_unidad_de, '
      'count(*) AS n, sum(pb) AS asignado '
      'GROUP BY entidad, departamento_entidad, nombre_de_la_unidad_de LIMIT 10000',
    );
    final grupos =
        <
          String,
          ({
            String cuenta,
            String departamento,
            String norm,
            Set<String> variantes,
            int n,
            double asignado,
          })
        >{};
    for (final f in filas.cast<Map<String, dynamic>>()) {
      final cuenta = '${f['entidad'] ?? ''}'.trim();
      final raw = '${f['nombre_de_la_unidad_de'] ?? ''}';
      final norm = normalizarUnidad(raw);
      final clave = '$cuenta|$norm';
      final previo = grupos[clave];
      grupos[clave] = (
        cuenta: cuenta,
        departamento: '${f['departamento_entidad'] ?? ''}',
        norm: norm,
        variantes: {...?previo?.variantes, raw},
        n: (previo?.n ?? 0) + (int.tryParse('${f['n']}') ?? 0),
        asignado: (previo?.asignado ?? 0) + _num(f['asignado']),
      );
    }
    return [
      for (final e in grupos.entries)
        DependenciaPresupuesto(
          clave: e.key,
          nombre: nombreParaMostrar(e.value.variantes.first),
          cuentaSecop: e.value.cuenta,
          variantes: e.value.variantes.toList(),
          procesos: e.value.n,
          asignadoCop: e.value.asignado,
          departamento: e.value.departamento,
        ),
    ]..sort((a, b) => b.asignadoCop.compareTo(a.asignadoCop));
  }

  /// Contratado y pagado de una dependencia, sumando los contratos de sus
  /// procesos (consultados por lotes de portafolio).
  static Future<EjecucionDependencia> ejecucion(
    DependenciaPresupuesto d, {
    required String nit,
    int? anio,
  }) async {
    if (d.partes.isNotEmpty) {
      // Una tras otra: cada parte ya consulta en paralelo por lotes.
      var total = const EjecucionDependencia(
        contratos: 0,
        contratadoCop: 0,
        pagadoCop: 0,
        facturadoCop: 0,
        pendienteCop: 0,
        procesosConsultados: 0,
        procesosTotales: 0,
      );
      for (final p in d.partes) {
        final e = await ejecucion(p, nit: nit, anio: anio);
        total = EjecucionDependencia(
          contratos: total.contratos + e.contratos,
          contratadoCop: total.contratadoCop + e.contratadoCop,
          pagadoCop: total.pagadoCop + e.pagadoCop,
          facturadoCop: total.facturadoCop + e.facturadoCop,
          pendienteCop: total.pendienteCop + e.pendienteCop,
          procesosConsultados:
              total.procesosConsultados + e.procesosConsultados,
          procesosTotales: total.procesosTotales + e.procesosTotales,
        );
      }
      return total;
    }
    final unidades = d.variantes.map((v) => "'${_sql(v)}'").join(',');
    final filas = await _get(
      _procesos,
      // Un portafolio por fila (las filas repetidas no gastan el límite).
      'SELECT id_del_portafolio, max(precio_base) AS pb '
      'WHERE ${_filtroBase(nit: nit, anio: anio, cuentaSecop: d.cuentaSecop)} '
      'AND nombre_de_la_unidad_de in ($unidades) '
      'GROUP BY id_del_portafolio '
      'ORDER BY pb DESC LIMIT $_maxProcesosDetalle',
    );
    final portafolios = {
      for (final f in filas.cast<Map<String, dynamic>>())
        if ('${f['id_del_portafolio'] ?? ''}'.isNotEmpty)
          '${f['id_del_portafolio']}',
    }.toList();

    var contratos = 0;
    double contratado = 0, pagado = 0, facturado = 0, pendiente = 0;
    final lotes = [
      for (var i = 0; i < portafolios.length; i += _lote)
        portafolios.sublist(i, (i + _lote).clamp(0, portafolios.length)),
    ];
    // De a 4 consultas a la vez para no saturar Datos Abiertos.
    for (var i = 0; i < lotes.length; i += 4) {
      final resultados = await Future.wait([
        for (final lote in lotes.skip(i).take(4))
          _get(
            _contratos,
            'SELECT count(*) AS n, sum(valor_del_contrato) AS contratado, '
            'sum(valor_pagado) AS pagado, sum(valor_facturado) AS facturado, '
            'sum(valor_pendiente_de_ejecucion) AS pendiente '
            "WHERE proceso_de_compra in (${lote.map((p) => "'${_sql(p)}'").join(',')})",
          ),
      ]);
      for (final r in resultados) {
        if (r.isEmpty) continue;
        final f = r.first as Map<String, dynamic>;
        contratos += int.tryParse('${f['n'] ?? 0}') ?? 0;
        contratado += _num(f['contratado']);
        pagado += _num(f['pagado']);
        facturado += _num(f['facturado']);
        pendiente += _num(f['pendiente']);
      }
    }
    return EjecucionDependencia(
      contratos: contratos,
      contratadoCop: contratado,
      pagadoCop: pagado,
      facturadoCop: facturado,
      pendienteCop: pendiente,
      // Solo se recorta cuando se llega al límite; si hay menos portafolios
      // que procesos es porque comparten portafolio o aún no lo tienen.
      procesosConsultados: filas.length >= _maxProcesosDetalle
          ? filas.length
          : d.procesos,
      procesosTotales: d.procesos,
    );
  }
}

class PresupuestoDependenciasException implements Exception {
  const PresupuestoDependenciasException(this.message);
  final String message;

  @override
  String toString() => message;
}
