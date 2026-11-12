// ignore_for_file: invalid_use_of_visible_for_testing_member
// Capturas de las secciones del panel, dentro del armazón real y con datos
// de Datos Abiertos (red real).
//   flutter test tool/vista/secciones_test.dart --update-goldens
import 'dart:io';

import 'package:app_secop/screens/home_screen.dart';
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
    // Red real: las pruebas la bloquean por defecto.
    HttpOverrides.global = null;
  });

  Future<void> tomar(
    WidgetTester tester,
    String nombre,
    Widget pantalla, {
    double ancho = 1366,
    double alto = 860,
    int espera = 9,
  }) async {
    sesionConTodosLosRoles(true);
    addTearDown(() => sesionConTodosLosRoles(false));
    ventana(tester, ancho, alto);
    await tester.pumpWidget(appCristal(pantalla));
    await tester.pump(const Duration(milliseconds: 400));
    await esperarRed(tester, espera);
    await capturar(tester, nombre);
  }

  const secciones = {
    'contratos': 2,
    'entidades': 3,
    'contratistas': 4,
    'favoritos': 7,
    'gestion': 8,
    'proyeccion': 9,
  };
  for (final e in secciones.entries) {
    testWidgets(
      e.key,
      (t) => tomar(t, 'sec_${e.key}', HomeScreen(initialIndex: e.value)),
    );
    testWidgets(
      '${e.key} móvil',
      (t) => tomar(
        t,
        'sec_${e.key}_movil',
        HomeScreen(initialIndex: e.value),
        ancho: 390,
        alto: 844,
      ),
    );
  }

  for (final consulta in ['fabian cuello', 'gustavo petro']) {
    testWidgets('contratistas: $consulta', (t) async {
      sesionConTodosLosRoles(true);
      addTearDown(() => sesionConTodosLosRoles(false));
      ventana(t, 1366, 1000);
      await t.pumpWidget(appCristal(const HomeScreen(initialIndex: 4)));
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(find.byType(TextField).first, consulta);
      await t.pump(const Duration(milliseconds: 400));
      await esperarRed(t, 10);
      await capturar(t, 'buscar_${consulta.replaceAll(' ', '_')}');
    });
  }
}
