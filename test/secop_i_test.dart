import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/utils/anios_secop.dart';
import 'package:app_secop/utils/secop_i.dart';

void main() {
  test('normalizar homologa las columnas reales de SECOP I', () {
    final m = SecopI.normalizar({
      'uid': '18-4-7495680-7097966',
      'numero_de_contrato': '177 DE 2018',
      'nom_razon_social_contratista': 'LUZ YAMILE PERAZA NOVOA',
      'identificacion_del_contratista': '52335431',
      'cuantia_contrato': '7800000',
      'fecha_de_firma_del_contrato': '2018-01-01T00:00:00.000',
      'ruta_proceso_en_secop_i': {
        'url': 'https://www.contratos.gov.co/consultas/detalleProceso.do',
      },
    });
    expect(m['id_contrato'], '18-4-7495680-7097966');
    expect(m['referencia_del_contrato'], '177 DE 2018');
    expect(m['proveedor_adjudicado'], 'LUZ YAMILE PERAZA NOVOA');
    expect(m['documento_proveedor'], '52335431');
    expect(m['valor_del_contrato'], '7800000');
    expect(m['fecha_de_firma'], '2018-01-01T00:00:00.000');
    expect(m['urlproceso'], isA<Map>());
  });

  test('normalizar no sobrescribe valores existentes', () {
    final m = SecopI.normalizar({
      'proveedor_adjudicado': 'ORIGINAL',
      'nom_razon_social_contratista': 'OTRO',
    });
    expect(m['proveedor_adjudicado'], 'ORIGINAL');
  });

  test('filtroAnio usa un rango cerrado para excluir "Sin Firma"', () {
    expect(
      SecopI.filtroAnio(),
      "anno_firma_contrato >= '2015' AND "
      "anno_firma_contrato <= '${AniosSecop.actual}'",
    );
    expect(SecopI.filtroAnio('2018'), contains("anno_firma_contrato = '2018'"));
    expect(SecopI.filtroAnio('abc'), startsWith('anno_firma_contrato >='));
  });
}
