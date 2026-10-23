import 'package:flutter/material.dart';

import '../data/auth_bg_asset_data.dart';
import '../services/auth_service.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  static const _navyDark = Color(0xFF0B224C);
  static const _royalBlue = Color(0xFF0D5BD9);
  static const _goldAccent = Color(0xFFF5C230);
  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _formKey = GlobalKey<FormState>();
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _documentoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _pais = 'Colombia';
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _documentoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : _navyDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _navigateToPortada() {
    Navigator.of(context).pushNamedAndRemoveUntil('/portada', (route) => false);
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacementNamed('/auth');
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage(
        'Por favor revisa los campos resaltados.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final nombres = _nombresController.text.trim();
      final apellidos = _apellidosController.text.trim();
      final email = _emailController.text.trim().toLowerCase();

      await AuthService.signUp(
        {
          'nombres': nombres,
          'apellidos': apellidos,
          'email': email,
          'pais': _pais,
          'telefono': _telefonoController.text.trim(),
          'documento': _documentoController.text.trim(),
        },
        _passwordController.text,
      );

      if (!mounted) return;
      final displayName = AuthService.getActiveUserDisplayName();
      _showMessage('¡Cuenta creada exitosamente! Bienvenido(a), $displayName.');
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (error) {
      if (mounted) {
        final msg = error.toString().replaceFirst('Exception: ', '');
        _showMessage(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 960;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF6),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Scenic Colombia city & mountain background
          Image.memory(
            AuthBgAssetData.bytes,
            fit: BoxFit.cover,
            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
            gaplessPlayback: true,
          ),

          // Deep navy / blue bottom-left wave overlay matching the Registro screenshot
          if (isDesktop)
            Positioned(
              left: 0,
              bottom: 0,
              width: size.width * 0.56,
              height: size.height * 0.32,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BottomLeftNavyWavePainter(),
                ),
              ),
            ),

          // Soft white scrim on mobile/tablet for readability
          if (!isDesktop)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.78),
                    Colors.white.withValues(alpha: 0.52),
                    Colors.white.withValues(alpha: 0.80),
                  ],
                ),
              ),
            ),

          // Left hero branding column on desktop ("Únete a Contrata Legal")
          if (isDesktop)
            Positioned(
              top: 38,
              left: 64,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _navigateToPortada,
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 92,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 34,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: _goldAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 22),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          letterSpacing: -0.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'Únete a\n',
                            style: TextStyle(color: _navyDark),
                          ),
                          TextSpan(
                            text: 'Contrata Legal',
                            style: TextStyle(color: Color(0xFF0A499B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Información pública más clara,\naccesible y transparente.',
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        height: 1.42,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right-aligned floating registration card on desktop, centered on mobile
          SafeArea(
            child: Align(
              alignment: isDesktop ? Alignment.centerRight : Alignment.center,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: isMobile ? 14 : 28,
                  right: isDesktop
                      ? (size.width * 0.055).clamp(36.0, 96.0)
                      : (isMobile ? 14 : 28),
                  top: isMobile ? 14 : 20,
                  bottom: isMobile ? 14 : 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 490),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: const Color(0xFFEDEFF3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _navyDark.withValues(alpha: 0.09),
                          blurRadius: 36,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 34,
                      vertical: isMobile ? 20 : 26,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Back to Portada link
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: _navigateToPortada,
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_back_rounded,
                                      size: 17,
                                      color: _navyDark,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Volver a la portada',
                                      style: TextStyle(
                                        color: _navyDark,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Title & Subtitle inside card
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isDesktop) ...[
                                  Center(
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      height: 62,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                const Text(
                                  'Crear cuenta',
                                  style: TextStyle(
                                    color: _navyDark,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Completa tus datos para unirte a la plataforma.',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 1. Nombres
                          _textField(
                            controller: _nombresController,
                            hint: 'Nombres',
                            icon: Icons.person_outline_rounded,
                            validator: _requiredValidator,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 10),

                          // 2. Apellidos
                          _textField(
                            controller: _apellidosController,
                            hint: 'Apellidos',
                            icon: Icons.person_outline_rounded,
                            validator: _requiredValidator,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 10),

                          // 3. Correo electrónico
                          _textField(
                            controller: _emailController,
                            hint: 'Correo electrónico',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty ||
                                  !_emailRegex.hasMatch(email)) {
                                return 'Ingresa un correo electrónico válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // 4. País de residencia
                          DropdownButtonFormField<String>(
                            initialValue: _pais,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF475569),
                            ),
                            decoration: _decoration(
                              hint: 'País de residencia',
                              labelText: 'País de residencia',
                              icon: Icons.public_rounded,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Colombia',
                                child: Text('Colombia'),
                              ),
                              DropdownMenuItem(
                                value: 'México',
                                child: Text('México'),
                              ),
                              DropdownMenuItem(
                                value: 'España',
                                child: Text('España'),
                              ),
                              DropdownMenuItem(
                                value: 'Estados Unidos',
                                child: Text('Estados Unidos'),
                              ),
                              DropdownMenuItem(
                                value: 'Otro',
                                child: Text('Otro'),
                              ),
                            ],
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _pais = value);
                                    }
                                  },
                            validator: (value) =>
                                value == null ? 'Selecciona un país.' : null,
                          ),
                          const SizedBox(height: 10),

                          // 5. Número de teléfono (opcional)
                          _textField(
                            controller: _telefonoController,
                            hint: 'Número de teléfono (opcional)',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 10),

                          // 6. Número de documento / cédula (opcional)
                          _textField(
                            controller: _documentoController,
                            hint: 'Número de documento / cédula (opcional)',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 10),

                          // 7. Contraseña
                          _textField(
                            controller: _passwordController,
                            hint: 'Contraseña',
                            icon: Icons.lock_outline_rounded,
                            obscureText: !_passwordVisible,
                            validator: (value) {
                              final password = value ?? '';
                              if (password.length < 6) {
                                return 'La contraseña debe tener al menos 6 caracteres.';
                              }
                              return null;
                            },
                            suffixIcon: IconButton(
                              tooltip: _passwordVisible
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF334155),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 8. Confirmar contraseña
                          _textField(
                            controller: _confirmPasswordController,
                            hint: 'Confirmar contraseña',
                            icon: Icons.lock_outline_rounded,
                            obscureText: !_confirmPasswordVisible,
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Confirma tu contraseña.';
                              }
                              if (value != _passwordController.text) {
                                return 'Las contraseñas no coinciden.';
                              }
                              return null;
                            },
                            suffixIcon: IconButton(
                              tooltip: _confirmPasswordVisible
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              onPressed: () => setState(
                                () => _confirmPasswordVisible =
                                    !_confirmPasswordVisible,
                              ),
                              icon: Icon(
                                _confirmPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF334155),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Info banner: Se enviará un correo de verificación a esta dirección.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9F2FC),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.mail_outline_rounded,
                                  color: Color(0xFF1D4ED8),
                                  size: 19,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Se enviará un correo de verificación a esta dirección.',
                                    style: TextStyle(
                                      color: Color(0xFF334155),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Primary dark navy button: Crear cuenta ->
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _navyDark,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Crear cuenta',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Bottom link: ¿Ya tienes cuenta? Inicia sesión
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '¿Ya tienes cuenta? ',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              InkWell(
                                onTap: _isLoading ? null : _navigateToLogin,
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    'Inicia sesión',
                                    style: TextStyle(
                                      color: _royalBlue,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _royalBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _requiredValidator(String? value) {
    return (value?.trim().isEmpty ?? true)
        ? 'Este campo es obligatorio.'
        : null;
  }

  TextFormField _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      enabled: !_isLoading,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF1E293B),
      ),
      decoration: _decoration(hint: hint, icon: icon).copyWith(
        suffixIcon: suffixIcon,
      ),
    );
  }

  InputDecoration _decoration({
    required String hint,
    String? labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      labelText: labelText,
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 13,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 13.8,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      prefixIcon: Icon(icon, color: _navyDark, size: 19),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: _navyDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }
}

class _BottomLeftNavyWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final darkNavyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF061B40),
          Color(0xFF0C3474),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(0, size.height * 0.25)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.18,
        size.width * 0.62,
        size.height * 0.92,
      )
      ..lineTo(size.width * 0.68, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, darkNavyPaint);

    // Subtle white inner curve highlight matching the screenshot
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final highlightPath = Path()
      ..moveTo(0, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.30,
        size.width * 0.60,
        size.height,
      );
    canvas.drawPath(highlightPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
