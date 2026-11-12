import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;

import 'package:http/http.dart' as http;

import 'datos_abiertos.dart';

/// Una persona del directorio del SIGEP II (Función Pública).
class PersonaSigep {
  const PersonaSigep({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.entidad,
  });

  /// Identificador de su hoja de vida (p. ej. `S2876680-5794-4`).
  final String id;
  final String nombre;

  /// "Servidor Público" o "Contratista", como lo publica el directorio.
  final String tipo;
  final String entidad;

  bool get esServidorPublico => tipo.toUpperCase().startsWith('SERVIDOR');
}

/// Un cargo de la experiencia laboral.
class CargoSigep {
  const CargoSigep({
    required this.cargo,
    required this.entidad,
    required this.inicio,
    required this.fin,
  });

  final String cargo;
  final String entidad;
  final String inicio;

  /// "Actual" si es el cargo vigente.
  final String fin;
}

/// Hoja de vida pública en el SIGEP. Sin datos de contacto: la app no los
/// muestra (están en la página oficial, que se enlaza).
class HojaDeVidaSigep {
  const HojaDeVidaSigep({
    required this.id,
    required this.nombre,
    required this.cargo,
    required this.entidad,
    required this.dependencia,
    required this.formacion,
    required this.experiencia,
  });

  final String id;
  final String nombre;
  final String cargo;
  final String entidad;
  final String dependencia;
  final List<String> formacion;
  final List<CargoSigep> experiencia;

  Uri get enlace => DirectorioSigepService.enlaceHojaDeVida(id);
}

/// Consulta el directorio de servidores públicos y contratistas del SIGEP
/// II a través del intermediario de Contrata Legal (`netlify/functions/
/// sigep.mjs`).
///
/// El navegador no puede consultar el sitio de Función Pública directamente
/// (no lo permite su política de CORS y su servidor no envía la cadena de
/// certificados completa), y el directorio no tiene una fuente de datos para
/// aplicaciones: el intermediario trae la página y la app la lee aquí. Sin
/// intermediario configurado ([disponible] es falso), la app solo enlaza la
/// búsqueda en el sitio oficial.
class DirectorioSigepService {
  DirectorioSigepService._();

  static const String _configurado = String.fromEnvironment('SIGEP_PROXY');

  /// Hasta cuándo no se vuelve a intentar: para siempre si el sitio no
  /// tiene el intermediario (404); 20 s si el intermediario local de
  /// desarrollo no respondió (puede estar encendiéndose o sin reenviar el
  /// puerto todavía).
  static DateTime? _ausenteHasta;

  /// En desarrollo (localhost), `/api/sigep` lo reenvía el servidor de
  /// Flutter (web_dev_config.yaml) al intermediario local
  /// (`dart run tool/sigep_local.dart`).
  static bool get _desarrolloLocal {
    final host = Uri.base.host;
    return _configurado.isEmpty &&
        kIsWeb &&
        kDebugMode &&
        (host == 'localhost' || host == '127.0.0.1');
  }

  /// Dirección del intermediario: la de `--dart-define=SIGEP_PROXY=…` o, en
  /// la web, `/api/sigep` en el mismo dominio de la app (la función de
  /// Netlify publicada; en desarrollo, el reenvío del servidor de Flutter).
  static String get intermediario {
    if (_configurado.isNotEmpty) return _configurado;
    if (kIsWeb && Uri.base.host.isNotEmpty) {
      return Uri.base.resolve('/api/sigep').toString();
    }
    return '';
  }

  /// Pausa breve tras una falla del intermediario local: la búsqueda debe
  /// tratarse como incompleta (no guardarla) en lugar de "sin resultados".
  static bool get enPausaTemporal =>
      _ausenteHasta != null &&
      _ausenteHasta!.year < 9999 &&
      DateTime.now().isBefore(_ausenteHasta!);

  static bool get disponible =>
      intermediario.isNotEmpty &&
      (_ausenteHasta == null || DateTime.now().isAfter(_ausenteHasta!));

  static final RegExp _idValido = RegExp(r'^S\d{1,12}-\d{1,8}-\d{1,3}$');

  static Uri enlaceHojaDeVida(String id) => Uri.https(
    'www.funcionpublica.gov.co',
    '/dafpIndexerBHV/hvSigep/detallarHV/$id',
  );

