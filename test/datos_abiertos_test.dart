import 'dart:async';

import 'package:app_secop/services/datos_abiertos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final uri = DatosAbiertos.uri('abcd-1234', {r'$limit': '1'});

  setUp(() {
    DatosAbiertos.restablecerToken();
    DatosAbiertos.limpiarCache();
    DatosAbiertos.esperas = const [Duration.zero, Duration.zero];
    DatosAbiertos.cobertura = const Duration(seconds: 30);
  });
  tearDown(() => DatosAbiertos.clientePruebas = null);

  test('reintenta un 503 y devuelve la respuesta buena', () async {
    var llamadas = 0;
    DatosAbiertos.clientePruebas = MockClient((_) async {
      llamadas++;
      return llamadas < 3
          ? http.Response('', 503)
          : http.Response('[{"a":1}]', 200);
    });
    final r = await DatosAbiertos.obtener(uri);
    expect(r.statusCode, 200);
    expect(llamadas, 3);
  });

  test('un 400 no se reintenta', () async {
    var llamadas = 0;
    DatosAbiertos.clientePruebas = MockClient((_) async {
      llamadas++;
      return http.Response('{"message":"no-such-column"}', 400);
    });
    final r = await DatosAbiertos.obtener(uri);
    expect(r.statusCode, 400);
    expect(llamadas, 1);
    expect(
      () => DatosAbiertos.filas('abcd-1234', {r'$limit': '1'}),
      throwsA(isA<DatosAbiertosException>()),
    );
  });

  test(
    'un error de red se reintenta y, si persiste, lanza excepción',
    () async {
      var llamadas = 0;
      DatosAbiertos.clientePruebas = MockClient((_) async {
        llamadas++;
        throw http.ClientException('XMLHttpRequest error');
      });
      await expectLater(
        DatosAbiertos.obtener(uri),
        throwsA(isA<DatosAbiertosException>()),
      );
      expect(llamadas, 3);
    },
  );

  test('un tiempo agotado no se reintenta', () async {
    var llamadas = 0;
    DatosAbiertos.clientePruebas = MockClient((_) {
      llamadas++;
      return Completer<http.Response>().future;
    });
    await expectLater(
      DatosAbiertos.obtener(uri, timeout: const Duration(milliseconds: 50)),
      throwsA(isA<DatosAbiertosException>()),
    );
    expect(llamadas, 1);
  });

  test('si la primera se cuelga, gana la petición de respaldo', () async {
    DatosAbiertos.cobertura = const Duration(milliseconds: 30);
    var llamadas = 0;
    DatosAbiertos.clientePruebas = MockClient((_) {
      llamadas++;
      return llamadas == 1
          ? Completer<http.Response>().future
          : Future.value(http.Response('[]', 200));
    });
    final r = await DatosAbiertos.obtener(
      uri,
      timeout: const Duration(milliseconds: 300),
    );
    expect(r.statusCode, 200);
    expect(llamadas, 2);
    // La colgada libera su turno al agotar el tiempo.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });

  test('la caché evita repetir la consulta; "fresco" la ignora', () async {
    var llamadas = 0;
    DatosAbiertos.clientePruebas = MockClient((_) async {
      llamadas++;
      return http.Response('[]', 200);
    });
    await DatosAbiertos.obtener(uri, cache: const Duration(minutes: 5));
    await DatosAbiertos.obtener(uri, cache: const Duration(minutes: 5));
    expect(llamadas, 1);
    await DatosAbiertos.obtener(
      uri,
      cache: const Duration(minutes: 5),
      fresco: true,
    );
    expect(llamadas, 2);
  });

  test('una falla nunca queda en caché', () async {
    var llamadas = 0;
    DatosAbiertos.clientePruebas = MockClient((_) async {
      llamadas++;
      return http.Response('', llamadas <= 3 ? 500 : 200);
    });
    final mala = await DatosAbiertos.obtener(
      uri,
      cache: const Duration(minutes: 5),
    );
    expect(mala.statusCode, 500);
    final buena = await DatosAbiertos.obtener(
      uri,
      cache: const Duration(minutes: 5),
    );
    expect(buena.statusCode, 200);
  });

  test('dos pedidos iguales a la vez comparten una sola petición', () async {
    var llamadas = 0;
    DatosAbiertos.clientePruebas = MockClient((_) async {
      llamadas++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response('[]', 200);
    });
    await Future.wait([DatosAbiertos.obtener(uri), DatosAbiertos.obtener(uri)]);
    expect(llamadas, 1);
  });

  test('nunca hay más de cuatro peticiones a la vez', () async {
    var activas = 0;
    var maximo = 0;
    DatosAbiertos.clientePruebas = MockClient((_) async {
      activas++;
      if (activas > maximo) maximo = activas;
      await Future<void>.delayed(const Duration(milliseconds: 15));
      activas--;
      return http.Response('[]', 200);
    });
    await Future.wait([
      for (var i = 0; i < 10; i++)
        DatosAbiertos.obtener(DatosAbiertos.uri('abcd-1234', {'i': '$i'})),
    ]);
    expect(maximo, DatosAbiertos.concurrencia);
  });

  group('unión de alternativas', () {
    test('una consulta por alternativa, sin repetir filas', () async {
      final wheres = <String>[];
      DatosAbiertos.clientePruebas = MockClient((req) async {
        final where = req.url.queryParameters[r'$where']!;
        wheres.add(where);
        return http.Response(
          where.contains("a = '1'")
              ? '[{"id":"1"},{"id":"2"}]'
              : '[{"id":"2"},{"id":"3"}]',
          200,
        );
      });
      final filas = await DatosAbiertos.filasUnion(
        'abcd-1234',
        {r'$limit': '10'},
        whereBase: 'valor > 0',
        alternativas: ["a = '1'", "b = '2'"],
        clave: (f) => '${f['id']}',
      );
      expect(filas.map((f) => f['id']), ['1', '2', '3']);
      expect(
        wheres,
        containsAll(["(valor > 0) AND (a = '1')", "(valor > 0) AND (b = '2')"]),
      );
    });

    test(
      'si una alternativa falla se usan las demás; si fallan todas, error',
      () async {
        DatosAbiertos.clientePruebas = MockClient(
          (req) async => req.url.queryParameters[r'$where']!.contains('mala')
              ? http.Response('', 400)
              : http.Response('[{"id":"1"}]', 200),
        );
        final filas = await DatosAbiertos.filasUnion(
          'abcd-1234',
          {},
          alternativas: ['buena', 'mala'],
        );
        expect(filas, hasLength(1));
        await expectLater(
          DatosAbiertos.filasUnion('abcd-1234', {}, alternativas: ['mala']),
          throwsA(isA<DatosAbiertosException>()),
        );
      },
    );
  });

  test('si la API rechaza el token, se sigue sin él', () async {
    final conToken = <bool>[];
    DatosAbiertos.clientePruebas = MockClient((req) async {
      final lleva = req.url.queryParameters.containsKey(r'$$app_token');
      conToken.add(lleva);
      return lleva
          ? http.Response('{"message":"Invalid app_token specified"}', 403)
          : http.Response('[]', 200);
    });
    final r = await DatosAbiertos.obtener(uri);
    expect(r.statusCode, 200);
    await DatosAbiertos.obtener(DatosAbiertos.uri('abcd-1234', {'otra': '1'}));
    expect(conToken, [true, false, false]);
  });
}
