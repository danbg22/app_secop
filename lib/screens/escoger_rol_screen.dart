import 'package:flutter/material.dart';

import '../data/roles_visual_assets_data.dart';
import '../services/payment_service.dart';
import 'login_screen.dart';
import 'pasarela_pago_wompi_screen.dart';
import 'registro_screen.dart';

/// Fondo escénico unificado (Catedral colonial, montañas andinas, bandera de
/// Colombia y hojas botánicas) compartido por los 3 pasos del flujo:
/// Paso 1 (Escoger Rol) -> Paso 2 (Registro) -> Paso 3 (Pago Wompi).
class OnboardingUnifiedBackground extends StatelessWidget {
  const OnboardingUnifiedBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  static const Color bgCream = Color(0xFFFEF9EB);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: bgCream),

        // Ilustración en alta definición de la catedral colonial y montañas a la derecha
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.58,
            heightFactor: 1.0,
            child: Image.asset(
              'assets/images/fondo_valledupar.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0.55, -0.15),
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
          ),
        ),

        // Difuminado cálido de izquierda a derecha idéntico a la imagen de referencia
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFFEF9EB),
                Color(0xFFFEF9EB),
                Color(0xF5FEF9EB),
                Color(0xB8FEF9EB),
                Color(0x28FEF9EB),
                Color(0x00FEF9EB),
              ],
              stops: [0.0, 0.42, 0.56, 0.72, 0.88, 1.0],
            ),
          ),
        ),

        // Suavizado superior e inferior
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xAAFEF9EB),
                Color(0x00FEF9EB),
                Color(0x99FEF9EB),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // Hojas botánicas suaves en la esquina inferior izquierda
        const Positioned(
          left: 0,
          bottom: 0,
          width: 210,
          height: 150,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _BotanicalLeavesCornerPainter(),
            ),
          ),
        ),

        // Cinta ondulada con la bandera de Colombia en la esquina inferior derecha
        const Positioned(
          right: 0,
          bottom: 0,
          width: 380,
          height: 210,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ColombiaFlagCornerPainter(),
            ),
          ),
        ),

        // Contenido interactivo de la pantalla
        child,
      ],
    );
  }
}

/// Barra superior unificada con botón Volver, Logo Contrata Legal e indicador de pasos
/// (Paso 1 de 3, Paso 2 de 3, Paso 3 de 3) con el diseño exacto de puntos y barra dorada.
class OnboardingUnifiedTopBar extends StatelessWidget {
  const OnboardingUnifiedTopBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.onBack,
    this.backLabel = 'Volver',
  });

  final int currentStep;
  final int totalSteps;
  final VoidCallback onBack;
  final String backLabel;

  static const Color _navy = Color(0xFF0E2646);
  static const Color _gold = Color(0xFFF5B82E);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 680;

    final stepIndicator = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= totalSteps; i++) ...[
          if (i == currentStep) ...[
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 24,
              height: 5,
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ] else if (i < currentStep) ...[
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
            ),
          ] else ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFD6DCE5),
                shape: BoxShape.circle,
              ),
            ),
          ],
          const SizedBox(width: 6),
        ],
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFDFE4EC),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Paso $currentStep de $totalSteps',
          style: const TextStyle(
            color: _navy,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    final backBtn = InkWell(
      onTap: onBack,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6DFCF)),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_rounded, size: 17, color: _navy),
            const SizedBox(width: 6),
            Text(
              backLabel,
              style: const TextStyle(
                color: _navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    if (isMobile) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          backBtn,
          Flexible(child: stepIndicator),
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              backBtn,
              const SizedBox(width: 14),
              Image.asset(
                'assets/images/logo.png',
                height: 42,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        stepIndicator,
      ],
    );
  }
}

class EscogerRolScreen extends StatefulWidget {
  const EscogerRolScreen({
    super.key,
    this.modoAcumularRol = false,
    this.rolActualSeleccionadoId = 'persona',
  });

  /// Si es `true`, el usuario ya tiene cuenta y está explorando roles para
  /// cambiar o acumular un nuevo rol adicional sobre su cuenta existente.
  final bool modoAcumularRol;
  final String rolActualSeleccionadoId;

  @override
  State<EscogerRolScreen> createState() => _EscogerRolScreenState();
}

class _EscogerRolScreenState extends State<EscogerRolScreen> {
  static const Color _navy = Color(0xFF0E2646);
  static const Color _subtitleBlue = Color(0xFF364F6B);
  static const Color _gold = Color(0xFFF5C032);

