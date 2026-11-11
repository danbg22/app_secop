import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cristal.dart';

/// Fondo de toda la aplicación: oscuro mate con manchas radiales muy
/// difuminadas en los colores de la marca, que se perciben a través de
/// los paneles de vidrio.
///
/// Va una sola vez, en `MaterialApp.builder`, detrás de todas las rutas;
/// las pantallas usan `Scaffold` transparente.
class FondoCristal extends StatelessWidget {
  const FondoCristal({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: CustomPaint(painter: _PintorManchas(), size: Size.infinite),
        ),
        child,
      ],
    );
  }
}

class _Mancha {
  const _Mancha(this.x, this.y, this.radio, this.color, this.alfa);

  /// Centro como fracción del ancho y del alto.
  final double x;
  final double y;

  /// Radio como fracción del lado mayor.
  final double radio;
  final Color color;
  final double alfa;
}

class _PintorManchas extends CustomPainter {
  const _PintorManchas();

  static const _manchas = [
    // Azul de la marca, arriba a la izquierda: la luz principal.
    _Mancha(0.10, 0.02, 0.62, Cristal.acento, 0.36),
    // Dorado, abajo a la derecha.
    _Mancha(0.96, 1.00, 0.52, Cristal.dorado, 0.15),
    // Azul claro, arriba a la derecha.
    _Mancha(0.88, 0.06, 0.40, Cristal.acentoClaro, 0.13),
    // Azul profundo, abajo a la izquierda, para que el borde no muera en negro.
    _Mancha(0.04, 0.96, 0.46, Color(0xFF1D4ED8), 0.20),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Cristal.fondo);
    final lado = math.max(size.width, size.height);
    for (final m in _manchas) {
      final centro = Offset(size.width * m.x, size.height * m.y);
      final radio = lado * m.radio;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              m.color.withValues(alpha: m.alfa),
              m.color.withValues(alpha: m.alfa * 0.42),
              m.color.withValues(alpha: m.alfa * 0.12),
              m.color.withValues(alpha: 0),
            ],
            stops: const [0, 0.38, 0.7, 1],
          ).createShader(Rect.fromCircle(center: centro, radius: radio)),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorManchas oldDelegate) => false;
}
