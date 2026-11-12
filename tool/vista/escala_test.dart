// ignore_for_file: invalid_use_of_visible_for_testing_member
// Cabeceras con escala de pantalla fraccionaria (125 % en Windows): ahí el
// borde inferior de la foto cae en medio píxel.
//   flutter test tool/vista/escala_test.dart --update-goldens
import 'dart:io';

import 'package:app_secop/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_falso.dart';
import 'soporte.dart';

void main() {
  setUpAll(() async {
    await cargarFuentes();
    SharedPreferences.setMockInitialValues({});
    await prepararFirebaseFalso();
    HttpOverrides.global = null;
  });

  for (final (nombre, indice) in [
    ('contratistas', 4),
    ('contratos', 2),
    ('entidades', 3),
  ]) {
    testWidgets('$nombre al 125 %', (t) async {
      sesionConTodosLosRoles(true);
      addTearDown(() => sesionConTodosLosRoles(false));
      ventana(t, 1536, 700, escala: 1.25);
      await t.pumpWidget(appCristal(HomeScreen(initialIndex: indice)));
      await t.pump(const Duration(milliseconds: 400));
      await esperarRed(t, 4);
      await capturar(t, 'escala125_$nombre');
    });
  }
}
