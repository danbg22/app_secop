import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app_secop/screens/proceso_compartido_screen.dart';
import 'package:app_secop/screens/sections/procesos_section.dart';
import 'package:app_secop/services/datos_abiertos.dart';
import 'package:app_secop/services/procesos_secop_service.dart';
import 'package:app_secop/tema/cristal.dart';

void main() {
  Map<String, dynamic> fila(
    String ref,
    String fase,
    String estado,
    String fecha, {
    String apertura = 'Abierto',
    String adjudicado = 'No',
  }) => {
    'id_del_portafolio': 'CO1.BDOS.1',
    'referencia_del_proceso': ref,
    'nombre_del_procedimiento': 'JUEGOS ZONALES',
    'entidad': 'SENA REGIONAL CESAR',
    'fase': fase,
    'estado_del_procedimiento': estado,
    'estado_de_apertura_del_proceso': apertura,
    'adjudicado': adjudicado,
    'fecha_de_publicacion_del': fecha,
  };

  test('una tarjeta por proceso, con su fase más reciente', () {
    final r = ProcesosSecopService.agrupar([
      fila(
        'SAMC_CSR_DIR_005_2026',
        'Presentación de observaciones',
        'Evaluación',
        '2026-11-05T06:37:58.204',
      ),
      fila(
        'SAMC_CSR_DIR_005_2026 (Presentación de oferta)',
        'Presentación de oferta',
        'Publicado',
        '2026-11-13T18:22:30.846',
      ),
    ]);
    expect(r.length, 1);
    expect(r.first.fases, 2);
    expect(r.first.referencia, 'SAMC_CSR_DIR_005_2026');
    expect(r.first.estado, 'Recibe ofertas');
    expect(r.first.tipo, TipoEstadoProceso.abierto);
  });

  test('estados en palabras', () {
    String e(
      String estado, {
      String apertura = 'Cerrado',
      String adj = 'No',
      String fase = 'Presentación de oferta',
    }) => ProcesoSecop(
      fila(
        'R',
        fase,
        estado,
        '2026-01-01',
        apertura: apertura,
        adjudicado: adj,
      ),
    ).estado;
    expect(e('Borrador'), 'Borrador');
    expect(e('En aprobación'), 'En aprobación');
    expect(e('Evaluación'), 'En evaluación');
    expect(e('Cancelado'), 'Cancelado');
    expect(e('Seleccionado', adj: 'Si'), 'Adjudicado');
    expect(
      e(
        'Publicado',
        apertura: 'Abierto',
        fase: 'Presentación de observaciones',
      ),
      'Recibe observaciones',
    );
  });

  test('todas las palabras buscadas, sin tildes ni conectores', () {
    final f = fila('R', 'F', 'Publicado', '2026-01-01');
    expect(ProcesosSecopService.palabras('Juegos de Zonales'), [
      'juegos',
      'zonales',
    ]);
    expect(
      ProcesosSecopService.contiene(f, ['juegos', 'zonales', 'cesar']),
      isTrue,
    );
    expect(ProcesosSecopService.contiene(f, ['juegos', 'nacionales']), isFalse);
  });

  group('Explorador de procesos', () {
    Map<String, dynamic> proceso(int id, {String estado = 'Publicado'}) => {
      ...fila(
        'MC-0$id-2026',
        'Presentación de oferta',
        estado,
        '2026-11-13T18:22:30.846',
      ),
      'id_del_portafolio': 'CO1.BDOS.$id',
      'id_del_proceso': 'CO1.REQ.$id',
    };

    http.Response respuesta(Iterable<Map<String, dynamic>> filas) =>
        http.Response.bytes(utf8.encode(jsonEncode(filas.toList())), 200);

    setUp(DatosAbiertos.limpiarCache);
    tearDown(() => DatosAbiertos.clientePruebas = null);

    testWidgets(
      'la ficha reutiliza el listado y limita sus procesos a la regional',
      (tester) async {
        final consultas = <Uri>[];
        DatosAbiertos.clientePruebas = MockClient((request) async {
          consultas.add(request.url);
          return respuesta(const []);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProcesosSection(
                nombreEntidad: 'SENA',
                nitEntidad: '899999034',
                departamento: 'Cesar',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ver abiertos'), findsOneWidget);
        expect(find.text('Todos los estados'), findsOneWidget);
        expect(find.text('Entidad o NIT'), findsNothing);
        await tester.tap(find.byTooltip('Filtrar por tipo de proceso'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Licitación pública'));
        await tester.pumpAndSettle();

        expect(consultas, isNotEmpty);
        for (final uri in consultas) {
          final where = uri.queryParameters[r'$where'];
          expect(where, contains("nit_entidad in ('899999034'"));
          expect(where, contains("departamento_entidad = 'Cesar'"));
        }
        expect(
          consultas.last.queryParameters[r'$where'],
          contains("modalidad_de_contratacion in ('Licitación pública'"),
        );
      },
    );

    test('recorre el historial por páginas sin imponer un periodo', () async {
      DatosAbiertos.clientePruebas = MockClient((request) async {
        final params = request.url.queryParameters;
        expect(params[r'$where'], isNot(contains('>=')));
        if (params[r'$where'] == 'fecha_de_publicacion_del is null') {
          return respuesta([
            {...proceso(40)}..remove('fecha_de_publicacion_del'),
          ]);
        }
        expect(params[r'$where'], 'fecha_de_publicacion_del is not null');
        expect(params[r'$order'], contains('fecha_de_publicacion_del DESC'));
        final offset = int.parse(params[r'$offset']!);
        return respuesta(
          offset == 0 ? List.generate(25, proceso) : [proceso(24), proceso(25)],
        );
      });
      final primera = await ProcesosSecopService.buscarPagina();
      expect(primera.procesos.length, 24);
      final segunda = await ProcesosSecopService.buscarPagina(
        desde: primera.siguiente!,
      );
      expect(segunda.procesos.map((p) => p.portafolio), [
        'CO1.BDOS.24',
        'CO1.BDOS.25',
        'CO1.BDOS.40',
      ]);
      expect(segunda.siguiente, isNull);
    });

    test(
      'Abiertos confirma la última fase antes de mostrar una oportunidad',
      () async {
        DatosAbiertos.clientePruebas = MockClient((request) async {
          final where = request.url.queryParameters[r'$where']!;
          if (where.startsWith('id_del_portafolio in')) {
            return respuesta([
              {
                ...proceso(1, estado: 'Evaluación'),
                'fecha_de_publicacion_del': '2026-11-14T00:00:00',
              },
              {...proceso(2), 'fecha_de_recepcion_de': '2000-01-01T12:00:00'},
              proceso(3),
            ]);
          }
          expect(where, contains('fecha_de_recepcion_de'));
          if (where.endsWith('fecha_de_publicacion_del is null')) {
            return respuesta([]);
          }
          return respuesta([proceso(1), proceso(2), proceso(3)]);
        });
        final pagina = await ProcesosSecopService.buscarPagina(
          estado: FiltroEstadoProceso.abiertos,
        );
        expect(pagina.procesos.map((p) => p.portafolio), ['CO1.BDOS.3']);
      },
    );

    test('una referencia con separadores conserva sus segmentos', () async {
      DatosAbiertos.clientePruebas = MockClient((request) async {
        final params = request.url.queryParameters;
        final where = params[r'$where']!;
        if (where.startsWith('id_del_portafolio in')) {
          return respuesta([proceso(7)]);
        }
        expect(params[r'$q'], isNull);
        if (where.endsWith('fecha_de_publicacion_del is null')) {
          return respuesta([]);
        }
        expect(
          where,
          contains("upper(referencia_del_proceso) LIKE 'MC%07%2026%'"),
        );
        return respuesta([proceso(7), proceso(71)]);
      });
      final pagina = await ProcesosSecopService.buscarPagina(
        texto: 'mc 07 / 2026',
        campo: CampoBusquedaProceso.referencia,
      );
      expect(pagina.procesos.single.referencia, 'MC-07-2026');
    });

    testWidgets('la página presenta tarjetas con distintos anchos', (
      tester,
    ) async {
      DatosAbiertos.clientePruebas = MockClient(
        (_) async => respuesta([
          {
            ...proceso(1),
            'precio_base': '2500000',
            'departamento_entidad': 'Cesar',
          },
          proceso(2),
        ]),
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final ancho in [1180.0, 360.0]) {
        tester.view.physicalSize = Size(ancho, 900);
        await tester.pumpWidget(
          MaterialApp(
            theme: temaCristal(),
            home: const Scaffold(body: ProcesosSection()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Procesos'), findsOneWidget);
        expect(find.text('Todos los estados'), findsOneWidget);
        expect(find.text('2 procesos mostrados'), findsOneWidget);
        expect(find.text('MC-01-2026'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('la vista compartida solo pide y muestra el encabezado', (
      tester,
    ) async {
      final rutas = <String>[];
      var consultas = 0;
      DatosAbiertos.clientePruebas = MockClient((request) async {
        consultas++;
        final params = request.url.queryParameters;
        expect(params[r'$where'], "id_del_portafolio = 'CO1.BDOS.7'");
        final seleccion = params[r'$select']!.split(',');
        expect(seleccion, contains('nombre_del_procedimiento'));
        expect(seleccion, isNot(contains('urlproceso')));
        expect(seleccion, isNot(contains('descripci_n_del_procedimiento')));
        expect(seleccion, isNot(contains('fecha_de_recepcion_de')));
        final fila = proceso(7);
        return respuesta([
          {for (final columna in seleccion) columna: fila[columna]},
        ]);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: temaCristal(),
          home: ProcesoCompartidoScreen(
            id: 'CO1.BDOS.7',
            soloEncabezado: true,
            onAutenticar: rutas.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(consultas, 1);
      expect(find.text('JUEGOS ZONALES'), findsOneWidget);
      expect(find.textContaining('MC-07-2026'), findsOneWidget);
      expect(find.text('Abrir en SECOP II'), findsNothing);
      expect(find.text('Documentos publicados'), findsNothing);
      expect(find.byType(SelectableText), findsNothing);

      await tester.tap(find.text('Ingresa').first);
      await tester.tap(find.text('Regístrate'));
      expect(rutas, ['/auth', '/registro']);
    });

    testWidgets(
      'el detalle completo permite compartir solo el enlace a la vista previa',
      (tester) async {
        const id = 'CO1.BDOS.7';
        const descripcion = 'Descripción disponible con sesión';
        final datos = (proceso(7)
          ..addAll({
            'descripci_n_del_procedimiento': descripcion,
            'urlproceso': {
              'url': 'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.7',
            },
          }));
        var sePidioDetalle = false;
        DatosAbiertos.clientePruebas = MockClient((request) async {
          if (!request.url.path.endsWith('/p6dx-8zbt.json')) {
            return respuesta([]);
          }
          final params = request.url.queryParameters;
          if (params[r'$limit'] == '1') {
            expect(params[r'$select'], isNull);
            expect(params[r'$where'], "id_del_portafolio = '$id'");
            sePidioDetalle = true;
          }
          return respuesta([datos]);
        });

        String? enlaceCopiado;
        final mensajero =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        mensajero.setMockMethodCallHandler(SystemChannels.platform, (
          llamada,
        ) async {
          if (llamada.method == 'Clipboard.setData') {
            enlaceCopiado = (llamada.arguments as Map)['text'] as String;
          }
          return null;
        });
        addTearDown(
          () =>
              mensajero.setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: temaCristal(),
            home: const ProcesoCompartidoScreen(id: id, soloEncabezado: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(sePidioDetalle, isTrue);
        expect(find.text(descripcion), findsOneWidget);
        expect(find.text('Abrir en SECOP II'), findsOneWidget);
        await tester.tap(find.text('Compartir proceso'));
        await tester.pumpAndSettle();
        expect(
          enlaceCopiado,
          'https://contratalegal.com/#/proceso-compartido/$id',
        );
      },
    );
  });
}
