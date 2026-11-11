import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// La foto de Valledupar como luz de ambiente del fondo: atenuada y
/// fundida con el fondo de la aplicación hacia la izquierda y hacia abajo,
/// para que se perciba a través de los paneles de vidrio sin competir con
/// el texto.
///
/// Usa el recorte limpio de la foto (sin las ondas claras del diseño
/// anterior). Va detrás del contenido, normalmente en un `Positioned`.
class FotoAmbiente extends StatelessWidget {
  const FotoAmbiente({
    super.key,
    this.alineacion = const Alignment(0.15, -0.25),
    this.opacidad = 0.62,
    this.inicio = 0.18,
    this.pleno = 0.72,
    this.fundidoInferior = 0.4,
    this.fundidoSuperior = 0,
    this.desenfoque = 0,
  });

  /// Franja de cabecera de una pantalla: la foto desenfocada y tenue, como
  /// una luz cálida detrás del título y de las primeras tarjetas, sin
  /// detalles nítidos que estorben la lectura.
  const FotoAmbiente.cabecera({
    super.key,
    this.alineacion = const Alignment(0.15, -0.3),
    this.opacidad = 0.5,
    this.inicio = 0.2,
    this.pleno = 0.8,
    this.fundidoInferior = 0.55,
    this.fundidoSuperior = 0,
    this.desenfoque = 10,
  });

  /// Qué parte de la foto queda a la vista cuando se recorta al encajar.
  final Alignment alineacion;

  /// Opacidad de la foto en su zona más visible (la derecha).
  final double opacidad;

  /// Fracción del ancho donde la foto empieza a aparecer.
  final double inicio;

  /// Fracción del ancho donde alcanza [opacidad].
  final double pleno;

  /// Fracción del alto, desde abajo, en la que se desvanece. Cero: no se
  /// desvanece.
  final double fundidoInferior;

  /// Fracción del alto, desde arriba, en la que va apareciendo (para dejar
  /// el encabezado sobre el fondo liso en pantallas angostas).
  final double fundidoSuperior;

  /// Desenfoque de la propia foto (sigma). Cero: nítida.
  final double desenfoque;

  static const String _recurso = 'assets/images/fondo_valledupar_recorte.jpg';

  @override
  Widget build(BuildContext context) {
    Widget foto = Image.asset(
      _recurso,
      fit: BoxFit.cover,
      alignment: alineacion,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const SizedBox.expand(),
    );
    if (desenfoque > 0) {
      // El desenfoque pinta más allá de su caja: se recorta.
      foto = ClipRect(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: desenfoque,
            sigmaY: desenfoque,
            tileMode: TileMode.clamp,
          ),
          child: foto,
        ),
      );
    }
    if (fundidoInferior > 0 || fundidoSuperior > 0) {
      foto = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fundidoSuperior > 0 ? Colors.transparent : Colors.black,
            Colors.black,
            Colors.black,
            fundidoInferior > 0 ? Colors.transparent : Colors.black,
          ],
          stops: [0, fundidoSuperior, 1 - fundidoInferior, 1],
        ).createShader(rect),
        child: foto,
      );
    }
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: opacidad * 0.55),
            Colors.black.withValues(alpha: opacidad),
          ],
          stops: [inicio, (inicio + pleno) / 2, pleno],
        ).createShader(rect),
        child: foto,
      ),
    );
  }
}
