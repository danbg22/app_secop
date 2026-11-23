import 'dart:convert';

import 'package:app_secop/services/datos_abiertos.dart';
import 'package:app_secop/services/expediente_contrato_service.dart';
import 'package:app_secop/services/reporte_seleccion_contratos.dart';
import 'package:app_secop/services/secop_document_intelligence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(DatosAbiertos.limpiarCache);
  tearDown(() => DatosAbiertos.clientePruebas = null);

  test(
    'la ficha completa conserva objetos largos y campos del expediente',
    () async {
      final objeto = List.filled(90, 'Objeto contractual íntegro').join(' ');
      DatosAbiertos.clientePruebas = MockClient((solicitud) async {
        expect(solicitud.url.path, endsWith('/jbjy-vk9h.json'));
        expect(
          solicitud.url.queryParameters[r'$where'],
          "id_contrato='CO1.PCCNTR.412'",
        );
        expect(solicitud.url.queryParameters, isNot(contains(r'$select')));
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {'objeto_del_contrato': objeto, 'valor_pagado': '5000'},
            ]),
          ),
          200,
        );
      });
      final resultado = await ExpedienteContratoService.consultar({
        'id_contrato': 'CO1.PCCNTR.412',
        'objeto_del_contrato': 'Objeto abreviado',
      });
      expect(resultado?['objeto_del_contrato'], objeto);
      expect(resultado?['valor_pagado'], '5000');
    },
  );

  test('la ficha no mezcla contratos que tienen la misma referencia', () async {
    DatosAbiertos.clientePruebas = MockClient((solicitud) async {
      expect(
        solicitud.url.queryParameters[r'$where'],
        contains("nit_entidad='800000000'"),
      );
      return http.Response(
        '[{"id_contrato":"uno"},{"id_contrato":"dos"}]',
        200,
      );
    });
    expect(
      await ExpedienteContratoService.consultar({
        'referencia_del_contrato': 'PS-2026',
        'nit_entidad': '800000000',
      }),
      isNull,
    );
  });

  test(
    'el PDF dedica una ficha a cada contrato y pagina objetos largos',
    () async {
      final objetoLargo = List.generate(
        460,
        (i) =>
            'Actividad ${i + 1} de mantenimiento y seguimiento en la entidad.',
      ).join(' ');
      final pdf = await ReporteSeleccionContratos.generar([
        ContratoDelReporte(
          datos: {
            'id_contrato': 'CO1.PCCNTR.100',
            'referencia_del_contrato': 'SALUD-2026-100',
            'nombre_entidad': 'Hospital Regional',
            'objeto_del_contrato': objetoLargo,
            'valor_del_contrato': '156000000',
            'fecha_de_inicio_del_contrato': '2026-04-01',
            'fecha_de_fin_del_contrato': '2026-10-01',
            'valor_pagado': '31000000',
          },
          expedienteCompleto: true,
          documentos: const SecopExtractionResult(
            status: SecopExtractionStatus.emptyOfficialList,
            documents: [],
            resolvedSecopUrl: 'https://community.secop.gov.co/',
          ),
        ),
        const ContratoDelReporte(
          datos: {
            'id_contrato': 'CO1.PCCNTR.200',
            'referencia_del_contrato': 'EDU-2026-200',
            'nombre_entidad': 'Municipio',
            'objeto_del_contrato': 'Contrato de educación',
          },
          expedienteCompleto: false,
          documentos: null,
        ),
      ], ahora: DateTime.utc(2026, 11, 23));

      final lectura = latin1.decode(pdf);
      expect(lectura, startsWith('%PDF-'));
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(lectura).length,
        greaterThan(3),
      );
      expect(lectura, contains('https://community.secop.gov.co/'));
    },
  );
}
