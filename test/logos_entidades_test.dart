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
    expect(LogosEntidades.logos.length, 50);
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
      LogosEntidades.buscar(nombre: 'Alcaldía Municipal de Valledupar')?.archivo,
      'valledupar.png',
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
