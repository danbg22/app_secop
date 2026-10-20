import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  static const _azulInstitucional = Color(0xFF17365D);
  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _passwordRegex = RegExp(r'^(?=.*[A-Z])(?=.*[!@#$&*~]).{8,}$');

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : _azulInstitucional,
        ),
      );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage(
        'Revisa los campos: verifica el correo y la contraseña.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.signUp(
        {
          'nombres': _nombresController.text.trim(),
          'apellidos': _apellidosController.text.trim(),
          'email': _emailController.text.trim(),
          'pais': _pais,
          'telefono': _telefonoController.text.trim(),
          'documento': _documentoController.text.trim(),
        },
        _passwordController.text,
      );

      if (!mounted) return;
      _showMessage('Registro completado. Revisa tu correo para verificarlo.');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) _showMessage('No fue posible completar el registro: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: _azulInstitucional,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                elevation: 3,
                shadowColor: _azulInstitucional.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Únete a Contrata Legal',
                          style: TextStyle(
                            color: _azulInstitucional,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Completa tus datos para crear una cuenta.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 20),
                        _textField(
                          controller: _nombresController,
                          label: 'Nombres',
                          icon: Icons.person_outline,
                          validator: _requiredValidator,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _apellidosController,
                          label: 'Apellidos',
                          icon: Icons.person_outline,
                          validator: _requiredValidator,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _emailController,
                          label: 'Correo electrónico',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty || !_emailRegex.hasMatch(email)) {
                              return 'Ingresa un correo electrónico válido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _pais,
                          decoration: _decoration(
                            label: 'País de residencia',
                            icon: Icons.public,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Colombia',
                              child: Text('Colombia'),
                            ),
                            DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  if (value != null) setState(() => _pais = value);
                                },
                          validator: (value) =>
                              value == null ? 'Selecciona un país.' : null,
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _telefonoController,
                          label: 'Número de teléfono (opcional)',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _documentoController,
                          label: 'Número de documento / cédula (opcional)',
                          icon: Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _passwordController,
                          label: 'Contraseña',
                          icon: Icons.lock_outline,
                          obscureText: !_passwordVisible,
                          validator: (value) {
                            final password = value ?? '';
                            if (!_passwordRegex.hasMatch(password)) {
                              return 'Mínimo 8 caracteres, una mayúscula y un carácter especial (!@#\$&*~).';
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
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _textField(
                          controller: _confirmPasswordController,
                          label: 'Confirmar contraseña',
                          icon: Icons.lock_outline,
                          obscureText: !_passwordVisible,
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Las contraseñas no coinciden.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF1F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.mark_email_read_outlined,
                                color: _azulInstitucional,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Se enviará un correo de verificación a esta dirección.',
                                  style: TextStyle(color: _azulInstitucional),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
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
                                    'Crear cuenta',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
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

  String? _requiredValidator(String? value) {
    return (value?.trim().isEmpty ?? true) ? 'Este campo es obligatorio.' : null;
  }

  TextFormField _textField({
    required TextEditingController controller,
    required String label,
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
      decoration: _decoration(label: label, icon: icon).copyWith(
        suffixIcon: suffixIcon,
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _azulInstitucional),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _azulInstitucional, width: 1.5),
      ),
    );
  }
}
