import 'package:app_secop/services/informe_pdf_service.dart';
import 'package:app_secop/services/juridico_contratacion_service.dart';
import 'package:app_secop/services/supervision_service.dart';
import 'package:flutter_test/flutter_test.dart';

PlanSupervision plan({
  Periodicidad periodicidad = Periodicidad.mensual,
  DateTime? inicio,
  DateTime? fin,
}) => PlanSupervision(
  supervisorNombre: 'Lily Esther Mendoza',
  supervisorEmail: 'lily@valledupar.gov.co',
  fechaInicio: inicio ?? DateTime(2026, 10, 9),
  fechaFin: fin ?? DateTime(2026, 12, 28),
  periodicidad: periodicidad,
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
  plantilla: PlantillaInforme.porDefecto('Alcaldía de Valledupar').copyWith(
    etapas: const [
      EtapaAprobacion(
        id: 'enlace',
        nombre: 'Enlace',
        responsableEmail: 'enlace@x.co',
      ),
      EtapaAprobacion(
        id: 'supervisor',
        nombre: 'Supervisor',
        responsableEmail: 'Lily@X.co',
        certificacion: 'Certifico el cumplimiento.',
      ),
    ],
  ),
);

ExpedienteContratoPs expediente() => const ExpedienteContratoPs(
  id: 'EXP',
  tokenInvitado: 'tok',
  entidadNombre: 'Alcaldía de Valledupar',
  entidadNit: '800098911',
  dependencia: 'Tesorería',
  numeroContrato: '3468-SGR DE 2026',
  objetoContrato: 'Prestación de servicios profesionales de apoyo jurídico.',
  valorContratoCop: 9333333,
  plazoEjecucion: 'Dos meses y veinte días',
  contratistaNombreEsperado: 'Iván David Bolaño Castillo',
  contratistaCedulaEsperada: '1065123456',
  contratistaCorreo: 'i@x.co',
  contratistaTelefono: '3215091457',
  creadoPorEmail: 'd@x.co',
  creadoPorNombre: 'Daniel',
  fechaCreacionIso: '2026-10-01',
  apartados: [],
  trazabilidad: [],
);

const _pdf = ArchivoAdjunto(
  id: 'f',
  nombre: 'x.pdf',
  mime: 'application/pdf',
  tamanoBytes: 1,
  sha256: '',
  cargadoEnIso: '',
);

InformePeriodo completo(PlanSupervision p) {
  final periodo = p.periodos.first;
  return InformePeriodo.nuevo(periodo, p).copyWith(
    actividades: {
      'a': 'Proyecté 12 autos de embargo y los notifiqué.',
      'b': 'Presenté el informe del periodo.',
    },
    planillas: const [
      PlanillaAporte(
        periodo: '2026-10',
        fechaPagoIso: '2026-11-03',
        numero: '9876543210',
        ibcCop: 1750905,
        valorCop: 520000,
      ),
    ],
    estampilla: const EstampillaDepartamental(
      fechaPagoIso: '2026-10-15',
      valorPagadoCop: 140000,
      liquidacion: 'L-77',
    ),
    datosCobro: const DatosCobro(
      direccion: 'Carrera 24A #2-99',
      ciudad: 'Valledupar',
      celular: '3215091457',
      banco: 'Bancolombia',
      numeroCuenta: '19787728718',
    ),
    documentos: {
      for (final d in p.plantilla.documentos.where(
        (d) => d.origen == OrigenDocumento.contratista,
      ))
        d.id: const [_pdf],
    },
    declaracion: true,
  );
}

