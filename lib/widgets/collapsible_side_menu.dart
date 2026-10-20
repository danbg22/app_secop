import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _bgMenu = Color(0xFFFAF0DC);
  static const Color _tileSelected = Color(0xFFF9E4B7);

  static const List<MenuOptionItem> opcionesMenu = [
    MenuOptionItem(titulo: 'Inicio', icono: Icons.home_outlined),
    MenuOptionItem(titulo: 'Explorar', icono: Icons.search),
    MenuOptionItem(titulo: 'Contratos', icono: Icons.description_outlined),
    MenuOptionItem(titulo: 'Entidades', icono: Icons.account_balance_outlined),
    MenuOptionItem(titulo: 'Contratistas', icono: Icons.people_outline),
    MenuOptionItem(titulo: 'Estadísticas', icono: Icons.bar_chart),
    MenuOptionItem(titulo: 'Alertas', icono: Icons.notifications_none),
    MenuOptionItem(titulo: 'Favoritos', icono: Icons.bookmark_border),
  ];

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: _azulOscuro),
            SizedBox(width: 10),
            Text(
              'Centro de Ayuda · Contrata Legal',
              style: TextStyle(
                color: _azulOscuro,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: const SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Consulta contratos públicos en tiempo real conectados con Datos Abiertos (SECOP II) y verificación SIGEP.',
                style: TextStyle(color: Color(0xFF475569), fontSize: 13.5),
              ),
              SizedBox(height: 14),
              Text(
                '• Usa la barra de búsqueda o los filtros para consultar procesos por entidad, ubicación, año, modalidad o estado.\n'
                '• Haz clic en el ícono del ojo (👁) para una vista rápida o en "Ver detalle >" para abrir el Copiloto IA ✨.\n'
                '• Haz clic en el isotipo superior para contraer o expandir la barra lateral.',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
            'assets/images/logo.png',
            width: 104,
            height: 52,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }

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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: isCollapsed ? 68 : 240,
      color: _bgMenu,
      padding: EdgeInsets.fromLTRB(
        isCollapsed ? 10 : 16,
        0,
        isCollapsed ? 10 : 14,
        18,
      ),
      child: Column(
        crossAxisAlignment:
            isCollapsed ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
        children: [
          if (isCollapsed)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Center(
                child: _SideMenuHoverBubble(
                  key: const ValueKey('collapsed-logo-bubble'),
                  label: 'Expandir barra lateral',
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: onToggleCollapse,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: Center(child: _buildCollapsedIsotipo()),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(
                left: 8,
                top: 18,
                bottom: 14,
                right: 2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onToggleCollapse,
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 66,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Ocultar barra lateral',
                    onPressed: onToggleCollapse,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    icon: const Icon(
                      Icons.keyboard_double_arrow_left_rounded,
                      color: _azulOscuro,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                'MENÚ PRINCIPAL',
                style: TextStyle(
                  color: _azulOscuro.withValues(alpha: 0.48),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                // Se ocultan visualmente Explorar (1), Estadísticas (5) y Alertas (6)
                // dejando habilitadas únicamente: Inicio (0), Contratos (2), Entidades (3), Contratistas (4) y Favoritos (7).
                const visibleIndices = <int>[0, 2, 3, 4, 7];
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 2),
                  itemCount: visibleIndices.length,
                  itemBuilder: (context, pos) {
                    final index = visibleIndices[pos];
                    final opcion = opcionesMenu[index];
                    final seleccionado = index == selectedIndex;
                    final IconData icono = (index == 2 && seleccionado)
                        ? Icons.description
                        : (index == 7 && seleccionado)
                            ? Icons.bookmark_rounded
                            : opcion.icono;

                    if (isCollapsed) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (index == 7)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Divider(
                                height: 1,
                                color: _azulOscuro.withValues(alpha: 0.10),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Center(
                              child: _SideMenuHoverBubble(
                                key: ValueKey('menu-item-$index'),
                                label: opcion.titulo,
                                child: Material(
                                  color: seleccionado
                                      ? _tileSelected
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => onItemSelected(index),
                                    child: SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: Icon(
                                        icono,
                                        color: _azulOscuro,
                                        size: 21,
                                        weight: seleccionado ? 700 : 400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (index == 7)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                            child: Divider(
                              height: 1,
                              color: _azulOscuro.withValues(alpha: 0.10),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -0.2),
                            selected: seleccionado,
                            selectedTileColor: _tileSelected,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(
                              icono,
                              color: _azulOscuro,
                              size: 21,
                              weight: seleccionado ? 700 : 400,
                            ),
                            title: Text(
                              opcion.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _azulOscuro,
                                fontSize: 14,
                                fontWeight: seleccionado
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            onTap: () => onItemSelected(index),
                          ),
                        ),
                      ],
                    );
                  },
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
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: _azulOscuro,
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
                onSelected: (value) {
                  if (value == 'logout') onLogout();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Cerrar sesión'),
                  ),
                ],
                child: CircleAvatar(
                  radius: 17,
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
            ),
          ] else ...[
            InkWell(
              onTap: () => _showHelpDialog(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _azulOscuro.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sms_outlined,
                      color: _azulOscuro,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '¿Necesitas ayuda?',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _azulOscuro,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chat con nosotros',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.blueGrey.shade600,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Contrata Legal\n© 2026. Todos los derechos\nreservados.',
                style: TextStyle(
                  color: Colors.blueGrey.shade600,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
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
                  CustomPaint(
                    size: const Size(6, 12),
                    painter: _BubbleArrowPainter(
                      color: const Color(0xFF1A2B4C),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2B4C),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
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
