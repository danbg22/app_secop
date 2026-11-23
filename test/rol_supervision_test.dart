import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/services/contratos_vinculados_service.dart';
import 'package:app_secop/services/juridico_contratacion_service.dart';
import 'package:app_secop/screens/supervision/registro_supervision.dart';
import 'package:app_secop/services/payment_service.dart';
import 'package:app_secop/services/supervision_service.dart';
import 'package:app_secop/widgets/ilustracion_rol.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';

  group('Rol Supervisión de contratos', () {
    test('solo el Supervisor paga entre los tres perfiles', () {
      final subroles = PaymentService.subrolesDe(
        AdminConfiguracionRolesYPagos.grupoSupervision,
      );
      expect(subroles.map((r) => r.id), [
        'supervisor_contratos',
        'contratista',
        'juridico_supervision',
      ]);
      final supervisor = subroles.first;
      final contratista = subroles[1];
      expect(subroles.last.esGratuito, isTrue);
      expect(supervisor.esGratuito, isFalse);
      expect(supervisor.precioCop, greaterThan(0));
      expect(contratista.esGratuito, isTrue);
      expect(contratista.precioFormateadoCop, 'Gratis');
      expect(subroles.every((r) => r.habilitadoParaRegistro), isTrue);
    });

    test('solo habilita su propia sección, no la de Equipo jurídico', () {
      for (final id in [
        'supervisor_contratos',
        'contratista',
        'juridico_supervision',
      ]) {
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
      expect(
        PaymentService.normalizarRolId('Jurídico'),
        'juridico_supervision',
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

    test('la plantilla genérica conserva compatibilidad con expedientes anteriores', () {
      final etapas = PlantillaInforme.porDefecto('Entidad').etapas;
      expect(etapas.map((e) => e.id), ['supervisor']);
    });

    test(
      'el contrato vinculado fija verificación inicial y aprobación final',
      () {
        final exp = ExpedienteContratoPs.fromMap({
          'estadoVinculacion': 'aprobada',
          'juridicoRevisionEmail': 'juridico@entidad.gov.co',
          'juridicoRevisionNombre': 'Asesora jurídica',
        });
        final etapas = SupervisionService.etapasDelContrato(
          exp,
          [
            ...PlantillaInforme.porDefecto('Entidad').etapas,
            const EtapaAprobacion(id: 'finanzas', nombre: 'Control financiero'),
            const EtapaAprobacion(id: 'juridico', nombre: 'Otra etapa'),
          ],
          supervisorNombre: 'Supervisora',
          supervisorEmail: 'supervision@entidad.gov.co',
        );
        expect(etapas.map((e) => e.id), ['juridico', 'finanzas', 'supervisor']);
        expect(etapas.first.responsableEmail, 'juridico@entidad.gov.co');
        expect(etapas.last.responsableEmail, 'supervision@entidad.gov.co');
        expect(
          ExpedienteContratoPs.fromMap(exp.toMap()).juridicoRevisionNombre,
          'Asesora jurídica',
        );
        expect(ExpedienteContratoPs.fromMap({}).vinculacionAprobada, isTrue);
        expect(
          ExpedienteContratoPs.fromMap({'estadoVinculacion': 'pendiente'})
              .vinculacionAprobada,
          isFalse,
        );
      },
    );
  });

  group('Contratos del Contratista', () {
    test('identifica el contrato por NIT canónico, cuenta y número', () {
      expect(
        RegistroSupervisionService.nitEntidad('899.999.061-9'),
        '899999061',
      );
      expect(RegistroSupervisionService.nitEntidad('899999061'), '899999061');
      expect(RegistroSupervisionService.nitEntidad('899999061-8'), isNull);
      expect(RegistroSupervisionService.nitEntidad('otra entidad'), isNull);
      final id = RegistroSupervisionService.idContrato(
        'usuario',
        '899999061',
        ' CPS-01 ',
      );
      expect(
        RegistroSupervisionService.idContrato('usuario', '899999061', 'cps-01'),
        id,
      );
      expect(
        RegistroSupervisionService.idContrato('usuario', '900000002', 'CPS-01'),
        isNot(id),
      );
      expect(
        RegistroSupervisionService.idContrato(
          'otra cuenta',
          '899999061',
          'CPS-01',
        ),
        isNot(id),
      );
    });

    test('normaliza el código del supervisor y rechaza datos incompletos', () {
      expect(
        RegistroSupervisionService.normalizarCodigo(
          ' sup-abcd-ef12 3456 7890 abcd ef12 ',
        ),
        'SUP-ABCDEF1234567890ABCDEF12',
      );
      expect(RegistroSupervisionService.normalizarCodigo('SUP-ABC'), isNull);
      expect(RegistroSupervisionService.normalizarCodigo('800222222'), isNull);
    });

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

  testWidgets(
    'el alta del supervisor muestra los datos de su vinculación y de Jurídico',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegistroSupervision(esSupervisor: true),
            ),
          ),
        ),
      );
      expect(find.text('Número del acto de nombramiento'), findsOneWidget);
      expect(find.text('Correo de Jurídico'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contratista').last);
      await tester.pumpAndSettle();
      for (final etiqueta in [
        'Número de tu contrato',
        'Fecha de aprobación en SECOP',
        'Número del RP',
        'Forma de pago',
        'Correo de Jurídico',
      ]) {
        expect(find.text(etiqueta), findsOneWidget);
      }
      expect(find.text('Número del acto de nombramiento'), findsNothing);
    },
  );

  testWidgets(
    'el contratista confirma el código y completa los datos presupuestales',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RegistroSupervision(esSupervisor: false),
            ),
          ),
        ),
      );
      for (final etiqueta in [
        'Código único del supervisor',
        'Confirmar supervisor',
        'Enviar solicitud de vinculación',
        'Número del contrato',
        'Fecha de aprobación en SECOP',
        'Valor total del contrato (COP)',
        'Duración',
        'Forma de pago',
        'Número del RP',
        'Número del CDP',
      ]) {
        expect(find.text(etiqueta), findsOneWidget);
      }
      await tester.tap(find.text('Confirmar supervisor'));
      await tester.pump();
      expect(find.textContaining('Ingresa el código SUP'), findsOneWidget);
      expect(find.text('Correo de Jurídico'), findsNothing);
    },
  );

  testWidgets('la ilustración de Supervisión se dibuja sin imagen propia', (
    tester,
  ) async {
    for (final id in [
      AdminConfiguracionRolesYPagos.grupoSupervision,
      'supervisor_contratos',
      'contratista',
      'juridico_supervision',
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
