import 'package:flutter/material.dart';

import '../services/app_instalable_service.dart';
import '../tema/cristal.dart';

/// "Instalar app": deja Contrata Legal en el escritorio o en la pantalla de
/// inicio. Solo aparece cuando el navegador lo permite y aún no está
/// instalada.
class BotonInstalarApp extends StatelessWidget {
  const BotonInstalarApp({super.key, this.estilo, this.textoEstilo});

  final ButtonStyle? estilo;
  final TextStyle? textoEstilo;

  static Future<void> abrir(BuildContext context) async {
    if (!AppInstalable.esIphone) {
      await AppInstalable.instalar();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instalar Contrata Legal'),
        content: const Text(
          'En iPhone o iPad, ábrela en Safari, toca el botón Compartir '
          '(el cuadro con la flecha hacia arriba) y elige '
          '"Agregar a pantalla de inicio".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppInstalable.disponible,
      builder: (context, disponible, _) {
        if (!disponible) return const SizedBox.shrink();
        return OutlinedButton.icon(
          onPressed: () => abrir(context),
          style: estilo,
          icon: Icon(
            Icons.install_desktop_rounded,
            size: 15,
            color: Cristal.acentoClaro,
          ),
          label: Text('Instalar app', style: textoEstilo),
        );
      },
    );
  }
}
