import 'package:flutter/material.dart';

import 'campo_busqueda.dart';
import '../screens/perfil_usuario_screen.dart';
import '../services/auth_service.dart';
import 'user_profile_header_action.dart';
import '../tema/cristal.dart';
import '../services/app_instalable_service.dart';
import 'boton_instalar_app.dart';

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

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 640;

    return Container(
      // Sin relleno: la barra deja ver el fondo; solo una línea la separa.
      decoration: BoxDecoration(
        border: transparent
            ? null
            : Border(bottom: BorderSide(color: Cristal.borde)),
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
                  color: Cristal.texto,
                  size: 21,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (showLogo) ...[
              Image.asset(
                Cristal.logo,
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
                    color: Cristal.texto,
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
                      child: CampoBusqueda(
                        controller: searchController,
                        onSubmitted: onSearchSubmitted,
                        style: TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Busca contratos, entidades...',
                          hintStyle: TextStyle(fontSize: 13),
                          prefixIcon: IconButton(
                            tooltip: 'Buscar en SECOP + SIGEP',
                            padding: EdgeInsets.zero,
                            onPressed: () =>
                                onSearchSubmitted?.call(searchController!.text),
                            icon: Icon(
                              Icons.search_rounded,
                              color: CampoBusqueda.tinta,
                              size: 19,
                            ),
                          ),
                          filled: true,
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
                            borderSide: BorderSide(color: Cristal.borde),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: Cristal.acentoClaro,
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
            // En escritorio el perfil va al pie del menú lateral.
            if (showUserActions &&
                MediaQuery.sizeOf(context).width <
                    UserProfileHeaderAction.anchoEscritorio) ...[
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
    this.isProfileScreen = false,
    this.compactAvatarOnly = false,
  });

  final VoidCallback? onLogout;
  final bool darkTheme;
  final bool isProfileScreen;
  final bool compactAvatarOnly;

  static Future<void> handleMenuSelection({
    required BuildContext context,
    required String value,
    VoidCallback? onLogout,
    bool isProfileScreen = false,
  }) async {
    if (value == 'profile') {
      if (isProfileScreen) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PerfilUsuarioScreen()),
      );
      return;
    }

    if (value == 'modo') {
      await Cristal.cambiarModo(
        Cristal.esClaro ? ModoCristal.oscuro : ModoCristal.claro,
      );
      return;
    }

    if (value == 'instalar') {
      await BotonInstalarApp.abrir(context);
      return;
    }

    if (value == 'accumulate_role') {
      Navigator.of(context).pushNamed('/planes');
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
                style: TextStyle(
                  color: Cristal.texto,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email.isNotEmpty ? email : 'Sin correo registrado',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Cristal.textoSuave,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x1F10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Roles: ${AuthService.getActiveUserRoleDisplayLabel()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Cristal.verde,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const PopupMenuDivider(height: 10),
      PopupMenuItem<String>(
        value: 'accumulate_role',
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.add_moderator_outlined,
              size: 19,
              color: Cristal.acentoClaro,
            ),
            SizedBox(width: 10),
            Text(
              'Acumular / Añadir rol',
              style: TextStyle(
                color: Cristal.acentoClaro,
                fontSize: 13.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      if (AppInstalable.disponible.value)
        PopupMenuItem<String>(
          value: 'instalar',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.install_desktop_rounded,
                size: 19,
                color: Cristal.acentoClaro,
              ),
              const SizedBox(width: 10),
              Text(
                'Instalar app',
                style: TextStyle(
                  color: Cristal.texto,
                  fontSize: 13.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      PopupMenuItem<String>(
        value: 'modo',
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(
              Cristal.esClaro
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              size: 19,
              color: Cristal.texto,
            ),
            const SizedBox(width: 10),
            Text(
              Cristal.esClaro ? 'Modo oscuro' : 'Modo claro',
              style: TextStyle(
                color: Cristal.texto,
                fontSize: 13.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'profile',
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.person_outline_rounded, size: 19, color: Cristal.texto),
            SizedBox(width: 10),
            Text(
              'Ver perfil',
              style: TextStyle(
                color: Cristal.texto,
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
            color: Cristal.rojoVidrio,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Cristal.rojoBorde),
          ),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: Cristal.rojo),
              SizedBox(width: 10),
              Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: Cristal.rojo,
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
        final String initial = fullName.isNotEmpty
            ? fullName[0].toUpperCase()
            : 'U';

        final double screenW = MediaQuery.sizeOf(context).width;
        final bool isCompact = screenW < 520;
        final Color textColor = Cristal.texto;
        final Color subtextColor = Cristal.textoMedio;

        final Widget avatarWidget = CircleAvatar(
          radius: isCompact ? 16 : 18,
          backgroundImage: avatarImage,
          backgroundColor: Cristal.avatar,
          foregroundColor: Cristal.blanco,
          child: avatarImage == null
              ? Text(
                  initial,
                  style: TextStyle(
                    color: Cristal.blanco,
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
            PopupMenuButton<String>(
              tooltip: 'Opciones de cuenta',
              offset: const Offset(0, 46),
              onSelected: (value) => handleMenuSelection(
                context: context,
                value: value,
                onLogout: onLogout,
                isProfileScreen: isProfileScreen,
              ),
              itemBuilder: (_) =>
                  buildStandardMenuItems(fullName: fullName, email: email),
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
