import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'screens/escoger_rol_screen.dart';
import 'screens/pasarela_pago_wompi_screen.dart';
import 'screens/perfil_usuario_screen.dart';
import 'screens/proceso_compartido_screen.dart';
import 'screens/planes_screen.dart';
import 'screens/soporte_buzon_screen.dart';
import 'screens/portal_contratista_invitado_screen.dart';
import 'screens/login_screen.dart';
import 'screens/portada_screen.dart';
import 'screens/registro_screen.dart';
import 'services/acceso_planes.dart';
import 'services/auth_service.dart';
import 'services/datos_abiertos.dart';
import 'services/juridico_contratacion_service.dart';
import 'tema/cristal.dart';
import 'utils/app_scroll_behavior.dart';
import 'utils/enlace_proceso.dart';
import 'utils/retorno_wompi.dart';
import 'widgets/collapsible_side_menu.dart';
import 'widgets/route_security_guard.dart';
import 'services/app_instalable_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activarAppCheck();
  await AuthService.restoreSessionFromPrefs();
  AuthService.refrescarVerificacionAlIniciar();
  // Consultas a Datos Abiertos de la última hora, guardadas en el navegador.
  await DatosAbiertos.iniciarPersistencia();
  // Modo claro u oscuro que eligió la persona en este navegador.
  await Cristal.cargarModo();
  runApp(const MyApp());
}

