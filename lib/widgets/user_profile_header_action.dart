import 'package:flutter/material.dart';

import 'custom_app_bar.dart';

/// Acción estandarizada de perfil de usuario y notificaciones que delega a
/// [CustomUserHeaderActions], asegurando 1 sola campana, avatar sin borde
/// blanco exterior y menú desplegable unificado en todas las vistas.
class UserProfileHeaderAction extends StatelessWidget {
  const UserProfileHeaderAction({
    super.key,
    this.onLogout,
    this.darkTheme = false,
    this.showNotificationBell = true,
  });

  final VoidCallback? onLogout;
  final bool darkTheme;
  final bool showNotificationBell;

  @override
  Widget build(BuildContext context) {
    return CustomUserHeaderActions(
      onLogout: onLogout,
      darkTheme: darkTheme,
      showNotificationBell: showNotificationBell,
    );
  }
}
