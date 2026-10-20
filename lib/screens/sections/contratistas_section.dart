import 'package:flutter/material.dart';

import '../contratistas_screen.dart';

export '../contratistas_screen.dart';

class ContratistasSection extends StatelessWidget {
  const ContratistasSection({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return ContratistasScreen(
      isEmbeddedInDashboard: true,
      onLogout: onLogout,
    );
  }
}
