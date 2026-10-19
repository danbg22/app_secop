import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'screens/planes_screen.dart';
import 'screens/login_screen.dart';
import 'screens/portada_screen.dart';
import 'screens/registro_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Contrata Legal',
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
        '/registro': (context) => const RegistroScreen(),
        '/planes': (context) => const PlanesScreen(),
        '/home': (context) => const AuthGate(),
      },
    );
  }
}
