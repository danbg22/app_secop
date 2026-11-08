import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'paa_service.dart';

/// Verifica contra SECOP II lo que una entidad proyectó en su PAA: el
/// proceso real de cada compra, su contrato y sus modificaciones, y cuánto
/// del plan se ha contratado y pagado.
///
/// Fuentes (Datos Abiertos): procesos p6dx-8zbt, contratos jbjy-vk9h y
/// modificaciones a contratos u8cx-r425. Todas las consultas filtran por
/// igualdad (código de la cuenta, portafolio o contrato), que es lo que
/// Datos Abiertos responde en menos de un segundo.

enum EstadoProceso {
  abierto('Abierto para ofertas'),
  enCurso('En evaluación'),
  estudioMercado('Estudio de mercado'),
  adjudicado('Adjudicado o contratado'),
  desierto('Declarado desierto'),
  cancelado('Cancelado');

  const EstadoProceso(this.etiqueta);
  final String etiqueta;
}

class ProcesoSecop {
  const ProcesoSecop({
    required this.referencia,
    required this.portafolio,
    required this.nombre,
    required this.descripcion,
    required this.estado,
    required this.fase,
    required this.precioBaseCop,
    required this.valorAdjudicadoCop,
    required this.publicacionIso,
    required this.recepcionIso,
    required this.proveedor,
    required this.modalidad,
    required this.respuestas,
    required this.manifestaciones,
    required this.url,
  });

  final String referencia;
  final String portafolio;
  final String nombre;
  final String descripcion;
  final EstadoProceso estado;

  /// Fase tal como la publica SECOP II ("Presentación de oferta").
  final String fase;
  final double precioBaseCop;
  final double valorAdjudicadoCop;
  final String publicacionIso;

  /// Cierre de recepción de ofertas, si la entidad lo registró.
  final String recepcionIso;
  final String proveedor;
  final String modalidad;
  final int respuestas;
  final int manifestaciones;
  final String url;

  DateTime? get cierre => DateTime.tryParse(recepcionIso);
  DateTime? get publicacion => DateTime.tryParse(publicacionIso);

  /// Una empresa presenta oferta (no es contratación directa sin ofertas).
  bool get esCompetitivo {
    final m = modalidad.toLowerCase();
    return !m.contains('directa') || m.contains('ofertas');
  }

  static double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

  static EstadoProceso _estado(Map<String, dynamic> m) {
    final estado = '${m['estado_del_procedimiento'] ?? ''}'.toLowerCase();
    final resumen = '${m['estado_resumen'] ?? ''}'.toLowerCase();
    final apertura = '${m['estado_de_apertura_del_proceso'] ?? ''}'
        .toLowerCase();
    final modalidad = '${m['modalidad_de_contratacion'] ?? ''}'.toLowerCase();
    if (estado.contains('cancel') || resumen.contains('cancel')) {
      return EstadoProceso.cancelado;
    }
    if (estado.contains('desiert') || resumen.contains('desiert')) {
      return EstadoProceso.desierto;
    }
    if ('${m['adjudicado'] ?? ''}'.toLowerCase() == 'si' ||
        resumen.contains('adjudicado') ||
        estado.contains('seleccionado') ||
        estado.contains('aprobado')) {
      return EstadoProceso.adjudicado;
    }
    if (modalidad.contains('solicitud de información') ||
        modalidad.contains('solicitud de informacion')) {
      return EstadoProceso.estudioMercado;
    }
    if ((estado.contains('publicado') || estado == 'abierto') &&
        apertura == 'abierto') {
      // Datos Abiertos se actualiza a diario: si el día de cierre ya pasó,
      // el proceso está en evaluación aunque aún diga "abierto".
      final cierre = DateTime.tryParse('${m['fecha_de_recepcion_de'] ?? ''}');
      final hoy = DateTime.now();
      if (cierre != null &&
          DateTime(
            cierre.year,
            cierre.month,
            cierre.day,
          ).isBefore(DateTime(hoy.year, hoy.month, hoy.day))) {
        return EstadoProceso.enCurso;
      }
      return EstadoProceso.abierto;
    }
    return EstadoProceso.enCurso;
  }

