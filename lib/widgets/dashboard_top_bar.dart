import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onLogout,
    this.transparent = false,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onLogout;
  final bool transparent;

  static const Color _azulOscuro = Color(0xFF1A2B4C);

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String fullName =
        (currentUser?.displayName?.trim().isNotEmpty ?? false)
            ? currentUser!.displayName!.trim()
            : 'Daniel Bolaño';
    final String? photoURL = currentUser?.photoURL;
    final String initial =
        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'D';

    return Container(
      decoration: BoxDecoration(
        color: transparent ? Colors.transparent : const Color(0xFFFAF7F0),
        border: transparent
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFEDE8DF), width: 1),
              ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      child: Row(
        children: [
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
                          ? Colors.white.withValues(alpha: 0.28)
                          : const Color(0xFFEDEFF3),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
          ),
          const SizedBox(width: 24),
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
                            fontSize: 15,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _azulOscuro,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Consulta ciudadana',
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

