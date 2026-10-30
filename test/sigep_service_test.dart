import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/sigep_service.dart';

void main() {
  test('nombreCompleto arma el nombre de las declaraciones sin "NULL"', () {
    expect(
      SigepService.nombreCompleto({
        'primer_nombre_declarante': 'CARLOS',
        'segundo_nombre_declarante': 'NULL',
        'primer_apellido_declarante': 'GOMEZ',
        'segundo_apellido_declarante': 'JAIMES',
      }),
      'CARLOS GOMEZ JAIMES',
    );
  });

  test('nombreCompleto usa nombre_pep en el dataset PEP', () {
    expect(
      SigepService.nombreCompleto({'nombre_pep': 'JUAN CARLOS CORTES GOMEZ'}),
      'JUAN CARLOS CORTES GOMEZ',
    );
  });
}
