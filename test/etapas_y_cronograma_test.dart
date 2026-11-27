import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/cronograma_proceso_service.dart';
import 'package:app_secop/services/etapas_proceso.dart';
import 'package:app_secop/services/procesos_secop_service.dart';

ProcesoSecop proceso(Map<String, dynamic> datos) => ProcesoSecop({
  'modalidad_de_contratacion': 'Mínima cuantía',
  'estado_de_apertura_del_proceso': 'Abierto',
  'adjudicado': 'No',
  'estado_del_procedimiento': 'Publicado',
  ...datos,
});

void main() {
  group('Línea de tiempo del proceso', () {
    test('un proceso que recibe ofertas va en la etapa de ofertas', () {
      final e = EtapasProceso.de(
        proceso({
          'fase': 'Presentación de oferta',
          'fecha_de_recepcion_de': '2099-01-01T17:00:00.000',
        }),
      );
      expect(e.nombres, EtapasProceso.competitivas);
      expect(e.nombres[e.actual], 'Ofertas');
      expect(e.interrumpido, isNull);
    });

    test('observaciones, borrador, adjudicado y cancelado', () {
      expect(
        EtapasProceso.de(proceso({'fase': 'Presentación de observaciones'}))
            .actual,
        1,
      );
      expect(
        EtapasProceso.de(proceso({'estado_del_procedimiento': 'Borrador'}))
            .actual,
        0,
      );
      expect(EtapasProceso.de(proceso({'adjudicado': 'Si'})).actual, 4);
      final cancelado = EtapasProceso.de(
        proceso({'estado_del_procedimiento': 'Cancelado'}),
      );
      expect(cancelado.interrumpido, 'Cancelado');
    });

    test('la contratación directa tiene tres etapas', () {
      final e = EtapasProceso.de(
        proceso({
          'modalidad_de_contratacion': 'Contratación directa',
          'adjudicado': 'Si',
        }),
      );
      expect(e.nombres, EtapasProceso.directas);
      expect(e.actual, 2);
    });
  });

  group('Requisitos de ley frente a lo publicado', () {
    test('cada modalidad de SECOP II tiene su modalidad de la ley', () {
      expect(RequisitosDeLey.modalidad('Mínima cuantía')?.id, 'minima_cuantia');
      expect(
        RequisitosDeLey.modalidad(
          'Seleccion Abreviada Menor Cuantia Sin Manifestacion Interes',
        )?.id,
        'seleccion_abreviada_menor_cuantia',
      );
      expect(
        RequisitosDeLey.modalidad('Selección abreviada subasta inversa')?.id,
        'subasta_inversa',
      );
      expect(
        RequisitosDeLey.modalidad('Licitación pública Obra Publica')?.id,
        'licitacion_publica',
      );
      expect(RequisitosDeLey.modalidad('Subasta de prueba'), isNull);
    });

    test('reconoce los documentos por el nombre del archivo', () {
      const archivos = [
        'GCCON-F-046-Estudioprevio-Juegos zonales DEFINITIVO.pdf',
        '4. ANÁLISIS DE SECTOR_XXVI JUEGOS DEPORTIVOS ZONALES.pdf',
        '5. CDP 9426 JUEGOS ZONALES DEPORTIVOS DESP.pdf',
        '20. GCCON-F-060Avisodeconvocatoria (2).pdf',
        'GCCON-F-070Adendaalproceso No.pdf',
        '1. RES-0899 Resolucion de Apertura juegos.pdf',
        'Proyecto de pliego de condiciones.pdf',
      ];
      expect(RequisitosDeLey.publicado('estudios_previos', archivos), isTrue);
      expect(RequisitosDeLey.publicado('analisis_sector', archivos), isTrue);
      expect(RequisitosDeLey.publicado('cdp', archivos), isTrue);
      expect(RequisitosDeLey.publicado('aviso_convocatoria', archivos), isTrue);
      expect(RequisitosDeLey.publicado('adendas', archivos), isTrue);
      expect(
        RequisitosDeLey.publicado('resolucion_apertura', archivos),
        isTrue,
      );
      expect(RequisitosDeLey.publicado('proyecto_pliego', archivos), isTrue);
      // El proyecto de pliego no cuenta como pliego definitivo.
      expect(RequisitosDeLey.publicado('pliego_definitivo', archivos), isFalse);
      expect(
        RequisitosDeLey.publicado('informe_evaluacion', archivos),
        isFalse,
      );
      expect(
        RequisitosDeLey.publicado('respuesta_observaciones', archivos),
        isFalse,
      );
      expect(
        RequisitosDeLey.publicado('respuesta_observaciones', [
          'Respuesta a observaciones al proyecto de pliego.pdf',
        ]),
        isTrue,
      );
      // "rp" dentro de otra palabra no es un registro presupuestal.
      expect(
        RequisitosDeLey.publicado('registro_presupuestal', ['Corporativo.pdf']),
        isFalse,
      );
      expect(
        RequisitosDeLey.publicado('registro_presupuestal', ['RP 123.pdf']),
        isTrue,
      );
    });
  });

  test('el cronograma une las fases y pasa a hora de Colombia', () {
    final fechas = CronogramaProcesoService.desdeFilas([
      {
        'fecha_de_publicaci_n': '2026-11-05 11:37:58.2040991',
        'presentaci_n_de_observaciones': '2026-11-18 21:30:00.0000000',
        'presentaci_n_de_ofertas': '2026-11-20 22:00:00.0000000',
      },
      {
        'fecha_de_publicaci_n': '2026-11-13 23:22:30.8467370',
        'presentaci_n_de_observaciones': '2026-11-19 23:30:00.0000000',
        'presentaci_n_de_observaciones_1': '2026-11-30 17:00:00.0000000',
        'presentaci_n_de_ofertas': '2026-11-23 22:00:00.0000000',
        'publicaci_n_del_informe_de': '2026-11-25 17:00:00.0000000',
        'publicaci_n_acto': '2026-12-01 22:00:00.0000000',
        'columna_desconocida': '2026-11-01 10:00:00.0000000',
      },
    ]);
    final porNombre = {for (final f in fechas) f.nombre: f.fecha};
    // Gana la fase más reciente y se restan 5 horas (UTC → Colombia).
    expect(
      porNombre['Cierre: presentación de ofertas'],
      DateTime.utc(2026, 11, 23, 17),
    );
    expect(
      porNombre['Observaciones a los documentos del proceso'],
      DateTime.utc(2026, 11, 19, 18, 30),
    );
    expect(
      porNombre['Observaciones al informe de evaluación'],
      DateTime.utc(2026, 11, 30, 12),
    );
    expect(fechas.where((f) => f.observaciones).length, 2);
    expect(fechas.length, 5);
    expect(fechas.first.fecha.isBefore(fechas.last.fecha), isTrue);
  });
}
