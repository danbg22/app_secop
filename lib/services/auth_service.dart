import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_access.dart';
import 'consent_service.dart';
import 'payment_service.dart';
import 'security_service.dart';

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
  static bool _cachedPaymentPending = false;
  static String _cachedPendingRoleId = 'persona';
  static bool _isLocalSessionActive = false;

  static const String _kUsersRegistryKey = 'registered_users_v1';
  static const String _kRolesSealMigrationFlag = '_sec_roles_seal_migrated_v1';
  static const String _kPaymentSealMigrationFlag =
      '_sec_payment_seal_migrated_v1';
  static const String coleccionIndicesUnicidad = 'indices_unicidad';

  /// Inicializa y verifica criptográficamente en memoria los datos de sesión
  /// guardados en SharedPreferences (bloqueando suplantación por `localStorage`).
  static Future<void> restoreSessionFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacyVaultAndRolesInRegistry(prefs);

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
        var state = await _lookupVerifiedAccountStateForEmail(prefs, fbEmail);

        // Si existe documento en Firestore con pago pendiente sin liquidar,
        // prevalece el bloqueo hasta que exista pago aprobado en Wompi.
        try {
          final snap = await FirebaseFirestore.instance
              .collection(ConsentService.coleccionUsuarios)
              .doc(fbUser.uid)
              .get()
              .timeout(const Duration(seconds: 3));
          final remote = snap.data();
          if (remote != null) {
            final remotePending =
                remote['pagoWompiPendiente'] == true &&
                remote['pagoWompiActivo'] != true;
            final remoteReqRole = PaymentService.normalizarRolId(
              (remote['rolSolicitadoRegistro'] ?? state.pendingRoleId)
                  .toString(),
            );
            if (remotePending) {
              state = (
                roles: <String>[],
                paymentPending: true,
                pendingRoleId: remoteReqRole,
              );
            } else if (remote['pagoWompiActivo'] == true &&
                remote['rolesActivos'] is List) {
              final remoteRoles = _extractNormalizedRolesFromMap(
                remote,
                fallbackToPersonaWhenEmpty: false,
              );
              if (remoteRoles.isNotEmpty) {
                state = (
                  roles: remoteRoles,
                  paymentPending: false,
                  pendingRoleId: remoteReqRole,
                );
              }
            }
          }
        } catch (_) {}

        _cachedRoles = state.roles;
        _cachedPaymentPending = state.paymentPending;
        _cachedPendingRoleId = state.pendingRoleId;
        _cachedFullName = fbName.isNotEmpty
            ? fbName
            : (profileName.isNotEmpty
                  ? profileName
                  : (savedName.isNotEmpty
                        ? savedName
                        : _humanizeEmailPrefix(fbEmail)));
        _isLocalSessionActive = true;
        await SecurityService.sealActiveSession(
          prefs: prefs,
          email: fbEmail,
          roles: _cachedRoles,
          paymentPending: _cachedPaymentPending,
          pendingRoleId: _cachedPendingRoleId,
        );
      } else if (isLogged && activeEmail.isNotEmpty) {
        final state = await _lookupVerifiedAccountStateForEmail(
          prefs,
          activeEmail,
        );
        final isSealValid = await SecurityService.verifyAndTouchSessionSeal(
          prefs: prefs,
          expectedEmail: activeEmail,
          expectedRoles: state.roles,
          expectedPaymentPending: state.paymentPending,
          expectedPendingRoleId: state.pendingRoleId,
        );

        if (isSealValid) {
          final profileName = await _lookupStoredNameForEmail(
            prefs,
            activeEmail,
          );
          _cachedPhotoData = await _lookupStoredPhotoForEmail(
            prefs,
            activeEmail,
          );
          _cachedRoles = state.roles;
          _cachedPaymentPending = state.paymentPending;
          _cachedPendingRoleId = state.pendingRoleId;
          _cachedEmail = activeEmail;
          _cachedFullName = profileName.isNotEmpty
              ? profileName
              : (savedName.isNotEmpty
                    ? savedName
                    : _humanizeEmailPrefix(activeEmail));
          _isLocalSessionActive = true;
        } else {
          // Sesión manipulada en almacenamiento local o expirada por TTL/inactividad:
          // se revoca inmediatamente por seguridad.
          await _purgeSessionFlags(prefs);
          _resetInMemorySession();
        }
      } else {
        await SecurityService.clearSessionSeal(prefs);
        _resetInMemorySession();
      }
      authStateVersion.value++;
    } catch (_) {
      _resetInMemorySession();
    }
  }

  static void _resetInMemorySession() {
    _cachedEmail = '';
    _cachedFullName = '';
    _cachedPhotoData = '';
    _cachedRoles = <String>['persona'];
    _cachedPaymentPending = false;
    _cachedPendingRoleId = 'persona';
    _isLocalSessionActive = false;
  }

  static Future<void> _purgeSessionFlags(SharedPreferences prefs) async {
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('usuarioActivo');
    await prefs.remove('userEmail');
    await prefs.remove('usuarioNombreActivo');
    await SecurityService.clearSessionSeal(prefs);
  }

  /// Indica si la cuenta autenticada tiene un pago inicial obligatorio pendiente
  /// en Wompi y por lo tanto TIENE BLOQUEADO el acceso al panel principal `/home`.
  static bool get requiresMandatoryWompiPayment =>
      hasActiveSession && _cachedPaymentPending && !isActiveUserAdmin;

  /// Indica si existe sesión autenticada Y con pago validado/autorizado para usar la app.
  static bool get hasAuthorizedPlatformAccess =>
      hasActiveSession && (!_cachedPaymentPending || isActiveUserAdmin);

  /// Cuenta administradora (ver [AdminAccess]): requiere sesión real de
  /// Firebase con el correo verificado.
  static bool get isActiveUserAdmin {
    final user = _auth.currentUser;
    return user != null &&
        user.emailVerified &&
        AdminAccess.esAdministrador(user.email);
  }

  /// Correo administrador que aún no está verificado en Firebase: el acceso
  /// de administrador se concede en cuanto se verifique.
  static bool get adminPendienteDeVerificacion {
    final user = _auth.currentUser;
    return user != null &&
        !user.emailVerified &&
        AdminAccess.esAdministrador(user.email);
  }

  /// Vuelve a leer el estado de verificación del correo desde Firebase (el
  /// navegador lo conserva en caché hasta recargar la sesión).
  static Future<void> refrescarVerificacionCorreo() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    try {
      await user.reload().timeout(const Duration(seconds: 6));
    } catch (_) {}
    authStateVersion.value++;
  }

  /// Al abrir la app, Firebase restaura la sesión con el estado de
  /// verificación guardado; se refresca una vez restaurada.
  static void refrescarVerificacionAlIniciar() {
    unawaited(
      _auth.authStateChanges().first.then((_) => refrescarVerificacionCorreo()),
    );
  }

  static Future<void> reenviarVerificacionCorreo() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException(
        'Inicia sesión nuevamente para reenviar la verificación.',
      );
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  /// Rol elegido durante el registro que está pendiente de activación en Wompi.
  static String getPendingRegistrationRoleId() =>
      PaymentService.normalizarRolId(_cachedPendingRoleId);

  /// Devuelve la lista de roles acumulados del usuario activo.
  /// Si el pago obligatorio está pendiente, devuelve lista vacía (cero permisos).
  static List<String> getActiveUserRoles() {
    if (isActiveUserAdmin) {
      return AdminAccess.todosLosRoles;
    }
    if (requiresMandatoryWompiPayment) {
      return const <String>[];
    }
    if (_cachedRoles.isEmpty) {
      return const <String>['persona'];
    }
    return List<String>.unmodifiable(_cachedRoles);
  }

  /// Devuelve la etiqueta visible de los roles activos (ej. `'Persona'` o `'Persona + Empresa licitante'`).
  static String getActiveUserRoleDisplayLabel() {
    if (isActiveUserAdmin) return 'Administrador · Todos los roles';
    return PaymentService.formatearEtiquetaRolesAcumulados(
      getActiveUserRoles(),
    );
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

  /// Identificador opaco derivado del usuario activo para aislar datos locales
  /// (PQRS, favoritos) en navegadores compartidos sin filtrar su correo.
  static String getActiveUserStorageScope() {
    final uid = _auth.currentUser?.uid ?? '';
    final email = getActiveUserEmail();
    final key = uid.isNotEmpty ? uid : email;
    return SecurityService.deriveUserStorageScope(key);
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

  /// Devuelve la fuente de foto del usuario activo (Data URL raster validado o URL HTTPS).
  static String? getActiveUserPhotoSource() {
    if (_cachedPhotoData.trim().isNotEmpty) {
      return _cachedPhotoData.trim();
    }
    final fbPhoto = _auth.currentUser?.photoURL?.trim();
    if (fbPhoto != null && fbPhoto.isNotEmpty) {
      final safeUri = SecurityService.validateSafeExternalImageUrl(fbPhoto);
      if (safeUri != null) {
        return safeUri.toString();
      }
    }
    return null;
  }

  /// Construye un [ImageProvider] seguro validando Magic Bytes (PNG/JPEG/WEBP/GIF)
  /// y URLs externas HTTPS públicas (bloqueando SVG XSS y Mixed Content).
  static ImageProvider<Object>? getActiveUserAvatarImageProvider() {
    final src = getActiveUserPhotoSource();
    if (src == null || src.isEmpty) return null;

    if (src.startsWith('data:image/')) {
      final safeBytes = SecurityService.decodeSafeRasterDataUrl(src);
      if (safeBytes != null && safeBytes.isNotEmpty) {
        return MemoryImage(safeBytes);
      }
      return null;
    }

    final safeUri = SecurityService.validateSafeExternalImageUrl(src);
    if (safeUri != null) {
      return NetworkImage(safeUri.toString());
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
      return prefix.isNotEmpty
          ? prefix[0].toUpperCase() + prefix.substring(1).toLowerCase()
          : 'Usuario';
    }
    return parts.join(' ');
  }

  /// Migra automáticamente cualquier contraseña heredada en texto claro hacia
  /// PBKDF2-HMAC-SHA256 con sal CSPRNG y sella criptográficamente los roles.
  static Future<void> _migrateLegacyVaultAndRolesInRegistry(
    SharedPreferences prefs,
  ) async {
    try {
      final registry = await _loadRegistry(prefs);
      final initialSealMigrationDone =
          prefs.getBool(_kRolesSealMigrationFlag) ?? false;
      final paymentSealMigrationDone =
          prefs.getBool(_kPaymentSealMigrationFlag) ?? false;
      if (registry.isEmpty) {
        if (!initialSealMigrationDone) {
          await prefs.setBool(_kRolesSealMigrationFlag, true);
        }
        if (!paymentSealMigrationDone) {
          await prefs.setBool(_kPaymentSealMigrationFlag, true);
        }
        return;
      }

      bool changed = false;
      for (final entryKey in registry.keys.toList()) {
        final rawEntry = registry[entryKey];
        if (rawEntry is Map) {
          final map = Map<String, dynamic>.from(rawEntry);
          final emailKey = (map['email'] ?? entryKey)
              .toString()
              .trim()
              .toLowerCase();

          // 1. Purga definitiva de contraseñas en texto claro (CWE-256 / CWE-312)
          if (map.containsKey('password')) {
            final legacyCleartext = (map.remove('password') ?? '').toString();
            if (legacyCleartext.isNotEmpty &&
                (map['passwordVerifier'] ?? '').toString().isEmpty) {
              map.addAll(
                SecurityService.createPasswordVerifier(legacyCleartext),
              );
            }
            changed = true;
          }

          // 2. Sanitización de avatares almacenados previamente
          final rawPhoto = (map['photoData'] ?? '').toString().trim();
          if (rawPhoto.isNotEmpty) {
            final validDataUrl =
                rawPhoto.startsWith('data:image/') &&
                SecurityService.decodeSafeRasterDataUrl(rawPhoto) != null;
            final validHttpsUrl =
                SecurityService.validateSafeExternalImageUrl(rawPhoto) != null;
            if (!validDataUrl && !validHttpsUrl) {
              map['photoData'] = '';
              changed = true;
            }
          }

          // 3. Verificación o sellado de integridad de roles y pago obligatorio Wompi
          bool payPending =
              map['pagoWompiPendiente'] == true &&
              map['pagoWompiActivo'] != true;
          bool payActive = map['pagoWompiActivo'] == true;
          final requestedRole = PaymentService.normalizarRolId(
            (map['rolSolicitadoRegistro'] ??
                    map['rolPrincipal'] ??
                    map['rol'] ??
                    'persona')
                .toString(),
          );

          var normalizedRoles = _extractNormalizedRolesFromMap(
            map,
            fallbackToPersonaWhenEmpty: !payPending,
          );
          if (payPending) {
            normalizedRoles = <String>[];
          }

          final existingSeal = map['rolesSeal']?.toString();
          final existingPaySeal = map['paymentStateSeal']?.toString();

          if (!initialSealMigrationDone && existingSeal == null) {
            map['rolesSeal'] = await SecurityService.computeUserRolesSeal(
              prefs: prefs,
              email: emailKey,
              roles: normalizedRoles,
            );
            changed = true;
          } else {
            final validSeal = await SecurityService.verifyUserRolesSeal(
              prefs: prefs,
              email: emailKey,
              roles: normalizedRoles,
              seal: existingSeal,
            );
            if (!validSeal) {
              // Si alguien alteró `rolesActivos` desde DevTools, se bloquea y exige validación.
              payPending = true;
              payActive = false;
              normalizedRoles = <String>[];
              map['pagoWompiPendiente'] = true;
              map['pagoWompiActivo'] = false;
              map['rolesSeal'] = await SecurityService.computeUserRolesSeal(
                prefs: prefs,
                email: emailKey,
                roles: normalizedRoles,
              );
              changed = true;
            }
          }

          if (!paymentSealMigrationDone && existingPaySeal == null) {
            map['pagoWompiPendiente'] = payPending;
            map['pagoWompiActivo'] = payActive;
            map['rolSolicitadoRegistro'] = requestedRole;
            map['paymentStateSeal'] =
                await SecurityService.computePaymentStateSeal(
                  prefs: prefs,
                  email: emailKey,
                  paymentPending: payPending,
                  paymentActive: payActive,
                  requestedRoleId: requestedRole,
                  roles: normalizedRoles,
                );
            changed = true;
          } else {
            final validPaySeal = await SecurityService.verifyPaymentStateSeal(
              prefs: prefs,
              email: emailKey,
              paymentPending: payPending,
              paymentActive: payActive,
              requestedRoleId: requestedRole,
              roles: normalizedRoles,
              seal: existingPaySeal,
            );
            if (!validPaySeal) {
              // Intento de evadir pago editando `pagoWompiPendiente` en localStorage:
              payPending = true;
              payActive = false;
              normalizedRoles = <String>[];
              map['pagoWompiPendiente'] = true;
              map['pagoWompiActivo'] = false;
              map['rolSolicitadoRegistro'] = requestedRole;
              map['rolesSeal'] = await SecurityService.computeUserRolesSeal(
                prefs: prefs,
                email: emailKey,
                roles: normalizedRoles,
              );
              map['paymentStateSeal'] =
                  await SecurityService.computePaymentStateSeal(
                    prefs: prefs,
                    email: emailKey,
                    paymentPending: true,
                    paymentActive: false,
                    requestedRoleId: requestedRole,
                    roles: normalizedRoles,
                  );
              changed = true;
            }
          }

          final expectedLabel = PaymentService.formatearEtiquetaRolesAcumulados(
            normalizedRoles,
          );
          final currentLabel = (map['rolEtiqueta'] ?? '').toString().trim();
          final currentRolesRaw = map['rolesActivos'];
          final bool needsRoleSync =
              currentLabel != expectedLabel ||
              currentRolesRaw is! List ||
              !listEquals(
                currentRolesRaw.map((e) => e.toString()).toList(),
                normalizedRoles,
              );
          if (needsRoleSync) {
            map['rolesActivos'] = normalizedRoles;
            map['rolPrincipal'] = normalizedRoles.isNotEmpty
                ? normalizedRoles.first
                : requestedRole;
            map['rolEtiqueta'] = expectedLabel;
            changed = true;
          }
          registry[entryKey] = map;
        }
      }

      if (changed) {
        await prefs.setString(_kUsersRegistryKey, jsonEncode(registry));
      }
      if (!initialSealMigrationDone) {
        await prefs.setBool(_kRolesSealMigrationFlag, true);
      }
      if (!paymentSealMigrationDone) {
        await prefs.setBool(_kPaymentSealMigrationFlag, true);
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
      final raw = (entry['photoData'] ?? '').toString().trim();
      if (raw.startsWith('data:image/') &&
          SecurityService.decodeSafeRasterDataUrl(raw) != null) {
        return raw;
      }
      final safeUri = SecurityService.validateSafeExternalImageUrl(raw);
      if (safeUri != null) return safeUri.toString();
    }
    return '';
  }

  static Future<
    ({List<String> roles, bool paymentPending, String pendingRoleId})
  >
  _lookupVerifiedAccountStateForEmail(
    SharedPreferences prefs,
    String email,
  ) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) {
      return (
        roles: <String>['persona'],
        paymentPending: false,
        pendingRoleId: 'persona',
      );
    }
    final reg = await _loadRegistry(prefs);
    final entry = reg[clean];
    if (entry is Map) {
      final map = Map<String, dynamic>.from(entry);
      final payPending =
          map['pagoWompiPendiente'] == true && map['pagoWompiActivo'] != true;
      final payActive = map['pagoWompiActivo'] == true;
      final reqRole = PaymentService.normalizarRolId(
        (map['rolSolicitadoRegistro'] ??
                map['rolPrincipal'] ??
                map['rol'] ??
                'persona')
            .toString(),
      );
      final roles = payPending
          ? <String>[]
          : _extractNormalizedRolesFromMap(
              map,
              fallbackToPersonaWhenEmpty: true,
            );

      final validRoles = await SecurityService.verifyUserRolesSeal(
        prefs: prefs,
        email: clean,
        roles: roles,
        seal: map['rolesSeal']?.toString(),
      );
      final validPay = await SecurityService.verifyPaymentStateSeal(
        prefs: prefs,
        email: clean,
        paymentPending: payPending,
        paymentActive: payActive,
        requestedRoleId: reqRole,
        roles: roles,
        seal: map['paymentStateSeal']?.toString(),
      );

      if (validRoles && validPay) {
        return (
          roles: roles,
          paymentPending: payPending,
          pendingRoleId: reqRole,
        );
      }
      // Si el sello fue alterado manualmente en localStorage, bloquea acceso y exige pago.
      return (roles: <String>[], paymentPending: true, pendingRoleId: reqRole);
    }
    return (
      roles: <String>['persona'],
      paymentPending: false,
      pendingRoleId: 'persona',
    );
  }

  static Future<List<String>> _lookupVerifiedRolesForEmail(
    SharedPreferences prefs,
    String email,
  ) async {
    final state = await _lookupVerifiedAccountStateForEmail(prefs, email);
    return state.roles;
  }

  static List<String> _extractNormalizedRolesFromMap(
    Map<String, dynamic> data, {
    bool fallbackToPersonaWhenEmpty = true,
  }) {
    final roles = <String>[];
    final hasExplicitList = data['rolesActivos'] is List || data['roles'] is List;
    final rawList = data['rolesActivos'] ?? data['roles'];
    if (rawList is List) {
      for (final item in rawList) {
        final rawStr = (item ?? '').toString().trim();
        if (rawStr.isEmpty) continue;
        final norm = PaymentService.normalizarRolId(rawStr);
        if (!roles.contains(norm)) {
          roles.add(norm);
        }
      }
    }
    if (!hasExplicitList) {
      final singleRol =
          data['rol'] ?? data['rolPrincipal'] ?? data['rolSeleccionado'];
      if (singleRol != null && singleRol.toString().trim().isNotEmpty) {
        final norm = PaymentService.normalizarRolId(singleRol.toString());
        if (!roles.contains(norm)) {
          roles.add(norm);
        }
      }
    }
    if (roles.isEmpty && fallbackToPersonaWhenEmpty) {
      roles.add('persona');
    }
    return roles;
  }

  static Future<void> _persistActiveSession({
    required String email,
    required String displayName,
    Map<String, dynamic>? extraProfileData,
    String? passwordForVaultUpdate,
    bool allowNewRolesFromExtra = false,
    bool? paymentPendingOverride,
    bool? paymentActiveOverride,
    String? pendingRoleIdOverride,
    List<String>? explicitRolesOverride,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final resolvedName = displayName.trim().isNotEmpty
        ? displayName.trim()
        : _humanizeEmailPrefix(cleanEmail);

    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);
    final hasExisting = registry[cleanEmail] is Map;
    final existing = hasExisting
        ? Map<String, dynamic>.from(registry[cleanEmail] as Map)
        : <String, dynamic>{};

    final verifiedState = hasExisting
        ? await _lookupVerifiedAccountStateForEmail(prefs, cleanEmail)
        : (
            roles: <String>['persona'],
            paymentPending: false,
            pendingRoleId: 'persona',
          );

    final bool resolvedPayPending =
        paymentPendingOverride ?? verifiedState.paymentPending;
    final bool resolvedPayActive =
        paymentActiveOverride ??
        (!resolvedPayPending && (existing['pagoWompiActivo'] == true));
    final String resolvedPendingRole = PaymentService.normalizarRolId(
      pendingRoleIdOverride ??
          extraProfileData?['rolSolicitadoRegistro']?.toString() ??
          verifiedState.pendingRoleId,
    );

    List<String> deduplicatedRoles;
    if (explicitRolesOverride != null) {
      deduplicatedRoles = <String>[
        for (final r in explicitRolesOverride)
          if (r.trim().isNotEmpty) PaymentService.normalizarRolId(r),
      ];
    } else if (resolvedPayPending) {
      deduplicatedRoles = <String>[];
    } else {
      final combinedRoles = <String>[
        ...verifiedState.roles,
        if (allowNewRolesFromExtra && extraProfileData != null)
          ..._extractNormalizedRolesFromMap(
            extraProfileData,
            fallbackToPersonaWhenEmpty: false,
          ),
      ];
      deduplicatedRoles = <String>[];
      for (final r in combinedRoles) {
        if (!deduplicatedRoles.contains(r)) {
          deduplicatedRoles.add(r);
        }
      }
      if (deduplicatedRoles.isEmpty) {
        deduplicatedRoles.add('persona');
      }
    }

    final sanitizedExtra = <String, dynamic>{...?extraProfileData}
      ..remove('password');

    existing.remove('password');

    final vaultFields =
        (passwordForVaultUpdate != null && passwordForVaultUpdate.isNotEmpty)
        ? SecurityService.createPasswordVerifier(passwordForVaultUpdate)
        : <String, dynamic>{};

    final rolesSeal = await SecurityService.computeUserRolesSeal(
      prefs: prefs,
      email: cleanEmail,
      roles: deduplicatedRoles,
    );
    final paymentStateSeal = await SecurityService.computePaymentStateSeal(
      prefs: prefs,
      email: cleanEmail,
      paymentPending: resolvedPayPending,
      paymentActive: resolvedPayActive,
      requestedRoleId: resolvedPendingRole,
      roles: deduplicatedRoles,
    );

    final merged = <String, dynamic>{
      ...existing,
      ...sanitizedExtra,
      ...vaultFields,
      'email': cleanEmail,
      'displayName': resolvedName,
      'rolesActivos': deduplicatedRoles,
      'rolPrincipal': deduplicatedRoles.isNotEmpty
          ? deduplicatedRoles.first
          : resolvedPendingRole,
      'rolSolicitadoRegistro': resolvedPendingRole,
      'rolEtiqueta': PaymentService.formatearEtiquetaRolesAcumulados(
        deduplicatedRoles,
      ),
      'pagoWompiPendiente': resolvedPayPending,
      'pagoWompiActivo': resolvedPayActive,
      'rolesSeal': rolesSeal,
      'paymentStateSeal': paymentStateSeal,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    registry[cleanEmail] = merged;

    await prefs.setString(_kUsersRegistryKey, jsonEncode(registry));
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('usuarioActivo', cleanEmail);
    await prefs.setString('userEmail', cleanEmail);
    await prefs.setString('usuarioNombreActivo', resolvedName);
    await SecurityService.sealActiveSession(
      prefs: prefs,
      email: cleanEmail,
      roles: deduplicatedRoles,
      paymentPending: resolvedPayPending,
      pendingRoleId: resolvedPendingRole,
    );

    _cachedEmail = cleanEmail;
    _cachedFullName = resolvedName;
    _cachedPhotoData = await _lookupStoredPhotoForEmail(prefs, cleanEmail);
    _cachedRoles = deduplicatedRoles;
    _cachedPaymentPending = resolvedPayPending;
    _cachedPendingRoleId = resolvedPendingRole;
    _isLocalSessionActive = true;
    authStateVersion.value++;
  }

  static Future<void> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw const AuthServiceException('Ingresa tu correo electrónico.');
    }
    if (password.isEmpty || password.length > 128) {
      throw const AuthServiceException(
        'El correo electrónico o la contraseña son incorrectos.',
      );
    }

    // 1. Control de tasa global y bloqueo progresivo anti-fuerza bruta por cuenta
    final globalLimit = SecurityService.checkRateLimit(
      actionKey: 'auth_login_global',
      maxAttempts: 12,
      window: const Duration(minutes: 2),
      customErrorMessage: 'Demasiados intentos de acceso en poco tiempo. Espera para volver a intentar.',
    );
    if (!globalLimit.allowed) {
      throw AuthServiceException(globalLimit.message);
    }

    final lockout = await SecurityService.checkAuthLockout('login:$cleanEmail');
    if (!lockout.allowed) {
      throw AuthServiceException(lockout.message);
    }

    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyVaultAndRolesInRegistry(prefs);
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
      await SecurityService.resetAuthFailures('login:$cleanEmail');

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

      // Sincroniza roles autoritativos y estado de pago desde Firestore si existen
      List<String>? remoteRoles;
      bool? remotePaymentPending;
      bool? remotePaymentActive;
      String? remoteRequestedRole;
      if (user != null) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection(ConsentService.coleccionUsuarios)
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 4));
          final data = snap.data();
          if (data != null) {
            remotePaymentActive = data['pagoWompiActivo'] == true;
            if (data.containsKey('pagoWompiPendiente')) {
              remotePaymentPending =
                  data['pagoWompiPendiente'] == true && !remotePaymentActive;
            }
            if (data['rolSolicitadoRegistro'] != null) {
              remoteRequestedRole = PaymentService.normalizarRolId(
                data['rolSolicitadoRegistro'].toString(),
              );
            }
            if (remotePaymentPending == true) {
              remoteRoles = <String>[];
            } else if (data['rolesActivos'] is List) {
              remoteRoles = _extractNormalizedRolesFromMap(
                data,
                fallbackToPersonaWhenEmpty: true,
              );
            }
          }
        } catch (_) {}
      }

      await _persistActiveSession(
        email: cleanEmail,
        displayName: resolvedName,
        passwordForVaultUpdate: password,
        paymentPendingOverride: remotePaymentPending,
        paymentActiveOverride: remotePaymentActive,
        pendingRoleIdOverride: remoteRequestedRole,
        explicitRolesOverride: remotePaymentPending == true
            ? const <String>[]
            : remoteRoles,
        extraProfileData: remoteRoles != null
            ? <String, dynamic>{'rolesActivos': remoteRoles}
            : null,
        allowNewRolesFromExtra: remoteRoles != null,
      );
    } on FirebaseAuthException catch (error) {
      // Respaldo estrictamente offline: solo se permite si falló la red y el
      // verificador criptográfico PBKDF2-HMAC-SHA256 coincide en tiempo constante.
      // (`operation-not-allowed` indica un proveedor deshabilitado, no falta de red.)
      final bool isOfflineFallbackAllowed =
          error.code == 'network-request-failed';

      if (isOfflineFallbackAllowed && localEntry != null) {
        final iterations = localEntry['passwordKdfIterations'] is int
            ? localEntry['passwordKdfIterations'] as int
            : 15000;
        final verified = SecurityService.verifyPasswordVerifier(
          password: password,
          saltBase64: localEntry['passwordSalt']?.toString(),
          verifierBase64: localEntry['passwordVerifier']?.toString(),
          iterations: iterations,
        );
        if (verified) {
          await SecurityService.resetAuthFailures('login:$cleanEmail');
          final localName = (localEntry['displayName'] ?? '').toString().trim();
          await _persistActiveSession(
            email: cleanEmail,
            displayName: localName.isNotEmpty
                ? localName
                : _humanizeEmailPrefix(cleanEmail),
          );
          return;
        }
      }

      await SecurityService.recordAuthFailure('login:$cleanEmail');
      throw AuthServiceException(_messageFor(error));
    }
  }

  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _purgeSessionFlags(prefs);
      _resetInMemorySession();

      await FirebaseAuth.instance.signOut();
      authStateVersion.value++;
    } on FirebaseAuthException catch (error) {
      _resetInMemorySession();
      authStateVersion.value++;
      throw AuthServiceException(_messageFor(error));
    }
  }

  static Future<void> signInWithGoogle() async {
    final limit = SecurityService.checkRateLimit(
      actionKey: 'oauth_google',
      maxAttempts: 6,
      window: const Duration(minutes: 2),
    );
    if (!limit.allowed) {
      throw AuthServiceException(limit.message);
    }

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
    final limit = SecurityService.checkRateLimit(
      actionKey: 'oauth_apple',
      maxAttempts: 6,
      window: const Duration(minutes: 2),
    );
    if (!limit.allowed) {
      throw AuthServiceException(limit.message);
    }

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

  /// Verifica disponibilidad de correo y cédula usando índices criptográficos
  /// unidireccionales SHA-256 (`indices_unicidad/{hash}`), protegiendo los datos
  /// personales conforme a la Ley 1581 de 2012 sin permitir listado de `usuarios`.
  static Future<({bool emailEnUso, bool documentoEnUso})>
  checkDuplicateCredentials({
    required String email,
    required String documento,
  }) async {
    final rate = SecurityService.checkRateLimit(
      actionKey: 'uniqueness_lookup',
      maxAttempts: 10,
      window: const Duration(minutes: 2),
    );
    if (!rate.allowed) {
      throw AuthServiceException(rate.message);
    }

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
          final entryEmail = (entry['email'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final entryDoc = normalizeDocumentoDigits(
            (entry['documento'] ?? entry['documentoNormalizado'] ?? '')
                .toString(),
          );
          if (cleanEmail.isNotEmpty && entryEmail == cleanEmail) {
            emailEnUso = true;
          }
          if (normDoc.length >= 5 &&
              entryDoc.isNotEmpty &&
              entryDoc == normDoc) {
            documentoEnUso = true;
          }
        }
      }
    } catch (_) {}

    // Consulta puntual por hash SHA-256 (`get` directo, sin `list` ni exposición de PII)
    if (!emailEnUso || !documentoEnUso) {
      try {
        final idxCol = FirebaseFirestore.instance.collection(
          coleccionIndicesUnicidad,
        );
        if (!emailEnUso && cleanEmail.isNotEmpty) {
          final emailHash = SecurityService.hashCredentialUniquenessIndex(
            type: 'email',
            normalizedValue: cleanEmail,
          );
          final emailDoc = await idxCol
              .doc(emailHash)
              .get()
              .timeout(const Duration(seconds: 3));
          if (emailDoc.exists) {
            emailEnUso = true;
          }
        }
        if (!documentoEnUso && normDoc.length >= 5) {
          final docHash = SecurityService.hashCredentialUniquenessIndex(
            type: 'doc',
            normalizedValue: normDoc,
          );
          final cedulaDoc = await idxCol
              .doc(docHash)
              .get()
              .timeout(const Duration(seconds: 3));
          if (cedulaDoc.exists) {
            documentoEnUso = true;
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
    final signupLimit = SecurityService.checkRateLimit(
      actionKey: 'auth_signup',
      maxAttempts: 5,
      window: const Duration(minutes: 10),
      customErrorMessage: 'Se alcanzó el límite temporal de intentos de registro. Espera unos minutos.',
    );
    if (!signupLimit.allowed) {
      throw AuthServiceException(signupLimit.message);
    }

    // Defensa en profundidad: aunque la UI ya lo valida, el servicio nunca crea
    // una cuenta sin autorización expresa de tratamiento de datos (Ley 1581/2012).
    if (!aceptaTratamientoDatos) {
      throw const AuthServiceException(
        'Debes aceptar la Política de Privacidad y Tratamiento de Datos Personales para crear tu cuenta.',
      );
    }

    final passwordPolicyError = SecurityService.validateStrongPassword(
      password,
    );
    if (passwordPolicyError != null) {
      throw AuthServiceException(passwordPolicyError);
    }

    final cleanEmail = (userData['email'] as String?)?.trim().toLowerCase();
    if (cleanEmail == null ||
        cleanEmail.isEmpty ||
        cleanEmail.length > 160 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(cleanEmail)) {
      throw const AuthServiceException(
        'Ingresa un correo electrónico válido para crear la cuenta.',
      );
    }

    final cleanDocumento = (userData['documento'] ?? '')
        .toString()
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    final normDoc = normalizeDocumentoDigits(cleanDocumento);
    if (cleanDocumento.isEmpty || normDoc.length < 5 || normDoc.length > 20) {
      throw const AuthServiceException(
        'El número de cédula o documento válido es obligatorio para crear la cuenta.',
      );
    }

    // Validación estricta de unicidad
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
    // CERO ACCESO SIN PAGO: durante el registro la cuenta inicia con 0 roles activos
    // y `pagoWompiPendiente = true` sellado criptográficamente. Ningún módulo se
    // desbloquea hasta que Wompi confirme `APPROVED` en `assignPaidRoleToActiveUser`.
    const initialRoles = <String>[];
    final rolEtiqueta = PaymentService.formatearEtiquetaRolesAcumulados(
      initialRoles,
    );

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
        try {
          await ConsentService.registrarAceptacionTratamientoDatos(
            uid: user.uid,
            email: cleanEmail,
            canal: 'registro_email',
          );

          final db = FirebaseFirestore.instance;
          final emailIdxHash = SecurityService.hashCredentialUniquenessIndex(
            type: 'email',
            normalizedValue: cleanEmail,
          );
          final docIdxHash = SecurityService.hashCredentialUniquenessIndex(
            type: 'doc',
            normalizedValue: normDoc,
          );

          final batch = db.batch();
          batch.set(
            db.collection(ConsentService.coleccionUsuarios).doc(user.uid),
            {
              'uid': user.uid,
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
              'rolSolicitadoRegistro': selectedRolId,
              'rolEtiqueta': rolEtiqueta,
              'pagoWompiPendiente': true,
              'pagoWompiActivo': false,
              'actualizado_en': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          batch.set(db.collection(coleccionIndicesUnicidad).doc(emailIdxHash), {
            'tipo': 'email',
            'uid': user.uid,
            'creado_en': FieldValue.serverTimestamp(),
          });
          batch.set(db.collection(coleccionIndicesUnicidad).doc(docIdxHash), {
            'tipo': 'doc',
            'uid': user.uid,
            'creado_en': FieldValue.serverTimestamp(),
          });
          await batch.commit().timeout(const Duration(seconds: 6));
        } catch (_) {
          debugPrint(
            'Aviso de auditoría: respaldo remoto diferido; evidencia preservada en bóveda local.',
          );
        }

        await user.updateDisplayName(displayName);
        await user.reload();
        unawaited(user.sendEmailVerification().catchError((_) {}));
      }

      await _persistActiveSession(
        email: cleanEmail,
        displayName: displayName,
        passwordForVaultUpdate: password,
        paymentPendingOverride: true,
        paymentActiveOverride: false,
        pendingRoleIdOverride: selectedRolId,
        explicitRolesOverride: initialRoles,
        extraProfileData: {
          ...userData,
          'email': cleanEmail,
          'documento': cleanDocumento,
          'documentoNormalizado': normDoc,
          'displayName': displayName,
          'rolesActivos': initialRoles,
          'rolPrincipal': selectedRolId,
          'rolSolicitadoRegistro': selectedRolId,
          'rolEtiqueta': rolEtiqueta,
          'pagoWompiPendiente': true,
          'pagoWompiActivo': false,
          'aceptacion_datos': true,
          'version_politica': ConsentService.versionPolitica,
          'fecha_aceptacion_datos': DateTime.now().toIso8601String(),
        }..remove('password'),
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

  /// Envía restablecimiento de contraseña con control de tasa anti-spam y
  /// protección contra enumeración de cuentas (OWASP WSTG-IDNT-04).
  static Future<void> resetPassword(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(cleanEmail)) {
      throw const AuthServiceException(
        'Ingresa un correo electrónico válido para recuperar tu contraseña.',
      );
    }

    final perEmailLimit = SecurityService.checkRateLimit(
      actionKey: 'pwd_reset:$cleanEmail',
      maxAttempts: 2,
      window: const Duration(minutes: 10),
      customErrorMessage: 'Ya se envió una solicitud reciente para este correo. Espera unos minutos antes de reintentar.',
    );
    if (!perEmailLimit.allowed) {
      throw AuthServiceException(perEmailLimit.message);
    }

    final globalResetLimit = SecurityService.checkRateLimit(
      actionKey: 'pwd_reset_global',
      maxAttempts: 5,
      window: const Duration(minutes: 10),
    );
    if (!globalResetLimit.allowed) {
      throw AuthServiceException(globalResetLimit.message);
    }

    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
    } on FirebaseAuthException catch (error) {
      // No revela si el correo existe o no en la base de datos.
      if (error.code == 'user-not-found') {
        return;
      }
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

    final verifiedPhoto = await _lookupStoredPhotoForEmail(prefs, activeEmail);
    if (verifiedPhoto.isNotEmpty && _cachedPhotoData.isEmpty) {
      _cachedPhotoData = verifiedPhoto;
    }

    final activeRoles = await _lookupVerifiedRolesForEmail(prefs, activeEmail);
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

  /// Permite a un usuario con pago inicial pendiente cambiar el paquete/rol
  /// que desea activar antes de pagar, manteniendo `pagoWompiPendiente = true`.
  static Future<void> updatePendingRegistrationRole(String rolId) async {
    final cleanEmail = getActiveUserEmail().trim().toLowerCase();
    if (cleanEmail.isEmpty) return;
    final cleanRol = PaymentService.normalizarRolId(rolId);
    _cachedPendingRoleId = cleanRol;

    final fbUser = _auth.currentUser;
    if (fbUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection(ConsentService.coleccionUsuarios)
            .doc(fbUser.uid)
            .set({
              'rolSolicitadoRegistro': cleanRol,
              'actualizado_en': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    await _persistActiveSession(
      email: cleanEmail,
      displayName: getActiveUserDisplayName(),
      paymentPendingOverride: true,
      paymentActiveOverride: false,
      pendingRoleIdOverride: cleanRol,
      explicitRolesOverride: const <String>[],
    );
  }

  /// Valida criptográficamente el recibo de Wompi (incluyendo protección anti-replay)
  /// y asigna/acumula el rol pagado sellando su integridad en cliente y Firestore.
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

    final historyRaw = existing['historialPagosWompi'];
    final history = <Map<String, dynamic>>[
      if (historyRaw is List)
        for (final item in historyRaw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];

    // Protección Anti-Replay: rechaza recibos cuyo transactionId o reference ya fue aplicado
    final alreadyRedeemed = history.any(
      (tx) =>
          tx['transactionId']?.toString() == receipt.transactionId ||
          tx['reference']?.toString() == receipt.reference,
    );
    if (alreadyRedeemed) {
      throw const AuthServiceException(
        'Esta transacción de pago ya fue procesada y aplicada anteriormente.',
      );
    }
    history.add(receipt.toMap());

    final verifiedState = await _lookupVerifiedAccountStateForEmail(
      prefs,
      activeEmail,
    );
    // Si la cuenta tenía pago inicial pendiente, parte de [] y recibe su primer rol pagado;
    // si ya tenía roles activos (ej. `['persona']`), ACUMULA el nuevo rol (`['persona', 'equipo_juridico']`).
    final baseRoles = verifiedState.paymentPending
        ? <String>[]
        : verifiedState.roles;
    final paidRolId = PaymentService.normalizarRolId(receipt.rolId);
    final updatedRoles = <String>[
      ...baseRoles,
      if (!baseRoles.contains(paidRolId)) paidRolId,
    ];
    final rolEtiqueta = PaymentService.formatearEtiquetaRolesAcumulados(
      updatedRoles,
    );
    final rolesSeal = await SecurityService.computeUserRolesSeal(
      prefs: prefs,
      email: activeEmail,
      roles: updatedRoles,
    );
    final paymentStateSeal = await SecurityService.computePaymentStateSeal(
      prefs: prefs,
      email: activeEmail,
      paymentPending: false,
      paymentActive: true,
      requestedRoleId: paidRolId,
      roles: updatedRoles,
    );

    existing.remove('password');
    existing['rolesActivos'] = updatedRoles;
    existing['rolPrincipal'] = updatedRoles.first;
    existing['rolSolicitadoRegistro'] = paidRolId;
    existing['rolEtiqueta'] = rolEtiqueta;
    existing['rolesSeal'] = rolesSeal;
    existing['paymentStateSeal'] = paymentStateSeal;
    existing['pagoWompiActivo'] = true;
    existing['pagoWompiPendiente'] = false;
    existing['ultimoPagoWompi'] = receipt.toMap();
    existing['historialPagosWompi'] = history;
    existing['updatedAt'] = DateTime.now().toIso8601String();
    registry[activeEmail] = existing;
    await prefs.setString(_kUsersRegistryKey, jsonEncode(registry));
    await SecurityService.sealActiveSession(
      prefs: prefs,
      email: activeEmail,
      roles: updatedRoles,
      paymentPending: false,
      pendingRoleId: paidRolId,
    );

    _cachedRoles = updatedRoles;
    _cachedPaymentPending = false;
    _cachedPendingRoleId = paidRolId;
    authStateVersion.value++;

    final fbUser = _auth.currentUser;
    if (fbUser != null) {
      try {
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

        await FirebaseFirestore.instance
            .collection(ConsentService.coleccionUsuarios)
            .doc(fbUser.uid)
            .set({
              'rolesActivos': updatedRoles,
              'rolPrincipal': updatedRoles.first,
              'rolEtiqueta': rolEtiqueta,
              'pagoWompiActivo': true,
              'pagoWompiPendiente': false,
              'ultimoPagoWompi': receipt.toMap(),
              'actualizado_en': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        debugPrint(
          'Aviso de auditoría: recibo Wompi verificado y sellado localmente.',
        );
      }
    }
  }

  /// Actualiza o restaura la foto de perfil validando formato raster (Magic Bytes),
  /// límite de tamaño (1.5 MB) y esquema HTTPS seguro.
  static Future<void> updateActiveUserPhoto(String? photoSource) async {
    final activeEmail = getActiveUserEmail().trim().toLowerCase();
    if (activeEmail.isEmpty) {
      throw const AuthServiceException(
        'No se encontró una sesión activa para actualizar la foto.',
      );
    }

    final cleanPhoto = (photoSource ?? '').trim();
    String validatedPhoto = '';

    if (cleanPhoto.isNotEmpty) {
      if (cleanPhoto.startsWith('data:image/')) {
        final decoded = SecurityService.decodeSafeRasterDataUrl(cleanPhoto);
        if (decoded == null) {
          throw const AuthServiceException(
            'El archivo seleccionado no es una imagen válida (PNG, JPG o WEBP) o supera el límite seguro de 1.5 MB.',
          );
        }
        validatedPhoto = cleanPhoto;
      } else {
        final safeUri = SecurityService.validateSafeExternalImageUrl(
          cleanPhoto,
        );
        if (safeUri == null) {
          throw const AuthServiceException(
            'Por seguridad, el enlace de la imagen debe usar HTTPS público y apuntar a un formato válido (JPG, PNG o WEBP).',
          );
        }
        validatedPhoto = safeUri.toString();
      }
    }

    final fbUser = _auth.currentUser;
    if (fbUser != null &&
        (validatedPhoto.isEmpty || validatedPhoto.startsWith('https://'))) {
      try {
        await fbUser.updatePhotoURL(
          validatedPhoto.isEmpty ? null : validatedPhoto,
        );
        await fbUser.reload();
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final registry = await _loadRegistry(prefs);
    final existing = registry[activeEmail] is Map
        ? Map<String, dynamic>.from(registry[activeEmail] as Map)
        : <String, dynamic>{};
    existing['photoData'] = validatedPhoto;
    existing['updatedAt'] = DateTime.now().toIso8601String();
    registry[activeEmail] = existing;
    await prefs.setString(_kUsersRegistryKey, jsonEncode(registry));

    _cachedPhotoData = validatedPhoto;
    authStateVersion.value++;
  }

  /// Actualiza únicamente los datos editables del perfil (conservando bloqueados
  /// el correo electrónico y la cédula/documento). Devuelve `false` si el
  /// cambio quedó solo en este dispositivo porque no se pudo guardar en la nube.
  static Future<bool> updateActiveUserProfile({
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

    final rate = SecurityService.checkRateLimit(
      actionKey: 'profile_update:$activeEmail',
      maxAttempts: 8,
      window: const Duration(minutes: 2),
    );
    if (!rate.allowed) {
      throw AuthServiceException(rate.message);
    }

    String cleanField(String v, int maxLen) {
      final s = v.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
      return s.length > maxLen ? s.substring(0, maxLen) : s;
    }

    final cleanNombres = cleanField(nombres, 80);
    final cleanApellidos = cleanField(apellidos, 80);
    final cleanTelefono = cleanField(telefono, 25);
    final cleanPais = cleanField(pais, 60).isNotEmpty
        ? cleanField(pais, 60)
        : 'Colombia';
    final displayName = '$cleanNombres $cleanApellidos'.trim().isNotEmpty
        ? '$cleanNombres $cleanApellidos'.trim()
        : getActiveUserDisplayName();

    var sincronizado = false;
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
        sincronizado = true;
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
    return sincronizado;
  }

  /// Cambia la contraseña del usuario activo validando primero su contraseña actual,
  /// aplicando bloqueo anti-fuerza bruta y almacenando solo verificadores PBKDF2.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) {
      throw const AuthServiceException('Ingresa tu contraseña actual.');
    }

    final passwordPolicyError = SecurityService.validateStrongPassword(
      newPassword,
    );
    if (passwordPolicyError != null) {
      throw AuthServiceException(passwordPolicyError);
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

    final lockout = await SecurityService.checkAuthLockout(
      'pwd_change:$activeEmail',
    );
    if (!lockout.allowed) {
      throw AuthServiceException(lockout.message);
    }

    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyVaultAndRolesInRegistry(prefs);
    final registry = await _loadRegistry(prefs);
    final localEntry = registry[activeEmail] is Map
        ? Map<String, dynamic>.from(registry[activeEmail] as Map)
        : <String, dynamic>{};

    final fbUser = _auth.currentUser;
    if (fbUser != null && fbUser.email?.trim().toLowerCase() == activeEmail) {
      final usesPassword =
          fbUser.providerData.isEmpty ||
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
        await SecurityService.resetAuthFailures('pwd_change:$activeEmail');
      } on FirebaseAuthException catch (error) {
        await SecurityService.recordAuthFailure('pwd_change:$activeEmail');
        if (error.code == 'wrong-password' ||
            error.code == 'invalid-credential') {
          throw const AuthServiceException(
            'La contraseña actual ingresada no es correcta.',
          );
        }
        throw AuthServiceException(_messageFor(error));
      }
    } else {
      // Sin sesión de Firebase solo cambiaría la copia local y la contraseña
      // real de la cuenta seguiría siendo la anterior.
      throw const AuthServiceException(
        'Para cambiar tu contraseña necesitas conexión. Vuelve a iniciar sesión e inténtalo de nuevo.',
      );
    }

    // Guarda únicamente el verificador criptográfico PBKDF2-HMAC-SHA256 (sin texto plano)
    localEntry.remove('password');
    localEntry.addAll(SecurityService.createPasswordVerifier(newPassword));
    localEntry['updatedAt'] = DateTime.now().toIso8601String();
    registry[activeEmail] = localEntry;
    await prefs.setString(_kUsersRegistryKey, jsonEncode(registry));
  }

  static String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        // Mensaje unificado para impedir enumeración de cuentas (OWASP WSTG-IDNT-04)
        return 'El correo electrónico o la contraseña son incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta registrada con ese correo. Inicia sesión con tu contraseña.';
      case 'weak-password':
        return 'La contraseña no cumple el nivel mínimo de seguridad (usa al menos 8 caracteres, mayúsculas, minúsculas y números).';
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión antes de realizar esta acción sensible.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada por seguridad.';
      case 'too-many-requests':
        return 'Hubo demasiados intentos seguidos. Espera unos minutos e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'No se pudo establecer conexión segura. Revisa tu conexión a internet.';
      case 'operation-not-allowed':
        return 'Este método de acceso no está habilitado actualmente.';
      default:
        return 'No fue posible completar la autenticación de forma segura. Intenta nuevamente.';
    }
  }

  // Adaptadores para los puntos de entrada que aún usan la API anterior.
  Future<bool> iniciarSesion(String correo, String contrasena) async {
    await signInWithEmail(correo, contrasena);
    return true;
  }

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
}
