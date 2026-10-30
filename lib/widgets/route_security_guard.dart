import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/pasarela_pago_wompi_screen.dart';
import '../screens/portada_screen.dart';
import '../services/auth_service.dart';

/// Guardián de control de acceso para rutas protegidas (OWASP A01 - Broken Access Control).
///
/// Impide navegación forzada por URL en Web (`/#/perfil`, `/#/planes`,
/// `/#/home`) tanto cuando no existe sesión autenticada como cuando la cuenta
/// aún tiene pendiente el pago obligatorio inicial en Wompi.
class RouteSecurityGuard extends StatelessWidget {
  const RouteSecurityGuard({
    super.key,
    required this.child,
    this.fallbackToPortada = false,
    this.allowWhenPaymentPending = false,
  });

  final Widget child;
  final bool fallbackToPortada;
  final bool allowWhenPaymentPending;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AuthService.authStateVersion,
      builder: (context, _, _) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !AuthService.hasActiveSession) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasData || AuthService.hasActiveSession) {
              if (AuthService.requiresMandatoryWompiPayment &&
                  !allowWhenPaymentPending) {
                return PasarelaPagoWompiScreen(
                  rolId: AuthService.getPendingRegistrationRoleId(),
                  esFlujoRegistro: true,
                );
              }
              return child;
            }

            return fallbackToPortada
                ? const PortadaScreen()
                : const LoginScreen();
          },
        );
      },
    );
  }
}
