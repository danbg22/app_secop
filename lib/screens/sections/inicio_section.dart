import 'package:flutter/material.dart';

import '../../widgets/dashboard_top_bar.dart';

class InicioSection extends StatelessWidget {
  const InicioSection({
    super.key,
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onNavigateToSection,
    required this.onLogout,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<int> onNavigateToSection;
  final VoidCallback onLogout;

  Widget _buildCategoryCard({
    required String title,
    required String description,
    required Color iconBackground,
    required Color waveColor,
    required Color iconColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Container(
        height: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    right: -20,
                    left: -20,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: waveColor.withValues(alpha: 0.8),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.elliptical(300, 80),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: iconBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, color: iconColor, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            color: const Color(0xFF1A2B4C)
                                .withValues(alpha: 0.78),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const Spacer(),
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x241A2B4C),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.chevron_right,
                                color: Color(0xFF1A2B4C),
                              ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFFFBF8F1))),
          Positioned.fill(
            child: Image.asset(
              'assets/images/fondo_valledupar.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFFFF8E7),
                    Color(0xDDFFF8E7),
                    Color(0x00FFF8E7),
                  ],
                  stops: [0.0, 0.3, 0.6],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              children: [
                DashboardTopBar(
                  searchController: searchController,
                  onSearchSubmitted: onSearchSubmitted,
                  onLogout: onLogout,
                  transparent: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          color: const Color(0xFFFFD54F),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Contrata Legal',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Explora la contratación pública de forma clara,\n'
                          'accesible y transparente.',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                            fontSize: 22,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildCategoryCard(
                              title: 'Contratos',
                              description:
                                  'Consulta todos los contratos de la entidad o filtra por criterios específicos.',
                              iconBackground: const Color(0xFFFFF9C4),
                              waveColor: const Color(0xFFFFF9C4),
                              iconColor: const Color(0xFFFBC02D),
                              icon: Icons.description_outlined,
                              onTap: () => onNavigateToSection(2),
                            ),
                            const SizedBox(width: 24),
                            _buildCategoryCard(
                              title: 'Entidades',
                              description:
                                  'Explora las entidades contratantes y su gestión contractual.',
                              iconBackground: const Color(0xFFE3F2FD),
                              waveColor: const Color(0xFFE3F2FD),
                              iconColor: const Color(0xFF1976D2),
                              icon: Icons.account_balance_outlined,
                              onTap: () => onNavigateToSection(3),
                            ),
                            const SizedBox(width: 24),
                            _buildCategoryCard(
                              title: 'Contratistas',
                              description:
                                  'Conoce el historial de contratistas y proveedores del Estado.',
                              iconBackground: const Color(0xFFE8F5E9),
                              waveColor: const Color(0xFFE8F5E9),
                              iconColor: const Color(0xFF388E3C),
                              icon: Icons.person_outline,
                              onTap: () => onNavigateToSection(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

