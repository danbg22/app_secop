import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/roles_visual_assets_data.dart';
import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../services/payment_service.dart';
import '../services/security_service.dart';
import 'escoger_rol_screen.dart';
import 'pasarela_pago_wompi_screen.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({
    super.key,
    this.rolSeleccionadoId = 'persona',
  });

  final String rolSeleccionadoId;

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  static const _navyDark = Color(0xFF0E2646);
  static const _subtitleBlue = Color(0xFF364F6B);
  static const _royalBlue = Color(0xFF0D5BD9);
  static const _goldAccent = Color(0xFFF5C032);
  static const _tealCheck = Color(0xFF1E7868);
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

  /// Errores bloqueantes cuando el correo o la cédula ya están vinculados a otra cuenta.
  String? _errorEmailEnUso;
  String? _errorCedulaEnUso;

  /// Autorización expresa de tratamiento de datos (Ley 1581 de 2012). Obligatoria.
  bool _aceptaPolitica = false;
  bool _mostrarErrorPolitica = false;

  RolPaqueteConfig get _rolConfig =>
      PaymentService.obtenerConfiguracionRol(widget.rolSeleccionadoId);

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
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.verified_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? Colors.red.shade700 : _navyDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Future<void> _mostrarAlertaCredencialesEnUso({
    required bool emailEnUso,
    required bool documentoEnUso,
    required String email,
    required String documento,
  }) async {
    if (!mounted) return;
    final String titulo = (emailEnUso && documentoEnUso)
        ? 'Cédula y correo electrónico ya están en uso'
        : (documentoEnUso
              ? 'Número de cédula ya se encuentra en uso'
              : 'Correo electrónico ya se encuentra en uso');

    final String detalle = (emailEnUso && documentoEnUso)
        ? 'El número de cédula ($documento) y el correo electrónico ($email) ya están vinculados a una cuenta registrada.\n\nNo puedes avanzar al siguiente paso hasta que ingreses una cédula y un correo electrónico que no hayan sido usados.'
        : (documentoEnUso
              ? 'El número de cédula o documento ($documento) ya se encuentra vinculado a otra cuenta en la plataforma.\n\nPor favor cámbialo por un número de documento que no se haya usado para poder continuar.'
              : 'El correo electrónico ($email) ya se encuentra vinculado a otra cuenta en la plataforma.\n\nPor favor cámbialo por un correo electrónico diferente que no esté en uso para poder continuar.');

    _showMessage(titulo, isError: true);

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _navyDark,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  detalle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navyDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: const Text(
                      'Entendido, cambiar datos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _cambiarRol() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EscogerRolScreen(
            rolActualSeleccionadoId: widget.rolSeleccionadoId,
          ),
        ),
      );
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacementNamed('/auth');
  }

  Future<void> _register() async {
    setState(() {
      _errorEmailEnUso = null;
      _errorCedulaEnUso = null;
    });

    final camposValidos = _formKey.currentState!.validate();
    if (!_aceptaPolitica) {
      setState(() => _mostrarErrorPolitica = true);
    }
    if (!camposValidos) {
      _showMessage(
        'Por favor completa todos los campos obligatorios (incluyendo correo y cédula).',
        isError: true,
      );
      return;
    }
    if (!_aceptaPolitica) {
      _showMessage(
        'Debes aceptar la Política de Privacidad y Tratamiento de Datos Personales para continuar.',
        isError: true,
      );
      return;
    }

    final nombres = _nombresController.text.trim();
    final apellidos = _apellidosController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final documento = _documentoController.text.trim();
    final rolConfig = _rolConfig;

    setState(() => _isLoading = true);
    try {
      // 1. Verificar disponibilidad de cédula y correo antes de permitir avanzar
      final duplicados = await AuthService.checkDuplicateCredentials(
        email: email,
        documento: documento,
      );
      if (duplicados.emailEnUso || duplicados.documentoEnUso) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          if (duplicados.emailEnUso) {
            _errorEmailEnUso =
                'Este correo electrónico ya se encuentra en uso. Cámbialo por otro.';
          }
          if (duplicados.documentoEnUso) {
            _errorCedulaEnUso =
                'Esta cédula ya se encuentra en uso. Cámbiala por otra.';
          }
        });
        _formKey.currentState!.validate();
        await _mostrarAlertaCredencialesEnUso(
          emailEnUso: duplicados.emailEnUso,
          documentoEnUso: duplicados.documentoEnUso,
          email: email,
          documento: documento,
        );
        return;
      }

      // 2. Crear cuenta en AuthService (también valida unicidad contra Firebase Auth)
      await AuthService.signUp(
        {
          'nombres': nombres,
          'apellidos': apellidos,
          'email': email,
          'pais': _pais,
          'telefono': _telefonoController.text.trim(),
          'documento': documento,
          'rol': rolConfig.id,
          'rolPrincipal': rolConfig.id,
        },
        _passwordController.text,
        aceptaTratamientoDatos: _aceptaPolitica,
      );
      _passwordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;
      _showMessage(
        'Datos validados correctamente. Continúa con la activación de tu rol ${rolConfig.nombre}.',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PasarelaPagoWompiScreen(
            rolId: rolConfig.id,
            esFlujoRegistro: true,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Exception: ', '');
      final lowerMsg = msg.toLowerCase();
      final bool esCorreoDuplicado =
          lowerMsg.contains('correo') && lowerMsg.contains('en uso');
      final bool esCedulaDuplicada =
          (lowerMsg.contains('cédula') || lowerMsg.contains('cedula') || lowerMsg.contains('documento')) &&
          lowerMsg.contains('en uso');

      if (esCorreoDuplicado || esCedulaDuplicada) {
        setState(() {
          _isLoading = false;
          if (esCorreoDuplicado) {
            _errorEmailEnUso =
                'Este correo electrónico ya se encuentra en uso. Cámbialo por otro.';
          }
          if (esCedulaDuplicada) {
            _errorCedulaEnUso =
                'Esta cédula ya se encuentra en uso. Cámbiala por otra.';
          }
        });
        _formKey.currentState!.validate();
        await _mostrarAlertaCredencialesEnUso(
          emailEnUso: esCorreoDuplicado,
          documentoEnUso: esCedulaDuplicada,
          email: email,
          documento: documento,
        );
        return;
      }

      _showMessage(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = _rolConfig;

    return Scaffold(
      backgroundColor: OnboardingUnifiedBackground.bgCream,
      body: OnboardingUnifiedBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isTwoCols = width >= 680;
            final isMobile = width < 600;

            final fieldNombres = _textField(
              controller: _nombresController,
              hint: 'Nombres *',
              icon: Icons.person_outline_rounded,
              validator: _requiredValidator,
              textCapitalization: TextCapitalization.words,
            );

            final fieldApellidos = _textField(
              controller: _apellidosController,
              hint: 'Apellidos *',
              icon: Icons.person_outline_rounded,
              validator: _requiredValidator,
              textCapitalization: TextCapitalization.words,
            );

            final fieldEmail = _textField(
              controller: _emailController,
              hint: 'Correo electrónico *',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) {
                if (_errorEmailEnUso != null) {
                  setState(() => _errorEmailEnUso = null);
                  _formKey.currentState?.validate();
                }
              },
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) {
                  return 'El correo electrónico es obligatorio.';
                }
                if (!_emailRegex.hasMatch(email)) {
                  return 'Ingresa un correo electrónico válido.';
                }
                if (_errorEmailEnUso != null) {
                  return _errorEmailEnUso;
                }
                return null;
              },
            );

            final fieldDocumento = _textField(
              controller: _documentoController,
              hint: 'Número de cédula o documento *',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                LengthLimitingTextInputFormatter(18),
              ],
              onChanged: (_) {
                if (_errorCedulaEnUso != null) {
                  setState(() => _errorCedulaEnUso = null);
                  _formKey.currentState?.validate();
                }
              },
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.isEmpty) {
                  return 'El número de cédula es obligatorio.';
                }
                if (digits.length < 5) {
                  return 'Ingresa un número de cédula válido (mínimo 5 dígitos).';
                }
                if (_errorCedulaEnUso != null) {
                  return _errorCedulaEnUso;
                }
                return null;
              },
            );

            final fieldPais = DropdownButtonFormField<String>(
              initialValue: _pais,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 14.8,
                fontWeight: FontWeight.w500,
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF475569),
              ),
              decoration: _decoration(
                hint: 'País de residencia',
                labelText: 'País de residencia *',
                icon: Icons.public_rounded,
              ),
              items: const [
                DropdownMenuItem(value: 'Colombia', child: Text('Colombia')),
                DropdownMenuItem(value: 'México', child: Text('México')),
                DropdownMenuItem(value: 'España', child: Text('España')),
                DropdownMenuItem(
                  value: 'Estados Unidos',
                  child: Text('Estados Unidos'),
                ),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
              ],
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _pais = value);
                      }
                    },
              validator: (value) => value == null ? 'Selecciona un país.' : null,
            );

            final fieldTelefono = _textField(
              controller: _telefonoController,
              hint: 'Número de teléfono (opcional)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            );

            final fieldPassword = _textField(
              controller: _passwordController,
              hint: 'Contraseña (mín. 8, mayús. y número) *',
              icon: Icons.lock_outline_rounded,
              obscureText: !_passwordVisible,
              validator: (value) => SecurityService.validateStrongPassword(value),
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
            );

            final fieldConfirmPassword = _textField(
              controller: _confirmPasswordController,
              hint: 'Confirmar contraseña *',
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
                  () => _confirmPasswordVisible = !_confirmPasswordVisible,
                ),
                icon: Icon(
                  _confirmPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF334155),
                  size: 20,
                ),
              ),
            );

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 36,
                  vertical: isMobile ? 12 : 22,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Barra superior sin logo duplicado (el logo HD grande va dentro de la tarjeta)
                        OnboardingUnifiedTopBar(
                          currentStep: 2,
                          totalSteps: 3,
                          onBack: _cambiarRol,
                          backLabel: 'Cambiar rol',
                          showBrandLogo: false,
                        ),
                        SizedBox(height: isMobile ? 14 : 20),

                        // Título y subtítulo centrados
                        Text(
                          'Crea tu cuenta para continuar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _navyDark,
                            fontSize: isMobile ? 25 : 36,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Completa tus datos personales. Tu cédula y tu correo electrónico son obligatorios y únicos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _subtitleBlue,
                              fontSize: isMobile ? 13.8 : 16,
                              fontWeight: FontWeight.w500,
                              height: 1.38,
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 24),

                        // Tarjeta centralizada más amplia, con fondo blanco puro para el logo HD
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: const Color(0xFFF5C032),
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF5B82E).withValues(
                                    alpha: 0.16,
                                  ),
                                  blurRadius: 32,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: _navyDark.withValues(alpha: 0.07),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : 36,
                              vertical: isMobile ? 20 : 30,
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Cabecera superior de la tarjeta: UN SOLO LOGO HD GRANDE + Stepper
                                  _buildRegistrationCardHeader(
                                    isMobile: isMobile,
                                  ),
                                  SizedBox(height: isMobile ? 16 : 22),

                                  // Banner del rol seleccionado con la ilustración original de la foto y su precio ($100 COP)
                                  _buildSelectedRoleBanner(
                                    rol: rol,
                                    isMobile: isMobile,
                                  ),
                                  SizedBox(height: isMobile ? 16 : 22),

                                  // Campos en cuadrícula limpia de 2 columnas en escritorio / 1 columna ajustada en celular
                                  if (isTwoCols) ...[
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: fieldNombres),
                                        const SizedBox(width: 14),
                                        Expanded(child: fieldApellidos),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: fieldEmail),
                                        const SizedBox(width: 14),
                                        Expanded(child: fieldDocumento),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: fieldPais),
                                        const SizedBox(width: 14),
                                        Expanded(child: fieldTelefono),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: fieldPassword),
                                        const SizedBox(width: 14),
                                        Expanded(child: fieldConfirmPassword),
                                      ],
                                    ),
                                  ] else ...[
                                    fieldNombres,
                                    const SizedBox(height: 12),
                                    fieldApellidos,
                                    const SizedBox(height: 12),
                                    fieldEmail,
                                    const SizedBox(height: 12),
                                    fieldDocumento,
                                    const SizedBox(height: 12),
                                    fieldPais,
                                    const SizedBox(height: 12),
                                    fieldTelefono,
                                    const SizedBox(height: 12),
                                    fieldPassword,
                                    const SizedBox(height: 12),
                                    fieldConfirmPassword,
                                  ],
                                  const SizedBox(height: 16),

                                  // Aviso de verificación de unicidad de cédula y correo
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF5FD),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFDCE8F8),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.verified_user_outlined,
                                          color: Color(0xFF1D4ED8),
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Tu número de cédula y tu correo electrónico son de uso único por cuenta y quedarán vinculados de forma segura.',
                                            style: TextStyle(
                                              color: Color(0xFF334155),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // Autorización obligatoria de tratamiento de datos (Ley 1581 de 2012)
                                  _buildConsentimientoDatos(),
                                  const SizedBox(height: 20),

                                  // Botón principal grande y proporcionado
                                  SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _register,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _aceptaPolitica
                                            ? _goldAccent
                                            : const Color(0xFFE2E8F0),
                                        foregroundColor: _navyDark,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(28),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: _navyDark,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    'Continuar al pago (${rol.precioFormateadoCop})',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: _navyDark,
                                                      fontSize:
                                                          isMobile ? 15.2 : 16.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 20,
                                                  color: _navyDark,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Enlace inferior a Iniciar sesión
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      const Text(
                                        '¿Ya tienes cuenta registrada? ',
                                        style: TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 14.2,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: _isLoading
                                            ? null
                                            : _navigateToLogin,
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            'Inicia sesión aquí →',
                                            style: TextStyle(
                                              color: _navyDark,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              decoration:
                                                  TextDecoration.underline,
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
                        const SizedBox(height: 20),
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

  Widget _buildRegistrationCardHeader({required bool isMobile}) {
    final logo = ContrataLegalHdLogo(height: isMobile ? 50 : 62);

    final stepper = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepMiniItem(label: 'Rol', completed: true, active: false),
        Container(
          width: isMobile ? 22 : 32,
          height: 2,
          margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
          color: _tealCheck,
        ),
        _buildStepMiniItem(label: 'Registro', completed: false, active: true),
        Container(
          width: isMobile ? 22 : 32,
          height: 2,
          margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
          color: const Color(0xFFD8E0EA),
        ),
        _buildStepMiniItem(label: 'Pago', completed: false, active: false),
      ],
    );

    if (isMobile) {
      return Column(
        children: [
          Center(child: logo),
          const SizedBox(height: 12),
          Center(child: stepper),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        logo,
        stepper,
      ],
    );
  }

  Widget _buildStepMiniItem({
    required String label,
    required bool completed,
    required bool active,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: completed
                ? _tealCheck
                : (active ? Colors.white : const Color(0xFFEEF2F6)),
            shape: BoxShape.circle,
            border: Border.all(
              color: completed || active
                  ? _tealCheck
                  : const Color(0xFFCBD5E1),
              width: active ? 2.0 : 1.4,
            ),
          ),
          child: Icon(
            completed
                ? Icons.check_rounded
                : (active ? Icons.edit_rounded : Icons.circle),
            size: completed || active ? 14 : 6,
            color: completed
                ? Colors.white
                : (active ? _tealCheck : const Color(0xFFCBD5E1)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: completed || active ? _navyDark : const Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight:
                completed || active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedRoleBanner({
    required RolPaqueteConfig rol,
    required bool isMobile,
  }) {
    final avatarWidget = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: isMobile ? 68 : 88,
        height: isMobile ? 56 : 70,
        child: Image.memory(
          RolesVisualAssetsData.bytesForRole(rol.id),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          gaplessPlayback: true,
        ),
      ),
    );

    final cambiarRolBtn = OutlinedButton.icon(
      onPressed: _cambiarRol,
      style: OutlinedButton.styleFrom(
        foregroundColor: _navyDark,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2C05A), width: 1.3),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 8 : 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: _navyDark),
      label: Text(
        'Cambiar rol',
        style: TextStyle(
          color: _navyDark,
          fontSize: isMobile ? 12.8 : 13.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5D061), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatarWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Rol elegido: ${rol.nombre}',
                          style: TextStyle(
                            color: _navyDark,
                            fontSize: isMobile ? 15.5 : 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: _goldAccent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            rol.precioFormateadoCop,
                            style: const TextStyle(
                              color: _navyDark,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rol.descripcionCorta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _subtitleBlue,
                        fontSize: isMobile ? 12.2 : 13,
                        fontWeight: FontWeight.w500,
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 10),
                cambiarRolBtn,
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: cambiarRolBtn),
          ],
        ],
      ),
    );
  }

  Widget _buildConsentimientoDatos() {
    final hayError = _mostrarErrorPolitica && !_aceptaPolitica;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          decoration: BoxDecoration(
            color: hayError ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hayError ? Colors.red.shade400 : const Color(0xFFD8DEE8),
              width: hayError ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _aceptaPolitica,
                activeColor: _navyDark,
                side: BorderSide(
                  color:
                      hayError ? Colors.red.shade400 : const Color(0xFF64748B),
                  width: 1.6,
                ),
                onChanged: _isLoading
                    ? null
                    : (value) => setState(() {
                          _aceptaPolitica = value ?? false;
                          if (_aceptaPolitica) _mostrarErrorPolitica = false;
                        }),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => setState(() {
                              _aceptaPolitica = !_aceptaPolitica;
                              if (_aceptaPolitica) _mostrarErrorPolitica = false;
                            }),
                    child: Wrap(
                      children: [
                        const Text(
                          'He leído y acepto la ',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 13.2,
                            height: 1.4,
                          ),
                        ),
                        InkWell(
                          onTap: _mostrarPoliticaPrivacidad,
                          child: const Text(
                            'Política de Privacidad y Tratamiento de Datos Personales',
                            style: TextStyle(
                              color: _royalBlue,
                              fontSize: 13.2,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: _royalBlue,
                            ),
                          ),
                        ),
                        const Text(
                          ' y autorizo el tratamiento de mis datos conforme a la Ley 1581 de 2012. *',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 13.2,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hayError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 15, color: Colors.red.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Debes aceptar la política para crear tu cuenta.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _mostrarPoliticaPrivacidad() async {
    final acepta = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Política de Privacidad y Tratamiento de Datos Personales',
          style: TextStyle(
            color: _navyDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
          child: const SingleChildScrollView(
            child: Text(
              'Versión ${ConsentService.versionPolitica}\n\n'
              '1. Responsable: Contrata Legal, plataforma tecnológica de información contractual pública para el rol Persona y roles especializados.\n\n'
              '2. Datos tratados: nombres, apellidos, correo electrónico, número de documento/cédula, país y teléfono.\n\n'
              '3. Finalidades: crear y administrar tu cuenta, asignar tus roles activos, autenticarte, guardar tus favoritos y preferencias, procesar la activación de tu plan y cumplir obligaciones legales.\n\n'
              '4. Derechos del titular (Art. 8, Ley 1581 de 2012): conocer, actualizar y rectificar tus datos; solicitar prueba de esta autorización; ser informado del uso dado a tus datos; presentar quejas ante la Superintendencia de Industria y Comercio; revocar la autorización y solicitar la supresión de tus datos.\n\n'
              '5. Datos sensibles: no son obligatorios; puedes abstenerte de suministrarlos.\n\n'
              '6. Seguridad y conservación: los datos se almacenan en servicios de Google Firebase con medidas de seguridad razonables y se conservan mientras la cuenta esté activa o lo exija la ley.\n\n'
              '7. Evidencia: al aceptar, se registra la fecha y hora de tu autorización y la versión de esta política, como prueba exigida por el Decreto 1377 de 2013.',
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _navyDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Acepto'),
          ),
        ],
      ),
    );

    if (acepta == true && mounted) {
      setState(() {
        _aceptaPolitica = true;
        _mostrarErrorPolitica = false;
      });
    }
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
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      enabled: !_isLoading,
      style: const TextStyle(
        fontSize: 14.8,
        fontWeight: FontWeight.w500,
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
        fontSize: 13.5,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 14.2,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: const Color(0xFFFDFEFE),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      prefixIcon: Icon(icon, color: _navyDark, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFD8DEE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _navyDark, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Colors.red.shade600, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.8),
      ),
    );
  }
}
