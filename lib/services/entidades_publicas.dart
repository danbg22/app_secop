import 'package:flutter/foundation.dart';

import '../data/colombia_entities_database.dart';
import '../utils/nit.dart';
import 'datos_abiertos.dart';

/// Reconoce a las entidades públicas que aparecen como contratistas (por
/// ejemplo el SENA en contratos o convenios interadministrativos).
///
/// Una persona jurídica es entidad pública si en el registro de cuentas de
/// SECOP II (4ex9-j3n8, "Contacto Entidades y Proveedores") su NIT figura con
/// `es_entidad = Si`, o si está en el catálogo de entidades de la app. No se
/// adivina por el nombre: "Sena - Unión Temporal…" es privada aunque empiece
/// por Sena.
class EntidadesPublicas {
  EntidadesPublicas._();

  static const String _cuentas = '4ex9-j3n8';

  /// NIT base (9 dígitos) → es entidad contratante. Se recuerda en la sesión.
  static final Map<String, bool> _conocidas = {};

  static final Set<String> _catalogo = {
    for (final e in ColombiaEntitiesDatabase.allEntities)
      e.nit.replaceAll(RegExp(r'[^0-9]'), ''),
  };

  /// NIT de 9 dígitos sin dígito de verificación, o null si [documento] no
  /// tiene forma de NIT (cédulas, documentos vacíos).
  static String? base(String documento) {
    final d = documento.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 9 && (d.startsWith('8') || d.startsWith('9'))) return d;
    if (d.length == 10 && (d.startsWith('8') || d.startsWith('9'))) {
      final b = d.substring(0, 9);
      if ('${Nit.digitoVerificacion(b)}' == d.substring(9)) return b;
    }
    return null;
  }

  /// Lo que ya se sabe de [documento] sin consultar: true o false si ya se
  /// verificó o está en el catálogo; null si falta consultarlo.
  static bool? conocida(String documento) {
    final b = base(documento);
    if (b == null) return false;
    if (_catalogo.contains(b)) return true;
    return _conocidas[b];
  }

  /// NIT base de los [documentos] que son entidades públicas. Consulta en
  /// SECOP II solo los que no se conocen, en una sola petición. Si SECOP no
  /// responde, devuelve lo que ya se sabía (nada se marca por error).
  static Future<Set<String>> verificar(Iterable<String> documentos) async {
    final bases = {for (final d in documentos) ?base(d)};
    final pendientes = [
      for (final b in bases)
        if (!_catalogo.contains(b) && !_conocidas.containsKey(b)) b,
    ].take(80).toList();
    if (pendientes.isNotEmpty) {
      try {
        // En este conjunto el NIT es texto, con y sin dígito de verificación.
        final formas = [
          for (final b in pendientes)
            for (final f in Nit.formasNumericas(b)) "'$f'",
        ];
        final filas = await DatosAbiertos.filas(_cuentas, {
          r'$select': 'nit_entidad',
          r'$where': "es_entidad='Si' AND nit_entidad in (${formas.join(',')})",
          r'$group': 'nit_entidad',
          r'$limit': '500',
        });
        final encontrados = {
          for (final f in filas) ?base('${f['nit_entidad'] ?? ''}'),
        };
        for (final b in pendientes) {
          _conocidas[b] = encontrados.contains(b);
        }
      } catch (e) {
        debugPrint('EntidadesPublicas.verificar: $e');
      }
    }
    return {
      for (final b in bases)
        if (_catalogo.contains(b) || _conocidas[b] == true) b,
    };
  }

  @visibleForTesting
  static void olvidar() => _conocidas.clear();
}
