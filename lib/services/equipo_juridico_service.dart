import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'auth_service.dart';
import 'security_service.dart';

/// Permisos que el Master Jurídico asigna a cada abogado de su equipo.
/// Ver expedientes del equipo no es un permiso: lo tienen todos.
enum PermisoEquipo {
  crearContratos('crear_contratos', 'Crear contratos y procesos'),
  pedirDocumentos(
    'pedir_documentos',
    'Pedir documentos y devolver para subsanar',
  ),
  verificarDocumentos(
    'verificar_documentos',
    'Verificar documentos y emitir aval',
  );

  const PermisoEquipo(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static PermisoEquipo? desdeCodigo(String codigo) {
    for (final p in values) {
      if (p.codigo == codigo) return p;
    }
    return null;
  }
}

/// Abogado (usuario temporal) del equipo de un Master Jurídico. Se guarda en
/// `miembros_equipo/{correo}`: el correo identifica al abogado aunque su
/// cuenta exista desde antes, y las reglas de Firestore lo comparan con el
/// correo verificado del token.
class MiembroEquipo {
  const MiembroEquipo({
    required this.email,
    required this.nombre,
    required this.masterUid,
    required this.masterNombre,
    required this.permisos,
    required this.vigenteHasta,
    this.estado = 'activo',
    this.creadoEn,
  });

  final String email;
  final String nombre;
  final String masterUid;
  final String masterNombre;
  final Set<PermisoEquipo> permisos;
  final DateTime vigenteHasta;

  /// `activo` o `suspendido`.
  final String estado;
  final DateTime? creadoEn;

  bool get suspendido => estado == 'suspendido';
  bool get vencido => !vigenteHasta.isAfter(DateTime.now());
  bool get vigente => !suspendido && !vencido;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'email': email,
    'nombre': nombre,
    'masterUid': masterUid,
    'masterNombre': masterNombre,
    'permisos': permisos.map((p) => p.codigo).toList(),
    'vigenteHasta': Timestamp.fromDate(vigenteHasta),
    'estado': estado,
    'creadoEn': creadoEn == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(creadoEn!),
  };

