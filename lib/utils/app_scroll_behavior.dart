import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Comportamiento global de scroll para Web y Escritorio.
/// No incluye [PointerDeviceKind.mouse] a nivel global para permitir seleccionar
/// libremente textos, cifras, cédulas, NIT y objetos contractuales con el cursor
/// en todas las pantallas mediante [SelectionArea].
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

class _HorizontalMouseDragScrollBehavior extends MaterialScrollBehavior {
  const _HorizontalMouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

/// Contenedor reutilizable para franjas horizontales de tarjetas (KPIs, chips,
/// macrofiltros y tablas) en Web/PC:
/// 1. Permite arrastrar con clic sostenido del mouse (gracias a [AppScrollBehavior]).
/// 2. Traduce el giro vertical de la rueda del mouse (`PointerScrollEvent`) en
///    desplazamiento horizontal cuando el contenido excede el ancho disponible,
///    sin bloquear el scroll vertical normal cuando llega al extremo o cabe completo.
class HorizontalWebScroll extends StatefulWidget {
  const HorizontalWebScroll({
    super.key,
    required this.child,
    this.padding,
    this.controller,
    this.showScrollbar = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final bool showScrollbar;

  @override
  State<HorizontalWebScroll> createState() => _HorizontalWebScrollState();
}

class _HorizontalWebScrollState extends State<HorizontalWebScroll> {
  ScrollController? _internalController;

  ScrollController get _effectiveController =>
      widget.controller ?? (_internalController ??= ScrollController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final controller = _effectiveController;
    if (!controller.hasClients) return;

    final maxExtent = controller.position.maxScrollExtent;
    if (maxExtent <= 0) return;

    // Si el usuario gira la rueda vertical del mouse sobre una tira horizontal,
    // convertimos el delta Y en desplazamiento horizontal X.
    final double delta = event.scrollDelta.dx != 0
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) return;

    final current = controller.offset;
    final target = (current + delta).clamp(0.0, maxExtent);
    if ((target - current).abs() < 0.5) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (!controller.hasClients) return;
      controller.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget scrollable = ScrollConfiguration(
      behavior: const _HorizontalMouseDragScrollBehavior(),
      child: SingleChildScrollView(
        controller: _effectiveController,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        physics: const ClampingScrollPhysics(),
        child: widget.child,
      ),
    );

    if (widget.showScrollbar) {
      scrollable = Scrollbar(
        controller: _effectiveController,
        thumbVisibility: false,
        thickness: 5,
        radius: const Radius.circular(6),
        child: scrollable,
      );
    }

    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: scrollable,
      ),
    );
  }
}

