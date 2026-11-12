// Sonda manual contra Datos Abiertos (necesita internet):
//   flutter test tool/sondas/busqueda_personas_vivo_test.dart
import 'dart:io';

import 'package:app_secop/services/busqueda_personas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => HttpOverrides.global = null);

  for (final consulta in [
    'fabian cuello',
    'cuello fabian',
    'fabian cuel',
    'muñoz',
    'nunez',
    'sandra erazo',
    '1065842391',
    '800096329',
    'gustavo petro',
  ]) {
    test(consulta, () async {
      final reloj = Stopwatch()..start();
      var primero = -1;
      late ResultadoBusquedaPersonas r;
      await for (final parcial in BusquedaPersonas.buscarProgresivo(consulta)) {
        if (primero < 0 && parcial.personas.isNotEmpty) primero = reloj.elapsedMilliseconds;
        r = parcial;
      }
      // ignore: avoid_print
      print(
        '"$consulta": primeros resultados en $primero ms; ${r.personas.length} en total en ${reloj.elapsedMilliseconds} ms'
        '${r.parcial ? ' (fallaron: ${r.fuentesFallidas})' : ''}',
      );
      for (final p in r.personas.take(8)) {
        // ignore: avoid_print
        print(
          '   ${p.nombre} · ${p.documento} · ${p.contratos} contratos · '
          '${p.fuentes.map((f) => f.name).join('+')}'
          '${p.servidorPublico ? ' · SERVIDOR: ${p.cargoEntidad}' : ''}',
        );
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  }
}
