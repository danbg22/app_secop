import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/consent_service.dart';
import 'package:app_secop/utils/contract_financial_calculator.dart';

void main() {
  group('Ficha del contrato', () {
    test(
      'no muestra la dirección de residencia ni el género de la persona',
      () {
        final secciones = ContractFieldCatalog.buildSections({
          'proveedor_adjudicado': 'Persona de prueba',
          'documento_proveedor': '1000000000',
          'domicilio_representante_legal': 'Calle 1 # 2 - 3',
          'g_nero_representante_legal': 'Mujer',
          'sexo_replegal': 'F',
          'nacionalidad_representante_legal': 'Colombia',
        });
        final claves = {
          for (final s in secciones)
            for (final e in s.entries) e.key,
        };
        expect(claves, contains('proveedor_adjudicado'));
        expect(claves, contains('documento_proveedor'));
        expect(claves, isNot(contains('domicilio_representante_legal')));
        expect(claves, isNot(contains('g_nero_representante_legal')));
        expect(claves, isNot(contains('sexo_replegal')));
      },
    );
  });

  group('Política de datos', () {
    test('nombra la versión y los datos del contratista del enlace', () {
      expect(
        ConsentService.textoPolitica,
        startsWith('Versión ${ConsentService.versionPolitica}'),
      );
      for (final dato in [
        'cédula',
        'dirección',
        'celular',
        'número de cuenta',
        'SECOP',
        'SIGEP',
        'Superintendencia de Industria y Comercio',
      ]) {
        expect(ConsentService.textoPolitica, contains(dato));
      }
    });
  });
}
