// ignore_for_file: invalid_use_of_visible_for_testing_member
// Frente 3: búsqueda + modalidad en la pestaña Contratos del perfil de
// entidad (Alcaldía de Valledupar), con datos reales.
//   flutter test tool/vista/filtros_entidad_test.dart --update-goldens
import 'dart:io';

import 'package:app_secop/screens/perfil_entidad_screen.dart';
import 'package:app_secop/screens/sections/entidades_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_falso.dart';
import 'soporte.dart';

const _valledupar = EntitySummaryRecord(
  name: 'ALCALDIA MUNICIPAL DE VALLEDUPAR',
  nit: '800098911',
  location: 'Valledupar, Cesar',
  municipio: 'Valledupar',
  departamento: 'Cesar',
  category: 'Municipal',
  emblemType: EntityEmblemType.alcaldiaCoatOfArms,
  contractsCount: 0,
  contractsFormatted: '—',
  amountMillions: 0,
  amountFormatted: '—',
  dependenciesCount: 0,
  uniqueContractors: 0,
  secopKeywords: ['VALLEDUPAR'],
);

void main() {
  setUpAll(() async {
    await cargarFuentes();
    SharedPreferences.setMockInitialValues({});
    await prepararFirebaseFalso();
    HttpOverrides.global = null;
  });

  testWidgets('modalidad y luego búsqueda se suman', (t) async {
    sesionConTodosLosRoles(true);
    addTearDown(() => sesionConTodosLosRoles(false));
    ventana(t, 1366, 1000);
    await t.pumpWidget(appCristal(const PerfilEntidadScreen(entity: _valledupar)));
    await t.pump(const Duration(milliseconds: 400));
    await esperarRed(t, 12);
    await t.tap(find.text('Contratos').first, warnIfMissed: false);
    await esperarRed(t, 4);
    await t.tap(find.text('Filtros').first, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(
      find.textContaining('Licitación pública ·').first,
      warnIfMissed: false,
    );
    await esperarRed(t, 6);
    await t.enterText(find.byType(TextField).first, 'bienes');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await esperarRed(t, 16);
    await capturar(t, 'entidad_modalidad_y_busqueda');
    expect(find.textContaining('Búsqueda: "bienes"'), findsWidgets);
    expect(find.textContaining('Modalidad: Licitación pública'), findsWidgets);
  });
}