  factory ProcesoSecop.fromMap(Map<String, dynamic> m) {
    final url = m['urlproceso'];
    final proveedor = '${m['nombre_del_proveedor'] ?? ''}'.trim();
    return ProcesoSecop(
      referencia: '${m['referencia_del_proceso'] ?? ''}'.trim(),
      portafolio: '${m['id_del_portafolio'] ?? ''}'.trim(),
      nombre: '${m['nombre_del_procedimiento'] ?? ''}'.trim(),
      descripcion: '${m['descripci_n_del_procedimiento'] ?? ''}'.trim(),
      estado: _estado(m),
      fase: '${m['estado_resumen'] ?? ''}'.trim(),
      precioBaseCop: _num(m['precio_base']),
      valorAdjudicadoCop: _num(m['valor_total_adjudicacion']),
      publicacionIso: '${m['fecha_de_publicacion_del'] ?? ''}',
      recepcionIso: '${m['fecha_de_recepcion_de'] ?? ''}',
      proveedor: proveedor.toLowerCase() == 'no definido' ? '' : proveedor,
      modalidad: '${m['modalidad_de_contratacion'] ?? ''}'.trim(),
      respuestas:
          int.tryParse('${m['respuestas_al_procedimiento'] ?? ''}') ?? 0,
      manifestaciones:
          int.tryParse('${m['proveedores_que_manifestaron'] ?? ''}') ?? 0,
      url: url is Map ? '${url['url'] ?? ''}' : '',
    );
  }
}

/// Cómo se encontró el proceso de una compra del plan.
enum Vinculo {
  /// La entidad lo vinculó en el PAA (referencia exacta).
  porEntidad,

  /// Coincidencia por objeto y valor (no vinculado por la entidad).
  porCoincidencia,
}

class Cruce {
  const Cruce({
    required this.proceso,
    required this.vinculo,
    this.similitud = 1,
  });

  final ProcesoSecop proceso;
  final Vinculo vinculo;

  /// 0–1: qué tanto se parecen el objeto y el valor.
  final double similitud;
}

class ContratoSecop {
  const ContratoSecop({
    required this.id,
    required this.referencia,
    required this.estado,
    required this.valorCop,
    required this.pagadoCop,
    required this.firmaIso,
    required this.inicioIso,
    required this.finIso,
    required this.proveedor,
    required this.diasAdicionados,
    required this.url,
  });

  final String id;
  final String referencia;
  final String estado;
  final double valorCop;
  final double pagadoCop;
  final String firmaIso;
  final String inicioIso;
  final String finIso;
  final String proveedor;
  final int diasAdicionados;
  final String url;
}

class ModificacionContrato {
  const ModificacionContrato({
    required this.fechaIso,
    required this.proposito,
    required this.valorCop,
    required this.diasExtendidos,
  });

  final String fechaIso;
  final String proposito;

  /// Valor que registra la modificación en SECOP II.
  final double valorCop;
  final int diasExtendidos;
}

/// Lo contratado y pagado en el año por la cuenta, frente a su plan.
class EjecucionPlan {
  const EjecucionPlan({
    required this.contratos,
    required this.contratadoCop,
    required this.pagadoCop,
    this.sinValor = 0,
  });

  final int contratos;

  /// Contratos registrados con valor $ 0 en Datos Abiertos (lo contratado
  /// queda por debajo de lo real).
  final int sinValor;
  final double contratadoCop;
  final double pagadoCop;
}

class VerificacionPaaService {
  VerificacionPaaService._();

  static const String _procesos =
      'https://www.datos.gov.co/resource/p6dx-8zbt.json';
  static const String _contratos =
      'https://www.datos.gov.co/resource/jbjy-vk9h.json';
  static const String _modificaciones =
      'https://www.datos.gov.co/resource/u8cx-r425.json';

  static String _sql(String v) => v.replaceAll("'", "''");
  static double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

  static Future<List<dynamic>> _get(String base, String query) async {
    final uri = Uri.parse(base).replace(queryParameters: {r'$query': query});
    for (var intento = 1; ; intento++) {
      try {
        final r = await http.get(uri).timeout(const Duration(seconds: 60));
        if (r.statusCode == 200) {
          return jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
        }
        if (r.statusCode < 500 && r.statusCode != 429) {
          throw PaaException('SECOP II respondió con error ${r.statusCode}.');
        }
      } on PaaException {
        rethrow;
      } catch (_) {
        if (intento >= 3) {
          throw const PaaException(
            'No fue posible consultar SECOP II. Revisa tu conexión.',
          );
        }
      }
      if (intento >= 3) {
        throw const PaaException('SECOP II no respondió. Intenta de nuevo.');
      }
      await Future<void>.delayed(Duration(milliseconds: 700 * intento));
    }
  }

