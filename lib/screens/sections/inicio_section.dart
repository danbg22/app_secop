import 'package:flutter/material.dart';

import '../../widgets/dashboard_top_bar.dart';
import '../../tema/cristal.dart';

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
    // Vidrio de verdad: la tarjeta va sobre la foto, así que desenfoca lo
    // que tiene detrás y lo oscurece para que el texto se lea.
    return PanelCristal(
      height: isMobile ? 210 : 280,
      radio: Cristal.radioPanel,
      desenfoque: true,
      color: Cristal.vidrioOscuro,
      colorEncima: Cristal.vidrioOscuroEncima,
      colorBorde: Cristal.bordeFuerte,
      colorBordeEncima: const Color(0x52FFFFFF),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Cristal.radioPanel - 1),
        child: Stack(
          children: [
            // Luz del color de la categoría, atrapada en el vidrio.
            Positioned(
              right: -80,
              bottom: -100,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        waveColor.withValues(alpha: 0.36),
                        waveColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: const SizedBox(width: 280, height: 280),
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
                      borderRadius: BorderRadius.circular(Cristal.radioAviso),
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: isMobile ? 28 : 36,
                    ),
                  ),
                  SizedBox(height: isMobile ? 10 : 16),
                  Text(
                    title,
                    style: TextStyle(
                      color: Cristal.texto,
                      fontSize: isMobile ? 19 : 22,
                      height: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Cristal.textoCuerpo,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Cristal.vidrioFuerte,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Cristal.bordeFuerte),
                        ),
                      ),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.chevron_right, color: Cristal.texto),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        description: 'Consulta todos los contratos de la entidad o filtra por criterios específicos.',
        iconBackground: Cristal.doradoVidrio,
        waveColor: Cristal.dorado,
        iconColor: Cristal.dorado,
        icon: Icons.description_outlined,
        onTap: () => onNavigateToSection(2),
        isMobile: isMobile,
      ),
      _buildCategoryCardContent(
        title: 'Entidades',
        description:
            'Explora las entidades contratantes y su gestión contractual.',
        iconBackground: Cristal.azulVidrio,
        waveColor: Cristal.acento,
        iconColor: Cristal.acentoClaro,
        icon: Icons.account_balance_outlined,
        onTap: () => onNavigateToSection(3),
        isMobile: isMobile,
      ),
      _buildCategoryCardContent(
        title: 'Contratistas',
        description:
            'Conoce el historial de contratistas y proveedores del Estado.',
        iconBackground: Cristal.verdeVidrio,
        waveColor: Cristal.verde,
        iconColor: Cristal.verde,
        icon: Icons.person_outline,
        onTap: () => onNavigateToSection(4),
        isMobile: isMobile,
      ),
    ];

    return Expanded(
      child: Stack(
        children: [
          // La foto de Valledupar, fundida con el fondo: es lo que se ve
          // a través de las tarjetas de vidrio.
          Positioned.fill(
            child: isMobile
                ? const FotoAmbiente(
                    opacidad: 0.7,
                    inicio: 0,
                    pleno: 0.9,
                    fundidoSuperior: 0.34,
                    fundidoInferior: 0.2,
                  )
                : const FotoAmbiente(
                    opacidad: 0.8,
                    inicio: 0.1,
                    pleno: 0.8,
                    fundidoInferior: 0.3,
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
                        Container(width: 40, height: 4, color: Cristal.dorado),
                        SizedBox(height: isMobile ? 12 : 18),
                        Text(
                          'Contrata Legal',
                          style: TextStyle(
                            color: Cristal.texto,
                            fontSize: isMobile ? 36 : 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        SizedBox(height: isMobile ? 10 : 16),
                        Text(
                          // El salto de línea fijo solo cabe en pantallas anchas.
                          'Explora la contratación pública de forma clara,'
                          '${isMobile ? ' ' : '\n'}'
                          'accesible y transparente.',
                          style: TextStyle(
                            color: Cristal.textoCuerpo,
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
