import 'dart:convert';

import '../utils/nit.dart';
import '../utils/secop_i.dart';
import 'busqueda_personas.dart';
import 'datos_abiertos.dart';
import 'favorites_service.dart';

abstract final class HistorialContratistaService {
  static const String _camposHistorial =
      'id_contrato,referencia_del_contrato,proceso_de_compra,nombre_entidad,'
      'nit_entidad,orden,departamento,ciudad,sector,estado_contrato,'
      'modalidad_de_contratacion,tipo_de_contrato,valor_del_contrato,'
      'proveedor_adjudicado,tipodocproveedor,documento_proveedor,'
      'fecha_de_firma,fecha_de_inicio_del_contrato,fecha_de_fin_del_contrato,'
      'objeto_del_contrato,descripcion_del_proceso,urlproceso';

  static Future<({List<Map<String, dynamic>> contratos, bool parcial})>
  consultar({required String nombre, required String documento}) async {
    final allContracts = <Map<String, dynamic>>[];
    var parcial = false;
    final Set<String> seenContractIds = {};

    // Un proceso de compra puede tener varios contratos con el mismo
    // proveedor, por eso se deduplica por el identificador del contrato.
    void addContractIfNew(Map<String, dynamic> c) {
      final id = FavoritesService.idContrato(c);
      if (seenContractIds.add(id.isNotEmpty ? id : jsonEncode(c))) {
        allContracts.add(c);
      }
    }

    Future<List<Map<String, dynamic>>> consultar(
      String dataset,
      Map<String, String> params,
    ) async {
      try {
        return await DatosAbiertos.filas(
          dataset,
          params,
          timeout: const Duration(seconds: 12),
        );
      } catch (_) {
        parcial = true;
        return const [];
      }
    }

    final cleanDoc = documento.replaceAll(RegExp(r'[^0-9]'), '').trim();

    // Las consultas son independientes: SECOP II por documento (índice
    // B-tree) y por nombre exacto, y SECOP I, en paralelo. Solo se piden
    // las columnas que usa la vista (todas pesaban ~3 veces más: 16,7 MB
    // para un contratista con 4.000 contratos) y la consulta por nombre
    // excluye lo que ya trae la del documento.
    // Un NIT de empresa (9 o 10 dígitos que empiezan por 8 o 9) puede
    // estar guardado con o sin dígito de verificación; una cédula se busca
    // tal cual (ampliarla confundiría personas).
    final esNitEmpresa = RegExp(r'^[89]\d{8,9}$').hasMatch(cleanDoc);
    final formasDoc = esNitEmpresa
        ? Nit.formasNumericas(cleanDoc)
        : <String>[cleanDoc];
    final listaDoc = formasDoc.map((f) => "'$f'").join(',');
    final consultasSecopII = <Future<List<Map<String, dynamic>>>>[
      if (cleanDoc.length >= 5)
        consultar('jbjy-vk9h', {
          r'$select': _camposHistorial,
          r'$where': 'documento_proveedor in ($listaDoc)',
          r'$order': 'fecha_de_firma DESC',
          r'$limit': '50000',
        }),
      if (nombre.isNotEmpty)
        consultar('jbjy-vk9h', {
          r'$select': _camposHistorial,
          'proveedor_adjudicado': nombre,
          if (cleanDoc.length >= 5)
            r'$where': 'documento_proveedor not in ($listaDoc)',
          r'$order': 'fecha_de_firma DESC',
          r'$limit': '50000',
        }),
    ];
    final consultaSecopI = cleanDoc.length >= 5
        ? consultar(SecopI.dataset, {
            'identificacion_del_contratista': cleanDoc,
            r'$where': SecopI.filtroAnio(),
            r'$order': 'fecha_de_firma_del_contrato DESC',
            r'$limit': '2000',
          })
        : nombre.isNotEmpty
        ? consultar(SecopI.dataset, {
            'nom_razon_social_contratista': nombre,
            r'$where': SecopI.filtroAnio(),
            r'$order': 'fecha_de_firma_del_contrato DESC',
            r'$limit': '2000',
          })
        : Future.value(const <Map<String, dynamic>>[]);

    final resultados = await Future.wait([...consultasSecopII, consultaSecopI]);
    for (final lista in resultados.take(consultasSecopII.length)) {
      lista.forEach(addContractIfNew);
    }

    // Si SECOP II no encontró nada por documento ni por nombre exacto:
    // todas las palabras del nombre, en cualquier orden y sin importar
    // tildes, con el índice de texto completo (un LIKE por palabra sin
    // índice tardaba segundos o se agotaba).
    if (allContracts.isEmpty && nombre.isNotEmpty) {
      final palabras = BusquedaPersonas.tokens(nombre);
      final q = BusquedaPersonas.textoCompleto(palabras);
      if (q.isNotEmpty) {
        final porPalabras = await consultar('jbjy-vk9h', {
          r'$select': _camposHistorial,
          r'$q': q,
          r'$where': BusquedaPersonas.whereTodasLasPalabras(
            'proveedor_adjudicado',
            palabras,
          ),
          r'$limit': '2000',
        });
        for (final c in porPalabras) {
          if (BusquedaPersonas.nombreCoincide(
            '${c['proveedor_adjudicado'] ?? ''}',
            palabras,
          )) {
            addContractIfNew(c);
          }
        }
      }
    }

    for (final raw in resultados.last) {
      addContractIfNew(SecopI.normalizar(raw));
    }

    // Ordenar contratos consolidados cronológicamente (más recientes primero)
    allContracts.sort((a, b) {
      String fecha(Map<String, dynamic> c) =>
          (c['fecha_de_firma'] ?? c['fecha_de_inicio_del_contrato'] ?? '')
              .toString();
      return fecha(b).compareTo(fecha(a));
    });
    return (contratos: allContracts, parcial: parcial);
  }
}
