import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _azulInstitucional = Color(0xFF17365D);
  static const _correosAdministradores = {
    'ivanbolano19@gmail.com',
    'danielbg2231@gmail.com',
  };
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : _azulInstitucional,
        ),
      );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Ingresa un correo válido y tu contraseña.', isError: true);
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    if (!_correosAdministradores.contains(email)) {
      _showMessage(
        'Acceso denegado. Este correo no está autorizado.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.signInWithEmail(email, _passwordController.text);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('usuarioActivo', email);
      await prefs.setString('userEmail', email);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('No fue posible iniciar sesión: $error', isError: true);
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

      final email = FirebaseAuth.instance.currentUser?.email
          ?.trim()
          .toLowerCase();
      if (email == null || !_correosAdministradores.contains(email)) {
        await FirebaseAuth.instance.signOut();
        _showMessage(
          'Acceso denegado. Este correo no está autorizado.',
          isError: true,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('usuarioActivo', email);
      await prefs.setString('userEmail', email);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) _showMessage('Error con $provider: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final correoIngresado = _emailController.text.trim();
    if (correoIngresado.isEmpty || !_emailRegex.hasMatch(correoIngresado)) {
      _showMessage(
        'Ingresa un correo válido para recuperar tu contraseña.',
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
          'Se ha enviado un enlace para recuperar la contraseña a tu correo.',
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
    final canGoBack = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 3,
                shadowColor: _azulInstitucional.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (canGoBack)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                                color: _azulInstitucional,
                              ),
                              label: const Text(
                                'Volver a la portada',
                                style: TextStyle(
                                  color: _azulInstitucional,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        const Icon(
                          Icons.gavel_rounded,
                          size: 52,
                          color: _azulInstitucional,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Contrata Legal',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _azulInstitucional,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Inicia sesión para continuar',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: _inputDecoration(
                            label: 'Correo electrónico',
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty || !_emailRegex.hasMatch(email)) {
                              return 'Ingresa un correo electrónico válido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _signIn(),
                          decoration:
                              _inputDecoration(
                                label: 'Contraseña',
                                icon: Icons.lock_outline,
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
                                  ),
                                ),
                              ),
                          validator: (value) => (value ?? '').isEmpty
                              ? 'Ingresa tu contraseña.'
                              : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            child: const Text('Olvidé mi contraseña'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _azulInstitucional,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Iniciar Sesión',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'O continuar con',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _signInWithProvider(
                                  provider: 'Google',
                                  signIn: AuthService.signInWithGoogle,
                                ),
                          icon: const Icon(Icons.g_mobiledata, size: 26),
                          label: const Text('Iniciar sesión con Google'),
                          style: _socialButtonStyle(),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _signInWithProvider(
                                  provider: 'Apple',
                                  signIn: AuthService.signInWithApple,
                                ),
                          icon: const Icon(Icons.apple, size: 22),
                          label: const Text('Iniciar sesión con Apple'),
                          style: _socialButtonStyle(),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('¿No tienes cuenta?'),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pushNamed(
                                      context,
                                      '/registro',
                                    ),
                              child: const Text(
                                'Regístrate',
                                style: TextStyle(
                                  color: _azulInstitucional,
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _azulInstitucional),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _azulInstitucional, width: 1.5),
      ),
    );
  }

  ButtonStyle _socialButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF243447),
      minimumSize: const Size.fromHeight(48),
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
