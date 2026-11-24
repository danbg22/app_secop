import 'package:cloud_firestore/cloud_firestore.dart';

import 'security_service.dart';

abstract final class RegistroCedula {
  static final _formato = RegExp(r'^[0-9]{5,20}$');

  static String normalizar(String valor) {
    final entrada = valor.trim();
    if (!RegExp(r'^[0-9. -]{5,32}$').hasMatch(entrada)) return '';
    final digitos = entrada.replaceAll(RegExp(r'[^0-9]'), '');
    return _formato.hasMatch(digitos) ? digitos : '';
  }

  static bool completado(Map<String, dynamic> perfil) =>
      perfil['registroCedulaEn'] is Timestamp ||
      (perfil['cedulaVinculada'] == true &&
          normalizar((perfil['documentoNormalizado'] ?? '').toString())
              .isNotEmpty);

  static Future<void> guardar({
    required String uid,
    required String cedula,
    required String rol,
    Map<String, dynamic> datos = const {},
  }) async {
    final documento = normalizar(cedula);
    if (documento.isEmpty) {
      throw const RegistroCedulaException(
        'Ingresa una cédula de 5 a 20 dígitos.',
      );
    }

    final db = FirebaseFirestore.instance;
    final perfil = db.collection('usuarios').doc(uid);
    final indice = db
        .collection('indices_unicidad')
        .doc(
          SecurityService.hashCredentialUniquenessIndex(
            type: 'doc',
            normalizedValue: documento,
          ),
        );

    Future<bool> yaRegistrado() async {
      final guardado = (await perfil.get(
        const GetOptions(source: Source.server),
      )).data();
      return guardado != null &&
          completado(guardado) &&
          guardado['documentoNormalizado'] == documento;
    }

    final lote = db.batch();
    lote.set(perfil, {
      ...datos,
      'uid': uid,
      'documento': documento,
      'documentoNormalizado': documento,
      'cedulaVinculada': true,
      'rolRegistroCedula': rol,
      'registroCedulaEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    lote.set(indice, {
      'tipo': 'doc',
      'uid': uid,
      'creado_en': FieldValue.serverTimestamp(),
    });
    try {
      await lote.commit().timeout(const Duration(seconds: 12));
    } on FirebaseException catch (error) {
      if (await yaRegistrado()) return;
      if (error.code == 'permission-denied') {
        throw const RegistroCedulaException(
          'La cédula no está disponible para este registro. Si ya tienes cuenta, inicia sesión o contacta a soporte.',
        );
      }
      rethrow;
    }
  }
}

class RegistroCedulaException implements Exception {
  const RegistroCedulaException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}
