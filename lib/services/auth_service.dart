import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'consent_service.dart';
import 'payment_service.dart';

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
  static String _cachedPhotoData = '';
  static List<String> _cachedRoles = <String>['persona'];
  static bool _isLocalSessionActive = false;

  static const String _kUsersRegistryKey = 'registered_users_v1';

  /// Inicializa en memoria los datos de sesión guardados en SharedPreferences.
  static Future<void> restoreSessionFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacyRolesInRegistry(prefs);
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
        _cachedPhotoData = await _lookupStoredPhotoForEmail(prefs, fbEmail);
        _cachedRoles = await _lookupStoredRolesForEmail(prefs, fbEmail);
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
        _cachedPhotoData = await _lookupStoredPhotoForEmail(prefs, activeEmail);
        _cachedRoles = await _lookupStoredRolesForEmail(prefs, activeEmail);
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
        _cachedPhotoData = '';
        _cachedRoles = <String>['persona'];
        _isLocalSessionActive = false;
      }
      authStateVersion.value++;
    } catch (_) {}
  }

  /// Devuelve la lista de roles acumulados del usuario activo (por defecto `['persona']`).
  static List<String> getActiveUserRoles() {
    if (_cachedRoles.isEmpty) {
      return const <String>['persona'];
    }
    return List<String>.unmodifiable(_cachedRoles);
  }

  /// Devuelve la etiqueta visible de los roles activos (ej. `'Persona'` o `'Persona + Empresa licitante'`).
  static String getActiveUserRoleDisplayLabel() {
    return PaymentService.formatearEtiquetaRolesAcumulados(getActiveUserRoles());
  }

  /// Verifica si el usuario activo tiene un rol específico dentro de sus roles acumulados.
  static bool hasActiveRole(String rolId) {
    final clean = PaymentService.normalizarRolId(rolId);
    return getActiveUserRoles().contains(clean);
  }

  /// Verifica si el usuario activo cuenta con permiso para una funcionalidad de la plataforma.
  static bool hasPlatformPermission(String permiso) {
    return PaymentService.usuarioTienePermiso(
      rolesActivos: getActiveUserRoles(),
      permiso: permiso,
    );
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

  /// Devuelve la fuente de foto del usuario activo (Data URL subida, URL web o Firebase Auth).
  static String? getActiveUserPhotoSource() {
    if (_cachedPhotoData.trim().isNotEmpty) {
      return _cachedPhotoData.trim();
    }
    final fbPhoto = _auth.currentUser?.photoURL?.trim();
    if (fbPhoto != null && fbPhoto.isNotEmpty) {
      return fbPhoto;
    }
    return null;
  }

  /// Construye un [ImageProvider] listo para usar en avatares (Data URL base64 o NetworkImage).
  static ImageProvider<Object>? getActiveUserAvatarImageProvider() {
    final src = getActiveUserPhotoSource();
    if (src == null || src.isEmpty) return null;

    if (src.startsWith('data:image/') && src.contains(',')) {
      try {
        final base64Part = src.substring(src.indexOf(',') + 1);
        final bytes = base64Decode(base64Part);
        if (bytes.isNotEmpty) {
          return MemoryImage(bytes);
        }
      } catch (_) {
        return null;
      }
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return NetworkImage(src);
    }

    return null;
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

  static Future<void> _migrateLegacyRolesInRegistry(
    SharedPreferences prefs,
  ) async {
    try {
      final registry = await _loadRegistry(prefs);
      if (registry.isEmpty) return;
      bool changed = false;
      for (final entryKey in registry.keys.toList()) {
        final rawEntry = registry[entryKey];
        if (rawEntry is Map) {
          final map = Map<String, dynamic>.from(rawEntry);
          final normalizedRoles = _extractNormalizedRolesFromMap(map);
          final expectedLabel =
              PaymentService.formatearEtiquetaRolesAcumulados(normalizedRoles);
          final currentLabel = (map['rolEtiqueta'] ?? '').toString().trim();
          final currentRolesRaw = map['rolesActivos'];
          final bool needsMigration =
              currentLabel != expectedLabel ||
              currentRolesRaw is! List ||
              !listEquals(
                currentRolesRaw.map((e) => e.toString()).toList(),
                normalizedRoles,
              );
          if (needsMigration) {
            map['rolesActivos'] = normalizedRoles;
            map['rolPrincipal'] = normalizedRoles.first;
            map['rolEtiqueta'] = expectedLabel;
            registry[entryKey] = map;
            changed = true;
          }
        }
      }
      if (changed) {
        await prefs.setString(_kUsersRegistryKey, jsonEncode(registry));
      }
    } catch (_) {}
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

  static Future<String> _lookupStoredPhotoForEmail(
    SharedPreferences prefs,
    String email,
  ) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return '';
    final reg = await _loadRegistry(prefs);
    final entry = reg[clean];
    if (entry is Map) {
      return (entry['photoData'] ?? '').toString().trim();
    }
    return '';
  }

  static Future<List<String>> _lookupStoredRolesForEmail(
    SharedPreferences prefs,
    String email,
  ) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return <String>['persona'];
    final reg = await _loadRegistry(prefs);
    final entry = reg[clean];
    if (entry is Map) {
      return _extractNormalizedRolesFromMap(Map<String, dynamic>.from(entry));
    }
    return <String>['persona'];
  }

  static List<String> _extractNormalizedRolesFromMap(
    Map<String, dynamic> data,
  ) {
    final roles = <String>[];
    final rawList = data['rolesActivos'] ?? data['roles'];
    if (rawList is List) {
      for (final item in rawList) {
        final norm = PaymentService.normalizarRolId(item?.toString());
        if (!roles.contains(norm)) {
          roles.add(norm);
        }
      }
    }
    final singleRol = data['rol'] ?? data['rolPrincipal'] ?? data['rolSeleccionado'];
    if (singleRol != null && singleRol.toString().trim().isNotEmpty) {
      final norm = PaymentService.normalizarRolId(singleRol.toString());
      if (!roles.contains(norm)) {
        roles.add(norm);
      }
    }
    if (roles.isEmpty) {
      roles.add('persona');
    }
    return roles;
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

    final combinedRoles = <String>[
      ..._extractNormalizedRolesFromMap(existing),
      if (extraProfileData != null)
        ..._extractNormalizedRolesFromMap(extraProfileData),
    ];
    final deduplicatedRoles = <String>[];
    for (final r in combinedRoles) {
      if (!deduplicatedRoles.contains(r)) {
        deduplicatedRoles.add(r);
      }
    }
    if (deduplicatedRoles.isEmpty) {
      deduplicatedRoles.add('persona');
    }

    final merged = <String, dynamic>{
      ...existing,
      ...?extraProfileData,
      'email': cleanEmail,
      'displayName': resolvedName,
      'rolesActivos': deduplicatedRoles,
      'rolPrincipal': deduplicatedRoles.first,
      'rolEtiqueta':
          PaymentService.formatearEtiquetaRolesAcumulados(deduplicatedRoles),
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
    _cachedPhotoData = (merged['photoData'] ?? '').toString().trim();
    _cachedRoles = deduplicatedRoles;
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
      _cachedPhotoData = '';
      _cachedRoles = <String>['persona'];
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

  static String normalizeDocumentoDigits(String raw) {
    final onlyDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.isNotEmpty) return onlyDigits;
    return raw.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toLowerCase();
  }

  /// Verifica si el correo electrónico o el número de cédula/documento ya están
  /// vinculados a una cuenta existente (en registro local o en Firestore).
  static Future<({bool emailEnUso, bool documentoEnUso})>
      checkDuplicateCredentials({
    required String email,
    required String documento,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final normDoc = normalizeDocumentoDigits(documento);

    bool emailEnUso = false;
    bool documentoEnUso = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final registry = await _loadRegistry(prefs);

      if (cleanEmail.isNotEmpty && registry.containsKey(cleanEmail)) {
        emailEnUso = true;
      }

      for (final entry in registry.values) {
        if (entry is Map) {
          final entryEmail =
              (entry['email'] ?? '').toString().trim().toLowerCase();
          final entryDoc = normalizeDocumentoDigits(
            (entry['documento'] ?? entry['documentoNormalizado'] ?? '')
                .toString(),
          );
          if (cleanEmail.isNotEmpty && entryEmail == cleanEmail) {
            emailEnUso = true;
          }
          if (normDoc.length >= 5 && entryDoc.isNotEmpty && entryDoc == normDoc) {
            documentoEnUso = true;
          }
        }
      }
    } catch (_) {}

    // Consulta adicional en Firestore para cuentas creadas desde otros dispositivos
    if (!emailEnUso || !documentoEnUso) {
      try {
        final col = FirebaseFirestore.instance.collection(
          ConsentService.coleccionUsuarios,
        );
        if (!emailEnUso && cleanEmail.isNotEmpty) {
          final emailSnap = await col
              .where('email', isEqualTo: cleanEmail)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 3));
          if (emailSnap.docs.isNotEmpty) {
            emailEnUso = true;
          }
        }
        if (!documentoEnUso && normDoc.length >= 5) {
          final docSnap = await col
              .where('documentoNormalizado', isEqualTo: normDoc)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 3));
          if (docSnap.docs.isNotEmpty) {
            documentoEnUso = true;
          } else {
            final rawDocSnap = await col
                .where('documento', isEqualTo: documento.trim())
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 3));
            if (rawDocSnap.docs.isNotEmpty) {
              documentoEnUso = true;
            }
          }
        }
      } catch (_) {}
    }

    return (emailEnUso: emailEnUso, documentoEnUso: documentoEnUso);
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

    final cleanDocumento = (userData['documento'] ?? '')
        .toString()
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    final normDoc = normalizeDocumentoDigits(cleanDocumento);
    if (cleanDocumento.isEmpty || normDoc.length < 5) {
      throw const AuthServiceException(
        'El número de cédula o documento es obligatorio para crear la cuenta.',
      );
    }

    // Validación estricta de unicidad: no permite avanzar si la cédula o el correo ya están en uso
    final duplicados = await checkDuplicateCredentials(
      email: cleanEmail,
      documento: cleanDocumento,
    );
    if (duplicados.emailEnUso && duplicados.documentoEnUso) {
      throw AuthServiceException(
        'La cédula ($cleanDocumento) y el correo electrónico ($cleanEmail) ya se encuentran en uso. Debes cambiarlos por unos no vinculados para continuar.',
      );
    }
    if (duplicados.documentoEnUso) {
      throw AuthServiceException(
        'La cédula o documento ($cleanDocumento) ya se encuentra en uso en otra cuenta. Cámbiala por una que no haya sido registrada.',
      );
    }
    if (duplicados.emailEnUso) {
      throw AuthServiceException(
        'El correo electrónico ($cleanEmail) ya se encuentra en uso en otra cuenta. Cámbialo por uno que no haya sido registrado.',
      );
    }

    final nombres = (userData['nombres'] as String? ?? '').trim();
    final apellidos = (userData['apellidos'] as String? ?? '').trim();
    final displayName = '$nombres $apellidos'.trim().isNotEmpty
        ? '$nombres $apellidos'.trim()
        : _humanizeEmailPrefix(cleanEmail);
    final selectedRolId = PaymentService.normalizarRolId(
      (userData['rol'] ?? userData['rolPrincipal'] ?? 'persona').toString(),
    );
    final initialRoles = <String>[selectedRolId];
    final rolEtiqueta = PaymentService.formatearEtiquetaRolesAcumulados(
      initialRoles,
    );

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
        // Evidencia de la autorización en Firestore (auditoría SIC) + datos de perfil + rol
        try {
          await ConsentService.registrarAceptacionTratamientoDatos(
            uid: user.uid,
            email: cleanEmail,
            canal: 'registro_email',
          );
          await FirebaseFirestore.instance
              .collection(ConsentService.coleccionUsuarios)
              .doc(user.uid)
              .set({
                'email': cleanEmail,
                'nombres': nombres,
                'apellidos': apellidos,
                'displayName': displayName,
                'pais': (userData['pais'] ?? 'Colombia').toString().trim(),
                'telefono': (userData['telefono'] ?? '').toString().trim(),
                'documento': cleanDocumento,
                'documentoNormalizado': normDoc,
                'rolesActivos': initialRoles,
                'rolPrincipal': selectedRolId,
                'rolEtiqueta': rolEtiqueta,
                'pagoWompiPendiente': true,
                'actualizado_en': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true))
              .timeout(const Duration(seconds: 5));
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
          'documento': cleanDocumento,
          'documentoNormalizado': normDoc,
          'displayName': displayName,
          'password': password,
          'rolesActivos': initialRoles,
          'rolPrincipal': selectedRolId,
          'rolEtiqueta': rolEtiqueta,
          'aceptacion_datos': true,
          'version_politica': ConsentService.versionPolitica,
          'fecha_aceptacion_datos': DateTime.now().toIso8601String(),
        },
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        throw AuthServiceException(
          'El correo electrónico ($cleanEmail) ya se encuentra en uso en otra cuenta. Cámbialo por uno que no haya sido registrado.',
        );
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

  /// Obtiene los datos completos del perfil del usuario activo (registro local +
  /// Firebase Auth + respaldo en Firestore `usuarios/{uid}`).
  static Future<Map<String, dynamic>> getActiveUserProfile() async {
    final fbUser = _auth.currentUser;
    final activeEmail = getActiveUserEmail().trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);

    Map<String, dynamic> localData = <String, dynamic>{};
    if (activeEmail.isNotEmpty && registry[activeEmail] is Map) {
      localData = Map<String, dynamic>.from(registry[activeEmail] as Map);
    }

    // Si faltan campos del registro (ej. inició sesión en otro navegador), intentamos recuperar de Firestore
    if (fbUser != null &&
        ((localData['documento'] ?? '').toString().trim().isEmpty ||
            (localData['nombres'] ?? '').toString().trim().isEmpty)) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection(ConsentService.coleccionUsuarios)
            .doc(fbUser.uid)
            .get()
            .timeout(const Duration(seconds: 4));
        final remote = snap.data();
        if (remote != null) {
          for (final key in const [
            'nombres',
            'apellidos',
            'documento',
            'telefono',
            'pais',
            'aceptacion_datos',
            'version_politica',
          ]) {
            final currentVal = (localData[key] ?? '').toString().trim();
            if (currentVal.isEmpty && remote[key] != null) {
              localData[key] = remote[key];
            }
          }
        }
      } catch (_) {}
    }

    final fullDisplay = getActiveUserDisplayName().trim();
    String nombres = (localData['nombres'] ?? '').toString().trim();
    String apellidos = (localData['apellidos'] ?? '').toString().trim();

    if (nombres.isEmpty && fullDisplay.isNotEmpty && fullDisplay != 'Usuario') {
      final parts = fullDisplay.split(RegExp(r'\s+'));
      if (parts.length == 1) {
        nombres = parts.first;
      } else {
        final half = (parts.length / 2).ceil();
        nombres = parts.sublist(0, half).join(' ');
        apellidos = parts.sublist(half).join(' ');
      }
    }

    final bool hasPasswordProvider = fbUser == null
        ? true
        : (fbUser.providerData.isEmpty ||
              fbUser.providerData.any((p) => p.providerId == 'password'));

    final storedPhoto = (localData['photoData'] ?? '').toString().trim();
    if (storedPhoto.isNotEmpty && _cachedPhotoData.isEmpty) {
      _cachedPhotoData = storedPhoto;
    }

    final activeRoles = _extractNormalizedRolesFromMap(localData);
    _cachedRoles = activeRoles;

    return <String, dynamic>{
      'nombres': nombres,
      'apellidos': apellidos,
      'displayName': fullDisplay,
      'email': activeEmail,
      'documento': (localData['documento'] ?? '').toString().trim(),
      'telefono': (localData['telefono'] ?? '').toString().trim(),
      'pais': (localData['pais'] ?? '').toString().trim().isNotEmpty
          ? (localData['pais']).toString().trim()
          : 'Colombia',
      'photoURL': getActiveUserPhotoSource(),
      'hasPasswordProvider': hasPasswordProvider,
      'rolesActivos': activeRoles,
      'rolEtiqueta': PaymentService.formatearEtiquetaRolesAcumulados(
        activeRoles,
      ),
      'pagoWompiActivo': localData['pagoWompiActivo'] == true,
      'aceptacion_datos': localData['aceptacion_datos'] == true,
      'version_politica':
          (localData['version_politica'] ?? ConsentService.versionPolitica)
              .toString(),
    };
  }

  /// Valida criptográficamente el recibo de Wompi y asigna (o acumula) el rol pagado
  /// en la cuenta activa tanto en almacenamiento local como en Firestore.
  static Future<void> assignPaidRoleToActiveUser(
    WompiTransactionReceipt receipt,
  ) async {
    if (!PaymentService.verificarReciboTransaccion(receipt)) {
      throw const AuthServiceException(
        'No se pudo verificar la autenticidad e integridad criptográfica del pago en Wompi.',
      );
    }

    final activeEmail = getActiveUserEmail().trim().toLowerCase();
    if (activeEmail.isEmpty) {
      throw const AuthServiceException(
        'No se encontró una sesión de usuario activa para asignar el rol.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);
    final existing = registry[activeEmail] is Map
        ? Map<String, dynamic>.from(registry[activeEmail] as Map)
        : <String, dynamic>{};

    final currentRoles = _extractNormalizedRolesFromMap(existing);
    final paidRolId = PaymentService.normalizarRolId(receipt.rolId);
    if (!currentRoles.contains(paidRolId)) {
      currentRoles.add(paidRolId);
    }
    final rolEtiqueta = PaymentService.formatearEtiquetaRolesAcumulados(
      currentRoles,
    );

    final historyRaw = existing['historialPagosWompi'];
    final history = <Map<String, dynamic>>[
      if (historyRaw is List)
        for (final item in historyRaw)
          if (item is Map) Map<String, dynamic>.from(item),
      receipt.toMap(),
    ];

    existing['rolesActivos'] = currentRoles;
    existing['rolPrincipal'] = currentRoles.first;
    existing['rolEtiqueta'] = rolEtiqueta;
    existing['pagoWompiActivo'] = true;
    existing['pagoWompiPendiente'] = false;
    existing['ultimoPagoWompi'] = receipt.toMap();
    existing['historialPagosWompi'] = history;
    existing['updatedAt'] = DateTime.now().toIso8601String();
    registry[activeEmail] = existing;
    await prefs.setString(_kUsersRegistryKey, jsonEncode(registry));

    _cachedRoles = currentRoles;
    authStateVersion.value++;

    final fbUser = _auth.currentUser;
    if (fbUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection(ConsentService.coleccionUsuarios)
            .doc(fbUser.uid)
            .set({
              'rolesActivos': currentRoles,
              'rolPrincipal': currentRoles.first,
              'rolEtiqueta': rolEtiqueta,
              'pagoWompiActivo': true,
              'pagoWompiPendiente': false,
              'ultimoPagoWompi': receipt.toMap(),
              'actualizado_en': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));

        await FirebaseFirestore.instance
            .collection('pagos_wompi')
            .doc(receipt.transactionId)
            .set({
              ...receipt.toMap(),
              'uid': fbUser.uid,
              'email': activeEmail,
              'registrado_en': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint(
          'Aviso: El pago Wompi quedó validado y asignado localmente ($e).',
        );
      }
    }
  }

  /// Actualiza o restaura la foto de perfil del usuario activo (Data URL o URL).
  static Future<void> updateActiveUserPhoto(String? photoSource) async {
    final activeEmail = getActiveUserEmail().trim().toLowerCase();
    if (activeEmail.isEmpty) {
      throw const AuthServiceException(
        'No se encontró una sesión activa para actualizar la foto.',
      );
    }

    final cleanPhoto = (photoSource ?? '').trim();
    final fbUser = _auth.currentUser;
    if (fbUser != null &&
        (cleanPhoto.isEmpty ||
            cleanPhoto.startsWith('http://') ||
            cleanPhoto.startsWith('https://'))) {
      try {
        await fbUser.updatePhotoURL(cleanPhoto.isEmpty ? null : cleanPhoto);
        await fbUser.reload();
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);
    final existing = registry[activeEmail] is Map
        ? Map<String, dynamic>.from(registry[activeEmail] as Map)
        : <String, dynamic>{};
    existing['photoData'] = cleanPhoto;
    existing['updatedAt'] = DateTime.now().toIso8601String();
    registry[activeEmail] = existing;
    await prefs.setString(_kUsersRegistryKey, jsonEncode(registry));

    _cachedPhotoData = cleanPhoto;
    authStateVersion.value++;
  }

  /// Actualiza únicamente los datos editables del perfil (conservando bloqueados
  /// el correo electrónico y la cédula/documento).
  static Future<void> updateActiveUserProfile({
    required String nombres,
    required String apellidos,
    required String telefono,
    required String pais,
  }) async {
    final activeEmail = getActiveUserEmail().trim().toLowerCase();
    if (activeEmail.isEmpty) {
      throw const AuthServiceException(
        'No se encontró una sesión activa para actualizar el perfil.',
      );
    }

    final cleanNombres = nombres.trim();
    final cleanApellidos = apellidos.trim();
    final cleanTelefono = telefono.trim();
    final cleanPais = pais.trim().isNotEmpty ? pais.trim() : 'Colombia';
    final displayName = '$cleanNombres $cleanApellidos'.trim().isNotEmpty
        ? '$cleanNombres $cleanApellidos'.trim()
        : getActiveUserDisplayName();

    final fbUser = _auth.currentUser;
    if (fbUser != null) {
      try {
        await fbUser.updateDisplayName(displayName);
        await fbUser.reload();
      } catch (_) {}

      try {
        await FirebaseFirestore.instance
            .collection(ConsentService.coleccionUsuarios)
            .doc(fbUser.uid)
            .set({
              'nombres': cleanNombres,
              'apellidos': cleanApellidos,
              'displayName': displayName,
              'telefono': cleanTelefono,
              'pais': cleanPais,
              'actualizado_en': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    await _persistActiveSession(
      email: activeEmail,
      displayName: displayName,
      extraProfileData: {
        'nombres': cleanNombres,
        'apellidos': cleanApellidos,
        'telefono': cleanTelefono,
        'pais': cleanPais,
      },
    );
  }

  /// Cambia la contraseña del usuario activo validando primero su contraseña actual.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) {
      throw const AuthServiceException('Ingresa tu contraseña actual.');
    }
    if (newPassword.length < 6) {
      throw const AuthServiceException(
        'La nueva contraseña debe tener al menos 6 caracteres.',
      );
    }
    if (currentPassword == newPassword) {
      throw const AuthServiceException(
        'La nueva contraseña debe ser diferente a la contraseña actual.',
      );
    }

    final activeEmail = getActiveUserEmail().trim().toLowerCase();
    if (activeEmail.isEmpty) {
      throw const AuthServiceException(
        'No hay una sesión activa para cambiar la contraseña.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);
    final localEntry = registry[activeEmail] is Map
        ? Map<String, dynamic>.from(registry[activeEmail] as Map)
        : <String, dynamic>{};

    final fbUser = _auth.currentUser;
    if (fbUser != null &&
        fbUser.email?.trim().toLowerCase() == activeEmail) {
      final usesPassword = fbUser.providerData.isEmpty ||
          fbUser.providerData.any((p) => p.providerId == 'password');
      if (!usesPassword) {
        throw const AuthServiceException(
          'Tu cuenta inició sesión mediante proveedor externo (Google / Apple) y no utiliza clave local.',
        );
      }

      try {
        final credential = EmailAuthProvider.credential(
          email: activeEmail,
          password: currentPassword,
        );
        await fbUser.reauthenticateWithCredential(credential);
        await fbUser.updatePassword(newPassword);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'wrong-password' ||
            error.code == 'invalid-credential') {
          throw const AuthServiceException(
            'La contraseña actual ingresada no es correcta.',
          );
        }
        throw AuthServiceException(_messageFor(error));
      }
    } else {
      final savedPass = (localEntry['password'] ?? '').toString();
      if (savedPass.isEmpty || savedPass != currentPassword) {
        throw const AuthServiceException(
          'La contraseña actual ingresada no es correcta.',
        );
      }
    }

    // Sincronizamos el registro local para mantener consistencia
    localEntry['password'] = newPassword;
    localEntry['updatedAt'] = DateTime.now().toIso8601String();
    registry[activeEmail] = localEntry;
    await prefs.setString(_kUsersRegistryKey, jsonEncode(registry));
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
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión antes de cambiar tu contraseña.';
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
