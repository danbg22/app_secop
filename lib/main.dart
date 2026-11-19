import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'screens/escoger_rol_screen.dart';
import 'screens/pasarela_pago_wompi_screen.dart';
import 'screens/perfil_usuario_screen.dart';
import 'screens/planes_screen.dart';
import 'screens/portal_contratista_invitado_screen.dart';
import 'screens/login_screen.dart';
import 'screens/portada_screen.dart';
import 'screens/registro_screen.dart';
import 'services/auth_service.dart';
import 'services/datos_abiertos.dart';
import 'services/juridico_contratacion_service.dart';
import 'tema/cristal.dart';
import 'utils/app_scroll_behavior.dart';
import 'widgets/route_security_guard.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Al cambiar entre claro y oscuro se reconstruye toda la app con el
    // tema nuevo, sin perder la ruta ni lo escrito.
    return ModoCristalScope(builder: (context) => _app());
  }

  Widget _app() {
    return MaterialApp(
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
        '/portada': (context) => const PortadaScreen(),
        '/auth': (context) => const LoginScreen(),
        '/registro': (context) => const EscogerRolScreen(),
        '/escoger-rol': (context) => const EscogerRolScreen(),
        '/registro-datos': (context) => const RegistroScreen(),
        '/pasarela-wompi': (context) => const RouteSecurityGuard(
          allowWhenPaymentPending: true,
          child: PasarelaPagoWompiScreen(),
        ),
        '/planes': (context) => const RouteSecurityGuard(child: PlanesScreen()),
        '/perfil': (context) =>
            const RouteSecurityGuard(child: PerfilUsuarioScreen()),
        '/home': (context) => const AuthGate(),
      },
      onGenerateRoute: (settings) {
        final rawName = settings.name ?? '';
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
