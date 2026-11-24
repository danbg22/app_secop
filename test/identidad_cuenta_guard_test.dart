import 'package:app_secop/services/acceso_planes.dart';
import 'package:app_secop/services/registro_cedula.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registro = DateTime.utc(2026, 11, 24, 19);

  EstadoPlanes estado({
    Map<String, dynamic> perfil = const {},
    Map<String, dynamic>? acceso,
    bool cuentaAnterior = false,
    DateTime? ahora,
  }) => EstadoPlanes.desdeFirestore(
    perfil: perfil,
    acceso: acceso,
    cuentaAnterior: cuentaAnterior,
    ahora: ahora ?? registro,
  );

  test('solo las cuentas nuevas incompletas deben ingresar cédula', () {
    expect(estado().preparando, isTrue);
    final anterior = estado(cuentaAnterior: true);
    expect(anterior.preparando, isFalse);
    expect(anterior.roles, contains('persona'));
    expect(anterior.tieneSuscripcionVigente('persona'), isFalse);
  });

  test(
    'el registro normaliza la cédula y descarta identificadores inválidos',
    () {
      expect(RegistroCedula.normalizar(' 1.234.567 '), '1234567');
      expect(RegistroCedula.normalizar('CC 1234567'), isEmpty);
      expect(RegistroCedula.normalizar('1234'), isEmpty);
    },
  );

  test('la prueba va del registro confirmado a los 30 días exactos', () {
    final perfil = {
      'registroCedulaEn': Timestamp.fromDate(registro),
      'rolRegistroCedula': 'equipo_juridico',
    };
    final vigente = estado(perfil: perfil);
    expect(vigente.roles, {'equipo_juridico'});
    expect(vigente.diasPrueba, 30);
    final fin = registro.add(const Duration(days: 30));
    expect(
      estado(
        perfil: perfil,
        ahora: fin.subtract(const Duration(seconds: 1)),
      ).roles,
      {'equipo_juridico'},
    );
    final vencido = estado(perfil: perfil, ahora: fin);
    expect(vencido.roles, isEmpty);
    expect(vencido.pruebaVencida, isTrue);
    expect(vencido.preparando, isFalse);
  });

  test('un registro requiere cédula antes de activar su rol gratuito', () {
    expect(
      estado(
        perfil: {
          'rolesActivos': ['contratista'],
        },
      ).preparando,
      isTrue,
    );
    final listo = estado(
      perfil: {
        'registroCedulaEn': Timestamp.fromDate(registro),
        'rolRegistroCedula': 'contratista',
        'rolesActivos': ['contratista'],
      },
    );
    expect(listo.roles, {'contratista'});
    expect(listo.enPrueba, isFalse);
  });

  test('una vigencia anterior confirmada prevalece sobre la exención', () {
    final vencido = estado(
      cuentaAnterior: true,
      acceso: {
        'rolInicial': 'persona',
        'pruebaRol': 'persona',
        'pruebaHasta': Timestamp.fromDate(registro),
      },
    );
    expect(vencido.roles, isEmpty);
    expect(vencido.preparando, isFalse);
  });
}
