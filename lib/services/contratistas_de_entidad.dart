import '../utils/nit.dart';
import '../utils/secop_i.dart';
import 'busqueda_personas.dart';
import 'datos_abiertos.dart';

abstract final class ContratistasDeEntidad {
  static Future<ResultadoBusquedaPersonas> buscar(String nit) async {
    final formas = Nit.formasNumericas(nit);
    if (formas.isEmpty) {
      return const ResultadoBusquedaPersonas([], completo: true);
    }
    final fallidas = <FuentePersona>{};
    final personas = <String, PersonaEncontrada>{};

    Future<void> consultar({
      required FuentePersona fuente,
      required String conjunto,
      required String where,
      required String nombre,
      required String documento,
      required String tipo,
      required String valor,
      required String fecha,
    }) async {
      const tamano = 1000;
      try {
        for (var offset = 0; ; offset += tamano) {
          final datos = await DatosAbiertos.filas(conjunto, {
            r'$select':
                '$nombre as n,$documento as d,$tipo as t,count(*) as contratos,sum($valor) as total,max($fecha) as ultima',
            r'$where':
                "$where AND $nombre is not null AND upper($nombre) != 'NO DEFINIDO'",
            r'$group': '$nombre,$documento,$tipo',
            r'$order': '$nombre,$documento,$tipo',
            r'$limit': '$tamano',
            r'$offset': '$offset',
          }, timeout: const Duration(seconds: 20));
          for (final fila in datos) {
            final nombre = '${fila['n'] ?? ''}'.trim();
            if (nombre.isEmpty) continue;
            final tipo = '${fila['t'] ?? ''}';
            final doc = '${fila['d'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
            final baseNit = tipo.toUpperCase().contains('NIT')
                ? Nit.formasNumericas(doc).firstOrNull
                : null;
            final clave = doc.isEmpty
                ? 'NOMBRE:${BusquedaPersonas.normalizar(nombre)}'
                : 'DOC:${baseNit ?? doc}';
            final persona = personas.putIfAbsent(
              clave,
              () => PersonaEncontrada(
                nombre: nombre,
                documento: baseNit ?? doc,
                tipoDocumento: tipo,
                entidades: 1,
              ),
            );
            persona.contratos += int.tryParse('${fila['contratos']}') ?? 0;
            persona.valor += double.tryParse('${fila['total']}') ?? 0;
            final ultima = '${fila['ultima'] ?? ''}';
            if (ultima.compareTo(persona.ultimaFecha) > 0) {
              persona.ultimaFecha = ultima;
            }
            persona.fuentes.add(fuente);
          }
          if (datos.length < tamano) break;
        }
      } catch (_) {
        fallidas.add(fuente);
      }
    }

    final nitI = Nit.formas(nit).map((n) => "'$n'").join(',');
    await Future.wait([
      consultar(
        fuente: FuentePersona.secopII,
        conjunto: 'jbjy-vk9h',
        where: 'nit_entidad in (${formas.join(',')})',
        nombre: 'proveedor_adjudicado',
        documento: 'documento_proveedor',
        tipo: 'tipodocproveedor',
        valor: 'valor_del_contrato',
        fecha: 'fecha_de_firma',
      ),
      consultar(
        fuente: FuentePersona.secopI,
        conjunto: SecopI.dataset,
        where: 'nit_de_la_entidad in ($nitI) AND ${SecopI.filtroContratos}',
        nombre: 'nom_razon_social_contratista',
        documento: 'identificacion_del_contratista',
        tipo: 'tipo_identifi_del_contratista',
        valor: 'cuantia_contrato',
        fecha: 'fecha_de_firma_del_contrato',
      ),
    ]);
    return ResultadoBusquedaPersonas(
      personas.values.toList(),
      fuentesFallidas: fallidas,
      completo: true,
    );
  }
}
