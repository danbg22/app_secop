import 'dart:io';

import 'package:app_secop/data/colombia_entities_database.dart';
import 'package:app_secop/data/logos_entidades.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada logo tiene su archivo y no hay NIT repetidos', () {
    final nits = <String>{};
    for (final l in LogosEntidades.logos) {
      expect(File(l.asset).existsSync(), isTrue, reason: l.asset);
      for (final n in l.nits) {
        expect(n, matches(RegExp(r'^\d{9}$')));
        expect(nits.add(n), isTrue, reason: 'NIT repetido $n');
      }
    }
    expect(LogosEntidades.logos.length, 116);
  });

  test('reconoce por NIT con o sin dígito de verificación', () {
    expect(LogosEntidades.buscar(nit: '899999034')?.archivo, 'sena.png');
    expect(LogosEntidades.buscar(nit: '8301259969')?.archivo, 'ani.png');
    expect(LogosEntidades.buscar(nit: '899.999.239-2')?.archivo, 'icbf.png');
  });

  test('reconoce por nombre cuando el NIT no coincide', () {
    expect(
      LogosEntidades.buscar(nombre: 'Ministerio de Educación Nacional (MEN)')
          ?.archivo,
      'mineducacion.png',
    );
    expect(
      LogosEntidades.buscar(nombre: 'Alcaldía Municipal de Valledupar')
          ?.archivo,
      'valledupar.png',
    );
  });

  test('ciudades principales y sus departamentos', () {
    expect(
      LogosEntidades.buscar(nit: '890102018')?.archivo,
      'barranquilla.png',
    );
    expect(
      LogosEntidades.buscar(nombre: 'Municipio de Bucaramanga')?.archivo,
      'bucaramanga.png',
    );
    expect(LogosEntidades.buscar(nit: '8902012356')?.archivo, 'santander.png');
    expect(
      LogosEntidades.buscar(nombre: 'DEPARTAMENTO DEL ATLANTICO**')?.archivo,
      'atlantico.png',
    );
    expect(
      LogosEntidades.buscar(nit: '830063506')?.archivo,
      'transmilenio.png',
    );
    expect(
      LogosEntidades.buscar(nombre: 'Gobernación de Norte de Santander')
          ?.archivo,
      'norte_santander.png',
    );
  });

  test('todos los departamentos y sus capitales', () {
    expect(LogosEntidades.buscar(nit: '8001028385')?.archivo, 'arauca.png');
    expect(
      LogosEntidades.buscar(nit: '800102504')?.archivo,
      'arauca_municipio.png',
    );
    expect(
      LogosEntidades.buscar(nombre: 'GOBERNACIÓN DE NARIÑO')?.archivo,
      'narino.png',
    );
    expect(
      LogosEntidades.buscar(
        nombre: 'SANTIAGO DE CALI DISTRITO ESPECIAL - SECRETARIA DE MOVILIDAD',
      )?.archivo,
      'cali.png',
    );
    expect(LogosEntidades.buscar(nit: '890480184')?.archivo, 'cartagena.png');
    expect(LogosEntidades.buscar(nit: '8001136727')?.archivo, 'tolima.png');
    // Florencia (Cauca) no es la capital del Caquetá.
    expect(
      LogosEntidades.buscar(nombre: 'ALCALDIA DE FLORENCIA CAUCA'),
      isNull,
    );
    // Armenia (Antioquia) tiene otro NIT y no lleva el escudo de la capital.
    expect(
      LogosEntidades.buscar(nombre: 'MUNICIPIO DE ARMENIA', nit: '890983763'),
      isNull,
    );
  });

  test('empresas, universidades y áreas metropolitanas', () {
    expect(LogosEntidades.buscar(nit: '8923005488')?.archivo, 'emdupar.png');
    expect(LogosEntidades.buscar(nit: '8923002856')?.archivo, 'upc.png');
    expect(
      LogosEntidades.buscar(nombre: 'AREA METROPOLITANA DE BUCARAMANGA')
          ?.archivo,
      'amb.png',
    );
    expect(LogosEntidades.buscar(nit: '899999081')?.archivo, 'idu.png');
    // Otro instituto de desarrollo urbano no lleva el logo del IDU de Bogotá.
    expect(
      LogosEntidades.buscar(
        nombre: 'INSTITUTO DE DESARROLLO URBANO DE CALI',
        nit: '805000000',
      ),
      isNull,
    );
  });

  test('no confunde entidades con nombres parecidos', () {
    expect(
      LogosEntidades.buscar(
        nombre: 'E.S.E. Hospital Eduardo Arredondo Daza de Valledupar',
        nit: '824001041',
      ),
      isNull,
    );
    expect(LogosEntidades.buscar(nombre: 'Senado de la República'), isNull);
  });

  test('ningún NIT del catálogo muestra el logo de otra entidad', () {
    for (final e in ColombiaEntitiesDatabase.allEntities) {
      final porNit = LogosEntidades.buscar(nit: e.nit);
      if (porNit == null) continue;
      final porNombre = LogosEntidades.buscar(nombre: e.name);
      expect(
        porNombre?.archivo,
        porNit.archivo,
        reason: '${e.name} (NIT ${e.nit}) mostraría ${porNit.archivo}',
      );
    }
  });
}
