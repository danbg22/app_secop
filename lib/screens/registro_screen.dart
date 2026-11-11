import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/roles_visual_assets_data.dart';
import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../services/payment_service.dart';
import '../services/security_service.dart';
import 'escoger_rol_screen.dart';
import 'pasarela_pago_wompi_screen.dart';
import '../tema/cristal.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key, this.rolSeleccionadoId = 'persona'});

  final String rolSeleccionadoId;

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
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
                color: Cristal.texto,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Cristal.texto,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? Color(0xFFDC2626) : Cristal.flotante,
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

    await mostrarDialogoCristal<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Cristal.flotante,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Cristal.bordeFuerte),
        ),
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
                    color: Cristal.rojoVidrio,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Cristal.rojo,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Cristal.texto,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  detalle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Cristal.textoMedio,
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
                      backgroundColor: Cristal.acento,
                      foregroundColor: Cristal.texto,
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
            _errorEmailEnUso = 'Este correo electrónico ya se encuentra en uso. Cámbialo por otro.';
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
          (lowerMsg.contains('cédula') ||
              lowerMsg.contains('cedula') ||
              lowerMsg.contains('documento')) &&
          lowerMsg.contains('en uso');

      if (esCorreoDuplicado || esCedulaDuplicada) {
        setState(() {
          _isLoading = false;
          if (esCorreoDuplicado) {
            _errorEmailEnUso = 'Este correo electrónico ya se encuentra en uso. Cámbialo por otro.';
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

    return SelectionArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                  color: Cristal.texto,
                  fontSize: 14.8,
                  fontWeight: FontWeight.w500,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Cristal.textoMedio,
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
                validator: (value) =>
                    value == null ? 'Selecciona un país.' : null,
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
                validator: (value) =>
                    SecurityService.validateStrongPassword(value),
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
                    color: Cristal.textoCuerpo,
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
                    color: Cristal.textoCuerpo,
                    size: 20,
                  ),
                ),
              );

              return SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 32,
                    vertical: isMobile ? 12 : 18,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 36).clamp(
                        0.0,
                        2000.0,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                            SizedBox(height: isMobile ? 10 : 14),

                            // Título y subtítulo centrados
                            Text(
                              'Crea tu cuenta para continuar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Cristal.texto,
                                fontSize: isMobile ? 23 : 30,
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                'Completa tus datos personales. Tu cédula y tu correo electrónico son obligatorios y únicos.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Cristal.textoMedio,
                                  fontSize: isMobile ? 13.2 : 14.8,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            SizedBox(height: isMobile ? 14 : 18),

                            // Tarjeta centralizada más compacta y visualmente equilibrada
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 625),
                              // Vidrio de verdad: el formulario va sobre
                              // la foto.
                              child: DesenfoqueCristal(
                                radio: BorderRadius.circular(24),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Cristal.vidrioOscuro,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Cristal.dorado,
                                      width: 1.8,
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 28,
                                    vertical: isMobile ? 18 : 24,
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Cabecera superior de la tarjeta: UN SOLO LOGO HD GRANDE + Stepper
                                        _buildRegistrationCardHeader(
                                          isMobile: isMobile,
                                        ),
                                        SizedBox(height: isMobile ? 14 : 16),

                                        // Banner del rol seleccionado con la ilustración original de la foto y su precio ($100 COP)
                                        _buildSelectedRoleBanner(
                                          rol: rol,
                                          isMobile: isMobile,
                                        ),
                                        SizedBox(height: isMobile ? 14 : 16),

                                        // Campos en cuadrícula limpia de 2 columnas en escritorio / 1 columna ajustada en celular
                                        if (isTwoCols) ...[
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: fieldNombres),
                                              const SizedBox(width: 12),
                                              Expanded(child: fieldApellidos),
                                            ],
                                          ),
                                          const SizedBox(height: 11),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: fieldEmail),
                                              const SizedBox(width: 12),
                                              Expanded(child: fieldDocumento),
                                            ],
                                          ),
                                          const SizedBox(height: 11),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: fieldPais),
                                              const SizedBox(width: 12),
                                              Expanded(child: fieldTelefono),
                                            ],
                                          ),
                                          const SizedBox(height: 11),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: fieldPassword),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: fieldConfirmPassword,
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          fieldNombres,
                                          const SizedBox(height: 11),
                                          fieldApellidos,
                                          const SizedBox(height: 11),
                                          fieldEmail,
                                          const SizedBox(height: 11),
                                          fieldDocumento,
                                          const SizedBox(height: 11),
                                          fieldPais,
                                          const SizedBox(height: 11),
                                          fieldTelefono,
                                          const SizedBox(height: 11),
                                          fieldPassword,
                                          const SizedBox(height: 11),
                                          fieldConfirmPassword,
                                        ],
                                        const SizedBox(height: 13),

                                        // Aviso de verificación de unicidad de cédula y correo
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Cristal.vidrioSuave,
                                            borderRadius: BorderRadius.circular(
                                              11,
                                            ),
                                            border: Border.all(
                                              color: Cristal.acentoBorde,
                                            ),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.verified_user_outlined,
                                                color: Cristal.acentoClaro,
                                                size: 18,
                                              ),
                                              SizedBox(width: 9),
                                              Expanded(
                                                child: Text(
                                                  'Tu número de cédula y tu correo electrónico son de uso único por cuenta y quedarán vinculados de forma segura.',
                                                  style: TextStyle(
                                                    color: Cristal.textoCuerpo,
                                                    fontSize: 12.2,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.32,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 11),

                                        // Autorización obligatoria de tratamiento de datos (Ley 1581 de 2012)
                                        _buildConsentimientoDatos(),
                                        const SizedBox(height: 16),

                                        // Botón principal proporcionado
                                        SizedBox(
                                          height: 50,
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _register,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _aceptaPolitica
                                                  ? Cristal.dorado
                                                  : Cristal.vidrioFuerte,
                                              foregroundColor: Cristal.texto,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(26),
                                              ),
                                            ),
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color: Cristal
                                                              .acentoClaro,
                                                        ),
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          'Continuar al pago (${rol.precioFormateadoCop})',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color:
                                                                Cristal.texto,
                                                            fontSize: isMobile
                                                                ? 14.8
                                                                : 15.8,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      const Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 19,
                                                        color: Cristal.texto,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 13),

                                        // Enlace inferior a Iniciar sesión
                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            const Text(
                                              '¿Ya tienes cuenta registrada? ',
                                              style: TextStyle(
                                                color: Cristal.textoMedio,
                                                fontSize: 13.6,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            InkWell(
                                              hoverDuration: Cristal.micro,
                                              onTap: _isLoading
                                                  ? null
                                                  : _navigateToLogin,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 4,
                                                ),
                                                child: Text(
                                                  'Inicia sesión aquí →',
                                                  style: TextStyle(
                                                    color: Cristal.texto,
                                                    fontSize: 13.8,
                                                    fontWeight: FontWeight.w800,
                                                    decoration: TextDecoration
                                                        .underline,
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
                            const SizedBox(height: 16),
                          ],
                        ),
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
          color: Color(0xFF1E7868),
        ),
        _buildStepMiniItem(label: 'Registro', completed: false, active: true),
        Container(
          width: isMobile ? 22 : 32,
          height: 2,
          margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
          color: Cristal.vidrioFuerte,
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
      children: [logo, stepper],
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
                ? Color(0xFF1E7868)
                : (active ? Cristal.vidrio : Cristal.vidrioSuave),
            shape: BoxShape.circle,
            border: Border.all(
              color: completed || active
                  ? Color(0xFF2DD4BF)
                  : Cristal.bordeFuerte,
              width: active ? 2.0 : 1.4,
            ),
          ),
          child: Icon(
            completed
                ? Icons.check_rounded
                : (active ? Icons.edit_rounded : Icons.circle),
            size: completed || active ? 14 : 6,
            color: completed
                ? Cristal.texto
                : (active ? Color(0xFF2DD4BF) : Cristal.textoApagado),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: completed || active ? Cristal.texto : Cristal.textoTenue,
            fontSize: 11.5,
            fontWeight: completed || active ? FontWeight.w800 : FontWeight.w600,
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
        foregroundColor: Cristal.texto,
        backgroundColor: Cristal.vidrio,
        side: const BorderSide(color: Cristal.dorado, width: 1.3),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 8 : 10,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      icon: const Icon(
        Icons.swap_horiz_rounded,
        size: 18,
        color: Cristal.texto,
      ),
      label: Text(
        'Cambiar rol',
        style: TextStyle(
          color: Cristal.texto,
          fontSize: isMobile ? 12.8 : 13.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Cristal.vidrioSuave,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Cristal.dorado, width: 1.3),
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
                            color: Cristal.texto,
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
                            color: Cristal.dorado,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            rol.precioFormateadoCop,
                            style: const TextStyle(
                              color: Cristal.tinta,
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
                        color: Cristal.textoMedio,
                        fontSize: isMobile ? 12.2 : 13,
                        fontWeight: FontWeight.w500,
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[const SizedBox(width: 10), cambiarRolBtn],
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
            color: hayError ? Cristal.rojoVidrio : Cristal.vidrioSuave,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hayError ? Color(0xFFEF5350) : Cristal.borde,
              width: hayError ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _aceptaPolitica,
                activeColor: Cristal.acento,
                side: BorderSide(
                  color: hayError ? Color(0xFFEF5350) : const Color(0x52FFFFFF),
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
                            color: Cristal.textoCuerpo,
                            fontSize: 13.2,
                            height: 1.4,
                          ),
                        ),
                        InkWell(
                          hoverDuration: Cristal.micro,
                          onTap: _mostrarPoliticaPrivacidad,
                          child: const Text(
                            'Política de Privacidad y Tratamiento de Datos Personales',
                            style: TextStyle(
                              color: Cristal.acentoClaro,
                              fontSize: 13.2,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: Cristal.acentoClaro,
                            ),
                          ),
                        ),
                        const Text(
                          ' y autorizo el tratamiento de mis datos conforme a la Ley 1581 de 2012. *',
                          style: TextStyle(
                            color: Cristal.textoCuerpo,
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
                Icon(Icons.error_outline, size: 15, color: Cristal.rojo),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Debes aceptar la política para crear tu cuenta.',
                    style: TextStyle(
                      color: Cristal.rojo,
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
    final acepta = await mostrarDialogoCristal<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Política de Privacidad y Tratamiento de Datos Personales',
          style: TextStyle(
            color: Cristal.texto,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
          child: const SingleChildScrollView(
            child: Text(
              ConsentService.textoPolitica,
              style: TextStyle(
                color: Cristal.textoCuerpo,
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
              backgroundColor: Cristal.acento,
              foregroundColor: Cristal.texto,
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
        color: Cristal.texto,
      ),
      decoration: _decoration(
        hint: hint,
        icon: icon,
      ).copyWith(suffixIcon: suffixIcon),
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
      labelStyle: const TextStyle(color: Cristal.textoSuave, fontSize: 13.5),
      hintStyle: const TextStyle(
        color: Cristal.textoSuave,
        fontSize: 14.2,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Cristal.campo,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      prefixIcon: Icon(icon, color: Cristal.texto, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Cristal.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Cristal.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Cristal.acentoClaro, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Cristal.rojo, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: Cristal.rojo, width: 1.8),
      ),
    );
  }
}
