import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/seguimiento_service.dart';

void main() {
  const entidad = Seguido(
    tipo: TipoSeguido.entidad,
    clave: '899999034',
    nombre: 'Servicio Nacional de Aprendizaje (SENA)',
    desdeIso: '2026-09-21',
    vistos: 3058,
  );
  const contratista = Seguido(
    tipo: TipoSeguido.contratista,
    clave: '1000000000',
    nombre: 'Persona de prueba',
    desdeIso: '2026-09-21',
    vistos: 4,
  );

  group('Alertas de lo que se sigue', () {
    test('la entidad se busca por nit_entidad numérico con y sin DV', () {
      expect(
        entidad.filtroSecop,
        "nit_entidad in (899999034,8999990341) AND fecha_de_firma >= '2026-09-21T00:00:00.000'",
      );
    });

    test('el contratista se busca por documento_proveedor como texto', () {
      expect(
        contratista.filtroSecop,
        "documento_proveedor in ('1000000000') AND fecha_de_firma >= '2026-09-21T00:00:00.000'",
      );
    });

    test('nuevos = contratos de hoy menos los que ya había visto', () {
      SeguimientoService.fijarParaPrueba(
        [entidad, contratista],
        {entidad.id: 3061, contratista.id: 4},
      );
      expect(SeguimientoService.nuevos(entidad), 3);
      expect(SeguimientoService.nuevos(contratista), 0);
      expect(SeguimientoService.totalNuevos, 3);
      expect(
        SeguimientoService.sigue(TipoSeguido.entidad, '899.999.034-1'),
        isTrue,
      );
      expect(
        SeguimientoService.sigue(TipoSeguido.contratista, '899999034'),
        isFalse,
      );
      SeguimientoService.fijarParaPrueba(const [], const {});
    });

    test('ida y vuelta por la cuenta', () {
      final s = Seguido.fromMap(entidad.toMap());
      expect(s.id, 'entidad:899999034');
      expect(s.vistos, 3058);
      expect(s.conVistos(3061).vistos, 3061);
    });
  });
}
