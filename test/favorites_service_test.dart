import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/favorites_service.dart';
import 'package:app_secop/utils/anios_secop.dart';

void main() {
  group('FavoritesService.idContrato', () {
    test('distingue contratos del mismo proceso de compra', () {
      final a = {
        'id_contrato': 'CO1.PCCNTR.1',
        'proceso_de_compra': 'CO1.BDOS.9',
      };
      final b = {
        'id_contrato': 'CO1.PCCNTR.2',
        'proceso_de_compra': 'CO1.BDOS.9',
      };
      expect(
        FavoritesService.idContrato(a),
        isNot(FavoritesService.idContrato(b)),
      );
    });

    test('SECOP I sin id_contrato usa proceso, referencia y proveedor', () {
      final c = {
        'proceso_de_compra': '15-12-123',
        'referencia_del_contrato': '45',
        'documento_proveedor': '900123',
      };
      expect(FavoritesService.idContrato(c), '15-12-123|45|900123');
    });

    test('no falla con campos nulos ni con valores que no son mapas', () {
      expect(FavoritesService.idContrato({'nombre_entidad': null}), '|');
      expect(FavoritesService.idContrato('texto'), '');
    });
  });

  test('AniosSecop.disponibles va del año actual a 2015', () {
    final anios = AniosSecop.disponibles;
    expect(anios.first, DateTime.now().year);
    expect(anios.last, AniosSecop.primero);
    expect(anios.length, DateTime.now().year - AniosSecop.primero + 1);
  });
}
