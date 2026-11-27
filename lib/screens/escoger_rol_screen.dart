import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/acceso_planes.dart';
import '../services/payment_service.dart';
import 'login_screen.dart';
import 'pasarela_pago_wompi_screen.dart';
import 'registro_screen.dart';
import '../tema/cristal.dart';
import '../widgets/ilustracion_rol.dart';
import 'activacion_gratuita_screen.dart';

/// Fondo escénico unificado (Catedral colonial, montañas andinas, bandera de
/// Colombia y hojas botánicas) compartido por los 3 pasos del flujo:
/// Paso 1 (Escoger Rol) -> Paso 2 (Registro) -> Paso 3 (Pago Wompi).
/// Con `showScenicPhoto: false` conserva solo el fondo crema y los adornos
/// vectoriales, como en Portada e Inicio de sesión.
class OnboardingUnifiedBackground extends StatelessWidget {
  const OnboardingUnifiedBackground({
    super.key,
    required this.child,
    this.showScenicPhoto = true,
  });

  final Widget child;
  final bool showScenicPhoto;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (showScenicPhoto)
          // La foto de Valledupar a la derecha, fundida con el fondo.
          const Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.64,
              heightFactor: 1.0,
              child: FotoAmbiente(
                alineacion: Alignment(0.55, -0.15),
                opacidad: 0.72,
                inicio: 0.04,
                pleno: 0.82,
                fundidoInferior: 0.28,
                // El encabezado queda sobre el fondo liso.
                fundidoSuperior: 0.3,
              ),
            ),
          ),

        // Luz lateral con los colores de la bandera, difuminada hacia el
        // centro: le da color al inicio sin competir con el contenido.
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: MediaQuery.sizeOf(context).width < 640 ? 56 : 150,
          child: const IgnorePointer(
            child: CustomPaint(painter: _FranjaBanderaLateral()),
          ),
        ),

        // Cinta ondulada con la bandera de Colombia en la esquina inferior derecha
        const Positioned(
          right: 0,
          bottom: 0,
          width: 380,
          height: 210,
          child: IgnorePointer(
            child: CustomPaint(painter: _ColombiaFlagCornerPainter()),
          ),
        ),

        // Contenido interactivo de la pantalla
        child,
      ],
    );
  }
}

/// Logo de Contrata Legal recortado al área real del dibujo de
/// `assets/images/logo.png` (fondo transparente con márgenes amplios), sin
/// tarjeta de fondo. El recorte deja un pequeño margen alrededor para no
/// cortar la punta del mapa ni el pie de la "g".
class ContrataLegalHdLogo extends StatelessWidget {
  const ContrataLegalHdLogo({super.key, this.height = 56});

  /// Alto visible del logo (sin los márgenes transparentes del PNG).
  final double height;

  // Dibujo medido en el PNG: x 12,6 %–89,4 %, y 18,3 %–89,7 %.
  static const double _anchoVisible = 0.79;
  static const double _altoVisible = 0.74;
  static const Alignment _centroDibujo = Alignment(0.095, 0.31);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: _centroDibujo,
        widthFactor: _anchoVisible,
        heightFactor: _altoVisible,
        child: Image.asset(
          Cristal.logo,
          height: height / _altoVisible,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        ),
      ),
    );
  }
}

