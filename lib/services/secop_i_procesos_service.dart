import '../utils/secop_i.dart';
import 'security_service.dart';
import '../utils/nit.dart';
import 'datos_abiertos.dart';

/// Entidad con procesos publicados en SECOP I. Las entidades de régimen
/// especial pueden publicar en ambas plataformas. Los registros históricos
/// pueden incluir un proceso convocado o un contrato con datos de firma.
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

  static Future<List<dynamic>> _consultar(
    Map<String, String> params, {
    bool reportarErrores = false,
  }) async {
    try {
      // Con el cliente común: token, caché, reintentos y turno.
      final res = await DatosAbiertos.obtener(
        DatosAbiertos.uri(SecopI.dataset, params),
        timeout: const Duration(seconds: 15),
        cache: DatosAbiertos.ttlPorDefecto,
      );
      return DatosAbiertos.decodificar(res);
    } catch (_) {
      if (reportarErrores) rethrow;
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
    bool reportarErrores = false,
  }) async {
    final clave = '${_normalizar(consulta)}|${nitsCatalogo.join(',')}';
    final enCache = _cache[clave];
    if (enCache != null) return enCache;

    final tokens = _normalizar(
      SecurityService.sanitizeSoqlToken(consulta, maxLength: 100),
    ).split(RegExp(r'\s+')).where((t) => t.length >= 3).take(5).toList();

    final nombres = <String>{};
    if (tokens.isNotEmpty) {
      // Sin orden en el servidor: con texto completo ($q) lo vuelve lento.
      final candidatos = await _consultar({
        r'$select': 'nombre_entidad,count(*) as n',
        r'$q': tokens.join(' '),
        r'$group': 'nombre_entidad',
        r'$limit': '200',
      }, reportarErrores: reportarErrores);
      for (final c in candidatos.whereType<Map>()) {
        final nombre = (c['nombre_entidad'] ?? '').toString();
        final normal = _normalizar(nombre);
        if (tokens.every(normal.contains)) nombres.add(nombre);
      }
    }

    // SECOP I guarda el NIT con guion y dígito de verificación
    // ("892300285-6"); se consultan todas sus formas.
    final nits = nitsCatalogo
        .map((n) => n.replaceAll(RegExp(r'[^0-9]'), ''))
        .where((n) => n.length >= 8)
        .expand((nit) => Nit.formas(Nit.formasNumericas(nit).firstOrNull ?? ''))
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
    }, reportarErrores: reportarErrores);
    final resultado = filas
        .whereType<Map>()
        .map(EntidadSecopI.fromMap)
        .where((e) => e.nombre.isNotEmpty && e.procesos > 0)
        .toList();
    if (resultado.isNotEmpty) _cache[clave] = resultado;
    return resultado;
  }

  static Future<EntidadSecopI?> archivoPorNit(String nit, String nombre) async {
    final filas = await buscarEntidades('', nitsCatalogo: [nit]);
    if (filas.isEmpty) return null;
    final primera = filas.first;
    final desde = [
      for (final e in filas)
        if (e.desde.isNotEmpty) e.desde,
    ]..sort();
    final hasta = [
      for (final e in filas)
        if (e.hasta.isNotEmpty) e.hasta,
    ]..sort();
    return EntidadSecopI(
      nombre: nombre,
      nit: nit,
      departamento: primera.departamento,
      municipio: primera.municipio,
      procesos: filas.fold(0, (total, e) => total + e.procesos),
      valorEstimado: filas.fold(0, (total, e) => total + e.valorEstimado),
      desde: desde.firstOrNull ?? '',
      hasta: hasta.lastOrNull ?? '',
    );
  }

  /// Procesos publicados por la entidad, del más reciente al más antiguo.
  static Future<List<Map<String, dynamic>>> procesosDeEntidad(
    EntidadSecopI entidad, {
    int limite = 200,
  }) async {
    final formas = Nit.formas(
      Nit.formasNumericas(entidad.nit).firstOrNull ?? '',
    );
    final filas = await DatosAbiertos.filas(SecopI.dataset, {
      r'$select':
          'numero_de_proceso,detalle_del_objeto_a_contratar,modalidad_de_contratacion,'
          'estado_del_proceso,cuantia_proceso,fecha_de_cargue_en_el_secop,'
          'numero_de_contrato,nom_razon_social_contratista,cuantia_contrato,'
          'fecha_de_firma_del_contrato,ruta_proceso_en_secop_i',
      r'$where': formas.isEmpty
          ? 'nombre_entidad = ${_literal(entidad.nombre)}'
          : 'nit_de_la_entidad in (${formas.map(_literal).join(',')})',
      r'$order': 'fecha_de_cargue_en_el_secop DESC, :id DESC',
      r'$limit': '$limite',
    }, timeout: const Duration(seconds: 15));
    return filas;
  }
}
