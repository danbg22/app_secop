import 'package:app_secop/screens/gestion_contractual/estado_secop.dart';
import 'package:app_secop/services/procesos_contratacion_service.dart';
import 'package:app_secop/services/secop_importacion_service.dart';
import 'package:flutter_test/flutter_test.dart';

ProcesoSecop secop({
  String estado = 'Publicado',
  String fase = 'Presentación de oferta',
  bool adjudicado = false,
  int ofertas = 0,
  List<DocumentoSecop> docs = const [],
}) => ProcesoSecop(
  idProceso: 'CO1.REQ.1',
  idPortafolio: 'CO1.BDOS.1',
  referencia: 'MC-01-2026',
  nombre: 'Suministro',
  descripcion: 'Suministro de papelería',
  entidad: 'SENA',
  nit: '899999034',
  departamento: 'Cesar',
  unidad: 'Despacho',
  modalidad: 'Mínima cuantía',
  tipoContrato: 'Suministro',
  fase: fase,
  estado: estado,
  precioBase: 10000000,
  duracion: '30 día(s)',
  adjudicado: adjudicado,
  proveedor: adjudicado ? 'Papelería SAS' : '',
  valorAdjudicado: adjudicado ? 9500000 : 0,
  ofertas: ofertas,
  manifestaciones: 0,
  fechas: const {'recepcionOfertas': '2026-04-29'},
  url: 'https://community.secop.gov.co/x',
  documentos: docs,
);

DocumentoSecop doc(String id) => DocumentoSecop(
  id: id,
  nombre: 'doc$id.pdf',
  descripcion: '',
  fechaIso: '2026-04-01',
  extension: 'pdf',
  tamanoBytes: 1,
  url: '',
);

void main() {
  test('extrae el ID de lo que pegue el usuario', () {
    const e = SecopImportacionService.extraerIdentificador;
    expect(e('CO1.REQ.9858450'), 'CO1.REQ.9858450');
    expect(e(' co1.bdos.9690611 '), 'CO1.BDOS.9690611');
    expect(
      e(
        'https://community.secop.gov.co/Public/Tendering/OpportunityDetail/Index?noticeUID=CO1.NTC.9706497&isFromPublicArea=True',
      ),
      'CO1.NTC.9706497',
    );
    expect(e('proceso 123'), isNull);
  });

  test('traduce la modalidad de SECOP II', () {
    const m = SecopImportacionService.modalidadDesdeSecop;
    expect(m('Licitación pública Obra Publica'), 'licitacion_publica');
    expect(m('Selección abreviada subasta inversa'), 'subasta_inversa');
    expect(
      m('Seleccion Abreviada Menor Cuantia Sin Manifestacion Interes'),
      'seleccion_abreviada_menor_cuantia',
    );
    expect(m('Concurso de méritos abierto'), 'concurso_meritos');
    expect(m('Mínima cuantía'), 'minima_cuantia');
    expect(m('Contratación Directa (con ofertas)'), 'contratacion_directa');
    expect(
      m('Contratación régimen especial (con ofertas)'),
      'regimen_especial',
    );
  });

  test('detecta novedades entre sincronizaciones', () {
    final antes = secop(docs: [doc('1')]);
    expect(SecopImportacionService.novedades(antes, antes), isEmpty);
    final despues = secop(
      estado: 'Seleccionado',
      fase: 'Adjudicado',
      adjudicado: true,
      ofertas: 3,
      docs: [doc('1'), doc('2')],
    );
    final n = SecopImportacionService.novedades(antes, despues);
    expect(
      n.any((t) => t.startsWith('Estado: Publicado → Seleccionado')),
      isTrue,
    );
    expect(n.any((t) => t.startsWith('Adjudicado a Papelería SAS')), isTrue);
    expect(n.any((t) => t.startsWith('3 ofertas nuevas')), isTrue);
    expect(n.any((t) => t == 'Documento nuevo: doc2.pdf'), isTrue);
  });

  test('agrupa el estado para los chips de color', () {
    expect(GrupoEstadoSecop.de(null), GrupoEstadoSecop.sinSincronizar);
    expect(GrupoEstadoSecop.de(secop()), GrupoEstadoSecop.publicado);
    expect(
      GrupoEstadoSecop.de(secop(estado: 'Evaluación')),
      GrupoEstadoSecop.evaluacion,
    );
    expect(
      GrupoEstadoSecop.de(secop(adjudicado: true)),
      GrupoEstadoSecop.adjudicado,
    );
    expect(
      GrupoEstadoSecop.de(secop(estado: 'Cancelado')),
      GrupoEstadoSecop.terminado,
    );
    expect(
      GrupoEstadoSecop.de(secop(estado: 'Borrador')),
      GrupoEstadoSecop.preparacion,
    );
  });

  test('el proceso importado guarda la fotografía de SECOP II', () {
    final p = ProcesoContratacion(
      id: 'a' * 32,
      modalidadId: 'minima_cuantia',
      equipoUid: 'm',
      creadoPorUid: 'm',
      creadoPorNombre: 'D',
      entidadNombre: 'SENA',
      entidadNit: '899999034',
      dependencia: '',
      numeroProceso: 'MC-01-2026',
      objeto: 'Suministro',
      presupuestoCop: 1,
      plazoEjecucion: '',
      fechaCreacionIso: '2026-11-01',
      origen: 'importado',
      secop: secop(docs: [doc('1')]),
      secopSincronizadoEnIso: '2026-11-01T10:00:00Z',
      secopNovedades: const ['Estado: Publicado → Evaluación'],
    );
    final copia = ProcesoContratacion.fromMap(p.toMap());
    expect(copia.importado, isTrue);
    expect(copia.secop!.documentos.single.id, '1');
    expect(copia.secop!.fechas['recepcionOfertas'], '2026-04-29');
    expect(copia.secopNovedades, ['Estado: Publicado → Evaluación']);
  });
}
