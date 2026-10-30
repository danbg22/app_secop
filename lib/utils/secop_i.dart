import 'anios_secop.dart';

/// Dataset "SECOP I - Procesos de Compra Pública" (`f789-7hwg`) y su
/// homologación a los nombres de columna de SECOP II (`jbjy-vk9h`).
class SecopI {
  static const String dataset = 'f789-7hwg';

  /// Filtro por año de firma. `anno_firma_contrato` es texto e incluye
  /// "Sin Firma" y años inválidos (2099...), por eso se usa un rango cerrado.
  static String filtroAnio([String? anio]) {
    if (anio != null && RegExp(r'^\d{4}$').hasMatch(anio)) {
      return "(anno_firma_contrato = '$anio' OR anno_cargue_secop = '$anio')";
    }
    return "anno_firma_contrato >= '${AniosSecop.primero}' AND "
        "anno_firma_contrato <= '${AniosSecop.actual}'";
  }

  static bool _vacio(dynamic v) {
    if (v == null) return true;
    final s = v.toString().trim();
    return s.isEmpty || s.toLowerCase() == 'no definido';
  }

  /// Copia del registro con las claves de SECOP II completadas a partir de
  /// las columnas de SECOP I. No sobrescribe valores ya presentes.
  static Map<String, dynamic> normalizar(Map raw) {
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    void alias(String destino, List<String> origenes) {
      if (!_vacio(m[destino])) return;
      for (final origen in origenes) {
        if (!_vacio(m[origen])) {
          m[destino] = m[origen];
          return;
        }
      }
    }

    alias('id_contrato', ['uid', 'numero_de_constancia']);
    alias('proceso_de_compra', ['numero_de_proceso', 'numero_de_constancia']);
    alias('referencia_del_contrato', ['numero_de_contrato', 'numero_de_proceso']);
    alias('proveedor_adjudicado', ['nom_razon_social_contratista']);
    alias('documento_proveedor', ['identificacion_del_contratista']);
    alias('tipodocproveedor', ['tipo_identifi_del_contratista']);
    alias('valor_del_contrato', ['cuantia_contrato']);
    alias('fecha_de_firma', ['fecha_de_firma_del_contrato', 'fecha_ini_ejec_contrato']);
    alias('fecha_de_inicio_del_contrato', ['fecha_ini_ejec_contrato', 'fecha_de_firma_del_contrato']);
    alias('fecha_de_fin_del_contrato', ['fecha_fin_ejec_contrato']);
    alias('nit_entidad', ['nit_de_la_entidad']);
    alias('descripcion_del_proceso', ['detalle_del_objeto_a_contratar', 'objeto_a_contratar']);
    alias('objeto_del_contrato', ['objeto_a_contratar', 'detalle_del_objeto_a_contratar']);
    alias('estado_contrato', ['estado_del_proceso']);
    alias('departamento', ['departamento_entidad']);
    alias('ciudad', ['municipio_entidad']);
    alias('orden', ['orden_entidad', 'nivel_entidad']);
    alias('urlproceso', ['ruta_proceso_en_secop_i']);
    return m;
  }
}
