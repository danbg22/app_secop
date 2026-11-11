// ignore_for_file: invalid_use_of_visible_for_testing_member
// Capturas de las pantallas de detalle (perfil de entidad, contrato,
// contratista, perfil de usuario, pago), con datos de Datos Abiertos.
//   flutter test tool/vista/detalle_test.dart --update-goldens
import 'dart:io';

import 'package:app_secop/screens/home_screen.dart';
import 'package:app_secop/screens/pasarela_pago_wompi_screen.dart';
import 'package:app_secop/screens/perfil_entidad_screen.dart';
import 'package:app_secop/screens/perfil_usuario_screen.dart';
import 'package:app_secop/screens/sections/entidades_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_falso.dart';
import 'soporte.dart';

const _sena = EntitySummaryRecord(
  name: 'SERVICIO NACIONAL DE APRENDIZAJE (SENA)',
  nit: '899999034',
  location: 'Bogotá D.C.',
  municipio: 'Bogotá D.C.',
  departamento: 'Distrito Capital de Bogotá',
  category: 'Nacional',
  emblemType: EntityEmblemType.educacionShield,
  contractsCount: 0,
  contractsFormatted: '—',
  amountMillions: 0,
  amountFormatted: '—',
  dependenciesCount: 0,
  uniqueContractors: 0,
  secopKeywords: ['SENA'],
);

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
    double alto = 860,
    int espera = 10,
    bool ejemplo = false,
  }) async {
    ejemplo ? sesionDeEjemplo(true) : sesionConTodosLosRoles(true);
    addTearDown(() => sesionConTodosLosRoles(false));
    ventana(tester, ancho, alto);
    await tester.pumpWidget(appCristal(pantalla));
    await tester.pump(const Duration(milliseconds: 400));
    await esperarRed(tester, espera);
  }

  Future<void> tocar(WidgetTester tester, Finder f, {int espera = 6}) async {
    await tester.tap(f.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    await esperarRed(tester, espera);
  }

  testWidgets('perfil entidad', (t) async {
    await abrir(t, const PerfilEntidadScreen(entity: _sena), espera: 14);
    await capturar(t, 'ent_resumen');
    for (final tab in ['Contratos', 'Dependencias', 'Contratistas']) {
      await tocar(t, find.text(tab), espera: 9);
      await capturar(t, 'ent_${tab.toLowerCase()}');
    }
  });

  testWidgets('perfil entidad móvil', (t) async {
    await abrir(
      t,
      const PerfilEntidadScreen(entity: _sena),
      ancho: 390,
      alto: 844,
      espera: 14,
    );
    await capturar(t, 'ent_resumen_movil');
  });

  testWidgets('detalle de contrato', (t) async {
    await abrir(t, const HomeScreen(initialIndex: 2), espera: 9);
    await tocar(t, find.text('Ver detalle'), espera: 10);
    await capturar(t, 'det_resumen');
    await tocar(t, find.text('Documentos'), espera: 6);
    await capturar(t, 'det_documentos');
    await tocar(t, find.text('Copiloto IA'), espera: 3);
    await capturar(t, 'det_copiloto');
  });

  testWidgets('perfil de contratista', (t) async {
    await abrir(t, const HomeScreen(initialIndex: 4), espera: 8);
    await tocar(t, find.text('Ver perfil'), espera: 10);
    await capturar(t, 'contratista_perfil');
  });

  testWidgets('perfil de usuario', (t) async {
    await abrir(t, const PerfilUsuarioScreen(), espera: 3, ejemplo: true);
    await capturar(t, 'usuario_perfil');
  });

  testWidgets('pasarela de pago', (t) async {
    await abrir(t, const PasarelaPagoWompiScreen(), espera: 3);
    await capturar(t, 'pasarela');
  });
}
