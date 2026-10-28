import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/auth_bg_asset_data.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _navyDark = Color(0xFF0B224C);
  static const _royalBlue = Color(0xFF0D5BD9);
  static const _goldAccent = Color(0xFFF5B800);
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
          backgroundColor: isError ? Colors.red.shade700 : _navyDark,
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
      if (!mounted) return;

      final displayName = AuthService.getActiveUserDisplayName();
      _showMessage('Bienvenido(a), $displayName');
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
        final msg = error.toString().replaceFirst('Exception: ', '');
        _showMessage('Error con $provider: $msg', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final correoIngresado = _emailController.text.trim();
    if (correoIngresado.isEmpty || !_emailRegex.hasMatch(correoIngresado)) {
      _showMessage(
        'Ingresa tu correo electrónico arriba para recuperar tu contraseña.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: correoIngresado,
      );
      if (mounted) {
        _showMessage(
          'Se ha enviado un enlace para recuperar la contraseña a $correoIngresado.',
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showMessage(
          error.message ?? 'No fue posible enviar el correo de recuperación.',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          'No fue posible recuperar la contraseña: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 900;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF6),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Scenic Colombia city & mountain background with golden/blue curves
          Image.memory(
            AuthBgAssetData.bytes,
            fit: BoxFit.cover,
            alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          ),

          // Subtle gradient overlay on smaller screens so the card & logo stay crisp
          if (!isDesktop)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.72),
                    Colors.white.withValues(alpha: 0.45),
                    Colors.white.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),

          // Top-left Contrata Legal brand logo (visible on desktop/tablet)
          if (!isMobile)
            Positioned(
              top: isDesktop ? 34 : 20,
              left: isDesktop ? 54 : 24,
              child: InkWell(
                onTap: _navigateToPortada,
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: isDesktop ? 88 : 68,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),

          // Main content area: right-aligned floating card on desktop, centered on mobile
          SafeArea(
            child: Align(
              alignment: isDesktop ? Alignment.centerRight : Alignment.center,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: isMobile ? 16 : 32,
                  right: isDesktop
                      ? (size.width * 0.065).clamp(40.0, 110.0)
                      : (isMobile ? 16 : 32),
                  top: isMobile ? 16 : 28,
                  bottom: isMobile ? 16 : 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.97),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: const Color(0xFFEDEFF3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B224C).withValues(alpha: 0.08),
                          blurRadius: 36,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 22 : 36,
                      vertical: isMobile ? 24 : 32,
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
                                  vertical: 6,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_back_rounded,
                                      size: 18,
                                      color: _navyDark,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Volver a la portada',
                                      style: TextStyle(
                                        color: _navyDark,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Centered Contrata Legal logo inside the card
                          Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: isMobile ? 72 : 82,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Gold accent bar
                          Center(
                            child: Container(
                              width: 34,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: _goldAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Inicia sesión para continuar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Correo electrónico
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: Color(0xFF1E293B),
                            ),
                            decoration: _inputDecoration(
                              hint: 'Correo electrónico',
                              icon: Icons.mail_outline_rounded,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty ||
                                  !_emailRegex.hasMatch(email)) {
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
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: Color(0xFF1E293B),
                            ),
                            decoration: _inputDecoration(
                              hint: 'Contraseña',
                              icon: Icons.lock_outline_rounded,
                            ).copyWith(
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
                            validator: (value) => (value ?? '').isEmpty
                                ? 'Ingresa tu contraseña.'
                                : null,
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
                          const SizedBox(height: 14),

                          // Primary dark navy button: Iniciar sesión ->
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _navyDark,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
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
                                          'Iniciar sesión',
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
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
                          const SizedBox(height: 20),

                          // Divider: O continuar con
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                ),
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
                              Expanded(
                                child: Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Google button
                          SizedBox(
                            height: 46,
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
                                      color: Color(0xFF1E293B),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Apple button
                          SizedBox(
                            height: 46,
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
                                  Icon(
                                    Icons.apple,
                                    size: 22,
                                    color: Colors.black,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Iniciar sesión con Apple',
                                    style: TextStyle(
                                      color: Color(0xFF1E293B),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Bottom link: ¿No tienes cuenta? Regístrate
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '¿No tienes cuenta? ',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              InkWell(
                                onTap: _isLoading
                                    ? null
                                    : () => Navigator.pushNamed(
                                        context,
                                        '/registro',
                                      ),
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    'Regístrate',
                                    style: TextStyle(
                                      color: _royalBlue,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
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
      prefixIcon: Icon(icon, color: _navyDark, size: 20),
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
        borderSide: const BorderSide(color: _navyDark, width: 1.5),
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
      foregroundColor: const Color(0xFF1E293B),
      side: const BorderSide(color: Color(0xFFD8DEE8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
