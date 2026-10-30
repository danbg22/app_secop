import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'screens/escoger_rol_screen.dart';
import 'screens/pasarela_pago_wompi_screen.dart';
import 'screens/perfil_usuario_screen.dart';
import 'screens/planes_screen.dart';
import 'screens/login_screen.dart';
import 'screens/portada_screen.dart';
import 'screens/registro_screen.dart';
import 'services/auth_service.dart';
import 'utils/app_scroll_behavior.dart';
import 'widgets/route_security_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthService.restoreSessionFromPrefs();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Contrata Legal',
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFFDF8),
        primaryColor: const Color(0xFF1A2B4C),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1A2B4C),
          secondary: Color(0xFFFFD54F),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: Color(0xFF1A2B4C),
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            color: Color(0xFF1A2B4C),
            fontWeight: FontWeight.bold,
          ),
          displaySmall: TextStyle(
            color: Color(0xFF1A2B4C),
            fontWeight: FontWeight.bold,
          ),
          headlineLarge: TextStyle(
            color: Color(0xFF1A2B4C),
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: Color(0xFF1A2B4C),
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            color: Color(0xFF1A2B4C),
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            color: Color(0xFF1A2B4C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const AuthGate(),
      routes: {
        '/portada': (context) => const PortadaScreen(),
        '/auth': (context) => const LoginScreen(),
        '/registro': (context) => const EscogerRolScreen(),
        '/escoger-rol': (context) => const EscogerRolScreen(),
        '/registro-datos': (context) => const RegistroScreen(),
        '/pasarela-wompi': (context) => const RouteSecurityGuard(
              child: PasarelaPagoWompiScreen(),
            ),
        '/planes': (context) => const RouteSecurityGuard(
              child: PlanesScreen(),
            ),
        '/perfil': (context) => const RouteSecurityGuard(
              child: PerfilUsuarioScreen(),
            ),
        '/home': (context) => const AuthGate(),
      },
      onUnknownRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const AuthGate(),
      ),
    );
  }
}
