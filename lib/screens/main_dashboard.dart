import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../utils/estado_vista.dart';
import '../widgets/collapsible_side_menu.dart';
import 'home_screen.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final rol = PaymentService.obtenerConfiguracionRol(
      AuthService.getPendingRegistrationRoleId(),
    );
    final guardada = EstadoVista.leer('panel')['seccion'];
    return HomeScreen(
      initialIndex: guardada is int
          ? guardada
          : rol.grupo == AdminConfiguracionRolesYPagos.grupoSupervision
          ? CollapsibleSideMenu.indiceSupervision
          : 0,
    );
  }
}
