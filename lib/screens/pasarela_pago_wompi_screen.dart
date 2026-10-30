import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/auth_bg_asset_data.dart';
import '../data/roles_visual_assets_data.dart';
import '../widgets/admin_verification_banner.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import 'escoger_rol_screen.dart';
import 'perfil_usuario_screen.dart';

class PasarelaPagoWompiScreen extends StatefulWidget {
  const PasarelaPagoWompiScreen({
    super.key,
    this.rolId = 'persona',
    this.esFlujoRegistro = true,
  });

  final String rolId;
  final bool esFlujoRegistro;

  @override
  State<PasarelaPagoWompiScreen> createState() =>
      _PasarelaPagoWompiScreenState();
}

class _PasarelaPagoWompiScreenState extends State<PasarelaPagoWompiScreen> {
  static const Color _navy = Color(0xFF0B2545);
  static const Color _subtitleSlate = Color(0xFF475569);
  static const Color _bgCream = Color(0xFFF9F1DF);
  static const Color _tealCheck = Color(0xFF1E7868);

  /// Paso interno dentro de la pasarela (0: Plan, 1: Método, 2: Datos de pago, 3: ¡Listo!)
  int _pasoActual = 0;

  WompiMetodoPago _metodoSeleccionado = WompiMetodoPago.tarjetaCreditoDebito;
  bool _procesandoPago = false;
  late String _referenciaTransaccion;
  late String _firmaSha256;
  WompiTransactionReceipt? _reciboAprobado;

  // Controladores para Tarjeta
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();

  // Controladores para Nequi / Daviplata
  String _billeteraMovil = 'Nequi';
  final TextEditingController _celularBilleteraController =
      TextEditingController();

  // Controladores para Transferencia PSE Bancolombia
  String _bancoPse = 'Bancolombia';
  final TextEditingController _documentoPseController = TextEditingController();

  RolPaqueteConfig get _rolConfig =>
      PaymentService.obtenerConfiguracionRol(widget.rolId);

  @override
  void initState() {
    super.initState();
    _regenerarSellosCriptograficos();
    final activeName = AuthService.getActiveUserDisplayName();
    if (activeName.isNotEmpty && activeName != 'Usuario') {
      _cardHolderController.text = activeName;
    }
  }

