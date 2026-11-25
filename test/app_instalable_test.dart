import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/app_instalable_service.dart';
import 'package:app_secop/widgets/boton_instalar_app.dart';

void main() {
  tearDown(() => AppInstalable.disponible.value = false);

  testWidgets('el botón de instalar solo aparece si el navegador lo permite', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BotonInstalarApp())),
    );
    expect(find.text('Instalar app'), findsNothing);

    AppInstalable.disponible.value = true;
    await tester.pump();
    expect(find.text('Instalar app'), findsOneWidget);
  });

  test('fuera del navegador no se busca versión nueva', () async {
    AppInstalable.iniciar();
    await AppInstalable.comprobarVersion();
    expect(AppInstalable.hayVersionNueva.value, isFalse);
  });
}
