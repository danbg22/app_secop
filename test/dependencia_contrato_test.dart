import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/utils/dependencia_contrato.dart';

void main() {
  String? dep(String objeto, {String ciudad = ''}) =>
      DependenciaContrato.deTexto(objeto, ciudad: ciudad);

  group('Dependencia según el objeto del contrato', () {
    test('alcaldía: secretarías y oficinas', () {
      expect(
        dep(
          'PRESTACIÓN DE SERVICIOS PROFESIONALES PARA BRINDAR APOYO JURÍDICO EN '
          'EL TRÁMITE DE LOS PROCESOS DE PRESCRIPCIÓN DE LA SECRETARÍA DE '
          'HACIENDA MUNICIPAL',
        ),
        'Secretaría de Hacienda Municipal',
      );
      expect(
        dep(
          'PRESTACIÓN DE SERVICIOS DE APOYO A LA GESTION JURIDICA EN LA '
          'SECRETARIA DE OBRAS PUBLICAS DEL MUNICIPIO DE VALLEDUPAR',
        ),
        'Secretaria de Obras Publicas',
      );
      expect(
        dep(
          'PRESTACIÓN DE SERVICIOS DE APOYO A LA GESTIÓN A LA SECRETARÍA DE\n'
          'GOBIERNO EN EL DESARROLLO DE LAS ACTIVIDADES',
        ),
        'Secretaría de Gobierno',
      );
      expect(
        dep(
          'APOYO A LA GESTION ADMINISTRATIVA A LA OFICINA DE BIENES INMUEBLES '
          'ADSCRITA A LA SECRETARIA GENERAL',
        ),
        'Oficina de Bienes Inmuebles',
      );
      expect(
        dep(
          'SERVICIOS ESPECIALIZADOS PARA BRINDAR ASESORIA JURÍDICA AL DESPACHO '
          'DEL ALCALDE DEL MUNICIPIO DE VALLEDUPAR',
        ),
        'Despacho del Alcalde',
      );
      expect(
        dep(
          'APOYO A LA GESTIÓN ADMINISTRATIVA DE LA SECRETARÍA LOCAL DE SALUD DE '
          'VALLEDUPAR (CE',
          ciudad: 'Valledupar',
        ),
        'Secretaría Local de Salud',
      );
    });

    test('gobernación', () {
      expect(
        dep(
          'APOYAR LA GESTIÓN TECNICA DE LOS PROYECTOS DE INVERSIÓN A CARGO DE '
          'LA SECRETARÍA DE EDUCACION DEL DEPARTAMENTO DEL CESAR',
        ),
        'Secretaría de Educacion',
      );
      expect(
        dep(
          'PRESTACIÓN DE SERVICIOS PROFESIONALES PARA APOYAR LA OFICINA DE '
          'ASUNTOS EN SALUD EN LA GESTION DE AUDITORIA',
        ),
        'Oficina de Asuntos en Salud',
      );
      expect(
        dep(
          'APOYAR A LA OFICINA ASESORA JURÍDICA DE LA GOBERNACIÓN DEL CESAR EN',
        ),
        'Oficina Asesora Jurídica',
      );
    });

    test('sin dependencia en el objeto', () {
      expect(
        dep(
          'APOYO AL CUERPO DE AGENTES DE TRÁNSITO Y TRANSPORTE PARA EL '
          'MEJORAMIENTO DE LA MOVILIDAD',
        ),
        isNull,
      );
      expect(
        dep('ACTIVIDADES BAJO LA DIRECCIÓN DEL SUPERVISOR DEL CONTRATO'),
        isNull,
      );
      expect(dep(''), isNull);
    });

    test('toma el objeto del contrato de la fila de SECOP', () {
      expect(
        DependenciaContrato.desde({
          'ciudad': 'Valledupar',
          'objeto_del_contrato':
              'APOYO A LA SECRETARIA DE TALENTO HUMANO DEL MUNICIPIO',
        }),
        'Secretaria de Talento Humano',
      );
      expect(DependenciaContrato.desde({'nombre_entidad': 'X'}), isNull);
    });
  });
}
