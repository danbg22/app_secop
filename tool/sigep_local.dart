// Intermediario local del directorio del SIGEP, para desarrollo: hace lo
// mismo que netlify/functions/sigep.mjs (que es el que usa la app publicada).
//
//   dart run tool/sigep_local.dart          (escucha en 127.0.0.1:8787)
//
// La app en modo de desarrollo lo usa sola cuando corre en localhost; con
// VS Code, el botón "Run" lo arranca antes de la app (.vscode/launch.json).
//
// El sitio de Función Pública envía una cadena de certificados incompleta;
// aquí se agregan los dos intermedios públicos de Let's Encrypt (al final de
// este archivo) a las raíces de confianza: la verificación TLS sigue
// completa.
import 'dart:convert';
import 'dart:io';

const _host = 'www.funcionpublica.gov.co';
const _base = '/dafpIndexerBHV/hvSigep';
const _ttl = Duration(hours: 6);

final _cache = <String, (DateTime, String)>{};

Future<void> main(List<String> args) async {
  final puerto = args.isNotEmpty ? int.parse(args.first) : 8787;
  final contexto = SecurityContext(withTrustedRoots: true)
    ..setTrustedCertificatesBytes(utf8.encode(_intermediosLetsEncrypt));
  final cliente = HttpClient(context: contexto)
    ..userAgent = 'ContrataLegal/1.0 (consulta del directorio SIGEP)'
    ..connectionTimeout = const Duration(seconds: 10);

  final HttpServer servidor;
  try {
    servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, puerto);
  } on SocketException {
    // Ya hay uno encendido (por ejemplo, de un "Run" anterior): sirve ese.
    stdout.writeln(
      'Directorio SIGEP ya estaba escuchando en '
      'http://127.0.0.1:$puerto/api/sigep',
    );
    return;
  }
  stdout.writeln(
    'Directorio SIGEP escuchando en http://127.0.0.1:$puerto/api/sigep',
  );

  await for (final peticion in servidor) {
    final respuesta = peticion.response
      ..headers.set('Access-Control-Allow-Origin', '*')
      ..headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    if (peticion.method == 'OPTIONS') {
      respuesta.statusCode = HttpStatus.noContent;
      await respuesta.close();
      continue;
    }
    final ruta = _rutaDestino(peticion.uri);
    if (peticion.method != 'GET' || ruta == null) {
      respuesta.statusCode = HttpStatus.badRequest;
      await respuesta.close();
      continue;
    }
    try {
      final guardada = _cache[ruta];
      var html = guardada != null && guardada.$1.isAfter(DateTime.now())
          ? guardada.$2
          : null;
      if (html == null) {
        final p = await cliente.getUrl(Uri.parse('https://$_host$ruta'));
        final r = await p.close().timeout(const Duration(seconds: 12));
        if (r.statusCode != 200) {
          throw HttpException('El directorio respondió ${r.statusCode}');
        }
        html = _sinContacto(await r.transform(utf8.decoder).join());
        _cache[ruta] = (DateTime.now().add(_ttl), html);
      }
      if (ruta.contains('/detallarHV/') &&
          !html.contains('nombre_funcionario')) {
        respuesta.statusCode = HttpStatus.notFound;
      } else {
        respuesta.headers.contentType = ContentType.html;
        respuesta.write(html);
      }
      stdout.writeln('${respuesta.statusCode} $ruta');
    } catch (e) {
      stdout.writeln('Error con $ruta: $e');
      respuesta.statusCode = HttpStatus.badGateway;
    }
    await respuesta.close();
  }
}

