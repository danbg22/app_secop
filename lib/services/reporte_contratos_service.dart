import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/estructura_sena.dart';
import '../utils/dias_habiles_colombia.dart';
import '../utils/texto_profesional.dart';
import 'presupuesto_dependencias_service.dart';
import 'reporte_contratos_modelo.dart';

/// Una unidad de contratación tal como la registra la entidad en SECOP II
/// (p. ej. el Despacho de la Dirección Regional Cesar del SENA). Puede
/// juntar varias cuentas y formas de escribir el nombre, o, si es el
/// consolidado de una regional, varias unidades ([subunidades]).
class UnidadContratacion {
  const UnidadContratacion({
    required this.etiqueta,
    required this.partes,
    this.nombre,
    this.regional,
    this.esDespacho = false,
    this.subunidades = const [],
  });

  /// Nombre uniforme ("Regional Cesar · Despacho de la Dirección Regional").
  final String etiqueta;

  /// Nombre corto para la columna Dependencia ("Despacho de la Dirección
  /// Regional"); si falta, [etiqueta].
  final String? nombre;

  /// Cuenta + nombres de la unidad en SECOP II.
  final List<DependenciaPresupuesto> partes;

  /// Regional del SENA a la que pertenece, si aplica.
  final String? regional;
  final bool esDespacho;

  /// Unidades del consolidado de una regional.
  final List<UnidadContratacion> subunidades;

  bool get esConsolidado => subunidades.isNotEmpty;

  int get procesos => esConsolidado
      ? subunidades.fold(0, (s, u) => s + u.procesos)
      : partes.fold(0, (s, p) => s + p.procesos);

  /// Nombres exactos con que la entidad la registró, para el reporte.
  List<String> get variantes => {
    for (final u in esConsolidado ? subunidades : [this])
      for (final p in u.partes)
        for (final v in p.variantes)
          if (v.trim().isNotEmpty) v.trim(),
  }.toList();

  List<String> get cuentas => {
    for (final u in esConsolidado ? subunidades : [this])
      for (final p in u.partes)
        if (p.cuentaSecop.isNotEmpty) p.cuentaSecop,
  }.toList();
}

/// Datos para el reporte de contratos por unidad de contratación: el
/// criterio exacto. SECOP II registra en cada proceso la unidad que lo
/// adelanta (dataset de procesos p6dx-8zbt) y cada contrato apunta a su
/// proceso por el portafolio (`proceso_de_compra` en jbjy-vk9h), así que los
/// contratos de una unidad son los que nacieron de sus procesos.
class ReporteContratosService {
  ReporteContratosService._();

  static const String _procesos =
      'https://www.datos.gov.co/resource/p6dx-8zbt.json';
  static const String _contratos =
      'https://www.datos.gov.co/resource/jbjy-vk9h.json';
  static const int _lote = 80;

  static const String campos =
      'id_contrato,referencia_del_contrato,fecha_de_firma,'
      'fecha_de_inicio_del_contrato,fecha_de_fin_del_contrato,'
      'objeto_del_contrato,modalidad_de_contratacion,tipo_de_contrato,'
      'proveedor_adjudicado,documento_proveedor,valor_del_contrato,'
      'valor_pagado,estado_contrato,nombre_entidad,urlproceso,'
      'duraci_n_del_contrato,dias_adicionados,origen_de_los_recursos,'
      'destino_gasto,presupuesto_general_de_la_nacion_pgn,recursos_propios,'
      'sistema_general_de_participaciones,sistema_general_de_regal_as,'
      'recursos_de_credito,'
      'recursos_propios_alcald_as_gobernaciones_y_resguardos_ind_genas_';

  /// Contratos de prestación de servicios profesionales y de apoyo a la
  /// gestión (numeral 3 del artículo 32 de la Ley 80 de 1993).
  static const String filtroPrestacionServicios =
      "tipo_de_contrato = 'Prestación de servicios' AND "
      "(upper(justificacion_modalidad_de) LIKE '%APOYO A LA GESTI%' OR "
      "upper(justificacion_modalidad_de) LIKE '%SERVICIOS PROFESIONALES%')";

