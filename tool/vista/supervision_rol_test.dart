// ignore_for_file: invalid_use_of_visible_for_testing_member
// Capturas del rol Supervisión de contratos: tarjeta y subroles al escoger
// rol. (La sección necesita Firestore, que estas pruebas no simulan.)
//   flutter test tool/vista/supervision_rol_test.dart --update-goldens
import 'dart:io';

import 'package:app_secop/screens/escoger_rol_screen.dart';
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
    HttpOverrides.global = null;
  });

  Future<void> abrir(
    WidgetTester tester,
    Widget pantalla, {
    double ancho = 1366,
    double alto = 900,
  }) async {
    ventana(tester, ancho, alto);
    await tester.pumpWidget(appCristal(pantalla));
    await tester.pump(const Duration(milliseconds: 400));
    await cargarImagenes(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final (nombre, ancho, alto) in [
    ('escritorio', 1366.0, 900.0),
    ('tableta', 820.0, 1180.0),
    ('movil', 390.0, 844.0),
  ]) {
    testWidgets('escoger rol $nombre', (t) async {
      await abrir(t, const EscogerRolScreen(), ancho: ancho, alto: alto);
      await capturar(t, 'sup_escoger_rol_$nombre');
    });
  }

  for (final (nombre, ancho, alto) in [
    ('escritorio', 1366.0, 900.0),
    ('movil', 390.0, 844.0),
  ]) {
    testWidgets('subroles $nombre', (t) async {
      await abrir(t, const EscogerRolScreen(), ancho: ancho, alto: alto);
      final tarjeta = find.text('Supervisión de\ncontratos');
      await t.ensureVisible(tarjeta);
      await t.pump();
      await t.tap(tarjeta);
      await t.pump(const Duration(milliseconds: 600));
      await cargarImagenes(t);
      await capturar(t, 'sup_subroles_$nombre');
    });
  }
}
