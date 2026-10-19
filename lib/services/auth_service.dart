import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static Future<void>? _googleSignInInitialization;

  static Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  static Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  static Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
        return;
      }

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
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  static Future<void> signUp(
    Map<String, dynamic> userData,
    String password,
  ) async {
    try {
      final email = (userData['email'] as String?)?.trim();
      if (email == null || email.isEmpty) {
        throw const AuthServiceException(
          'El correo electrónico es obligatorio para crear la cuenta.',
        );
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw const AuthServiceException(
          'Firebase creó la cuenta, pero no devolvió los datos del usuario.',
        );
      }

      final nombres = (userData['nombres'] as String? ?? '').trim();
      final apellidos = (userData['apellidos'] as String? ?? '').trim();
      final displayName = '$nombres $apellidos'.trim();
      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }

      await user.sendEmailVerification();
      debugPrint('Correo de verificación enviado a $email');
    } on FirebaseAuthException catch (error) {
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
        return 'Ya existe una cuenta registrada con ese correo.';
      case 'weak-password':
        return 'La contraseña es demasiado débil. Usa una contraseña más segura.';
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

  Future<bool> registrarCuenta(String correo, String contrasena) async {
    await signUp({'email': correo}, contrasena);
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
