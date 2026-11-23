import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/consentimiento_equipo_screen.dart';
import 'screens/main_dashboard.dart';
import 'screens/portada_screen.dart';
import 'screens/portal_contratista_invitado_screen.dart';
import 'services/auth_service.dart';
import 'services/consent_service.dart';
import 'services/equipo_juridico_service.dart';
import 'services/juridico_contratacion_service.dart';
import 'widgets/acceso_plan_guard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.visitante, this.autenticado});

  final Widget? visitante;
  final Widget? autenticado;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && visitante == null) {
      final guestToken = JuridicoContratacionService.extraerTokenInvitadoDeUri(
        Uri.base,
      );
      if (guestToken.isNotEmpty) {
        return PortalContratistaInvitadoScreen(token: guestToken);
      }
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        AuthService.authStateVersion,
        ConsentService.cambios,
      ]),
      builder: (context, _) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !AuthService.hasActiveSession) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (FirebaseAuth.instance.currentUser != null) {
              // Autorización de tratamiento de datos (Ley 1581 de 2012):
              // nadie entra a la app sin haber aceptado la versión vigente de
              // la política. El abogado de un equipo ve la versión con el
              // nombre del equipo que lo agregó.
              if (EquipoJuridicoService.consentimientoPendiente) {
                return const ConsentimientoEquipoScreen();
              }
              if (ConsentService.verificando) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (ConsentService.pendiente) {
                return const ConsentimientoUsuarioScreen();
              }
              return AccesoPlanGuard(
                child: autenticado ?? const MainDashboard(),
              );
            }

            return visitante ?? const PortadaScreen();
          },
        );
      },
    );
  }
}
