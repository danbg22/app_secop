import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/novedades_proceso_service.dart';

void main() {
  group('Novedades del proceso', () {
    test('reconoce los documentos clave por su nombre', () {
      final casos = {
        'GCCON-F-070Adendaalproceso No.pdf': TipoNovedad.adenda,
        '1. RES-0899 Resolucion de Apertura juegos.pdf': TipoNovedad.apertura,
        '20. GCCON-F-060Avisodeconvocatoria (2).pdf': TipoNovedad.convocatoria,
        'Informe de Evaluación Preliminar SAMC 005.pdf': TipoNovedad.evaluacion,
        'RESPUESTA A OBSERVACIONES AL PROYECTO DE PLIEGO.pdf':
            TipoNovedad.observaciones,
        'Resolución de adjudicación No. 12.pdf': TipoNovedad.adjudicacion,
        'Resolucion declaratoria desierto.pdf': TipoNovedad.desierto,
        'Acta de cierre y lista de oferentes.pdf': TipoNovedad.oferentes,
        'Modificación al cronograma.pdf': TipoNovedad.modificacion,
      };
      casos.forEach((archivo, tipo) {
        expect(
          NovedadesProcesoService.clasificar(archivo),
          tipo,
          reason: archivo,
        );
      });
    });

    test('ignora los documentos ordinarios del expediente', () {
      for (final archivo in [
        'GCCON-F-046-Estudioprevio-Juegos zonales DEFINITIVO.pdf',
        '5. CDP 9426 JUEGOS ZONALES DEPORTIVOS DESP.pdf',
        '12. OFERTA ECONÓMICA.xlsx',
        '19. GCCON-F-068-DeclaracionfechadecortedelosestadosfinancierosdepersonaextranjeraV02.docx',
        '9. Acta de comite de contratacion.pdf',
      ]) {
        expect(
          NovedadesProcesoService.clasificar(archivo),
          isNull,
          reason: archivo,
        );
      }
    });

    test('deja una novedad por archivo, la más reciente primero', () {
      final novedades = NovedadesProcesoService.depurar([
        {
          'nombre_archivo': '1. RES-0899 Resolucion de Apertura juegos.pdf',
          'fecha_carga': '2026-11-12T19:00:00.000',
          'url_descarga_documento': {
            'url': 'https://community.secop.gov.co/Public/Archive/RetrieveFile/Index?DocumentId=1',
          },
        },
        {
          'nombre_archivo': '1. RES-0899 Resolucion de Apertura juegos.pdf',
          'fecha_carga': '2026-11-12T19:00:00.000',
        },
        {
          'nombre_archivo': 'GCCON-F-070Adendaalproceso No.pdf',
          'fecha_carga': '2026-11-19T19:00:00.000',
        },
        {'nombre_archivo': '6. PAA.pdf', 'fecha_carga': '2026-11-02'},
      ]);
      expect(novedades.map((n) => n.tipo), [
        TipoNovedad.adenda,
        TipoNovedad.apertura,
      ]);
      expect(novedades.last.url, startsWith('https://community.secop.gov.co'));
      // La carga del 12 a las 19:00 (sin hora real) es del 13 de noviembre.
      expect(novedades.last.fecha, DateTime(2026, 11, 13));
    });

    test('los proponentes no se repiten entre fases', () {
      final lista = NovedadesProcesoService.proponentesUnicos([
        {'proveedor': 'FUNDATURCOGIL', 'nit_proveedor': '824003749'},
        {'proveedor': 'Fundaturcogil', 'nit_proveedor': '824003749'},
        {
          'proveedor': 'UNIÓN TEMPORAL JUEGOS ZONALES VALLEDUPAR',
          'nit_proveedor': 'No Definido',
        },
      ]);
      expect(lista.length, 2);
      expect(lista.last.nit, '');
    });
  });
}
