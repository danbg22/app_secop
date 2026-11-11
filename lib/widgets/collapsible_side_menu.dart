import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'custom_app_bar.dart';
import 'pqrs_help_dialog.dart';
import '../tema/cristal.dart';

class MenuOptionItem {
  const MenuOptionItem({required this.titulo, required this.icono});

  final String titulo;
  final IconData icono;
}

class CollapsibleSideMenu extends StatelessWidget {
  const CollapsibleSideMenu({
    super.key,
    required this.selectedIndex,
    required this.isCollapsed,
    required this.onItemSelected,
    required this.onToggleCollapse,
    required this.onLogout,
  });

  final int selectedIndex;
  final bool isCollapsed;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onToggleCollapse;
  final VoidCallback onLogout;

  static const List<MenuOptionItem> opcionesMenu = [
    MenuOptionItem(titulo: 'Inicio', icono: Icons.home_outlined),
    MenuOptionItem(titulo: 'Explorar', icono: Icons.search),
    MenuOptionItem(titulo: 'Contratos', icono: Icons.description_outlined),
    MenuOptionItem(titulo: 'Entidades', icono: Icons.account_balance_outlined),
    MenuOptionItem(titulo: 'Contratistas', icono: Icons.people_outline),
    MenuOptionItem(titulo: 'Estadísticas', icono: Icons.bar_chart),
    MenuOptionItem(titulo: 'Alertas', icono: Icons.notifications_none),
    MenuOptionItem(titulo: 'Favoritos', icono: Icons.bookmark_border),
    MenuOptionItem(titulo: 'Gestión contractual', icono: Icons.gavel_outlined),
    MenuOptionItem(
      titulo: 'Proyección de contratación',
      icono: Icons.event_note_outlined,
    ),
  ];

  /// Calcula dinámicamente las secciones habilitadas según los roles pagados y acumulados.
  static List<int> obtenerIndicesVisiblesPorRol() {
    final tienePersona = AuthService.hasActiveRole('persona');
    final tieneJuridico = AuthService.hasActiveRole('equipo_juridico');
    final indices = <int>[];
    if (tienePersona) {
      indices.addAll(const <int>[0, 2, 3, 4, 7]);
    }
    if (tieneJuridico) {
      indices.add(8);
    }
    if (AuthService.hasActiveRole('empresa_licitante')) {
      indices.add(9);
    }
    if (indices.isEmpty) {
      indices.addAll(const <int>[0, 2, 3, 4, 7]);
    }
    return indices;
  }

  void _showHelpDialog(BuildContext context) {
    PqrsHelpDialog.show(context);
  }

