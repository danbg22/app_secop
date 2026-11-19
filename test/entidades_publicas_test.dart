import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/entidades_publicas.dart';

void main() {
  group('Entidades públicas como contratistas', () {
    test('toma el NIT base con o sin dígito de verificación', () {
      expect(EntidadesPublicas.base('899.999.034-1'), '899999034');
      expect(EntidadesPublicas.base('8999990341'), '899999034');
      expect(EntidadesPublicas.base('899999034'), '899999034');
    });

    test('las cédulas y los documentos vacíos no son NIT', () {
      expect(EntidadesPublicas.base('5822570'), isNull);
      expect(EntidadesPublicas.base('1065000000'), isNull);
      expect(EntidadesPublicas.base(''), isNull);
      expect(EntidadesPublicas.conocida('5822570'), isFalse);
    });

    test('el SENA está en el catálogo sin consultar SECOP', () {
      expect(EntidadesPublicas.conocida('8999990341'), isTrue);
    });
  });
}
