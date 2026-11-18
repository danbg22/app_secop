import 'package:app_secop/services/presupuesto_dependencias_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Unidades de contratación de SECOP II', () {
    test('agrupa las variantes con que se escribe la misma dependencia', () {
      const s = PresupuestoDependenciasService.normalizarUnidad;
      expect(
        s('UNIDAD DE CONTRATACION DESPACHO REGIONAL ok'),
        'DESPACHO REGIONAL',
      );
      expect(
        s('UNIDAD DE CONTRATACIÓN DESPACHO REGIONAL'),
        'DESPACHO REGIONAL',
      );
      expect(
        s('UNIDAD DE CONTRATACION CAE***'),
        s('UNIDAD DE CONTRATACION CAE'),
      );
      expect(s('UNIDAD DE CONTRATACIÓN CBC..'), 'CBC');
      expect(s('UNIDAD DE CONTRATACION DEL CIGEC'), s('CIGEC'));
      expect(s('GERENCIA DE CONTRATACIÒN'), s('Gerencia de Contratación'));
      expect(s(''), 'SIN UNIDAD REGISTRADA');
    });

    test('muestra nombres legibles con tildes y siglas', () {
      const n = PresupuestoDependenciasService.nombreParaMostrar;
      expect(
        n('UNIDAD DE CONTRATACION DESPACHO REGIONAL ok'),
        'Despacho Regional',
      );
      expect(n('UNIDAD DE CONTRATACION DEL CIGEC'), 'CIGEC');
      expect(
        n('VICEPRESIDENCIA JURIDICA  GERENCIA DE CONTRATACIÒN'),
        'Vicepresidencia Juridica Gerencia de Contratación',
      );
      expect(
        n('Dirección Administrativa y Financiera'),
        'Dirección Administrativa y Financiera',
      );
    });
  });

  group('Ejecución de todas las dependencias de una vez', () {
    // Dos unidades de la misma cuenta; el portafolio P2 aparece en las dos.
    // P4 es un proceso sin fecha de publicación.
    final m = EjecucionMasiva.desdeFilas(
      anio: 2026,
      procesos: [
        {
          'entidad': 'CUENTA ',
          'nombre_de_la_unidad_de': 'DESPACHO',
          'id_del_portafolio': 'P1',
        },
        {
          'entidad': 'CUENTA',
          'nombre_de_la_unidad_de': 'DESPACHO',
          'id_del_portafolio': 'P2',
        },
        {
          'entidad': 'CUENTA',
          'nombre_de_la_unidad_de': 'CENTRO ok',
          'id_del_portafolio': 'P2',
        },
        {
          'entidad': 'CUENTA',
          'nombre_de_la_unidad_de': 'CENTRO ok',
          'id_del_portafolio': 'P3',
        },
        {'entidad': 'CUENTA', 'nombre_de_la_unidad_de': 'CENTRO ok'},
      ],
      procesosSinFecha: [
        {
          'entidad': 'CUENTA',
          'nombre_de_la_unidad_de': 'CENTRO ok',
          'id_del_portafolio': 'P4',
          'pb': '70',
        },
        // Sin contratos firmados en la vigencia: no entra.
        {
          'entidad': 'CUENTA',
          'nombre_de_la_unidad_de': 'CENTRO ok',
          'id_del_portafolio': 'P5',
          'pb': '900',
        },
      ],
      contratos: [
        {
          'proceso_de_compra': 'P1',
          'af': '2026',
          'n': '2',
          'contratado': '100',
          'pagado': '40',
          'facturado': '50',
          'pendiente': '60',
        },
        {
          'proceso_de_compra': 'P2',
          'af': '2026',
          'n': '1',
          'contratado': '10',
          'pagado': '10',
          'facturado': '10',
          'pendiente': '0',
        },
        // Sin fecha de firma y proceso de la vigencia: cuenta.
        {'proceso_de_compra': 'P3', 'n': '3', 'contratado': '30'},
        // Firmado en otra vigencia: no cuenta.
        {
          'proceso_de_compra': 'P3',
          'af': '2025',
          'n': '5',
          'contratado': '500',
        },
        // Proceso sin fecha con contrato firmado en la vigencia: cuenta.
        {'proceso_de_compra': 'P4', 'af': '2026', 'n': '1', 'contratado': '65'},
        // Sin fecha de firma y proceso sin fecha: no se sabe la vigencia.
        {'proceso_de_compra': 'P5', 'n': '1', 'contratado': '800'},
        {
          'proceso_de_compra': 'OTRO',
          'af': '2026',
          'n': '9',
          'contratado': '999',
          'pagado': '999',
        },
      ],
    );
    DependenciaPresupuesto unidad(String nombre) => DependenciaPresupuesto(
      clave: 'CUENTA|$nombre',
      nombre: nombre,
      cuentaSecop: 'CUENTA',
      variantes: [nombre],
      procesos: 2,
      asignadoCop: 0,
    );

    test('suma los contratos firmados en la vigencia de cada unidad', () {
      final despacho = m.de(unidad('DESPACHO'));
      expect(despacho.contratos, 3);
      expect(despacho.contratadoCop, 110);
      expect(despacho.pagadoCop, 50);
      expect(despacho.pendienteCop, 60);
      expect(despacho.completa, isTrue);
      expect(despacho.procesosSinFecha, 0);
      expect(m.de(unidad('NO EXISTE')).contratos, 0);
    });

    test('ubica los procesos sin fecha por la firma de sus contratos', () {
      final centro = m.de(unidad('CENTRO ok'));
      // P2 (10) + P3 sin fecha de firma (30) + P4 (65).
      expect(centro.contratadoCop, 105);
      expect(centro.contratos, 5);
      expect(centro.procesosSinFecha, 1);
      expect(centro.asignadoSinFechaCop, 70);
    });

    test(
      'una dependencia agrupada no cuenta dos veces un proceso compartido',
      () {
        final grupo = DependenciaPresupuesto.agrupada(
          clave: 'g',
          nombre: 'Grupo',
          partes: [unidad('DESPACHO'), unidad('CENTRO ok')],
        );
        final e = m.de(grupo);
        expect(e.contratos, 7); // P1 (2) + P2 (1) + P3 (3) + P4 (1)
        expect(e.contratadoCop, 205);
        expect(e.pagadoCop, 50);
      },
    );

    test('empareja los departamentos de la Tienda Virtual', () {
      const igual = PresupuestoDependenciasService.mismoDepartamento;
      expect(igual('Bogotá, D.C.', 'Distrito Capital de Bogotá'), isTrue);
      expect(igual('Cesar', 'Cesar'), isTrue);
      expect(igual('Santander', 'Norte de Santander'), isFalse);
      expect(igual('Atlántico', 'ATLANTICO'), isTrue);
    });
  });
}
