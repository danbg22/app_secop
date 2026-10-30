import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/secop_i.dart';
import 'security_service.dart';

/// Entidad con procesos publicados en SECOP I. Las entidades de régimen
/// especial (p. ej. universidades públicas, Ley 30 de 1992) no publican en
/// SECOP II, pero muchas registraron sus convocatorias en SECOP I. Son
/// procesos convocados, no contratos firmados: no traen contratista ni
/// valor del contrato, solo la cuantía estimada del proceso.
class EntidadSecopI {
  const EntidadSecopI({
    required this.nombre,
    required this.nit,
    required this.departamento,
    required this.municipio,
    required this.procesos,
    required this.valorEstimado,
    required this.desde,
    required this.hasta,
  });

  final String nombre;
  final String nit;
  final String departamento;
  final String municipio;
  final int procesos;
  final double valorEstimado;
  final String desde;
  final String hasta;

  String get periodo => desde == hasta ? desde : '$desde – $hasta';

  factory EntidadSecopI.fromMap(Map map) {
    String v(String k) => (map[k] ?? '').toString().trim();
    final nit = v('nit_de_la_entidad');
    return EntidadSecopI(
      nombre: v('nombre_entidad'),
      nit: nit.toLowerCase() == 'no definido' ? '' : nit,
      departamento: v('departamento_entidad'),
      municipio: v('municipio_entidad'),
      procesos: int.tryParse(v('procesos')) ?? 0,
      valorEstimado: double.tryParse(v('valor')) ?? 0,
      desde: v('desde'),
      hasta: v('hasta'),
    );
  }
}

class SecopIProcesosService {
  static const String _select =
      'nombre_entidad,nit_de_la_entidad,departamento_entidad,municipio_entidad,'
      'count(*) as procesos,sum(cuantia_proceso) as valor,'
      'min(anno_cargue_secop) as desde,max(anno_cargue_secop) as hasta';
  static const String _group =
      'nombre_entidad,nit_de_la_entidad,departamento_entidad,municipio_entidad';

  static final Map<String, List<EntidadSecopI>> _cache = {};

  static Future<List<dynamic>> _consultar(Map<String, String> params) async {
    try {
      final res = await http
          .get(Uri.https('www.datos.gov.co', '/resource/${SecopI.dataset}.json', params))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return const [];
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  static String _normalizar(String texto) => texto
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U');

  static String _literal(String valor) => "'${valor.replaceAll("'", "''")}'";

  /// Busca entidades por nombre o por los NIT del catálogo y devuelve sus
  /// totales reales de procesos. En SECOP I `LIKE` sobre el nombre no usa
  /// índice (~35 s), por eso se ubican los nombres con la búsqueda de texto
  /// indexada (`$q`) y luego se agregan por nombre exacto.
  static Future<List<EntidadSecopI>> buscarEntidades(
    String consulta, {
    List<String> nitsCatalogo = const [],
  }) async {
    final clave = '${_normalizar(consulta)}|${nitsCatalogo.join(',')}';
    final enCache = _cache[clave];
    if (enCache != null) return enCache;

    final tokens = _normalizar(
      SecurityService.sanitizeSoqlToken(consulta, maxLength: 100),
    )
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .take(5)
        .toList();

    final nombres = <String>{};
    if (tokens.isNotEmpty) {
      final candidatos = await _consultar({
        r'$select': 'nombre_entidad,count(*) as n',
        r'$q': tokens.join(' '),
        r'$group': 'nombre_entidad',
        r'$order': 'n DESC',
        r'$limit': '50',
      });
      for (final c in candidatos.whereType<Map>()) {
        final nombre = (c['nombre_entidad'] ?? '').toString();
        final normal = _normalizar(nombre);
        if (tokens.every(normal.contains)) nombres.add(nombre);
      }
    }

    final nits = nitsCatalogo
        .map((n) => n.replaceAll(RegExp(r'[^0-9]'), ''))
        .where((n) => n.length >= 8)
        .toSet();
    if (nombres.isEmpty && nits.isEmpty) return const [];

    final condiciones = <String>[
      if (nombres.isNotEmpty)
        'nombre_entidad in (${nombres.take(20).map(_literal).join(',')})',
      if (nits.isNotEmpty)
        'nit_de_la_entidad in (${nits.map(_literal).join(',')})',
    ];
    final filas = await _consultar({
      r'$select': _select,
      r'$where': condiciones.join(' OR '),
      r'$group': _group,
      r'$order': 'procesos DESC',
      r'$limit': '30',
    });
    final resultado = filas
        .whereType<Map>()
        .map(EntidadSecopI.fromMap)
        .where((e) => e.nombre.isNotEmpty && e.procesos > 0)
        .toList();
    _cache[clave] = resultado;
    return resultado;
  }

  /// Procesos publicados por la entidad, del más reciente al más antiguo.
  static Future<List<Map<String, dynamic>>> procesosDeEntidad(
    EntidadSecopI entidad, {
    int limite = 200,
  }) async {
    final filas = await _consultar({
      r'$select':
          'numero_de_proceso,detalle_del_objeto_a_contratar,modalidad_de_contratacion,'
          'estado_del_proceso,cuantia_proceso,fecha_de_cargue_en_el_secop,'
          'ruta_proceso_en_secop_i',
      r'$where': 'nombre_entidad = ${_literal(entidad.nombre)}',
      r'$order': 'fecha_de_cargue_en_el_secop DESC',
      r'$limit': '$limite',
    });
    return filas
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }
}
