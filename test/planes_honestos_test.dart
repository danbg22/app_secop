import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/payment_service.dart';

/// Los planes que se cobran solo anuncian lo que la app hace (Ley 1480 de
/// 2011, art. 30: publicidad engañosa). Cuando una de estas funciones exista,
/// se quita de la lista.
void main() {
  const noExisten = [
    'estadística',
    'certificado',
    'acta de aval',
    'notificación por correo',
    'entidades y contratistas en favoritos',
  ];

  test('los planes habilitados no anuncian funciones que no existen', () {
    for (final rol in PaymentService.obtenerRolesHabilitados()) {
      final textos = [
        rol.descripcionCorta,
        ...rol.beneficiosPrincipales,
        ...rol.todosLosBeneficios,
      ].map((t) => t.toLowerCase());
      for (final texto in textos) {
        for (final f in noExisten) {
          expect(
            texto.contains(f),
            isFalse,
            reason: 'El plan ${rol.nombre} anuncia "$f": $texto',
          );
        }
      }
    }
  });
}
