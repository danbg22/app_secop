import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/procesos_secop_service.dart';

void main() {
  test('cada modalidad de SECOP II cae en un tipo de proceso', () {
    expect(
      ModalidadProceso.de('Licitación pública Obra Publica'),
      ModalidadProceso.licitacion,
    );
    expect(
      ModalidadProceso.de('selección abreviada subasta inversa'),
      ModalidadProceso.seleccionAbreviada,
    );
    expect(
      ModalidadProceso.de('Mínima cuantía'),
      ModalidadProceso.minimaCuantia,
    );
    expect(
      ModalidadProceso.de('Contratación Directa (con ofertas)'),
      ModalidadProceso.contratacionDirecta,
    );
    expect(
      ModalidadProceso.de('Contratación régimen especial (con ofertas)'),
      ModalidadProceso.regimenEspecial,
    );
    expect(ModalidadProceso.de('Subasta de prueba'), isNull);
  });

  test('el filtro arma una condición segura para SoQL', () {
    expect(ModalidadProceso.todas.condicion, isNull);
    expect(
      ModalidadProceso.minimaCuantia.condicion,
      "modalidad_de_contratacion in ('Mínima cuantía')",
    );
  });
}
