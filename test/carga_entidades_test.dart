// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';

import 'package:app_secop/screens/perfil_entidad_screen.dart';
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

  testWidgets('se puede buscar mientras sigue pendiente el ranking nacional', (
    tester,
  ) async {
    final ranking = Completer<http.Response>();
    DatosAbiertos.clientePruebas = MockClient((request) async {
      final params = request.url.queryParameters;
      if ((params[r'$where'] ?? '').contains('NOT LIKE')) return ranking.future;
      if ((params[r'$select'] ?? '').contains('count(distinct')) {
        return http.Response('[]', 200);
      }
      return entidad('INSTITUTO CANDIL');
    });

    await abrir(tester);
    expect(find.text('Acceso directo a entidades'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Instituto Candil');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();

    expect(find.text('Instituto Candil', findRichText: true), findsWidgets);
    expect(ranking.isCompleted, isFalse);
    ranking.complete(entidad('INSTITUTO DEL RANKING'));
    await tester.pumpAndSettle();
    expect(find.text('Instituto Candil', findRichText: true), findsWidgets);
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

  testWidgets('una búsqueda conserva el directorio y recupera SECOP I', (
    tester,
  ) async {
    final archivo = Completer<http.Response>();
    DatosAbiertos.clientePruebas = MockClient((request) async {
      if (request.url.path.endsWith('f789-7hwg.json')) {
        if (request.url.queryParameters.containsKey(r'$q')) {
          return http.Response('[]', 200);
        }
        return archivo.future;
      }
      final where = request.url.queryParameters[r'$where'] ?? '';
      if (where.contains('892300548')) return http.Response('[]', 400);
      return entidad('INSTITUTO DEL RANKING');
    });
    await abrir(tester);
    await tester.enterText(find.byType(TextField), 'Emdupar');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();
    expect(find.text('Coincidencias del directorio'), findsOneWidget);
    expect(
      find.text('No pudimos consultar las entidades en SECOP.'),
      findsNothing,
    );
    archivo.complete(
      http.Response(
        '[{"nombre_entidad":"EMDUPAR ARCHIVO","nit_de_la_entidad":"892300548","procesos":"12"}]',
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('EMDUPAR ARCHIVO'), findsWidgets);
    expect(
      find.textContaining('Las cifras de SECOP no se pudieron confirmar'),
      findsNothing,
    );
  });

  testWidgets(
    'la ficha deja seleccionar contratos antes de las cifras y conserva la selección al buscar',
    (tester) async {
      final estados = Completer<http.Response>();
      DatosAbiertos.clientePruebas = MockClient((request) async {
        final params = request.url.queryParameters;
        if (params[r'$group'] == 'estado_contrato') return estados.future;
        if (request.url.path.endsWith('jbjy-vk9h.json') &&
            params[r'$limit'] != null &&
            params[r'$select'] == null) {
          final buscando = (params[r'$where'] ?? '').contains('LINTERN');
          return http.Response(
            jsonEncode([
              {
                'id_contrato': buscando ? 'CO1.PCCNTR.2' : 'CO1.PCCNTR.1',
                'referencia_del_contrato': buscando ? 'MC-2' : 'MC-1',
                'nombre_entidad': 'INSTITUTO DE PRUEBA',
                'nit_entidad': '800432123',
                'objeto_del_contrato': buscando
                    ? 'Compra de linternas'
                    : 'Primer contrato',
                'valor_del_contrato': '2500000',
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: temaCristal(),
          home: const PerfilEntidadScreen(
            entity: EntitySummaryRecord(
              name: 'Instituto de Prueba',
              nit: '800432123',
              location: 'Cali',
              municipio: 'Cali',
              departamento: 'Valle del Cauca',
              category: 'Territorial',
              emblemType: EntityEmblemType.haciendaSeal,
              contractsCount: 1,
              contractsFormatted: '1',
              amountMillions: 2.5,
              amountFormatted: '2.5',
              dependenciesCount: 0,
              uniqueContractors: 0,
              secopKeywords: [],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Contratos').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Primer contrato'), findsWidgets);
      expect(estados.isCompleted, isFalse);

      await tester.tap(find.text('Seleccionar contratos'));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('1 seleccionado'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Linternas');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();
      expect(find.text('Compra de linternas'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('2 seleccionados'), findsOneWidget);

      estados.complete(
        http.Response('[{"contratos":1,"total_valor":2500000}]', 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Descargar reporte PDF'), findsOneWidget);
      expect(find.text('2 seleccionados'), findsOneWidget);
      expect(find.text('Compra de linternas'), findsOneWidget);
    },
  );

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
