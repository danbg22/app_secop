import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// La consulta a Datos Abiertos no se pudo completar (después de los
/// reintentos). Distinto de "no hay resultados": quien llama decide si
/// muestra un aviso en vez de una lista vacía.
class DatosAbiertosException implements Exception {
  const DatosAbiertosException(this.mensaje, {this.estado});

  final String mensaje;

  /// Código HTTP, si el servidor alcanzó a responder.
  final int? estado;

  @override
  String toString() => mensaje;
}

/// Cliente único para la API de Datos Abiertos Colombia (Socrata):
///
/// - **Petición de respaldo**: si a los [cobertura] no hay respuesta, lanza
///   la misma consulta otra vez y usa la que llegue primero. Datos Abiertos
///   a veces deja colgada una consulta liviana decenas de segundos; la
///   segunda suele responder en menos de un segundo.
/// - **Reintentos transparentes**: ante un error de red, un 429 o un 5xx
///   repite la consulta hasta dos veces con espera creciente (0,35 s y
///   1 s). Un tiempo agotado no se reintenta: la petición de respaldo ya
///   cubrió el caso de la conexión colgada, y si la consulta es pesada,
///   repetirla solo duplica la espera.
/// - **Caché** opcional con vencimiento (solo respuestas 200), de una hora
///   por defecto: en memoria y, para las respuestas medianas, también en el
///   navegador ([iniciarPersistencia]), así que volver a una sección o
///   recargar la página no vuelve a consultar lo que se consultó hace poco.
/// - **Una sola petición por URL en vuelo**: si dos pantallas piden lo mismo
///   a la vez, comparten la respuesta.
/// - **Token de aplicación** de Contrata Legal en datos.gov.co: sin él, la
///   API frena unos 6 s las peticiones que pasan de 4–5 simultáneas desde
///   la misma conexión. Es público por diseño (viaja en cada consulta del
///   navegador); se puede cambiar con `--dart-define=SOCRATA_APP_TOKEN=…`.
///   Si la API lo rechaza (revocado), se descarta y se sigue sin él.
/// - **Máximo [concurrencia] peticiones a la vez** (8 con token, 4 sin él):
///   esperar turno es más rápido que el frenado.
/// - **Unión en paralelo** ([filasUnion]): en lugar de `A OR B` en el
///   `$where` (que en los conjuntos grandes impide usar los índices y puede
///   tardar más de un minuto), lanza una consulta por alternativa y junta
///   los resultados.
class DatosAbiertos {
  DatosAbiertos._();

  static const String host = 'www.datos.gov.co';

  /// Peticiones simultáneas a Datos Abiertos.
  static int get concurrencia => _usarToken ? 8 : 4;

  static const String _token = String.fromEnvironment(
    'SOCRATA_APP_TOKEN',
    defaultValue: 'W0x73wta4HxyABG3HLrd3okMn',
  );

  /// La API rechazó el token: el resto de la sesión se consulta sin él.
  static bool _tokenRechazado = false;

  static bool get _usarToken => _token.isNotEmpty && !_tokenRechazado;

  @visibleForTesting
  static void restablecerToken() => _tokenRechazado = false;
  static int _activas = 0;
  static final List<Completer<void>> _turnos = [];

  /// Vencimiento por defecto de la caché de consultas. SECOP se actualiza
  /// una vez al día: una hora no deja ver datos viejos y evita volver a
  /// consultar cada vez que se entra a una sección.
  static const Duration ttlPorDefecto = Duration(hours: 1);

  // -------------------------------------------------------------------------
  // Caché guardada en el navegador
  // -------------------------------------------------------------------------

  static SharedPreferences? _prefs;
  static const String _prefijoGuardado = 'datos_abiertos_v1:';

  /// Respuestas más grandes no se guardan (el navegador da unos 5 MB).
  static const int _maxGuardadoPorRespuesta = 300 * 1024;
  static const int _maxGuardadoTotal = 3 * 1024 * 1024;