  String? _hoveredRoleId;

  void _seleccionarRol(RolPaqueteConfig rol) {
    if (!rol.habilitadoParaRegistro) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _navy,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: _gold,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Por ahora solo está habilitado el rol "Persona" (${rol.precioFormateadoCop} para "${rol.nombre}" estará disponible próximamente).',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      return;
    }

    if (widget.modoAcumularRol) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PasarelaPagoWompiScreen(
            rolId: rol.id,
            esFlujoRegistro: false,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegistroScreen(rolSeleccionadoId: rol.id),
      ),
    );
  }

  void _irALogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _regresar() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/portada');
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = PaymentService.obtenerCatalogoRoles();

    return Scaffold(
      backgroundColor: OnboardingUnifiedBackground.bgCream,
      body: OnboardingUnifiedBackground(
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        OnboardingUnifiedTopBar(
                          currentStep: 1,
                          totalSteps: widget.modoAcumularRol ? 2 : 3,
                          onBack: _regresar,
                          backLabel: widget.modoAcumularRol
                              ? 'Volver a la app'
                              : 'Portada',
                        ),
                        SizedBox(height: isMobile ? 16 : 22),
                        Text(
                          'Elige el rol con el que\nquieres continuar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _navy,
                            fontSize: isMobile ? 26 : (isTablet ? 34 : 42),
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Personaliza tu experiencia según tus necesidades.\nPuedes cambiar de rol en cualquier momento.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _subtitleBlue,
                            fontSize: isMobile ? 13.8 : 16,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: isMobile ? 22 : 32),

                        // 4 Tarjetas de Rol idénticas a la foto con su ilustración original y su precio
                        if (isDesktop)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (int i = 0; i < roles.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 18),
                                  Expanded(
                                    child: _buildRoleCard(
                                      rol: roles[i],
                                      isMobile: false,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else if (isTablet)
                          Column(
                            children: [
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildRoleCard(
                                        rol: roles[0],
                                        isMobile: false,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildRoleCard(
                                        rol: roles[1],
                                        isMobile: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildRoleCard(
                                        rol: roles[2],
                                        isMobile: false,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildRoleCard(
                                        rol: roles[3],
                                        isMobile: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              for (int i = 0; i < roles.length; i++) ...[
                                if (i > 0) const SizedBox(height: 16),
                                _buildRoleCard(
                                  rol: roles[i],
                                  isMobile: true,
                                ),
                              ],
                            ],
                          ),

                        const SizedBox(height: 24),
                        if (!widget.modoAcumularRol)
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              const Text(
                                '¿Ya tienes una cuenta registrada?',
                                style: TextStyle(
                                  color: _subtitleBlue,
                                  fontSize: 13.8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextButton(
                                onPressed: _irALogin,
                                style: TextButton.styleFrom(
                                  foregroundColor: _navy,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                child: const Text(
                                  'Inicia sesión aquí →',
                                  style: TextStyle(
                                    color: _navy,
                                    fontSize: 13.8,
                                    fontWeight: FontWeight.w800,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _cardBackgroundColorForRole(String rolId) {
    switch (rolId) {
      case 'persona':
        return const Color(0xFFFEFBF0);
      case 'equipo_juridico':
        return const Color(0xFFF8FAFC);
      case 'empresa_licitante':
        return const Color(0xFFF9FCFA);
      case 'veeduria_ciudadana':
        return const Color(0xFFFCFBFD);
      default:
        return Colors.white;
    }
  }

  Widget _buildRoleCard({
    required RolPaqueteConfig rol,
    required bool isMobile,
  }) {
    final bool isPersona = rol.id == 'persona';
    final bool isHovered = _hoveredRoleId == rol.id;

    final Color cardBg = _cardBackgroundColorForRole(rol.id);
    final Color borderColor = isPersona
        ? const Color(0xFFF5C032)
        : (isHovered
              ? rol.colorPrimario.withValues(alpha: 0.55)
              : const Color(0xFFE6ECF5));

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRoleId = rol.id),
      onExit: (_) => setState(() => _hoveredRoleId = null),
      cursor: rol.habilitadoParaRegistro
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: () => _seleccionarRol(rol),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: borderColor,
              width: isPersona ? 2.2 : 1.3,
            ),
            boxShadow: [
              if (isPersona)
                BoxShadow(
                  color: const Color(0xFFF5B82E).withValues(alpha: 0.24),
                  blurRadius: 28,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                )
              else
                BoxShadow(
                  color: _navy.withValues(alpha: isHovered ? 0.09 : 0.05),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera con la ilustración original exacta de la foto (incluye el personaje y el ícono circular)
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: AspectRatio(
                  aspectRatio: 184 / 150,
                  child: Image.memory(
                    RolesVisualAssetsData.bytesForRole(rol.id),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Fila de Título + Etiqueta de Precio en COP
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        rol.id == 'equipo_juridico'
                            ? 'Equipo jurídico\nentidad'
                            : rol.nombre,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 20.5,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPersona
                            ? const Color(0xFFFFF0C2)
                            : rol.colorFondoIlustracion,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPersona
                              ? const Color(0xFFF5C032)
                              : rol.colorPrimario.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        rol.precioFormateadoCop,
                        style: TextStyle(
                          color: isPersona ? _navy : rol.colorPrimario,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Descripción del rol (con "Consulta" en negrita para Persona como en la foto)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: isPersona
                    ? RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: _subtitleBlue,
                            fontSize: 13.5,
                            height: 1.42,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: 'Consulta ',
                              style: TextStyle(
                                color: _navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'información de contratos, entidades, contratistas y más. Ideal para usuarios individuales.',
                            ),
                          ],
                        ),
                      )
                    : Text(
                        rol.descripcionCorta,
                        style: const TextStyle(
                          color: _subtitleBlue,
                          fontSize: 13.4,
                          height: 1.42,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),

              if (!isMobile) const Spacer() else const SizedBox(height: 18),
              const SizedBox(height: 16),

              // Botón Seleccionar ->
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: isPersona
                      ? ElevatedButton(
                          onPressed: () => _seleccionarRol(rol),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF8C63A),
                            foregroundColor: _navy,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Seleccionar',
                                style: TextStyle(
                                  color: _navy,
                                  fontSize: 14.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color: _navy,
                              ),
                            ],
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () => _seleccionarRol(rol),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _navy,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: rol.colorPrimario.withValues(alpha: 0.65),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Seleccionar',
                                style: TextStyle(
                                  color: _navy,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color: _navy,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColombiaFlagCornerPainter extends CustomPainter {
  const _ColombiaFlagCornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final yellowPath = Path()
      ..moveTo(w * 0.12, h)
      ..quadraticBezierTo(w * 0.52, h * 0.58, w, h * 0.34)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFF6C624));

    final bluePath = Path()
      ..moveTo(w * 0.28, h)
      ..quadraticBezierTo(w * 0.62, h * 0.70, w, h * 0.52)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF1D438A));

    final redPath = Path()
      ..moveTo(w * 0.42, h)
      ..quadraticBezierTo(w * 0.72, h * 0.80, w, h * 0.66)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFD32027));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BotanicalLeavesCornerPainter extends CustomPainter {
  const _BotanicalLeavesCornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final hillPaint = Paint()
      ..color = const Color(0xFFF7E8BD).withValues(alpha: 0.65);
    final hillPath = Path()
      ..moveTo(0, h * 0.32)
      ..quadraticBezierTo(w * 0.48, h * 0.36, w * 0.88, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hillPath, hillPaint);

    final leafPaint = Paint()
      ..color = const Color(0xFF848C54).withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    final leaf1 = Path()
      ..moveTo(0, h * 0.64)
      ..quadraticBezierTo(w * 0.18, h * 0.44, w * 0.28, h * 0.54)
      ..quadraticBezierTo(w * 0.16, h * 0.72, 0, h * 0.64)
      ..close();
    canvas.drawPath(leaf1, leafPaint);

    final leaf2 = Path()
      ..moveTo(w * 0.05, h * 0.80)
      ..quadraticBezierTo(w * 0.24, h * 0.66, w * 0.36, h * 0.78)
      ..quadraticBezierTo(w * 0.18, h * 0.92, w * 0.05, h * 0.80)
      ..close();
    canvas.drawPath(leaf2, leafPaint);

    final leaf3 = Path()
      ..moveTo(w * 0.14, h * 0.94)
      ..quadraticBezierTo(w * 0.30, h * 0.80, w * 0.44, h * 0.94)
      ..quadraticBezierTo(w * 0.28, h * 1.02, w * 0.14, h * 0.94)
      ..close();
    canvas.drawPath(leaf3, leafPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