  /// Personas cuyo nombre (o entidad, o ciudad) coincide con [consulta].
  /// Lanza [DatosAbiertosException] si el directorio no responde.
  static Future<List<PersonaSigep>> buscar(String consulta) async {
    final limpia = consulta.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!disponible || limpia.length < 3) return const [];
    final http.Response respuesta;
    try {
      respuesta = await DatosAbiertos.obtener(
        Uri.parse(intermediario).replace(queryParameters: {'q': limpia}),
        timeout: const Duration(seconds: 12),
        cache: const Duration(hours: 6),
      );
    } on DatosAbiertosException {
      _pausarSiEsLocal();
      rethrow;
    }
    if (respuesta.statusCode == 404 && !_desarrolloLocal) {
      // Este alojamiento no tiene el intermediario: sin aviso de error.
      _ausenteHasta = DateTime(9999);
      return const [];
    }
    if (respuesta.statusCode != 200) {
      _pausarSiEsLocal();
      throw DatosAbiertosException(
        'El directorio del SIGEP respondió ${respuesta.statusCode}.',
        estado: respuesta.statusCode,
      );
    }
    return leerBusqueda(respuesta.body);
  }

  /// En desarrollo, el intermediario local puede no estar encendido: se
  /// reintenta en 20 s.
  static void _pausarSiEsLocal() {
    if (!_desarrolloLocal) return;
    debugPrint(
      'Directorio del SIGEP: no responde /api/sigep. Enciende el '
      'intermediario local con "dart run tool/sigep_local.dart" (o usa "Run" '
      'en VS Code); se reintenta en 20 s.',
    );
    _ausenteHasta = DateTime.now().add(const Duration(seconds: 20));
  }

  /// Hoja de vida de [id], o null si no existe.
  static Future<HojaDeVidaSigep?> hojaDeVida(String id) async {
    if (!disponible || !_idValido.hasMatch(id)) return null;
    final respuesta = await DatosAbiertos.obtener(
      Uri.parse(intermediario).replace(queryParameters: {'hv': id}),
      timeout: const Duration(seconds: 12),
      cache: const Duration(hours: 6),
    );
    if (respuesta.statusCode == 404) return null;
    if (respuesta.statusCode != 200) {
      throw DatosAbiertosException(
        'El directorio del SIGEP respondió ${respuesta.statusCode}.',
        estado: respuesta.statusCode,
      );
    }
    return leerHojaDeVida(respuesta.body, id);
  }

  // ---------------------------------------------------------------------
  // Lectura del HTML (funciones puras, probadas en
  // test/directorio_sigep_service_test.dart)
  // ---------------------------------------------------------------------

  /// Filas de la tabla de resultados de la búsqueda.
  static List<PersonaSigep> leerBusqueda(String html) {
    final personas = <PersonaSigep>[];
    final vistos = <String>{};
    final filas = RegExp(
      r'<td class="columna-datos">(.*?)</td>',
      dotAll: true,
    ).allMatches(html);
    for (final fila in filas) {
      final celda = fila.group(1)!;
      final enlace = RegExp(
        r'<a href="[^"]*detallarHV/(S[\d-]+)"[^>]*>(.*?)</a>',
        dotAll: true,
      ).firstMatch(celda);
      if (enlace == null) continue;
      final id = enlace.group(1)!;
      if (!_idValido.hasMatch(id) || !vistos.add(id)) continue;
      final nombre = texto(enlace.group(2)!);
      // Tras el nombre vienen, cada una en su <span>: el tipo, la entidad y
      // (en la página original) el contacto, que no se usa.
      final despues = celda.substring(enlace.end);
      final spans = RegExp(
        r'<span>(.*?)</span>',
        dotAll: true,
      ).allMatches(despues).map((m) => texto(m.group(1)!)).toList();
      if (nombre.isEmpty) continue;
      personas.add(
        PersonaSigep(
          id: id,
          nombre: nombre,
          tipo: spans.isNotEmpty ? spans[0] : '',
          entidad: spans.length > 1 ? spans[1] : '',
        ),
      );
    }
    return personas;
  }

  /// Hoja de vida desde la página de detalle.
  static HojaDeVidaSigep? leerHojaDeVida(String html, String id) {
    String parrafo(String clase) {
      final m = RegExp(
        '<p class="$clase">(.*?)</p>',
        dotAll: true,
      ).firstMatch(html);
      return m == null ? '' : texto(m.group(1)!);
    }

    final nombre = parrafo('nombre_funcionario');
    if (nombre.isEmpty) return null;

    String bloque(String idDiv) {
      final inicio = html.indexOf('<div id="$idDiv"');
      if (inicio < 0) return '';
      final siguiente = RegExp(
        r'<div id="(?:formacionAcademica|experienciaLaboral|escalaSalarial)"',
      ).allMatches(html).map((m) => m.start).where((p) => p > inicio);
      return html.substring(
        inicio,
        siguiente.isEmpty ? html.length : siguiente.first,
      );
    }

    final formacion = [
      for (final m in RegExp(
        r'<li[^>]*>(.*?)</li>',
        dotAll: true,
      ).allMatches(bloque('formacionAcademica')))
        texto(m.group(1)!),
    ].where((f) => f.isNotEmpty).toList();

    final experiencia = <CargoSigep>[];
    final cuerpo = RegExp(
      r'<tbody>(.*?)</tbody>',
      dotAll: true,
    ).firstMatch(bloque('experienciaLaboral'));
    if (cuerpo != null) {
      for (final fila in RegExp(
        r'<tr>(.*?)</tr>',
        dotAll: true,
      ).allMatches(cuerpo.group(1)!)) {
        final celdas = [
          for (final c in RegExp(
            r'<td[^>]*>(.*?)</td>',
            dotAll: true,
          ).allMatches(fila.group(1)!))
            texto(c.group(1)!),
        ];
        if (celdas.length < 4) continue;
        experiencia.add(
          CargoSigep(
            cargo: celdas[0],
            entidad: celdas[1],
            inicio: celdas[2],
            fin: celdas[3],
          ),
        );
      }
    }

    return HojaDeVidaSigep(
      id: id,
      nombre: nombre,
      cargo: parrafo('cargo_funcionario'),
      entidad: parrafo('institucion_funcionario'),
      dependencia: parrafo('dependencia_funcionario'),
      formacion: formacion,
      experiencia: experiencia,
    );
  }

  /// Texto de un fragmento HTML: sin etiquetas ni comentarios, entidades
  /// decodificadas y espacios normalizados.
  static String texto(String html) {
    final sinEtiquetas = html
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    return _decodificar(sinEtiquetas)
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' - ', ' · ')
        .trim();
  }

  static String _decodificar(String s) => s
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      )
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&aacute;', 'á')
      .replaceAll('&eacute;', 'é')
      .replaceAll('&iacute;', 'í')
      .replaceAll('&oacute;', 'ó')
      .replaceAll('&uacute;', 'ú')
      .replaceAll('&ntilde;', 'ñ')
      .replaceAll('&Ntilde;', 'Ñ');
}
