// ignore_for_file: invalid_use_of_visible_for_testing_member
// Capturas de pantallas reales con el tema Cristal, para revisar el diseño.
//   flutter test tool/vista/pantallas_test.dart --update-goldens
import 'package:app_secop/screens/escoger_rol_screen.dart';
import 'package:app_secop/screens/home_screen.dart';
import 'package:app_secop/screens/login_screen.dart';
import 'package:app_secop/screens/portada_screen.dart';
import 'package:app_secop/screens/registro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_falso.dart';
import 'soporte.dart';

void main() {
  setUpAll(() async {
    await cargarFuentes();
    SharedPreferences.setMockInitialValues({});
    await prepararFirebaseFalso();
  });

  Future<void> tomar(
    WidgetTester tester,
    String nombre,
    Widget pantalla, {
    double ancho = 1366,
    double alto = 860,
    bool todosLosRoles = false,
  }) async {
    sesionConTodosLosRoles(todosLosRoles);
    addTearDown(() => sesionConTodosLosRoles(false));
    ventana(tester, ancho, alto);
    await tester.pumpWidget(appCristal(pantalla));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await capturar(tester, nombre);
  }

  testWidgets('portada', (t) => tomar(t, 'portada', const PortadaScreen()));
  testWidgets(
    'portada móvil',
    (t) => tomar(t, 'portada_movil', const PortadaScreen(), ancho: 390, alto: 844),
  );
  testWidgets('login', (t) => tomar(t, 'login', const LoginScreen()));
  testWidgets(
    'escoger rol',
    (t) => tomar(t, 'escoger_rol', const EscogerRolScreen()),
  );
  testWidgets('registro', (t) => tomar(t, 'registro', const RegistroScreen()));
  testWidgets('inicio', (t) => tomar(t, 'inicio', const HomeScreen()));
  testWidgets(
    'inicio móvil',
    (t) => tomar(t, 'inicio_movil', const HomeScreen(), ancho: 390, alto: 844),
  );
  testWidgets(
    'inicio con todos los roles',
    (t) => tomar(t, 'inicio_roles', const HomeScreen(), todosLosRoles: true),
  );
  testWidgets(
    'inicio móvil con todos los roles',
    (t) => tomar(
      t,
      'inicio_movil_roles',
      const HomeScreen(),
      ancho: 390,
      alto: 844,
      todosLosRoles: true,
    ),
  );
}
