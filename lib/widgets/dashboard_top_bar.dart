import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onLogout,
    this.transparent = false,
    this.showSearch = true,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onLogout;
  final bool transparent;
  final bool showSearch;

  static const Color _azulOscuro = Color(0xFF1A2B4C);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return ValueListenableBuilder<int>(
      valueListenable: AuthService.authStateVersion,
      builder: (context, _, _) {
        final User? currentUser = FirebaseAuth.instance.currentUser;
        final String fullName = AuthService.getActiveUserDisplayName();
        final String? photoURL = currentUser?.photoURL;
        final String initial =
            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

        return Container(
          decoration: BoxDecoration(
            color: transparent ? Colors.transparent : const Color(0xFFFAF7F0),
            border: transparent
                ? null
                : const Border(
                    bottom: BorderSide(color: Color(0xFFEDE8DF), width: 1),
                  ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 28,
            vertical: 10,
          ),
          child: Row(
            children: [
              if (showSearch)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: searchController,
                          onSubmitted: onSearchSubmitted,
                          style: const TextStyle(fontSize: 13, color: _azulOscuro),
                          decoration: InputDecoration(
                            hintText: 'Busca contratos, entidades...',
                            hintStyle: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontSize: 13,
                            ),
                            prefixIcon: IconButton(
                              tooltip: 'Buscar en SECOP + SIGEP',
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  onSearchSubmitted(searchController.text),
                              icon: const Icon(
                                Icons.search,
                                color: _azulOscuro,
                                size: 19,
                              ),
                            ),
                            filled: true,
                            fillColor: transparent
                                ? Colors.white.withValues(alpha: 0.72)
                                : const Color(0xFFEDEFF3),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: _azulOscuro,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              SizedBox(width: isMobile ? 10 : 24),
              PopupMenuButton<String>(
                tooltip: 'Opciones del perfil',
                onSelected: (value) {
                  if (value == 'logout') onLogout();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Cerrar sesión'),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: isMobile ? 16 : 18,
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
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? 96 : 170,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _azulOscuro,
                              fontSize: isMobile ? 12.5 : 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!isMobile) ...[
                            const SizedBox(height: 1),
                            Text(
                              'Consulta ciudadana',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.blueGrey.shade600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