void main() {
  group('Aportes de contratistas independientes', () {
    test('IBC del 40 % con mínimos y tarifas', () {
      final a = AporteEsperado.calcular(
        valorMensualCop: 6000000,
        claseRiesgo: 1,
        anio: 2026,
      );
      expect(a.ibc, 2400000);
      expect(a.salud, 300000);
      expect(a.pension, 384000);
      expect(a.arl, 12600);
      expect(a.totalContratista(), 696600);
      expect(a.totalContratista(pensionado: true), 312600);
      final bajo = AporteEsperado.calcular(
        valorMensualCop: 2000000,
        claseRiesgo: 1,
        anio: 2025,
      );
      expect(bajo.ibc, 1423500);
      expect(
        AporteEsperado.calcular(
          valorMensualCop: 6000000,
          claseRiesgo: 5,
          anio: 2026,
        ).arlLaPagaLaEntidad,
        isTrue,
      );
    });
  });

  group('Periodos', () {
    test('mensuales desde la fecha de inicio, como 9 oct – 8 nov', () {
      final p = plan().periodos;
      expect(p.length, 3);
      expect(p[0].desde, DateTime(2026, 10, 9));
      expect(p[0].hasta, DateTime(2026, 11, 8));
      expect(p[0].id, '2026-10-09');
      expect(p[1].desde, DateTime(2026, 11, 9));
      expect(p.last.hasta, DateTime(2026, 12, 28));
    });

    test('quincenales de 15 días, como 28 sep – 12 oct', () {
      final p = plan(
        periodicidad: Periodicidad.quincenal,
        inicio: DateTime(2026, 9, 28),
        fin: DateTime(2026, 12, 27),
      ).periodos;
      expect(p.first.desde, DateTime(2026, 9, 28));
      expect(p.first.hasta, DateTime(2026, 10, 12));
      expect(p[1].desde, DateTime(2026, 10, 13));
      expect(p.length, 7);
    });

    test('un mes que no tiene el día de inicio cae en su último día', () {
      final p = plan(
        inicio: DateTime(2026, 1, 31),
        fin: DateTime(2026, 4, 30),
      ).periodos;
      expect(p[0].hasta, DateTime(2026, 2, 27));
      expect(p[1].desde, DateTime(2026, 2, 28));
    });
  });

  group('Documentos por informe', () {
    test('cada informe, los dos primeros y solo el primero', () {
      final p = plan();
      final ids1 = InformePeriodo.nuevo(
        p.periodos[0],
        p,
      ).documentosDelPeriodo(p).map((d) => d.id).toList();
      final ids2 = InformePeriodo.nuevo(
        p.periodos[1],
        p,
      ).documentosDelPeriodo(p).map((d) => d.id).toList();
      final ids3 = InformePeriodo.nuevo(
        p.periodos[2],
        p,
      ).documentosDelPeriodo(p).map((d) => d.id).toList();
      expect(
        ids1,
        containsAll([
          'seguridad_social',
          'estampilla_municipal',
          'rut',
          'cdp',
          'rp',
        ]),
      );
      expect(ids2, containsAll(['seguridad_social', 'estampilla_municipal']));
      expect(ids2, isNot(contains('rut')));
      expect(ids3, [
        'seguridad_social',
        'informe_supervision',
        'documento_equivalente',
      ]);
      // El orden es el de la plantilla.
      expect(ids1.first, 'seguridad_social');
      expect(ids1.last, 'rp');
    });
  });

  group('Informe', () {
    test('lista lo que falta y queda listo para enviar', () {
      final p = plan();
      final vacio = InformePeriodo.nuevo(p.periodos.first, p);
      expect(
        vacio.faltantes(p, firmaRegistrada: false),
        contains('Registrar tu firma.'),
      );
      expect(vacio.faltantes(p).any((f) => f.contains('obligación 1')), isTrue);
      final listo = completo(p);
      expect(listo.faltantes(p), isEmpty);
      expect(listo.faltantes(p, firmaRegistrada: false), [
        'Registrar tu firma.',
      ]);
    });

    test('verificación automática de aportes, documentos y plazo', () {
      final p = plan();
      final v = completo(p).verificar(p);
      // 3.500.000 → IBC 1 SMMLV 2026 (1.750.905): salud + pensión + ARL.
      final aportes = v.firstWhere((x) => x.texto.startsWith('Aportes'));
      expect(aportes.cumple, isTrue);
      expect(
        v.firstWhere((x) => x.texto.startsWith('Documentos')).cumple,
        isTrue,
      );
      final sinPlata = completo(p)
          .copyWith(
            planillas: const [
              PlanillaAporte(periodo: '2026-09', valorCop: 100000),
            ],
          )
          .verificar(p);
      expect(sinPlata.where((x) => !x.cumple).length, greaterThanOrEqualTo(2));
    });

    test('devolución y responsables por etapa', () {
      final p = plan();
      expect(p.etapas[1].esResponsable('lily@x.co'), isTrue);
      final devuelto = InformePeriodo.fromMap({
        ...completo(p)
            .copyWith(estado: EstadoInforme.devuelto)
            .camposContratista(),
        'revisiones': [
          const RevisionEtapa(
            etapaId: 'enlace',
            etapaNombre: 'Enlace',
            actor: 'Iván',
            fechaIso: '2026-10-31T10:00:00Z',
            aprobado: false,
            observacion: 'Corrige la actividad 4.',
            itemsDevueltos: ['obligacion:a', 'documento:rut'],
          ).toMap(),
        ],
      });
      expect(devuelto.devolucion?.observacion, 'Corrige la actividad 4.');
      expect(devuelto.estaDevuelto('documento:rut'), isTrue);
      expect(devuelto.estaDevuelto('aportes'), isFalse);
    });

    test('ida y vuelta por mapa', () {
      final p = plan();
      final copia = PlanSupervision.fromMap(p.toMap());
      expect(copia.periodos.length, 3);
      expect(copia.etapas.map((e) => e.id), ['enlace', 'supervisor']);
      expect(copia.plantilla.documentos.length, p.plantilla.documentos.length);
      expect(copia.toMap()['etapas'], isA<List>());
      final inf = InformePeriodo.fromMap(completo(p).camposContratista());
      expect(inf.planillas.single.numero, '9876543210');
      expect(inf.datosCobro.banco, 'Bancolombia');
      expect(inf.documentos['rut']!.single.nombre, 'x.pdf');
    });

    test('valor en letras para la cuenta de cobro', () {
      expect(valorEnLetras(3500000), 'TRES MILLONES QUINIENTOS MIL PESOS');
      expect(
        valorEnLetras(2333333),
        'DOS MILLONES TRESCIENTOS TREINTA Y TRES MIL TRESCIENTOS TREINTA Y TRES PESOS',
      );
      expect(valorEnLetras(1000000), 'UN MILLÓN DE PESOS');
      expect(valorEnLetras(21000), 'VEINTIUN MIL PESOS');
    });
  });

  group('PDF', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    test('genera el informe y los documentos del sistema', () async {
      final p = plan();
      final inf = completo(p).copyWith(
        estado: EstadoInforme.enRevision,
        enviadoEnIso: '2026-11-08T15:01:00Z',
      );
      final e = expediente();
      final informe = await InformePdfService.informeEjecucion(
        expediente: e,
        plan: p,
        informe: inf,
      );
      expect(String.fromCharCodes(informe.take(4)), '%PDF');
      for (final id in DocumentosSistema.todos) {
        final bytes = await InformePdfService.documentoSistema(
          id,
          expediente: e,
          plan: p,
          informe: inf,
          todos: {inf.id: inf},
        );
        expect(bytes, isNotNull, reason: id);
        expect(bytes!.length, greaterThan(1000));
      }
    });
  });
}
