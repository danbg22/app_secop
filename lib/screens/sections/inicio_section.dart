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

  Widget _buildCategoryCardContent({
    required String title,
    required String description,
    required Color iconBackground,
    required Color waveColor,
    required Color iconColor,
    required IconData icon,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Container(
      height: isMobile ? 210 : 280,
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
                  padding: EdgeInsets.all(isMobile ? 18 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isMobile ? 56 : 72,
                        height: isMobile ? 56 : 72,
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: isMobile ? 28 : 36,
                        ),
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      Text(
                        title,
                        style: TextStyle(
                          color: const Color(0xFF0F172A),
                          fontSize: isMobile ? 19 : 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF1A2B4C).withValues(alpha: 0.78),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 768;

    final cards = [
      _buildCategoryCardContent(
        title: 'Contratos',
        description:
            'Consulta todos los contratos de la entidad o filtra por criterios específicos.',
        iconBackground: const Color(0xFFFFF9C4),
        waveColor: const Color(0xFFFFF9C4),
        iconColor: const Color(0xFFFBC02D),
        icon: Icons.description_outlined,
        onTap: () => onNavigateToSection(2),
        isMobile: isMobile,
      ),
      _buildCategoryCardContent(
        title: 'Entidades',
        description:
            'Explora las entidades contratantes y su gestión contractual.',
        iconBackground: const Color(0xFFE3F2FD),
        waveColor: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1976D2),
        icon: Icons.account_balance_outlined,
        onTap: () => onNavigateToSection(3),
        isMobile: isMobile,
      ),
      _buildCategoryCardContent(
        title: 'Contratistas',
        description:
            'Conoce el historial de contratistas y proveedores del Estado.',
        iconBackground: const Color(0xFFE8F5E9),
        waveColor: const Color(0xFFE8F5E9),
        iconColor: const Color(0xFF388E3C),
        icon: Icons.person_outline,
        onTap: () => onNavigateToSection(4),
        isMobile: isMobile,
      ),
    ];

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
                if (!isMobile)
                  DashboardTopBar(
                    searchController: searchController,
                    onSearchSubmitted: onSearchSubmitted,
                    onLogout: onLogout,
                    transparent: true,
                    showSearch: false,
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 20 : 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          color: const Color(0xFFFFD54F),
                        ),
                        SizedBox(height: isMobile ? 12 : 18),
                        Text(
                          'Contrata Legal',
                          style: TextStyle(
                            color: const Color(0xFF0F172A),
                            fontSize: isMobile ? 36 : 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        SizedBox(height: isMobile ? 10 : 16),
                        Text(
                          'Explora la contratación pública de forma clara,\n'
                          'accesible y transparente.',
                          style: TextStyle(
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                            fontSize: isMobile ? 16 : 22,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: isMobile ? 24 : 40),
                        if (isMobile)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              cards[0],
                              const SizedBox(height: 16),
                              cards[1],
                              const SizedBox(height: 16),
                              cards[2],
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 24),
                              Expanded(child: cards[1]),
                              const SizedBox(width: 24),
                              Expanded(child: cards[2]),
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