  /// Firmados entre el 1 de enero de [desde] y [corte] inclusive (o, sin
  /// firma registrada, iniciados en ese lapso).
  static String filtroFechas(int desde, DateTime corte) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final a = '$desde-01-01T00:00:00.000';
    final b =
        '${corte.year}-${dos(corte.month)}-${dos(corte.day)}T23:59:59.999';
    return "((fecha_de_firma >= '$a' AND fecha_de_firma <= '$b') OR "
        "(fecha_de_firma IS NULL AND fecha_de_inicio_del_contrato >= '$a' "
        "AND fecha_de_inicio_del_contrato <= '$b'))";
  }

  static String _sql(String v) => v.replaceAll("'", "''");

  static String _nit9(String nit) {
    final d = nit.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length > 9 ? d.substring(0, 9) : d;
  }

  static Future<List<dynamic>> _get(String base, String query) async {
    final uri = Uri.parse(base).replace(queryParameters: {r'$query': query});
    for (var intento = 1; ; intento++) {
      try {
        final r = await http.get(uri).timeout(const Duration(seconds: 60));
        if (r.statusCode == 200) {
          return jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
        }
        if (r.statusCode < 500 && r.statusCode != 429) {
          throw StateError('SECOP II respondió ${r.statusCode}');
        }
      } on StateError {
        rethrow;
      } catch (_) {
        if (intento >= 3) rethrow;
      }
      if (intento >= 3) throw StateError('SECOP II no respondió');
      await Future<void>.delayed(Duration(milliseconds: 700 * intento));
    }
  }

  /// Unidades de contratación de la entidad (o de una regional), con su
  /// nombre uniforme. En el SENA siguen su estructura (Dirección General,
  /// despacho de cada regional y centros) y cada regional trae primero su
  /// consolidado, para responder con un solo reporte.
  static Future<List<UnidadContratacion>> unidades({
    required String nit,
    String? departamento,
  }) async {
    final deps = await PresupuestoDependenciasService.dependencias(
      nit: nit,
      departamento: departamento,
    );
    if (!esNitSena(nit)) {
      return [
        for (final d in deps)
          if (d.procesos > 0)
            UnidadContratacion(etiqueta: d.nombre, partes: [d]),
      ]..sort((a, b) => b.procesos.compareTo(a.procesos));
    }
    final grupos =
        <String, ({UbicacionSena u, List<DependenciaPresupuesto> p})>{};
    for (final d in deps) {
      final u = EstructuraSena.ubicar(
        cuenta: d.cuentaSecop,
        unidad: d.variantes.first,
        departamento: d.departamento,
      );
      final clave = '${u.regional?.nombre ?? ''}|${u.nodo}';
      final previo = grupos[clave];
      grupos[clave] = (u: u, p: [...?previo?.p, d]);
    }
    int orden(NivelSena n) => switch (n) {
      NivelSena.nacional => 0,
      NivelSena.despachoRegional => 1,
      NivelSena.centro => 2,
      NivelSena.regionalSinDistinguir => 3,
      NivelSena.otra => 4,
    };
    final porRegional = <String, List<(int, UnidadContratacion)>>{};
    for (final g in grupos.values) {
      final unidad = UnidadContratacion(
        etiqueta: switch (g.u.nivel) {
          NivelSena.nacional => 'Dirección General · ${g.u.nodo}',
          NivelSena.otra => TextoProfesional.titulo(g.u.nodo),
          _ => 'Regional ${g.u.regional!.nombre} · ${g.u.nodo}',
        },
        nombre: g.u.nivel == NivelSena.otra
            ? TextoProfesional.titulo(g.u.nodo)
            : g.u.nodo,
        partes: g.p,
        regional: g.u.regional?.nombre,
        esDespacho: g.u.nivel == NivelSena.despachoRegional,
      );
      porRegional.putIfAbsent(g.u.regional?.nombre ?? '', () => []).add((
        orden(g.u.nivel),
        unidad,
      ));
    }
    final claves = porRegional.keys.toList()..sort();
    return [
      for (final r in claves)
        ...() {
          final lista = porRegional[r]!
            ..sort(
              (a, b) => a.$1 != b.$1
                  ? a.$1.compareTo(b.$1)
                  : a.$2.etiqueta.compareTo(b.$2.etiqueta),
            );
          final unidades = [for (final x in lista) x.$2];
          return [
            if (r.isNotEmpty && unidades.length > 1)
              UnidadContratacion(
                etiqueta: 'Regional $r · todas sus unidades (consolidado)',
                partes: const [],
                regional: r,
                subunidades: unidades,
              ),
            ...unidades,
          ];
        }(),
    ];
  }

  /// Contratos firmados entre el 1 de enero de [desde] y [corte] que
  /// nacieron de los procesos de la unidad (o de cada unidad del
  /// consolidado, con su nombre en la columna Dependencia). Se buscan los
  /// procesos desde el año anterior a [desde], porque un contrato puede
  /// firmarse el año siguiente a su proceso.
  static Future<List<ContratoReporte>> contratosDeUnidad({
    required String nit,
    required UnidadContratacion unidad,
    required int desde,
    required DateTime corte,
    bool soloPrestacionServicios = false,
    void Function(String)? progreso,
  }) async {
    final base = _nit9(nit);
    // Portafolio → dependencia.
    final portafolios = <String, String>{};
    final unidades = unidad.esConsolidado ? unidad.subunidades : [unidad];
    for (final u in unidades) {
      for (final p in u.partes) {
        progreso?.call(
          'Buscando los procesos de ${u.nombre ?? u.etiqueta} en SECOP II…',
        );
        final nombres = p.variantes
            .where((v) => v.trim().isNotEmpty)
            .map((v) => "'${_sql(v)}'")
            .join(',');
        if (nombres.isEmpty) continue;
        final filas = await _get(
          _procesos,
          'SELECT id_del_portafolio, count(*) AS n '
          "WHERE starts_with(nit_entidad, '${_sql(base)}') "
          "AND entidad='${_sql(p.cuentaSecop)}' "
          'AND nombre_de_la_unidad_de in ($nombres) '
          "AND fecha_de_publicacion_del >= '${desde - 1}-01-01T00:00:00' "
          'GROUP BY id_del_portafolio LIMIT 50000',
        );
        for (final f in filas.cast<Map<String, dynamic>>()) {
          final id = '${f['id_del_portafolio'] ?? ''}'.trim();
          if (id.isNotEmpty) {
            portafolios.putIfAbsent(id, () => u.nombre ?? u.etiqueta);
          }
        }
      }
    }
    final lista = portafolios.keys.toList();
    final lotes = [
      for (var i = 0; i < lista.length; i += _lote)
        lista.sublist(i, (i + _lote).clamp(0, lista.length)),
    ];
    final filtros = [
      'valor_del_contrato > 0',
      'valor_del_contrato < 500000000000',
      filtroFechas(desde, corte),
      if (soloPrestacionServicios) filtroPrestacionServicios,
    ].join(' AND ');
    final vistos = <String>{};
    final contratos = <ContratoReporte>[];
    var hechos = 0;
    // De a 4 consultas a la vez para no saturar Datos Abiertos.
    for (var i = 0; i < lotes.length; i += 4) {
      final respuestas = await Future.wait([
        for (final lote in lotes.skip(i).take(4))
          _get(
            _contratos,
            'SELECT $campos, proceso_de_compra '
            'WHERE proceso_de_compra in (${lote.map((p) => "'${_sql(p)}'").join(',')}) '
            'AND $filtros LIMIT 5000',
          ),
      ]);
      for (final filas in respuestas) {
        for (final m in filas.cast<Map<String, dynamic>>()) {
          if (vistos.add('${m['id_contrato']}')) {
            contratos.add(
              ContratoReporte.fromSecop(
                m,
                dependencia: portafolios['${m['proceso_de_compra']}'],
              ),
            );
          }
        }
      }
      hechos += respuestas.length;
      progreso?.call(
        'Consultando los contratos de ${lista.length} procesos… '
        '${(hechos / lotes.length * 100).round()} %',
      );
    }
    contratos.sort((a, b) => b.fechaFirmaIso.compareTo(a.fechaFirmaIso));
    return contratos;
  }

  /// Completa, para cada contrato, lo que pide la Directiva 018 sobre el
  /// contratista y la entidad (todas sus cuentas en SECOP II, mismo NIT):
  /// - contratos del contratista con la entidad en el periodo;
  /// - días hábiles entre el fin de su contrato anterior con la entidad y
  ///   el inicio de este (desde el año anterior al periodo);
  /// - si figura como supervisor u ordenador del gasto de contratos de la
  ///   entidad.
  static Future<void> completarHistorial({
    required String nit,
    required List<ContratoReporte> contratos,
    required int desde,
    required DateTime corte,
    void Function(String)? progreso,
  }) async {
    final base = _nit9(nit);
    final docs = {
      for (final c in contratos)
        if (c.documentoContratista.trim().isNotEmpty)
          c.documentoContratista.trim(),
    }.toList();
    if (docs.isEmpty) return;
    String dos(int n) => n.toString().padLeft(2, '0');
    final finCorte =
        '${corte.year}-${dos(corte.month)}-${dos(corte.day)}T23:59:59.999';

    // Historial de contratos de cada contratista con la entidad.
    final historial =
        <
          String,
          List<({String id, DateTime? firma, DateTime? inicio, DateTime? fin})>
        >{};
    final supervisa = <String, int>{};
    final ordena = <String, int>{};
    const tam = 60;
    final lotes = [
      for (var i = 0; i < docs.length; i += tam)
        docs.sublist(i, (i + tam).clamp(0, docs.length)),
    ];
    var hechos = 0;
    for (var i = 0; i < lotes.length; i += 4) {
      final grupo = lotes.skip(i).take(4).toList();
      final respuestas = await Future.wait([
        for (final lote in grupo) ...[
          _get(
            _contratos,
            'SELECT documento_proveedor, id_contrato, fecha_de_firma, '
            'fecha_de_inicio_del_contrato, fecha_de_fin_del_contrato, '
            'duraci_n_del_contrato, dias_adicionados '
            "WHERE nit_entidad='${_sql(base)}' "
            'AND documento_proveedor in (${lote.map((d) => "'${_sql(d)}'").join(',')}) '
            "AND fecha_de_firma >= '${desde - 1}-01-01T00:00:00' "
            "AND fecha_de_firma <= '$finCorte' LIMIT 20000",
          ),
          _get(
            _contratos,
            'SELECT n_mero_de_documento_supervisor AS d, count(*) AS n '
            "WHERE nit_entidad='${_sql(base)}' "
            'AND n_mero_de_documento_supervisor in (${lote.map((d) => "'${_sql(d)}'").join(',')}) '
            "AND fecha_de_firma >= '$desde-01-01T00:00:00' "
            'GROUP BY n_mero_de_documento_supervisor',
          ),
          _get(
            _contratos,
            'SELECT n_mero_de_documento_ordenador_del_gasto AS d, count(*) AS n '
            "WHERE nit_entidad='${_sql(base)}' "
            'AND n_mero_de_documento_ordenador_del_gasto in (${lote.map((d) => "'${_sql(d)}'").join(',')}) '
            "AND fecha_de_firma >= '$desde-01-01T00:00:00' "
            'GROUP BY n_mero_de_documento_ordenador_del_gasto',
          ),
        ],
      ]);
      for (var k = 0; k < respuestas.length; k += 3) {
        final vistos = <String>{};
        for (final m in respuestas[k].cast<Map<String, dynamic>>()) {
          final id = '${m['id_contrato']}';
          if (!vistos.add(id)) continue;
          historial
              .putIfAbsent('${m['documento_proveedor']}'.trim(), () => [])
              .add((
                id: id,
                firma: DateTime.tryParse('${m['fecha_de_firma'] ?? ''}'),
                inicio:
                    DateTime.tryParse(
                      '${m['fecha_de_inicio_del_contrato'] ?? ''}',
                    ) ??
                    ContratoReporte.estimarInicio(
                      DateTime.tryParse(
                        '${m['fecha_de_fin_del_contrato'] ?? ''}',
                      ),
                      '${m['duraci_n_del_contrato'] ?? ''}',
                      (double.tryParse('${m['dias_adicionados'] ?? ''}') ?? 0)
                          .round(),
                    ),
                fin: DateTime.tryParse(
                  '${m['fecha_de_fin_del_contrato'] ?? ''}',
                ),
              ));
        }
        for (final m in respuestas[k + 1].cast<Map<String, dynamic>>()) {
          supervisa['${m['d']}'.trim()] = int.tryParse('${m['n']}') ?? 0;
        }
        for (final m in respuestas[k + 2].cast<Map<String, dynamic>>()) {
          ordena['${m['d']}'.trim()] = int.tryParse('${m['n']}') ?? 0;
        }
      }
      hechos += grupo.length;
      progreso?.call(
        'Revisando el historial de ${docs.length} contratistas con la entidad… '
        '${(hechos / lotes.length * 100).round()} %',
      );
    }

    final inicioPeriodo = DateTime(desde);
    for (final c in contratos) {
      final doc = c.documentoContratista.trim();
      final propios = historial[doc] ?? const [];
      c.contratosConEntidad = doc.isEmpty
          ? null
          : propios
                .where(
                  (h) => h.firma != null && !h.firma!.isBefore(inicioPeriodo),
                )
                .length;
      // Contrato anterior: el que terminó más tarde antes de que este
      // iniciara (otro contrato, de cualquier cuenta de la entidad).
      final inicio = c.inicioEfectivo;
      if (inicio != null && doc.isNotEmpty) {
        DateTime? finAnterior;
        var simultaneo = false;
        for (final h in propios) {
          if (h.id == c.id || h.inicio == null || h.fin == null) continue;
          if (!h.inicio!.isBefore(inicio)) continue;
          if (!h.fin!.isBefore(inicio)) {
            simultaneo = true;
            continue;
          }
          if (finAnterior == null || h.fin!.isAfter(finAnterior)) {
            finAnterior = h.fin;
          }
        }
        if (simultaneo) {
          c.interrupcionHabiles = 0;
          c.interrupcionNota = 'Se superpone con el contrato anterior';
        } else if (finAnterior != null) {
          // Días hábiles sin contrato entre uno y otro.
          final entre =
              DiasHabilesColombia.entre(finAnterior, inicio) -
              (DiasHabilesColombia.esHabil(inicio) ? 1 : 0);
          c.interrupcionHabiles = entre < 0 ? 0 : entre;
          if (c.inicioEstimado) {
            c.interrupcionNota = 'Con fecha de inicio estimada';
          }
        } else {
          c.interrupcionNota = 'Sin contrato anterior desde ${desde - 1}';
        }
      }
      final s = supervisa[doc] ?? 0, o = ordena[doc] ?? 0;
      c.cargoDirectivo = doc.isEmpty
          ? ''
          : (s == 0 && o == 0)
          ? 'No figura en SECOP II'
          : [
              if (s > 0) 'Sí: supervisor de $s contrato${s == 1 ? '' : 's'}',
              if (o > 0)
                'Sí: ordenador del gasto de $o contrato${o == 1 ? '' : 's'}',
            ].join('; ');
    }
  }
}
