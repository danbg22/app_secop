import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/secop_i_procesos_service.dart';

void main() {
  test('EntidadSecopI interpreta el agregado de SECOP I', () {
    final e = EntidadSecopI.fromMap({
      'nombre_entidad': 'BOLÍVAR - UNIVERSIDAD DE CARTAGENA DE INDIAS',
      'nit_de_la_entidad': 'No Definido',
      'procesos': '2007',
      'valor': '300546618816',
      'desde': '2018',
      'hasta': '2022',
    });
    expect(e.nit, isEmpty);
    expect(e.procesos, 2007);
    expect(e.valorEstimado, 300546618816);
    expect(e.periodo, '2018 – 2022');
  });

  test('el periodo de un solo año no se repite', () {
    final e = EntidadSecopI.fromMap({'desde': '2022', 'hasta': '2022'});
    expect(e.periodo, '2022');
  });
}
