import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'cristal.dart';

/// Panel de vidrio: relleno translúcido, borde de 1 px con muy poca
/// opacidad y esquinas amplias. Con [desenfoque] difumina lo que tiene
/// detrás (para lo que flota o se superpone a otro contenido).
///
/// Con [onTap] o [interactivo] reacciona al cursor: el relleno y el borde
/// suben de opacidad en 0,3 s con entrada y salida suaves.
class PanelCristal extends StatefulWidget {
  const PanelCristal({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radio = Cristal.radioTarjeta,
    this.color = Cristal.vidrio,
    this.colorEncima = Cristal.vidrioFuerte,
    this.colorBorde = Cristal.borde,
    this.colorBordeEncima = Cristal.bordeFuerte,
    this.desenfoque = false,
    this.interactivo = false,
    this.onTap,
    this.width,
    this.height,
    this.constraints,
    this.alignment,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radio;
  final Color color;
  final Color colorEncima;
  final Color colorBorde;
  final Color colorBordeEncima;

  /// Difumina el contenido que queda detrás del panel.
  final bool desenfoque;

  /// Reacciona al cursor aunque no tenga [onTap].
  final bool interactivo;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final AlignmentGeometry? alignment;

  @override
  State<PanelCristal> createState() => _PanelCristalState();
}

class _PanelCristalState extends State<PanelCristal> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final reacciona = widget.interactivo || widget.onTap != null;
    final radio = BorderRadius.circular(widget.radio);
    Widget panel = AnimatedContainer(
      duration: Cristal.micro,
      curve: Cristal.curvaMicro,
      width: widget.width,
      height: widget.height,
      constraints: widget.constraints,
      alignment: widget.alignment,
      padding: widget.onTap == null ? widget.padding : null,
      decoration: BoxDecoration(
        color: _encima ? widget.colorEncima : widget.color,
        borderRadius: radio,
        border: Border.all(
          color: _encima ? widget.colorBordeEncima : widget.colorBorde,
        ),
      ),
      child: widget.onTap == null
          ? widget.child
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: radio,
                hoverColor: Colors.transparent,
                child: Padding(
                  padding: widget.padding ?? EdgeInsets.zero,
                  child: widget.child,
                ),
              ),
            ),
    );
    if (widget.desenfoque) {
      panel = ClipRRect(
        borderRadius: radio,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: Cristal.desenfoque,
            sigmaY: Cristal.desenfoque,
          ),
          child: panel,
        ),
      );
    }
    if (reacciona) {
      panel = MouseRegion(
        cursor: widget.onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() => _encima = false),
        child: panel,
      );
    }
    if (widget.margin != null) {
      panel = Padding(padding: widget.margin!, child: panel);
    }
    return panel;
  }
}

/// Difumina lo que hay detrás de [child], recortado a [radio]. Para barras
/// y capas que se superponen al contenido.
class DesenfoqueCristal extends StatelessWidget {
  const DesenfoqueCristal({
    super.key,
    required this.child,
    this.radio = BorderRadius.zero,
    this.sigma = Cristal.desenfoque,
  });

  final Widget child;
  final BorderRadius radio;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radio,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

/// Isla clara dentro de la interfaz oscura: lo que imita papel o necesita
/// fondo blanco (la hoja del informe que se imprime, una firma, un logo
/// ajeno). Restituye el texto oscuro por defecto.
class PapelClaro extends StatelessWidget {
  const PapelClaro({super.key, required this.child});

  final Widget child;

  static const Color tinta = Color(0xFF0E2646);
  static const Color tintaSuave = Color(0xFF64748B);
  static const Color linea = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        brightness: Brightness.light,
        colorScheme: base.colorScheme.copyWith(
          brightness: Brightness.light,
          onSurface: tinta,
          onSurfaceVariant: tintaSuave,
        ),
        textTheme: base.textTheme.apply(bodyColor: tinta, displayColor: tinta),
        iconTheme: base.iconTheme.copyWith(color: tinta),
        dividerColor: linea,
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: tinta),
        child: IconTheme.merge(
          data: const IconThemeData(color: tinta),
          child: child,
        ),
      ),
    );
  }
}

/// Placa blanca para un logo ajeno (entidades públicas, medios de pago):
/// están dibujados para fondo claro.
class PlacaLogo extends StatelessWidget {
  const PlacaLogo({
    super.key,
    required this.child,
    this.radio = 12,
    this.padding = const EdgeInsets.all(6),
    this.circular = false,
  });

  final Widget child;
  final double radio;
  final EdgeInsetsGeometry padding;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(radio),
      ),
      child: child,
    );
  }
}
