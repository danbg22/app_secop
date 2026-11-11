// Firebase de mentira para las capturas: sin red ni sesión real.
// ignore_for_file: invalid_use_of_visible_for_testing_member, depend_on_referenced_packages
import 'package:app_secop/services/admin_access.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MultiFactorFalso extends MultiFactorPlatform
    with MockPlatformInterfaceMixin {
  _MultiFactorFalso(super.auth);
}

class _UsuarioFalso extends UserPlatform with MockPlatformInterfaceMixin {
  _UsuarioFalso(FirebaseAuthPlatform auth, String correo)
    : super(
        auth,
        _MultiFactorFalso(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'vista-previa',
            email: correo,
            displayName: 'Usuario de Prueba',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: const [],
        ),
      );
}

class _AuthFalso extends FirebaseAuthPlatform with MockPlatformInterfaceMixin {
  _AuthFalso() : super();

  UserPlatform? usuario;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => usuario;

  @override
  Stream<UserPlatform?> authStateChanges() => Stream.value(usuario);

  @override
  Stream<UserPlatform?> idTokenChanges() => Stream.value(usuario);

  @override
  Stream<UserPlatform?> userChanges() => Stream.value(usuario);
}

final _AuthFalso _auth = _AuthFalso();

Future<void> prepararFirebaseFalso() async {
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();
  FirebaseAuthPlatform.instance = _auth;
}

/// Simula la sesión de una cuenta administradora (todos los roles), para
/// ver el menú completo. Con `false`, vuelve a la sesión sin iniciar.
///
/// Ojo: las pantallas que muestran el correo de la sesión (Mi perfil)
/// enseñarían el de esa cuenta; para ellas, [sesionDeEjemplo].
void sesionConTodosLosRoles(bool activa) {
  _auth.usuario = activa
      ? _UsuarioFalso(_auth, AdminAccess.correosAdministradores.first)
      : null;
}

/// Sesión de una cuenta corriente con un correo de ejemplo.
void sesionDeEjemplo(bool activa) {
  _auth.usuario = activa ? _UsuarioFalso(_auth, 'persona@ejemplo.co') : null;
}
