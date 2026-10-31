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
      oferentes: const [
        OferenteProceso(
          id: 'OF-1',
          nombre: 'Proveedor SAS',
          documento: '900123',
          correo: 'p@x.co',
          tokenExpediente: 'tok',
          estado: EstadoOferente.habilitado,
          valorOfertaCop: 9000000,
          puntaje: 80,
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
      expect(copia.oferentes.single.estado, EstadoOferente.habilitado);
      expect(copia.oferentes.single.puntaje, 80);
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
}
