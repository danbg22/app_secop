import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_gate.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  static const _navy = Color(0xFF0B2136);
  static const _cream = Color(0xFFFFF8E7);
  static const _gold = Color(0xFFFFD54F);

  static const _navigationItems = [
    (label: 'Inicio', icon: Icons.home_outlined),
    (label: 'Contratos', icon: Icons.insert_drive_file_outlined),
    (label: 'Entidades', icon: Icons.account_balance_outlined),
    (label: 'Contratistas', icon: Icons.people_outline),
    (label: 'Estadísticas', icon: Icons.bar_chart),
    (label: 'Alertas', icon: Icons.notifications_none),
    (label: 'Favoritos', icon: Icons.bookmark_border),
  ];

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final usuarioActivo = prefs
        .getString('usuarioActivo')
        ?.trim()
        .toLowerCase();

    if (!isLoggedIn || usuarioActivo == null || usuarioActivo.isEmpty) return;

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  void _openApp() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _cream,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return Row(
                children: [
                  if (isWide) _buildSidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTopHeader(isWide: isWide),
                        Expanded(child: _buildMainContent(isWide: isWide)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 252,
      color: const Color(0xFFFFF4E0),
      padding: const EdgeInsets.fromLTRB(20, 28, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.gavel_rounded, color: _navy, size: 23),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Contrata Legal',
                  maxLines: 1,
                  style: TextStyle(
                    color: _navy,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.separated(
              itemCount: _navigationItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final selected = index == 0;
                return Material(
                  color: selected ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: selected ? null : _openApp,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon, color: _navy, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: _navy,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Contrata Legal © 2026.\nTodos los derechos reservados.',
            style: TextStyle(
              color: _navy.withValues(alpha: 0.62),
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader({required bool isWide}) {
    return Container(
      height: 78,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 30 : 18),
      decoration: BoxDecoration(
        color: _cream.withValues(alpha: 0.94),
        border: const Border(bottom: BorderSide(color: Color(0x1A0B2136))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: SizedBox(
                height: 44,
                child: TextField(
                  onSubmitted: (_) => _openApp(),
                  decoration: InputDecoration(
                    hintText: 'Buscar contratos, entidades, contratistas...',
                    hintStyle: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF607586),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.82),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: _navy.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: _openApp,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, color: _navy, size: 23),
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE45757),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          InkWell(
            onTap: _openApp,
            borderRadius: BorderRadius.circular(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: _gold,
                  child: Text(
                    'DB',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isWide) ...[
                  const SizedBox(width: 10),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daniel Bolaño',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Persona',
                        style: TextStyle(
                          color: Color(0xFF607586),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 7),
                  const Icon(Icons.keyboard_arrow_down, color: _navy, size: 18),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent({required bool isWide}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(),
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 54 : 22,
                isWide ? 58 : 35,
                isWide ? 54 : 22,
                36,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (isWide ? 94 : 70),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroTexts(isWide: isWide),
                    SizedBox(height: isWide ? 48 : 30),
                    _buildActionCards(isWide: isWide),
                    if (!isWide) ...[
                      const SizedBox(height: 28),
                      Center(
                        child: ElevatedButton(
                          onPressed: _openApp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Ingresar'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _cream),
        Image.asset(
          'assets/images/fondo_valledupar.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF8E7), Color(0xFFE7EEF1)],
              ),
            ),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: ColoredBox(color: _cream.withValues(alpha: 0.28)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xE6FFF8E7), Color(0xBFFFF8E7), Color(0x40FFF8E7)],
              stops: [0, 0.58, 1],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroTexts({required bool isWide}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 690),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 23),
            Text(
              'Contrata Legal',
              style: TextStyle(
                color: _navy,
                fontSize: isWide ? 48 : 36,
                height: 1.08,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Explora la contratación pública de forma clara,\n'
              'accesible y transparente.',
              style: TextStyle(
                color: const Color(0xFF33495B),
                fontSize: isWide ? 18 : 15,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCards({required bool isWide}) {
    const cards = [
      (
        title: 'Contratos',
        description: 'Consulta todos los contratos de la entidad o filtra por criterios específicos.',
        icon: Icons.insert_drive_file,
        iconColor: Color(0xFFC99700),
        iconBackground: Color(0xFFFFF1C2),
        waveColor: Color(0x44FFD54F),
      ),
      (
        title: 'Entidades',
        description:
            'Explora las entidades contratantes y su gestión contractual.',
        icon: Icons.account_balance,
        iconColor: Color(0xFF2878B5),
        iconBackground: Color(0xFFE3F2FD),
        waveColor: Color(0x443B9BD8),
      ),
      (
        title: 'Contratistas',
        description:
            'Conoce el historial de contratistas y proveedores del Estado.',
        icon: Icons.people,
        iconColor: Color(0xFF388E3C),
        iconBackground: Color(0xFFE8F5E9),
        waveColor: Color(0x4438A169),
      ),
    ];

    if (!isWide) {
      return Column(
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            if (index > 0) const SizedBox(height: 15),
            _buildActionCard(cards[index], height: 220),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          if (index > 0) const SizedBox(width: 19),
          Expanded(child: _buildActionCard(cards[index], height: 270)),
        ],
      ],
    );
  }

  Widget _buildActionCard(
    ({
      String title,
      String description,
      IconData icon,
      Color iconColor,
      Color iconBackground,
      Color waveColor,
    })
    card, {
    required double height,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openApp,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.1),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: -12,
                  right: -12,
                  bottom: -30,
                  child: ClipPath(
                    clipper: _CardWaveClipper(),
                    child: Container(height: 86, color: card.waveColor),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: card.iconBackground,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(card.icon, color: card.iconColor, size: 28),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        card.title,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text(
                          card.description,
                          style: TextStyle(
                            color: const Color(0xFF33495B)
                                .withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _navy.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: _navy,
                            size: 25,
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
}

class _CardWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height * 0.32)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.04,
        size.width * 0.5,
        size.height * 0.34,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.65,
        size.width,
        size.height * 0.24,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
