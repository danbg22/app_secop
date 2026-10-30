import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Resultado de verificación de control de tasa (Rate Limiting / Anti-Brute-Force).
class RateLimitDecision {
  const RateLimitDecision({
    required this.allowed,
    this.retryAfterSeconds = 0,
    this.message = '',
  });

  final bool allowed;
  final int retryAfterSeconds;
  final String message;
}

/// Motor centralizado de Ciberseguridad Defensiva para Contrata Legal (SECOP II).
///
/// Implementa primitivas criptográficas puras multiplataforma (VM + Web):
/// - SHA-256 (FIPS 180-4) seguro para enteros de 32 bits en Dart2JS/Wasm
/// - HMAC-SHA256 (RFC 2104) y comparación en tiempo constante
/// - PBKDF2-HMAC-SHA256 (RFC 8018) con sal aleatoria CSPRNG (`Random.secure`)
/// - Sellado criptográfico de sesión y roles con expiración (TTL + inactividad)
/// - Limitador de tasa con bloqueo progresivo persistente (anti-fuerza bruta)
/// - Sanitizadores contra SoQL Injection, CSV Formula Injection (CWE-1236),
///   Prompt Injection en IA, XSS/SVG Upload, Open Redirect y SSRF.
class SecurityService {
  SecurityService._();

  static const String _kDeviceSealKeyPref = '_sec_device_hmac_key_v1';
  static const String _kSessionSealPref = '_sec_active_session_seal_v1';
  static const String _kLockoutRegistryPref = '_sec_auth_lockout_v1';
  static const String _kDomainPepper = 'ContrataLegal::SECOP::AppSec::2026::v1';

  /// Tiempo máximo absoluto de sesión local (12 horas) e inactividad (4 horas).
  static const Duration maxSessionAge = Duration(hours: 12);
  static const Duration maxSessionIdle = Duration(hours: 4);

  /// Tamaño máximo permitido para avatares codificados localmente (1.5 MB).
  static const int maxAvatarBytes = 1572864;

  /// Tamaño máximo permitido por documento contractual cargado en línea (4 MB).
  static const int maxContractDocumentBytes = 4194304;

  static final Map<String, List<int>> _slidingWindows = <String, List<int>>{};

  static const List<int> _sha256K = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  // ===========================================================================
  // 1. PRIMITIVAS CRIPTOGRÁFICAS (SHA-256, HMAC-SHA256, PBKDF2, CSPRNG)
  // ===========================================================================

  static int _rotr32(int n, int x) {
    final ux = x.toUnsigned(32);
    return ((ux >>> n) | (ux << (32 - n))).toUnsigned(32);
  }

  static int _add32(int a, int b) => (a + b).toUnsigned(32);

  /// Calcula SHA-256 (FIPS 180-4) con aritmética unsigned de 32 bits compatible
  /// de forma idéntica en Dart VM y compilación Web (JS / Wasm).
  static Uint8List sha256Bytes(List<int> message) {
    final msgLen = message.length;
    final rem = (msgLen + 9) % 64;
    final padZeroes = rem == 0 ? 0 : (64 - rem);
    final totalLen = msgLen + 1 + padZeroes + 8;

    final padded = Uint8List(totalLen);
    for (var i = 0; i < msgLen; i++) {
      padded[i] = message[i] & 0xFF;
    }
    padded[msgLen] = 0x80;

    // Longitud en bits (64-bit big-endian) sin desplazamientos >= 32 para JS.
    final bitLenHigh = (msgLen ~/ 0x20000000).toUnsigned(32);
    final bitLenLow = ((msgLen & 0x1FFFFFFF) * 8).toUnsigned(32);
    final lenOffset = totalLen - 8;
    padded[lenOffset] = (bitLenHigh >>> 24) & 0xFF;
    padded[lenOffset + 1] = (bitLenHigh >>> 16) & 0xFF;
    padded[lenOffset + 2] = (bitLenHigh >>> 8) & 0xFF;
    padded[lenOffset + 3] = bitLenHigh & 0xFF;
    padded[lenOffset + 4] = (bitLenLow >>> 24) & 0xFF;
    padded[lenOffset + 5] = (bitLenLow >>> 16) & 0xFF;
    padded[lenOffset + 6] = (bitLenLow >>> 8) & 0xFF;
    padded[lenOffset + 7] = bitLenLow & 0xFF;

    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final w = Uint32List(64);

    for (var chunkStart = 0; chunkStart < totalLen; chunkStart += 64) {
      for (var i = 0; i < 16; i++) {
        final j = chunkStart + (i * 4);
        w[i] = (((padded[j] << 24) |
                    (padded[j + 1] << 16) |
                    (padded[j + 2] << 8) |
                    padded[j + 3]))
                .toUnsigned(32);
      }

      for (var i = 16; i < 64; i++) {
        final w15 = w[i - 15];
        final w2 = w[i - 2];
        final s0 = (_rotr32(7, w15) ^ _rotr32(18, w15) ^ (w15 >>> 3))
            .toUnsigned(32);
        final s1 = (_rotr32(17, w2) ^ _rotr32(19, w2) ^ (w2 >>> 10))
            .toUnsigned(32);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1).toUnsigned(32);
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var h = h7;

      for (var i = 0; i < 64; i++) {
        final s1 = (_rotr32(6, e) ^ _rotr32(11, e) ^ _rotr32(25, e))
            .toUnsigned(32);
        final notE = (~e).toUnsigned(32);
        final ch = ((e & f) ^ (notE & g)).toUnsigned(32);
        final temp1 = (h + s1 + ch + _sha256K[i] + w[i]).toUnsigned(32);
        final s0 = (_rotr32(2, a) ^ _rotr32(13, a) ^ _rotr32(22, a))
            .toUnsigned(32);
        final maj = ((a & b) ^ (a & c) ^ (b & c)).toUnsigned(32);
        final temp2 = _add32(s0, maj);

        h = g;
        g = f;
        f = e;
        e = _add32(d, temp1);
        d = c;
        c = b;
        b = a;
        a = _add32(temp1, temp2);
      }

      h0 = _add32(h0, a);
      h1 = _add32(h1, b);
      h2 = _add32(h2, c);
      h3 = _add32(h3, d);
      h4 = _add32(h4, e);
      h5 = _add32(h5, f);
      h6 = _add32(h6, g);
      h7 = _add32(h7, h);
    }

    final out = Uint8List(32);
    final words = <int>[h0, h1, h2, h3, h4, h5, h6, h7];
    for (var i = 0; i < 8; i++) {
      final word = words[i];
      final base = i * 4;
      out[base] = (word >>> 24) & 0xFF;
      out[base + 1] = (word >>> 16) & 0xFF;
      out[base + 2] = (word >>> 8) & 0xFF;
      out[base + 3] = word & 0xFF;
    }
    return out;
  }

