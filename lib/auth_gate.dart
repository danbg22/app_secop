import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/main_dashboard.dart';
import 'screens/pasarela_pago_wompi_screen.dart';
import 'screens/portada_screen.dart';
import 'screens/portal_contratista_invitado_screen.dart';
import 'services/auth_service.dart';
import 'services/juridico_contratacion_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final guestToken = JuridicoContratacionService.extraerTokenInvitadoDeUri(
        Uri.base,
      );
      if (guestToken.isNotEmpty) {
        return PortalContratistaInvitadoScreen(token: guestToken);
      }
    }

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
              // Bloqueo de ciberseguridad estricto: ninguna cuenta registrada
              // sin pago aprobado en Wompi puede entrar al panel principal,
              // ni devolviéndose con el botón Atrás ni recargando la URL.
              if (AuthService.requiresMandatoryWompiPayment) {
                return PasarelaPagoWompiScreen(
                  rolId: AuthService.getPendingRegistrationRoleId(),
                  esFlujoRegistro: true,
                );
              }
              return const MainDashboard();
            }

            return const PortadaScreen();
          },
        );
      },
    );
  }
}
