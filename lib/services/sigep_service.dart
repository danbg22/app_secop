import 'datos_abiertos.dart';
import 'security_service.dart';

class SigepService {
  /// Datasets de Datos Abiertos que identifican al servidor público con
  /// nombre y número de documento: declaraciones de bienes y rentas (Ley
  /// 2013 de 2019) y Personas Expuestas Políticamente (PEP), con el filtro
  /// propio de cada uno.
  ///
  /// En las declaraciones la gran mayoría de quienes declaran son
  /// contratistas (`declarante_es_contratista = 'SI'`, unos 307.000 de
  /// 329.000 registros): solo los demás son servidores públicos.
  static const Map<String, Map<String, String>> _datasets = {
    '8tz7-h3eu': {'declarante_es_contratista': 'NO'},
    '3qxn-uc22': {},
  };

  /// Nombre completo del registro, sea del dataset de declaraciones
  /// (nombres y apellidos separados) o del de PEP (`nombre_pep`).
  static String nombreCompleto(Map<String, dynamic> registro) {
    final pep = (registro['nombre_pep'] ?? '').toString().trim();
    if (pep.isNotEmpty) return pep;
    return [
      'primer_nombre_declarante',
      'segundo_nombre_declarante',
      'primer_apellido_declarante',
      'segundo_apellido_declarante',
    ]
        .map((k) => (registro[k] ?? '').toString().trim())
        .where((p) => p.isNotEmpty && p.toUpperCase() != 'NULL')
        .join(' ');
  }

  static String _normalizarNombre(String texto) => texto
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll(RegExp(r'[^A-ZÑ ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Indica si la persona figura como servidor público. Con [documento] la
  /// verificación es exacta por cédula; sin él solo se acepta una
  /// coincidencia exacta del nombre completo, para no confundir homónimos
  /// parciales (p. ej. "Juan Carlos Gómez" con "Juan Carlos Castañeda Gómez").
  static Future<Map<String, dynamic>?> verificarServidorPublico(
    String nombre, {
    String? documento,
  }) async {
    final doc = (documento ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (doc.length >= 5) {
      final porDocumento = await _consultar({'numero_documento': doc});
      return porDocumento.isEmpty ? null : porDocumento.first;
    }

    final objetivo = _normalizarNombre(nombre);
    if (objetivo.split(' ').length < 2) return null;
    final candidatos = await buscarListaServidores(nombre);
    for (final registro in candidatos) {
      if (_normalizarNombre(nombreCompleto(registro)) == objetivo) {
        return registro;
      }
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> buscarListaServidores(
    String query,
  ) async {
    final sanitizedQuery = SecurityService.sanitizeSoqlToken(
      query,
      maxLength: 100,
    );
    if (sanitizedQuery.isEmpty) return [];
    return _consultar({r'$q': sanitizedQuery, r'$limit': '1000'});
  }

  static Future<List<Map<String, dynamic>>> _consultar(
    Map<String, String> params,
  ) async {
    final respuestas = await Future.wait(
      _datasets.entries.map(
        (d) => DatosAbiertos.filas(
          d.key,
          {...params, ...d.value},
          timeout: const Duration(seconds: 8),
        ).catchError((Object _) => <Map<String, dynamic>>[]),
      ),
    );
    return [for (final r in respuestas) ...r];
  }
}