/// Barra superior unificada con botón Volver e indicador de pasos
/// (Paso 1 de 3, Paso 2 de 3, Paso 3 de 3) con el diseño exacto de puntos y barra dorada.
/// `showBrandLogo` se activa únicamente cuando la pantalla no tiene ya una tarjeta con logo propio,
/// evitando que el logo se vea duplicado.
class OnboardingUnifiedTopBar extends StatelessWidget {
  const OnboardingUnifiedTopBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.onBack,
    this.backLabel = 'Volver',
    this.showBrandLogo = false,
    this.trailing,
  });

  /// `totalSteps == 0` oculta el indicador de pasos (pantallas fuera del flujo).
  final int currentStep;
  final int totalSteps;
  final VoidCallback onBack;
  final String backLabel;
  final bool showBrandLogo;

  /// Contenido alineado a la derecha en lugar del indicador de pasos.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 680;
    final showSteps = totalSteps > 0;

    final stepIndicator = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 18,
        vertical: isMobile ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Cristal.vidrio,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Cristal.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 1; i <= totalSteps; i++) ...[
            if (i == currentStep) ...[
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: Cristal.dorado,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 6,
                decoration: BoxDecoration(
                  color: Cristal.dorado,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ] else if (i < currentStep) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Cristal.dorado,
                  shape: BoxShape.circle,
                ),
              ),
            ] else ...[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Cristal.vidrioIntenso,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            const SizedBox(width: 7),
          ],
          Container(
            width: 18,
            height: 4.5,
            decoration: BoxDecoration(
              color: Cristal.vidrioFuerte,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Paso $currentStep de $totalSteps',
            style: TextStyle(
              color: Cristal.texto,
              fontSize: isMobile ? 13.5 : 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    final backBtn = InkWell(
      hoverDuration: Cristal.micro,
      onTap: onBack,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 18,
          vertical: isMobile ? 9 : 11,
        ),
        decoration: BoxDecoration(
          color: Cristal.vidrio,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Cristal.borde, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_rounded,
              size: isMobile ? 18 : 20,
              color: Cristal.texto,
            ),
            const SizedBox(width: 8),
            Text(
              backLabel,
              style: TextStyle(
                color: Cristal.texto,
                fontSize: isMobile ? 13.5 : 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );

    if (isMobile) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              backBtn,
              if (showBrandLogo)
                const ContrataLegalHdLogo(height: 38)
              else if (showSteps)
                Flexible(child: stepIndicator),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(height: 10),
            trailing!,
          ] else if (showBrandLogo && showSteps) ...[
            const SizedBox(height: 10),
            stepIndicator,
          ],
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
              if (showBrandLogo) ...[
                const SizedBox(width: 14),
                const ContrataLegalHdLogo(height: 48),
              ],
            ],
          ),
        ),
        if (trailing != null)
          Align(alignment: Alignment.centerRight, child: trailing)
        else if (showSteps)
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
  String? _hoveredRoleId;

  /// Tarjeta que agrupa los perfiles de Supervisión de contratos: al tocarla se despliegan para escoger uno.
  static const RolPaqueteConfig _tarjetaSupervision = RolPaqueteConfig(
    id: AdminConfiguracionRolesYPagos.grupoSupervision,
    nombre: 'Supervisión de contratos',
    nombrePlan: 'Supervisión de contratos',
    etiquetaDestacada: 'Nuevo',
    descripcionCorta: 'Ejecución de contratos de prestación de servicios: el supervisor revisa y aprueba los informes y el contratista los presenta.',
    precioCop: 0,
    habilitadoParaRegistro: true,
    colorPrimarioHex: 0xFF0F766E,
    colorFondoIlustracionHex: 0xFFE0F2EF,
    colorBordeTarjetaHex: 0xFF0F766E,
    beneficiosPrincipales: <String>[],
    todosLosBeneficios: <String>[],
    permisosPlataforma: <String>[],
  );

  /// Roles en el orden del catálogo, con los subroles de un grupo reunidos
  /// en una sola tarjeta.
  List<RolPaqueteConfig> get _tarjetas {
    final lista = <RolPaqueteConfig>[];
    for (final rol in PaymentService.obtenerCatalogoRoles()) {
      if (rol.grupo == AdminConfiguracionRolesYPagos.grupoSupervision) {
        if (!lista.contains(_tarjetaSupervision)) {
          lista.add(_tarjetaSupervision);
        }
      } else {
        lista.add(rol);
      }
    }
    return lista;
  }

  static bool _esGrupo(RolPaqueteConfig rol) =>
      rol.id == AdminConfiguracionRolesYPagos.grupoSupervision;

  bool _yaTiene(RolPaqueteConfig rol) =>
      widget.modoAcumularRol &&
      AuthService.hasAuthorizedPlatformAccess &&
      AuthService.hasActiveRole(rol.id);

  String _precioTarjeta(RolPaqueteConfig rol) {
    final primerRegistro = !widget.modoAcumularRol;
    if (!_esGrupo(rol)) {
      return primerRegistro && rol.habilitadoParaRegistro && !rol.esGratuito
          ? 'Después, ${rol.precioMensualFormateado}'
          : rol.precioMensualFormateado;
    }
    final supervisor = PaymentService.obtenerConfiguracionRol(
      'supervisor_contratos',
    );
    return '${supervisor.precioMensualFormateado} para Supervisor · Otros perfiles gratis';
  }

  /// Despliega los subroles de Supervisión de contratos.
  Future<void> _escogerSubrol() async {
    final subroles = PaymentService.subrolesDe(
      AdminConfiguracionRolesYPagos.grupoSupervision,
    );
    final elegido = await mostrarDialogoCristal<RolPaqueteConfig>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Cristal.flotante,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Cristal.bordeFuerte),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Supervisión de contratos',
                  style: TextStyle(
                    color: Cristal.texto,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '¿Cómo vas a participar en la ejecución del contrato?',
                  style: TextStyle(color: Cristal.textoMedio, fontSize: 14),
                ),
                const SizedBox(height: 18),
                for (final rol in subroles) ...[
                  _OpcionSubrol(
                    rol: rol,
                    activo: _yaTiene(rol),
                    mostrarPrueba: !widget.modoAcumularRol && !rol.esGratuito,
                    onTap: () => Navigator.of(ctx).pop(rol),
                  ),
                  const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Cristal.textoSuave),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (elegido != null && mounted) await _seleccionarRol(elegido);
  }

  Future<void> _seleccionarRol(RolPaqueteConfig rol) async {
    if (_esGrupo(rol)) {
      await _escogerSubrol();
      return;
    }
    if (!rol.habilitadoParaRegistro) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Cristal.flotante,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Cristal.dorado,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Actualmente están habilitados Persona, Equipo jurídico entidad y Supervisión de contratos. El paquete "${rol.nombre}" (${rol.precioFormateadoCop}) estará disponible próximamente.',
                    style: TextStyle(
                      color: Cristal.texto,
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

    // Si el usuario tiene pago inicial obligatorio pendiente y vino a cambiar el rol a pagar:
    if (AuthService.requiresMandatoryWompiPayment) {
      await AuthService.updatePendingRegistrationRole(rol.id);
      if (!mounted) return;
      if (rol.esGratuito) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ActivacionGratuitaScreen(rolId: rol.id),
          ),
        );
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              PasarelaPagoWompiScreen(rolId: rol.id, esFlujoRegistro: true),
        ),
      );
      return;
    }

    // Si el usuario ya tiene cuenta activa y está comprando un módulo adicional (Roles acumulables):
    if (widget.modoAcumularRol && AuthService.hasAuthorizedPlatformAccess) {
      if (AuthService.hasActiveRole(rol.id) &&
          AccesoPlanes.estado?.rolPrueba != rol.id) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF15803D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: Row(
                children: [
                  Icon(Icons.verified_rounded, color: Cristal.texto, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ya tienes activo el rol "${rol.nombre}". Selecciona otro rol habilitado para acumular sus permisos y herramientas.',
                      style: TextStyle(
                        color: Cristal.texto,
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

      if (rol.esGratuito) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ActivacionGratuitaScreen(rolId: rol.id),
          ),
        );
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              PasarelaPagoWompiScreen(rolId: rol.id, esFlujoRegistro: false),
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

  Future<void> _irALogin() async {
    if (AuthService.requiresMandatoryWompiPayment) {
      await AuthService.signOut();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _regresar() async {
    // Seguridad estricta: si la cuenta aún no ha pagado y sale a Portada, cierra sesión primero.
    if (AuthService.requiresMandatoryWompiPayment) {
      await AuthService.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/portada', (route) => false);
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (widget.modoAcumularRol &&
        AuthService.hasAuthorizedPlatformAccess) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/portada');
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = _tarjetas;

    return SelectionArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                      constraints: BoxConstraints(
                        maxWidth: roles.length > 4 ? 1340 : 1180,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          OnboardingUnifiedTopBar(
                            currentStep: 1,
                            totalSteps: 2,
                            onBack: _regresar,
                            backLabel: widget.modoAcumularRol
                                ? 'Volver a la app'
                                : 'Portada',
                            showBrandLogo: true,
                          ),
                          SizedBox(height: isMobile ? 16 : 22),
                          Text(
                            widget.modoAcumularRol
                                ? 'Acumula un nuevo rol\nen tu cuenta actual'
                                : 'Elige el rol con el que\nquieres continuar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Cristal.texto,
                              fontSize: isMobile ? 26 : (isTablet ? 34 : 42),
                              fontWeight: FontWeight.w800,
                              height: 1.12,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.modoAcumularRol
                                ? 'Tus roles actuales (${AuthService.getActiveUserRoleDisplayLabel()}) se conservarán intactos.\nAl confirmar el pago en Wompi, el nuevo rol se sumará automáticamente sin cerrar tu sesión.'
                                : 'Prueba los planes de pago 30 días gratis. Crea tu cuenta sin tarjeta y suscríbete cuando quieras.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Cristal.textoMedio,
                              fontSize: isMobile ? 13.8 : 16,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          if (widget.modoAcumularRol &&
                              !AuthService.isActiveUserAdmin)
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (final rol in roles.expand(
                                  (rol) => _esGrupo(rol)
                                      ? PaymentService.subrolesDe(rol.id)
                                      : [rol],
                                ))
                                  if (!rol.esGratuito &&
                                      (AccesoPlanes.estado?.tienePagoMensual(
                                                rol.id,
                                              ) ==
                                              true ||
                                          AccesoPlanes.estado?.renovaciones
                                                  .containsKey(rol.id) ==
                                              true))
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  PasarelaPagoWompiScreen(
                                                    rolId: rol.id,
                                                    esFlujoRegistro: false,
                                                  ),
                                            ),
                                          ),
                                      icon: const Icon(Icons.payments_outlined),
                                      label: Text(
                                        'Suscripción · ${rol.nombre}',
                                      ),
                                    ),
                              ],
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
                                        precioDebajo: roles.length > 4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else if (isTablet)
                            Column(
                              children: [
                                for (int i = 0; i < roles.length; i += 2) ...[
                                  if (i > 0) const SizedBox(height: 16),
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _buildRoleCard(
                                            rol: roles[i],
                                            isMobile: false,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: i + 1 < roles.length
                                              ? _buildRoleCard(
                                                  rol: roles[i + 1],
                                                  isMobile: false,
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else
                            Column(
                              children: [
                                for (int i = 0; i < roles.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 16),
                                  _buildRoleCard(rol: roles[i], isMobile: true),
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
                                Text(
                                  '¿Ya tienes una cuenta registrada?',
                                  style: TextStyle(
                                    color: Cristal.textoMedio,
                                    fontSize: 13.8,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _irALogin,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Cristal.texto,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: Text(
                                    'Inicia sesión aquí →',
                                    style: TextStyle(
                                      color: Cristal.texto,
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
      ),
    );
  }

  Widget _buildRoleCard({
    required RolPaqueteConfig rol,
    required bool isMobile,
    bool precioDebajo = false,
  }) {
    final bool isPersona = rol.id == 'persona';
    // La cuenta puede sumar cada perfil por separado.
    final bool isAlreadyOwned = _esGrupo(rol)
        ? PaymentService.subrolesDe(rol.id).every(_yaTiene)
        : _yaTiene(rol);
    final grupo = _esGrupo(rol);
    final mostrarPrueba =
        !widget.modoAcumularRol &&
        rol.habilitadoParaRegistro &&
        (grupo || !rol.esGratuito);
    final etiquetaAccion = grupo
        ? 'Elegir perfil'
        : widget.modoAcumularRol
        ? 'Acumular rol'
        : mostrarPrueba
        ? 'Inicia tu prueba gratuita'
        : 'Seleccionar';
    final bool isHovered = _hoveredRoleId == rol.id;

    // El color del rol en su variante brillante, para el fondo oscuro.
    final Color luz = isPersona
        ? Cristal.dorado
        : Cristal.brillante(rol.colorPrimario);
    final Color borderColor = isAlreadyOwned
        ? Cristal.verde
        : (isPersona
              ? Cristal.dorado
              : (rol.habilitadoParaRegistro
                    ? luz.withValues(alpha: isHovered ? 0.9 : 0.5)
                    : (isHovered
                          ? luz.withValues(alpha: 0.45)
                          : Cristal.bordeFuerte)));

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRoleId = rol.id),
      onExit: (_) => setState(() => _hoveredRoleId = null),
      cursor: rol.habilitadoParaRegistro
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: () => _seleccionarRol(rol),
        // Vidrio de verdad: la tarjeta va sobre la foto.
        child: DesenfoqueCristal(
          radio: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: Cristal.micro,
            curve: Cristal.curvaMicro,
            decoration: BoxDecoration(
              color: isHovered
                  ? Cristal.vidrioOscuroEncima
                  : Cristal.vidrioOscuro,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: borderColor,
                width: isPersona ? 2.2 : 1.3,
              ),
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
                    child: IlustracionRol(rolId: rol.id),
                  ),
                ),
                const SizedBox(height: 8),

                // Título y precio: lado a lado si caben; en tarjetas angostas
                // (cinco por fila) el precio va debajo para no partir palabras.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Builder(
                    builder: (context) {
                      final titulo = Text(
                        rol.id == 'equipo_juridico'
                            ? 'Equipo jurídico\nentidad'
                            : _esGrupo(rol)
                            ? 'Supervisión de\ncontratos'
                            : rol.nombre,
                        style: TextStyle(
                          color: Cristal.texto,
                          fontSize: 20.5,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.4,
                        ),
                      );
                      final precio = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: luz.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: luz.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          _precioTarjeta(rol),
                          style: TextStyle(
                            color: luz,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      );
                      if (precioDebajo || mostrarPrueba || grupo) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titulo,
                            if (mostrarPrueba) ...[
                              const SizedBox(height: 6),
                              Text(
                                grupo
                                    ? 'Supervisor · 30 días gratis'
                                    : '30 días gratis',
                                style: TextStyle(
                                  color: luz,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            precio,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: titulo),
                          const SizedBox(width: 6),
                          precio,
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Descripción del rol (con "Consulta" en negrita para Persona como en la foto)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: isPersona
                      ? Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: Cristal.textoMedio,
                              fontSize: 13.5,
                              height: 1.42,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(
                                text: 'Consulta ',
                                style: TextStyle(
                                  color: Cristal.texto,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: 'información de contratos, entidades, contratistas y más. Ideal para usuarios individuales.',
                              ),
                            ],
                          ),
                        )
                      : Text(
                          rol.descripcionCorta,
                          style: TextStyle(
                            color: Cristal.textoMedio,
                            fontSize: 13.4,
                            height: 1.42,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),

                if (!isMobile) const Spacer() else const SizedBox(height: 18),
                const SizedBox(height: 16),

                // Botón Seleccionar / Acumular / Activo ->
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: isAlreadyOwned
                        ? OutlinedButton.icon(
                            onPressed: () => _seleccionarRol(rol),
                            icon: Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: Cristal.verde,
                            ),
                            label: Text(
                              'Rol activo en tu cuenta',
                              style: TextStyle(
                                color: Cristal.verde,
                                fontSize: 13.8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Cristal.verdeVidrio,
                              side: BorderSide(
                                color: Cristal.verdeBorde,
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                          )
                        : (rol.habilitadoParaRegistro
                              ? ElevatedButton(
                                  onPressed: () => _seleccionarRol(rol),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isPersona
                                        ? Cristal.doradoRelleno
                                        : luz,
                                    foregroundColor: Cristal.tinta,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          etiquetaAccion,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 17,
                                      ),
                                    ],
                                  ),
                                )
                              : OutlinedButton(
                                  onPressed: () => _seleccionarRol(rol),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Cristal.texto,
                                    backgroundColor: Cristal.vidrio,
                                    side: BorderSide(
                                      color: luz.withValues(alpha: 0.45),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Próximamente',
                                        style: TextStyle(
                                          color: Cristal.textoSuave,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(
                                        Icons.lock_clock_outlined,
                                        size: 17,
                                        color: Cristal.textoSuave,
                                      ),
                                    ],
                                  ),
                                )),
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

/// Opción de subrol dentro de Supervisión de contratos.
class _OpcionSubrol extends StatelessWidget {
  const _OpcionSubrol({
    required this.rol,
    required this.activo,
    required this.mostrarPrueba,
    required this.onTap,
  });

  final RolPaqueteConfig rol;
  final bool activo;
  final bool mostrarPrueba;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luz = Cristal.brillante(rol.colorPrimario);
    final angosto = MediaQuery.sizeOf(context).width < 480;
    return Material(
      color: Cristal.vidrio,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: activo ? Cristal.verdeBorde : luz.withValues(alpha: 0.45),
          width: 1.3,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverDuration: Cristal.micro,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!angosto) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: IlustracionRol(rolId: rol.id),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          rol.id == 'supervisor_contratos'
                              ? 'Supervisor'
                              : rol.nombre,
                          style: TextStyle(
                            color: Cristal.texto,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: luz.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: luz.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            mostrarPrueba
                                ? 'Después, ${rol.precioMensualFormateado}'
                                : rol.precioMensualFormateado,
                            style: TextStyle(
                              color: luz,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (activo)
                          Text(
                            'Activo en tu cuenta',
                            style: TextStyle(
                              color: Cristal.verde,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (mostrarPrueba) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Inicia tu prueba gratuita · 30 días',
                        style: TextStyle(
                          color: luz,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      rol.descripcionCorta,
                      style: TextStyle(
                        color: Cristal.textoMedio,
                        fontSize: 13.2,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final b in rol.beneficiosPrincipales)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: luz,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                b,
                                style: TextStyle(
                                  color: Cristal.texto,
                                  fontSize: 12.6,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Cristal.textoMedio),
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

/// Franja vertical amarillo, azul y rojo (proporciones de la bandera: 2-1-1)
/// que se desvanece hacia la derecha y se funde entre colores.
class _FranjaBanderaLateral extends CustomPainter {
  const _FranjaBanderaLateral();

  static const _bandas = [
    (Color(0xFFFCD116), 0.0, 0.5),
    (Color(0xFF003893), 0.5, 0.75),
    (Color(0xFFCE1126), 0.75, 1.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (color, desde, hasta) in _bandas) {
      final rect = Rect.fromLTRB(
        -size.width * 0.2,
        size.height * desde - 24,
        size.width,
        size.height * hasta + 24,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
          ..shader = LinearGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.35, 1],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
