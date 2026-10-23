import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class UserProfileHeaderAction extends StatelessWidget {
  const UserProfileHeaderAction({
    super.key,
    this.onLogout,
    this.darkTheme = false,
  });

  final VoidCallback? onLogout;
  final bool darkTheme;

  static const Color _azulOscuro = Color(0xFF1A2B4C);

  Future<void> _performLogout(BuildContext context) async {
    if (onLogout != null) {
      onLogout!();
      return;
    }
    await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AuthService.authStateVersion,
      builder: (context, _, _) {
        final User? currentUser = FirebaseAuth.instance.currentUser;
        final String fullName = AuthService.getActiveUserDisplayName();
        final String firstName = AuthService.getActiveUserFirstName();
        final String? photoURL = currentUser?.photoURL;
        final String initial =
            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

        final Color textColor = darkTheme ? Colors.white : _azulOscuro;
        final Color subtextColor =
            darkTheme ? Colors.white70 : const Color(0xFF475569);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Campana de notificaciones con badge
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Tienes 3 alertas activas de contratación pública en SECOP II.',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: textColor,
                      size: 22,
                    ),
                    Positioned(
                      right: 1,
                      top: 1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Menú desplegable con avatar y nombre del usuario activo
            PopupMenuButton<String>(
              tooltip: 'Opciones del perfil',
              onSelected: (value) {
                if (value == 'logout') {
                  _performLogout(context);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (AuthService.getActiveUserEmail().isNotEmpty)
                        Text(
                          AuthService.getActiveUserEmail(),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Color(0xFFDC2626)),
                      SizedBox(width: 10),
                      Text('Cerrar sesión'),
                    ],
                  ),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          photoURL != null ? NetworkImage(photoURL) : null,
                      backgroundColor: const Color(0xFFA91D54),
                      foregroundColor: Colors.white,
                      child: photoURL == null
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 9),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width < 520 ? 96 : 160,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hola, $firstName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (MediaQuery.sizeOf(context).width >= 520) ...[
                          const SizedBox(height: 1),
                          Text(
                            'Consulta ciudadana',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: subtextColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
