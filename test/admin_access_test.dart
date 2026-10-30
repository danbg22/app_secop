import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/admin_access.dart';

void main() {
  test('todosLosRoles incluye cada rol del catálogo', () {
    expect(
      AdminAccess.todosLosRoles,
      containsAll(<String>[
        'persona',
        'equipo_juridico',
        'empresa_licitante',
        'veeduria_ciudadana',
      ]),
    );
  });

  test('un correo que no está en la lista no es administrador', () {
    expect(AdminAccess.esAdministrador('cualquiera@ejemplo.com'), isFalse);
    expect(AdminAccess.esAdministrador(null), isFalse);
  });

  test('la comparación ignora mayúsculas y espacios', () {
    for (final correo in AdminAccess.correosAdministradores) {
      expect(AdminAccess.esAdministrador('  ${correo.toUpperCase()} '), isTrue);
    }
  });
}
