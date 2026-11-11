import 'package:flutter/material.dart';

import 'escoger_rol_screen.dart';
import '../tema/cristal.dart';

/// Portada pública: mismo lenguaje visual que el flujo de registro
/// (fondo crema sin fotografías, tarjetas limpias y botones tipo píldora).
class PortadaScreen extends StatelessWidget {
  const PortadaScreen({super.key});

  static const List<_PortadaFeature> _features = [
    _PortadaFeature(
      icon: Icons.manage_search_rounded,
      title: 'Consulta contratos',
      description: 'Busca procesos de SECOP I y SECOP II por entidad, contratista u objeto, con cifras claras y enlaces a la fuente oficial.',
      color: Cristal.dorado,
      tint: Cristal.doradoVidrio,
      cardBg: Cristal.vidrioSuave,
    ),
    _PortadaFeature(
      icon: Icons.account_balance_rounded,
      title: 'Entidades y contratistas',
      description: 'Revisa el historial contractual de entidades públicas y contratistas para entender quién contrata, con quién y por cuánto.',
      color: Cristal.acentoClaro,
      tint: Cristal.vidrioSuave,
      cardBg: Cristal.vidrioSuave,
    ),
    _PortadaFeature(
      icon: Icons.verified_user_rounded,
      title: 'Gestión con trazabilidad',
      description: 'Equipos jurídicos estructuran contratos en línea, invitan contratistas y validan documentos dejando registro de cada paso.',
      color: Color(0xFF22D3EE),
      tint: Color(0x2414B8A6),
      cardBg: Cristal.vidrioSuave,
    ),
  ];

  void _irALogin(BuildContext context) => Navigator.pushNamed(context, '/auth');

  void _irARegistro(BuildContext context) =>
      Navigator.pushNamed(context, '/registro');

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: OnboardingUnifiedBackground(
          showScenicPhoto: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isDesktop = width >= 1040;
              final isTablet = width >= 640 && width < 1040;
              final isMobile = width < 640;

              return SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : (isTablet ? 28 : 44),
                    vertical: isMobile ? 14 : 22,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        children: [
                          _buildHeader(context, isMobile),
                          SizedBox(height: isMobile ? 36 : 64),
                          _buildHero(context, isMobile, isTablet),
                          SizedBox(height: isMobile ? 36 : 56),
                          if (isDesktop)
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    int i = 0;
                                    i < _features.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(width: 18),
                                    Expanded(
                                      child: _PortadaFeatureCard(
                                        feature: _features[i],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else
                            Column(
                              children: [
                                for (int i = 0; i < _features.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 16),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 560,
                                    ),
                                    child: _PortadaFeatureCard(
                                      feature: _features[i],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          const SizedBox(height: 28),
                          Text(
                            'Datos abiertos de Colombia Compra Eficiente (SECOP I y SECOP II).',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Cristal.textoMedio.withValues(alpha: 0.85),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Espacio para que los adornos inferiores no tapen el contenido.
                          SizedBox(height: isMobile ? 90 : 120),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ContrataLegalHdLogo(height: isMobile ? 46 : 64),
    );
  }

  Widget _buildHero(BuildContext context, bool isMobile, bool isTablet) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Cristal.dorado,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'Contratación pública\nmás clara '),
                TextSpan(
                  text: 'para todos',
                  style: TextStyle(color: Cristal.dorado),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Cristal.texto,
              fontSize: isMobile ? 30 : (isTablet ? 40 : 50),
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: isMobile ? -0.6 : -1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Información confiable, accesible y comprensible\nsobre la contratación pública en Colombia.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Cristal.textoMedio,
              fontSize: isMobile ? 14.5 : 17,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 220,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _irARegistro(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Cristal.dorado,
                    foregroundColor: Cristal.tinta,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Crear cuenta',
                        style: TextStyle(
                          color: Cristal.tinta,
                          fontSize: 15.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                        color: Cristal.tinta,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 220,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _irALogin(context),
                  // Acción secundaria: de vidrio, para que la principal
                  // (dorada) sea la única de color.
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Cristal.vidrioFuerte,
                    foregroundColor: Cristal.texto,
                    elevation: 0,
                    side: const BorderSide(color: Cristal.bordeFuerte),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Ya tengo cuenta',
                    style: TextStyle(
                      color: Cristal.texto,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortadaFeature {
  const _PortadaFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.tint,
    required this.cardBg,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color tint;
  final Color cardBg;
}

/// Tarjeta con la misma estructura que las tarjetas de rol del registro:
/// cabecera teñida con ícono circular, título y descripción.
class _PortadaFeatureCard extends StatelessWidget {
  const _PortadaFeatureCard({required this.feature});

  final _PortadaFeature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: feature.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: feature.color.withValues(alpha: 0.35),
          width: 1.3,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 84,
            width: double.infinity,
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            decoration: BoxDecoration(
              color: feature.tint,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: feature.color,
                shape: BoxShape.circle,
                border: Border.all(color: Cristal.borde, width: 3),
              ),
              child: Icon(
                feature.icon,
                color: Cristal.sobre(feature.color),
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              feature.title,
              style: const TextStyle(
                color: Cristal.texto,
                fontSize: 20.5,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              feature.description,
              style: const TextStyle(
                color: Cristal.textoMedio,
                fontSize: 13.5,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
