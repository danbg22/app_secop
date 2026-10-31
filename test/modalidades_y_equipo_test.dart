import 'package:app_secop/data/modalidades_contratacion.dart';
import 'package:app_secop/services/equipo_juridico_service.dart';
import 'package:app_secop/services/procesos_contratacion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Catálogo de modalidades', () {
    test('ids únicos y prestación de servicios conservada', () {
      final ids = modalidadesContratacion.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(modalidadPorId('prestacion_servicios')?.esCompetitiva, isFalse);
    });

    test('incluye todas las modalidades de la Ley 1150 de 2007', () {
      expect(
        modalidadesContratacion.map((m) => m.id),
        containsAll([
          'licitacion_publica',
          'seleccion_abreviada_menor_cuantia',
          'subasta_inversa',
          'concurso_meritos',
          'minima_cuantia',
          'contratacion_directa',
          'regimen_especial',
        ]),
      );
    });

    for (final m in modalidadesContratacion) {
      test('${m.nombre}: configuración consistente', () {
        final etapas = m.etapas.map((e) => e.id).toList();
        expect(
          etapas.toSet().length,
          etapas.length,
          reason: 'etapas repetidas',
        );
        final docsEntidad = m.documentosEntidad.map((d) => d.id).toList();
        expect(
          docsEntidad.toSet().length,
          docsEntidad.length,
          reason: 'documentos de entidad repetidos',
        );
        if (m.esCompetitiva) {
          expect(m.etapas, isNotEmpty);
          expect(m.documentosOferente, isNotEmpty);
          expect(m.documentosContrato, isNotEmpty);
          expect(m.criterioEvaluacion, isNotNull);
        }
        for (final c in m.campos.where((c) => c.tipo == TipoCampo.seleccion)) {
          expect(c.opciones, isNotEmpty, reason: c.id);
        }
      });
    }

    test('mínima cuantía no exige RUP ni garantía de seriedad', () {
      final docs = modalidadPorId('minima_cuantia')!.documentosOferente
          .map((d) => d.id);
      expect(docs, isNot(contains('rup')));
      expect(docs, isNot(contains('garantia_seriedad')));
    });

    test(
      'licitación exige RUP, garantía de seriedad y audiencia de riesgos',
      () {
        final m = modalidadPorId('licitacion_publica')!;
        expect(
          m.documentosOferente.map((d) => d.id),
          containsAll(['rup', 'garantia_seriedad']),
        );
        expect(
          m.documentosEntidad.map((d) => d.id),
          contains('acta_audiencia_riesgos'),
        );
      },
    );
  });

  group('ProcesoContratacion', () {
    ProcesoContratacion proceso({
      Map<String, DocumentoEntidadCargado> docs = const {},
      Map<String, String> cronograma = const {},
    }) => ProcesoContratacion(
      id: 'a' * 32,
      modalidadId: 'minima_cuantia',
      equipoUid: 'master',
      creadoPorUid: 'abogado',
      creadoPorNombre: 'Abogada',
      entidadNombre: 'Alcaldía',
      entidadNit: '800',
      dependencia: 'Jurídica',
      numeroProceso: 'MC-01-2026',
      objeto: 'Suministro',
      presupuestoCop: 10000000,
      plazoEjecucion: '1 mes',
      fechaCreacionIso: '2026-10-31T00:00:00Z',
      documentosEntidad: docs,
      cronograma: cronograma,
      ofertas: const [
        OfertaRecibida(
          id: 'OF-1',
          proponente: 'Proveedor SAS',
          nit: '900123',
          valorCop: 9000000,
          puntaje: 80,
          verificaciones: {
            'rut': VerificacionRequisito(estado: EstadoVerificacion.cumple),
          },
        ),
      ],
    );

    test('ida y vuelta por mapa conserva los datos', () {
      final cargado = const DocumentoEntidadCargado(
        archivoNombre: 'ep.pdf',
        archivoMime: 'application/pdf',
        tamanoBytes: 10,
        sha256: 'x',
        cargadoPor: 'Abogada',
        fechaIso: '2026',
      );
      final original = proceso(docs: {'estudios_previos': cargado});
      final copia = ProcesoContratacion.fromMap(original.toMap());
      expect(copia.modalidad.id, 'minima_cuantia');
      expect(copia.documentosEntidad.keys, ['estudios_previos']);
      expect(copia.ofertas.single.proponente, 'Proveedor SAS');
      expect(copia.ofertas.single.puntaje, 80);
      expect(
        copia.ofertas.single.verificaciones['rut']?.estado,
        EstadoVerificacion.cumple,
      );
    });

    test('cronograma: el cierre de mínima cuantía exige 1 día hábil', () {
      // 2 de noviembre de 2026 es festivo (Todos los Santos trasladado).
      final incumple = proceso(
        cronograma: {'invitacion': '2026-10-30', 'cierre': '2026-11-02'},
      );
      expect(incumple.alertasCronograma.map((e) => e.hito.id), ['cierre']);
      final cumple = proceso(
        cronograma: {'invitacion': '2026-10-30', 'cierre': '2026-11-03'},
      );
      expect(cumple.alertasCronograma, isEmpty);
      final cierre = cumple
          .evaluarCronograma()
          .firstWhere((e) => e.hito.id == 'cierre');
      expect(cierre.limite, DateTime(2026, 11, 3));
      expect(cierre.cumple, isTrue);
    });

    test('alerta de documentos sin publicar en SECOP II', () {
      const sinPublicar = DocumentoEntidadCargado(
        archivoNombre: 'ep.pdf',
        archivoMime: 'application/pdf',
        tamanoBytes: 10,
        sha256: 'x',
        cargadoPor: 'Abogada',
        fechaIso: '2026-10-26T12:00:00',
      );
      final hoy = DateTime(2026, 11, 3);
      // 27, 28, 29, 30 de octubre y 3 de noviembre: 5 días hábiles.
      expect(sinPublicar.diasSinPublicar(hoy), 5);
      expect(
        proceso(docs: {'estudios_previos': sinPublicar})
            .publicacionesVencidas(hoy),
        ['estudios_previos'],
      );
      const publicado = DocumentoEntidadCargado(
        archivoNombre: 'ep.pdf',
        archivoMime: 'application/pdf',
        tamanoBytes: 10,
        sha256: 'x',
        cargadoPor: 'Abogada',
        fechaIso: '2026-10-26T12:00:00',
        publicadoSecop: true,
        fechaPublicacionIso: '2026-10-27',
      );
      expect(
        proceso(docs: {'estudios_previos': publicado}).publicacionesVencidas(hoy),
        isEmpty,
      );
    });

    test('resultado de verificación según los requisitos obligatorios', () {
      const a = DocumentoRequerido(id: 'a', nombre: 'A', descripcion: '');
      const b = DocumentoRequerido(id: 'b', nombre: 'B', descripcion: '');
      const opcional = DocumentoRequerido(
        id: 'c',
        nombre: 'C',
        descripcion: '',
        obligatorio: false,
      );
      const reqs = [a, b, opcional];
      VerificacionRequisito v(EstadoVerificacion e) =>
          VerificacionRequisito(estado: e);
      expect(ResultadoVerificacion.calcular(reqs, {}),
          ResultadoVerificacion.sinIniciar);
      expect(
        ResultadoVerificacion.calcular(reqs, {'a': v(EstadoVerificacion.cumple)}),
        ResultadoVerificacion.enVerificacion,
      );
      expect(
        ResultadoVerificacion.calcular(reqs, {
          'a': v(EstadoVerificacion.cumple),
          'b': v(EstadoVerificacion.subsanable),
        }),
        ResultadoVerificacion.requiereSubsanar,
      );
      expect(
        ResultadoVerificacion.calcular(reqs, {
          'a': v(EstadoVerificacion.noCumple),
          'b': v(EstadoVerificacion.subsanable),
        }),
        ResultadoVerificacion.noHabilitada,
      );
      expect(
        ResultadoVerificacion.calcular(reqs, {
          'a': v(EstadoVerificacion.cumple),
          'b': v(EstadoVerificacion.cumple),
        }),
        ResultadoVerificacion.habilitada,
      );
    });

    test('pendientes de la etapa: solo obligatorios no cargados', () {
      final p = proceso();
      expect(p.pendientesDeEtapa(0).map((d) => d.id), [
        'estudios_previos',
        'cdp',
      ]);
      // La invitación tiene adendas opcionales: no bloquean.
      expect(p.pendientesDeEtapa(1).map((d) => d.id), ['invitacion_publica']);
      expect(p.avanceDocumentosEntidad, 0);
    });
  });

  group('MiembroEquipo', () {
    MiembroEquipo miembro({
      String estado = 'activo',
      required DateTime vence,
    }) => MiembroEquipo(
      email: 'abogada@entidad.gov.co',
      nombre: 'Abogada',
      masterUid: 'master',
      masterNombre: 'Jefe Jurídico',
      permisos: {PermisoEquipo.pedirDocumentos},
      vigenteHasta: vence,
      estado: estado,
    );

    test('vigencia: activo y sin vencer', () {
      final manana = DateTime.now().add(const Duration(days: 1));
      final ayer = DateTime.now().subtract(const Duration(days: 1));
      expect(miembro(vence: manana).vigente, isTrue);
      expect(miembro(vence: ayer).vigente, isFalse);
      expect(miembro(vence: manana, estado: 'suspendido').vigente, isFalse);
    });

    test('permisos se guardan por código', () {
      final m = miembro(vence: DateTime.now().add(const Duration(days: 30)));
      final mapa = m.toMap()..['creadoEn'] = null;
      expect(mapa['permisos'], ['pedir_documentos']);
      final copia = MiembroEquipo.fromMap(mapa);
      expect(copia.permisos, {PermisoEquipo.pedirDocumentos});
      expect(copia.email, m.email);
    });

    test('cupo máximo del plan', () {
      expect(EquipoJuridicoService.cupoMaximo, 10);
    });
  });

  group('Revisión jurídica del catálogo', () {
    test('mínima cuantía y contratación directa: garantía a criterio de la entidad', () {
      for (final id in ['minima_cuantia', 'contratacion_directa']) {
        final garantia = modalidadPorId(id)!.documentosContrato
            .firstWhere((d) => d.id == 'garantia_cumplimiento');
        expect(garantia.obligatorio, isFalse, reason: id);
      }
      final licitacion = modalidadPorId('licitacion_publica')!
          .documentosContrato
          .firstWhere((d) => d.id == 'garantia_cumplimiento');
      expect(licitacion.obligatorio, isTrue);
    });

    test('la Cámara de Comercio solo se exige a personas jurídicas', () {
      for (final m in modalidadesContratacion) {
        for (final d in [...m.documentosOferente, ...m.documentosContrato]) {
          if (d.id == 'camara_comercio') {
            expect(d.obligatorio, isFalse, reason: m.id);
          }
        }
      }
    });

    test('la adjudicación cita el art. 9 de la Ley 1150 de 2007', () {
      final adjudicacion = modalidadPorId('licitacion_publica')!
          .documentosEntidad
          .firstWhere((d) => d.id == 'resolucion_adjudicacion');
      expect(adjudicacion.fundamento, 'Ley 1150 de 2007, art. 9');
    });
  });
}
