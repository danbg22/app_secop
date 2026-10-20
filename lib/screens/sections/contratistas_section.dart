import 'package:flutter/material.dart';

import '../contratistas_screen.dart';

export '../contratistas_screen.dart';

class ContratistasSection extends StatelessWidget {
  const ContratistasSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContratistasScreen(isEmbeddedInDashboard: true);
  }
}