  static String bytesToHex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write((b & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static String sha256Hex(String input) => bytesToHex(sha256Bytes(utf8.encode(input)));

  /// HMAC-SHA256 conforme a RFC 2104 (tamaño de bloque = 64 bytes).
  static Uint8List hmacSha256Bytes(List<int> key, List<int> message) {
    const blockSize = 64;
    final normalizedKey = key.length > blockSize
        ? sha256Bytes(key)
        : Uint8List.fromList(key);

    final keyBlock = Uint8List(blockSize);
    for (var i = 0; i < normalizedKey.length; i++) {
      keyBlock[i] = normalizedKey[i];
    }

    final innerPad = Uint8List(blockSize + message.length);
    final outerPad = Uint8List(blockSize + 32);
    for (var i = 0; i < blockSize; i++) {
      innerPad[i] = keyBlock[i] ^ 0x36;
      outerPad[i] = keyBlock[i] ^ 0x5C;
    }
    for (var i = 0; i < message.length; i++) {
      innerPad[blockSize + i] = message[i] & 0xFF;
    }

    final innerDigest = sha256Bytes(innerPad);
    for (var i = 0; i < 32; i++) {
      outerPad[blockSize + i] = innerDigest[i];
    }
    return sha256Bytes(outerPad);
  }

  static String hmacSha256Hex(String secret, String message) {
    return bytesToHex(hmacSha256Bytes(utf8.encode(secret), utf8.encode(message)));
  }

  /// PBKDF2-HMAC-SHA256 conforme a RFC 8018 para almacenamiento seguro de
  /// verificadores de contraseña (nunca texto plano).
  static Uint8List pbkdf2HmacSha256({
    required String password,
    required List<int> salt,
    int iterations = 15000,
    int derivedKeyLength = 32,
  }) {
    final safeIterations = iterations < 1000 ? 1000 : iterations;
    final passwordBytes = utf8.encode(password);
    final hashLen = 32;
    final blocks = (derivedKeyLength + hashLen - 1) ~/ hashLen;
    final output = Uint8List(blocks * hashLen);

    final saltPlusBlock = Uint8List(salt.length + 4);
    for (var i = 0; i < salt.length; i++) {
      saltPlusBlock[i] = salt[i] & 0xFF;
    }

    for (var blockIndex = 1; blockIndex <= blocks; blockIndex++) {
      saltPlusBlock[salt.length] = (blockIndex >>> 24) & 0xFF;
      saltPlusBlock[salt.length + 1] = (blockIndex >>> 16) & 0xFF;
      saltPlusBlock[salt.length + 2] = (blockIndex >>> 8) & 0xFF;
      saltPlusBlock[salt.length + 3] = blockIndex & 0xFF;

      var u = hmacSha256Bytes(passwordBytes, saltPlusBlock);
      final t = Uint8List.fromList(u);

      for (var iter = 1; iter < safeIterations; iter++) {
        u = hmacSha256Bytes(passwordBytes, u);
        for (var k = 0; k < hashLen; k++) {
          t[k] ^= u[k];
        }
      }

      final destOffset = (blockIndex - 1) * hashLen;
      for (var k = 0; k < hashLen; k++) {
        output[destOffset + k] = t[k];
      }
    }

    return Uint8List.sublistView(output, 0, derivedKeyLength);
  }

  /// Comparación en tiempo constante para mitigar ataques de temporización.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    final maxLen = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < maxLen; i++) {
      final byteA = i < a.length ? a[i] : 0;
      final byteB = i < b.length ? b[i] : 0;
      diff |= (byteA ^ byteB);
    }
    return diff == 0;
  }

