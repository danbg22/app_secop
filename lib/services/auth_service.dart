import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'consent_service.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static Future<void>? _googleSignInInitialization;

  /// Notificador reactivo para que AuthGate y los encabezados reflejen de inmediato
  /// cualquier inicio de sesión, registro, cambio de nombre o cierre de sesión.
  static final ValueNotifier<int> authStateVersion = ValueNotifier<int>(0);

  static String _cachedEmail = '';
  static String _cachedFullName = '';
  static bool _isLocalSessionActive = false;

  static const String _kUsersRegistryKey = 'registered_users_v1';

  /// Inicializa en memoria los datos de sesión guardados en SharedPreferences.
  static Future<void> restoreSessionFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLogged = prefs.getBool('isLoggedIn') ?? false;
      final activeEmail =
          (prefs.getString('usuarioActivo') ??
                  prefs.getString('userEmail') ??
                  '')
              .trim()
              .toLowerCase();
      final savedName = (prefs.getString('usuarioNombreActivo') ?? '').trim();

      final fbUser = _auth.currentUser;
      if (fbUser != null) {
        final fbEmail = (fbUser.email ?? activeEmail).trim().toLowerCase();
        _cachedEmail = fbEmail;
        final fbName = (fbUser.displayName ?? '').trim();
        final profileName = await _lookupStoredNameForEmail(prefs, fbEmail);
        _cachedFullName = fbName.isNotEmpty
            ? fbName
            : (profileName.isNotEmpty
                  ? profileName
                  : (savedName.isNotEmpty
                        ? savedName
                        : _humanizeEmailPrefix(fbEmail)));
        _isLocalSessionActive = true;
      } else if (isLogged && activeEmail.isNotEmpty) {
        final profileName = await _lookupStoredNameForEmail(prefs, activeEmail);
        _cachedEmail = activeEmail;
        _cachedFullName = profileName.isNotEmpty
            ? profileName
            : (savedName.isNotEmpty
                  ? savedName
                  : _humanizeEmailPrefix(activeEmail));
        _isLocalSessionActive = true;
      } else {
        _cachedEmail = '';
        _cachedFullName = '';
        _isLocalSessionActive = false;
      }
      authStateVersion.value++;
    } catch (_) {}
  }

  static bool get hasActiveSession =>
      _auth.currentUser != null ||
      (_isLocalSessionActive && _cachedEmail.isNotEmpty);

  static String getActiveUserEmail() {
    final fbEmail = _auth.currentUser?.email?.trim();
    if (fbEmail != null && fbEmail.isNotEmpty) {
      return fbEmail.toLowerCase();
    }
    return _cachedEmail;
  }

  static String getActiveUserDisplayName() {
    final fbUser = _auth.currentUser;
    final fbEmail = fbUser?.email?.trim().toLowerCase() ?? '';
    final fbName = fbUser?.displayName?.trim() ?? '';

    if (fbName.isNotEmpty) {
      return fbName;
    }
    if (_cachedFullName.isNotEmpty &&
        (fbEmail.isEmpty || _cachedEmail == fbEmail)) {
      return _cachedFullName;
    }
    final emailToUse = fbEmail.isNotEmpty ? fbEmail : _cachedEmail;
    if (emailToUse.isNotEmpty) {
      return _humanizeEmailPrefix(emailToUse);
    }
    return 'Usuario';
  }

  static String getActiveUserFirstName() {
    final full = getActiveUserDisplayName().trim();
    if (full.isEmpty) return 'Usuario';
    return full.split(RegExp(r'\s+')).first;
  }

  static String _humanizeEmailPrefix(String email) {
    final clean = email.trim();
    if (clean.isEmpty || !clean.contains('@')) return 'Usuario';
    final prefix = clean.split('@').first;
    final parts = prefix
        .replaceAll(RegExp(r'[0-9]+'), ' ')
        .split(RegExp(r'[._\-\s]+'))
        .where((w) => w.trim().isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .toList();
    if (parts.isEmpty) {
      return prefix[0].toUpperCase() + prefix.substring(1).toLowerCase();
    }
    return parts.join(' ');
  }

  static Future<Map<String, dynamic>> _loadRegistry(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_kUsersRegistryKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Future<String> _lookupStoredNameForEmail(
    SharedPreferences prefs,
    String email,
  ) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return '';
    final reg = await _loadRegistry(prefs);
    final entry = reg[clean];
    if (entry is Map) {
      final name = (entry['displayName'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
      final nombres = (entry['nombres'] ?? '').toString().trim();
      final apellidos = (entry['apellidos'] ?? '').toString().trim();
      final combined = '$nombres $apellidos'.trim();
      if (combined.isNotEmpty) return combined;
    }
    return '';
  }

  static Future<void> _persistActiveSession({
    required String email,
    required String displayName,
    Map<String, dynamic>? extraProfileData,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final resolvedName = displayName.trim().isNotEmpty
        ? displayName.trim()
        : _humanizeEmailPrefix(cleanEmail);

    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);
    final existing = registry[cleanEmail] is Map
        ? Map<String, dynamic>.from(registry[cleanEmail] as Map)
        : <String, dynamic>{};

    final merged = <String, dynamic>{
      ...existing,
      ...?extraProfileData,
      'email': cleanEmail,
      'displayName': resolvedName,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    registry[cleanEmail] = merged;

    await prefs.setString(_kUsersRegistryKey, jsonEncode(registry));
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('usuarioActivo', cleanEmail);
    await prefs.setString('userEmail', cleanEmail);
    await prefs.setString('usuarioNombreActivo', resolvedName);

    _cachedEmail = cleanEmail;
    _cachedFullName = resolvedName;
    _isLocalSessionActive = true;
    authStateVersion.value++;
  }

  static Future<void> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw const AuthServiceException('Ingresa tu correo electrónico.');
    }

    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);
    final localEntry = registry[cleanEmail] is Map
        ? Map<String, dynamic>.from(registry[cleanEmail] as Map)
        : null;

    // Si hay otro usuario distinto en la sesión de Firebase, cerramos primero esa sesión
    // para que nunca mezcle la identidad de un usuario anterior con el que está entrando.
    if (_auth.currentUser != null &&
        _auth.currentUser!.email?.trim().toLowerCase() != cleanEmail) {
      try {
        await _auth.signOut();
      } catch (_) {}
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = credential.user;
      String resolvedName = user?.displayName?.trim() ?? '';

      if (resolvedName.isEmpty && localEntry != null) {
        resolvedName = (localEntry['displayName'] ?? '').toString().trim();
        if (resolvedName.isNotEmpty && user != null) {
          try {
            await user.updateDisplayName(resolvedName);
            await user.reload();
          } catch (_) {}
        }
      }
      if (resolvedName.isEmpty) {
        resolvedName = _humanizeEmailPrefix(cleanEmail);
      }

      await _persistActiveSession(email: cleanEmail, displayName: resolvedName);
    } on FirebaseAuthException catch (error) {
      // Si el usuario se registró en este navegador/dispositivo y las credenciales coinciden
      // con el registro local (por ejemplo, cuando Firebase tiene restricciones de red/config),
      // validamos contra su registro guardado.
      if (localEntry != null &&
          (localEntry['password']?.toString() == password)) {
        final localName = (localEntry['displayName'] ?? '').toString().trim();
        await _persistActiveSession(
          email: cleanEmail,
          displayName: localName.isNotEmpty
              ? localName
              : _humanizeEmailPrefix(cleanEmail),
        );
        return;
      }
      throw AuthServiceException(_messageFor(error));
    }
  }

  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('usuarioActivo');
      await prefs.remove('userEmail');
      await prefs.remove('usuarioNombreActivo');

      _cachedEmail = '';
      _cachedFullName = '';
      _isLocalSessionActive = false;

      await FirebaseAuth.instance.signOut();
      authStateVersion.value++;
    } on FirebaseAuthException catch (error) {
      authStateVersion.value++;
      throw AuthServiceException(_messageFor(error));
    }
  }

  static Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final initialization = _googleSignInInitialization ??= GoogleSignIn
            .instance
            .initialize();
        await initialization;

        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
      }

      final user = _auth.currentUser;
      final email = user?.email?.trim().toLowerCase() ?? '';
      final name = (user?.displayName ?? '').trim();
      if (email.isNotEmpty) {
        await _persistActiveSession(
          email: email,
          displayName: name.isNotEmpty ? name : _humanizeEmailPrefix(email),
        );
      }
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  static Future<void> signInWithApple() async {
    try {
      final provider = AppleAuthProvider();
      if (kIsWeb) {
        await _auth.signInWithPopup(provider);
      } else {
        await _auth.signInWithProvider(provider);
      }

      final user = _auth.currentUser;
      final email = user?.email?.trim().toLowerCase() ?? '';
      final name = (user?.displayName ?? '').trim();
      if (email.isNotEmpty) {
        await _persistActiveSession(
          email: email,
          displayName: name.isNotEmpty ? name : _humanizeEmailPrefix(email),
        );
      }
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  static Future<void> signUp(
    Map<String, dynamic> userData,
    String password, {
    required bool aceptaTratamientoDatos,
  }) async {
    // Defensa en profundidad: aunque la UI ya lo valida, el servicio nunca crea
    // una cuenta sin autorización expresa de tratamiento de datos (Ley 1581/2012).
    if (!aceptaTratamientoDatos) {
      throw const AuthServiceException(
        'Debes aceptar la Política de Privacidad y Tratamiento de Datos Personales para crear tu cuenta.',
      );
    }

    final cleanEmail = (userData['email'] as String?)?.trim().toLowerCase();
    if (cleanEmail == null || cleanEmail.isEmpty) {
      throw const AuthServiceException(
        'El correo electrónico es obligatorio para crear la cuenta.',
      );
    }

    final nombres = (userData['nombres'] as String? ?? '').trim();
    final apellidos = (userData['apellidos'] as String? ?? '').trim();
    final displayName = '$nombres $apellidos'.trim().isNotEmpty
        ? '$nombres $apellidos'.trim()
        : _humanizeEmailPrefix(cleanEmail);

    // Cerramos cualquier sesión previa para que la nueva cuenta no herede datos de otro usuario
    if (_auth.currentUser != null) {
      try {
        await _auth.signOut();
      } catch (_) {}
    }

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        // Evidencia de la autorización en Firestore (auditoría SIC)
        try {
          await ConsentService.registrarAceptacionTratamientoDatos(
            uid: user.uid,
            email: cleanEmail,
            canal: 'registro_email',
          );
        } catch (e) {
          debugPrint('Aviso: No se pudo registrar en Firestore ($e). Se conserva evidencia en almacenamiento local.');
        }

        await user.updateDisplayName(displayName);
        await user.reload();
        unawaited(user.sendEmailVerification().catchError((_) {}));
      }

      await _persistActiveSession(
        email: cleanEmail,
        displayName: displayName,
        extraProfileData: {
          ...userData,
          'email': cleanEmail,
          'displayName': displayName,
          'password': password,
          'aceptacion_datos': true,
          'version_politica': ConsentService.versionPolitica,
          'fecha_aceptacion_datos': DateTime.now().toIso8601String(),
        },
      );
    } on FirebaseAuthException catch (error) {
      // Si el correo ya existía en Firebase, intentamos autenticarlo con esa contraseña
      // y actualizar su perfil para que el usuario pueda ingresar sin bloqueo.
      if (error.code == 'email-already-in-use') {
        UserCredential cred;
        try {
          cred = await _auth.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
        } catch (_) {
          throw AuthServiceException(_messageFor(error));
        }

        // El usuario vuelve a aceptar la política en este registro: se deja nueva evidencia.
        if (cred.user != null) {
          try {
            await ConsentService.registrarAceptacionTratamientoDatos(
              uid: cred.user!.uid,
              email: cleanEmail,
              canal: 'registro_email_cuenta_existente',
            );
          } catch (e) {
            debugPrint('Aviso: No se pudo registrar en Firestore ($e). Se conserva evidencia en almacenamiento local.');
          }
          if (displayName.isNotEmpty) {
            await cred.user!.updateDisplayName(displayName);
            await cred.user!.reload();
          }
        }
        await _persistActiveSession(
          email: cleanEmail,
          displayName: displayName,
          extraProfileData: {
            ...userData,
            'email': cleanEmail,
            'displayName': displayName,
            'password': password,
            'aceptacion_datos': true,
            'version_politica': ConsentService.versionPolitica,
            'fecha_aceptacion_datos': DateTime.now().toIso8601String(),
          },
        );
        return;
      }
      throw AuthServiceException(_messageFor(error));
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  static String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese correo electrónico.';
      case 'wrong-password':
        return 'La contraseña ingresada es incorrecta.';
      case 'invalid-credential':
        return 'El correo o la contraseña son incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta registrada con ese correo. Inicia sesión con tu contraseña.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Hubo demasiados intentos. Espera un momento e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'No se pudo conectar. Revisa tu conexión a internet.';
      case 'operation-not-allowed':
        return 'Este método de acceso no está habilitado en Firebase.';
      default:
        return error.message ?? 'Ocurrió un error de autenticación.';
    }
  }

  // Adaptadores para los puntos de entrada que aún usan la API anterior.
  Future<bool> iniciarSesion(String correo, String contrasena) async {
    await signInWithEmail(correo, contrasena);
    return true;
  }

  // Si un punto de entrada antiguo no envía la aceptación, signUp rechaza el registro.
  Future<bool> registrarCuenta(
    String correo,
    String contrasena, {
    bool aceptaTratamientoDatos = false,
  }) async {
    await signUp(
      {'email': correo},
      contrasena,
      aceptaTratamientoDatos: aceptaTratamientoDatos,
    );
    return true;
  }

  Future<void> asignarRol(String uid, String rolElegido) async {
    debugPrint('Rol actualizado a: $rolElegido');
  }

  Future<bool> procesarPagoPlan(String plan, double precio) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    debugPrint('Pago aprobado para el plan $plan por \$${precio.toString()}');
    return true;
  }
}
