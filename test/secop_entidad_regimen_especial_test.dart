import 'dart:convert';

import 'package:app_secop/data/colombia_entities_database.dart';
import 'package:app_secop/services/contratistas_de_entidad.dart';
import 'package:app_secop/services/datos_abiertos.dart';
import 'package:app_secop/services/procesos_secop_service.dart';
import 'package:app_secop/services/transparencia_entidad_service.dart';
import 'package:app_secop/utils/secop_i.dart';
import 'package:app_secop/utils/nit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response filas(List<Map<String, String>> datos) =>
    http.Response.bytes(utf8.encode(jsonEncode(datos)), 200);

void main() {
  tearDown(() {
    DatosAbiertos.clientePruebas = null;
    DatosAbiertos.limpiarCache();
  });

  test(
    'Emdupar y su NIT consultan al comprador en Procesos SECOP II',
    () async {
      expect(
        ColombiaEntitiesDatabase.entidadExacta('Emdupar')?.nit,
        '892300548',
      );
      expect(
        ColombiaEntitiesDatabase.entidadExacta('892.300.548')?.nit,
        '892300548',
      );
      DatosAbiertos.clientePruebas = MockClient((solicitud) async {
        final condicion = solicitud.url.queryParameters[r'$where'] ?? '';
        expect(condicion, contains("nit_entidad in ('892300548'"));
        expect(solicitud.url.queryParameters.containsKey(r'$q'), isFalse);
        if (condicion.contains(' is null')) return filas([]);
        return filas([
          {
            'referencia_del_proceso': 'IPS-40-2025',
            'nombre_del_procedimiento': 'Compra de insumos',
            'entidad': 'EMPRESA DE SERVICIOS PUBLICOS DE VALLEDUPAR',
            'nit_entidad': '892300548',
            'fecha_de_publicacion_del': '2025-03-02T00:00:00',
          },
        ]);
      });
      final pagina = await ProcesosSecopService.buscarPagina(
        texto: '892.300.548',
        campo: CampoBusquedaProceso.entidad,
      );
      expect(pagina.procesos.single.referencia, 'IPS-40-2025');
    },
  );

  test(
    'Contratistas combina proveedores del comprador en SECOP I y II',
    () async {
      DatosAbiertos.clientePruebas = MockClient((solicitud) async {
        final condicion = solicitud.url.queryParameters[r'$where'] ?? '';
        final fuenteI = solicitud.url.path.contains(SecopI.dataset);
        expect(
          condicion,
          contains(fuenteI ? 'nit_de_la_entidad' : 'nit_entidad'),
        );
        expect(condicion, contains('892300548'));
        if (fuenteI) expect(condicion, contains(SecopI.filtroContratos));
        return filas([
          {
            'n': 'Proveedor A',
            'd': '901234567',
            't': 'NIT',
            'contratos': '2',
            'total': '400',
            'ultima': '2025-01-01',
          },
          if (fuenteI)
            {
              'n': 'Proveedor B',
              'd': '1000123456',
              't': 'CC',
              'contratos': '1',
              'total': '800',
            },
        ]);
      });
      final dv = Nit.digitoVerificacion('892300548');
      final resultados = await ContratistasDeEntidad.buscar('892.300.548-$dv');
      expect(resultados.parcial, isFalse);
      expect(resultados.personas.length, 2);
      final proveedor = resultados.personas.firstWhere(
        (p) => p.nombre == 'Proveedor A',
      );
      expect(proveedor.contratos, 4);
      expect(proveedor.valor, 800);
      expect(proveedor.fuentes.length, 2);
    },
  );

  test('el archivo de contratación pagina por NIT y SIGEP conserva el mes más reciente', () async {
    DatosAbiertos.clientePruebas = MockClient((solicitud) async {
      final params = solicitud.url.queryParameters;
      expect(params[r'$where'], contains("'892300548'"));
      if (solicitud.url.path.contains(TransparenciaEntidadService.sigep)) {
        expect(params[r'$order'], startsWith('a_o DESC,mes DESC'));
        return filas([
          {'a_o': '2026', 'mes': '9', 'tipo_de_vinculaci_n': 'VINCULADAS'},
          {'a_o': '2026', 'mes': '9', 'tipo_de_vinculaci_n': 'CONTRATISTAS'},
          {'a_o': '2026', 'mes': '8', 'tipo_de_vinculaci_n': 'VINCULADAS'},
        ]);
      }
      expect(params[r'$q'], 'Acueducto');
      expect(params[r'$offset'], '${TransparenciaEntidadService.porPagina}');
      expect(params[r'$order'], endsWith(':id DESC'));
      return filas(
        List.generate(
          TransparenciaEntidadService.porPagina + 1,
          (i) => {'numero_del_contrato': 'Contrato $i'},
        ),
      );
    });
    final contratos = await TransparenciaEntidadService.contratos(
      '892300548',
      pagina: 1,
      texto: 'Acueducto',
    );
    expect(contratos.hayMas, isTrue);
    expect(contratos.filas.length, TransparenciaEntidadService.porPagina);
    final personal = await TransparenciaEntidadService.personal('892300548');
    expect(personal.length, 2);
    expect(personal.every((fila) => fila['mes'] == '9'), isTrue);
  });
}
