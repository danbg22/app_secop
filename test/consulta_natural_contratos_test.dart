import 'package:app_secop/services/consulta_natural_contratos.dart';
import 'package:flutter_test/flutter_test.dart';

InterpretacionConsulta _i(String texto) =>
    ConsultaNaturalContratos.interpretar(texto, anioActual: 2026);

void main() {
  test('alimentación en el Cesar: lugar + tema, sin confundir el nombre Cesar', () {
    final i = _i('contrato de alimentación en el cesar');
    expect(i.esConsultaNatural, isTrue);
    expect(i.departamento, 'Cesar');
    expect(i.temasEtiqueta, ['alimentación']);
    expect(i.temas.single, contains('ALIMENTACI'));
    expect(i.temas.single, contains('REFRIGERIO'));
    final soql = i.clausulasSecopII().join(' AND ');
    expect(soql, contains("departamento = 'Cesar'"));
    expect(soql, isNot(contains('proveedor_adjudicado')));
  });

  test('empresas que han contratado mantenimiento vial', () {
    final i = _i('Empresas que han contratado mantenimiento vial');
    expect(i.tipoContratista, TipoContratista.empresa);
    expect(i.temasEtiqueta, ['mantenimiento', 'vial']);
    expect(i.temas.last, containsAll(['VIAL', 'CARRETER']));
    expect(i.clausulasSecopII(), contains("tipodocproveedor = 'NIT'"));
  });

  test('contratos superiores a 500 millones en 2025', () {
    final i = _i('Contratos superiores a 500 millones en 2025');
    expect(i.valorMin, 500e6);
    expect(i.valorMax, isNull);
    expect((i.anioDesde, i.anioHasta), (2025, 2025));
    expect(i.temas, isEmpty);
    expect(i.esConsultaNatural, isTrue);
    expect(i.etiquetas(), containsAll(['Valor ≥ \$500 M', 'Año: 2025']));
  });

  test('montos: rangos, mil millones y decimales', () {
    final rango = _i('contratos entre 100 y 500 millones');
    expect((rango.valorMin, rango.valorMax), (100e6, 500e6));
    expect(_i('obras de más de 1.500 millones').valorMin, 1500e6);
    expect(_i('obras de mas de 2 mil millones').valorMin, 2e9);
    expect(_i('contratos menores a 1,5 millones').valorMax, 1.5e6);
  });

  test('años: rango, desde, este año, el año pasado y últimos N', () {
    final r = _i('licitaciones de obra en antioquia entre 2022 y 2024');
    expect((r.anioDesde, r.anioHasta), (2022, 2024));
    expect(r.modalidad, 'Licitación pública');
    expect(r.departamento, 'Antioquia');
    expect(r.temasEtiqueta, ['obra']);
    expect(_i('contratos de aseo desde 2023').anioDesde, 2023);
    expect(_i('contratos de aseo este año').anioDesde, 2026);
    expect(_i('contratos de aseo el año pasado').anioHasta, 2025);
    final u = _i('contratos de aseo de los últimos 3 años');
    expect((u.anioDesde, u.anioHasta), (2024, 2026));
  });

  test('un año no se confunde con un monto', () {
    final i = _i('contratos de más de 2000 millones');
    expect(i.valorMin, 2000e6);
    expect(i.anioDesde, isNull);
  });

  test('alcaldía de un municipio', () {
    final i = _i('contratos de la alcaldía de valledupar en 2024');
    expect(i.municipio, 'Valledupar');
    expect(i.departamento, 'Cesar');
    expect(i.entidadEtiqueta, 'Alcaldía de Valledupar');
    expect(i.patronesEntidad, ['ALCALD|MUNICIPIO|DISTRITO']);
    expect(i.temas, isEmpty);
  });

  test('"en el municipio de" es un lugar, no la alcaldía', () {
    final i = _i('contratos de transporte en el municipio de aguachica');
    expect(i.municipio, 'Aguachica');
    expect(i.patronesEntidad, isEmpty);
    expect(i.temasEtiqueta, ['transporte']);
  });

  test('gobernación y siglas de entidades', () {
    final g = _i('contratos de la gobernación del cesar');
    expect(g.departamento, 'Cesar');
    expect(g.entidadEtiqueta, 'Gobernación de Cesar');
    final s = _i('contratos del SENA en la guajira con contratación directa');
    expect(s.entidadEtiqueta, 'SENA');
    expect(s.departamento, 'La Guajira');
    expect(s.modalidad, 'Contratación directa');
  });

  test('departamentos de varias palabras y Bogotá', () {
    expect(_i('obras en norte de santander').departamento, 'Norte de Santander');
    expect(_i('vigilancia en bogota').departamento, 'Distrito Capital de Bogotá');
  });

  test('nombres de personas y números siguen por la búsqueda clásica', () {
    expect(_i('Cesar Ricardo Alvarado').esConsultaNatural, isFalse);
    expect(_i('Juan de la Cruz').esConsultaNatural, isFalse);
    expect(_i('CO1.PCCNTR.10122618').esConsultaNatural, isFalse);
    expect(_i('900123456').esConsultaNatural, isFalse);
    expect(_i('cesar').departamento, isNull);
  });

  test('solo deja letras, dígitos y comodines en el SoQL', () {
    final i = _i("contratos de aseo' OR 1=1 -- en el cesar");
    for (final c in i.clausulasSecopII()) {
      final sinLiterales = c.replaceAll(RegExp(r"'[^']*'"), '');
      expect(sinLiterales, isNot(contains("'")));
    }
    expect(i.clausulasSecopII().join(), isNot(contains('--')));
  });

  test('sin año, lugar ni entidad: últimas 3 vigencias, avisado', () {
    final i = _i('Empresas que han contratado mantenimiento vial');
    expect(i.aniosPorDefecto, isTrue);
    expect((i.anioDesde, i.anioHasta), (2024, 2026));
    expect(
      i.etiquetas().any((e) => e.contains('escribe un año para ampliar')),
      isTrue,
    );
    expect(_i('contrato de alimentación en el cesar').aniosPorDefecto, isFalse);
    expect(_i('contratos de aseo en 2019').aniosPorDefecto, isFalse);
  });

  test('tildes solo en terminaciones que las llevan', () {
    final energia = _i('contratos de energia en el meta').temas.single;
    expect(energia, ['ENERGIA', 'ENERGÍA']);
    final tecnico = _i('soporte tecnico en el meta').temas.last;
    expect(tecnico, ['TECNICO', 'TÉCNICO']);
    expect(_i('mantenimiento en el meta').temas.single, ['MANTENIMIENTO']);
  });

  test('la ración no coincide con "administración"', () {
    final alimentacion = _i('alimentación en el cesar').temas.single;
    expect(alimentacion, isNot(contains('RACION')));
    expect(alimentacion, contains(' RACION'));
  });
}

