import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'cristal.dart';

/// Desplazamiento lateral del contenido al cambiar de vista, como fracción
/// de su ancho: sutil, lo justo para sentir de dónde viene.
const double _desliz = 0.035;

/// Transición entre rutas: la pantalla que sale se desvanece y se desliza
/// un poco hacia un lado mientras la que entra aparece desde el lado
/// opuesto, las dos a la vez. Al volver, el movimiento se invierte.
class TransicionLiquida extends PageTransitionsBuilder {
  const TransicionLiquida();

  @override
  Duration get transitionDuration => Cristal.cambio;

  @override
  Duration get reverseTransitionDuration => Cristal.cambio;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final entra = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final sale = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut,
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: const Interval(0, 0.7, curve: Curves.easeOut),
          reverseCurve: const Interval(0.3, 1, curve: Curves.easeIn),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-_desliz, 0),
        ).animate(sale),
        child: FadeTransition(
          opacity: entra,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(_desliz, 0),
              end: Offset.zero,
            ).animate(entra),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Cambio de vista dentro de una misma pantalla (secciones del menú,
/// pestañas): el contenido anterior se desvanece hacia un lado mientras
/// el nuevo entra desde el opuesto.
///
/// [clave] identifica la vista; al cambiar, se anima. Si las claves tienen
/// orden (números o valores de un `enum`), ir a una vista anterior invierte
/// el sentido del movimiento.
class CambioLiquido extends StatefulWidget {
  const CambioLiquido({
    super.key,
    required this.clave,
    required this.child,
    this.expandir = false,
    this.alineacion = Alignment.topCenter,
  });

  final Object clave;
  final Widget child;

  /// La vista ocupa todo el espacio disponible (secciones a pantalla
  /// completa). Si no, recibe las mismas restricciones que tendría sin
  /// este envoltorio.
  final bool expandir;
  final AlignmentGeometry alineacion;

  @override
  State<CambioLiquido> createState() => _CambioLiquidoState();
}

class _CambioLiquidoState extends State<CambioLiquido> {
  bool _haciaAtras = false;

  static num? _orden(Object clave) => switch (clave) {
    final num n => n,
    final Enum e => e.index,
    _ => null,
  };

  @override
  void didUpdateWidget(CambioLiquido oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clave != oldWidget.clave) {
      final antes = _orden(oldWidget.clave);
      final ahora = _orden(widget.clave);
      _haciaAtras = antes != null && ahora != null && ahora < antes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final llave = ValueKey<Object>(widget.clave);
    final sentido = _haciaAtras ? -1.0 : 1.0;
    return AnimatedSwitcher(
      duration: Cristal.cambio,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (actual, anteriores) => Stack(
        alignment: widget.alineacion,
        fit: widget.expandir ? StackFit.expand : StackFit.passthrough,
        children: [...anteriores, ?actual],
      ),
      transitionBuilder: (hijo, animacion) {
        // El que entra viene de un lado; el que sale se va hacia el otro.
        final entrante = hijo.key == llave;
        final desde = Offset((entrante ? _desliz : -_desliz) * sentido, 0);
        return FadeTransition(
          opacity: animacion,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: desde,
              end: Offset.zero,
            ).animate(animacion),
            child: hijo,
          ),
        );
      },
      child: KeyedSubtree(key: llave, child: widget.child),
    );
  }
}

/// Como `showDialog`, con el velo de vidrio: lo que queda detrás se
/// oscurece y se desenfoca mientras el diálogo aparece con un leve
/// ascenso.
Future<T?> mostrarDialogoCristal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  final navegador = Navigator.of(context, rootNavigator: useRootNavigator);
  final temas = InheritedTheme.capture(from: context, to: navegador.context);
  return navegador.push<T>(
    _RutaDialogoCristal<T>(
      context: context,
      builder: builder,
      themes: temas,
      barrierColor: barrierColor ?? Cristal.velo,
      barrierDismissible: barrierDismissible,
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      useSafeArea: useSafeArea,
      settings: routeSettings,
      anchorPoint: anchorPoint,
    ),
  );
}

/// Secciones de la app que siguen vivas al cambiar de pestaña: lo buscado,
/// los filtros y los resultados se conservan y no se vuelve a consultar al
/// regresar. Las de [recrear] se construyen de nuevo cada vez (por ejemplo,
/// las que deben reflejar cambios hechos en otra parte). La sección que
/// entra lo hace con el mismo leve deslizamiento de [CambioLiquido].
class SeccionesVivas extends StatefulWidget {
  const SeccionesVivas({
    super.key,
    required this.activa,
    required this.construir,
    this.recrear = const {},
  });

  final int activa;
  final Widget Function(int indice) construir;
  final Set<int> recrear;

  @override
  State<SeccionesVivas> createState() => _SeccionesVivasState();
}

class _SeccionesVivasState extends State<SeccionesVivas>
    with SingleTickerProviderStateMixin {
  final List<int> _visitadas = [];
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: Cristal.cambio,
    value: 1,
  );
  late final Animation<double> _curva = CurvedAnimation(
    parent: _entrada,
    curve: Curves.easeOutCubic,
  );
  double _sentido = 1;

  @override
  void didUpdateWidget(SeccionesVivas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activa != widget.activa) {
      _sentido = widget.activa < oldWidget.activa ? -1 : 1;
      _entrada.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _visitadas.removeWhere(
      (i) => widget.recrear.contains(i) && i != widget.activa,
    );
    if (!_visitadas.contains(widget.activa)) _visitadas.add(widget.activa);
    final orden = [..._visitadas]..sort();
    const quieta = AlwaysStoppedAnimation<double>(1);
    return IndexedStack(
      index: orden.indexOf(widget.activa),
      sizing: StackFit.expand,
      children: [
        for (final i in orden)
          // La misma estructura para todas (activa o no), para que ninguna
          // pierda su estado al cambiar de pestaña.
          KeyedSubtree(
            key: ValueKey<int>(i),
            child: FadeTransition(
              opacity: i == widget.activa ? _curva : quieta,
              child: SlideTransition(
                position: i == widget.activa
                    ? Tween<Offset>(
                        begin: Offset(_desliz * _sentido, 0),
                        end: Offset.zero,
                      ).animate(_curva)
                    : const AlwaysStoppedAnimation<Offset>(Offset.zero),
                // Las secciones devuelven un Expanded: necesitan un Flex.
                child: Column(children: [widget.construir(i)]),
              ),
            ),
          ),
      ],
    );
  }
}

class _RutaDialogoCristal<T> extends DialogRoute<T> {
  _RutaDialogoCristal({
    required super.context,
    required super.builder,
    super.themes,
    super.barrierColor,
    super.barrierDismissible,
    super.barrierLabel,
    super.useSafeArea,
    super.settings,
    super.anchorPoint,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  /// El velo desenfoca lo que hay detrás a medida que aparece.
  @override
  Widget buildModalBarrier() {
    final barrera = super.buildModalBarrier();
    final anim = animation;
    if (anim == null) return barrera;
    return AnimatedBuilder(
      animation: anim,
      builder: (context, hijo) {
        final sigma = 14 * Curves.easeOut.transform(anim.value);
        if (sigma < 0.05) return hijo!;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: hijo,
        );
      },
      child: barrera,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curva = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(curva),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.975, end: 1).animate(curva),
          child: child,
        ),
      ),
    );
  }
}
