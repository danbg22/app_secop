import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Aviso para las cuentas administradoras cuyo correo aún no está verificado
/// en Firebase: sin verificación no se concede el acceso de administrador.
/// No ocupa espacio para el resto de usuarios.
class AdminVerificationBanner extends StatefulWidget {
  const AdminVerificationBanner({super.key});

  @override
  State<AdminVerificationBanner> createState() =>
      _AdminVerificationBannerState();
}

class _AdminVerificationBannerState extends State<AdminVerificationBanner> {
  bool _procesando = false;

  Future<void> _ejecutar(
    Future<void> Function() accion,
    String Function() mensajeExito,
  ) async {
    setState(() => _procesando = true);
    String mensaje;
    try {
      await accion();
      mensaje = mensajeExito();
    } on AuthServiceException catch (e) {
      mensaje = e.message;
    } catch (_) {
      mensaje = 'No fue posible completar la acción. Inténtalo de nuevo.';
    }
    if (!mounted) return;
    setState(() => _procesando = false);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AuthService.authStateVersion,
      builder: (context, _, _) {
        if (!AuthService.adminPendienteDeVerificacion) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      color: Color(0xFFB45309)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verifica tu correo para activar el acceso de administrador',
                      style: TextStyle(
                        color: Color(0xFF78350F),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tu cuenta (${AuthService.getActiveUserEmail()}) es administradora, '
                'pero el correo aún no está verificado. Abre el enlace que te enviamos '
                '(revisa también la carpeta de spam) y luego pulsa "Ya lo verifiqué".',
                style: const TextStyle(color: Color(0xFF92400E), fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _procesando
                        ? null
                        : () => _ejecutar(
                              AuthService.reenviarVerificacionCorreo,
                              () => 'Te enviamos un nuevo enlace de verificación.',
                            ),
                    icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                    label: const Text('Reenviar verificación'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _procesando
                        ? null
                        : () => _ejecutar(
                              AuthService.refrescarVerificacionCorreo,
                              () => AuthService.adminPendienteDeVerificacion
                                  ? 'Aún no vemos el correo verificado. Abre el enlace e inténtalo de nuevo.'
                                  : 'Acceso de administrador activado.',
                            ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Ya lo verifiqué'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
