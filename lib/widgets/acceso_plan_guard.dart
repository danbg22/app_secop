import 'package:flutter/material.dart';

import '../screens/activacion_gratuita_screen.dart';
import '../screens/pasarela_pago_wompi_screen.dart';
import '../services/acceso_planes.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import 'admin_verification_banner.dart';

class AccesoPlanGuard extends StatelessWidget {
  const AccesoPlanGuard({
    super.key,
    required this.child,
    this.permitirPago = false,
  });

  final Widget child;
  final bool permitirPago;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AuthService.authStateVersion,
    builder: (context, _) {
      if (AuthService.isActiveUserAdmin) return child;
      if (AuthService.adminPendienteDeVerificacion) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      const AdminVerificationBanner(),
                      TextButton(
                        onPressed: () => _cerrarSesion(context),
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      final estado = AccesoPlanes.estado;
      if (estado != null && (estado.roles.isNotEmpty || permitirPago)) {
        return child;
      }
      if ((estado == null && !AccesoPlanes.hayError) ||
          (AccesoPlanes.revisando && estado?.bloqueoConfirmado != true)) {
        return const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Verificando el plan',
            ),
          ),
        );
      }
      if (estado == null ||
          estado.preparando ||
          (AccesoPlanes.hayError && !estado.bloqueoConfirmado)) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    estado?.preparando == true
                        ? 'Estamos preparando tu cuenta.'
                        : 'No pudimos verificar tu plan en este momento.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: AccesoPlanes.refrescar,
                    child: const Text('Volver a verificar'),
                  ),
                  TextButton(
                    onPressed: () => _cerrarSesion(context),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      final rol = PaymentService.obtenerConfiguracionRol(estado.rolInicial);
      if (rol.esGratuito) return ActivacionGratuitaScreen(rolId: rol.id);
      return PasarelaPagoWompiScreen(rolId: rol.id);
    },
  );

  Future<void> _cerrarSesion(BuildContext context) async {
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/portada', (_) => false);
  }
}
