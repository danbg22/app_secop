import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../gestion_contractual/estilo_contractual.dart';

/// Recuadro para dibujar la firma con el mouse, el dedo o un lápiz. Entrega
/// un PNG con fondo transparente, recortado al trazo.
class FirmaPad extends StatefulWidget {
  const FirmaPad({super.key, required this.onGuardar, this.guardando = false});

  final ValueChanged<Uint8List> onGuardar;
  final bool guardando;

  @override
  State<FirmaPad> createState() => _FirmaPadState();
}

class _FirmaPadState extends State<FirmaPad> {
  final List<List<Offset>> _trazos = [];
  Size _tamano = Size.zero;

  bool get _vacia => _trazos.every((t) => t.length < 2);

  Future<void> _exportar() async {
    final puntos = _trazos.expand((t) => t);
    var minX = double.infinity, minY = double.infinity, maxX = 0.0, maxY = 0.0;
    for (final p in puntos) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    const margen = 8.0, escala = 2.0;
    final ancho = (maxX - minX + margen * 2), alto = (maxY - minY + margen * 2);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)
      ..scale(escala)
      ..translate(margen - minX, margen - minY);
    _PintorFirma(
      _trazos,
      color: const Color(0xFF0B1F3A),
    ).paint(canvas, _tamano);
    final img = await rec.endRecording().toImage(
      (ancho * escala).ceil(),
      (alto * escala).ceil(),
    );
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    if (png != null) widget.onGuardar(png.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            _tamano = Size(c.maxWidth, 170);
            return Container(
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 40,
                      child: Container(
                        height: 1,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                    if (_vacia)
                      const Positioned.fill(
                        child: Center(
                          child: Text(
                            'Firma aquí con el mouse o con el dedo',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) =>
                            setState(() => _trazos.add([d.localPosition])),
                        onPanUpdate: (d) =>
                            setState(() => _trazos.last.add(d.localPosition)),
                        child: CustomPaint(painter: _PintorFirma(_trazos)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton.icon(
              onPressed: _vacia ? null : () => setState(_trazos.clear),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Borrar'),
              style: TextButton.styleFrom(
                foregroundColor: EstiloContractual.navy,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _vacia || widget.guardando ? null : _exportar,
              style: EstiloContractual.botonPrincipal(),
              icon: const Icon(Icons.draw_outlined, size: 18),
              label: const Text(
                'Guardar mi firma',
                style: EstiloContractual.etiquetaBoton,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PintorFirma extends CustomPainter {
  _PintorFirma(this.trazos, {this.color = const Color(0xFF0E2646)});
  final List<List<Offset>> trazos;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final lapiz = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final t in trazos) {
      if (t.length < 2) continue;
      final path = Path()..moveTo(t.first.dx, t.first.dy);
      for (var i = 1; i < t.length - 1; i++) {
        final medio = Offset(
          (t[i].dx + t[i + 1].dx) / 2,
          (t[i].dy + t[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(t[i].dx, t[i].dy, medio.dx, medio.dy);
      }
      path.lineTo(t.last.dx, t.last.dy);
      canvas.drawPath(path, lapiz);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorFirma old) => true;
}
