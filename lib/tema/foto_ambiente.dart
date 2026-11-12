import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// La foto de Valledupar como luz de ambiente del fondo: atenuada y
/// fundida con el fondo de la aplicación hacia la izquierda (y, si se pide,
/// hacia arriba y hacia abajo), para que se perciba a través de los paneles
/// de vidrio sin competir con el texto.
///
/// La foto y sus fundidos se pintan en una sola capa recortada a la caja.
/// (Con `ShaderMask` sobre la imagen, el navegador dejaba ver una fila de
/// píxeles sin fundir en el borde inferior: una raya a lo ancho de la
/// pantalla.)
class FotoAmbiente extends StatefulWidget {
  const FotoAmbiente({
    super.key,
    this.alineacion = const Alignment(0.15, -0.25),
    this.opacidad = 0.62,
    this.inicio = 0.18,
    this.pleno = 0.72,
    this.fundidoInferior = 0.4,
    this.fundidoSuperior = 0,
  }) : difusa = false;

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
  }) : difusa = true;

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

  /// Usa la versión ya desenfocada de la foto (un desenfoque en vivo
  /// cuesta en cada cuadro al desplazar la página).
  final bool difusa;

  static const AssetImage nitida = AssetImage(
    'assets/images/fondo_valledupar_recorte.jpg',
  );
  static const AssetImage desenfocada = AssetImage(
    'assets/images/fondo_valledupar_difuso.jpg',
  );

  ImageProvider get proveedor => difusa ? desenfocada : nitida;

  @override
  State<FotoAmbiente> createState() => _FotoAmbienteState();
}

class _FotoAmbienteState extends State<FotoAmbiente> {
  ImageStream? _flujo;
  ImageInfo? _imagen;
  late final ImageStreamListener _oyente = ImageStreamListener((info, _) {
    if (!mounted) return;
    setState(() {
      _imagen?.dispose();
      _imagen = info;
    });
  }, onError: (_, _) {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolver();
  }

  @override
  void didUpdateWidget(FotoAmbiente oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.difusa != widget.difusa) _resolver();
  }

  void _resolver() {
    final flujo = widget.proveedor.resolve(
      createLocalImageConfiguration(context),
    );
    if (flujo.key == _flujo?.key) return;
    _flujo?.removeListener(_oyente);
    _flujo = flujo..addListener(_oyente);
  }

  @override
  void dispose() {
    _flujo?.removeListener(_oyente);
    _imagen?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagen = _imagen?.image;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: imagen == null
              ? null
              : _PintorFoto(
                  imagen: imagen,
                  alineacion: widget.alineacion,
                  opacidad: widget.opacidad,
                  inicio: widget.inicio,
                  pleno: widget.pleno,
                  fundidoInferior: widget.fundidoInferior,
                  fundidoSuperior: widget.fundidoSuperior,
                ),
        ),
      ),
    );
  }
}

class _PintorFoto extends CustomPainter {
  const _PintorFoto({
    required this.imagen,
    required this.alineacion,
    required this.opacidad,
    required this.inicio,
    required this.pleno,
    required this.fundidoInferior,
    required this.fundidoSuperior,
  });

  final ui.Image imagen;
  final Alignment alineacion;
  final double opacidad;
  final double inicio;
  final double pleno;
  final double fundidoInferior;
  final double fundidoSuperior;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final caja = Offset.zero & size;
    canvas
      ..save()
      ..clipRect(caja)
      ..saveLayer(caja, Paint());
    paintImage(
      canvas: canvas,
      rect: caja,
      image: imagen,
      fit: BoxFit.cover,
      alignment: alineacion,
      filterQuality: FilterQuality.medium,
    );
    // Fundido horizontal: transparente a la izquierda.
    canvas.drawRect(
      caja,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: opacidad * 0.55),
            Colors.black.withValues(alpha: opacidad),
          ],
          stops: [inicio, (inicio + pleno) / 2, pleno],
        ).createShader(caja),
    );
    // Fundido vertical.
    if (fundidoInferior > 0 || fundidoSuperior > 0) {
      canvas.drawRect(
        caja,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // El fundido inferior termina en cero antes del borde: la
            // última franja queda vacía aunque el navegador redondee la
            // posición de la caja a medio píxel.
            colors: [
              fundidoSuperior > 0 ? Colors.transparent : Colors.black,
              Colors.black,
              Colors.black,
              fundidoInferior > 0 ? Colors.transparent : Colors.black,
              fundidoInferior > 0 ? Colors.transparent : Colors.black,
            ],
            stops: [
              0,
              fundidoSuperior,
              (1 - fundidoInferior).clamp(fundidoSuperior, 0.94),
              0.94,
              1,
            ],
          ).createShader(caja),
      );
    }
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_PintorFoto old) =>
      old.imagen != imagen ||
      old.alineacion != alineacion ||
      old.opacidad != opacidad ||
      old.inicio != inicio ||
      old.pleno != pleno ||
      old.fundidoInferior != fundidoInferior ||
      old.fundidoSuperior != fundidoSuperior;
}
