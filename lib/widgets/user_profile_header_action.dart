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

  /// En escritorio el perfil vive al pie del menú lateral
  /// (`CollapsibleSideMenu`); la barra superior solo lo muestra en celular.
  static const double anchoEscritorio = 768;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= anchoEscritorio) {
      return const SizedBox.shrink();
    }
    return CustomUserHeaderActions(
      onLogout: onLogout,
      darkTheme: darkTheme,
      showNotificationBell: showNotificationBell,
    );
  }
}
