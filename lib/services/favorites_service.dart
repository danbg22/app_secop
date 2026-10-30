import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Favoritos locales (contratos y perfiles de contratistas) aislados por
/// usuario para que no se compartan entre cuentas en el mismo navegador.
class FavoritesService {
  static const String _legacyContratosKey = 'contratos_favoritos';
  static const String _legacyContratistasKey = 'favoritos_contratistas';

  /// Identificador único de un contrato. Un mismo proceso de compra puede
  /// tener varios contratos, por eso se prioriza `id_contrato`.
  static String idContrato(dynamic contrato) {
    if (contrato is! Map) return '';
    String v(String key) => (contrato[key] ?? '').toString().trim();

    final id = v('id_contrato');
    if (id.isNotEmpty) return id;
    final proceso = v('proceso_de_compra');
    final referencia = v('referencia_del_contrato');
    if (proceso.isNotEmpty || referencia.isNotEmpty) {
      return '$proceso|$referencia|${v('documento_proveedor')}';
    }
    return '${v('nombre_entidad')}|${v('descripcion_del_proceso')}';
  }

  // ---------------------------------------------------------------------------
  // Contratos
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> contratos() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodificar(await _leer(prefs, _legacyContratosKey));
  }

  static Future<Set<String>> idsContratos() async {
    final lista = await contratos();
    return lista.map(idContrato).where((id) => id.isNotEmpty).toSet();
  }

  /// Agrega o quita el contrato. Devuelve `true` si quedó guardado.
  static Future<bool> alternarContrato(Map contrato) async {
    final prefs = await SharedPreferences.getInstance();
    final id = idContrato(contrato);
    final lista = await _leer(prefs, _legacyContratosKey);
    final antes = lista.length;
    lista.removeWhere((raw) => idContrato(_decodificarUno(raw)) == id);
    final guardado = lista.length == antes;
    if (guardado) lista.add(json.encode(contrato));
    await prefs.setStringList(_scopedKey(_legacyContratosKey), lista);
    return guardado;
  }

  static Future<void> eliminarContrato(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await _leer(prefs, _legacyContratosKey)
      ..removeWhere((raw) => idContrato(_decodificarUno(raw)) == id);
    await prefs.setStringList(_scopedKey(_legacyContratosKey), lista);
  }

  // ---------------------------------------------------------------------------
  // Perfiles de contratistas
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> contratistas() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodificar(await _leer(prefs, _legacyContratistasKey));
  }

  static Future<bool> esContratistaFavorito(String id) async {
    final lista = await contratistas();
    return lista.any((p) => p['id']?.toString() == id);
  }

  /// Agrega o quita el perfil. Devuelve `true` si quedó guardado.
  static Future<bool> alternarContratista({
    required String id,
    required String nombre,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await _leer(prefs, _legacyContratistasKey);
    final antes = lista.length;
    lista.removeWhere((raw) => _decodificarUno(raw)?['id']?.toString() == id);
    final guardado = lista.length == antes;
    if (guardado) lista.add(json.encode({'id': id, 'nombre': nombre}));
    await prefs.setStringList(_scopedKey(_legacyContratistasKey), lista);
    return guardado;
  }

  static Future<void> eliminarContratista(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await _leer(prefs, _legacyContratistasKey)
      ..removeWhere((raw) => _decodificarUno(raw)?['id']?.toString() == id);
    await prefs.setStringList(_scopedKey(_legacyContratistasKey), lista);
  }

  // ---------------------------------------------------------------------------
  // Almacenamiento
  // ---------------------------------------------------------------------------

  static String _scopedKey(String legacyKey) =>
      '${legacyKey}_${AuthService.getActiveUserStorageScope()}';

  /// Lee la lista del usuario activo. La primera vez traslada al usuario los
  /// favoritos guardados con la clave global anterior (sin aislamiento).
  static Future<List<String>> _leer(
    SharedPreferences prefs,
    String legacyKey,
  ) async {
    final scoped = _scopedKey(legacyKey);
    final actual = prefs.getStringList(scoped);
    if (actual != null) return List<String>.of(actual);

    final legado = prefs.getStringList(legacyKey);
    if (legado == null || scoped.endsWith('_anon')) return <String>[];
    await prefs.setStringList(scoped, legado);
    await prefs.remove(legacyKey);
    return List<String>.of(legado);
  }

  static Map<String, dynamic>? _decodificarUno(String raw) {
    try {
      final decoded = json.decode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _decodificar(List<String> lista) =>
      lista.map(_decodificarUno).whereType<Map<String, dynamic>>().toList();
}
