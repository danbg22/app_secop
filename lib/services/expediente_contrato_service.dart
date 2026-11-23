import '../utils/secop_i.dart';
import 'datos_abiertos.dart';

abstract final class ExpedienteContratoService {
  static bool esSecopI(Map<String, dynamic> contrato) =>
      contrato.containsKey('ruta_proceso_en_secop_i') ||
      contrato.containsKey('nom_razon_social_contratista') ||
      contrato.containsKey('numero_de_constancia') ||
      (contrato.containsKey('uid') && !contrato.containsKey('id_contrato'));

  static String _literal(Object? valor) {
    final texto = (valor ?? '').toString().trim();
    if (texto.length > 180 || texto.toLowerCase() == 'no definido') return '';
    return texto.replaceAll("'", "''");
  }

  /// Devuelve null si el identificador no basta para reconocer una sola fila.
  /// Los errores de la fuente se propagan para distinguirlos de un dato ausente.
  static Future<Map<String, dynamic>?> consultar(
    Map<String, dynamic> contrato,
  ) async {
    final secopI = esSecopI(contrato);
    final c = SecopI.normalizar(contrato);
    final clausulas = <String>[];

    if (secopI) {
      final uid = _literal(c['uid']);
      final constancia = _literal(c['numero_de_constancia']);
      final numero = _literal(c['numero_de_contrato']);
      final nit = _literal(c['nit_de_la_entidad'] ?? c['nit_entidad']);
      if (uid.isNotEmpty) {
        clausulas.add("uid='$uid'");
      } else if (constancia.isNotEmpty) {
        clausulas.add("numero_de_constancia='$constancia'");
        if (numero.isNotEmpty) clausulas.add("numero_de_contrato='$numero'");
      } else if (numero.isNotEmpty && nit.isNotEmpty) {
        clausulas.addAll([
          "numero_de_contrato='$numero'",
          "nit_de_la_entidad='$nit'",
        ]);
      }
    } else {
      final id = _literal(c['id_contrato']);
      final referencia = _literal(c['referencia_del_contrato']);
      final nit = _literal(c['nit_entidad']);
      final proceso = _literal(c['proceso_de_compra']);
      final proveedor = _literal(c['documento_proveedor']);
      if (id.isNotEmpty) {
        clausulas.add("id_contrato='$id'");
      } else if (referencia.isNotEmpty && nit.isNotEmpty) {
        clausulas.addAll([
          "referencia_del_contrato='$referencia'",
          "nit_entidad='$nit'",
        ]);
        if (proveedor.isNotEmpty) {
          clausulas.add("documento_proveedor='$proveedor'");
        }
      } else if (proceso.isNotEmpty && proveedor.isNotEmpty) {
        clausulas.addAll([
          "proceso_de_compra='$proceso'",
          "documento_proveedor='$proveedor'",
        ]);
      }
    }

    if (clausulas.isEmpty) return null;
    final filas = await DatosAbiertos.filas(
      secopI ? SecopI.dataset : 'jbjy-vk9h',
      {r'$where': clausulas.join(' AND '), r'$limit': '2'},
    );
    if (filas.length != 1) return null;
    final mezcla = {...c};
    for (final MapEntry(:key, :value) in filas.single.entries) {
      final texto = (value ?? '').toString().trim();
      if ((texto.isNotEmpty && texto.toLowerCase() != 'no definido') ||
          !mezcla.containsKey(key)) {
        mezcla[key] = value;
      }
    }
    return SecopI.normalizar(mezcla);
  }
}
