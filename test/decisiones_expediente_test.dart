import 'package:app_secop/services/juridico_contratacion_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> apartado(String id, String estado, int version) => {
  'id': id,
  'nombre': 'Documento $id',
  'descripcion': '',
  'obligatorio': true,
  'estado': estado,
  'archivoNombre': 'archivo_$id.pdf',
  'versionCarga': version,
};

Map<String, dynamic> expediente({
  required List<Map<String, dynamic>> apartados,
  Map<String, dynamic>? decisiones,
}) => {
  'id': 'EXP',
  'tokenInvitado': 'a' * 32,
  'entidadNombre': 'Entidad',
  'entidadNit': '800000000',
  'dependencia': '',
  'numeroContrato': '1',
  'objetoContrato': 'Objeto',
  'valorContratoCop': 1,
  'plazoEjecucion': '',
  'contratistaNombreEsperado': '',
  'contratistaCedulaEsperada': '',
  'contratistaCorreo': '',
  'contratistaTelefono': '',
  'creadoPorEmail': '',
  'creadoPorNombre': '',
  'fechaCreacionIso': '2026-11-19',
  'apartados': apartados,
  'trazabilidad': const [],
  'decisiones': ?decisiones,
};

EstadoDocumentoJuridico estadoDe(ExpedienteContratoPs e, String id) =>
    e.apartados.firstWhere((a) => a.id == id).estado;

void main() {
  group('Decisiones del equipo sobre los documentos', () {
    test('un "aprobado" sin decisión del equipo vuelve a revisión', () {
      final e = ExpedienteContratoPs.fromMap(
        expediente(
          apartados: [
            apartado('a', 'APROBADO', 1),
            apartado('b', 'APROBADO', 2),
            apartado('c', 'DEVUELTO_SUBSANAR', 1),
          ],
          decisiones: {
            // Solo "a" lo aprobó el equipo.
            'a': {'estado': 'APROBADO', 'version': 1, 'revisadoPor': 'Equipo'},
          },
        ),
      );
      expect(estadoDe(e, 'a'), EstadoDocumentoJuridico.aprobado);
      expect(estadoDe(e, 'b'), EstadoDocumentoJuridico.subsanadoEnRevision);
      expect(estadoDe(e, 'c'), EstadoDocumentoJuridico.enRevision);
    });

    test('una decisión vale solo para la versión que se revisó', () {
      final e = ExpedienteContratoPs.fromMap(
        expediente(
          apartados: [apartado('a', 'SUBSANADO_EN_REVISION', 2)],
          decisiones: {
            'a': {'estado': 'DEVUELTO_SUBSANAR', 'version': 1},
          },
        ),
      );
      // El contratista subió una versión nueva: queda en revisión.
      expect(estadoDe(e, 'a'), EstadoDocumentoJuridico.subsanadoEnRevision);
    });

    test(
      'la decisión del equipo manda sobre lo que escriba el contratista',
      () {
        final e = ExpedienteContratoPs.fromMap(
          expediente(
            apartados: [apartado('a', 'EN_REVISION', 1)],
            decisiones: {
              'a': {
                'estado': 'DEVUELTO_SUBSANAR',
                'version': 1,
                'observacion': 'Falta la firma',
              },
            },
          ),
        );
        final a = e.apartados.single;
        expect(a.estado, EstadoDocumentoJuridico.devueltoSubsanar);
        expect(a.observacionJuridica, 'Falta la firma');
      },
    );

    test('los expedientes anteriores al campo se leen como estaban', () {
      final e = ExpedienteContratoPs.fromMap(
        expediente(apartados: [apartado('a', 'APROBADO', 1)]),
      );
      expect(estadoDe(e, 'a'), EstadoDocumentoJuridico.aprobado);
      expect(e.decisiones, isNull);
    });

    test('la escritura del equipo registra sus decisiones', () {
      final e = ExpedienteContratoPs.fromMap(
        expediente(
          apartados: [
            apartado('a', 'APROBADO', 1),
            apartado('b', 'EN_REVISION', 1),
          ],
        ),
      ).conDecisionesDelEquipo();
      final mapa = e.toMap();
      final decisiones = mapa['decisiones'] as Map;
      expect(decisiones.keys, ['a']);
      expect(decisiones['a']['estado'], 'APROBADO');
      expect(decisiones['a']['version'], 1);
      // Y al leerlo de nuevo, "a" sigue aprobado.
      final releido = ExpedienteContratoPs.fromMap(
        Map<String, dynamic>.from(mapa)..addAll(
          expediente(
            apartados: [
              apartado('a', 'APROBADO', 1),
              apartado('b', 'EN_REVISION', 1),
            ],
          )..remove('decisiones'),
        ),
      );
      expect(estadoDe(releido, 'a'), EstadoDocumentoJuridico.aprobado);
    });
  });
}