/// App Check certifica que las solicitudes a Firebase (incluido Gemini vía
/// Firebase AI Logic) provienen de esta app. En web requiere la clave de
/// sitio de Fraud Defense (reCAPTCHA Enterprise) del proyecto secop-ia, que
/// es pública (va en el navegador) y solo funciona en los dominios
/// registrados; se puede cambiar con `--dart-define=RECAPTCHA_SITE_KEY=...`.
Future<void> _activarAppCheck() async {
  const recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
    defaultValue: '6LcJpCcuAAAAALpmdncwH8xkiLBC9NavbJ3KluvK',
  );
  if (kIsWeb && recaptchaSiteKey.isEmpty) {
    debugPrint('App Check desactivado: falta RECAPTCHA_SITE_KEY.');
    return;
  }
  // En el computador local (flutter run) la clave no vale: solo funciona en
  // los dominios registrados en Fraud Defense. Cuando App Check se exija en
  // la consola, para probar en local hay que registrar un token de
  // depuración.
  if (kIsWeb && const {'localhost', '127.0.0.1'}.contains(Uri.base.host)) {
    debugPrint('App Check no se activa en local (${Uri.base.host}).');
    return;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: kIsWeb
          ? ReCaptchaEnterpriseProvider(recaptchaSiteKey)
          : null,
    );
  } catch (e) {
    debugPrint('No fue posible activar App Check: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _procesoTrasAutenticacion;

  void _limpiarDestino(String id) {
    if (_procesoTrasAutenticacion == id) _procesoTrasAutenticacion = null;
  }

  Widget _procesoCompartido(String id) => AuthGate(
    visitante: ProcesoCompartidoScreen(
      key: ValueKey('vista-$id'),
      id: id,
      soloEncabezado: true,
      onVistaActiva: () => _limpiarDestino(id),
      onAutenticar: (ruta) {
        _procesoTrasAutenticacion = id;
        _navegador.currentState!.pushNamed(ruta);
      },
    ),
    autenticado: ProcesoCompartidoScreen(
      key: ValueKey('detalle-$id'),
      id: id,
      soloEncabezado: false,
      onVistaActiva: () => _limpiarDestino(id),
    ),
  );

  final _navegador = GlobalKey<NavigatorState>();

  final _mensajes = GlobalKey<ScaffoldMessengerState>();
  late final AppLifecycleListener _ciclo;
  String? _uidVisto;
  Set<String> _rolesVistos = {};
  bool _reinicioPendiente = false;
  bool _retornoProcesado = false;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onResume: () {
        unawaited(AccesoPlanes.refrescar());
        unawaited(AppInstalable.comprobarVersion());
      },
    );
    AppInstalable.iniciar();
    AppInstalable.hayVersionNueva.addListener(_avisarVersionNueva);
    AccesoPlanes.cambios.addListener(_alCambiarAcceso);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _alCambiarAcceso();
    });
  }

  @override
  void dispose() {
    AppInstalable.hayVersionNueva.removeListener(_avisarVersionNueva);
    AccesoPlanes.cambios.removeListener(_alCambiarAcceso);
    _ciclo.dispose();
    super.dispose();
  }

  /// Se publicó una versión nueva mientras la app estaba abierta: se ofrece
  /// recargar sin interrumpir lo que el usuario esté haciendo.
  void _avisarVersionNueva() {
    if (!AppInstalable.hayVersionNueva.value) return;
    _mensajes.currentState?.showSnackBar(
      SnackBar(
        content: const Text('Hay una nueva versión de Contrata Legal.'),
        duration: const Duration(days: 1),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Actualizar',
          onPressed: AppInstalable.recargar,
        ),
      ),
    );
  }

  void _alCambiarAcceso() {
    final uid = AccesoPlanes.uid;
    if (uid != _uidVisto) CollapsibleSideMenu.reiniciarParaSesion();
    final roles = AuthService.getActiveUserRoles().toSet();
    if (uid == _uidVisto &&
        uid != null &&
        !roles.containsAll(_rolesVistos) &&
        !_reinicioPendiente) {
      _reinicioPendiente = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reinicioPendiente = false;
        if (!mounted || AccesoPlanes.uid != uid) return;
        _navegador.currentState?.pushNamedAndRemoveUntil('/home', (_) => false);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    _uidVisto = uid;
    _rolesVistos = roles;

    if (!kIsWeb ||
        uid == null ||
        _retornoProcesado ||
        AuthService.isActiveUserAdmin) {
      return;
    }
    final params = Uri.base.queryParameters;
    final id = params['id'];
    if (params['retorno_wompi'] == '1' && id != null) {
      _retornoProcesado = true;
      limpiarRetornoWompi();
      unawaited(_confirmarRetorno(id, uid));
    }
  }

  Future<void> _confirmarRetorno(String id, String uid) async {
    try {
      String? estado;
      for (var intento = 0; intento < 4; intento++) {
        if (!mounted || AccesoPlanes.uid != uid) return;
        estado = await AccesoPlanes.confirmarPago(id);
        if (estado != 'PENDING') break;
        if (intento < 3) await Future<void>.delayed(const Duration(seconds: 3));
      }
      if (mounted && AccesoPlanes.uid == uid) {
        _mensajes.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              estado == 'APPROVED'
                  ? 'Wompi confirmó el pago. Tu plan está activo.'
                  : switch (estado) {
                      'DECLINED' ||
                      'ERROR' ||
                      'VOIDED' => 'Wompi indicó que el pago no se completó.',
                      _ => 'Estamos esperando la confirmación de Wompi. El estado se actualizará automáticamente.',
                    },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted && AccesoPlanes.uid == uid) {
        _mensajes.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'La confirmación de Wompi aún está pendiente. El estado se actualizará automáticamente.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Al cambiar entre claro y oscuro se reconstruye toda la app con el
    // tema nuevo, sin perder la ruta ni lo escrito.
    return ModoCristalScope(builder: (context) => _app());
  }

  Widget _app() {
    return MaterialApp(
      navigatorKey: _navegador,
      scaffoldMessengerKey: _mensajes,
      debugShowCheckedModeBanner: false,
      title: 'Contrata Legal',
      scrollBehavior: const AppScrollBehavior(),
      // Lenguaje visual "Liquid Glass" (lib/tema): vidrio en modo oscuro o
      // claro y un único fondo de manchas difuminadas detrás de las rutas.
      theme: temaCristal(),
      // Sin animación del tema: el cambio de modo repinta todo de una vez.
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => FondoCristal(child: child!),
      home: const AuthGate(),
      routes: {
        '/portada': (context) {
          _procesoTrasAutenticacion = null;
          return const PortadaScreen();
        },
        '/auth': (context) => const LoginScreen(),
        '/registro': (context) => const EscogerRolScreen(),
        '/escoger-rol': (context) => const EscogerRolScreen(),
        '/registro-datos': (context) => const RegistroScreen(),
        '/pasarela-wompi': (context) => const RouteSecurityGuard(
          allowWhenPaymentPending: true,
          child: PasarelaPagoWompiScreen(),
        ),
        '/planes': (context) => const RouteSecurityGuard(child: PlanesScreen()),
        '/mis-solicitudes': (_) =>
            const RouteSecurityGuard(child: MisMensajesSoporteScreen()),
        '/perfil': (context) =>
            const RouteSecurityGuard(child: PerfilUsuarioScreen()),
      },
      onGenerateRoute: (settings) {
        final rawName = settings.name ?? '';
        final uri = Uri.tryParse(rawName);
        if (rawName == '/home') {
          final id = _procesoTrasAutenticacion;
          return MaterialPageRoute<void>(
            settings: id == null
                ? settings
                : RouteSettings(name: rutaProcesoCompartido(id)),
            builder: (_) =>
                id == null ? const AuthGate() : _procesoCompartido(id),
          );
        }
        if (uri != null &&
            uri.pathSegments.length == 2 &&
            uri.pathSegments.first == 'proceso-compartido') {
          final id = uri.pathSegments.last;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => _procesoCompartido(id),
          );
        }
        if (rawName.startsWith('/invitado-contrato')) {
          final parsed = Uri.tryParse(rawName);
          var token = (parsed?.queryParameters['token'] ?? '').trim();
          if (token.isEmpty) {
            token = JuridicoContratacionService.extraerTokenInvitadoDeUri(
              Uri.base,
            );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => PortalContratistaInvitadoScreen(token: token),
          );
        }
        return null;
      },
      onUnknownRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const AuthGate()),
    );
  }
}
