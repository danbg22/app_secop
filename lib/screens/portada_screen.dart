import 'package:flutter/material.dart';

import 'escoger_rol_screen.dart';

/// Portada pública: mismo lenguaje visual que el flujo de registro
/// (fondo crema sin fotografías, tarjetas limpias y botones tipo píldora).
class PortadaScreen extends StatelessWidget {
  const PortadaScreen({super.key});

  static const Color _navy = Color(0xFF0E2646);
  static const Color _subtitleBlue = Color(0xFF364F6B);
  static const Color _gold = Color(0xFFF5C032);
  static const Color _goldText = Color(0xFFC98A00);

  static const List<_PortadaFeature> _features = [
    _PortadaFeature(
      icon: Icons.manage_search_rounded,
      title: 'Consulta contratos',
      description:
          'Busca procesos de SECOP I y SECOP II por entidad, contratista u objeto, con cifras claras y enlaces a la fuente oficial.',
      color: Color(0xFFF5B82E),
      tint: Color(0xFFFFF3CC),
      cardBg: Color(0xFFFEFBF0),
    ),
    _PortadaFeature(
      icon: Icons.account_balance_rounded,
      title: 'Entidades y contratistas',
      description:
          'Revisa el historial contractual de entidades públicas y contratistas para entender quién contrata, con quién y por cuánto.',
      color: Color(0xFF28559A),
      tint: Color(0xFFE8F1FC),
      cardBg: Color(0xFFF8FAFC),
    ),
    _PortadaFeature(
      icon: Icons.verified_user_rounded,
      title: 'Gestión con trazabilidad',
      description:
          'Equipos jurídicos estructuran contratos en línea, invitan contratistas y validan documentos dejando registro de cada paso.',
      color: Color(0xFF1F6E7A),
      tint: Color(0xFFE3F3F2),
      cardBg: Color(0xFFF9FCFA),
    ),
  ];

  void _irALogin(BuildContext context) =>
      Navigator.pushNamed(context, '/auth');

  void _irARegistro(BuildContext context) =>
      Navigator.pushNamed(context, '/registro');

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        backgroundColor: OnboardingUnifiedBackground.bgCream,
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
                                  for (int i = 0; i < _features.length; i++) ...[
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
                              color: _subtitleBlue.withValues(alpha: 0.85),
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
    return Row(
      children: [
        ContrataLegalHdLogo(height: isMobile ? 38 : 48, withWhitePill: true),
        const Spacer(),
        _PortadaPillButton(
          label: 'Iniciar sesión',
          icon: Icons.login_rounded,
          compact: isMobile,
          onTap: () => _irALogin(context),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 10),
          _PortadaPillButton(
            label: 'Registrarse',
            filled: true,
            onTap: () => _irARegistro(context),
          ),
        ],
      ],
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
              color: _gold,
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
                  style: TextStyle(color: _goldText),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _navy,
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
              color: _subtitleBlue,
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
                    backgroundColor: const Color(0xFFF8C63A),
                    foregroundColor: _navy,
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
                          color: _navy,
                          fontSize: 15.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 19, color: _navy),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 220,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _irALogin(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Ya tengo cuenta',
                    style: TextStyle(
                      color: Colors.white,
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

  static const Color _navy = Color(0xFF0E2646);
  static const Color _subtitleBlue = Color(0xFF364F6B);

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
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
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
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(feature.icon, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              feature.title,
              style: const TextStyle(
                color: _navy,
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
                color: _subtitleBlue,
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

/// Botón píldora de la barra superior, con el estilo del botón "Portada"
/// del registro (blanco con borde cálido) o relleno azul marino.
class _PortadaPillButton extends StatelessWidget {
  const _PortadaPillButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool filled;
  final bool compact;

  static const Color _navy = Color(0xFF0E2646);

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : _navy;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: filled ? _navy : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled ? _navy : const Color(0xFFE2DAC8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 18 : 20, color: foreground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 13.5 : 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
