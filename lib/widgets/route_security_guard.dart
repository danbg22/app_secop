import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/portada_screen.dart';
import '../services/auth_service.dart';

/// Guardián de control de acceso para rutas protegidas (OWASP A01 - Broken Access Control).
///
/// Impide navegación forzada por URL en Web (`/#/perfil`, `/#/planes`,
/// `/#/pasarela-wompi`) cuando no existe una sesión autenticada e íntegra.
class RouteSecurityGuard extends StatelessWidget {
  const RouteSecurityGuard({
    super.key,
    required this.child,
    this.fallbackToPortada = false,
  });

  final Widget child;
  final bool fallbackToPortada;

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

