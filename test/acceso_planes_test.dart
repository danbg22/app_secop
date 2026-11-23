import 'package:app_secop/services/acceso_planes.dart';
import 'package:flutter_test/flutter_test.dart';

EstadoPlanes estado({
  int pruebaHasta = 0,
  String? prueba = 'persona',
  String inicial = 'persona',
  List<String> roles = const ['persona', 'contratista'],
  Map<String, int> pagos = const {},
}) => EstadoPlanes({
  'ahora': 10000,
  'roles': roles,
  'historicos': [],
  'pagadosHasta': pagos,
  'rolInicial': inicial,
  'pruebaRol': prueba,
  'pruebaHasta': pruebaHasta,
  'graciaEquipoHasta': 0,
});

void main() {
  test('el contador redondea hacia arriba los días de prueba', () {
    final acceso = estado(
      pruebaHasta: 10000 + 30 * Duration.millisecondsPerDay,
    );
    expect(acceso.diasPrueba, 30);
    expect(acceso.roles, contains('persona'));
  });

  test('al vencer se retira el acceso del plan pago y sus roles gratuitos', () {
    final acceso = estado(pruebaHasta: 10000);
    expect(acceso.pruebaVencida, isTrue);
    expect(acceso.roles, isEmpty);
  });

  test('la suscripción activa sustituye la prueba', () {
    final acceso = estado(prueba: null, pagos: {'persona': 90000});
    expect(acceso.enPrueba, isFalse);
    expect(acceso.tieneSuscripcionVigente('persona'), isTrue);
    expect(acceso.roles, contains('persona'));
  });

  test('una cuenta que comenzó en un plan gratuito conserva ese acceso', () {
    final acceso = estado(
      inicial: 'contratista',
      prueba: null,
      roles: ['contratista'],
    );
    expect(acceso.roles, {'contratista'});
  });
}