  /// Renderiza únicamente el isotipo del mapa de Colombia con lupa (sin el texto "Contrata Legal")
  /// ajustado exactamente al tamaño de los íconos de la barra contraída (38x40).
  Widget _buildCollapsedIsotipo() {
    return SizedBox(
      width: 38,
      height: 40,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 104,
          maxWidth: 104,
          minHeight: 52,
          maxHeight: 52,
          alignment: const Alignment(-0.80, 0.16),
          child: Image.asset(
            'assets/images/logo_fondo_oscuro.png',
            width: 104,
            height: 52,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AuthService.authStateVersion,
      builder: (context, _, _) {
        final String fullName = AuthService.getActiveUserDisplayName();
        final String email = AuthService.getActiveUserEmail();
        final ImageProvider<Object>? avatarImage =
            AuthService.getActiveUserAvatarImageProvider();
        final String initial = fullName.isNotEmpty
            ? fullName[0].toUpperCase()
            : 'U';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: isCollapsed ? 68 : 240,
          // El menú es un panel de vidrio que flota sobre el fondo.
          padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
          child: DecoratedBox(
            decoration: Cristal.vidrioDeco(radio: Cristal.radioPanel),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isCollapsed ? 4 : 8,
                  0,
                  isCollapsed ? 4 : 8,
                  10,
                ),
                child: Column(
                  crossAxisAlignment: isCollapsed
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.stretch,
                  children: [
                    if (isCollapsed)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 14),
                        child: Center(
                          child: _SideMenuHoverBubble(
                            key: const ValueKey('collapsed-logo-bubble'),
                            label: 'Expandir barra lateral',
                            child: InkWell(
                              onTap: onToggleCollapse,
                              borderRadius: BorderRadius.circular(12),
                              hoverDuration: Cristal.micro,
                              child: SizedBox(
                                width: 42,
                                height: 42,
                                child: Center(child: _buildCollapsedIsotipo()),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          top: 10,
                          bottom: 12,
                          right: 2,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: onToggleCollapse,
                                borderRadius: BorderRadius.circular(10),
                                hoverDuration: Cristal.micro,
                                child: Image.asset(
                                  'assets/images/logo_fondo_oscuro.png',
                                  height: 66,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Ocultar barra lateral',
                              onPressed: onToggleCollapse,
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(
                                backgroundColor: Cristal.vidrio,
                                side: const BorderSide(color: Cristal.borde),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.keyboard_double_arrow_left_rounded,
                                color: Cristal.texto,
                                size: 19,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (!isCollapsed) const _RotuloGrupo('MENÚ PRINCIPAL'),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final visibleIndices = obtenerIndicesVisiblesPorRol();
                          return _ListaDesvanecida(
                            builder: (controlador) => ListView.builder(
                              controller: controlador,
                              padding: const EdgeInsets.only(top: 2),
                              itemCount: visibleIndices.length,
                              itemBuilder: (context, pos) {
                                final index = visibleIndices[pos];
                                final opcion = opcionesMenu[index];
                                final seleccionado = index == selectedIndex;
                                final IconData icono =
                                    (index == 2 && seleccionado)
                                    ? Icons.description
                                    : (index == 7 && seleccionado)
                                    ? Icons.bookmark_rounded
                                    : (index == 8 && seleccionado)
                                    ? Icons.gavel_rounded
                                    : opcion.icono;

                                if (isCollapsed) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (index == 7 || (index == 8 && pos > 0))
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          child: Divider(height: 1),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Center(
                                          child: _SideMenuHoverBubble(
                                            key: ValueKey('menu-item-$index'),
                                            label: opcion.titulo,
                                            child: _OpcionMenu(
                                              icono: icono,
                                              titulo: opcion.titulo,
                                              seleccionado: seleccionado,
                                              compacta: true,
                                              onTap: () =>
                                                  onItemSelected(index),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (index == 7)
                                      const Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          10,
                                          6,
                                          10,
                                          10,
                                        ),
                                        child: Divider(height: 1),
                                      ),
                                    if (index == 8) ...[
                                      if (pos > 0)
                                        const Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            10,
                                            8,
                                            10,
                                            8,
                                          ),
                                          child: Divider(height: 1),
                                        ),
                                      const _RotuloGrupo(
                                        'EQUIPO JURÍDICO',
                                        inferior: 6,
                                      ),
                                    ],
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: _OpcionMenu(
                                        icono: icono,
                                        titulo: opcion.titulo,
                                        seleccionado: seleccionado,
                                        onTap: () => onItemSelected(index),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    if (isCollapsed) ...[
                      _SideMenuHoverBubble(
                        key: const ValueKey('help-bubble'),
                        label: '¿Necesitas ayuda?',
                        child: InkWell(
                          onTap: () => _showHelpDialog(context),
                          borderRadius: BorderRadius.circular(12),
                          hoverDuration: Cristal.micro,
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.help_outline_rounded,
                              color: Cristal.texto,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SideMenuHoverBubble(
                        key: const ValueKey('profile-bubble'),
                        label: fullName,
                        child: PopupMenuButton<String>(
                          tooltip: '',
                          onSelected: (value) =>
                              CustomUserHeaderActions.handleMenuSelection(
                                context: context,
                                value: value,
                                onLogout: onLogout,
                              ),
                          itemBuilder: (_) =>
                              CustomUserHeaderActions.buildStandardMenuItems(
                                fullName: fullName,
                                email: email,
                              ),
                          child: CircleAvatar(
                            radius: 17,
                            backgroundImage: avatarImage,
                            backgroundColor: Cristal.avatar,
                            foregroundColor: Cristal.texto,
                            child: avatarImage == null
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Cristal.texto,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ] else ...[
                      PanelCristal(
                        onTap: () => Navigator.of(context).pushNamed('/planes'),
                        radio: Cristal.radioCampo,
                        color: Cristal.doradoVidrio,
                        colorEncima: const Color(0x4DFFC53D),
                        colorBorde: Cristal.doradoBorde,
                        colorBordeEncima: Cristal.dorado,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.add_moderator_rounded,
                              color: Cristal.dorado,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Acumular otro rol (+)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Cristal.texto,
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      PanelCristal(
                        onTap: () => _showHelpDialog(context),
                        radio: Cristal.radioAviso,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.sms_outlined,
                              color: Cristal.texto,
                              size: 21,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¿Necesitas ayuda?',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Cristal.texto,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Chat con nosotros',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Cristal.textoSuave,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Cristal.textoSuave,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _TarjetaPerfil(
                        nombre: fullName,
                        rol: AuthService.getActiveUserRoleDisplayLabel(),
                        avatar: avatarImage,
                        inicial: initial,
                        onPerfil: () =>
                            CustomUserHeaderActions.handleMenuSelection(
                              context: context,
                              value: 'profile',
                            ),
                        onCerrarSesion: () =>
                            CustomUserHeaderActions.handleMenuSelection(
                              context: context,
                              value: 'logout',
                              onLogout: onLogout,
                            ),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          'Contrata Legal\n© 2026. Todos los derechos\nreservados.',
                          style: TextStyle(
                            color: Cristal.textoSuave,
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lista desplazable que se desvanece en el borde por donde aún queda
/// contenido, en vez de cortarse en seco.
class _ListaDesvanecida extends StatefulWidget {
  const _ListaDesvanecida({required this.builder});

  final Widget Function(ScrollController controlador) builder;

  @override
  State<_ListaDesvanecida> createState() => _ListaDesvanecidaState();
}

class _ListaDesvanecidaState extends State<_ListaDesvanecida> {
  final ScrollController _controlador = ScrollController();
  bool _arriba = false;
  bool _abajo = false;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  bool _medir(ScrollMetrics m) {
    final arriba = m.extentBefore > 2;
    final abajo = m.extentAfter > 2;
    if (arriba != _arriba || abajo != _abajo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _arriba = arriba;
          _abajo = abajo;
        });
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final lista = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _medir(n.metrics),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => _medir(n.metrics),
        child: widget.builder(_controlador),
      ),
    );
    // La máscara va siempre (toda opaca si no hace falta) para no remontar
    // la lista, que perdería su posición.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _arriba ? Colors.transparent : Colors.black,
          Colors.black,
          Colors.black,
          _abajo ? Colors.transparent : Colors.black,
        ],
        stops: const [0, 0.08, 0.9, 1],
      ).createShader(rect),
      child: lista,
    );
  }
}

/// Rótulo de un grupo de opciones del menú.
class _RotuloGrupo extends StatelessWidget {
  const _RotuloGrupo(this.texto, {this.inferior = 8});

  final String texto;
  final double inferior;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 12, bottom: inferior),
      child: Text(
        texto,
        style: const TextStyle(
          color: Cristal.textoTenue,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

/// Una opción del menú. La sección actual se marca en dorado; las demás
/// quedan atenuadas y suben de opacidad, con su fondo de vidrio, al pasar
/// el cursor.
class _OpcionMenu extends StatefulWidget {
  const _OpcionMenu({
    required this.icono,
    required this.titulo,
    required this.seleccionado,
    required this.onTap,
    this.compacta = false,
  });

  final IconData icono;
  final String titulo;
  final bool seleccionado;
  final VoidCallback onTap;

  /// Solo el ícono, para el menú contraído.
  final bool compacta;

  @override
  State<_OpcionMenu> createState() => _OpcionMenuState();
}

class _OpcionMenuState extends State<_OpcionMenu> {
  bool _encima = false;

  @override
  void initState() {
    super.initState();
    if (widget.seleccionado) _mostrar();
  }

  @override
  void didUpdateWidget(_OpcionMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seleccionado && !oldWidget.seleccionado) _mostrar();
  }

  /// Si la lista del menú no cabe entera, la desplaza hasta dejar a la
  /// vista la opción activa.
  void _mostrar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: Cristal.micro,
        curve: Cristal.curvaMicro,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final activa = widget.seleccionado;
    final radio = BorderRadius.circular(
      widget.compacta ? Cristal.radioFicha : Cristal.radioCampo,
    );
    return Semantics(
      button: true,
      selected: activa,
      label: widget.compacta ? widget.titulo : null,
      child: AnimatedContainer(
        duration: Cristal.micro,
        curve: Cristal.curvaMicro,
        width: widget.compacta ? 42 : null,
        height: widget.compacta ? 42 : null,
        decoration: BoxDecoration(
          color: activa
              ? Cristal.doradoVidrio
              : _encima
              ? Cristal.vidrioFuerte
              : Cristal.vidrio.withValues(alpha: 0),
          borderRadius: radio,
          border: Border.all(
            color: activa
                ? Cristal.doradoBorde
                : Cristal.borde.withValues(alpha: 0),
          ),
        ),
        child: InkWell(
          hoverDuration: Cristal.micro,
          onTap: widget.onTap,
          onHover: (encima) => setState(() => _encima = encima),
          borderRadius: radio,
          hoverColor: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: activa || _encima ? 1 : 0),
            duration: Cristal.micro,
            curve: Cristal.curvaMicro,
            builder: (context, t, _) {
              final tinta = Color.lerp(Cristal.textoMedio, Cristal.texto, t)!;
              final icono = Icon(
                widget.icono,
                color: activa ? Cristal.dorado : tinta,
                size: 21,
                weight: activa ? 700 : 400,
              );
              if (widget.compacta) return Center(child: icono);
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    icono,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tinta,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: activa
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Muestra una burbuja flotante con flecha lateral al pasar el mouse encima del ícono
/// y la oculta automáticamente al hacer clic o cambiar de estado.
class _SideMenuHoverBubble extends StatefulWidget {
  const _SideMenuHoverBubble({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  State<_SideMenuHoverBubble> createState() => _SideMenuHoverBubbleState();
}

class _SideMenuHoverBubbleState extends State<_SideMenuHoverBubble> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _showBubble() {
    if (_overlayEntry != null || !mounted) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        child: IgnorePointer(
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.centerRight,
            followerAnchor: Alignment.centerLeft,
            offset: const Offset(12, 0),
            child: Material(
              color: Colors.transparent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CustomPaint(
                    size: Size(6, 12),
                    painter: _BubbleArrowPainter(color: Cristal.burbuja),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Cristal.burbuja,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Cristal.bordeFuerte),
                    ),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Cristal.texto,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideBubble() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void didUpdateWidget(covariant _SideMenuHoverBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      _hideBubble();
    }
  }

  @override
  void deactivate() {
    _hideBubble();
    super.deactivate();
  }

  @override
  void dispose() {
    _hideBubble();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Listener(
        onPointerDown: (_) => _hideBubble(),
        child: MouseRegion(
          onEnter: (_) => _showBubble(),
          onExit: (_) => _hideBubble(),
          child: widget.child,
        ),
      ),
    );
  }
}

class _BubbleArrowPainter extends CustomPainter {
  const _BubbleArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Perfil del usuario al pie del menú lateral (escritorio): nombre, roles y
/// accesos a "Mi perfil" y "Cerrar sesión". En celular el perfil sigue en la
/// barra superior.
class _TarjetaPerfil extends StatelessWidget {
  const _TarjetaPerfil({
    required this.nombre,
    required this.rol,
    required this.avatar,
    required this.inicial,
    required this.onPerfil,
    required this.onCerrarSesion,
  });

  final String nombre;
  final String rol;
  final ImageProvider<Object>? avatar;
  final String inicial;
  final VoidCallback onPerfil;
  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    final estiloBoton = OutlinedButton.styleFrom(
      foregroundColor: Cristal.texto,
      backgroundColor: Cristal.vidrio,
      side: const BorderSide(color: Cristal.borde),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size.fromHeight(34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.centerLeft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    const estiloTexto = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: Cristal.vidrioDeco(radio: Cristal.radioAviso),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundImage: avatar,
                backgroundColor: Cristal.avatar,
                child: avatar == null
                    ? Text(
                        inicial,
                        style: const TextStyle(
                          color: Cristal.texto,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Cristal.texto,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rol,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Cristal.textoSuave,
                        fontSize: 11.3,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: onPerfil,
                style: estiloBoton,
                icon: const Icon(Icons.person_outline_rounded, size: 15),
                label: const Text('Mi perfil', style: estiloTexto),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: onCerrarSesion,
                style: estiloBoton,
                icon: const Icon(Icons.logout_rounded, size: 15),
                label: const Text('Cerrar sesión', style: estiloTexto),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