  factory MiembroEquipo.fromMap(Map<String, dynamic> map) {
    DateTime fecha(dynamic v) => v is Timestamp
        ? v.toDate()
        : DateTime.tryParse('${v ?? ''}') ??
              DateTime.fromMillisecondsSinceEpoch(0);
    return MiembroEquipo(
      email: (map['email'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      masterUid: (map['masterUid'] ?? '').toString(),
      masterNombre: (map['masterNombre'] ?? '').toString(),
      permisos: {
        for (final c in (map['permisos'] as List? ?? const []))
          ?PermisoEquipo.desdeCodigo(c.toString()),
      },
      vigenteHasta: fecha(map['vigenteHasta']),
      estado: (map['estado'] ?? 'activo').toString(),
      creadoEn: map['creadoEn'] == null ? null : fecha(map['creadoEn']),
    );
  }

  MiembroEquipo copyWith({
    String? nombre,
    Set<PermisoEquipo>? permisos,
    DateTime? vigenteHasta,
    String? estado,
  }) => MiembroEquipo(
    email: email,
    nombre: nombre ?? this.nombre,
    masterUid: masterUid,
    masterNombre: masterNombre,
    permisos: permisos ?? this.permisos,
    vigenteHasta: vigenteHasta ?? this.vigenteHasta,
    estado: estado ?? this.estado,
    creadoEn: creadoEn,
  );
}

/// Resultado de agregar un abogado al equipo.
enum ResultadoAltaMiembro {
  /// Se creó la cuenta y se envió el correo para definir la contraseña.
  cuentaCreada,

  /// El correo ya tenía cuenta: queda vinculado y entra con su clave actual.
  cuentaExistenteVinculada,
}

class EquipoJuridicoException implements Exception {
  const EquipoJuridicoException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Equipo jurídico "Master Chief": el usuario que paga la suscripción
/// (Master Jurídico) crea abogados temporales con permisos y vigencia, que
/// trabajan sobre los mismos expedientes del equipo.
///
/// Sin Cloud Functions (plan Spark), las cuentas se crean desde la app con
/// una instancia secundaria de Firebase, para no cerrar la sesión del Master.
/// La autorización real está en `firestore.rules` (`miembroVigente`).
class EquipoJuridicoService {
  EquipoJuridicoService._();

  static const String coleccionMiembros = 'miembros_equipo';
  static const int cupoMaximo = 10;

  /// Vigencia máxima de un abogado temporal desde hoy.
  static const Duration vigenciaMaxima = Duration(days: 366);

  static final ValueNotifier<MiembroEquipo?> membresia =
      ValueNotifier<MiembroEquipo?>(null);

  /// El acceso al equipo exige el correo verificado (lo mismo comprueban las
  /// reglas de Firestore); la membresía se lee igual para poder avisarlo.
  static bool _correoVerificado = false;
  static StreamSubscription<User?>? _escuchaSesion;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Vigencia por defecto: fin de la vigencia fiscal (31 de diciembre).
  static DateTime vigenciaPorDefecto() {
    final hoy = DateTime.now();
    return DateTime(hoy.year, 12, 31, 23, 59);
  }

  static String _normalizarCorreo(String email) => email.trim().toLowerCase();

  // ===========================================================================
  // Membresía del usuario activo (abogado temporal)
  // ===========================================================================

  /// Carga la membresía del usuario activo cada vez que cambia la sesión.
  static void iniciar() {
    _escuchaSesion ??= FirebaseAuth.instance.authStateChanges().listen(
      (_) => unawaited(recargarMembresia()),
    );
  }

  static Future<void> recargarMembresia() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = _normalizarCorreo(user?.email ?? '');
    MiembroEquipo? encontrada;
    final verificadoAntes = _correoVerificado;
    _correoVerificado = user?.emailVerified ?? false;
    if (user != null && email.isNotEmpty) {
      try {
        final doc = await _db
            .collection(coleccionMiembros)
            .doc(email)
            .get()
            .timeout(const Duration(seconds: 6));
        if (doc.exists && doc.data() != null) {
          encontrada = MiembroEquipo.fromMap(doc.data()!);
        }
      } catch (_) {}
    }
    if (verificadoAntes != _correoVerificado ||
        membresia.value?.email != encontrada?.email ||
        membresia.value?.vigente != encontrada?.vigente ||
        membresia.value?.permisos.length != encontrada?.permisos.length) {
      membresia.value = encontrada;
      AuthService.authStateVersion.value++;
    }
  }

  /// El usuario activo es abogado temporal de un equipo, vigente, activo y
  /// con el correo verificado.
  static bool get esMiembroVigente =>
      _correoVerificado && (membresia.value?.vigente ?? false);

  /// Pertenece a un equipo pero falta verificar el correo para activarlo.
  static bool get miembroPendienteDeVerificacion =>
      !_correoVerificado && (membresia.value?.vigente ?? false);

  /// El usuario activo administra su propio equipo (no es abogado temporal).
  static bool get esMaster => !esMiembroVigente;

  /// Equipo dueño de los expedientes que ve y crea el usuario activo: el del
  /// Master si es abogado temporal, o el propio.
  static String get equipoUidActivo {
    final m = membresia.value;
    if (m != null && esMiembroVigente) return m.masterUid;
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  /// El Master tiene todos los permisos; el abogado, los que le asignaron.
  static bool tienePermiso(PermisoEquipo permiso) {
    final m = membresia.value;
    if (m == null || !esMiembroVigente) return true;
    return m.permisos.contains(permiso);
  }

  // ===========================================================================
  // Gestión del equipo (Master Jurídico)
  // ===========================================================================

  static String get _masterUid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const EquipoJuridicoException(
        'Inicia sesión nuevamente para administrar tu equipo.',
      );
    }
    if (esMiembroVigente) {
      throw const EquipoJuridicoException(
        'Solo el titular de la suscripción puede administrar el equipo.',
      );
    }
    return uid;
  }

  static Future<List<MiembroEquipo>> listarMiembros() async {
    final snap = await _db
        .collection(coleccionMiembros)
        .where('masterUid', isEqualTo: _masterUid)
        .get()
        .timeout(const Duration(seconds: 10));
    final miembros =
        snap.docs.map((d) => MiembroEquipo.fromMap(d.data())).toList()..sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
        );
    return miembros;
  }

  static void _validarVigencia(DateTime vigenteHasta) {
    final ahora = DateTime.now();
    if (!vigenteHasta.isAfter(ahora)) {
      throw const EquipoJuridicoException(
        'La fecha de vencimiento debe ser posterior a hoy.',
      );
    }
    if (vigenteHasta.isAfter(ahora.add(vigenciaMaxima))) {
      throw const EquipoJuridicoException(
        'La vigencia de un abogado temporal no puede superar un año.',
      );
    }
  }

