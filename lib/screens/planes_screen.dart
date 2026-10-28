import 'package:flutter/material.dart';

import 'escoger_rol_screen.dart';

/// Pantalla de selección y acumulación de roles/planes conectada al nuevo
/// catálogo oficial de roles y a la pasarela de pago segura de Wompi.
class PlanesScreen extends StatelessWidget {
  const PlanesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EscogerRolScreen(modoAcumularRol: true);
  }
}
