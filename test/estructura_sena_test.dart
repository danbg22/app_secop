import 'package:app_secop/data/estructura_sena.dart';
import 'package:flutter_test/flutter_test.dart';

UbicacionSena ubicar(String cuenta, String unidad, [String depto = '']) =>
    EstructuraSena.ubicar(cuenta: cuenta, unidad: unidad, departamento: depto);

void main() {
  const cesar = 'SENA REGIONAL CESAR Grupo de Apoyo Administrativo Mixto';

  test('la Regional Cesar: despacho y sus tres centros', () {
    final despacho = ubicar(
      cesar,
      'UNIDAD DE CONTRATACION DESPACHO REGIONAL ok',
    );
    expect(despacho.nivel, NivelSena.despachoRegional);
    expect(despacho.regional?.nombre, 'Cesar');
    expect(
      ubicar(cesar, 'UNIDAD DE CONTRATACIÓN CBC..').nodo,
      'Centro Biotecnológico del Caribe',
    );
    expect(
      ubicar(cesar, 'UNIDAD DE CONTRATACION CAE***').nodo,
      'Centro Agroempresarial',
    );
    // COMM hasta 2024 y CIGEC desde 2025: el mismo centro.
    expect(
      ubicar(cesar, 'CIGEC').nodo,
      ubicar(cesar, 'UNIDAD DE CONTRATACIÓN COMM').nodo,
    );
    expect(
      ubicar(cesar, 'CONTRATACIÓN MÍNIMA CUANTÍA BIENES Y SERVICIOS').nivel,
      NivelSena.regionalSinDistinguir,
    );
  });

  test('Dirección General: sus dependencias nacionales', () {
    final u = ubicar(
      'SENA SECRETARIA GENERAL',
      'UNIDAD DE CONTRATACIÓN SISTEMA NACIONAL DE FORMACIÓN PARA EL TRABAJO',
    );
    expect(u.nivel, NivelSena.nacional);
    expect(
      u.nodo,
      'Dirección del Sistema Nacional de Formación para el Trabajo',
    );
    expect(
      ubicar('SENA DIRECCION GENERAL', 'Dirección Jurídica').nodo,
      'Dirección Jurídica',
    );
    expect(
      ubicar(
        'SENA SECRETARIA GENERAL',
        'UNIDAD DE CONTRATACIÓN OFICINA DE CONTROL INTERNO',
      ).nodo,
      'Oficina de Control Interno',
    );
  });

  test('cuentas sin regional en el nombre van a la del centro', () {
    // Cazucá está en Soacha, pero sus centros son del Distrito Capital.
    final u = ubicar(
      'SENA GRUPO DE APOYO ADMINISTRATIVO INTERCENTROS CAZUCA',
      'CENTRO DE TECNOLOGÍAS DEL TRANSPORTE - CTT',
      'Cundinamarca',
    );
    expect(u.regional?.nombre, 'Distrito Capital');
    expect(u.nivel, NivelSena.centro);
    expect(
      ubicar(
        'Sena - Centro Agropecuario de Buga',
        'ServiciosPersonales',
      ).regional?.nombre,
      'Valle',
    );
  });

  test('Norte de Santander no se confunde con Santander', () {
    final u = ubicar(
      'SENA REGIONAL NORTE DE SANTANDER Grupo de Apoyo Administrativo Mixto',
      'CENTRO DESARROLLO RURAL Y MINERO- CEDRUM',
    );
    expect(u.regional?.nombre, 'Norte de Santander');
    expect(u.nodo, 'Centro de Formación para el Desarrollo Rural y Minero');
  });

  test('una cuenta intercentros reparte por la unidad', () {
    const cuenta =
        'SENA REGIONAL DISTRITO CAPITAL Grupo Administrativo Intercentros CEET **';
    expect(
      ubicar(cuenta, 'CENTRO METALMECANICO D.C').nodo,
      'Centro Metalmecánico',
    );
    expect(
      ubicar(cuenta, 'CENTRO DE MATERIALES Y ENSAYOS D.C').nodo,
      'Centro de Materiales y Ensayos',
    );
  });

  test('33 regionales', () {
    expect(regionalesSena.length, 33);
    expect(esNitSena('899999034-1'), isTrue);
    expect(esNitSena('800098911'), isFalse);
  });
}
