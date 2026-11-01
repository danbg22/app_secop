import 'package:app_secop/services/supervision_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aportes de contratistas independientes', () {
    test('IBC del 40 % con tarifas de salud, pensión y ARL', () {
      final a = AporteEsperado.calcular(
        valorMensualCop: 6000000,
        claseRiesgo: 1,
        anio: 2026,
      );
      expect(a.ibc, 2400000);
      expect(a.salud, 300000);
      expect(a.pension, 384000);
      expect(a.arl, 12600); // 0,522 % = 12.528, PILA redondea a la centena
      expect(a.totalContratista, 696600);
      expect(a.arlLaPagaLaEntidad, isFalse);
    });

    test('el IBC no baja de 1 SMMLV ni sube de 25', () {
      final bajo = AporteEsperado.calcular(
        valorMensualCop: 2000000,
        claseRiesgo: 1,
        anio: 2025,
      );
      expect(bajo.ibc, 1423500);
      final alto = AporteEsperado.calcular(
        valorMensualCop: 200000000,
        claseRiesgo: 1,
        anio: 2025,
      );
      expect(alto.ibc, 1423500 * 25);
    });

    test('en riesgo IV y V la ARL la paga la entidad', () {
      final a = AporteEsperado.calcular(
        valorMensualCop: 6000000,
        claseRiesgo: 4,
        anio: 2026,
      );
      expect(a.arlLaPagaLaEntidad, isTrue);
      expect(a.totalContratista, a.salud + a.pension);
    });
  });

  group('Verificación de la planilla', () {
    final esperado = AporteEsperado.calcular(
      valorMensualCop: 6000000,
      claseRiesgo: 1,
      anio: 2026,
    );

    test('cumple cuando paga el mínimo del periodo correcto', () {
      const p = PlanillaReportada(
        numero: '123',
        periodoCotizado: '2026-03',
        ibcCop: 2400000,
        saludCop: 300000,
        pensionCop: 384000,
        arlCop: 12600,
      );
      expect(p.verificar(esperado, '2026-03').every((h) => h.cumple), isTrue);
    });

    test('señala periodo equivocado y aportes por debajo del mínimo', () {
      const p = PlanillaReportada(
        numero: '123',
        periodoCotizado: '2026-02',
        ibcCop: 1750905,
        saludCop: 218900,
        pensionCop: 280200,
        arlCop: 9200,
      );
      final fallas = p
          .verificar(esperado, '2026-03')
          .where((h) => !h.cumple)
          .toList();
      expect(fallas.length, 5); // periodo, IBC, salud, pensión y ARL
    });

    test('los pensionados no cotizan a pensión', () {
      const p = PlanillaReportada(
        numero: '1',
        periodoCotizado: '2026-03',
        ibcCop: 2400000,
        saludCop: 300000,
        arlCop: 12600,
        pensionado: true,
      );
      expect(p.verificar(esperado, '2026-03').every((h) => h.cumple), isTrue);
    });
  });

  group('Plan e informe', () {
    final plan = PlanSupervision(
      supervisorNombre: 'Ana',
      supervisorEmail: 'Ana@Entidad.gov.co',
      fechaInicio: DateTime(2026, 2, 15),
      fechaFin: DateTime(2026, 6, 30),
      valorMensualCop: 6000000,
      claseRiesgo: 1,
      obligaciones: const [
        ObligacionContractual(id: 'a', texto: 'Apoyar la gestión contractual'),
        ObligacionContractual(id: 'b', texto: 'Presentar informes'),
      ],
    );

    test('meses del contrato y supervisor sin importar mayúsculas', () {
      expect(plan.periodos, [
        '2026-02',
        '2026-03',
        '2026-04',
        '2026-05',
        '2026-06',
      ]);
      expect(plan.esSupervisor('ana@entidad.gov.co'), isTrue);
      expect(plan.esSupervisor('otro@entidad.gov.co'), isFalse);
      expect(nombrePeriodo('2026-03'), 'marzo de 2026');
    });

    test('lista lo que falta para enviar', () {
      const vacio = InformeMensual(periodo: '2026-03');
      expect(vacio.faltantes(plan).length, 1 + 2 + 1 + 3);
      final completo = vacio.copyWith(
        valorCobradoCop: 6000000,
        actividades: {
          'a': 'Revisé 12 expedientes de contratación',
          'b': 'Entregué el informe mensual',
        },
        planilla: const PlanillaReportada(
          numero: '9',
          periodoCotizado: '2026-03',
          ibcCop: 2400000,
        ),
        documentos: {
          for (final t in DocumentoInformeTipo.values.where(
            (t) => t.obligatorio,
          ))
            t.name: const DocumentoInforme(
              nombre: 'x.pdf',
              mime: 'application/pdf',
              tamanoBytes: 1,
              sha256: '',
              cargadoEnIso: '',
            ),
        },
      );
      expect(completo.faltantes(plan), isEmpty);
    });

    test('ida y vuelta por mapa', () {
      final copia = PlanSupervision.fromMap(plan.toMap());
      expect(copia.supervisorEmail, 'ana@entidad.gov.co');
      expect(copia.obligaciones.map((o) => o.id), ['a', 'b']);
      final inf = InformeMensual.fromMap({
        ...const InformeMensual(
          periodo: '2026-03',
          estado: EstadoInforme.enviado,
          valorCobradoCop: 5,
        ).camposContratista(),
        'revision': {
          'planilla': {'cumple': false, 'observacion': 'Falta ARL'},
        },
      });
      expect(inf.estado, EstadoInforme.enviado);
      expect(inf.devueltos.single.observacion, 'Falta ARL');
    });
  });
}