  /// Activa la caché en el navegador (al abrir la app) y descarta lo
  /// vencido.
  static Future<void> iniciarPersistencia() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _podarGuardadas();
    } catch (_) {
      _prefs = null;
    }
  }

  /// Clave corta de una URL: dos hashes polinómicos de 30 bits (exactos
  /// también en la web, donde los enteros son de 53 bits). Al leer se
  /// confirma además con la URL guardada.
  static String _claveGuardada(String url) {
    var a = 7, b = 11;
    for (final c in utf8.encode(url)) {
      a = (a * 31 + c) & 0x3FFFFFFF;
      b = (b * 131 + c) & 0x3FFFFFFF;
    }
    return '$_prefijoGuardado${a.toRadixString(36)}${b.toRadixString(36)}';
  }

  /// Olvida solo la caché en memoria (como al recargar la página).
  @visibleForTesting
  static void olvidarMemoria() => _cache.clear();

  static http.Response? _leerGuardada(String url) {
    final prefs = _prefs;
    if (prefs == null) return null;
    try {
      final crudo = prefs.getString(_claveGuardada(url));
      if (crudo == null) return null;
      final m = json.decode(crudo) as Map<String, dynamic>;
      final vence = DateTime.fromMillisecondsSinceEpoch(m['v'] as int);
      if (m['u'] != url || DateTime.now().isAfter(vence)) return null;
      final respuesta = http.Response.bytes(
        utf8.encode(m['b'] as String),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
      _cache[url] = _Entrada(respuesta, vence);
      return respuesta;
    } catch (_) {
      return null;
    }
  }

  static void _guardar(String url, http.Response respuesta, DateTime vence) {
    final prefs = _prefs;
    if (prefs == null ||
        respuesta.bodyBytes.length > _maxGuardadoPorRespuesta) {
      return;
    }
    try {
      prefs
          .setString(
            _claveGuardada(url),
            json.encode({
              'u': url,
              'v': vence.millisecondsSinceEpoch,
              'b': utf8.decode(respuesta.bodyBytes),
            }),
          )
          .then((_) => _podarGuardadas())
          .catchError((Object _) {})
          .ignore();
    } catch (_) {}
  }

  /// Quita lo vencido y, si se pasa del tope, lo que vence primero.
  static void _podarGuardadas() {
    final prefs = _prefs;
    if (prefs == null) return;
    final ahora = DateTime.now().millisecondsSinceEpoch;
    final vivas = <(String, int, int)>[];
    for (final clave in prefs.getKeys().toList()) {
      if (!clave.startsWith(_prefijoGuardado)) continue;
      final crudo = prefs.getString(clave);
      var vence = 0;
      try {
        vence =
            (json.decode(crudo ?? '{}') as Map<String, dynamic>)['v'] as int;
      } catch (_) {}
      if (crudo == null || vence <= ahora) {
        prefs.remove(clave).ignore();
      } else {
        vivas.add((clave, vence, crudo.length));
      }
    }
    var total = vivas.fold<int>(0, (s, e) => s + e.$3);
    vivas.sort((a, b) => a.$2.compareTo(b.$2));
    for (final (clave, _, tamano) in vivas) {
      if (total <= _maxGuardadoTotal) break;
      prefs.remove(clave).ignore();
      total -= tamano;
    }
  }

  /// Cliente HTTP para pruebas; en la app se usa el de `package:http`.
  @visibleForTesting
  static http.Client? clientePruebas;

  /// Tiempo sin respuesta tras el cual se lanza la petición de respaldo.
  @visibleForTesting
  static Duration cobertura = const Duration(milliseconds: 2500);

  /// Espera antes de cada reintento (para pruebas se puede acortar).
  @visibleForTesting
  static List<Duration> esperas = const [
    Duration(milliseconds: 350),
    Duration(milliseconds: 1000),
  ];

  static final Map<String, _Entrada> _cache = {};
  static final Map<String, Future<http.Response>> _enVuelo = {};

  static Uri uri(String dataset, Map<String, String> parametros) =>
      Uri.https(host, '/resource/$dataset.json', parametros);

  /// Vacía la caché (por ejemplo, al pulsar "Actualizar datos").
  static void limpiarCache() {
    _cache.clear();
    final prefs = _prefs;
    if (prefs == null) return;
    for (final clave in prefs.getKeys().toList()) {
      if (clave.startsWith(_prefijoGuardado)) prefs.remove(clave).ignore();
    }
  }

  /// GET con reintentos. Con [cache] guarda la respuesta 200 ese tiempo;
  /// con [fresco] ignora lo guardado y vuelve a consultar. [respaldoTras]
  /// cambia cuándo se lanza la petición de respaldo (por defecto
  /// [cobertura]): las consultas pesadas, que tardan varios segundos de por
  /// sí, la esperan más para no duplicarse sin necesidad.
  ///
  /// Devuelve la última respuesta del servidor aunque no sea 200 (como
  /// `http.get`); lanza [DatosAbiertosException] solo si nunca hubo
  /// respuesta (red o tiempo agotado en todos los intentos).
  static Future<http.Response> obtener(
    Uri uri, {
    Duration timeout = const Duration(seconds: 9),
    Duration? cache,
    bool fresco = false,
    Duration? respaldoTras,
  }) {
    final clave = uri.toString();
    if (cache != null && !fresco) {
      final guardada = _cache[clave];
      if (guardada != null && guardada.vigente) {
        return Future.value(guardada.respuesta);
      }
      final enNavegador = _leerGuardada(clave);
      if (enNavegador != null) return Future.value(enNavegador);
    }
    final pendiente = _enVuelo[clave];
    if (pendiente != null) return pendiente;

    final futuro = _conReintentos(uri, timeout, respaldoTras ?? cobertura).then(
      (respuesta) {
        if (cache != null && respuesta.statusCode == 200) {
          final vence = DateTime.now().add(cache);
          _cache[clave] = _Entrada(respuesta, vence);
          _podarCache();
          _guardar(clave, respuesta, vence);
        }
        return respuesta;
      },
    );
    _enVuelo[clave] = futuro;
    futuro.whenComplete(() => _enVuelo.remove(clave)).ignore();
    return futuro;
  }

  /// Filas de un conjunto de datos. Lanza [DatosAbiertosException] si la
  /// consulta falla (estado distinto de 200 o sin respuesta).
  static Future<List<Map<String, dynamic>>> filas(
    String dataset,
    Map<String, String> parametros, {
    Duration timeout = const Duration(seconds: 9),
    Duration? cache = ttlPorDefecto,
    bool fresco = false,
  }) async {
    final respuesta = await obtener(
      uri(dataset, parametros),
      timeout: timeout,
      cache: cache,
      fresco: fresco,
    );
    return decodificar(respuesta);
  }

  /// Igual que [filas] con `$where = base AND (alternativa)`, pero una
  /// consulta por alternativa, todas en paralelo, y resultados unidos sin
  /// repetir (según [clave]; por defecto, la fila completa).
  ///
  /// Si alguna alternativa falla se devuelve lo de las demás; solo si
  /// fallan todas se lanza la excepción.
  static Future<List<Map<String, dynamic>>> filasUnion(
    String dataset,
    Map<String, String> parametros, {
    required List<String> alternativas,
    String? whereBase,
    String Function(Map<String, dynamic> fila)? clave,
    Duration timeout = const Duration(seconds: 9),
    Duration? cache = ttlPorDefecto,
    bool fresco = false,
  }) async {
    final consultas = [
      for (final alternativa in alternativas)
        filas(
          dataset,
          {
            ...parametros,
            r'$where': [
              if (whereBase != null && whereBase.trim().isNotEmpty)
                '($whereBase)',
              '($alternativa)',
            ].join(' AND '),
          },
          timeout: timeout,
          cache: cache,
          fresco: fresco,
        ).then<List<Map<String, dynamic>>?>((f) => f, onError: (_) => null),
    ];
    final resultados = await Future.wait(consultas);
    if (resultados.isNotEmpty && resultados.every((r) => r == null)) {
      throw const DatosAbiertosException(
        'No fue posible consultar Datos Abiertos.',
      );
    }
    final vistas = <String>{};
    final unidas = <Map<String, dynamic>>[];
    for (final lista in resultados) {
      for (final fila in lista ?? const <Map<String, dynamic>>[]) {
        final id = clave?.call(fila) ?? jsonEncode(fila);
        if (vistas.add(id)) unidas.add(fila);
      }
    }
    return unidas;
  }

  /// Decodifica una respuesta de Socrata como lista de filas; lanza
  /// [DatosAbiertosException] si el estado no es 200 o el cuerpo no es
  /// una lista.
  static List<Map<String, dynamic>> decodificar(http.Response respuesta) {
    if (respuesta.statusCode != 200) {
      throw DatosAbiertosException(
        'Datos Abiertos respondió ${respuesta.statusCode}.',
        estado: respuesta.statusCode,
      );
    }
    final cuerpo = json.decode(utf8.decode(respuesta.bodyBytes));
    if (cuerpo is! List) {
      throw const DatosAbiertosException('Respuesta inesperada.');
    }
    return [
      for (final fila in cuerpo)
        if (fila is Map) fila.map((k, v) => MapEntry(k.toString(), v)),
    ];
  }

  static Future<http.Response> _conReintentos(
    Uri uri,
    Duration timeout,
    Duration respaldo,
  ) async {
    Object? ultimoError;
    for (var intento = 0; intento <= esperas.length; intento++) {
      if (intento > 0) await Future<void>.delayed(esperas[intento - 1]);
      try {
        // El tiempo límite cuenta desde que la petición sale, no mientras
        // espera turno.
        final respuesta = await _conRespaldo(uri, timeout, respaldo);
        if (_usarToken && _esTokenRechazado(respuesta)) {
          debugPrint('Datos Abiertos rechazó el token; se sigue sin él.');
          _tokenRechazado = true;
          intento--;
          continue;
        }
        final reintentable =
            respuesta.statusCode == 429 || respuesta.statusCode >= 500;
        if (!reintentable || intento == esperas.length) return respuesta;
        ultimoError = 'estado ${respuesta.statusCode}';
      } on TimeoutException catch (e) {
        ultimoError = e;
        break;
      } catch (e) {
        // Error de red (en la web, `ClientException` de XMLHttpRequest).
        ultimoError = e;
      }
    }
    debugPrint('Datos Abiertos sin respuesta (${uri.path}): $ultimoError');
    throw DatosAbiertosException(
      'No fue posible consultar Datos Abiertos ($ultimoError).',
    );
  }

  /// Una petición; si tarda más de [tras], otra igual en paralelo. Gana la
  /// primera respuesta; solo falla si fallan las dos.
  static Future<http.Response> _conRespaldo(
    Uri uri,
    Duration timeout,
    Duration tras,
  ) {
    final listo = Completer<http.Response>();
    var pendientes = 0;
    void lanzar() {
      pendientes++;
      // El tiempo límite cuenta desde que la petición sale, no mientras
      // espera turno.
      _conTurno(() {
        final cliente = clientePruebas;
        final destino = _conToken(uri);
        return (cliente != null ? cliente.get(destino) : http.get(destino))
            .timeout(timeout);
      }).then(
        (respuesta) {
          if (!listo.isCompleted) listo.complete(respuesta);
        },
        onError: (Object e) {
          if (--pendientes == 0 && !listo.isCompleted) listo.completeError(e);
        },
      );
    }

    lanzar();
    final respaldo = Timer(tras, () {
      if (!listo.isCompleted) lanzar();
    });
    return listo.future.whenComplete(respaldo.cancel);
  }

  /// Ejecuta [peticion] cuando hay turno (máximo [concurrencia] a la vez).
  static Future<T> _conTurno<T>(Future<T> Function() peticion) async {
    if (_activas >= concurrencia) {
      final turno = Completer<void>();
      _turnos.add(turno);
      await turno.future;
    }
    _activas++;
    try {
      return await peticion();
    } finally {
      _activas--;
      if (_turnos.isNotEmpty) _turnos.removeAt(0).complete();
    }
  }

  /// Agrega el token de aplicación de Socrata como parámetro (`$$app_token`
  /// no exige una petición previa de CORS, a diferencia del encabezado).
  static bool _esTokenRechazado(http.Response r) =>
      (r.statusCode == 403 || r.statusCode == 401) &&
      utf8.decode(r.bodyBytes, allowMalformed: true).contains('app_token');

  static Uri _conToken(Uri uri) {
    if (!_usarToken || uri.host != host) return uri;
    return uri.replace(
      queryParameters: {...uri.queryParameters, r'$$app_token': _token},
    );
  }

  static void _podarCache() {
    if (_cache.length <= 400) return;
    _cache.removeWhere((_, e) => !e.vigente);
    while (_cache.length > 400) {
      _cache.remove(_cache.keys.first);
    }
  }
}

class _Entrada {
  _Entrada(this.respuesta, this.vence);

  final http.Response respuesta;
  final DateTime vence;

  bool get vigente => DateTime.now().isBefore(vence);
}
