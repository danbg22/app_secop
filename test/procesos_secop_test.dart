import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/procesos_secop_service.dart';

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
}