  static Uint8List generateSecureRandomBytes(int length) {
    final rng = math.Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  static String generateSecureSaltBase64([int byteLength = 16]) {
    return base64Url.encode(generateSecureRandomBytes(byteLength));
  }

  static String generateSecureTokenHex([int byteLength = 16]) {
    return bytesToHex(generateSecureRandomBytes(byteLength));
  }

  /// Deriva verificador PBKDF2-HMAC-SHA256 para respaldo local sin guardar jamás
  /// la contraseña en texto claro.
  static Map<String, dynamic> createPasswordVerifier(
    String password, {
    int iterations = 15000,
  }) {
    final saltBytes = generateSecureRandomBytes(16);
    final derived = pbkdf2HmacSha256(
      password: '$_kDomainPepper|$password',
      salt: saltBytes,
      iterations: iterations,
    );
    return <String, dynamic>{
      'passwordSalt': base64Url.encode(saltBytes),
      'passwordVerifier': base64Url.encode(derived),
      'passwordKdfIterations': iterations,
    };
  }

  static bool verifyPasswordVerifier({
    required String password,
    required String? saltBase64,
    required String? verifierBase64,
    int iterations = 15000,
  }) {
    if (saltBase64 == null ||
        saltBase64.isEmpty ||
        verifierBase64 == null ||
        verifierBase64.isEmpty) {
      return false;
    }
    try {
      final saltBytes = base64Url.decode(saltBase64);
      final expectedBytes = base64Url.decode(verifierBase64);
      final actualBytes = pbkdf2HmacSha256(
        password: '$_kDomainPepper|$password',
        salt: saltBytes,
        iterations: iterations,
        derivedKeyLength: expectedBytes.length,
      );
      return constantTimeEquals(actualBytes, expectedBytes);
    } catch (_) {
      return false;
    }
  }

  /// Índice criptográfico unidireccional (SHA-256 con separación de dominio)
  /// para validar unicidad de correo/documento en Firestore sin exponer PII
  /// (Ley 1581 de 2012).
  static String hashCredentialUniquenessIndex({
    required String type,
    required String normalizedValue,
  }) {
    final cleanType = type.trim().toLowerCase();
    final cleanVal = normalizedValue.trim().toLowerCase();
    return sha256Hex('$_kDomainPepper::uniqueness::$cleanType::$cleanVal');
  }

  /// Identificador opaco por usuario para aislar cachés locales (PQRS, favoritos)
  /// en navegadores compartidos.
  static String deriveUserStorageScope(String emailOrUid) {
    final normalized = emailOrUid.trim().toLowerCase();
    if (normalized.isEmpty) return 'anon';
    return sha256Hex('$_kDomainPepper::scope::$normalized').substring(0, 20);
  }

  // ===========================================================================
  // 2. SELLADO DE INTEGRIDAD DE SESIÓN Y ROLES (ANTI-TAMPERING LOCALSTORAGE)
  // ===========================================================================

  static Future<String> _getOrCreateDeviceSealSecret(
    SharedPreferences prefs,
  ) async {
    final existing = prefs.getString(_kDeviceSealKeyPref);
    if (existing != null && existing.length >= 48) {
      return '$existing|$_kDomainPepper';
    }
    final created = generateSecureTokenHex(32);
    await prefs.setString(_kDeviceSealKeyPref, created);
    return '$created|$_kDomainPepper';
  }

  /// Firma los roles de un usuario en el registro local para detectar ediciones
  /// manuales desde DevTools (`localStorage`).
  static Future<String> computeUserRolesSeal({
    required SharedPreferences prefs,
    required String email,
    required List<String> roles,
  }) async {
    final secret = await _getOrCreateDeviceSealSecret(prefs);
    final normalizedRoles = roles
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final canonical =
        'roles_v1|${email.trim().toLowerCase()}|${normalizedRoles.join(',')}';
    return hmacSha256Hex(secret, canonical);
  }

  static Future<bool> verifyUserRolesSeal({
    required SharedPreferences prefs,
    required String email,
    required List<String> roles,
    required String? seal,
  }) async {
    if (seal == null || seal.length != 64) return false;
    final expected = await computeUserRolesSeal(
      prefs: prefs,
      email: email,
      roles: roles,
    );
    return constantTimeEquals(utf8.encode(expected), utf8.encode(seal));
  }

  /// Firma criptográficamente el estado de pago obligatorio de Wompi de una cuenta
  /// (`pagoWompiPendiente`, `pagoWompiActivo` y `rolSolicitadoRegistro`) para que
  /// sea imposible saltarse el cobro editando `localStorage` o devolviéndose.
  static Future<String> computePaymentStateSeal({
    required SharedPreferences prefs,
    required String email,
    required bool paymentPending,
    required bool paymentActive,
    required String requestedRoleId,
    required List<String> roles,
  }) async {
    final secret = await _getOrCreateDeviceSealSecret(prefs);
    final normalizedRoles = roles
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final canonical =
        'paystate_v1|${email.trim().toLowerCase()}|${paymentPending ? 1 : 0}|${paymentActive ? 1 : 0}|${requestedRoleId.trim().toLowerCase()}|${normalizedRoles.join(',')}';
    return hmacSha256Hex(secret, canonical);
  }

  static Future<bool> verifyPaymentStateSeal({
    required SharedPreferences prefs,
    required String email,
    required bool paymentPending,
    required bool paymentActive,
    required String requestedRoleId,
    required List<String> roles,
    required String? seal,
  }) async {
    if (seal == null || seal.length != 64) return false;
    final expected = await computePaymentStateSeal(
      prefs: prefs,
      email: email,
      paymentPending: paymentPending,
      paymentActive: paymentActive,
      requestedRoleId: requestedRoleId,
      roles: roles,
    );
    return constantTimeEquals(utf8.encode(expected), utf8.encode(seal));
  }

  /// Emite y persiste un sello criptográfico para la sesión activa con TTL.
  static Future<void> sealActiveSession({
    required SharedPreferences prefs,
    required String email,
    required List<String> roles,
    bool paymentPending = false,
    String pendingRoleId = 'persona',
    int? issuedAtMs,
  }) async {
    final secret = await _getOrCreateDeviceSealSecret(prefs);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final effectiveIssuedMs = issuedAtMs ?? nowMs;
    final expiresAtMs = effectiveIssuedMs + maxSessionAge.inMilliseconds;
    final sortedRoles = roles
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final cleanPendingRole = pendingRoleId.trim().toLowerCase();

    final payload =
        'session_v2|${email.trim().toLowerCase()}|${sortedRoles.join(',')}|${paymentPending ? 1 : 0}|$cleanPendingRole|$effectiveIssuedMs|$nowMs|$expiresAtMs';
    final mac = hmacSha256Hex(secret, payload);
    final record = jsonEncode(<String, dynamic>{
      'email': email.trim().toLowerCase(),
      'roles': sortedRoles,
      'payPend': paymentPending,
      'pendRol': cleanPendingRole,
      'iat': effectiveIssuedMs,
      'lat': nowMs,
      'exp': expiresAtMs,
      'mac': mac,
    });
    await prefs.setString(_kSessionSealPref, record);
  }

  /// Verifica autenticidad y vigencia (TTL absoluto + inactividad) de la sesión
  /// almacenada en preferencias locales.
  static Future<bool> verifyAndTouchSessionSeal({
    required SharedPreferences prefs,
    required String expectedEmail,
    required List<String> expectedRoles,
    bool expectedPaymentPending = false,
    String expectedPendingRoleId = 'persona',
  }) async {
    final raw = prefs.getString(_kSessionSealPref);
    if (raw == null || raw.trim().isEmpty) return false;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;

      final email = (decoded['email'] ?? '').toString().trim().toLowerCase();
      if (email.isEmpty || email != expectedEmail.trim().toLowerCase()) {
        return false;
      }

      final rawRoles = decoded['roles'];
      final sealedRoles = rawRoles is List
          ? (rawRoles
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toSet()
                .toList()
              ..sort())
          : <String>[];
      final currentSortedRoles = expectedRoles
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (sealedRoles.join(',') != currentSortedRoles.join(',')) {
        return false;
      }

      final iat = decoded['iat'] is int ? decoded['iat'] as int : 0;
      final lat = decoded['lat'] is int ? decoded['lat'] as int : 0;
      final exp = decoded['exp'] is int ? decoded['exp'] as int : 0;
      final mac = (decoded['mac'] ?? '').toString();
      if (iat <= 0 || lat <= 0 || exp <= 0 || mac.length != 64) {
        return false;
      }

      final secret = await _getOrCreateDeviceSealSecret(prefs);
      final bool hasV2Fields = decoded.containsKey('payPend');
      final bool sealedPayPend = decoded['payPend'] == true;
      final String sealedPendRol =
          (decoded['pendRol'] ?? 'persona').toString().trim().toLowerCase();

      if (hasV2Fields && sealedPayPend != expectedPaymentPending) {
        return false;
      }

      final payload = hasV2Fields
          ? 'session_v2|$email|${sealedRoles.join(',')}|${sealedPayPend ? 1 : 0}|$sealedPendRol|$iat|$lat|$exp'
          : 'session_v1|$email|${sealedRoles.join(',')}|$iat|$lat|$exp';
      final expectedMac = hmacSha256Hex(secret, payload);
      if (!constantTimeEquals(utf8.encode(expectedMac), utf8.encode(mac))) {
        return false;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs > exp || (nowMs - lat) > maxSessionIdle.inMilliseconds) {
        return false;
      }

      // Renueva marca de actividad manteniendo `iat` original.
      await sealActiveSession(
        prefs: prefs,
        email: email,
        roles: sealedRoles,
        paymentPending: expectedPaymentPending,
        pendingRoleId: expectedPendingRoleId,
        issuedAtMs: iat,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearSessionSeal(SharedPreferences prefs) async {
    await prefs.remove(_kSessionSealPref);
  }

  // ===========================================================================
  // 3. CONTROL DE TASA Y ANTI-FUERZA BRUTA (PERSISTENTE + VENTANA DESLIZANTE)
  // ===========================================================================

  /// Control de tasa en memoria para operaciones de alta frecuencia (IA, PQRS, Pagos).
  static RateLimitDecision checkRateLimit({
    required String actionKey,
    required int maxAttempts,
    required Duration window,
    String customErrorMessage =
        'Has realizado demasiadas solicitudes seguidas. Espera unos segundos e inténtalo de nuevo.',
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cutoffMs = nowMs - window.inMilliseconds;
    final history = _slidingWindows.putIfAbsent(actionKey, () => <int>[]);
    history.removeWhere((ts) => ts < cutoffMs);

    if (history.length >= maxAttempts) {
      final oldestMs = history.first;
      final waitSec =
          ((oldestMs + window.inMilliseconds - nowMs) / 1000).ceil().clamp(
            1,
            3600,
          );
      return RateLimitDecision(
        allowed: false,
        retryAfterSeconds: waitSec,
        message: '$customErrorMessage (${waitSec}s)',
      );
    }

    history.add(nowMs);
    return const RateLimitDecision(allowed: true);
  }

  /// Verifica si una cuenta/acción de autenticación se encuentra bloqueada
  /// temporalmente por intentos fallidos repetidos (persiste ante recargas Web).
  static Future<RateLimitDecision> checkAuthLockout(String scopeKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLockoutRegistryPref);
      if (raw == null || raw.isEmpty) {
        return const RateLimitDecision(allowed: true);
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const RateLimitDecision(allowed: true);

      final hashedScope = sha256Hex('$_kDomainPepper::lockout::$scopeKey')
          .substring(0, 24);
      final entry = decoded[hashedScope];
      if (entry is! Map) return const RateLimitDecision(allowed: true);

      final lockedUntilMs = entry['lockedUntilMs'] is int
          ? entry['lockedUntilMs'] as int
          : 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (lockedUntilMs > nowMs) {
        final secs = ((lockedUntilMs - nowMs) / 1000).ceil().clamp(1, 3600);
        return RateLimitDecision(
          allowed: false,
          retryAfterSeconds: secs,
          message:
              'Por seguridad, el acceso se bloqueó temporalmente tras varios intentos fallidos. Intenta de nuevo en $secs segundos.',
        );
      }
      return const RateLimitDecision(allowed: true);
    } catch (_) {
      return const RateLimitDecision(allowed: true);
    }
  }

  /// Registra un fallo de autenticación y aplica bloqueo exponencial a partir
  /// del 5.º intento fallido dentro de 10 minutos.
  static Future<void> recordAuthFailure(String scopeKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLockoutRegistryPref);
      final registry = <String, dynamic>{};
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          registry.addAll(Map<String, dynamic>.from(decoded));
        }
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final hashedScope = sha256Hex('$_kDomainPepper::lockout::$scopeKey')
          .substring(0, 24);
      final existing = registry[hashedScope] is Map
          ? Map<String, dynamic>.from(registry[hashedScope] as Map)
          : <String, dynamic>{};

      final lastFailMs = existing['lastFailMs'] is int
          ? existing['lastFailMs'] as int
          : 0;
      final previousCount = (nowMs - lastFailMs) > 600000
          ? 0
          : (existing['count'] is int ? existing['count'] as int : 0);
      final nextCount = previousCount + 1;

      var lockedUntilMs = 0;
      if (nextCount >= 10) {
        lockedUntilMs = nowMs + const Duration(minutes: 10).inMilliseconds;
      } else if (nextCount >= 7) {
        lockedUntilMs = nowMs + const Duration(minutes: 3).inMilliseconds;
      } else if (nextCount >= 5) {
        lockedUntilMs = nowMs + const Duration(seconds: 60).inMilliseconds;
      }

      registry[hashedScope] = <String, dynamic>{
        'count': nextCount,
        'lastFailMs': nowMs,
        'lockedUntilMs': lockedUntilMs,
      };

      await prefs.setString(_kLockoutRegistryPref, jsonEncode(registry));
    } catch (_) {
      // No interrumpe el flujo si el almacenamiento está restringido.
    }
  }

