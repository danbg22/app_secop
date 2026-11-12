import 'dart:async';

import '../data/colombia_entities_database.dart';
import 'datos_abiertos.dart';

/// De dónde salió una persona encontrada.
enum FuentePersona { secopII, secopI, servidores }

/// Una persona o empresa encontrada en las fuentes abiertas, ya unida entre
/// fuentes por su documento.
class PersonaEncontrada {
  PersonaEncontrada({
    required this.nombre,
    required this.documento,
    required this.tipoDocumento,
    this.contratos = 0,
    this.valor = 0,
    this.ultimaFecha = '',
    this.entidades = 0,
    Set<FuentePersona>? fuentes,
    this.servidorPublico = false,
    this.cargoEntidad,
  }) : fuentes = fuentes ?? {};

  String nombre;

  /// Solo dígitos.
  String documento;
  String tipoDocumento;
  int contratos;
  double valor;

  /// Fecha ISO de la última firma (vacía si no tiene contratos).
  String ultimaFecha;
  int entidades;
  final Set<FuentePersona> fuentes;

  /// Figura como servidor público en Datos Abiertos (no como contratista).
  bool servidorPublico;

  /// "Cargo · Entidad" del registro de servidor público.
  String? cargoEntidad;
}

/// Resultado de una búsqueda: las personas y si alguna fuente no respondió.
class ResultadoBusquedaPersonas {
  const ResultadoBusquedaPersonas(
    this.personas, {
    this.fuentesFallidas = const {},
    this.completo = false,
  });

  final List<PersonaEncontrada> personas;
  final Set<FuentePersona> fuentesFallidas;

  /// Ya respondieron (o fallaron) todas las fuentes.
  final bool completo;

  /// Ninguna fuente de contratos respondió: no es un "sin resultados".
  bool get fallo =>
      fuentesFallidas.contains(FuentePersona.secopII) &&
      fuentesFallidas.contains(FuentePersona.secopI);

  bool get parcial => fuentesFallidas.isNotEmpty;
}

/// Búsqueda de contratistas y servidores públicos por nombre, cédula o NIT
/// en SECOP II, SECOP I y las fuentes abiertas de servidores públicos.
///
/// Por nombre, cada palabra debe aparecer en el nombre, en cualquier orden
/// y posición ("fabian cuello" encuentra "FREDY FABIAN CUELLO ROJAS"), sin
/// importar tildes ni eñes. Para que sea rápido se combina el índice de
/// texto completo de Socrata (`$q`, que ya ignora tildes) con un filtro por
/// la columna del nombre; el resultado se verifica otra vez aquí con el
/// nombre normalizado.
class BusquedaPersonas {
  BusquedaPersonas._();

  static const String _secopII = 'jbjy-vk9h';
  static const String _secopI = 'f789-7hwg';
  static const String _declaraciones = '8tz7-h3eu';
  static const String _pep = '3qxn-uc22';

  static const Duration _ttl = Duration(minutes: 12);
  static const Duration _timeout = Duration(seconds: 8);

  // ---------------------------------------------------------------------
  // Normalización y SoQL (funciones puras, probadas en
  // test/busqueda_personas_test.dart)
  // ---------------------------------------------------------------------

