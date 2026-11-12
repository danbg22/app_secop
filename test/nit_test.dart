import 'package:app_secop/utils/nit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dígito de verificación (DIAN)', () {
    expect(
      Nit.digitoVerificacion('892300285'),
      6,
    ); // Universidad Popular del Cesar
    expect(Nit.digitoVerificacion('899999034'), 1); // SENA
  });

  test('formas en que SECOP guarda el NIT', () {
    expect(Nit.formas('892.300.285'), [
      '892300285',
      '8923002856',
      '892300285-6',
    ]);
    expect(Nit.formas('12345'), ['12345']);
  });
}
