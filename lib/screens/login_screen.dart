import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/security_service.dart';
import 'escoger_rol_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Paleta compartida con el flujo de registro (EscogerRolScreen).
  static const _navy = Color(0xFF0E2646);
  static const _subtitleBlue = Color(0xFF364F6B);
  static const _royalBlue = Color(0xFF0D5BD9);
  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : _navy,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _navigateToPortada() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/portada');
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Ingresa un correo válido y tu contraseña.', isError: true);
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithEmail(email, password);
      _passwordController.clear();
      if (!mounted) return;

      final displayName = AuthService.getActiveUserDisplayName();
      _showMessage('Bienvenido(a), $displayName');
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (error) {
      if (mounted) {
        final msg = SecurityService.sanitizeErrorMessage(
          error.toString().replaceFirst('Exception: ', ''),
        );
        _showMessage(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithProvider({
    required String provider,
    required Future<void> Function() signIn,
  }) async {
    setState(() => _isLoading = true);
    try {
      await signIn();
      if (!mounted) return;

      final displayName = AuthService.getActiveUserDisplayName();
      _showMessage('Bienvenido(a), $displayName');
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (error) {
      if (mounted) {
        final msg = SecurityService.sanitizeErrorMessage(
          error.toString().replaceFirst('Exception: ', ''),
        );
        _showMessage('Error con $provider: $msg', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final correoIngresado = _emailController.text.trim().toLowerCase();
    if (correoIngresado.isEmpty || !_emailRegex.hasMatch(correoIngresado)) {
      _showMessage(
        'Ingresa tu correo electrónico arriba para recuperar tu contraseña.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.resetPassword(correoIngresado);
      if (mounted) {
        _showMessage(
          'Si el correo $correoIngresado está registrado, recibirás un enlace seguro para recuperar tu contraseña.',
        );
      }
    } catch (error) {
      if (mounted) {
        final msg = SecurityService.sanitizeErrorMessage(
          error.toString().replaceFirst('Exception: ', ''),
          fallback: 'No fue posible procesar la solicitud de recuperación.',
        );
        _showMessage(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingUnifiedBackground.bgCream,
      body: OnboardingUnifiedBackground(
        showScenicPhoto: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
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
                        OnboardingUnifiedTopBar(
                          currentStep: 0,
                          totalSteps: 0,
                          onBack: _navigateToPortada,
                          backLabel: 'Portada',
                          showBrandLogo: true,
                        ),
                        SizedBox(height: isMobile ? 22 : 36),
                        Text(
                          'Inicia sesión para continuar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _navy,
                            fontSize: isMobile ? 26 : (isTablet ? 34 : 40),
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Accede a tus consultas, favoritos y herramientas de contratación.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _subtitleBlue,
                            fontSize: isMobile ? 13.8 : 16,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: isMobile ? 22 : 30),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: _buildFormCard(isMobile),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            const Text(
                              '¿No tienes cuenta?',
                              style: TextStyle(
                                color: _subtitleBlue,
                                fontSize: 13.8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pushNamed(
                                      context,
                                      '/registro',
                                    ),
                              style: TextButton.styleFrom(
                                foregroundColor: _navy,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              child: const Text(
                                'Regístrate aquí →',
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
    );
  }

  /// Tarjeta del formulario con el estilo de las tarjetas del registro.
  Widget _buildFormCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6ECF5), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 24 : 30,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Correo electrónico
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(fontSize: 14.5, color: Color(0xFF1E293B)),
              decoration: _inputDecoration(
                hint: 'Correo electrónico',
                icon: Icons.mail_outline_rounded,
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !_emailRegex.hasMatch(email)) {
                  return 'Ingresa un correo electrónico válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Contraseña
            TextFormField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _signIn(),
              style: const TextStyle(fontSize: 14.5, color: Color(0xFF1E293B)),
              decoration: _inputDecoration(
                hint: 'Contraseña',
                icon: Icons.lock_outline_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: _passwordVisible
                      ? 'Ocultar contraseña'
                      : 'Mostrar contraseña',
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF334155),
                    size: 20,
                  ),
                ),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Ingresa tu contraseña.' : null,
            ),
            const SizedBox(height: 8),

            // Olvidé mi contraseña
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: TextButton.styleFrom(
                  foregroundColor: _royalBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Olvidé mi contraseña',
                  style: TextStyle(
                    color: _royalBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botón principal tipo píldora, como "Seleccionar" en el registro
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 15.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 19,
                            color: Colors.white,
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 22),

            // Divider: O continuar con
            Row(
              children: [
                const Expanded(
                  child: Divider(color: Color(0xFFE6ECF5), thickness: 1),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'O continuar con',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(color: Color(0xFFE6ECF5), thickness: 1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Google button
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => _signInWithProvider(
                        provider: 'Google',
                        signIn: AuthService.signInWithGoogle,
                      ),
                style: _socialButtonStyle(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGoogleIcon(),
                    const SizedBox(width: 12),
                    const Text(
                      'Iniciar sesión con Google',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Apple button
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => _signInWithProvider(
                        provider: 'Apple',
                        signIn: AuthService.signInWithApple,
                      ),
                style: _socialButtonStyle(),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apple, size: 22, color: Colors.black),
                    SizedBox(width: 10),
                    Text(
                      'Iniciar sesión con Apple',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Icon(icon, color: _navy, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navy, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
    );
  }

  ButtonStyle _socialButtonStyle() {
    return OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: _navy,
      side: const BorderSide(color: Color(0xFFD8DEE8), width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;
    final strokeWidth = size.width * 0.21;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Red top arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.35, 1.55, false, paint);

    // Yellow left arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.35, 1.58, false, paint);

    // Green bottom arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.75, 1.60, false, paint);

    // Blue right arc + horizontal bar
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.35, 1.10, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - strokeWidth * 0.48,
        radius + strokeWidth * 0.45,
        strokeWidth * 0.95,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
