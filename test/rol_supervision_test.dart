import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/contratos_vinculados_service.dart';
import 'package:app_secop/services/payment_service.dart';
import 'package:app_secop/services/supervision_service.dart';
import 'package:app_secop/widgets/ilustracion_rol.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';

  group('Rol Supervisión de contratos', () {
    test('tiene dos subroles: Supervisor (pago) y Contratista (gratis)', () {
      final subroles = PaymentService.subrolesDe(
        AdminConfiguracionRolesYPagos.grupoSupervision,
      );
      expect(subroles.map((r) => r.id), [
        'supervisor_contratos',
        'contratista',
      ]);
      final supervisor = subroles.first;
      final contratista = subroles.last;
      expect(supervisor.esGratuito, isFalse);
      expect(supervisor.precioCop, greaterThan(0));
      expect(contratista.esGratuito, isTrue);
      expect(contratista.precioFormateadoCop, 'Gratis');
      expect(subroles.every((r) => r.habilitadoParaRegistro), isTrue);
    });

    test('solo habilita su propia sección, no la de Equipo jurídico', () {
      for (final id in ['supervisor_contratos', 'contratista']) {
        final permisos = PaymentService.obtenerConfiguracionRol(id)
            .permisosPlataforma;
        expect(permisos, isNot(contains('gestion_juridica_entidad')));
        expect(permisos, isNot(contains('contratos')));
      }
      expect(
        PaymentService.usuarioTienePermiso(
          rolesActivos: const ['supervisor_contratos'],
          permiso: 'supervision_contratos',
        ),
        isTrue,
      );
      expect(
        PaymentService.usuarioTienePermiso(
          rolesActivos: const ['equipo_juridico'],
          permiso: 'supervision_contratos',
        ),
        isFalse,
      );
    });

    test('los ids nuevos no se confunden con Persona al normalizar', () {
      expect(
        PaymentService.normalizarRolId('supervisor_contratos'),
        'supervisor_contratos',
      );
      expect(
        PaymentService.normalizarRolId('Supervisor'),
        'supervisor_contratos',
      );
      expect(PaymentService.normalizarRolId('contratista'), 'contratista');
      expect(
        PaymentService.normalizarRolId('equipo_juridico'),
        'equipo_juridico',
      );
      expect(
        PaymentService.formatearEtiquetaRolesAcumulados(const [
          'persona',
          'contratista',
        ]),
        'Persona + Contratista',
      );
    });
  });

  group('Designación del supervisor', () {
    test('el supervisor va primero, en minúsculas y sin repetir', () {
      expect(
        AsignacionSupervision.revisoresCon('Sup@Entidad.gov.co ', [
          'apoyo@entidad.gov.co',
          'SUP@entidad.gov.co',
          '',
          'sin-arroba',
          'Apoyo@Entidad.gov.co',
        ]),
        ['sup@entidad.gov.co', 'apoyo@entidad.gov.co'],
      );
      final muchos = AsignacionSupervision.revisoresCon('s@x.co', [
        for (var i = 0; i < 20; i++) 'r$i@x.co',
      ]);
      expect(muchos.length, 8);
      expect(muchos.first, 's@x.co');
    });

    test('ida y vuelta por Firestore conserva supervisor y revisores', () {
      const a = AsignacionSupervision(
        token: token,
        supervisorNombre: 'Supervisora de prueba',
        supervisorEmail: 'Supervisora@Entidad.gov.co',
        revisoresEmails: ['financiera@entidad.gov.co'],
        numeroContrato: 'CPS-001',
      );
      final mapa = a.toMap();
      expect(mapa['supervisorEmail'], 'supervisora@entidad.gov.co');
      expect(mapa['revisoresEmails'], [
        'supervisora@entidad.gov.co',
        'financiera@entidad.gov.co',
      ]);
      final b = AsignacionSupervision.fromMap(mapa);
      expect(b.esSupervisor('SUPERVISORA@entidad.gov.co'), isTrue);
      expect(b.esSupervisor('financiera@entidad.gov.co'), isFalse);
      expect(b.esRevisor('financiera@entidad.gov.co'), isTrue);
      expect(b.esRevisor('otro@entidad.gov.co'), isFalse);
      expect(b.numeroContrato, 'CPS-001');
    });

    test('la cadena por defecto empieza en el supervisor, sin el jurídico', () {
      final etapas = PlantillaInforme.porDefecto('Entidad').etapas;
      expect(etapas.map((e) => e.id), ['supervisor']);
    });
  });

  group('Contratos del Contratista', () {
    test('toma el contrato del enlace que envía la entidad', () {
      expect(
        ContratosVinculadosService.tokenDesdeTexto(
          'https://contratalegal.co/?invitado_token=$token#/invitado-contrato?token=$token',
        ),
        token,
      );
      expect(
        ContratosVinculadosService.tokenDesdeTexto(
          ' https://x.netlify.app/#/invitado-contrato?token=${token.toUpperCase()} ',
        ),
        token,
      );
      expect(ContratosVinculadosService.tokenDesdeTexto(token), token);
    });

    test('rechaza textos que no son el enlace del contrato', () {
      expect(ContratosVinculadosService.tokenDesdeTexto(''), '');
      expect(ContratosVinculadosService.tokenDesdeTexto('CPS-001-2026'), '');
      expect(
        ContratosVinculadosService.tokenDesdeTexto('https://contratalegal.co/'),
        '',
      );
    });

    test('ida y vuelta del contrato vinculado', () {
      const c = ContratoVinculado(
        token: token,
        numeroContrato: 'CPS-001',
        objetoContrato: 'Prestación de servicios profesionales',
        entidadNombre: 'Entidad de prueba',
        vinculadoEnIso: '2026-11-19T00:00:00.000Z',
      );
      final d = ContratoVinculado.fromMap(c.toMap());
      expect(d.token, token);
      expect(d.numeroContrato, 'CPS-001');
      expect(d.entidadNombre, 'Entidad de prueba');
    });
  });

  testWidgets('la ilustración de Supervisión se dibuja sin imagen propia', (
    tester,
  ) async {
    for (final id in [
      AdminConfiguracionRolesYPagos.grupoSupervision,
      'supervisor_contratos',
      'contratista',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 184,
              height: 150,
              child: IlustracionRol(rolId: id),
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byType(Icon), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}
