import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/data/colombia_entities_database.dart';

void main() {
  test('cada entidad del catálogo tiene nombre y NIT numérico', () {
    for (final e in ColombiaEntitiesDatabase.allEntities) {
      expect(e.name.trim(), isNotEmpty);
      expect(
        RegExp(r'^\d{8,10}$').hasMatch(e.nit.replaceAll(RegExp(r'\D'), '')),
        isTrue,
        reason: '${e.name}: NIT "${e.nit}"',
      );
    }
  });

  test('la sigla SENA apunta al NIT del SENA en SECOP II', () {
    final sena = ColombiaEntitiesDatabase.allEntities.where(
      (e) => e.secopKeywords.contains('SENA'),
    );
    expect(sena.map((e) => e.nit.replaceAll(RegExp(r'\D'), '')),
        contains('899999034'));
  });

  test('nitsPorSigla encuentra siglas exactas, con o sin puntos', () {
    expect(ColombiaEntitiesDatabase.nitsPorSigla('UIS'), contains('890201213'));
    expect(ColombiaEntitiesDatabase.nitsPorSigla('u.i.s.'), contains('890201213'));
    expect(ColombiaEntitiesDatabase.nitsPorSigla('UNIVERSIDAD'), isEmpty);
  });
}
