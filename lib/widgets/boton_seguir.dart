import 'package:flutter/material.dart';

import '../services/seguimiento_service.dart';
import '../tema/cristal.dart';

/// Botón "Seguir" de los perfiles de entidad y de contratista.
class BotonSeguir extends StatelessWidget {
  const BotonSeguir({
    super.key,
    required this.tipo,
    required this.clave,
    required this.nombre,
    this.compacto = false,
  });

  final TipoSeguido tipo;
  final String clave;
  final String nombre;
  final bool compacto;

  Future<void> _alternar(BuildContext context, bool sigue) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (sigue) {
        await SeguimientoService.dejarDeSeguir(tipo, clave);
      } else {
        await SeguimientoService.seguir(
          tipo: tipo,
          clave: clave,
          nombre: nombre,
        );
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              sigue
                  ? 'Dejaste de seguir a $nombre.'
                  : 'Sigues a $nombre: sus contratos nuevos aparecerán en Alertas.',
            ),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('$e'.replaceFirst('Bad state: ', '')),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SeguimientoService.cambios,
      builder: (context, _) {
        final sigue = SeguimientoService.sigue(tipo, clave);
        final icono = Icon(
          sigue
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          size: compacto ? 22 : 17,
          color: sigue ? Cristal.acentoClaro : Cristal.texto,
        );
        if (compacto) {
          return IconButton(
            tooltip: sigue
                ? 'Dejar de seguir'
                : 'Seguir: avísame de sus contratos nuevos',
            onPressed: () => _alternar(context, sigue),
            icon: icono,
          );
        }
        return Tooltip(
          message: sigue
              ? 'Sus contratos nuevos aparecen en Alertas'
              : 'Avísame de sus contratos nuevos',
          child: OutlinedButton.icon(
            onPressed: () => _alternar(context, sigue),
            icon: icono,
            label: Text(
              sigue ? 'Siguiendo' : 'Seguir',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Cristal.texto,
              side: BorderSide(
                color: sigue ? Cristal.acentoBorde : Cristal.bordeFuerte,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      },
    );
  }
}
