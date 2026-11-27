import 'package:flutter_test/flutter_test.dart';

import 'package:app_secop/utils/banderas_control.dart';

void main() {
  group('Ley de Garantías (Ley 996 de 2005, art. 33)', () {
    test('marca la contratación directa firmada en el periodo', () {
      final p = BanderasControl.enLeyDeGarantias({
        'modalidad_de_contratacion': 'Contratación directa',
        'fecha_de_firma': '2026-03-15T10:00:00.000',
      });
      expect(p, isNotNull);
      expect(p!.eleccion, 'presidenciales de 2026');
      expect(
        BanderasControl.enLeyDeGarantias({
          'modalidad_de_contratacion': 'Contratación Directa (con ofertas)',
          'fecha_de_firma': '2022-06-19T23:00:00.000',
        })?.eleccion,
        'presidenciales de 2022',
      );
    });

    test('no marca fuera del periodo ni otras modalidades', () {
      expect(
        BanderasControl.enLeyDeGarantias({
          'modalidad_de_contratacion': 'Contratación directa',
          'fecha_de_firma': '2026-01-30T10:00:00.000',
        }),
        isNull,
      );
      expect(
        BanderasControl.enLeyDeGarantias({
          'modalidad_de_contratacion': 'Contratación directa',
          'fecha_de_firma': '2026-06-22T10:00:00.000',
        }),
        isNull,
      );
      expect(
        BanderasControl.enLeyDeGarantias({
          'modalidad_de_contratacion': 'Mínima cuantía',
          'fecha_de_firma': '2026-03-15T10:00:00.000',
        }),
        isNull,
      );
    });
  });

  group('Contratos de prestación de servicios que se cruzan', () {
    Map<String, dynamic> ps(String id, String desde, String hasta) => {
      'id_contrato': id,
      'tipo_de_contrato': 'Prestación de servicios',
      'fecha_de_inicio_del_contrato': '${desde}T00:00:00.000',
      'fecha_de_fin_del_contrato': '${hasta}T00:00:00.000',
    };

    test('encuentra los que se cruzan al menos 15 días', () {
      final cruces = BanderasControl.cruces([
        ps('A', '2026-02-01', '2026-06-30'),
        ps('B', '2026-04-01', '2026-09-30'),
        ps('C', '2026-06-25', '2026-12-31'),
      ]);
      expect(cruces.length, 2);
      // A y B: 1 abr – 30 jun (91 días); B y C: 25 jun – 30 sep.
      expect(cruces.first.dias, 98);
      expect(
        cruces.map((c) => '${c.a['id_contrato']}${c.b['id_contrato']}'),
        containsAll(['AB', 'BC']),
      );
    });

    test('ignora empalmes cortos, el mismo contrato y otros tipos', () {
      expect(
        BanderasControl.cruces([
          ps('A', '2026-01-01', '2026-06-30'),
          ps('B', '2026-06-25', '2026-12-31'),
          ps('A', '2026-01-01', '2026-06-30'),
          {
            'id_contrato': 'D',
            'tipo_de_contrato': 'Compraventa',
            'fecha_de_inicio_del_contrato': '2026-01-01',
            'fecha_de_fin_del_contrato': '2026-12-31',
          },
        ]),
        isEmpty,
      );
    });
  });

  group('Ley de Garantías frente al inicio del proceso', () {
    // Contrato 0891-SGR de 2022 de la Alcaldía de Valledupar: SECOP II
    // registra la firma electrónica el 2 feb 2022, pero el proceso se
    // publicó y preveía firmarse el 27 ene 2022, antes del periodo.
    final contrato = {
      'modalidad_de_contratacion': 'Contratación directa',
      'fecha_de_firma': '2022-02-02T15:56:37.899',
      'proceso_de_compra': 'CO1.BDOS.2755594',
    };

    test('un proceso que empezó antes del periodo no es alerta', () {
      final e = BanderasControl.evaluarLeyDeGarantias(
        contrato,
        inicio: InicioProceso(
          publicacion: DateTime(2022, 1, 27),
          firmaPrevista: DateTime(2022, 1, 27),
        ),
      )!;
      expect(e.iniciadoAntes, isTrue);
      expect(e.alerta, isFalse);
    });

    test('si todo ocurrió dentro del periodo, sigue siendo alerta', () {
      final e = BanderasControl.evaluarLeyDeGarantias(
        contrato,
        inicio: InicioProceso(
          publicacion: DateTime(2022, 2, 1),
          firmaPrevista: DateTime(2022, 2, 2),
        ),
      )!;
      expect(e.alerta, isTrue);
    });

    test('sin el cronograma se conserva la señal', () {
      expect(BanderasControl.evaluarLeyDeGarantias(contrato)!.alerta, isTrue);
    });

    test('un contrato firmado fuera del periodo no se evalúa', () {
      expect(
        BanderasControl.evaluarLeyDeGarantias({
          ...contrato,
          'fecha_de_firma': '2022-01-27T17:00:00.000',
        }),
        isNull,
      );
    });
  });
}
