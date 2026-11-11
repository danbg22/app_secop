// ignore_for_file: invalid_use_of_visible_for_testing_member
// Capturas de Gestión contractual y Supervisión con datos de ejemplo.
//   flutter test tool/vista/gestion_test.dart --update-goldens
import 'dart:io';

import 'package:app_secop/data/modalidades_contratacion.dart';
import 'package:app_secop/screens/consentimiento_equipo_screen.dart';
import 'package:app_secop/screens/gestion_contractual/crear_proceso_screen.dart';
import 'package:app_secop/screens/gestion_contractual/importar_proceso_screen.dart';
import 'package:app_secop/screens/gestion_contractual/inicio_gestion_screen.dart';
import 'package:app_secop/screens/gestion_contractual/seguimiento_secop_screen.dart';
import 'package:app_secop/screens/gestion_contractual/selector_modalidad_screen.dart';
import 'package:app_secop/screens/gestion_equipo_screen.dart';
import 'package:app_secop/screens/supervision/bandeja_supervision_screen.dart';
import 'package:app_secop/screens/supervision/editar_plan_screen.dart';
import 'package:app_secop/screens/supervision/informe_contratista_screen.dart';
import 'package:app_secop/screens/supervision/plantilla_informe_screen.dart';
import 'package:app_secop/screens/supervision/supervision_contrato_screen.dart';
import 'package:app_secop/services/juridico_contratacion_service.dart';
import 'package:app_secop/services/supervision_service.dart';
import 'package:app_secop/tema/cristal.dart';
import 'package:app_secop/widgets/pqrs_help_dialog.dart';
import 'package:app_secop/widgets/reporte_contratos_flujo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_falso.dart';
import 'soporte.dart';

PlanSupervision _plan() => PlanSupervision(
  supervisorNombre: 'Supervisora de Ejemplo',
  supervisorEmail: 'supervision@ejemplo.co',
  fechaInicio: DateTime(2026, 10, 9),
  fechaFin: DateTime(2026, 12, 28),
  periodicidad: Periodicidad.mensual,
  valorPeriodoCop: 3500000,
  claseRiesgo: 1,
  cdp: const DatoPresupuestal(
    numero: '4086',
    fechaIso: '2026-09-21',
    valorCop: 12000000,
  ),
  obligaciones: const [
    ObligacionContractual(
      id: 'a',
      texto: 'Brindar apoyo en medidas cautelares de embargo.',
    ),
    ObligacionContractual(id: 'b', texto: 'Presentar informes mensuales.'),
  ],
  plantilla: PlantillaInforme.porDefecto('Entidad de Ejemplo'),
);

const _expediente = ExpedienteContratoPs(
  id: 'EXP',
  tokenInvitado: 'tok',
  entidadNombre: 'Entidad de Ejemplo',
  entidadNit: '800000000',
  dependencia: 'Tesorería',
  numeroContrato: '0001 DE 2026',
  objetoContrato: 'Prestación de servicios profesionales de apoyo jurídico.',
  valorContratoCop: 9333333,
  plazoEjecucion: 'Dos meses y veinte días',
  contratistaNombreEsperado: 'Contratista de Ejemplo',
  contratistaCedulaEsperada: '1000000000',
  contratistaCorreo: 'contratista@ejemplo.co',
  contratistaTelefono: '3000000000',
  creadoPorEmail: 'equipo@ejemplo.co',
  creadoPorNombre: 'Equipo',
  fechaCreacionIso: '2026-10-01',
  apartados: [],
  trazabilidad: [],
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
    int espera = 3,
    bool ejemplo = false,
  }) async {
    ejemplo ? sesionDeEjemplo(true) : sesionConTodosLosRoles(true);
    addTearDown(() => sesionConTodosLosRoles(false));
    ventana(tester, ancho, alto);
    await tester.pumpWidget(appCristal(pantalla));
    await tester.pump(const Duration(milliseconds: 400));
    await esperarRed(tester, espera);
  }

  void pantalla(String nombre, Widget Function() w, {int espera = 3}) {
    testWidgets(nombre, (t) async {
      await abrir(t, w(), espera: espera);
      await capturar(t, 'ges_$nombre');
    });
    testWidgets('$nombre móvil', (t) async {
      await abrir(t, w(), ancho: 390, alto: 844, espera: espera);
      await capturar(t, 'ges_${nombre}_movil');
    });
  }

  pantalla('inicio', () => const InicioGestionScreen());
  pantalla('modalidad', () => const SelectorModalidadScreen());
  pantalla(
    'crear',
    () => CrearProcesoScreen(modalidad: modalidadesContratacion.first),
  );
  pantalla('importar', () => const ImportarProcesoScreen());
  pantalla('seguimiento', () => const SeguimientoSecopScreen());
  pantalla('equipo', () => const GestionEquipoScreen());
  pantalla(
    'bandeja',
    () => const BandejaSupervisionScreen(expedientes: [_expediente]),
  );
  pantalla(
    'supervision',
    () => const SupervisionContratoScreen(expediente: _expediente),
  );
  pantalla(
    'plan',
    () => EditarPlanScreen(expediente: _expediente, plan: _plan()),
  );
  pantalla(
    'plantilla',
    () => const PlantillaInformeScreen(entidad: 'Entidad de Ejemplo'),
  );
  pantalla('informe', () {
    final plan = _plan();
    return InformeContratistaScreen(
      expediente: _expediente,
      plan: plan,
      periodo: plan.periodos.first,
      todos: const {},
      contratistaNombre: 'Contratista de Ejemplo',
    );
  });
  pantalla('consentimiento', () => const ConsentimientoEquipoScreen());

  testWidgets('diálogo de ayuda', (t) async {
    await abrir(
      t,
      Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: FilledButton(
              onPressed: () => PqrsHelpDialog.show(context),
              child: const Text('Abrir ayuda'),
            ),
          ),
        ),
      ),
      espera: 1,
      ejemplo: true,
    );
    await t.tap(find.text('Abrir ayuda'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    await capturar(t, 'dlg_ayuda');
  });

  testWidgets('diálogo de reporte', (t) async {
    await abrir(
      t,
      Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: FilledButton(
              onPressed: () => mostrarDialogoCristal<void>(
                context: context,
                builder: (_) => DialogoReporte(
                  criterios: (o, u) => const [
                    ('Entidad', 'SENA · Regional Cesar'),
                    ('Periodo', '2023 – corte de hoy'),
                  ],
                  descripcionFiltros: 'Filtros de la pantalla',
                  vigencia: 2026,
                ),
              ),
              child: const Text('Abrir reporte'),
            ),
          ),
        ),
      ),
      espera: 1,
    );
    await t.tap(find.text('Abrir reporte'));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 600));
    await capturar(t, 'dlg_reporte');
  });
}
