import 'package:flutter/material.dart';

import '../data/portada_asset_data.dart';

class PortadaScreen extends StatelessWidget {
  const PortadaScreen({super.key});

  static const double _designWidth = 1024.0;
  static const double _designHeight = 544.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF1),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;
          final scaleX = screenW / _designWidth;
          final scaleY = screenH / _designHeight;
          final fontScale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.75, 2.5);

          final btnTop = (18.0 * scaleY).clamp(12.0, 56.0);
          final btnHeight = (32.0 * scaleY).clamp(30.0, 56.0);
          final loginLeft = 758.0 * scaleX;
          final loginWidth = (106.0 * scaleX).clamp(96.0, 220.0);
          final registerLeft = 878.0 * scaleX;
          final registerWidth = (98.0 * scaleX).clamp(90.0, 205.0);
          final radius = (9.0 * fontScale).clamp(7.0, 15.0);
          final btnFontSize = (12.5 * fontScale).clamp(11.5, 19.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Ilustración de fondo en alta definición (2048x1088)
              Image.memory(
                PortadaAssetData.bytes,
                width: screenW,
                height: screenH,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
              ),

              // 2. Logo "Contrata Legal" en alta definición (1774x887 transparente)
              Positioned(
                left: 28.3 * scaleX,
                top: -1.9 * scaleY,
                width: 187.8 * scaleX,
                height: 91.2 * scaleY,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),

              // 3. Línea decorativa amarilla superior (100% vectorial)
              Positioned(
                left: 57.0 * scaleX,
                top: 141.0 * scaleY,
                width: 43.0 * scaleX,
                height: (3.5 * scaleY).clamp(2.5, 6.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5C638),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 4. Título principal y subtítulo 100% vectoriales en HD/4K
              Positioned(
                left: 57.0 * scaleX,
                top: 161.0 * scaleY,
                width: 472.0 * scaleX,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Segoe UI',
                            fontSize: 51.0 * scaleY,
                            fontWeight: FontWeight.w800,
                            height: 1.06,
                            letterSpacing: -1.0 * scaleX,
                            color: const Color(0xFF081A45),
                          ),
                          children: const [
                            TextSpan(text: 'Contratación pública\n'),
                            TextSpan(text: 'más clara '),
                            TextSpan(
                              text: 'para todos',
                              style: TextStyle(
                                color: Color(0xFFFCBA1D),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 15.0 * scaleY),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Información confiable, accesible y comprensible\nsobre la contratación pública en Colombia.',
                        style: TextStyle(
                          fontFamily: 'Segoe UI',
                          fontSize: 19.5 * scaleY,
                          fontWeight: FontWeight.w400,
                          height: 1.32,
                          letterSpacing: -0.15 * scaleX,
                          color: const Color(0xFF566B84),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Botón "Iniciar sesión" en la posición exacta de la referencia
              Positioned(
                top: btnTop,
                left: loginLeft,
                width: loginWidth,
                height: btnHeight,
                child: _PortadaOutlinedButton(
                  label: 'Iniciar sesión',
                  fontSize: btnFontSize,
                  borderRadius: radius,
                  onTap: () => Navigator.pushNamed(context, '/auth'),
                ),
              ),

              // 6. Botón "Registrarse" en la posición exacta de la referencia
              Positioned(
                top: btnTop,
                left: registerLeft,
                width: registerWidth,
                height: btnHeight,
                child: _PortadaFilledButton(
                  label: 'Registrarse',
                  fontSize: btnFontSize,
                  borderRadius: radius,
                  onTap: () => Navigator.pushNamed(context, '/registro'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PortadaOutlinedButton extends StatefulWidget {
  final String label;
  final double fontSize;
  final double borderRadius;
  final VoidCallback onTap;

  const _PortadaOutlinedButton({
    required this.label,
    required this.fontSize,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  State<_PortadaOutlinedButton> createState() => _PortadaOutlinedButtonState();
}

class _PortadaOutlinedButtonState extends State<_PortadaOutlinedButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white
                : const Color(0xFFF0F5F9).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF031E4E)
                  : const Color(0xFF6E809B),
              width: 1.15,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF031E4E).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: const Color(0xFF031E4E),
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PortadaFilledButton extends StatefulWidget {
  final String label;
  final double fontSize;
  final double borderRadius;
  final VoidCallback onTap;

  const _PortadaFilledButton({
    required this.label,
    required this.fontSize,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  State<_PortadaFilledButton> createState() => _PortadaFilledButtonState();
}

class _PortadaFilledButtonState extends State<_PortadaFilledButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF0A2E6E)
                : const Color(0xFF031E4E),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF031E4E).withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}
