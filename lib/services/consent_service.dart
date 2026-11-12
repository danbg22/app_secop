import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  /// legal modifique la política, para saber qué versión aceptó cada usuario:
  /// con una versión nueva, la app vuelve a pedir la autorización.
  static const String versionPolitica = '1.1-2026-11';

  /// Texto de la política que acepta el titular. Lo usan el registro, la
  /// aceptación al iniciar sesión, la de los abogados de equipo y el ingreso
  /// del contratista por el enlace de su contrato, para que todos los canales
  /// acepten exactamente la misma versión.
  static const String textoPolitica =
      'Versión $versionPolitica\n\n'
      '1. Responsable. Contrata Legal, plataforma tecnológica de información contractual pública. '
      'Las consultas y reclamos sobre datos personales se atienden en el Centro de Ayuda y PQRS de la app.\n\n'
      '2. Datos que tratamos.\n'
      'a) De quien crea una cuenta o inicia sesión (correo, Google o Apple): nombres, apellidos, correo electrónico, '
      'número de documento, país, teléfono y foto de perfil.\n'
      'b) Del contratista que ingresa por el enlace de su contrato: nombre, número de cédula, dirección, ciudad, celular, '
      'datos bancarios para el pago (banco, tipo y número de cuenta), información tributaria, los documentos que el '
      'contrato pide (cédula, RUT, certificación bancaria, planillas de seguridad social, ARL, antecedentes, soportes de '
      'estudios y experiencia), su firma y sus informes de actividades.\n'
      'c) Información pública: contratos, procesos, declaraciones y hojas de vida publicados por SECOP I y II, '
      'datos.gov.co y el SIGEP II de Función Pública, que incluyen nombres y números de identificación de contratistas y '
      'servidores públicos.\n\n'
      '3. Finalidades.\n'
      'a) Crear y administrar tu cuenta, autenticarte, asignar tus roles, guardar favoritos y preferencias, procesar el '
      'pago de tu plan y cumplir obligaciones legales.\n'
      'b) Verificar la identidad de quien entra al enlace del contrato, reunir y revisar los documentos del contrato, '
      'elaborar y aprobar los informes de supervisión y tramitar los pagos.\n'
      'c) Facilitar la consulta de la información pública para la transparencia, el control social y la gestión '
      'contractual (Ley 1712 de 2014). Se muestra tal como la publica la fuente oficial, no se vende ni se usa para '
      'publicidad. La app no muestra la dirección de residencia ni el género de las personas; los únicos datos de '
      'contacto que muestra son los institucionales que las entidades publican en sus planes de adquisiciones.\n\n'
      '4. Datos de los contratos. El equipo jurídico o la entidad que crea un contrato en Contrata Legal responde por '
      'los datos del contratista que registra y por los documentos que le pide; Contrata Legal los trata por cuenta de '
      'ese equipo. Solo acceden el equipo, los responsables de aprobación que designe y el contratista con su enlace '
      'personal, que no debe compartirse.\n\n'
      '5. Datos sensibles. Contrata Legal no pide datos sensibles (origen racial o étnico, orientación política, '
      'convicciones religiosas, pertenencia a sindicatos u organizaciones, salud, vida sexual ni datos biométricos) ni '
      'datos de niñas, niños o adolescentes. Si un documento los contiene, no estás obligado(a) a suministrarlos y '
      'puedes ocultarlos antes de subirlo.\n\n'
      '6. Derechos del titular (art. 8, Ley 1581 de 2012): conocer, actualizar y rectificar tus datos; pedir prueba de '
      'esta autorización; saber qué uso se les ha dado; presentar quejas ante la Superintendencia de Industria y '
      'Comercio; revocar la autorización y pedir la supresión de tus datos cuando no exista un deber legal o contractual '
      'de conservarlos. Las consultas se responden en máximo 10 días hábiles y los reclamos en máximo 15 (arts. 14 y 15). '
      'Si un dato público tuyo está errado, también puedes pedir su corrección a la fuente oficial (la entidad '
      'contratante, Colombia Compra Eficiente o Función Pública); la app se actualiza cuando la fuente cambia.\n\n'
      '7. Seguridad, conservación y terceros. Los datos se guardan en Google Firebase, cuyos servidores pueden estar '
      'fuera de Colombia, con medidas de seguridad razonables, y se conservan mientras la cuenta o el contrato estén '
      'activos o lo exija la ley. Los pagos los procesa Wompi: la app no guarda datos de tarjetas.\n\n'
      '8. Cambios. Si esta política cambia, te pediremos de nuevo la autorización antes de que sigas usando la app.\n\n'
      '9. Evidencia. Al aceptar se registran la fecha y la hora de tu autorización y la versión de esta política, como '
      'prueba exigida por el Decreto 1377 de 2013.';

  /// Texto de la casilla de autorización (el mismo en todos los canales).
  static const String textoCasilla =
      'Autorizo de forma previa, expresa e informada el tratamiento de mis '
      'datos personales según esta política.';

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
    batch.set(userRef, {
      'uid': uid,
      'email': email,
      'aceptacion_datos': true,
      'version_politica': versionPolitica,
      'fecha_aceptacion_datos': FieldValue.serverTimestamp(),
      'actualizado_en': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(logRef, evidencia);
    await batch.commit().timeout(const Duration(seconds: 8));
    _marcarVigente(uid);
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

  // ---------------------------------------------------------------------------
  // Autorización del usuario con sesión iniciada
  // ---------------------------------------------------------------------------
  //
  // Quien entra con Google o Apple, o creó su cuenta antes de la versión
  // vigente de la política, no ha dado la autorización (o la dio para otra
  // versión): AuthGate le pide aceptarla antes de usar la app.

  /// Avisa a AuthGate cada vez que cambia el estado de la autorización.
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);

  static String _uid = '';
  static bool _pendiente = false;
  static bool _verificando = false;

  /// Usuarios que aceptaron en esta sesión de la app: una lectura iniciada
  /// antes de guardar la aceptación no los vuelve a marcar como pendientes.
  static final Set<String> _aceptaronAhora = <String>{};

  static StreamSubscription<User?>? _suscripcion;

  /// Falta la autorización del usuario con sesión: AuthGate muestra la
  /// política antes del panel.
  static bool get pendiente => _pendiente;

  /// Se está consultando por primera vez en este navegador si el usuario ya
  /// aceptó la versión vigente.
  static bool get verificando => _verificando;

  static String _claveCache(String uid) => 'consentimiento_datos_$uid';

  /// Empieza a seguir la sesión de Firebase (una vez, al abrir la app).
  static void iniciar() {
    _suscripcion ??= FirebaseAuth.instance.authStateChanges().listen(
      (user) => unawaited(verificar(user)),
    );
  }

  /// Comprueba si [user] aceptó la versión vigente de la política. Si este
  /// navegador ya lo confirmó antes, entra sin esperar y se verifica en
  /// segundo plano. Sin conexión con Firestore no se bloquea el acceso: se
  /// vuelve a verificar en el próximo inicio de sesión.
  @visibleForTesting
  static Future<void> verificar(User? user) async {
    if (user == null) {
      _uid = '';
      _pendiente = false;
      _verificando = false;
      cambios.value++;
      return;
    }
    if (user.uid == _uid && !_pendiente) return;
    final uid = user.uid;
    _uid = uid;
    _pendiente = false;

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    final confirmadaAntes =
        prefs?.getString(_claveCache(uid)) == versionPolitica;
    _verificando = !confirmadaAntes;
    cambios.value++;

    bool? vigente;
    try {
      vigente = await tieneAceptacionVigente(uid);
    } catch (error) {
      debugPrint('No se pudo verificar la autorización de datos: $error');
    }
    if (uid != _uid) return; // Cambió la sesión mientras tanto.
    _verificando = false;
    if (vigente == true || _aceptaronAhora.contains(uid)) {
      _marcarVigente(uid);
      return;
    }
    if (vigente == false) {
      _pendiente = true;
      try {
        await prefs?.remove(_claveCache(uid));
      } catch (_) {}
    }
    cambios.value++;
  }

  /// Registra la autorización del usuario con sesión iniciada.
  static Future<void> aceptarUsuarioActual() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión nuevamente.');
    }
    final proveedores = user.providerData.map((p) => p.providerId).toSet();
    await registrarAceptacionTratamientoDatos(
      uid: user.uid,
      email: (user.email ?? '').trim().toLowerCase(),
      canal: proveedores.contains('google.com')
          ? 'inicio_sesion_google'
          : proveedores.contains('apple.com')
          ? 'inicio_sesion_apple'
          : 'inicio_sesion',
    );
  }

  static void _marcarVigente(String uid) {
    _aceptaronAhora.add(uid);
    if (uid == _uid) {
      _pendiente = false;
      _verificando = false;
      cambios.value++;
    }
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_claveCache(uid), versionPolitica);
      } catch (_) {}
    }());
  }
}
