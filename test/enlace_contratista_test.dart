import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/juridico_contratacion_service.dart';

void main() {
  test('el enlace desactivado del contratista se conserva al guardar', () {
    final base = ExpedienteContratoPs.fromMap(const {
      'id': 'exp-1',
      'tokenInvitado': '0123456789abcdef0123456789abcdef',
      'numeroContrato': 'CPS-001',
      'apartados': [],
      'trazabilidad': [],
    });
    expect(base.enlaceDesactivado, isFalse);
    expect(base.toMap().containsKey('enlaceDesactivado'), isFalse);

    final desactivado = base.copyWith(enlaceDesactivado: true);
    final ida = ExpedienteContratoPs.fromMap(desactivado.toMap());
    expect(ida.enlaceDesactivado, isTrue);
    // Cualquier otro cambio del equipo no lo reactiva por accidente.
    expect(ida.copyWith(conceptoJuridico: 'ok').enlaceDesactivado, isTrue);
  });
}