String? _rutaDestino(Uri uri) {
  final hv = (uri.queryParameters['hv'] ?? '').trim();
  if (hv.isNotEmpty) {
    return RegExp(r'^S\d{1,12}-\d{1,8}-\d{1,3}$').hasMatch(hv)
        ? '$_base/detallarHV/$hv'
        : null;
  }
  final consulta = (uri.queryParameters['q'] ?? '')
      .replaceAll(RegExp(r"[^\p{L}\p{N} .'-]", unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (consulta.length < 3 || consulta.length > 100) return null;
  return Uri(
    path: '$_base/index',
    queryParameters: {
      'find': 'FindNext',
      'query': consulta,
      'offset': '0',
      'max': '30',
    },
  ).toString();
}

/// Quita lo que la app no muestra: scripts, el bloque de contacto de la hoja
/// de vida (correo, teléfono, fax, municipio de nacimiento) y la línea de
/// contacto de cada resultado.
String _sinContacto(String html) => html
    .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
    .replaceFirst(RegExp(r'<div id="datosContacto"[\s\S]*?</div>'), '')
    .replaceAll(RegExp(r'<span>[^<]*(?:@|&#64;)[^<]*</span>'), '<span></span>');

/// Let's Encrypt YR1 (http://yr1.i.lencr.org/, vence el 2028-09-02) y Root
/// YR firmado por ISRG Root X1 (http://yr.i.lencr.org/, vence el
/// 2032-09-02): certificados públicos, los mismos de
/// netlify/functions/sigep.mjs.
const _intermediosLetsEncrypt = '''
-----BEGIN CERTIFICATE-----
MIIE2zCCAsOgAwIBAgIRAKICU/FfJpHAXcHOE7m8yk4wDQYJKoZIhvcNAQELBQAw
LjELMAkGA1UEBhMCVVMxDTALBgNVBAoTBElTUkcxEDAOBgNVBAMTB1Jvb3QgWVIw
HhcNMjUwOTAzMDAwMDAwWhcNMjgwOTAyMjM1OTU5WjAzMQswCQYDVQQGEwJVUzEW
MBQGA1UEChMNTGV0J3MgRW5jcnlwdDEMMAoGA1UEAxMDWVIxMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoVi8X2xCYgMXvJxNPKp/oF13UMgmPABB07VC
LNDtoXmt9luEZNJSBV10VyT1Pz6LD8Zq1d2gc43WNl1AdRrj4sEnazbOiz0nPpmG
Bp2hui49oZtDIY6wdKeZAi5BbNU20CH6RSBBMLSQ9cXrH8dxdv4PAJ45ssGML68U
SE3BsjC2a6cAN9L5CgXVIQi5tfNiTPoFZZ3S0OlXqLmmtdV95udWAb5b6e/F49Di
CsH0Y00Ag72BVIb1hzynmKe+X0mERBTtsb3BwmpV9ipeBjMLoR/D9cHxHQCWoi5l
TmXwY015J5rGelz1nZjJuxc2kioaX29XJBnhMkP531rSdG5uMwIDAQABo4HuMIHr
MA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDATASBgNVHRMBAf8E
CDAGAQH/AgEAMB0GA1UdDgQWBBQfLzW+RhSCzUCxrnksVXj699Ro+zAfBgNVHSME
GDAWgBTe51tg0CJtQCh9Pw0B/qS1UrRRlDAyBggrBgEFBQcBAQQmMCQwIgYIKwYB
BQUHMAKGFmh0dHA6Ly95ci5pLmxlbmNyLm9yZy8wEwYDVR0gBAwwCjAIBgZngQwB
AgEwJwYDVR0fBCAwHjAcoBqgGIYWaHR0cDovL3lyLmMubGVuY3Iub3JnLzANBgkq
hkiG9w0BAQsFAAOCAgEA0+zvMq3kHig1ddTmmm+RibTr9/RpX7k4buanMMRqbV/y
IvP82zAHN3mvaw+cASuVsdpd0ikjhr4hnhJQLQOzOp2ccKrsdGOAgo0vddeISFAq
EWEV4lmUM3vFF796up+bSgmJ1u6RupDCMxDgF8M3eLvGuj6L0lu3zkQ0KuQLnKxL
tB0oQqn1Idg5CuuGpMvQzk29Pa3D/qHurc0EIM9SxukQuJqq63lxsYyRQFU8yMBO
hq1w5LbfaWNRrz1uklOfI/pYkAb2E2MTZrAMQkBIE2S8Jt1F8gRc96o/xOsrgvSk
a84AisX6xq1lz1Z7jGvrnXc4TMcjxZTjiTaihcYI1JIXZiLtEMSCa5l3cu8YWd6z
dLRQlqRdclVjuQfNHawRJ6GWlkK0QJosivTKwdBw3KxEtzGo8yMHERbsy57gP1UX
HOMcmZYQC0gtyR3SxfenIM/MxC3Ia2Ypab/kQ/CTnlIn2KQ5JUC6NYrGCbhFN9bp
5lKJStEwCUnLpntcrXk5XVDCNv/5RyWpRThkGOV7GetKkQ0qAY8hCzWK6oqnAhDZ
cjlYVdWfqOw3DIOX6EDNBgAqHarRVxyF9QZdOaXSyPJ0ueD2BYJEBgaCGQ8rAaU/
Qc123V5LTXDZW4CcsPBDyhy4v+c8hClAyw/IkJlfBqxB9D+/wvIMHgECZ4ptP6o=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
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
-----END CERTIFICATE-----
''';
