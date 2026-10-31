import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Registro probatorio de la autorización de tratamiento de datos personales
/// (Ley 1581 de 2012 y Decreto 1377 de 2013, compilado en el Decreto 1074 de 2015).
///
/// El responsable del tratamiento debe poder demostrar ante la SIC que obtuvo la
/// autorización previa, expresa e informada del titular. Por eso se guardan:
///  - Un estado vigente en `usuarios/{uid}` (consulta rápida).
///  - Una entrada inmutable en `usuarios/{uid}/auditoria_consentimiento` (evidencia).
class ConsentService {
  ConsentService._();

  /// Versión del texto de la política aceptada. Cámbiala cada vez que el área
  /// legal modifique la política, para saber qué versión aceptó cada usuario.
  static const String versionPolitica = '1.0-2026-10';

  /// Texto de la política que acepta el titular. Lo usan el registro y la
  /// aceptación de los abogados de equipo, para que ambos canales acepten
  /// exactamente la misma versión.
  static const String textoPolitica =
      'Versión $versionPolitica\n\n'
      '1. Responsable: Contrata Legal, plataforma tecnológica de información contractual pública para el rol Persona y roles especializados.\n\n'
      '2. Datos tratados: nombres, apellidos, correo electrónico, número de documento/cédula, país y teléfono.\n\n'
      '3. Finalidades: crear y administrar tu cuenta, asignar tus roles activos, autenticarte, guardar tus favoritos y preferencias, procesar la activación de tu plan y cumplir obligaciones legales.\n\n'
      '4. Derechos del titular (Art. 8, Ley 1581 de 2012): conocer, actualizar y rectificar tus datos; solicitar prueba de esta autorización; ser informado del uso dado a tus datos; presentar quejas ante la Superintendencia de Industria y Comercio; revocar la autorización y solicitar la supresión de tus datos.\n\n'
      '5. Datos sensibles: no son obligatorios; puedes abstenerte de suministrarlos.\n\n'
      '6. Seguridad y conservación: los datos se almacenan en servicios de Google Firebase con medidas de seguridad razonables y se conservan mientras la cuenta esté activa o lo exija la ley.\n\n'
      '7. Evidencia: al aceptar, se registra la fecha y hora de tu autorización y la versión de esta política, como prueba exigida por el Decreto 1377 de 2013.';

  static const String coleccionUsuarios = 'usuarios';
  static const String subcoleccionAuditoria = 'auditoria_consentimiento';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Guarda la evidencia de aceptación. Lanza excepción si Firestore falla,
  /// para que el registro NO se complete sin prueba de la autorización.
  static Future<void> registrarAceptacionTratamientoDatos({
    required String uid,
    required String email,
    required String canal,
  }) async {
    final ahoraCliente = DateTime.now();
    final userRef = _db.collection(coleccionUsuarios).doc(uid);
    final logRef = userRef.collection(subcoleccionAuditoria).doc();

    final evidencia = <String, dynamic>{
      'uid': uid,
      'email': email,
      'aceptacion_datos': true,
      'aceptacion_politica_privacidad': true,
      'version_politica': versionPolitica,
      'canal': canal,
      'plataforma': kIsWeb ? 'web' : defaultTargetPlatform.name,
      // Hora del servidor de Google: es la fuente de verdad (no manipulable por el cliente).
      'fecha_aceptacion': FieldValue.serverTimestamp(),
      // Hora del dispositivo, solo como dato de referencia.
      'fecha_aceptacion_cliente': ahoraCliente.toIso8601String(),
      'zona_horaria_cliente': ahoraCliente.timeZoneName,
    };

    // Escritura atómica: o se guardan ambos documentos o ninguno.
    final batch = _db.batch();
    batch.set(
      userRef,
      {
        'uid': uid,
        'email': email,
        'aceptacion_datos': true,
        'version_politica': versionPolitica,
        'fecha_aceptacion_datos': FieldValue.serverTimestamp(),
        'actualizado_en': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(logRef, evidencia);
    await batch.commit().timeout(const Duration(seconds: 8));
  }

  /// El titular ya aceptó la versión vigente de la política. Si cambia la
  /// versión, se le vuelve a pedir.
  static Future<bool> tieneAceptacionVigente(String uid) async {
    final doc = await _db
        .collection(coleccionUsuarios)
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 8));
    final data = doc.data();
    return data != null &&
        data['aceptacion_datos'] == true &&
        data['version_politica'] == versionPolitica;
  }
}