  /// Crea la cuenta del abogado en Firebase Auth (o vincula la existente) y
  /// su membresía en el equipo. Si la cuenta es nueva, se le envía un correo
  /// para que defina su propia contraseña: el Master nunca la conoce.
  static Future<ResultadoAltaMiembro> agregarMiembro({
    required String nombre,
    required String email,
    required Set<PermisoEquipo> permisos,
    required DateTime vigenteHasta,
  }) async {
    final masterUid = _masterUid;
    final correo = _normalizarCorreo(email);
    final nombreLimpio = SecurityService.sanitizePlainText(
      nombre,
      maxLength: 120,
    );
    if (nombreLimpio.isEmpty) {
      throw const EquipoJuridicoException('Ingresa el nombre del abogado.');
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(correo)) {
      throw const EquipoJuridicoException(
        'Ingresa un correo electrónico válido.',
      );
    }
    if (correo == _normalizarCorreo(AuthService.getActiveUserEmail())) {
      throw const EquipoJuridicoException(
        'Ese es tu propio correo: agrega el de otro abogado.',
      );
    }
    _validarVigencia(vigenteHasta);

    final actuales = await listarMiembros();
    if (actuales.any((m) => m.email == correo)) {
      throw const EquipoJuridicoException('Ese abogado ya está en tu equipo.');
    }
    if (actuales.length >= cupoMaximo) {
      throw const EquipoJuridicoException(
        'Tu plan permite hasta $cupoMaximo abogados. Quita uno para agregar otro.',
      );
    }
    // Primero la membresía: si el correo ya pertenece a otro equipo, las
    // reglas de Firestore rechazan la escritura (sería editar un documento
    // ajeno) y no se crea ninguna cuenta.
    final referencia = _db.collection(coleccionMiembros).doc(correo);
    try {
      await referencia.set(
        MiembroEquipo(
          email: correo,
          nombre: nombreLimpio,
          masterUid: masterUid,
          masterNombre: AuthService.getActiveUserDisplayName(),
          permisos: permisos,
          vigenteHasta: vigenteHasta,
        ).toMap(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const EquipoJuridicoException(
          'No se pudo agregar: ese correo ya pertenece al equipo de otra '
          'entidad, o tu cuenta no tiene activo el plan Equipo Jurídico.',
        );
      }
      throw EquipoJuridicoException(
        'No fue posible registrar al abogado (${e.code}).',
      );
    }

    final ResultadoAltaMiembro resultado;
    try {
      resultado = await _crearCuentaSinCerrarSesion(correo, nombreLimpio);
    } catch (_) {
      // Sin cuenta no hay acceso: se deshace la membresía.
      await referencia.delete().catchError((_) {});
      rethrow;
    }

    if (resultado == ResultadoAltaMiembro.cuentaCreada) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
      } catch (_) {
        throw const EquipoJuridicoException(
          'El abogado quedó en el equipo, pero no se pudo enviar el correo para '
          'definir su contraseña. Usa "Reenviar acceso".',
        );
      }
    }
    return resultado;
  }

  /// `createUserWithEmailAndPassword` inicia sesión con la cuenta nueva; en
  /// una instancia secundaria de Firebase eso no afecta la sesión del Master.
  /// La contraseña aleatoria nunca se muestra ni se guarda: el abogado la
  /// reemplaza con el enlace que le llega por correo.
  static Future<ResultadoAltaMiembro> _crearCuentaSinCerrarSesion(
    String correo,
    String nombre,
  ) async {
    final app = await Firebase.initializeApp(
      name: 'alta-equipo-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      final credencial = await auth.createUserWithEmailAndPassword(
        email: correo,
        password: '${SecurityService.generateSecureTokenHex(18)}Aa!9',
      );
      await credencial.user?.updateDisplayName(nombre);
      await auth.signOut();
      return ResultadoAltaMiembro.cuentaCreada;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return ResultadoAltaMiembro.cuentaExistenteVinculada;
      }
      throw EquipoJuridicoException(switch (e.code) {
        'invalid-email' => 'El correo no es válido.',
        'operation-not-allowed' =>
          'El acceso con correo y contraseña está deshabilitado en Firebase.',
        'too-many-requests' =>
          'Demasiadas solicitudes. Espera unos minutos e inténtalo de nuevo.',
        _ => 'No fue posible crear la cuenta del abogado (${e.code}).',
      });
    } finally {
      await app.delete();
    }
  }

  static Future<void> actualizarMiembro(MiembroEquipo miembro) async {
    _validarVigencia(miembro.vigenteHasta);
    if (miembro.masterUid != _masterUid) {
      throw const EquipoJuridicoException(
        'Ese abogado no pertenece a tu equipo.',
      );
    }
    await _db.collection(coleccionMiembros).doc(miembro.email).update({
      'nombre': miembro.nombre,
      'permisos': miembro.permisos.map((p) => p.codigo).toList(),
      'vigenteHasta': Timestamp.fromDate(miembro.vigenteHasta),
      'estado': miembro.estado,
    });
  }

  /// Quita al abogado del equipo: pierde el acceso de inmediato. Su cuenta
  /// de Contrata Legal se conserva (la app no puede borrar cuentas ajenas)
  /// y los expedientes que creó siguen en el equipo.
  static Future<void> quitarMiembro(MiembroEquipo miembro) async {
    if (miembro.masterUid != _masterUid) {
      throw const EquipoJuridicoException(
        'Ese abogado no pertenece a tu equipo.',
      );
    }
    await _db.collection(coleccionMiembros).doc(miembro.email).delete();
  }

  static Future<void> reenviarAcceso(MiembroEquipo miembro) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: miembro.email);
  }
}
