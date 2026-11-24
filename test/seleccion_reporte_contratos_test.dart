// Interfaz de plugins usada únicamente para simular la sesión en este test.
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:app_secop/screens/contratistas_screen.dart';
import 'package:app_secop/screens/sections/contratos_section.dart';
import 'package:app_secop/services/datos_abiertos.dart';
import 'package:app_secop/tema/cristal.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('la selección sigue activa al buscar otro contrato', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1500);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    Map<String, String> contrato(int id, String ref, String objeto) => {
      'id_contrato': 'CO1.PCCNTR.$id',
      'referencia_del_contrato': ref,
      'proceso_de_compra': 'CO1.BDOS.$id',
      'objeto_del_contrato': objeto,
      'nombre_entidad': 'Alcaldía municipal',
      'nit_entidad': '812345678',
      'proveedor_adjudicado': 'Proveedor de prueba',
      'documento_proveedor': '12345123',
      'fecha_de_firma': '2026-11-01T00:00:00',
      'valor_del_contrato': '15000000',
      'estado_contrato': 'En ejecución',
    };
    const primera = 'PRUEBA-100';
    const segunda = 'REPORTE-98765';
    DatosAbiertos.clientePruebas = MockClient((request) async {
      final cambio = Uri.decodeFull(request.url.toString())
          .toUpperCase()
          .contains('98765');
      final fila = cambio
          ? contrato(200, segunda, 'Objeto segundo contrato de prueba')
          : contrato(100, primera, 'Objeto primero contrato de prueba');
      return http.Response.bytes(utf8.encode(jsonEncode([fila])), 200);
    });

    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCristal(),
        home: Scaffold(
          body: Column(
            children: [
              ContratosSection(
                topSearchController: controller,
                onTopSearchSubmitted: (_) {},
                onLogout: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder casilla(String ref) => find.byWidgetPredicate(
      (w) => w is Checkbox && (w.semanticLabel?.contains(ref) ?? false),
    );
    expect(casilla(primera), findsNothing);
    final botonReporte = find.text('Seleccionar contratos');
    final ordenar = find.text('Ordenar por:');
    await tester.ensureVisible(botonReporte);
    expect(
      tester.getCenter(botonReporte).dy,
      closeTo(tester.getCenter(ordenar).dy, 5),
    );
    expect(
      tester.getCenter(botonReporte).dx,
      lessThan(tester.getCenter(ordenar).dx),
    );
    await tester.tap(botonReporte);
    await tester.pumpAndSettle();
    expect(casilla(primera), findsOneWidget);
    expect(find.text('Exportar'), findsNothing);
    final cancelar = find.text('Cancelar selección');
    final descargar = find.text('Descargar reporte PDF');
    expect(
      tester.getCenter(cancelar).dy,
      closeTo(tester.getCenter(descargar).dy, 1),
    );
    expect(
      tester.getCenter(cancelar).dx,
      greaterThan(tester.getCenter(descargar).dx),
    );
    await tester.ensureVisible(casilla(primera));
    await tester.tap(casilla(primera));
    await tester.pumpAndSettle();
    expect(find.text('1 seleccionado'), findsOneWidget);

    final buscador = find.byType(TextField).first;
    await tester.ensureVisible(buscador);
    await tester.enterText(buscador, segunda);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(casilla(primera), findsNothing);
    expect(casilla(segunda), findsOneWidget);
    await tester.ensureVisible(casilla(segunda));
    await tester.tap(casilla(segunda));
    await tester.pumpAndSettle();
    final seleccionados = find.text('2 seleccionados');
    await tester.ensureVisible(seleccionados);
    await tester.tap(seleccionados);
    await tester.pumpAndSettle();

    final lista = find.byType(AlertDialog);
    expect(
      find.descendant(of: lista, matching: find.text('Proceso: $primera')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lista, matching: find.text('Proceso: $segunda')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Contratistas acumula personas de distintas páginas', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1500);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    DatosAbiertos.clientePruebas = MockClient(
      (_) async => http.Response('[]', 200),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCristal(),
        home: const ContratistasScreen(isEmbeddedInDashboard: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Exportar'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('Seleccionar contratistas'));
    await tester.pumpAndSettle();

    Future<String> seleccionarPrimero() async {
      final tabla = tester.widget<ContratistasResultsTable>(
        find.byType(ContratistasResultsTable),
      );
      final casilla = find.byType(Checkbox).first;
      await tester.ensureVisible(casilla);
      await tester.tap(casilla);
      await tester.pumpAndSettle();
      return tabla.rows.first.name;
    }

    final primero = await seleccionarPrimero();
    final siguiente = find.byIcon(Icons.chevron_right_rounded);
    await tester.ensureVisible(siguiente);
    await tester.tap(siguiente);
    await tester.pumpAndSettle();
    final segundo = await seleccionarPrimero();
    expect(primero, isNot(segundo));

    final revisar = find.text('2 seleccionados');
    await tester.ensureVisible(revisar);
    await tester.tap(revisar);
    await tester.pumpAndSettle();
    final modal = find.byType(AlertDialog);
    expect(find.text('Contratistas seleccionados (2)'), findsOneWidget);
    for (final nombre in [primero, segundo]) {
      expect(
        find.descendant(of: modal, matching: find.text(nombre)),
        findsOneWidget,
      );
    }
    await tester.tap(find.text('Seguir seleccionando'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar selección'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionar contratistas'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
