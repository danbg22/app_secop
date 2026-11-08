import 'package:app_secop/data/estructura_paa.dart';
import 'package:app_secop/services/paa_service.dart';
import 'package:flutter_test/flutter_test.dart';

CuentaPaa cuenta(String nombre, {String depto = '', String id = ''}) =>
    CuentaPaa(
      plan: PlanPaa(
        encabezadoId: id.isEmpty ? nombre : id,
        codigoEntidad: nombre,
        nombreEntidad: nombre,
        anio: 2026,
        version: 1,
        presupuestoGeneralCop: 0,
        menorCuantiaCop: 0,
        minimaCuantiaCop: 0,
        actualizadoIso: '',
        municipio: '',
        departamento: depto,
      ),
    );

void main() {
  test('MinTrabajo: seccionales con NIT propio en una sola familia', () {
    final f = EstructuraPaa.familiaDe(
      'MINISTERIO DEL TRABAJO DIRECCIÓN TERRITORIAL DE ANTIOQUIA',
    );
    expect(f?.nombre, 'Ministerio del Trabajo');
    expect(EstructuraPaa.familiaDe('MINTRABAJO DT META'), f);
    // "Para el trabajo" no es el ministerio.
    expect(
      EstructuraPaa.familiaDe('CENTRO DE FORMACION INTEGRAL PARA EL TRABAJO'),
      isNull,
    );
  });

  test(
    'nivel central y territoriales por departamento, sin repetir la entidad',
    () {
      final fam = familiasPaa.first;
      final grupos = EstructuraPaa.agrupar('', [
        cuenta('MINTRABAJO NIVEL CENTRAL*/'),
        cuenta('MINISTERIO DEL TRABAJO DIRECCIÓN TERRITORIAL DE ANTIOQUIA'),
        cuenta(
          'MINISTERIO DEL TRABAJO DIRECCION TERRITORIAL DE URABA',
          depto: 'Antioquia',
        ),
        cuenta(
          'OFICINA ESPECIAL MINISTERIO DE TRABAJO BUENAVENTURA',
          depto: 'Valle del Cauca',
        ),
      ], familia: fam);
      expect(grupos.first.titulo, 'Nivel central');
      expect(grupos.first.nodos.single.nombre, 'Nivel central');
      final antioquia = grupos.firstWhere((g) => g.titulo == 'Antioquia');
      expect(antioquia.nodos.length, 2);
      expect(
        antioquia.nodos.map((n) => n.nombre),
        contains('Dirección Territorial de Antioquia'),
      );
      expect(grupos.any((g) => g.titulo == 'Valle del Cauca'), isTrue);
    },
  );

  test('SENA: regionales y centros con nombre uniforme', () {
    final grupos = EstructuraPaa.agrupar('899999034', [
      cuenta('SENA DIRECCION GENERAL', depto: 'Distrito Capital de Bogotá'),
      cuenta(
        'SENA REGIONAL CESAR Grupo de Apoyo Administrativo Mixto',
        depto: 'Cesar',
      ),
      cuenta(
        'SENA REGIONAL ANTIOQUIA Grupo Administrativo CFMA',
        depto: 'Antioquia',
      ),
      cuenta(
        'SENA REGIONAL ANTIOQUIA Grupo de Apoyo Administrativo Mixto',
        depto: 'Antioquia',
      ),
      cuenta(
        'SENA REGIONAL ANTIOQUIA Grupo Administrativo Intercentros Medellin',
        depto: 'Antioquia',
      ),
    ]);
    expect(grupos.first.titulo, 'Dirección General');
    expect(grupos.first.esCentral, isTrue);
    final antioquia = grupos.firstWhere(
      (g) => g.titulo == 'Regional Antioquia',
    );
    expect(antioquia.nodos.map((n) => n.nombre), [
      'Centro de Formación Minero Ambiental',
      'Grupo Administrativo Intercentros Medellín',
      'Grupo de Apoyo Administrativo Mixto',
    ]);
    expect(grupos.any((g) => g.titulo == 'Regional Cesar'), isTrue);
  });

  test('el total de un grupo espera a todas sus cuentas', () {
    final g = GrupoPaa(
      titulo: 'Regional',
      nodos: [
        NodoPaa(nombre: 'a', cuenta: cuenta('A')),
        NodoPaa(nombre: 'b', cuenta: cuenta('B')),
      ],
    );
    expect(g.total({'A': (compras: 3, total: 100)}), isNull);
    expect(
      g.total({'A': (compras: 3, total: 100), 'B': (compras: 1, total: 50)}),
      150,
    );
    expect(PaaService.nit9('8999990341'), '899999034');
  });
}
