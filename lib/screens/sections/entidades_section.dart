import 'package:flutter/material.dart';

import '../resultados_screen.dart';
import '../segmentacion_screen.dart';

class EntidadesSection extends StatelessWidget {
  const EntidadesSection({super.key});

  static const Color _azulOscuro = Color(0xFF1A2B4C);

  Widget _buildEntityTab(IconData icon, String label, {bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? _azulOscuro : Colors.blueGrey.shade400,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _azulOscuro : Colors.blueGrey.shade500,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: selected ? 42 : 0,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityListCard(
    BuildContext context, {
    required String name,
    required IconData icon,
    required String contracts,
    required String amount,
    required String departments,
  }) {
    Widget metric(IconData metricIcon, String value, String label) {
      return Row(
        children: [
          Icon(metricIcon, size: 18, color: Colors.blueGrey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.blueGrey.shade500,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultadosScreen(
              nivel: 'Municipal',
              departamento: 'Cesar',
              municipio: 'Valledupar',
              dependencia: name,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _azulOscuro.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF4D6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _azulOscuro, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _azulOscuro,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Valledupar, Cesar',
                    style: TextStyle(
                      color: Colors.blueGrey.shade500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: metric(Icons.description_outlined, contracts, 'Contratos'),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: metric(Icons.payments_outlined, amount, 'Valor contratado'),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: metric(
                Icons.account_tree_outlined,
                departments,
                'Dependencias',
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildEntitiesRightSide(BuildContext context) {
    Widget panel({
      required Widget child,
      EdgeInsets padding = const EdgeInsets.all(18),
    }) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _azulOscuro.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
    }

    const topEntities = [
      ('Alcaldía de Valledupar', '1.248', '\$182.400 M'),
      ('Gobernación del Cesar', '864', '\$96.250 M'),
      ('Secretaría de Educación', '386', '\$48.620 M'),
      ('Hospital E.A.D.', '214', '\$32.180 M'),
      ('Instituto de Deportes', '92', '\$12.750 M'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top 5 Entidades',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < topEntities.length; index++) ...[
                if (index > 0) const SizedBox(height: 13),
                Row(
                  children: [
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.blueGrey.shade400,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF4D6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: _azulOscuro,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topEntities[index].$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${topEntities[index].$2} contratos · ${topEntities[index].$3}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.blueGrey.shade500,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Explorador de relaciones',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE082),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'NUEVO',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Descubre conexiones entre entidades y contratistas.',
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _EntityNetworkIllustration(),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SegmentacionScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _azulOscuro,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'Explorar por territorio',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comparar entidades',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Compara contratos y valores entre entidades.',
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _EntityBarIllustration(),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SegmentacionScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _azulOscuro,
                    side: const BorderSide(color: Color(0xFFD5DDE6)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text(
                    'Seleccionar entidades',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget filterButton(String label, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE5E9EF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _azulOscuro,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 7),
            Icon(icon, size: 16, color: Colors.blueGrey.shade500),
          ],
        ),
      );
    }

    Widget summaryCard({
      required IconData icon,
      required Color iconColor,
      required Color iconBackground,
      required String label,
      required String value,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: _azulOscuro.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(height: 11),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _azulOscuro,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    const entities = [
      (
        name: 'Alcaldía de Valledupar',
        icon: Icons.account_balance,
        contracts: '1.248',
        amount: '\$182.400 M',
        departments: '15',
      ),
      (
        name: 'Secretaría de Educación',
        icon: Icons.school,
        contracts: '386',
        amount: '\$48.620 M',
        departments: '8',
      ),
      (
        name: 'Hospital Eduardo Arredondo Daza',
        icon: Icons.local_hospital,
        contracts: '214',
        amount: '\$32.180 M',
        departments: '6',
      ),
      (
        name: 'Instituto Municipal de Deportes',
        icon: Icons.sports_soccer,
        contracts: '92',
        amount: '\$12.750 M',
        departments: '4',
      ),
    ];

    return Expanded(
      child: Container(
        color: const Color(0xFFFFF8E7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 130,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const ColoredBox(color: Color(0xFFFFF8E7)),
                                  ShaderMask(
                                    blendMode: BlendMode.dstIn,
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        Colors.white,
                                      ],
                                      stops: [0.05, 0.85],
                                    ).createShader(bounds),
                                    child: Image.asset(
                                      'assets/images/fondo_valledupar.jpg',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Entidades',
                                  style: TextStyle(
                                    color: _azulOscuro,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Explora las entidades y conoce cómo gestionan los recursos públicos.',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Buscar entidades...',
                              hintStyle: TextStyle(
                                color: Colors.blueGrey.shade400,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF78909C),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(11),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        filterButton('Valledupar', Icons.expand_more),
                        const SizedBox(width: 10),
                        filterButton('2026', Icons.expand_more),
                        const SizedBox(width: 10),
                        filterButton('Estado', Icons.expand_more),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        summaryCard(
                          icon: Icons.account_balance,
                          iconColor: const Color(0xFF1976D2),
                          iconBackground: const Color(0xFFE3F2FD),
                          label: 'Entidades',
                          value: '48',
                        ),
                        const SizedBox(width: 12),
                        summaryCard(
                          icon: Icons.insert_drive_file,
                          iconColor: const Color(0xFF1976D2),
                          iconBackground: const Color(0xFFE3F2FD),
                          label: 'Total de contratos',
                          value: '3.842',
                        ),
                        const SizedBox(width: 12),
                        summaryCard(
                          icon: Icons.monetization_on,
                          iconColor: const Color(0xFF388E3C),
                          iconBackground: const Color(0xFFE8F5E9),
                          label: 'Valor contratado',
                          value: '\$426.8 mil M',
                        ),
                        const SizedBox(width: 12),
                        summaryCard(
                          icon: Icons.people,
                          iconColor: const Color(0xFF1976D2),
                          iconBackground: const Color(0xFFE3F2FD),
                          label: 'Contratistas únicos',
                          value: '1.206',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildEntityTab(
                                  Icons.grid_view,
                                  'Todas',
                                  selected: true,
                                ),
                                _buildEntityTab(
                                  Icons.account_balance,
                                  'Alcaldías',
                                ),
                                _buildEntityTab(Icons.apartment, 'Secretarías'),
                                _buildEntityTab(Icons.business, 'Institutos'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ordenar por: ',
                              style: TextStyle(
                                color: Color(0xFF78909C),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Más relevantes',
                              style: TextStyle(
                                color: _azulOscuro,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.expand_more,
                              size: 17,
                              color: Color(0xFF78909C),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: entities.length,
                      itemBuilder: (context, index) {
                        final entity = entities[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildEntityListCard(
                            context,
                            name: entity.name,
                            icon: entity.icon,
                            contracts: entity.contracts,
                            amount: entity.amount,
                            departments: entity.departments,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: _buildEntitiesRightSide(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntityNetworkIllustration extends StatelessWidget {
  const _EntityNetworkIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 48,
      child: Stack(
        children: [
          Positioned(
            left: 19,
            top: 10,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 34,
                height: 2,
                color: const Color(0xFFCBD5E1),
              ),
            ),
          ),
          Positioned(
            left: 19,
            top: 31,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 34,
                height: 2,
                color: const Color(0xFFCBD5E1),
              ),
            ),
          ),
          Positioned(
            left: 1,
            top: 17,
            child: _networkNode(const Color(0xFFFFD54F), 14),
          ),
          Positioned(
            left: 29,
            top: 2,
            child: _networkNode(const Color(0xFF1976D2), 16),
          ),
          Positioned(
            left: 53,
            top: 17,
            child: _networkNode(const Color(0xFF009688), 14),
          ),
          Positioned(
            left: 29,
            top: 32,
            child: _networkNode(const Color(0xFF9C27B0), 14),
          ),
        ],
      ),
    );
  }

  Widget _networkNode(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _EntityBarIllustration extends StatelessWidget {
  const _EntityBarIllustration();

  @override
  Widget build(BuildContext context) {
    const heights = [19.0, 32.0, 25.0, 39.0];
    const colors = [
      Color(0xFFFFC107),
      Color(0xFF1976D2),
      Color(0xFFFFC107),
      Color(0xFF1976D2),
    ];

    return SizedBox(
      width: 68,
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var index = 0; index < heights.length; index++)
            Container(
              width: 10,
              height: heights[index],
              decoration: BoxDecoration(
                color: colors[index],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

