// ignore_for_file: invalid_use_of_visible_for_testing_member
// Capturas de Alertas con lo seguido de ejemplo (entidades y una empresa).
//   flutter test tool/vista/alertas_test.dart --update-goldens
import 'dart:io';

import 'package:app_secop/screens/home_screen.dart';
import 'package:app_secop/services/seguimiento_service.dart';
import 'package:app_secop/widgets/collapsible_side_menu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_falso.dart';
import 'soporte.dart';

const _sena = Seguido(
  tipo: TipoSeguido.entidad,
  clave: '899999034',
  nombre: 'Servicio Nacional de Aprendizaje (SENA)',
  desdeIso: '2026-09-21',
  vistos: 3040,
);
const _cesar = Seguido(
  tipo: TipoSeguido.entidad,
  clave: '892399999',
  nombre: 'Gobernación del Departamento del Cesar',
  desdeIso: '2026-09-21',
  vistos: 120,
);
const _findeter = Seguido(
  tipo: TipoSeguido.contratista,
  clave: '800096329',
  nombre: 'Financiera de Desarrollo Territorial S.A. (FINDETER)',
  desdeIso: '2026-09-21',
  vistos: 0,
);

void main() {
  setUpAll(() async {
    await cargarFuentes();
    SharedPreferences.setMockInitialValues({});
    await prepararFirebaseFalso();
    HttpOverrides.global = null;
  });

  for (final (nombre, ancho, alto) in [
    ('escritorio', 1366.0, 860.0),
    ('movil', 390.0, 844.0),
  ]) {
    testWidgets('alertas $nombre', (t) async {
      sesionDeEjemplo(true);
      addTearDown(() => sesionDeEjemplo(false));
      SeguimientoService.fijarParaPrueba(
        const [_sena, _cesar, _findeter],
        {_sena.id: 3058, _cesar.id: 120, _findeter.id: 0},
      );
      ventana(t, ancho, alto);
      await t.pumpWidget(
        appCristal(
          const HomeScreen(initialIndex: CollapsibleSideMenu.indiceAlertas),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Servicio Nacional de Aprendizaje (SENA)'));
      await esperarRed(t, 8);
      await capturar(t, 'alertas_$nombre');
    });
  }
}
