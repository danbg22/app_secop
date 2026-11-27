import '../utils/nit.dart';
import 'datos_abiertos.dart';
import 'security_service.dart';

abstract final class TransparenciaEntidadService {
  static const archivo = 'fapy-smq9';
  static const sigep = 'h8rs-jxum';
  static const porPagina = 20;

  static String _nits(String nit) =>
      Nit.formas(Nit.formasNumericas(nit).firstOrNull ?? '')
          .map(_literal)
          .join(',');

  static String _literal(String valor) => "'${valor.replaceAll("'", "''")}'";

  static Future<({List<Map<String, dynamic>> filas, bool hayMas})> contratos(
    String nit, {
    required int pagina,
    String texto = '',
  }) async {
    final nits = _nits(nit);
    if (nits.isEmpty) {
      return (filas: const <Map<String, dynamic>>[], hayMas: false);
    }
    final busqueda = SecurityService.sanitizeSoqlToken(texto, maxLength: 100);
    final filas = await DatosAbiertos.filas(archivo, {
      r'$select':
          'numero_del_contrato,numero_de_proceso,tipo_de_contrato,'
          'estado_del_proceso,modalidad_de_contrataci_n,objeto_a_contratar,'
          'nom_raz_social_contratista,valor_contrato,fecha_de_firma_del_contrato,url_contrato',
      r'$where': 'nit_de_la_entidad in ($nits)',
      if (busqueda.isNotEmpty) r'$q': busqueda,
      r'$order': 'fecha_de_firma_del_contrato DESC NULLS LAST,:id DESC',
      r'$limit': '${porPagina + 1}',
      r'$offset': '${pagina * porPagina}',
    });
    return (
      filas: filas.take(porPagina).toList(),
      hayMas: filas.length > porPagina,
    );
  }

  static Future<List<Map<String, dynamic>>> personal(String nit) async {
    final nits = _nits(nit);
    if (nits.isEmpty) return const [];
    final filas = await DatosAbiertos.filas(sigep, {
      r'$select':
          'a_o,mes,tipo_de_vinculaci_n,genero_hombre,genero_mujer,'
          'genero_no_binario,salario_mensual_promedio',
      r'$where': 'nit in ($nits) AND a_o is not null AND mes is not null',
      r'$order': 'a_o DESC,mes DESC,:id DESC',
      r'$limit': '30',
    });
    if (filas.isEmpty) return filas;
    final reciente = filas.first;
    return filas
        .where(
          (f) => f['a_o'] == reciente['a_o'] && f['mes'] == reciente['mes'],
        )
        .toList();
  }
}
