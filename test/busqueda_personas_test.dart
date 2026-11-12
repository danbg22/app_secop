import 'package:app_secop/services/busqueda_personas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalización y palabras', () {
    test('quita tildes y pasa la Ñ a N', () {
      expect(BusquedaPersonas.normalizar('  Fabián  Núñez '), 'FABIAN NUNEZ');
      expect(BusquedaPersonas.normalizar('muñoz'), 'MUNOZ');
    });

    test('divide en palabras sin signos ni repetidas', () {
      expect(BusquedaPersonas.tokens("fabian  cuello"), ['FABIAN', 'CUELLO']);
      expect(BusquedaPersonas.tokens("O'Neil, Ana-María"), [
        'O',
        'NEIL',
        'ANA',
        'MARIA',
      ]);
      expect(BusquedaPersonas.tokens('ana ana'), ['ANA']);
    });

    test('documento: solo dígitos y separadores', () {
      expect(BusquedaPersonas.esDocumento('1.065.842.391'), isTrue);
      expect(BusquedaPersonas.esDocumento('900123456-7'), isTrue);
      expect(BusquedaPersonas.esDocumento('fabian 1'), isFalse);
      expect(BusquedaPersonas.esDocumento('--'), isFalse);
    });
  });

  group('SoQL', () {
    test('el patrón tolera tildes y eñes en vocales y N', () {
      expect(BusquedaPersonas.patronTolerante('FABIAN'), 'F_B___');
      expect(BusquedaPersonas.patronTolerante('CUELLO'), 'C__LL_');
    });

    test('exige todas las palabras en cualquier posición', () {
      expect(
        BusquedaPersonas.whereTodasLasPalabras('proveedor_adjudicado', [
          'FABIAN',
          'CUELLO',
        ]),
        "upper(proveedor_adjudicado) LIKE '%F_B___%' AND "
        "upper(proveedor_adjudicado) LIKE '%C__LL_%'",
      );
    });

    test('el texto completo descarta palabras de menos de tres letras', () {
      expect(
        BusquedaPersonas.textoCompleto(['ANA', 'DE', 'LA', 'CRUZ']),
        'ANA CRUZ',
      );
    });
  });

  group('coincidencia y unión', () {
    test('todas las palabras, en cualquier orden y sin importar tildes', () {
      const palabras = ['FABIAN', 'CUELLO'];
      expect(
        BusquedaPersonas.nombreCoincide('FREDY FABIAN CUELLO ROJAS', palabras),
        isTrue,
      );
      expect(
        BusquedaPersonas.nombreCoincide(
          'Fabián Alberto Cuello Redondo',
          palabras,
        ),
        isTrue,
      );
      expect(
        BusquedaPersonas.nombreCoincide('FABIAN DAVID ALARCON', palabras),
        isFalse,
      );
      expect(BusquedaPersonas.nombreCoincide('JUAN NUÑEZ', ['NUNEZ']), isTrue);
    });

    test('la clave une el NIT con y sin dígito de verificación', () {
      expect(BusquedaPersonas.claveUnion('8000963297', 'x'), '800096329');
      expect(BusquedaPersonas.claveUnion('800.096.329', 'x'), '800096329');
      expect(BusquedaPersonas.claveUnion('', 'Ana Pérez'), 'N:ANA PEREZ');
    });

    test('suma SECOP II y SECOP I por documento y marca servidores', () {
      final personas = BusquedaPersonas.unir(
        {
          FuentePersona.secopII: [
            {
              'proveedor_adjudicado': 'FREDY FABIAN CUELLO ROJAS',
              'documento_proveedor': '79752978',
              'tipodocproveedor': 'Cédula de Ciudadanía',
              'contratos': '2',
              'total_valor': '1000',
              'ultima_fecha': '2026-01-22T00:00:00.000',
              'entidades': '1',
            },
            // No contiene "cuello": se descarta.
            {
              'proveedor_adjudicado': 'FABIAN PEREZ',
              'documento_proveedor': '123456',
              'contratos': '1',
            },
          ],
          FuentePersona.secopI: [
            {
              'nom_razon_social_contratista': 'FREDDY FABIAN CUELLO ROJAS',
              'identificacion_del_contratista': '79752978',
              'contratos': '1',
              'total_valor': '500',
              'ultima_fecha': '2015-03-01T00:00:00.000',
              'entidades': '2',
            },
          ],
          FuentePersona.servidores: [
            {
              'numero_documento': '555666',
              'nombre_pep': 'FABIAN ALBERTO CUELLO REDONDO',
              'denominacion_cargo': 'CONDUCTOR',
              'nombre_entidad': 'DEFENSORIA DEL PUEBLO',
            },
          ],
        },
        const ['FABIAN', 'CUELLO'],
      );

      expect(personas, hasLength(2));
      final fredy = personas.firstWhere((p) => p.documento == '79752978');
      expect(fredy.contratos, 3);
      expect(fredy.valor, 1500);
      expect(fredy.ultimaFecha, startsWith('2026'));
      expect(fredy.entidades, 2);
      expect(fredy.fuentes, {FuentePersona.secopII, FuentePersona.secopI});
      expect(fredy.servidorPublico, isFalse);

      final servidor = personas.firstWhere((p) => p.documento == '555666');
      expect(servidor.servidorPublico, isTrue);
      expect(servidor.contratos, 0);
      expect(servidor.cargoEntidad, 'CONDUCTOR · DEFENSORIA DEL PUEBLO');
    });

    test('una sigla trae a la entidad aunque el nombre no la contenga', () {
      final personas = BusquedaPersonas.unir(
        {
          FuentePersona.secopII: [
            {
              'proveedor_adjudicado': 'UNIVERSIDAD INDUSTRIAL DE SANTANDER',
              'documento_proveedor': '8902012134',
              'contratos': '4',
            },
          ],
        },
        const ['UIS'],
        documentosSigla: const ['890201213'],
      );
      expect(personas.single.contratos, 4);
    });

    test('"No definido" no es una persona', () {
      final personas = BusquedaPersonas.unir({
        FuentePersona.secopII: [
          {'proveedor_adjudicado': 'No Definido', 'documento_proveedor': ''},
        ],
      }, const []);
      expect(personas, isEmpty);
    });
  });

  group('directorio del SIGEP', () {
    test('se une por nombre exacto con quien ya tiene contratos', () {
      final personas = BusquedaPersonas.unir(
        {
          FuentePersona.secopII: [
            {
              'proveedor_adjudicado': 'JUAN CARLOS BERMUDEZ CUELLO',
              'documento_proveedor': '1234567',
              'contratos': '3',
            },
          ],
          FuentePersona.sigep: [
            {
              'id_sigep': 'S1-2-3',
              'nombre': 'Juan Carlos Bermúdez Cuello',
              'tipo': 'Servidor Público',
              'entidad': 'ALCALDIA DE VALLEDUPAR',
            },
          ],
        },
        const ['CUELLO'],
      );
      expect(personas, hasLength(1));
      expect(personas.single.contratos, 3);
      expect(personas.single.servidorPublico, isTrue);
      expect(personas.single.idSigep, 'S1-2-3');
      expect(personas.single.cargoEntidad, 'ALCALDIA DE VALLEDUPAR');
    });

    test('quien solo está en el SIGEP aparece sin contratos', () {
      final personas = BusquedaPersonas.unir(
        {
          FuentePersona.sigep: [
            {
              'id_sigep': 'S9-8-7',
              'nombre': 'FABIAN ALBERTO CUELLO REDONDO',
              'tipo': 'Servidor Público',
              'entidad': 'DEFENSORIA DEL PUEBLO',
            },
            {
              'id_sigep': 'S5-5-5',
              'nombre': 'CARLOS ALBERTO CUELLO GUTIERREZ',
              'tipo': 'Contratista',
              'entidad': 'SERVICIO NACIONAL DE APRENDIZAJE',
            },
            // La búsqueda del SIGEP también coincide por entidad: se descarta.
            {
              'id_sigep': 'S6-6-6',
              'nombre': 'PEDRO PEREZ',
              'tipo': 'Servidor Público',
              'entidad': 'FABIAN CUELLO S.A.S.',
            },
          ],
        },
        const ['CUELLO'],
      );
      expect(personas, hasLength(2));
      final fabian = personas.firstWhere((p) => p.idSigep == 'S9-8-7');
      expect(fabian.servidorPublico, isTrue);
      expect(fabian.contratos, 0);
      expect(fabian.fuentes, {FuentePersona.sigep});
      final carlos = personas.firstWhere((p) => p.idSigep == 'S5-5-5');
      expect(carlos.servidorPublico, isFalse);
      expect(
        carlos.cargoEntidad,
        'Contratista · SERVICIO NACIONAL DE APRENDIZAJE',
      );
    });
  });
}
