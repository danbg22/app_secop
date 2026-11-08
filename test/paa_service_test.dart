import 'package:app_secop/services/paa_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee una compra del PAA tal como viene de Datos Abiertos', () {
    final i = ItemPaa.fromMap({
      'id': 'X1',
      'descripcion': '20_9521_451 COMPRA DE MATERIALES DE FORMACION',
      'fecha_esperada_de_inicio': 'Octubre',
      'duracion_esperada': '2',
      'unidad_de_duracion_esperada': 'Mes(es)',
      'valor_total_esperado': '147653461',
      'modalidad': 'MINIMA CUANTIA',
      'categorias_unspsc': '27111910;23242105;23241624',
      'origen_recursos': 'Presupuesto de entidad nacional',
      'procesos_relacionados': 'No Definido',
      'url_proceso': {'url': 'https://community.secop.gov.co/'},
    });
    expect(i.descripcion, 'Compra de materiales de formación');
    expect(i.mes, 10);
    expect(i.duracion, '2 meses');
    expect(i.codigosUnspsc, ['27111910', '23242105', '23241624']);
    expect(i.esCompetitiva, isTrue);
    expect(i.yaTieneProceso, isFalse);
    expect(i.urlProceso, isEmpty);
    expect(
      sectorUnspsc(i.codigosUnspsc.first),
      'Herramientas y maquinaria general',
    );
  });

  test('la contratación directa no es competitiva; con ofertas sí', () {
    ItemPaa con(String m) => ItemPaa.fromMap({'modalidad': m});
    expect(con('CONTRATACION DIRECTA').esCompetitiva, isFalse);
    expect(con('CONTRATACION DIRECTA (CON OFERTAS)').esCompetitiva, isTrue);
    expect(con('LICITACION PUBLICA (OBRA PUBLICA)').esCompetitiva, isTrue);
    expect(con('CONCURSO DE MERITOS ABIERTO').esCompetitiva, isTrue);
    expect(con('No Definido').modalidad, isEmpty);
  });

  test('proceso vinculado y meses', () {
    final i = ItemPaa.fromMap({
      'procesos_relacionados': 'PSP-CSR-CBC-0104-2026',
      'url_proceso': {'url': 'https://community.secop.gov.co/Public/x'},
      'fecha_esperada_de_inicio': 'No Definido',
      'duracion_esperada': '30',
      'unidad_de_duracion_esperada': 'día(s)',
    });
    expect(i.yaTieneProceso, isTrue);
    expect(i.urlProceso, startsWith('https://'));
    expect(i.mes, 0);
    expect(i.duracion, '30 días');
    expect(ItemPaa.mesDe('Setiembre'), 9);
  });
}
