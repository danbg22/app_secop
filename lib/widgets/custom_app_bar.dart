import 'package:flutter/material.dart';

import '../screens/perfil_usuario_screen.dart';
import '../services/auth_service.dart';

/// Cabecera estandarizada de Contrata Legal para todas las pantallas del SaaS.
/// Unifica buscador opcional, título/navegación opcional, una única campana de
/// notificaciones y el menú desplegable de usuario sin bordes blancos extraños.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.title,
    this.leading,
    this.showBackButton = false,
    this.showLogo = false,
    this.searchController,
    this.onSearchSubmitted,
    this.showSearch = false,
    this.showUserActions = true,
    this.transparent = false,
    this.darkTheme = false,
    this.onLogout,
    this.extraActions = const <Widget>[],
    this.isProfileScreen = false,
  });

  final String? title;
  final Widget? leading;
  final bool showBackButton;
  final bool showLogo;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchSubmitted;
  final bool showSearch;
  final bool showUserActions;
  final bool transparent;
  final bool darkTheme;
  final VoidCallback? onLogout;
  final List<Widget> extraActions;
  final bool isProfileScreen;

  static const Color _navy = Color(0xFF1A2B4C);

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 640;

    return Container(
      decoration: BoxDecoration(
        color: transparent ? Colors.transparent : const Color(0xFFFFFDF8),
        border: transparent
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFEDE6D6), width: 1),
              ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 26,
        vertical: 9,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 8),
            ] else if (showBackButton) ...[
              IconButton(
                tooltip: 'Regresar',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/home');
                  }
                },
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: darkTheme ? Colors.white : _navy,
                  size: 21,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (showLogo) ...[
              Image.asset(
                'assets/images/logo.png',
                height: isMobile ? 34 : 40,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(width: 10),
            ],
            if (title != null && title!.trim().isNotEmpty) ...[
              Flexible(
                flex: showSearch ? 0 : 1,
                child: Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: darkTheme ? Colors.white : _navy,
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (showSearch) const SizedBox(width: 16),
            ],
            if (showSearch && searchController != null)
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
                        style: const TextStyle(fontSize: 13, color: _navy),
                        decoration: InputDecoration(
                          hintText: 'Busca contratos, entidades...',
                          hintStyle: TextStyle(
                            color: Colors.blueGrey.shade400,
                            fontSize: 13,
                          ),
                          prefixIcon: IconButton(
                            tooltip: 'Buscar en SECOP + SIGEP',
                            padding: EdgeInsets.zero,
                            onPressed: () => onSearchSubmitted?.call(
                              searchController!.text,
                            ),
                            icon: const Icon(
                              Icons.search_rounded,
                              color: _navy,
                              size: 19,
                            ),
                          ),
                          filled: true,
                          fillColor: transparent
                              ? Colors.white.withValues(alpha: 0.78)
                              : const Color(0xFFF1F4F9),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: _navy,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (title == null || title!.trim().isEmpty)
              const Spacer()
            else
              const Spacer(),
            if (extraActions.isNotEmpty) ...[
              ...extraActions,
              const SizedBox(width: 4),
            ],
            if (showUserActions) ...[
              SizedBox(width: isMobile ? 6 : 16),
              CustomUserHeaderActions(
                onLogout: onLogout,
                darkTheme: darkTheme,
                isProfileScreen: isProfileScreen,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bloque estandarizado de acciones de cabecera de usuario:
/// - 1 sola campana funcional (`SnackBar` -> "Sin notificaciones")
/// - Avatar limpio sin borde blanco exterior
/// - Flecha desplegable (`PopupMenuButton`) con Nombre, Correo, "Ver perfil"
///   y botón rojo resaltado de "Cerrar sesión".
class CustomUserHeaderActions extends StatelessWidget {
  const CustomUserHeaderActions({
    super.key,
    this.onLogout,
    this.darkTheme = false,
    this.showNotificationBell = true,
    this.isProfileScreen = false,
    this.compactAvatarOnly = false,
  });

  final VoidCallback? onLogout;
  final bool darkTheme;
  final bool showNotificationBell;
  final bool isProfileScreen;
  final bool compactAvatarOnly;

  static const Color _navy = Color(0xFF1A2B4C);

  static void showNoNotificationsSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.notifications_off_outlined,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 10),
              Text('Sin notificaciones'),
            ],
          ),
          backgroundColor: _navy,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  static Future<void> handleMenuSelection({
    required BuildContext context,
    required String value,
    VoidCallback? onLogout,
    bool isProfileScreen = false,
  }) async {
    if (value == 'profile') {
      if (isProfileScreen) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PerfilUsuarioScreen(),
        ),
      );
      return;
    }

    if (value == 'logout') {
      if (onLogout != null) {
        onLogout();
        return;
      }
      await AuthService.signOut();
      if (!context.mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/portada', (route) => false);
    }
  }

  static List<PopupMenuEntry<String>> buildStandardMenuItems({
    required String fullName,
    required String email,
  }) {
    return <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        enabled: false,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 210, maxWidth: 260),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email.isNotEmpty ? email : 'Sin correo registrado',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      const PopupMenuDivider(height: 10),
      const PopupMenuItem<String>(
        value: 'profile',
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 19,
              color: _navy,
            ),
            SizedBox(width: 10),
            Text(
              'Ver perfil',
              style: TextStyle(
                color: _navy,
                fontSize: 13.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'logout',
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 18,
                color: Color(0xFFDC2626),
              ),
              SizedBox(width: 10),
              Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 13.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AuthService.authStateVersion,
      builder: (context, _, _) {
        final String fullName = AuthService.getActiveUserDisplayName();
        final String firstName = AuthService.getActiveUserFirstName();
        final String email = AuthService.getActiveUserEmail();
        final ImageProvider<Object>? avatarImage =
            AuthService.getActiveUserAvatarImageProvider();
        final String initial =
            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

        final double screenW = MediaQuery.sizeOf(context).width;
        final bool isCompact = screenW < 520;
        final Color textColor = darkTheme ? Colors.white : _navy;
        final Color subtextColor =
            darkTheme ? Colors.white70 : const Color(0xFF475569);

        final Widget avatarWidget = CircleAvatar(
          radius: isCompact ? 16 : 18,
          backgroundImage: avatarImage,
          backgroundColor: const Color(0xFFB81D4E),
          foregroundColor: Colors.white,
          child: avatarImage == null
              ? Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: isCompact ? 13 : 14,
                  ),
                )
              : null,
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showNotificationBell) ...[
              IconButton(
                tooltip: 'Notificaciones',
                visualDensity: VisualDensity.compact,
                onPressed: () => showNoNotificationsSnackBar(context),
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: textColor,
                  size: 22,
                ),
              ),
              SizedBox(width: isCompact ? 4 : 8),
            ],
            PopupMenuButton<String>(
              tooltip: 'Opciones de cuenta',
              offset: const Offset(0, 46),
              elevation: 8,
              color: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              onSelected: (value) => handleMenuSelection(
                context: context,
                value: value,
                onLogout: onLogout,
                isProfileScreen: isProfileScreen,
              ),
              itemBuilder: (_) => buildStandardMenuItems(
                fullName: fullName,
                email: email,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    avatarWidget,
                    if (!compactAvatarOnly) ...[
                      if (!isCompact) ...[
                        const SizedBox(width: 9),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
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
                              const SizedBox(height: 1),
                              Text(
                                AuthService.getActiveUserRoleDisplayLabel(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: subtextColor,
                        size: 19,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