  /// Procesos que la cuenta publicó en SECOP II desde el 1 de enero del año
  /// del plan, cada uno una vez (Datos Abiertos repite filas).
  static Future<List<ProcesoSecop>> procesosDeCuenta(
    String codigoEntidad,
    int anio,
  ) async {
    final filas = await _get(
      _procesos,
      'SELECT referencia_del_proceso, id_del_portafolio, nombre_del_procedimiento, '
      'descripci_n_del_procedimiento, estado_del_procedimiento, estado_resumen, '
      'estado_de_apertura_del_proceso, adjudicado, precio_base, '
      'valor_total_adjudicacion, fecha_de_publicacion_del, fecha_de_recepcion_de, '
      'fecha_de_ultima_publicaci, nombre_del_proveedor, modalidad_de_contratacion, '
      'respuestas_al_procedimiento, proveedores_que_manifestaron, urlproceso '
      "WHERE codigo_entidad='${_sql(codigoEntidad)}' "
      "AND fecha_de_publicacion_del >= '$anio-01-01T00:00:00' "
      'ORDER BY fecha_de_ultima_publicaci DESC LIMIT 50000',
    );
    final vistos = <String>{};
    return [
      for (final f in filas.cast<Map<String, dynamic>>())
        if (vistos.add(
          '${f['referencia_del_proceso'] ?? ''}|${f['id_del_portafolio'] ?? ''}',
        ))
          ProcesoSecop.fromMap(f),
    ];
  }

  static const Set<String> _vacias = {
    'PARA',
    'POR',
    'CON',
    'LOS',
    'LAS',
    'DEL',
    'QUE',
    'COMO',
    'SENA',
    'REGIONAL',
    'CENTRO',
    'VIGENCIA',
    'SERVICIOS',
    'SERVICIO',
    'PRESTACION',
    'PRESTAR',
    'CONTRATAR',
    'ADQUISICION',
    'COMPRA',
    'DIFERENTES',
    'ENTIDAD',
    'MUNICIPIO',
    'DEPARTAMENTO',
    'SEGUN',
    'TODAS',
    'TODOS',
  };

  static Set<String> _palabras(String t) {
    const tildes = {'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ñ': 'N'};
    final s = t.toUpperCase().split('').map((c) => tildes[c] ?? c).join();
    return {
      for (final w in s.split(RegExp(r'[^A-Z0-9]+')))
        if (w.length > 3 && !_vacias.contains(w) && int.tryParse(w) == null) w,
    };
  }

