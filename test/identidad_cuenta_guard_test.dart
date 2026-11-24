// ignore_for_file: depend_on_referenced_packages

import 'package:app_secop/services/admin_access.dart';
import 'package:app_secop/widgets/identidad_cuenta_guard.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _AuthPrueba extends FirebaseAuthPlatform {
  late final _usuario = _UsuarioPrueba(this);

  @override
  UserPlatform get currentUser => _usuario;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;
}

class _SegundoFactorPrueba extends MultiFactorPlatform {
  _SegundoFactorPrueba(super.auth);
}

class _UsuarioPrueba extends UserPlatform {
  _UsuarioPrueba(FirebaseAuthPlatform auth)
    : super(
        auth,
        _SegundoFactorPrueba(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'uid-admin-prueba',
            email: AdminAccess.correosAdministradores.first,
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );

  @override
  Future<String?> getIdToken(bool forceRefresh) async => 'token-prueba';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    FirebaseAuthPlatform.instance = _AuthPrueba();
    await Firebase.initializeApp();
  });

  Future<void> abrir(WidgetTester tester, http.Response respuesta) {
    return http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: IdentidadCuentaGuard(child: Text('Acceso confirmado')),
          ),
        );
        await tester.pumpAndSettle();
      },
      () => MockClient((solicitud) async {
        expect(solicitud.url.path, '/identidadCuenta');
        return respuesta;
      }),
    );
  }

  testWidgets('un administrador verificado conserva acceso ante un 404 HTML', (
    tester,
  ) async {
    await abrir(tester, http.Response('<html>Not Found</html>', 404));
    expect(find.text('Acceso confirmado'), findsOneWidget);
  });

  testWidgets('una cédula duplicada conserva el bloqueo y muestra el motivo', (
    tester,
  ) async {
    await abrir(
      tester,
      http.Response(
        '{"error":{"status":"ALREADY_EXISTS","message":"Cédula duplicada."}}',
        409,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    expect(find.text('Acceso confirmado'), findsNothing);
    expect(find.text('Cédula duplicada.'), findsOneWidget);
  });
}
