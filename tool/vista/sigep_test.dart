// ignore_for_file: invalid_use_of_visible_for_testing_member
// Servidor público que solo está en el directorio del SIGEP, de punta a
// punta: búsqueda en Contratistas y su perfil con la hoja de vida.
// Necesita el intermediario:
//   flutter test tool/vista/sigep_test.dart --update-goldens \
//     --dart-define=SIGEP_PROXY=https://<sitio>/api/sigep
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
    HttpOverrides.global = null;
  });

  testWidgets('servidor público del SIGEP', (t) async {
    sesionConTodosLosRoles(true);
    addTearDown(() => sesionConTodosLosRoles(false));
    ventana(t, 1366, 1000);
    await t.pumpWidget(appCristal(const HomeScreen(initialIndex: 4)));
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(
      find.byType(TextField).first,
      'fabian alberto cuello redondo',
    );
    await t.pump(const Duration(milliseconds: 400));
    await esperarRed(t, 10);
    await capturar(t, 'sigep_busqueda');
    expect(find.textContaining('Cuello Redondo'), findsWidgets);

    await t.tap(find.text('Ver perfil').first);
    await t.pump(const Duration(milliseconds: 600));
    await esperarRed(t, 25);
    await capturar(t, 'sigep_perfil');
    expect(find.text('Hoja de vida en el SIGEP'), findsOneWidget);
  });
}
