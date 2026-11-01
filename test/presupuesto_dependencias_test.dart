import 'package:app_secop/services/presupuesto_dependencias_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Unidades de contratación de SECOP II', () {
    test('agrupa las variantes con que se escribe la misma dependencia', () {
      const s = PresupuestoDependenciasService.normalizarUnidad;
      expect(
        s('UNIDAD DE CONTRATACION DESPACHO REGIONAL ok'),
        'DESPACHO REGIONAL',
      );
      expect(
        s('UNIDAD DE CONTRATACIÓN DESPACHO REGIONAL'),
        'DESPACHO REGIONAL',
      );
      expect(
        s('UNIDAD DE CONTRATACION CAE***'),
        s('UNIDAD DE CONTRATACION CAE'),
      );
      expect(s('UNIDAD DE CONTRATACIÓN CBC..'), 'CBC');
      expect(s('UNIDAD DE CONTRATACION DEL CIGEC'), s('CIGEC'));
      expect(s('GERENCIA DE CONTRATACIÒN'), s('Gerencia de Contratación'));
      expect(s(''), 'SIN UNIDAD REGISTRADA');
    });

    test('muestra nombres legibles con tildes y siglas', () {
      const n = PresupuestoDependenciasService.nombreParaMostrar;
      expect(
        n('UNIDAD DE CONTRATACION DESPACHO REGIONAL ok'),
        'Despacho Regional',
      );
      expect(n('UNIDAD DE CONTRATACION DEL CIGEC'), 'CIGEC');
      expect(
        n('VICEPRESIDENCIA JURIDICA  GERENCIA DE CONTRATACIÒN'),
        'Vicepresidencia Juridica Gerencia de Contratación',
      );
      expect(
        n('Dirección Administrativa y Financiera'),
        'Dirección Administrativa y Financiera',
      );
    });
  });
}
