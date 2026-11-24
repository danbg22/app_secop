// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';

import 'package:app_secop/screens/sections/entidades_section.dart';
import 'package:app_secop/services/datos_abiertos.dart';
import 'package:app_secop/tema/cristal.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _AuthDePrueba extends FirebaseAuthPlatform {
  @override
  UserPlatform? get currentUser => null;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    FirebaseAuthPlatform.instance = _AuthDePrueba();
    await Firebase.initializeApp();
  });

  tearDown(() {
    DatosAbiertos.clientePruebas = null;
    DatosAbiertos.limpiarCache();
  });

  Future<void> abrir(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCristal(),
        home: const Scaffold(body: Column(children: [EntidadesSection()])),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  http.Response entidad(String nombre) => http.Response(
    jsonEncode([
      {
        'nombre_entidad': nombre,
        'nit_entidad': '800432123',
        'ciudad': 'Cali',
        'departamento': 'Valle del Cauca',
        'orden': 'Territorial',
        'contratos': '27',
        'total_valor': '2500000',
      },
    ]),
    200,
  );

  testWidgets('el ranking se muestra antes de recibir los contratistas', (
    tester,
  ) async {
    final conteo = Completer<http.Response>();
    var solicitudesConteo = 0;
    DatosAbiertos.clientePruebas = MockClient((request) async {
      final select = request.url.queryParameters[r'$select'] ?? '';
      if (select.contains('count(distinct')) {
        solicitudesConteo++;
        return conteo.future;
      }
      return entidad('INSTITUTO DE PRUEBA');
    });

    await abrir(tester);
    expect(find.text('Instituto de Prueba'), findsWidgets);
    expect(solicitudesConteo, 2);
    expect(conteo.isCompleted, isFalse);

    conteo.complete(
      http.Response('[{"nit_entidad":"800432123","contratistas":13}]', 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('13'), findsWidgets);
  });

  testWidgets('una falla de SECOP permite reintentar desde la misma vista', (
    tester,
  ) async {
    var primera = true;
    DatosAbiertos.clientePruebas = MockClient((_) async {
      if (primera) {
        primera = false;
        return http.Response('[]', 400);
      }
      return entidad('INSTITUTO RECUPERADO');
    });
    await abrir(tester);
    expect(
      find.text('No pudimos cargar el ranking de SECOP II.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Volver a consultar'));
    await tester.pumpAndSettle();
    expect(find.text('Instituto Recuperado'), findsWidgets);
  });

  testWidgets(
    'una búsqueda vigente publica resultados sin pedir el histórico',
    (tester) async {
      final consultas = <Uri>[];
      DatosAbiertos.clientePruebas = MockClient((request) async {
        consultas.add(request.url);
        final params = request.url.queryParameters;
        if ((params[r'$select'] ?? '').contains('count(distinct')) {
          return http.Response('[]', 200);
        }
        return entidad(
          params.containsKey(r'$q')
              ? 'INSTITUTO LINTERNA'
              : 'INSTITUTO DE PRUEBA',
        );
      });
      await abrir(tester);
      await tester.enterText(find.byType(TextField), 'Instituto Linterna');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Instituto Linterna', findRichText: true), findsWidgets);
      final busquedas = consultas.where(
        (uri) => uri.queryParameters.containsKey(r'$q'),
      );
      expect(busquedas, hasLength(1));
      expect(
        busquedas.single.queryParameters[r'$where'],
        contains('fecha_de_firma <'),
      );
    },
  );
}
