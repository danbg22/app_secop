import 'package:app_secop/services/paa_service.dart';
import 'package:app_secop/services/verificacion_paa_service.dart';
import 'package:app_secop/utils/texto_profesional.dart';
import 'package:flutter_test/flutter_test.dart';

ProcesoSecop proceso(Map<String, dynamic> m) => ProcesoSecop.fromMap({
  'referencia_del_proceso': 'P-1',
  'id_del_portafolio': 'CO1.BDOS.1',
  'modalidad_de_contratacion': 'Mínima cuantía',
  ...m,
});

void main() {
  group('estado real del proceso', () {
    test('adjudicado, cancelado, desierto y estudio de mercado', () {
      expect(
        proceso({'estado_del_procedimiento': 'Seleccionado'}).estado,
        EstadoProceso.adjudicado,
      );
      expect(
        proceso({'estado_resumen': 'Adjudicado'}).estado,
        EstadoProceso.adjudicado,
      );
      expect(
        proceso({'estado_del_procedimiento': 'Cancelado'}).estado,
        EstadoProceso.cancelado,
      );
      expect(
        proceso({'estado_resumen': 'Desierto'}).estado,
        EstadoProceso.desierto,
      );
      expect(
        proceso({
          'modalidad_de_contratacion':
              'Solicitud de información a los Proveedores',
          'estado_del_procedimiento': 'Publicado',
        }).estado,
        EstadoProceso.estudioMercado,
      );
    });

    test('abierto solo si su día de cierre no ha pasado', () {
      final manana = DateTime.now().add(const Duration(days: 1));
      final ayer = DateTime.now().subtract(const Duration(days: 1));
      Map<String, dynamic> abierto(DateTime cierre) => {
        'estado_del_procedimiento': 'Publicado',
        'estado_de_apertura_del_proceso': 'Abierto',
        'fecha_de_recepcion_de': cierre.toIso8601String(),
      };
      expect(proceso(abierto(manana)).estado, EstadoProceso.abierto);
      expect(proceso(abierto(ayer)).estado, EstadoProceso.enCurso);
    });

    test('la contratación directa sin ofertas no es competitiva', () {
      expect(
        proceso({'modalidad_de_contratacion': 'Contratación directa'})
            .esCompetitivo,
        isFalse,
      );
      expect(
        proceso({
          'modalidad_de_contratacion': 'Contratación directa (con ofertas)',
        }).esCompetitivo,
        isTrue,
      );
    });
  });

  test('cruce: por referencia vinculada y por objeto y valor', () {
    final items = [
      ItemPaa.fromMap({
        'id': 'A',
        'descripcion': 'MANTENIMIENTO DE AIRES ACONDICIONADOS DEL DESPACHO',
        'modalidad': 'MINIMA CUANTIA',
        'valor_total_esperado': '100000000',
        'procesos_relacionados': 'MC-001-2026',
      }),
      ItemPaa.fromMap({
        'id': 'B',
        'descripcion':
            'ADQUISICION DE DOTACION Y ROPA DE TRABAJO PARA LOS APRENDICES',
        'modalidad': 'MINIMA CUANTIA',
        'valor_total_esperado': '147000000',
        'procesos_relacionados': 'No Definido',
      }),
      ItemPaa.fromMap({
        'id': 'C',
        'descripcion': 'COMPRA DE PAPELERIA PARA EL ARCHIVO',
        'modalidad': 'MINIMA CUANTIA',
        'valor_total_esperado': '20000000',
        'procesos_relacionados': 'No Definido',
      }),
    ];
    final procesos = [
      proceso({
        'referencia_del_proceso': 'MC-001-2026',
        'nombre_del_procedimiento': 'Aires',
        'estado_del_procedimiento': 'Seleccionado',
      }),
      proceso({
        'referencia_del_proceso': 'MC-050-2026',
        'nombre_del_procedimiento': 'Dotación ropa de trabajo aprendices',
        'descripci_n_del_procedimiento':
            'Adquisición de dotación y ropa de trabajo para los aprendices',
        'precio_base': '145000000',
        'estado_del_procedimiento': 'Evaluación',
      }),
      proceso({
        'referencia_del_proceso': 'MC-060-2026',
        'nombre_del_procedimiento': 'Combustibles',
        'descripci_n_del_procedimiento':
            'Suministro de combustibles para vehículos',
      }),
    ];
    final r = VerificacionPaaService.cruzar(items, procesos);
    expect(r['A']?.vinculo, Vinculo.porEntidad);
    expect(r['A']?.proceso.estado, EstadoProceso.adjudicado);
    expect(r['B']?.vinculo, Vinculo.porCoincidencia);
    expect(r['B']?.proceso.referencia, 'MC-050-2026');
    // Nada parecido: queda sin proceso (no se inventa un cruce).
    expect(r['C'], isNull);
  });

  test('evento de calendario de día completo con aviso', () {
    final p = proceso({
      'nombre_del_procedimiento': 'Juegos zonales',
      'fecha_de_recepcion_de': '2026-11-20T00:00:00.000',
    });
    final ics = VerificacionPaaService.eventoCalendario(p, 'SENA');
    expect(ics, contains('DTSTART;VALUE=DATE:20261120'));
    expect(ics, contains('DTEND;VALUE=DATE:20261121'));
    expect(ics, contains('TRIGGER:-P1D'));
    expect(ics, contains('SUMMARY:Cierre de ofertas: Juegos zonales'));
  });

  test('textos profesionales', () {
    expect(
      TextoProfesional.oracion(
        '20_231 ADQUISICION DE DOTACION Y ROPA DE TRABAJO PARA LOS APRENDICES DEL SENA',
      ),
      'Adquisición de dotación y ropa de trabajo para los aprendices del SENA',
    );
    expect(
      TextoProfesional.titulo(
        'MINISTERIO DEL TRABAJO DIRECCION TERRITORIAL HUILA',
      ),
      'Ministerio del Trabajo Dirección Territorial Huila',
    );
    expect(
      TextoProfesional.titulo('MINTRABAJO NIVEL CENTRAL*/'),
      'MinTrabajo Nivel Central',
    );
    expect(
      TextoProfesional.etiqueta('Seleccion Abreviada Menor Cuantia'),
      'Selección abreviada menor cuantía',
    );
    // Lo que ya viene bien escrito no se toca.
    expect(
      TextoProfesional.oracion('Servicio de mantenimiento de la PTAR'),
      'Servicio de mantenimiento de la PTAR',
    );
  });
}