  void _regenerarSellosCriptograficos() {
    _referenciaTransaccion = PaymentService.generarReferenciaUnicaWompi(
      _rolConfig.id,
    );
    _firmaSha256 = PaymentService.generarFirmaIntegridadWompi(
      referencia: _referenciaTransaccion,
      montoEnCentavos: _rolConfig.montoEnCentavosWompi,
    );
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardHolderController.dispose();
    _celularBilleteraController.dispose();
    _documentoPseController.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String texto, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              esError ? const Color(0xFFDC2626) : const Color(0xFF15803D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                esError ? Icons.error_outline : Icons.verified_rounded,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
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
  }

  void _cambiarRol() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EscogerRolScreen(
          modoAcumularRol:
              !widget.esFlujoRegistro && AuthService.hasAuthorizedPlatformAccess,
          rolActualSeleccionadoId: _rolConfig.id,
        ),
      ),
    );
  }

  Future<void> _cerrarSesionPendienteYSalir() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/portada', (route) => false);
  }

  Future<void> _manejarIntentoRegresar() async {
    if (_procesandoPago) return;

    if (_pasoActual == 3) {
      _irAlInicioPlataforma();
      return;
    }

    if (_pasoActual > 0) {
      setState(() => _pasoActual--);
      return;
    }

    // Si el usuario ya tiene cuenta activa pagada y está acumulando un rol nuevo,
    // regresa fluidamente a la plataforma sin perder su sesión actual.
    if (!widget.esFlujoRegistro && AuthService.hasAuthorizedPlatformAccess) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        _irAlInicioPlataforma();
      }
      return;
    }

    // CIBERSEGURIDAD ESTRICTA: Si el pago inicial está pendiente, jamás se permite
    // entrar a /home retrocediendo. Mostramos opciones controladas y seguras.
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFB45309),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Activación de pago requerida',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _navy,
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Por seguridad, tu cuenta aún no tiene acceso habilitado a la plataforma hasta que Wompi confirme el pago del rol ${_rolConfig.nombre} (${_rolConfig.precioFormateadoCop}).',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _subtitleSlate,
                    fontSize: 13.5,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Continuar con el pago',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _cambiarRol();
                    },
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text(
                      'Cambiar rol a activar',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _cerrarSesionPendienteYSalir();
                  },
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 17,
                    color: Colors.red.shade700,
                  ),
                  label: Text(
                    'Cancelar activación y cerrar sesión',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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

  void _autocompletarSandbox({required bool aprobado}) {
    setState(() {
      if (_metodoSeleccionado == WompiMetodoPago.tarjetaCreditoDebito) {
        _cardNumberController.text = aprobado
            ? '4242 4242 4242 4242'
            : '4242 4242 4242 0002';
        _cardExpiryController.text = '12/29';
        _cardCvvController.text = '123';
        if (_cardHolderController.text.trim().isEmpty) {
          _cardHolderController.text = 'USUARIO PRUEBA WOMPI';
        }
      } else if (_metodoSeleccionado == WompiMetodoPago.nequiDaviplata) {
        _celularBilleteraController.text =
            aprobado ? '3991111111' : '3992222222';
      } else {
        _bancoPse = 'Bancolombia';
        _documentoPseController.text = aprobado ? '1098765432' : '00000';
      }
    });
    _mostrarMensaje(
      aprobado
          ? 'Datos de prueba Sandbox Wompi (APROBADO) cargados.'
          : 'Datos de prueba Sandbox Wompi (RECHAZADO) cargados.',
    );
  }

  void _mostrarDiagnosticoAmbienteWompi() {
    final diag = PaymentService.diagnosticarCredencialesWompi();
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: diag.isSandbox
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        diag.environmentLabel.toUpperCase(),
                        style: TextStyle(
                          color: diag.isSandbox
                              ? const Color(0xFF92400E)
                              : _tealCheck,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      diag.allValid
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
                      color: diag.allValid ? _tealCheck : Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Verificación de Ambiente y Llaves Wompi',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  diag.allValid
                      ? 'Las 4 llaves configuradas (pública, privada, eventos e integridad SHA-256) coinciden estrictamente con los prefijos oficiales de ${diag.environmentLabel}.'
                      : 'Revisa los prefijos de llaves en AdminConfiguracionRolesYPagos según la documentación oficial de Wompi.',
                  style: const TextStyle(
                    color: _subtitleSlate,
                    fontSize: 12.8,
                    height: 1.38,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Endpoint API: ${diag.apiBaseUrl}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Llave Pública: ${diag.maskedPublicKey}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Comercio: ${AdminConfiguracionRolesYPagos.titularCuentaDestino} (${AdminConfiguracionRolesYPagos.nitComercioDestino})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Archivo de configuración rápida: lib/services/payment_service.dart -> AdminConfiguracionRolesYPagos',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _tealCheck,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Cerrar verificación',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

  void _mostrarModalTodosLosBeneficios() {
    final rol = _rolConfig;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAE29C),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        rol.nombrePlan,
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      rol.precioFormateadoCop,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Beneficios incluidos en el rol ${rol.nombre}',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Este rol es acumulable en el futuro con cualquier otro rol de la plataforma.',
                  style: TextStyle(
                    color: _subtitleSlate,
                    fontSize: 12.8,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                for (final b in rol.todosLosBeneficios) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: _tealCheck,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            b.trim(),
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 13.2,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
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

  Future<void> _abrirCheckoutExternoWompi() async {
    final uri = PaymentService.construirUrlWompiCheckout(
      rolId: _rolConfig.id,
      referencia: _referenciaTransaccion,
      emailUsuario: AuthService.getActiveUserEmail(),
      nombreUsuario: AuthService.getActiveUserDisplayName(),
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _mostrarMensaje(
        'Puedes completar el pago seguro directamente en este formulario integrado de Wompi.',
      );
    }
  }

  Future<void> _ejecutarPagoWompi() async {
    if (_procesandoPago) return;

    setState(() => _procesandoPago = true);
    try {
      final datos = <String, String>{
        'numeroTarjeta': _cardNumberController.text,
        'expiracion': _cardExpiryController.text,
        'cvv': _cardCvvController.text,
        'titular': _cardHolderController.text,
        'billetera': _billeteraMovil,
        'celular': _celularBilleteraController.text,
        'banco': _bancoPse,
        'documento': _documentoPseController.text,
      };

      final receipt = await PaymentService.procesarYValidarPagoWompi(
        rolId: _rolConfig.id,
        metodoPago: _metodoSeleccionado,
        datosPago: datos,
        referenciaPrevia: _referenciaTransaccion,
        emailCliente: AuthService.getActiveUserEmail(),
      );

      // Purga inmediata de credenciales financieras en memoria (PCI-DSS higiene)
      _cardNumberController.clear();
      _cardExpiryController.clear();
      _cardCvvController.clear();
      _celularBilleteraController.clear();
      _documentoPseController.clear();
      datos.clear();

      await AuthService.assignPaidRoleToActiveUser(receipt);

      if (!mounted) return;
      setState(() {
        _reciboAprobado = receipt;
        _procesandoPago = false;
        _pasoActual = 3; // Vista 4: ¡Listo!
      });
    } on PaymentSecurityException catch (e) {
      if (!mounted) return;
      setState(() => _procesandoPago = false);
      _mostrarMensaje(e.message, esError: true);
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      setState(() => _procesandoPago = false);
      _mostrarMensaje(e.message, esError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesandoPago = false);
      _mostrarMensaje(
        'Ocurrió un inconveniente al validar el pago con Wompi. Verifica los datos e inténtalo de nuevo.',
        esError: true,
      );
    }
  }

  void _irAlInicioPlataforma() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _irAMiPerfil() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const PerfilUsuarioScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool acumulandoEnSesionActiva =
        !widget.esFlujoRegistro && AuthService.hasAuthorizedPlatformAccess;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _manejarIntentoRegresar();
        }
      },
      child: SelectionArea(
        child: Scaffold(
          backgroundColor: _bgCream,
          body: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            return OnboardingUnifiedBackground(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 14 : 24,
                      vertical: isMobile ? 16 : 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AdminVerificationBanner(),
                          OnboardingUnifiedTopBar(
                            currentStep: 3,
                            totalSteps: 3,
                            showBrandLogo: false,
                            backLabel: _pasoActual == 3
                                ? 'Ir al inicio'
                                : (_pasoActual > 0
                                      ? 'Volver'
                                      : (acumulandoEnSesionActiva
                                            ? 'Volver a mi cuenta'
                                            : 'Cambiar rol')),
                            onBack: _pasoActual == 3
                                ? _irAlInicioPlataforma
                                : (_pasoActual > 0
                                      ? () => setState(() => _pasoActual--)
                                      : (acumulandoEnSesionActiva
                                            ? _manejarIntentoRegresar
                                            : _cambiarRol)),
                          ),
                          SizedBox(height: isMobile ? 12 : 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              child: _buildActiveCard(isMobile: isMobile),
                            ),
                          ),
                          if (AuthService.requiresMandatoryWompiPayment &&
                              _pasoActual < 3) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _procesandoPago
                                  ? null
                                  : _cerrarSesionPendienteYSalir,
                              icon: const Icon(
                                Icons.logout_rounded,
                                size: 16,
                                color: Color(0xFF475569),
                              ),
                              label: const Text(
                                'Cerrar sesión y volver a la portada',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildActiveCard({required bool isMobile}) {
    final bool isSuccessStep = _pasoActual == 3;

    return Container(
      key: ValueKey<int>(_pasoActual),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFF5C032), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5B82E).withValues(alpha: 0.15),
            blurRadius: 32,
            spreadRadius: 1,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: _navy.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 18 : 38,
              isMobile ? 20 : 32,
              isMobile ? 18 : 38,
              isSuccessStep ? 0 : (isMobile ? 22 : 34),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardHeader(
                  showStepper: !isSuccessStep,
                  isMobile: isMobile,
                ),
                SizedBox(height: isMobile ? 20 : 28),
                if (_pasoActual == 0) _buildPaso0PlanSummary(isMobile: isMobile),
                if (_pasoActual == 1)
                  _buildPaso1MetodoPago(isMobile: isMobile),
                if (_pasoActual == 2)
                  _buildPaso2FormularioPago(isMobile: isMobile),
                if (_pasoActual == 3)
                  _buildPaso3ExitoConfirmacion(isMobile: isMobile),
              ],
            ),
          ),

          // En el paso 4 ("¡Listo!") mostramos el paisaje colonial inferior con bandera igual a la foto
          if (isSuccessStep) _buildSuccessBottomBanner(isMobile: isMobile),
        ],
      ),
    );
  }

  // ===========================================================================
  // CABECERA DE LA TARJETA (UN SOLO LOGO CONTRATA LEGAL HD + STEPPER)
  // ===========================================================================

  Widget _buildCardHeader({
    required bool showStepper,
    required bool isMobile,
  }) {
    final logoRow = ContrataLegalHdLogo(height: isMobile ? 50 : 62);

    if (!showStepper) {
      return Align(alignment: Alignment.centerLeft, child: logoRow);
    }

    final bool pagoCompletadoEnStepper = _pasoActual >= 1;

    final stepperWidget = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Paso 1: Registro
        _buildMiniStepNode(
          label: 'Registro',
          isCompleted: true,
          isActive: false,
        ),
        _buildStepConnector(active: true),
        // Paso 2: Pago
        _buildMiniStepNode(
          label: 'Pago',
          isCompleted: pagoCompletadoEnStepper,
          isActive: !_procesandoPago,
        ),
        _buildStepConnector(active: false),
        // Paso 3: Inicio
        _buildMiniStepNode(
          label: 'Inicio',
          isCompleted: false,
          isActive: false,
        ),
      ],
    );

    if (isMobile) {
      return Column(
        children: [
          Center(child: logoRow),
          const SizedBox(height: 12),
          Center(child: stepperWidget),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: logoRow),
        const SizedBox(width: 12),
        stepperWidget,
      ],
    );
  }

  Widget _buildMiniStepNode({
    required String label,
    required bool isCompleted,
    required bool isActive,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted
                ? _tealCheck
                : (isActive ? Colors.white : const Color(0xFFEEF2F6)),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isActive
                  ? _tealCheck
                  : const Color(0xFFCBD5E1),
              width: isActive && !isCompleted ? 2.0 : 1.4,
            ),
          ),
          child: Icon(
            isCompleted
                ? Icons.check_rounded
                : (isActive ? Icons.check_rounded : Icons.circle),
            size: isCompleted || isActive ? 14 : 6,
            color: isCompleted
                ? Colors.white
                : (isActive ? _tealCheck : const Color(0xFFCBD5E1)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCompleted || isActive
                ? _navy
                : const Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: isCompleted || isActive
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector({required bool active}) {
    return Container(
      width: 34,
      height: 2,
      margin: const EdgeInsets.only(top: 11, left: 4, right: 4),
      color: active ? _tealCheck : const Color(0xFFD8E0EA),
    );
  }

  // ===========================================================================
  // VISTA 1: "¡YA CASI ESTÁS!" - RESUMEN DEL PLAN / ROL PERSONA ($100 COP)
  // ===========================================================================

  Widget _buildPaso0PlanSummary({required bool isMobile}) {
    final rol = _rolConfig;
    final diag = PaymentService.diagnosticarCredencialesWompi();
    final bool acumulandoEnSesion =
        !widget.esFlujoRegistro && AuthService.hasAuthorizedPlatformAccess;
    final String rolesPrevios = AuthService.getActiveUserRoleDisplayLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Píldora de verificación de ambiente Wompi (Sandbox / Producción)
        InkWell(
          onTap: _mostrarDiagnosticoAmbienteWompi,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: diag.isSandbox
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: diag.isSandbox
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFFBBF7D0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  diag.allValid
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: diag.isSandbox
                      ? const Color(0xFFB45309)
                      : _tealCheck,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diag.isSandbox
                        ? 'Wompi Sandbox verificado (${diag.maskedPublicKey}) · Pago integrado sin salir de tu sesión'
                        : 'Wompi Producción activo (${diag.maskedPublicKey})',
                    style: TextStyle(
                      color: diag.isSandbox
                          ? const Color(0xFF92400E)
                          : _tealCheck,
                      fontSize: 11.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Text(
                  'Ver llaves ↗',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (acumulandoEnSesion) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.layers_rounded,
                  size: 17,
                  color: Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Acumulación de rol activa: conservarás "$rolesPrevios" y se sumará "${rol.nombre}" a tu cuenta (${AuthService.getActiveUserEmail()}).',
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 11.8,
                      fontWeight: FontWeight.w700,
                      height: 1.32,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acumulandoEnSesion
                        ? 'Suma un nuevo rol a tu cuenta'
                        : '¡Ya casi estás!',
                    style: TextStyle(
                      color: _navy,
                      fontSize: isMobile ? 24 : 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    acumulandoEnSesion
                        ? 'Al confirmar el pago en Wompi, las nuevas herramientas se habilitarán al instante junto con las que ya tienes.'
                        : 'Para activar tu cuenta, elige un plan\ny completa el pago.',
                    style: const TextStyle(
                      color: _subtitleSlate,
                      fontSize: 13.8,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              width: 78,
              height: 74,
              child: CustomPaint(painter: _PlanBadgeIllustrationPainter()),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Contenedor "Tu plan"
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEFF3F8)),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: SizedBox(
                      width: 34,
                      height: 28,
                      child: Image.memory(
                        RolesVisualAssetsData.bytesForRole(rol.id),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'Tu plan',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Rol: ${rol.nombre}',
                      style: const TextStyle(
                        color: _tealCheck,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5EDF5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6D57A),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            rol.nombrePlan,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 12.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          rol.precioFormateadoCop,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final beneficio in rol.beneficiosPrincipales) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1.5),
                              child: Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: _tealCheck,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                beneficio,
                                style: const TextStyle(
                                  color: Color(0xFF1E3A5F),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _mostrarModalTodosLosBeneficios,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ver todos los beneficios',
                              style: TextStyle(
                                color: _navy,
                                fontSize: 12.2,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: _navy,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Barra inferior: Cambiar plan | Continuar al pago ->
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _cambiarRol,
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Cambiar plan',
                style: TextStyle(
                  color: _navy,
                  fontSize: 14.8,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => setState(() => _pasoActual = 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continuar al pago',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // VISTA 2: "SELECCIONA TU MÉTODO DE PAGO" (TARJETA / NEQUI-DAVIPLATA / PSE)
  // ===========================================================================

  Widget _buildPaso1MetodoPago({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Selecciona tu método de pago',
          style: TextStyle(
            color: _navy,
            fontSize: isMobile ? 22 : 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              color: _subtitleSlate,
              fontSize: 13.6,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
            children: [
              TextSpan(text: 'Puedes pagar de forma '),
              TextSpan(
                text: 'segura',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
              ),
              TextSpan(text: ' con tarjeta, Nequi, Daviplata o '),
              TextSpan(
                text: 'transferencia bancaria.',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Opción 1: Tarjeta de crédito o débito
        _buildMetodoPagoOptionCard(
          metodo: WompiMetodoPago.tarjetaCreditoDebito,
          leadingIcon: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F4F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.credit_card_rounded,
              color: _tealCheck,
              size: 20,
            ),
          ),
          title: 'Tarjeta de crédito o débito',
          subtitleWidget: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                const Text(
                  'VISA',
                  style: TextStyle(
                    color: Color(0xFF1A1F71),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 24,
                  height: 15,
                  child: Stack(
                    children: [
                      Container(
                        width: 15,
                        height: 15,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEB001B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Positioned(
                        left: 9,
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF79E1B).withValues(
                              alpha: 0.9,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AMEX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Opción 2: Nequi / Daviplata
        _buildMetodoPagoOptionCard(
          metodo: WompiMetodoPago.nequiDaviplata,
          leadingIcon: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF6F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              color: _tealCheck,
              size: 20,
            ),
          ),
          title: 'Nequi / Daviplata',
          subtitleWidget: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(
                  'Nequi',
                  style: TextStyle(
                    color: Color(0xFF200020),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'DAVIPLATA',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Opción 3: Transferencia bancaria (PSE / Bancolombia)
        _buildMetodoPagoOptionCard(
          metodo: WompiMetodoPago.transferenciaPseBancolombia,
          leadingIcon: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2F8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: _navy,
              size: 20,
            ),
          ),
          title: 'Transferencia bancaria',
          subtitleWidget: const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text(
              'PSE · Bancolombia · Todos los bancos en Colombia',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        // Leyenda de seguridad y no almacenamiento en Wompi
        const SizedBox(height: 18),
        _buildLeyendaSeguridadEncriptacionWompi(),
        const SizedBox(height: 22),

        // Barra inferior: Volver | Continuar ->
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _pasoActual = 0),
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Volver',
                style: TextStyle(
                  color: _navy,
                  fontSize: 14.8,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => setState(() => _pasoActual = 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continuar',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetodoPagoOptionCard({
    required WompiMetodoPago metodo,
    required Widget leadingIcon,
    required String title,
    required Widget subtitleWidget,
  }) {
    final bool selected = _metodoSeleccionado == metodo;

    return InkWell(
      onTap: () => setState(() => _metodoSeleccionado = metodo),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6FBF9) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _tealCheck : const Color(0xFFE6ECF2),
            width: selected ? 1.6 : 1.1,
          ),
        ),
        child: Row(
          children: [
            leadingIcon,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 14.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitleWidget,
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _tealCheck : const Color(0xFFCBD5E1),
                  width: 1.8,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          color: _tealCheck,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VISTA 3: "INGRESA LOS DATOS DE TU TARJETA / MÉTODO" + BOTÓN PAGAR $100 COP
  // ===========================================================================

  Widget _buildPaso2FormularioPago({required bool isMobile}) {
    final rol = _rolConfig;
    final String tituloPaso = switch (_metodoSeleccionado) {
      WompiMetodoPago.tarjetaCreditoDebito => 'Ingresa los datos de tu tarjeta',
      WompiMetodoPago.nequiDaviplata => 'Ingresa los datos de tu billetera',
      WompiMetodoPago.transferenciaPseBancolombia =>
        'Transferencia bancaria PSE',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tituloPaso,
                    style: TextStyle(
                      color: _navy,
                      fontSize: isMobile ? 21 : 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tu información está protegida con estándares de seguridad internacionales.',
                    style: TextStyle(
                      color: _subtitleSlate,
                      fontSize: 13.2,
                      height: 1.38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const SizedBox(
              width: 68,
              height: 58,
              child: CustomPaint(painter: _CardSecurityIllustrationPainter()),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (AdminConfiguracionRolesYPagos.modoSandbox) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 16,
                      color: Color(0xFFB45309),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Asistente de pruebas Wompi Sandbox (1 clic)',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      onPressed: _procesandoPago
                          ? null
                          : () => _autocompletarSandbox(aprobado: true),
                      backgroundColor: const Color(0xFFDCFCE7),
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                      avatar: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: _tealCheck,
                      ),
                      label: const Text(
                        'Cargar pago APROBADO',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ActionChip(
                      onPressed: _procesandoPago
                          ? null
                          : () => _autocompletarSandbox(aprobado: false),
                      backgroundColor: const Color(0xFFFEE2E2),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      avatar: Icon(
                        Icons.cancel_outlined,
                        size: 16,
                        color: Colors.red.shade700,
                      ),
                      label: Text(
                        'Probar pago RECHAZADO',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Tarjeta blanca del formulario
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAEFF5)),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_metodoSeleccionado == WompiMetodoPago.tarjetaCreditoDebito)
                _buildFormularioTarjeta(),
              if (_metodoSeleccionado == WompiMetodoPago.nequiDaviplata)
                _buildFormularioNequiDaviplata(),
              if (_metodoSeleccionado ==
                  WompiMetodoPago.transferenciaPseBancolombia)
                _buildFormularioPseBancolombia(),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEEF2F6)),
              const SizedBox(height: 12),

              // Sello de ciberseguridad Wompi SHA-256
              Row(
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 15,
                    color: _tealCheck,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Wompi Bancolombia · Firma SHA-256 (${_firmaSha256.substring(0, 10)}...)',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _abrirCheckoutExternoWompi,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Checkout web ↗',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Leyenda de seguridad: nada se almacena, todo está encriptado por Wompi
        _buildLeyendaSeguridadEncriptacionWompi(),
        const SizedBox(height: 22),

        // Barra inferior: Volver | Pagar $100 COP ->
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _procesandoPago
                  ? null
                  : () => setState(() => _pasoActual = 1),
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Volver',
                style: TextStyle(
                  color: _navy,
                  fontSize: 14.8,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _procesandoPago ? null : _ejecutarPagoWompi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _procesandoPago
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Validando pago en Wompi...',
                            style: TextStyle(
                              fontSize: 14.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Pagar ${rol.precioFormateadoCop}',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormularioTarjeta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.credit_card_rounded, color: _navy, size: 22),
        const SizedBox(height: 12),
        _buildFieldLabel('Número de tarjeta'),
        TextField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
            _CardNumberSpacingFormatter(),
          ],
          style: const TextStyle(
            color: _navy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration(hint: '1234 5678 9012 3456'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Fecha de expiración'),
                  TextField(
                    controller: _cardExpiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      _CardExpiryDateFormatter(),
                    ],
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _inputDecoration(hint: 'MM / AA'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('CVV'),
                  TextField(
                    controller: _cardCvvController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _inputDecoration(
                      hint: '123',
                      suffixIcon: const Icon(
                        Icons.credit_score_rounded,
                        color: _navy,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('Nombre del titular'),
        TextField(
          controller: _cardHolderController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
            color: _navy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration(hint: 'Como aparece en la tarjeta'),
        ),
      ],
    );
  }

  Widget _buildFormularioNequiDaviplata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Selecciona tu billetera'),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Nequi'),
                selected: _billeteraMovil == 'Nequi',
                onSelected: (_) => setState(() => _billeteraMovil = 'Nequi'),
                selectedColor: const Color(0xFFE6F4F1),
                labelStyle: TextStyle(
                  color: _navy,
                  fontWeight: _billeteraMovil == 'Nequi'
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                label: const Text('Daviplata'),
                selected: _billeteraMovil == 'Daviplata',
                onSelected: (_) =>
                    setState(() => _billeteraMovil = 'Daviplata'),
                selectedColor: const Color(0xFFE6F4F1),
                labelStyle: TextStyle(
                  color: _navy,
                  fontWeight: _billeteraMovil == 'Daviplata'
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('Número de celular de $_billeteraMovil'),
        TextField(
          controller: _celularBilleteraController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: const TextStyle(
            color: _navy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration(hint: '300 123 4567'),
        ),
      ],
    );
  }

  Widget _buildFormularioPseBancolombia() {
    const bancos = <String>[
      'Bancolombia',
      'Nequi',
      'Banco de Bogotá',
      'Davivienda',
      'BBVA Colombia',
      'Banco de Occidente',
      'Banco Popular',
      'Scotiabank Colpatria',
      'Banco Caja Social',
      'AV Villas',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Entidad bancaria PSE'),
        DropdownButtonFormField<String>(
          initialValue: _bancoPse,
          decoration: _inputDecoration(hint: 'Selecciona tu banco'),
          items: [
            for (final b in bancos)
              DropdownMenuItem<String>(
                value: b,
                child: Text(
                  b,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _bancoPse = v);
          },
        ),
        const SizedBox(height: 14),
        _buildFieldLabel('Número de documento o NIT del titular'),
        TextField(
          controller: _documentoPseController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          style: const TextStyle(
            color: _navy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration(hint: 'Ej: 1098765432'),
        ),
      ],
    );
  }

  Widget _buildLeyendaSeguridadEncriptacionWompi() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.enhanced_encryption_rounded,
              color: _tealCheck,
              size: 22,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cero almacenamiento · Encriptación segura por Wompi Bancolombia',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tus datos de tarjeta de crédito o débito, código CVV, credenciales de botón Nequi, Daviplata y transferencias bancarias por PSE o Bancolombia no son almacenados por nadie. Toda la información es encriptada y procesada directamente por Wompi de manera 100% segura bajo estándares PCI-DSS.',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12.4,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: _navy,
          fontSize: 13.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF6F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navy, width: 1.6),
      ),
    );
  }

  // ===========================================================================
  // VISTA 4: "¡LISTO!" - CUENTA ACTIVADA Y ROL PERSONA ASIGNADO
  // ===========================================================================

  Widget _buildPaso3ExitoConfirmacion({required bool isMobile}) {
    final rol = _rolConfig;
    final receipt = _reciboAprobado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Círculo grande verde con check y confeti alrededor
        SizedBox(
          height: 112,
          width: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _ConfettiCelebrationPainter()),
              ),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: _tealCheck,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _tealCheck.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '¡Listo!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _navy,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tu cuenta ha sido activada correctamente.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _subtitleSlate,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),

        // Recuadro informativo con ícono de escudo verificado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F7FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3ECF5)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: _tealCheck,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ya puedes explorar toda la información de contratación pública en un solo lugar.',
                      style: TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rol habilitado: ${rol.nombre} · Pago Wompi APPROVED (${rol.precioFormateadoCop})'
                      '${receipt != null ? " · Ref: ${receipt.reference.substring(0, 15)}" : ""}',
                      style: const TextStyle(
                        color: _tealCheck,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Roles activos acumulados en tu cuenta: ${AuthService.getActiveUserRoleDisplayLabel()}',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 11.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Botón principal "Ir al inicio ->"
        SizedBox(
          width: 280,
          height: 54,
          child: ElevatedButton(
            onPressed: _irAlInicioPlataforma,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ir al inicio',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, size: 19),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _irAMiPerfil,
          child: const Text(
            'Ver mi perfil',
            style: TextStyle(
              color: _navy,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSuccessBottomBanner({required bool isMobile}) {
    return SizedBox(
      height: isMobile ? 135 : 155,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            AuthBgAssetData.bytes,
            fit: BoxFit.cover,
            alignment: const Alignment(0.35, -0.15),
            gaplessPlayback: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFCFAF5),
                  Color(0x99FCFAF5),
                  Color(0x00FCFAF5),
                ],
                stops: [0.0, 0.25, 0.65],
              ),
            ),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            width: 210,
            height: 110,
            child: IgnorePointer(
              child: CustomPaint(painter: _MiniFlagWavePainter()),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FORMATEADORES DE CAMPOS DE TARJETA (NÚMERO Y FECHA DE EXPIRACIÓN MM/AA)
// =============================================================================

class _CardNumberSpacingFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CardExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// =============================================================================
// ILUSTRACIONES PERSONALIZADAS DE LA PASARELA (FIELES A LA IMAGEN 2)
// =============================================================================

class _PlanBadgeIllustrationPainter extends CustomPainter {
  const _PlanBadgeIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Círculo amarillo suave de fondo
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.52),
      32,
      Paint()..color = const Color(0xFFFEF0C7),
    );

    // Tarjeta trasera dorada
    canvas.save();
    canvas.translate(size.width * 0.25, size.height * 0.18);
    canvas.rotate(-0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 36, 42),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFFF5B82E),
    );
    canvas.restore();

    // Tarjeta frontal azul oscuro con check
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.28, size.height * 0.20, 38, 44),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF143666),
    );

    // Check blanco dentro de la tarjeta azul
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.40, size.height * 0.45)
      ..lineTo(size.width * 0.46, size.height * 0.52)
      ..lineTo(size.width * 0.56, size.height * 0.38);
    canvas.drawPath(path, checkPaint);

    // Sello dorado de verificación abajo a la derecha
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.70),
      11,
      Paint()..color = const Color(0xFFF5B82E),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardSecurityIllustrationPainter extends CustomPainter {
  const _CardSecurityIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * 0.14, size.height * 0.12);
    canvas.rotate(0.14);

    // Cuerpo de la tarjeta azul marino
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 52, 34),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF143666),
    );

    // Banda superior y chip dorado
    canvas.drawRect(
      const Rect.fromLTWH(0, 7, 52, 6),
      Paint()..color = const Color(0xFF0A1D3B),
    );
    canvas.drawCircle(
      const Offset(39, 23),
      5.5,
      Paint()..color = const Color(0xFFF5B82E),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConfettiCelebrationPainter extends CustomPainter {
  const _ConfettiCelebrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final yellow = Paint()..color = const Color(0xFFF5B82E);
    final navy = Paint()..color = const Color(0xFF1D438A);

    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.25), 4, yellow);
    canvas.drawCircle(Offset(size.width * 0.80, size.height * 0.18), 4.5, yellow);
    canvas.drawCircle(Offset(size.width * 0.84, size.height * 0.68), 4, yellow);
    canvas.drawCircle(Offset(size.width * 0.24, size.height * 0.65), 3.5, yellow);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.42), 3.5, navy);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniFlagWavePainter extends CustomPainter {
  const _MiniFlagWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final yellow = Path()
      ..moveTo(w * 0.15, h)
      ..quadraticBezierTo(w * 0.55, h * 0.58, w, h * 0.35)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(yellow, Paint()..color = const Color(0xFFF6C624));

    final blue = Path()
      ..moveTo(w * 0.32, h)
      ..quadraticBezierTo(w * 0.65, h * 0.72, w, h * 0.54)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(blue, Paint()..color = const Color(0xFF1D438A));

    final red = Path()
      ..moveTo(w * 0.48, h)
      ..quadraticBezierTo(w * 0.75, h * 0.82, w, h * 0.68)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(red, Paint()..color = const Color(0xFFD32027));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