  static Future<void> resetAuthFailures(String scopeKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLockoutRegistryPref);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final registry = Map<String, dynamic>.from(decoded);
      final hashedScope = sha256Hex('$_kDomainPepper::lockout::$scopeKey')
          .substring(0, 24);
      if (registry.remove(hashedScope) != null) {
        await prefs.setString(_kLockoutRegistryPref, jsonEncode(registry));
      }
    } catch (_) {}
  }

  // ===========================================================================
  // 4. POLÍTICA DE CONTRASEÑAS FUERTES Y VALIDACIÓN DE PAGOS (LUHN + EXPIRY)
  // ===========================================================================

  static const Set<String> _commonWeakPasswords = <String>{
    '12345678',
    '123456789',
    '1234567890',
    'password',
    'password1',
    'password123',
    'contraseña',
    'contrasena',
    'colombia1',
    'colombia123',
    'qwerty123',
    'qwertyui',
    'admin123',
    'admin1234',
    'secop123',
    'secop2026',
    'contratalegal',
    'abcd1234',
    '11111111',
    '00000000',
  };

  /// Valida política robusta de contraseña (NIST SP 800-63B + complejidad):
  /// devuelve `null` si es válida o un mensaje claro en español si no cumple.
  static String? validateStrongPassword(String? rawPassword) {
    final value = rawPassword ?? '';
    if (value.isEmpty) {
      return 'Ingresa una contraseña.';
    }
    if (value.length < 8) {
      return 'Usa al menos 8 caracteres para proteger tu cuenta.';
    }
    if (value.length > 128) {
      return 'La contraseña no puede superar 128 caracteres.';
    }
    if (_commonWeakPasswords.contains(value.trim().toLowerCase())) {
      return 'Esta contraseña es muy común e insegura. Elige una combinación única.';
    }
    if (!RegExp(r'[A-ZÁÉÍÓÚÑ]').hasMatch(value)) {
      return 'Incluye al menos una letra mayúscula.';
    }
    if (!RegExp(r'[a-záéíóúñ]').hasMatch(value)) {
      return 'Incluye al menos una letra minúscula.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Incluye al menos un número.';
    }
    return null;
  }

  /// Algoritmo de Luhn (ISO/IEC 7812) para validar integridad numérica de tarjetas.
  static bool isValidLuhnCardNumber(String rawCardNumber) {
    final digits = rawCardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 13 || digits.length > 19) return false;
    if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return false;

    var sum = 0;
    var alternate = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = digits.codeUnitAt(i) - 48;
      if (n < 0 || n > 9) return false;
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return (sum % 10) == 0;
  }

  /// Verifica que la fecha de expiración `MM/AA` corresponda a un mes vigente o futuro.
  static bool isValidFutureCardExpiry(String rawExpiry) {
    final match = RegExp(
      r'^(0[1-9]|1[0-2])\/([0-9]{2})$',
    ).firstMatch(rawExpiry.trim());
    if (match == null) return false;

    final month = int.tryParse(match.group(1)!) ?? 0;
    final twoDigitYear = int.tryParse(match.group(2)!) ?? -1;
    if (month < 1 || month > 12 || twoDigitYear < 0) return false;

    final fullYear = 2000 + twoDigitYear;
    final now = DateTime.now();
    if (fullYear > now.year + 25) return false;
    if (fullYear < now.year) return false;
    if (fullYear == now.year && month < now.month) return false;
    return true;
  }

  // ===========================================================================
  // 5. SANITIZADORES CONTRA INYECCIÓN (SoQL, CSV FORMULA, PROMPT IA, ARCHIVOS)
  // ===========================================================================

  /// Sanitiza literales para cláusulas SoQL (`$where` en Socrata / Datos Abiertos),
  /// eliminando caracteres de control, comentarios SQL y escapes peligrosos.
  static String sanitizeSoqlToken(String raw, {int maxLength = 80}) {
    var clean = raw
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .replaceAll('--', ' ')
        .replaceAll('/*', ' ')
        .replaceAll('*/', ' ')
        .replaceAll(';', ' ')
        .replaceAll('\\', ' ')
        .replaceAll("'", '')
        .replaceAll('"', '')
        .replaceAll('%', '')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.length > maxLength) {
      clean = clean.substring(0, maxLength).trim();
    }
    return clean;
  }

  /// Neutraliza ataques de CSV / Spreadsheet Formula Injection (OWASP CWE-1236)
  /// en Excel, Google Sheets y LibreOffice Calc cuando una celda inicia con
  /// `=`, `+`, `-`, `@`, `|`, tabulación o retorno de carro.
  static String neutralizeSpreadsheetFormula(String raw) {
    final clean = raw.replaceAll('\x00', '');
    if (clean.isEmpty) return '';
    final trimmedLeft = clean.trimLeft();
    if (trimmedLeft.isEmpty) return clean;

    final firstChar = trimmedLeft[0];
    const dangerousTriggers = <String>['=', '+', '-', '@', '|'];
    if (dangerousTriggers.contains(firstChar) ||
        clean.startsWith('\t') ||
        clean.startsWith('\r')) {
      // Si es un número negativo legítimo puro (ej. "-1500.50"), es seguro;
      // de lo contrario se antepone comilla simple para forzar modo texto.
      if (firstChar == '-' && RegExp(r'^-[0-9]+([.,][0-9]+)?$').hasMatch(trimmedLeft)) {
        return clean;
      }
      return "'$clean";
    }
    return clean;
  }

  /// Formatea una celda CSV conforme a RFC 4180 + protección contra fórmulas.
  static String formatSafeCsvCell(dynamic rawValue, {String delimiter = ';'}) {
    final raw = (rawValue ?? '').toString();
    final safeText = neutralizeSpreadsheetFormula(raw);
    final escaped = safeText.replaceAll('"', '""');
    if (escaped.contains(delimiter) ||
        escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  /// Sanitiza nombres de archivo de descarga contra Path Traversal y caracteres reservados.
  static String sanitizeFileName(
    String rawName, {
    String fallback = 'reporte_contrata_legal.csv',
  }) {
    var clean = rawName
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .replaceAll('..', '_')
        .replaceAll(RegExp(r'[/\\<>:"|?*]'), '_')
        .trim();
    clean = clean.replaceAll(RegExp(r'^\.+'), '');
    if (clean.isEmpty) return fallback;
    if (clean.length > 120) {
      clean = clean.substring(0, 120);
    }
    return clean;
  }

  /// Sanitiza texto plano de formularios eliminando caracteres de control e
  /// inyecciones HTML/script y aplicando límite estricto de longitud.
  static String sanitizePlainText(String? raw, {int maxLength = 300}) {
    if (raw == null) return '';
    var clean = raw
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
        .replaceAll('<', '‹')
        .replaceAll('>', '›')
        .trim();
    if (clean.length > maxLength) {
      clean = clean.substring(0, maxLength).trim();
    }
    return clean;
  }

  /// Normaliza dígitos de cédula o NIT dejando únicamente dígitos numéricos limpios.
  static String normalizeDocumentDigits(String? raw) {
    if (raw == null) return '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length > 20 ? digits.substring(0, 20) : digits;
  }

  /// Sanitiza entradas no confiables antes de interpolarlas en prompts de Gemini,
  /// mitigando Prompt Injection directo e indirecto.
  static String sanitizePromptInput(String raw, {int maxLength = 1200}) {
    var clean = raw
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
        // Evita ruptura de delimitadores XML defensivos
        .replaceAll('<', '‹')
        .replaceAll('>', '›')
        .trim();

    // Neutraliza directivas típicas de secuestro de instrucciones del sistema
    final overridePattern = RegExp(
      r'(ignore\s+(all\s+)?(previous|above|prior)\s+instructions|'
      r'ignora\s+(todas\s+)?las\s+instrucciones\s+(anteriores|previas)|'
      r'olvida\s+tus\s+instrucciones|'
      r'system\s*prompt\s*:|'
      r'developer\s*mode)',
      caseSensitive: false,
    );
    clean = clean.replaceAll(overridePattern, '[instrucción filtrada]');

    if (clean.length > maxLength) {
      clean = '${clean.substring(0, maxLength)}…';
    }
    return clean;
  }

  // ===========================================================================
  // 6. SEGURIDAD DE URLS, DOMINIOS OFICIALES SECOP Y AVATARES RASTER
  // ===========================================================================

  static const List<String> _officialGovAllowedDomains = <String>[
    'secop.gov.co',
    'colombiacompra.gov.co',
    'datos.gov.co',
    'funcionpublica.gov.co',
  ];

  static bool _isPrivateOrLoopbackHost(String host) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty ||
        h == 'localhost' ||
        h.endsWith('.localhost') ||
        h.endsWith('.local') ||
        h.endsWith('.internal') ||
        h == '[::1]' ||
        h == '::1' ||
        h == '0.0.0.0') {
      return true;
    }

    final ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
        .firstMatch(h);
    if (ipv4 != null) {
      final o1 = int.tryParse(ipv4.group(1)!) ?? -1;
      final o2 = int.tryParse(ipv4.group(2)!) ?? -1;
      if (o1 == 10 || o1 == 127 || o1 == 0) return true;
      if (o1 == 169 && o2 == 254) return true;
      if (o1 == 192 && o2 == 168) return true;
      if (o1 == 172 && o2 >= 16 && o2 <= 31) return true;
    }
    return false;
  }

  /// Verifica estrictamente que un enlace apunte por HTTPS a un portal oficial
  /// del Estado colombiano (`.gov.co` autorizado), bloqueando `javascript:`,
  /// `data:`, credenciales embebidas y Open Redirects hacia sitios de phishing.
  static Uri? validateOfficialGovUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty || trimmed.length > 2048) return null;

    final candidate = trimmed.startsWith('http://')
        ? 'https://${trimmed.substring(7)}'
        : trimmed;

    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
    if (uri.userInfo.isNotEmpty) return null;

    final host = uri.host.trim().toLowerCase();
    if (host.isEmpty || _isPrivateOrLoopbackHost(host)) return null;

    final isAllowed = _officialGovAllowedDomains.any(
      (domain) => host == domain || host.endsWith('.$domain'),
    );
    if (!isAllowed) return null;

    return uri;
  }

  /// Valida URLs externas de imagen de perfil exigiendo `https://` y bloqueando
  /// redes privadas/loopback (anti-SSRF / Mixed Content / esquemas peligrosos).
  static Uri? validateSafeExternalImageUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty || trimmed.length > 1024) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
    if (uri.userInfo.isNotEmpty) return null;

    final host = uri.host.trim().toLowerCase();
    if (host.isEmpty || !host.contains('.') || _isPrivateOrLoopbackHost(host)) {
      return null;
    }

    // Bloquea explícitamente extensiones vectoriales ejecutables (.svg / .svgz / .html)
    final lowerPath = uri.path.toLowerCase();
    if (lowerPath.endsWith('.svg') ||
        lowerPath.endsWith('.svgz') ||
        lowerPath.endsWith('.html') ||
        lowerPath.endsWith('.htm')) {
      return null;
    }
    return uri;
  }

  /// Inspecciona la firma binaria (Magic Bytes) para permitir únicamente imágenes
  /// rasterizadas reales (PNG, JPEG, WEBP, GIF) y bloquear SVG/HTML con XSS.
  static String? detectSafeRasterImageMime(
    Uint8List bytes, {
    int maxBytes = maxAvatarBytes,
  }) {
    if (bytes.length < 12 || bytes.length > maxBytes) return null;

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // WEBP: "RIFF" .... "WEBP"
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    // GIF87a / GIF89a
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      return 'image/gif';
    }

    return null;
  }

  /// Valida y normaliza un Data URL `data:image/...;base64,...` asegurando que
  /// sea raster seguro y no exceda la cuota local.
  static Uint8List? decodeSafeRasterDataUrl(
    String? dataUrl, {
    int maxBytes = maxAvatarBytes,
  }) {
    if (dataUrl == null) return null;
    final trimmed = dataUrl.trim();
    if (!trimmed.startsWith('data:image/')) return null;

    // Máximo aproximado en Base64 para evitar decodificaciones gigantes en memoria
    final maxBase64Chars = ((maxBytes * 4) ~/ 3) + 256;
    if (trimmed.length > maxBase64Chars) return null;

    final commaIdx = trimmed.indexOf(',');
    if (commaIdx <= 0) return null;
    final header = trimmed.substring(0, commaIdx).toLowerCase();
    if (!header.contains(';base64') || header.contains('svg')) {
      return null;
    }

    try {
      final bytes = base64Decode(trimmed.substring(commaIdx + 1));
      final mime = detectSafeRasterImageMime(bytes, maxBytes: maxBytes);
      if (mime == null) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Valida Magic Bytes para documentos contractuales (PDF, PNG, JPEG, WEBP,
  /// DOCX/ZIP y DOC OLE2), rechazando ejecutables, scripts, HTML o SVG (XSS).
  static String? detectSafeContractDocumentMime(
    Uint8List bytes, {
    String fileName = '',
    int maxBytes = maxContractDocumentBytes,
  }) {
    if (bytes.length < 8 || bytes.length > maxBytes) return null;

    // PDF: "%PDF-" (25 50 44 46 2D)
    if (bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D) {
      return 'application/pdf';
    }

    // Imágenes raster seguras (PNG, JPEG, WEBP)
    final raster = detectSafeRasterImageMime(bytes, maxBytes: maxBytes);
    if (raster != null && raster != 'image/gif') {
      return raster;
    }

    final lowerName = fileName.trim().toLowerCase();

    // DOCX (contenedor OpenXML PK\x03\x04)
    if (bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04 &&
        lowerName.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    // DOC clásico OLE2 (D0 CF 11 E0 A1 B1 1A E1)
    if (bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0 &&
        lowerName.endsWith('.doc')) {
      return 'application/msword';
    }

    return null;
  }

  /// Redacta detalles técnicos internos, trazas y posibles llaves antes de
  /// mostrar errores en la interfaz de usuario.
  static String sanitizeErrorMessage(
    Object error, {
    String fallback =
        'No fue posible completar la operación en este momento. Intenta nuevamente.',
  }) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return fallback;

    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('failed host lookup')) {
      return 'Error de conexión segura con el servidor. Verifica tu red e inténtalo nuevamente.';
    }
    if (lower.contains('timeoutexception')) {
      return 'El servidor tardó demasiado en responder. Intenta nuevamente en unos segundos.';
    }
    if (lower.contains('aizasy') ||
        lower.contains('integrity') ||
        lower.contains('stacktrace') ||
        lower.contains('type \'') ||
        lower.contains('nosuchmethoderror')) {
      return fallback;
    }

    return raw.length > 220 ? fallback : raw;
  }
}

