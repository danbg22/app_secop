import 'package:flutter/material.dart';

class ExplorarSection extends StatelessWidget {
  const ExplorarSection({
    super.key,
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onNavigateToSection,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<int> onNavigateToSection;

  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _crema = Color(0xFFFFF8EE);

  BoxDecoration _exploreCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: _azulOscuro.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildExploreCategoryCard({
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color iconColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 140,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.75),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _azulOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: _azulOscuro,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExploreMainContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 270,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: 400,
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Colors.black],
                    ).createShader(bounds),
                    child: Image.asset(
                      'assets/images/fondo_valledupar.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Volver al inicio',
                            onPressed: () => onNavigateToSection(0),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: _azulOscuro,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Explorar',
                            style: TextStyle(
                              color: _azulOscuro,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Descubre y entiende\nla contratación pública',
                        style: TextStyle(
                          color: _azulOscuro,
                          fontSize: 34,
                          height: 1.12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Busca contratos, entidades, contratistas y mucho más. '
                        'Toda la información en un solo lugar.',
                        style: TextStyle(
                          color: Colors.blueGrey.shade600,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(80),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explora por categorías',
                    style: TextStyle(
                      color: _azulOscuro,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildExploreCategoryCard(
                            title: 'Contratos',
                            subtitle:
                                'Consulta todos los contratos de la entidad o filtra por criterios específicos.',
                            backgroundColor: const Color(0xFFFFF9E6),
                            iconColor: const Color(0xFFF9A826),
                            icon: Icons.description_outlined,
                            onTap: () => onNavigateToSection(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildExploreCategoryCard(
                            title: 'Entidades',
                            subtitle:
                                'Explora las entidades contratantes y su gestión contractual.',
                            backgroundColor: const Color(0xFFF0F4FF),
                            iconColor: const Color(0xFF1E64D4),
                            icon: Icons.account_balance_outlined,
                            onTap: () => onNavigateToSection(3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildExploreCategoryCard(
                            title: 'Contratistas',
                            subtitle:
                                'Conoce el historial de contratistas y proveedores del Estado.',
                            backgroundColor: const Color(0xFFEEF9F0),
                            iconColor: const Color(0xFF00A36C),
                            icon: Icons.person_outline,
                            onTap: () => onNavigateToSection(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildExploreCategoryCard(
                            title: 'Estadísticas',
                            subtitle:
                                'Visualiza datos, tendencias y análisis de la contratación pública.',
                            backgroundColor: const Color(0xFFFFF0F5),
                            iconColor: const Color(0xFFD9383A),
                            icon: Icons.bar_chart,
                            onTap: () => onNavigateToSection(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _crema,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb,
                          color: Color(0xFFF9A826),
                          size: 34,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '¿No sabes por dónde empezar?',
                                style: TextStyle(
                                  color: _azulOscuro,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Aprende a encontrar y entender la información pública.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.blueGrey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => onNavigateToSection(2),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Explorar contratos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD54F),
                            foregroundColor: _azulOscuro,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExploreRightSide(BuildContext context) {
    final recentSearches = [
      ('Contratos de abogados', 'Hoy, 10:24 a.m.'),
      ('Hacienda Valledupar 2026', 'Hoy, 9:15 a.m.'),
      ('Obras públicas del Cesar', 'Ayer, 4:32 p.m.'),
      ('Proveedores de salud', 'Ayer, 11:08 a.m.'),
      ('Contratos de tecnología', '12 oct, 3:40 p.m.'),
    ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: _exploreCardDecoration(),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Color(0xFFF9A826)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Datos clave de Valledupar',
                      style: TextStyle(
                        color: _azulOscuro,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ExploreStatTile(
                          label: 'Contratos',
                          value: '1.248',
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _ExploreStatTile(
                          label: 'Valor contratado',
                          value: '\$182.400 M',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ExploreStatTile(
                          label: 'Contratistas',
                          value: '487',
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _ExploreStatTile(
                          label: 'Dependencias',
                          value: '15',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            decoration: _exploreCardDecoration(),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Búsquedas recientes',
                        style: TextStyle(
                          color: _azulOscuro,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onNavigateToSection(2),
                      child: const Text('Ver todas'),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final search in recentSearches)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.search,
                            color: Color(0xFF78909C),
                            size: 20,
                          ),
                          title: Text(
                            search.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _azulOscuro,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            search.$2,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () {
                            searchController.text = search.$1;
                            onSearchSubmitted(search.$1);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF8EE), Color(0xFFEAF2FF)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: _azulOscuro, size: 30),
              const SizedBox(height: 12),
              const Text(
                'Sé parte del cambio',
                style: TextStyle(
                  color: _azulOscuro,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'La información pública también es tuya. Explórala, '
                'compártela y ayúdanos a construir transparencia.',
                style: TextStyle(
                  color: Colors.blueGrey.shade700,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 5,
                        child: ColoredBox(color: Color(0xFFFCD116)),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 5,
                        child: ColoredBox(color: Color(0xFF003893)),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 5,
                        child: ColoredBox(color: Color(0xFFCE1126)),
                      ),
                    ),
                  ],
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
    return Expanded(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFFBF8F1),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 7, child: _buildExploreMainContent(context)),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: _buildExploreRightSide(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreStatTile extends StatelessWidget {
  const _ExploreStatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 10),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A2B4C),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