  /// Une cada compra del plan con su proceso en SECOP II: primero por la
  /// referencia que vinculó la entidad; si no la vinculó, por el parecido del
  /// objeto y del valor (solo compras competitivas con procesos competitivos,
  /// y cada proceso a una sola compra).
  static Map<String, Cruce> cruzar(
    List<ItemPaa> items,
    List<ProcesoSecop> procesos,
  ) {
    final porReferencia = <String, ProcesoSecop>{
      for (final p in procesos)
        if (p.referencia.isNotEmpty) p.referencia.toUpperCase(): p,
    };
    final r = <String, Cruce>{};
    final usados = <String>{};
    for (final i in items) {
      if (!i.yaTieneProceso) continue;
      final p = porReferencia[i.procesoRelacionado.trim().toUpperCase()];
      if (p != null) {
        r[i.id] = Cruce(proceso: p, vinculo: Vinculo.porEntidad);
        usados.add(p.referencia);
      }
    }

    final candidatos = [
      for (final p in procesos)
        if (p.esCompetitivo && !usados.contains(p.referencia))
          (p, _palabras('${p.nombre} ${p.descripcion}')),
    ];
    final pares = <(double, ItemPaa, ProcesoSecop)>[];
    for (final i in items) {
      if (r.containsKey(i.id) || i.yaTieneProceso || !i.esCompetitiva) {
        continue;
      }
      final pi = _palabras(i.descripcion);
      if (pi.length < 2) continue;
      for (final (p, pp) in candidatos) {
        final comunes = pi.intersection(pp).length;
        if (comunes < 2) continue;
        var s = comunes / pi.union(pp).length;
        if (i.valorCop > 0 && p.precioBaseCop > 0) {
          final a = i.valorCop, b = p.precioBaseCop;
          s = s * 0.75 + 0.25 * ((a < b ? a : b) / (a > b ? a : b));
        }
        // El estudio de mercado precede al proceso real: si ambos se
        // parecen a la compra, gana el proceso.
        final umbral = p.estado == EstadoProceso.estudioMercado ? 0.4 : 0.45;
        if (p.estado == EstadoProceso.estudioMercado) s *= 0.85;
        if (s >= umbral) pares.add((s, i, p));
      }
    }
    pares.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (s, i, p) in pares) {
      if (r.containsKey(i.id) || usados.contains(p.referencia)) continue;
      r[i.id] = Cruce(
        proceso: p,
        vinculo: Vinculo.porCoincidencia,
        similitud: s,
      );
      usados.add(p.referencia);
    }
    return r;
  }

  /// Contratos que nacieron del proceso (por su portafolio).
  static Future<List<ContratoSecop>> contratos(String portafolio) async {
    if (portafolio.isEmpty) return const [];
    final filas = await _get(
      _contratos,
      'SELECT id_contrato, referencia_del_contrato, estado_contrato, '
      'valor_del_contrato, valor_pagado, fecha_de_firma, '
      'fecha_de_inicio_del_contrato, fecha_de_fin_del_contrato, '
      'proveedor_adjudicado, dias_adicionados, urlproceso '
      "WHERE proceso_de_compra='${_sql(portafolio)}' LIMIT 50",
    );
    final vistos = <String>{};
    return [
      for (final f in filas.cast<Map<String, dynamic>>())
        if (vistos.add('${f['id_contrato']}'))
          ContratoSecop(
            id: '${f['id_contrato'] ?? ''}',
            referencia: '${f['referencia_del_contrato'] ?? ''}',
            estado: '${f['estado_contrato'] ?? ''}',
            valorCop: _num(f['valor_del_contrato']),
            pagadoCop: _num(f['valor_pagado']),
            firmaIso: '${f['fecha_de_firma'] ?? ''}',
            inicioIso: '${f['fecha_de_inicio_del_contrato'] ?? ''}',
            finIso: '${f['fecha_de_fin_del_contrato'] ?? ''}',
            proveedor: '${f['proveedor_adjudicado'] ?? ''}'.trim(),
            diasAdicionados: _num(f['dias_adicionados']).round(),
            url: f['urlproceso'] is Map
                ? '${f['urlproceso']['url'] ?? ''}'
                : '',
          ),
    ];
  }

  /// Modificaciones (adiciones, prórrogas…) aprobadas del contrato.
  static Future<List<ModificacionContrato>> modificaciones(
    String idContrato,
  ) async {
    if (idContrato.isEmpty) return const [];
    final filas = await _get(
      _modificaciones,
      'SELECT fecha_de_aprobacion, proposito_modificacion, valor_modificacion, '
      'dias_extendidos, identificador_modificacion '
      "WHERE id_contrato='${_sql(idContrato)}' "
      'ORDER BY fecha_de_aprobacion LIMIT 50',
    );
    final vistos = <String>{};
    return [
      for (final f in filas.cast<Map<String, dynamic>>())
        if (vistos.add(
          '${f['identificador_modificacion'] ?? f['fecha_de_aprobacion']}',
        ))
          ModificacionContrato(
            fechaIso: '${f['fecha_de_aprobacion'] ?? ''}',
            proposito: '${f['proposito_modificacion'] ?? ''}'.trim(),
            valorCop: _num(f['valor_modificacion']),
            diasExtendidos: _num(f['dias_extendidos']).round(),
          ),
    ];
  }

  /// Contratos firmados por la cuenta en el año: cuántos, por cuánto y cuánto
  /// se ha pagado.
  static Future<EjecucionPlan> ejecucion(
    String codigoEntidad,
    int anio, {
    bool contarSinValor = false,
  }) async {
    final filtro =
        "WHERE codigo_entidad='${_sql(codigoEntidad)}' "
        "AND fecha_de_firma >= '$anio-01-01T00:00:00' "
        "AND fecha_de_firma < '${anio + 1}-01-01T00:00:00'";
    final consultas = await Future.wait([
      _get(
        _contratos,
        'SELECT count(*) AS n, sum(valor_del_contrato) AS v, '
        'sum(valor_pagado) AS p $filtro',
      ),
      if (contarSinValor)
        _get(
          _contratos,
          'SELECT count(*) AS n $filtro AND valor_del_contrato = 0',
        ),
    ]);
    final f = consultas.first;
    final m = f.isEmpty
        ? const <String, dynamic>{}
        : f.first as Map<String, dynamic>;
    final cero = contarSinValor && consultas.last.isNotEmpty
        ? int.tryParse('${(consultas.last.first as Map)['n'] ?? 0}') ?? 0
        : 0;
    return EjecucionPlan(
      contratos: int.tryParse('${m['n'] ?? 0}') ?? 0,
      contratadoCop: _num(m['v']),
      pagadoCop: _num(m['p']),
      sinValor: cero,
    );
  }

  /// Procesos que hoy reciben ofertas en las cuentas [codigos] (consulta
  /// liviana: solo abiertos y con cierre desde hoy), a medida que llegan.
  static Stream<(String, List<ProcesoSecop>)> abiertosDe(List<String> codigos) {
    final control = StreamController<(String, List<ProcesoSecop>)>();
    final hoy = DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    final desde = '${hoy.year}-${dos(hoy.month)}-${dos(hoy.day)}T00:00:00';
    var siguiente = 0;
    Future<void> trabajador() async {
      while (siguiente < codigos.length) {
        final c = codigos[siguiente++];
        try {
          final filas = await _get(
            _procesos,
            'SELECT referencia_del_proceso, id_del_portafolio, nombre_del_procedimiento, '
            'descripci_n_del_procedimiento, estado_del_procedimiento, estado_resumen, '
            'estado_de_apertura_del_proceso, adjudicado, precio_base, '
            'valor_total_adjudicacion, fecha_de_publicacion_del, fecha_de_recepcion_de, '
            'nombre_del_proveedor, modalidad_de_contratacion, '
            'respuestas_al_procedimiento, proveedores_que_manifestaron, urlproceso '
            "WHERE codigo_entidad='${_sql(c)}' "
            "AND estado_de_apertura_del_proceso='Abierto' "
            "AND fecha_de_recepcion_de >= '$desde' LIMIT 500",
          );
          final vistos = <String>{};
          control.add((
            c,
            [
                  for (final f in filas.cast<Map<String, dynamic>>())
                    if (vistos.add('${f['referencia_del_proceso']}'))
                      ProcesoSecop.fromMap(f),
                ]
                .where(
                  (p) => p.estado == EstadoProceso.abierto && p.esCompetitivo,
                )
                .toList(),
          ));
        } catch (e) {
          control.addError(e);
        }
      }
    }

    Future.wait([for (var k = 0; k < 10; k++) trabajador()])
        .whenComplete(control.close);
    return control.stream;
  }

  /// Ejecución de varias cuentas, a medida que llega (de a 6 consultas).
  static Stream<(String, EjecucionPlan)> ejecucionDe(
    List<String> codigos,
    int anio,
  ) {
    final control = StreamController<(String, EjecucionPlan)>();
    var siguiente = 0;
    Future<void> trabajador() async {
      while (siguiente < codigos.length) {
        final c = codigos[siguiente++];
        try {
          control.add((c, await ejecucion(c, anio)));
        } catch (e) {
          control.addError(e);
        }
      }
    }

    Future.wait([for (var k = 0; k < 10; k++) trabajador()])
        .whenComplete(control.close);
    return control.stream;
  }

  /// Evento de calendario (.ics) de día completo con el día de cierre de un
  /// proceso abierto (Datos Abiertos publica el día, no la hora), con aviso
  /// el día anterior.
  static String eventoCalendario(ProcesoSecop p, String entidad) {
    final cierre = p.cierre ?? DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    String dia(DateTime d) => '${d.year}${dos(d.month)}${dos(d.day)}';
    final u = DateTime.now().toUtc();
    final sello = '${dia(u)}T${dos(u.hour)}${dos(u.minute)}${dos(u.second)}Z';
    String esc(String t) => t
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Contrata Legal//Proyeccion de contratacion//ES',
      'BEGIN:VEVENT',
      'UID:${p.referencia.isEmpty ? p.portafolio : p.referencia}@contratalegal',
      'DTSTAMP:$sello',
      'DTSTART;VALUE=DATE:${dia(cierre)}',
      'DTEND;VALUE=DATE:${dia(cierre.add(const Duration(days: 1)))}',
      'SUMMARY:${esc('Cierre de ofertas: ${p.nombre.isEmpty ? p.referencia : p.nombre}')}',
      'DESCRIPTION:${esc('$entidad · ${p.referencia} · ${p.modalidad}\nConfirma la hora exacta en SECOP II: ${p.url}')}',
      'BEGIN:VALARM',
      'TRIGGER:-P1D',
      'ACTION:DISPLAY',
      'DESCRIPTION:${esc('Mañana cierra la recepción de ofertas')}',
      'END:VALARM',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }
}