  /// Mayúsculas sin tildes; la Ñ pasa a N para comparar sin importar si la
  /// fuente o quien busca la escribió.
  static String normalizar(String texto) {
    const mapa = {
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'Ñ': 'N',
    };
    final mayus = texto.toUpperCase();
    final b = StringBuffer();
    for (final ch in mayus.split('')) {
      b.write(mapa[ch] ?? ch);
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Palabras de la búsqueda, normalizadas y sin signos (solo A–Z y 0–9),
  /// sin repetir y como máximo seis.
  static List<String> tokens(String consulta) {
    final vistos = <String>{};
    return normalizar(consulta)
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .split(' ')
        .where((t) => t.isNotEmpty && vistos.add(t))
        .take(6)
        .toList();
  }

  /// La búsqueda es por documento (solo dígitos, puntos, guiones, espacios).
  static bool esDocumento(String consulta) =>
      RegExp(r'^[0-9.\-\s]+$').hasMatch(consulta.trim()) &&
      consulta.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty;

  /// Patrón LIKE que tolera tildes y eñes: cada vocal y cada N se vuelve el
  /// comodín de un carácter (`_`). "FABIAN" → "F_B___".
  static String patronTolerante(String token) =>
      token.replaceAll(RegExp('[AEIOUN]'), '_');

  /// `upper(col) LIKE '%T1%' AND upper(col) LIKE '%T2%' …` con patrones
  /// tolerantes. Los tokens ya vienen limpios de [tokens].
  static String whereTodasLasPalabras(String columna, List<String> tokens) =>
      tokens
          .map((t) => "upper($columna) LIKE '%${patronTolerante(t)}%'")
          .join(' AND ');

  /// Texto para `$q`: solo las palabras de tres o más letras (el índice de
  /// texto completo descarta las muy cortas).
  static String textoCompleto(List<String> tokens) =>
      tokens.where((t) => t.length >= 3).join(' ');

  /// Todas las palabras aparecen en el nombre (normalizado).
  static bool nombreCoincide(String nombre, List<String> tokens) {
    final n = normalizar(nombre);
    return tokens.every(n.contains);
  }

  /// Clave para unir una persona entre fuentes: el documento (el NIT sin
  /// dígito de verificación) o, si no hay, el nombre normalizado.
  static String claveUnion(String documento, String nombre) {
    final d = documento.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 10 && (d.startsWith('8') || d.startsWith('9'))) {
      return d.substring(0, 9);
    }
    if (d.length >= 5) return d;
    return 'N:${normalizar(nombre)}';
  }

  // ---------------------------------------------------------------------
  // Búsqueda
  // ---------------------------------------------------------------------

  /// Busca [consulta] (un nombre, una cédula o un NIT) en todas las
  /// fuentes a la vez y espera a que respondan todas.
  static Future<ResultadoBusquedaPersonas> buscar(
    String consulta, {
    bool fresco = false,
  }) => buscarProgresivo(consulta, fresco: fresco).last;

  /// Como [buscar], pero entrega un resultado cada vez que responde una
  /// fuente (SECOP II, SECOP I, servidores públicos), ya unido con lo
  /// anterior. El último evento tiene [ResultadoBusquedaPersonas.completo].
  ///
  /// Nunca deja una fuente fallida como "sin resultados": la reporta en
  /// [ResultadoBusquedaPersonas.fuentesFallidas].
  static Stream<ResultadoBusquedaPersonas> buscarProgresivo(
    String consulta, {
    bool fresco = false,
  }) async* {
    final limpia = consulta.replaceAll(RegExp(r"['%;\\]"), ' ').trim();
    final documento = esDocumento(limpia);
    final palabras = documento ? const <String>[] : tokens(limpia);
    if (limpia.isEmpty || (!documento && palabras.isEmpty)) {
      yield const ResultadoBusquedaPersonas([], completo: true);
      return;
    }
    final digitos = limpia.replaceAll(RegExp(r'[^0-9]'), '');
    // Siglas de entidades que también contratan ("UIS" → NIT de la
    // Universidad Industrial de Santander).
    final nitsSigla = documento
        ? const <String>[]
        : ColombiaEntitiesDatabase.nitsPorSigla(limpia)
              .where((n) => n.length >= 8)
              .toSet()
              .toList();
    final fuentes = <FuentePersona, Future<List<Map<String, dynamic>>>>{
      FuentePersona.secopII: documento
          ? _secopIIPorDocumento(digitos, fresco)
          : _secopIIPorNombre(palabras, fresco, nitsSigla),
      FuentePersona.secopI: documento
          ? _secopIPorDocumento(digitos, fresco)
          : _secopIPorNombre(palabras, fresco),
      FuentePersona.servidores: documento
          ? _servidoresPorDocumento(digitos, fresco)
          : _servidoresPorNombre(palabras, fresco),
    };

    final datos = <FuentePersona, List<Map<String, dynamic>>>{};
    final fallidas = <FuentePersona>{};
    final avisos = StreamController<FuentePersona>();
    for (final MapEntry(key: fuente, value: consultaFuente)
        in fuentes.entries) {
      consultaFuente.then<void>(
        (filas) {
          datos[fuente] = filas;
          avisos.add(fuente);
        },
        onError: (Object _) {
          fallidas.add(fuente);
          avisos.add(fuente);
        },
      );
    }
    var respondidas = 0;
    await for (final _ in avisos.stream) {
      respondidas++;
      final completo = respondidas == fuentes.length;
      yield ResultadoBusquedaPersonas(
        unir(datos, palabras, documentosSigla: nitsSigla),
        fuentesFallidas: {...fallidas},
        completo: completo,
      );
      if (completo) break;
    }
    await avisos.close();
  }

  /// Une las filas de las fuentes en personas (por documento), suma
  /// contratos y valor, y marca a los servidores públicos.
  ///
  /// Con [palabras], solo quedan los nombres que las contienen todas, salvo
  /// los documentos de [documentosSigla].
  static List<PersonaEncontrada> unir(
    Map<FuentePersona, List<Map<String, dynamic>>> datos,
    List<String> palabras, {
    List<String> documentosSigla = const [],
  }) {
    final siglas = {for (final n in documentosSigla) claveUnion(n, '')};
    final porClave = <String, PersonaEncontrada>{};
    void sumar({
      required String nombre,
      required String documento,
      required String tipo,
      required FuentePersona fuente,
      int contratos = 0,
      double valor = 0,
      String fecha = '',
      int entidades = 0,
    }) {
      if (nombre.trim().isEmpty || normalizar(nombre) == 'NO DEFINIDO') {
        return;
      }
      if (palabras.isNotEmpty &&
          !nombreCoincide(nombre, palabras) &&
          !siglas.contains(claveUnion(documento, ''))) {
        return;
      }
      final doc = documento.replaceAll(RegExp(r'[^0-9]'), '');
      final p = porClave.putIfAbsent(
        claveUnion(doc, nombre),
        () => PersonaEncontrada(
          nombre: nombre.trim(),
          documento: doc,
          tipoDocumento: tipo,
        ),
      );
      p.fuentes.add(fuente);
      p.contratos += contratos;
      p.valor += valor;
      if (fecha.compareTo(p.ultimaFecha) > 0) p.ultimaFecha = fecha;
      if (entidades > p.entidades) p.entidades = entidades;
      if (p.documento.isEmpty) p.documento = doc;
      if (p.tipoDocumento.isEmpty) p.tipoDocumento = tipo;
    }

    int entero(Object? v) => int.tryParse('${v ?? 0}') ?? 0;
    double decimal(Object? v) => double.tryParse('${v ?? 0}') ?? 0;

    for (final f
        in datos[FuentePersona.secopII] ?? const <Map<String, dynamic>>[]) {
      sumar(
        nombre: '${f['proveedor_adjudicado'] ?? ''}',
        documento: '${f['documento_proveedor'] ?? ''}',
        tipo: '${f['tipodocproveedor'] ?? ''}',
        fuente: FuentePersona.secopII,
        contratos: entero(f['contratos']),
        valor: decimal(f['total_valor']),
        fecha: '${f['ultima_fecha'] ?? ''}',
        entidades: entero(f['entidades']),
      );
    }
    for (final f
        in datos[FuentePersona.secopI] ?? const <Map<String, dynamic>>[]) {
      sumar(
        nombre: '${f['nom_razon_social_contratista'] ?? ''}',
        documento: '${f['identificacion_del_contratista'] ?? ''}',
        tipo: '${f['tipo_identifi_del_contratista'] ?? ''}',
        fuente: FuentePersona.secopI,
        contratos: entero(f['contratos']),
        valor: decimal(f['total_valor']),
        fecha: '${f['ultima_fecha'] ?? ''}',
        entidades: entero(f['entidades']),
      );
    }
    for (final f
        in datos[FuentePersona.servidores] ?? const <Map<String, dynamic>>[]) {
      final nombre = nombreServidor(f);
      final doc = '${f['numero_documento'] ?? ''}';
      sumar(
        nombre: nombre,
        documento: doc,
        tipo: 'Cédula de Ciudadanía',
        fuente: FuentePersona.servidores,
      );
      final p =
          porClave[claveUnion(doc.replaceAll(RegExp(r'[^0-9]'), ''), nombre)];
      if (p == null) continue;
      p.servidorPublico = true;
      p.cargoEntidad ??= cargoEntidad(f);
    }

    final personas = porClave.values.toList()
      ..sort((a, b) {
        // Primero quien empieza por lo buscado, luego por valor contratado.
        if (palabras.isNotEmpty) {
          final pa = normalizar(a.nombre).startsWith(palabras.first) ? 0 : 1;
          final pb = normalizar(b.nombre).startsWith(palabras.first) ? 0 : 1;
          if (pa != pb) return pa.compareTo(pb);
        }
        final porValor = b.valor.compareTo(a.valor);
        return porValor != 0 ? porValor : a.nombre.compareTo(b.nombre);
      });
    return personas;
  }

  /// Nombre completo de un registro de servidor público (declaraciones o
  /// personas expuestas políticamente).
  static String nombreServidor(Map<String, dynamic> f) {
    final pep = '${f['nombre_pep'] ?? ''}'.trim();
    if (pep.isNotEmpty) return pep;
    return [
          'primer_nombre_declarante',
          'segundo_nombre_declarante',
          'primer_apellido_declarante',
          'segundo_apellido_declarante',
        ]
        .map((k) => '${f[k] ?? ''}'.trim())
        .where((p) => p.isNotEmpty && p.toUpperCase() != 'NULL')
        .join(' ');
  }

  /// "Cargo · Entidad" de un registro de servidor público.
  static String? cargoEntidad(Map<String, dynamic> f) {
    final cargo = '${f['denominacion_cargo'] ?? f['cargo_declarante'] ?? ''}'
        .trim();
    final entidad = '${f['nombre_entidad'] ?? ''}'.trim();
    final partes = [
      if (cargo.isNotEmpty && cargo.toUpperCase() != 'NO APLICA') cargo,
      if (entidad.isNotEmpty) entidad,
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  // --- SECOP II -----------------------------------------------------------

  static const String _aggSecopII =
      'proveedor_adjudicado,tipodocproveedor,documento_proveedor,'
      'count(*) as contratos,sum(valor_del_contrato) as total_valor,'
      'max(fecha_de_firma) as ultima_fecha,'
      'count(distinct nombre_entidad) as entidades';
  static const String _grupoSecopII =
      'proveedor_adjudicado,tipodocproveedor,documento_proveedor';

  static Future<List<Map<String, dynamic>>> _secopIIPorNombre(
    List<String> palabras,
    bool fresco, [
    List<String> nitsSigla = const [],
  ]) async {
    final q = textoCompleto(palabras);
    final unido = palabras.join(' ');
    final r = await Future.wait([
      // Prefijo por el índice del nombre: responde mientras se escribe
      // aunque las palabras sean muy cortas para el texto completo.
      _opcional(
        DatosAbiertos.filas(
          _secopII,
          {
            r'$select': _aggSecopII,
            r'$where':
                "starts_with(proveedor_adjudicado, '$unido') OR "
                "starts_with(proveedor_adjudicado, '${_titulo(unido)}')",
            r'$group': _grupoSecopII,
            r'$limit': '200',
          },
          timeout: _timeout,
          cache: _ttl,
          fresco: fresco,
        ),
      ),
      if (nitsSigla.isNotEmpty)
        _opcional(
          DatosAbiertos.filas(
            _secopII,
            {
              r'$select': _aggSecopII,
              r'$where':
                  'documento_proveedor in (${nitsSigla.map((n) => "'$n'").join(', ')})',
              r'$group': _grupoSecopII,
              r'$limit': '50',
            },
            timeout: _timeout,
            cache: _ttl,
            fresco: fresco,
          ),
        ),
      // Cada palabra en cualquier posición, con el índice de texto completo.
      if (q.isNotEmpty)
        _opcional(
          DatosAbiertos.filas(
            _secopII,
            {
              r'$q': q,
              r'$select': _aggSecopII,
              r'$where': whereTodasLasPalabras(
                'proveedor_adjudicado',
                palabras,
              ),
              r'$group': _grupoSecopII,
              r'$limit': '300',
            },
            timeout: _timeout,
            cache: _ttl,
            fresco: fresco,
          ),
        ),
    ]);
    if (r.every((l) => l == null)) {
      throw const DatosAbiertosException('SECOP II no respondió.');
    }
    return [for (final l in r.reversed) ...?l];
  }

  /// Una consulta que puede fallar sin tumbar a las demás (null si falla).
  static Future<List<Map<String, dynamic>>?> _opcional(
    Future<List<Map<String, dynamic>>> consulta,
  ) => consulta.then<List<Map<String, dynamic>>?>(
    (f) => f,
    onError: (Object _) => null,
  );

  static Future<List<Map<String, dynamic>>> _secopIIPorDocumento(
    String digitos,
    bool fresco,
  ) {
    final alternativas = <String>[
      "starts_with(documento_proveedor, '$digitos')",
    ];
    if (digitos.length == 10 &&
        (digitos.startsWith('8') || digitos.startsWith('9'))) {
      alternativas.add("documento_proveedor = '${digitos.substring(0, 9)}'");
    }
    return DatosAbiertos.filasUnion(
      _secopII,
      {r'$select': _aggSecopII, r'$group': _grupoSecopII, r'$limit': '200'},
      alternativas: alternativas,
      clave: (f) => '${f['proveedor_adjudicado']}|${f['documento_proveedor']}',
      timeout: _timeout,
      cache: _ttl,
      fresco: fresco,
    );
  }

  // --- SECOP I ------------------------------------------------------------

  static const String _aggSecopI =
      'nom_razon_social_contratista,tipo_identifi_del_contratista,'
      'identificacion_del_contratista,count(*) as contratos,'
      'sum(cuantia_contrato) as total_valor,'
      'max(fecha_de_firma_del_contrato) as ultima_fecha,'
      'count(distinct nombre_entidad) as entidades';
  static const String _grupoSecopI =
      'nom_razon_social_contratista,tipo_identifi_del_contratista,'
      'identificacion_del_contratista';

  static Future<List<Map<String, dynamic>>> _secopIPorNombre(
    List<String> palabras,
    bool fresco,
  ) async {
    final q = textoCompleto(palabras);
    if (q.isEmpty) return const [];
    return DatosAbiertos.filas(
      _secopI,
      {
        r'$q': q,
        r'$select': _aggSecopI,
        r'$where': whereTodasLasPalabras(
          'nom_razon_social_contratista',
          palabras,
        ),
        r'$group': _grupoSecopI,
        r'$limit': '200',
      },
      timeout: _timeout,
      cache: _ttl,
      fresco: fresco,
    );
  }

  static Future<List<Map<String, dynamic>>> _secopIPorDocumento(
    String digitos,
    bool fresco,
  ) async {
    if (digitos.length < 4) return const [];
    return DatosAbiertos.filas(
      _secopI,
      {
        r'$select': _aggSecopI,
        r'$where': "starts_with(identificacion_del_contratista, '$digitos')",
        r'$group': _grupoSecopI,
        r'$limit': '200',
      },
      timeout: _timeout,
      cache: _ttl,
      fresco: fresco,
    );
  }

  // --- Servidores públicos ------------------------------------------------

  /// Columnas de las declaraciones de bienes y rentas (Ley 2013 de 2019).
  /// Ojo: la gran mayoría de quienes declaran son contratistas
  /// (`declarante_es_contratista = 'SI'`); solo los demás son servidores.
  static const String _camposDeclaraciones =
      'numero_documento,primer_nombre_declarante,segundo_nombre_declarante,'
      'primer_apellido_declarante,segundo_apellido_declarante,'
      'nombre_entidad,cargo_declarante,fecha_publicac_declarac';

  static Future<List<Map<String, dynamic>>> _servidoresPorNombre(
    List<String> palabras,
    bool fresco,
  ) async {
    final q = textoCompleto(palabras);
    if (q.isEmpty) return const [];
    final r = await Future.wait([
      DatosAbiertos.filas(
        _declaraciones,
        {
          r'$q': q,
          r'$select': _camposDeclaraciones,
          r'$where': "declarante_es_contratista = 'NO'",
          r'$limit': '200',
        },
        timeout: _timeout,
        cache: _ttl,
        fresco: fresco,
      ),
      DatosAbiertos.filas(
        _pep,
        {
          r'$q': q,
          r'$select':
              'numero_documento,nombre_pep,denominacion_cargo,nombre_entidad',
          r'$where': whereTodasLasPalabras('nombre_pep', palabras),
          r'$limit': '100',
        },
        timeout: _timeout,
        cache: _ttl,
        fresco: fresco,
      ),
    ]);
    // El registro más reciente de cada persona primero (PEP antes que las
    // declaraciones: trae el cargo actual).
    return [...r[1], ...r[0]];
  }

  static Future<List<Map<String, dynamic>>> _servidoresPorDocumento(
    String digitos,
    bool fresco,
  ) async {
    if (digitos.length < 5) return const [];
    final r = await Future.wait([
      DatosAbiertos.filas(
        _declaraciones,
        {
          r'$select': _camposDeclaraciones,
          r'$where':
              "numero_documento = '$digitos' AND declarante_es_contratista = 'NO'",
          r'$order': 'fecha_publicac_declarac DESC',
          r'$limit': '5',
        },
        timeout: _timeout,
        cache: _ttl,
        fresco: fresco,
      ),
      DatosAbiertos.filas(
        _pep,
        {
          r'$select':
              'numero_documento,nombre_pep,denominacion_cargo,nombre_entidad',
          'numero_documento': digitos,
          r'$limit': '5',
        },
        timeout: _timeout,
        cache: _ttl,
        fresco: fresco,
      ),
    ]);
    return [...r[1], ...r[0]];
  }

  static String _titulo(String texto) => texto
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w.length == 1 ? w : '${w[0]}${w.substring(1).toLowerCase()}')
      .join(' ');
}
