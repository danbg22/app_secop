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
    final m = EjecucionMasiva.desdeFilas(
      [
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
      [
        {
          'proceso_de_compra': 'P1',
          'n': '2',
          'contratado': '100',
          'pagado': '40',
          'facturado': '50',
          'pendiente': '60',
        },
        {
          'proceso_de_compra': 'P2',
          'n': '1',
          'contratado': '10',
          'pagado': '10',
          'facturado': '10',
          'pendiente': '0',
        },
        {'proceso_de_compra': 'P3', 'n': '3', 'contratado': '30'},
        {
          'proceso_de_compra': 'OTRO',
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

    test('suma los contratos de los procesos de cada unidad', () {
      final despacho = m.de(unidad('DESPACHO'));
      expect(despacho.contratos, 3);
      expect(despacho.contratadoCop, 110);
      expect(despacho.pagadoCop, 50);
      expect(despacho.pendienteCop, 60);
      expect(despacho.completa, isTrue);
      expect(m.de(unidad('CENTRO ok')).contratadoCop, 40);
      expect(m.de(unidad('NO EXISTE')).contratos, 0);
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
        expect(e.contratos, 6); // P1 (2) + P2 (1) + P3 (3)
        expect(e.contratadoCop, 140);
        expect(e.pagadoCop, 50);
      },
    );
  });
}
