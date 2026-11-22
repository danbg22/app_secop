import 'package:flutter/material.dart';

import '../data/roles_visual_assets_data.dart';
import '../services/payment_service.dart';

/// Ilustración de un rol en las tarjetas de escoger rol, registro y pago.
/// Los roles de Supervisión de contratos no tienen ilustración propia: se
/// dibujan con sus íconos sobre el color del rol.
class IlustracionRol extends StatelessWidget {
  const IlustracionRol({
    super.key,
    required this.rolId,
    this.alignment = Alignment.topCenter,
  });

  /// Id del rol o [AdminConfiguracionRolesYPagos.grupoSupervision] para la
  /// tarjeta que agrupa Supervisor y Contratista.
  final String rolId;
  final Alignment alignment;

  static const Color _tinta = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    final iconos = switch (rolId) {
      AdminConfiguracionRolesYPagos.grupoSupervision => const [
        Icons.fact_check_rounded,
        Icons.badge_rounded,
      ],
      'supervisor_contratos' => const [Icons.fact_check_rounded],
      'juridico_supervision' => const [Icons.gavel_rounded],
      'contratista' => const [Icons.badge_rounded],
      _ => const <IconData>[],
    };
    if (iconos.isEmpty) {
      return Image.memory(
        RolesVisualAssetsData.bytesForRole(rolId),
        fit: BoxFit.cover,
        alignment: alignment,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6F5F2), Color(0xFFB9E3DA)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final lado = c.biggest.shortestSide;
          final circulo = lado * (iconos.length > 1 ? 0.5 : 0.6);
          Widget burbuja(IconData icono, {bool frente = true}) => Container(
            width: circulo,
            height: circulo,
            decoration: BoxDecoration(
              color: frente ? Colors.white : const Color(0xFFD5EFEA),
              shape: BoxShape.circle,
              border: Border.all(
                color: _tinta.withValues(alpha: 0.35),
                width: lado > 80 ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _tinta.withValues(alpha: 0.18),
                  blurRadius: lado * 0.08,
                  offset: Offset(0, lado * 0.02),
                ),
              ],
            ),
            child: Icon(icono, size: circulo * 0.5, color: _tinta),
          );
          if (iconos.length == 1) {
            return Center(child: burbuja(iconos.first));
          }
          return Center(
            child: SizedBox(
              width: circulo * 1.7,
              height: circulo * 1.25,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: burbuja(iconos[1], frente: false),
                  ),
                  Positioned(right: 0, bottom: 0, child: burbuja(iconos[0])),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
