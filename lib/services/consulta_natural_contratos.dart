import '../data/colombia_secop_catalog.dart';

/// Tipo de contratista pedido en la consulta ("empresas", "personas naturales").
enum TipoContratista { empresa, personaNatural }

/// Filtros deducidos de una consulta en lenguaje natural sobre contratos de
/// SECOP II, p. ej. "contratos de alimentación en el Cesar" o "empresas que
/// han contratado mantenimiento vial en 2025 por más de 500 millones".
class InterpretacionConsulta {
  const InterpretacionConsulta({
    required this.original,
    this.temas = const [],
    this.temasEtiqueta = const [],
    this.departamento,
    this.municipio,
    this.patronMunicipio,
    this.patronesEntidad = const [],
    this.entidadEtiqueta,
    this.valorMin,
    this.valorMax,
    this.anioDesde,
    this.anioHasta,
    this.modalidad,
    this.tipoContratista,
    this.fraseNatural = false,
    this.aniosPorDefecto = false,
  });

  /// Sin año en la consulta ni filtro de lugar o entidad se buscan solo las
  /// últimas vigencias: recorrer todo SECOP II con comparaciones de texto
  /// tarda más de lo que el usuario espera.
  final bool aniosPorDefecto;

  final String original;

  /// La consulta trae conectores o palabras de pregunta ("contratos de…",
  /// "que han…"): es una frase y no un nombre o un número sueltos.
  final bool fraseNatural;

  /// Cada tema es una lista de patrones alternativos (OR) sobre el objeto del
  /// contrato; todos los temas deben cumplirse (AND).
  final List<List<String>> temas;
  final List<String> temasEtiqueta;

  /// Valor exacto de la columna `departamento` de SECOP II.
  final String? departamento;
  final String? municipio;
  final String? patronMunicipio;

  /// Patrones que deben aparecer todos en `nombre_entidad`; cada elemento
  /// puede traer alternativas separadas por `|`.
  final List<String> patronesEntidad;
  final String? entidadEtiqueta;
  final double? valorMin;
  final double? valorMax;
  final int? anioDesde;
  final int? anioHasta;

  /// Una de las etiquetas de modalidad que usa la sección de contratos.
  final String? modalidad;
  final TipoContratista? tipoContratista;

  bool get tieneFiltros =>
      departamento != null ||
      municipio != null ||
      patronesEntidad.isNotEmpty ||
      valorMin != null ||
      valorMax != null ||
      (anioDesde != null && !aniosPorDefecto) ||
      modalidad != null ||
      tipoContratista != null;

  bool get tieneAnios => anioDesde != null || anioHasta != null;

  /// Se usa la búsqueda interpretada cuando la consulta trae algún filtro o
  /// es una frase con tema; nombres, NIT o números sueltos siguen por la
  /// búsqueda clásica.
  bool get esConsultaNatural =>
      tieneFiltros || (fraseNatural && temas.isNotEmpty);

  /// Cláusulas SoQL para el dataset de SECOP II (`jbjy-vk9h`). Con
  /// [incluirAniosPorDefecto] en `false` se omite la ventana de años que no
  /// pidió el usuario (p. ej. porque ya eligió una vigencia en los filtros).
  List<String> clausulasSecopII({bool incluirAniosPorDefecto = true}) {
    final conAnios = !aniosPorDefecto || incluirAniosPorDefecto;
    String like(String campo, String patron) =>
        "upper($campo) LIKE '%$patron%'";
    return [
      for (final tema in temas)
        '(${tema.map((p) => like('objeto_del_contrato', p)).join(' OR ')})',
      if (departamento != null)
        "departamento = '${departamento!.replaceAll("'", "''")}'",
      if (patronMunicipio != null) like('ciudad', patronMunicipio!),
      for (final p in patronesEntidad)
        '(${p.split('|').map((alt) => like('nombre_entidad', alt)).join(' OR ')})',
      if (valorMin != null)
        'valor_del_contrato >= ${valorMin!.toStringAsFixed(0)}',
      if (valorMax != null)
        'valor_del_contrato <= ${valorMax!.toStringAsFixed(0)}',
      if (conAnios && anioDesde != null)
        "fecha_de_firma >= '$anioDesde-01-01T00:00:00.000'",
      if (conAnios && anioHasta != null)
        "fecha_de_firma < '${anioHasta! + 1}-01-01T00:00:00.000'",
      if (modalidad != null) _soqlModalidad(modalidad!),
      if (tipoContratista == TipoContratista.empresa) "tipodocproveedor = 'NIT'",
      if (tipoContratista == TipoContratista.personaNatural)
        "tipodocproveedor != 'NIT'",
    ];
  }

  static String _soqlModalidad(String modalidad) => switch (modalidad) {
    'Contratación directa' => "upper(modalidad_de_contratacion) LIKE '%DIRECTA%'",
    'Mínima cuantía' => "upper(modalidad_de_contratacion) LIKE '%M_NIMA%'",
    'Selección abreviada' =>
      "(upper(modalidad_de_contratacion) LIKE '%ABREVIADA%' OR upper(modalidad_de_contratacion) LIKE '%SUBASTA%')",
    'Licitación pública' => "upper(modalidad_de_contratacion) LIKE '%LICITACI%'",
    'Concurso de méritos' => "upper(modalidad_de_contratacion) LIKE '%M_RITOS%'",
    _ => "upper(modalidad_de_contratacion) LIKE '%ESPECIAL%'",
  };

  /// Descripción de cada filtro deducido, para mostrar al usuario qué se
  /// entendió de su pregunta.
  List<String> etiquetas() {
    String millones(double v) {
      final m = v / 1e6;
      if (m >= 1000) {
        final milM = m / 1000;
        return '\$${milM == milM.roundToDouble() ? milM.toStringAsFixed(0) : milM.toStringAsFixed(1)} mil M';
      }
      return '\$${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)} M';
    }

    return [
      if (temasEtiqueta.isNotEmpty) 'Tema: ${temasEtiqueta.join(' + ')}',
      if (municipio != null) 'Municipio: $municipio',
      if (departamento != null) 'Departamento: $departamento',
      if (entidadEtiqueta != null) 'Entidad: $entidadEtiqueta',
      if (valorMin != null && valorMax != null)
        'Valor: ${millones(valorMin!)} – ${millones(valorMax!)}'
      else if (valorMin != null)
        'Valor ≥ ${millones(valorMin!)}'
      else if (valorMax != null)
        'Valor ≤ ${millones(valorMax!)}',
      if (aniosPorDefecto)
        'Años: $anioDesde–$anioHasta (escribe un año para ampliar)'
      else if (anioDesde != null && anioDesde == anioHasta)
        'Año: $anioDesde'
      else if (anioDesde != null && anioHasta != null)
        'Años: $anioDesde–$anioHasta'
      else if (anioDesde != null)
        'Desde $anioDesde'
      else if (anioHasta != null)
        'Hasta $anioHasta',
      if (modalidad != null) 'Modalidad: $modalidad',
      if (tipoContratista == TipoContratista.empresa)
        'Contratistas: empresas (NIT)',
      if (tipoContratista == TipoContratista.personaNatural)
        'Contratistas: personas naturales',
    ];
  }
}

/// Intérprete por reglas (sin IA, sin cuota y sin latencia): reconoce lugares
/// del catálogo, entidades, montos, años, modalidad y tipo de contratista, y
/// convierte el resto de palabras en temas del objeto del contrato.
class ConsultaNaturalContratos {
  ConsultaNaturalContratos._();

  static InterpretacionConsulta interpretar(String texto, {int? anioActual}) {
    final actual = anioActual ?? DateTime.now().year;
    var t = ' ${_normalizar(texto)} ';
    final fraseNatural = t
        .split(' ')
        .any((w) => _vacias.contains(w) && !_nombresPropios.contains(w));

    // --- Años (antes que los montos para no confundir "2025" con dinero) ----
    int? anioDesde;
    int? anioHasta;
    const noMonto = r'(?!\s*(?:MIL|MILLON|MILLONES|BILLON|BILLONES|MM|M)\b)';
    final rangoAnios = RegExp(
      r'\b(?:ENTRE|DE|DESDE)\s+(?:EL\s+)?(20[0-3]\d)\s+(?:Y|A|HASTA)\s+(?:EL\s+)?(20[0-3]\d)\b' +
          noMonto,
    ).firstMatch(t);
    if (rangoAnios != null) {
      final a = int.parse(rangoAnios.group(1)!);
      final b = int.parse(rangoAnios.group(2)!);
      anioDesde = a < b ? a : b;
      anioHasta = a < b ? b : a;
      t = t.replaceFirst(rangoAnios.group(0)!, ' ');
    } else {
      final desde = RegExp(
        r'\b(?:DESDE|A PARTIR DE)\s+(?:EL\s+)?(?:A[NÑ]O\s+)?(20[0-3]\d)\b' + noMonto,
      ).firstMatch(t);
      final hasta = RegExp(
        r'\b(?:HASTA|ANTES DE)\s+(?:EL\s+)?(?:A[NÑ]O\s+)?(20[0-3]\d)\b' + noMonto,
      ).firstMatch(t);
      if (desde != null || hasta != null) {
        if (desde != null) {
          anioDesde = int.parse(desde.group(1)!);
          t = t.replaceFirst(desde.group(0)!, ' ');
        }
        if (hasta != null) {
          anioHasta = int.parse(hasta.group(1)!);
          if (hasta.group(0)!.contains('ANTES')) anioHasta = anioHasta - 1;
          t = t.replaceFirst(hasta.group(0)!, ' ');
        }
      } else {
        final ultimos = RegExp(
          r'\b(?:LOS\s+)?ULTIMOS\s+(\d{1,2})\s+A[NÑ]OS\b',
        ).firstMatch(t);
        final solo = RegExp(
          r'\b(?:EN|DE|DEL|DURANTE|PARA)?\s*(?:EL\s+)?(?:A[NÑ]O\s+|VIGENCIA\s+)?(20[0-3]\d)\b' +
              noMonto,
        ).firstMatch(t);
        if (ultimos != null) {
          anioHasta = actual;
          anioDesde = actual - int.parse(ultimos.group(1)!) + 1;
          t = t.replaceFirst(ultimos.group(0)!, ' ');
        } else if (RegExp(r'\bESTE A[NÑ]O\b').hasMatch(t)) {
          anioDesde = anioHasta = actual;
          t = t.replaceFirst(RegExp(r'\b(?:EN\s+|DE\s+|DEL\s+)?ESTE A[NÑ]O\b'), ' ');
        } else if (RegExp(r'\b(?:EL\s+)?A[NÑ]O PASADO\b').hasMatch(t)) {
          anioDesde = anioHasta = actual - 1;
          t = t.replaceFirst(
            RegExp(r'\b(?:EN\s+|DE\s+|DEL\s+)?(?:EL\s+)?A[NÑ]O PASADO\b'),
            ' ',
          );
        } else if (solo != null) {
          anioDesde = anioHasta = int.parse(solo.group(1)!);
          t = t.replaceFirst(solo.group(0)!, ' ');
        }
      }
    }

    // --- Montos -----------------------------------------------------------
    double? valorMin;
    double? valorMax;
    const numero = r'\$?\s*(\d+(?:[.,]\d+)*)';
    const unidad =
        r'\s*(MIL\s+MILLONES|MILLONES|MILLON|BILLONES|BILLON|MM|MILL|M|MIL|PESOS)?\b';
    final entre = RegExp(
      r'\bENTRE\s+' + numero + unidad + r'\s+Y\s+' + numero + unidad,
    ).firstMatch(t);
    if (entre != null) {
      final unidadComun = entre.group(4) ?? entre.group(2);
      valorMin = _monto(entre.group(1)!, entre.group(2) ?? unidadComun);
      valorMax = _monto(entre.group(3)!, unidadComun);
      t = t.replaceFirst(entre.group(0)!, ' ');
    }
    final minimo = RegExp(
      r'\b(?:SUPERIOR(?:ES)?\s+A|MAYOR(?:ES)?\s+(?:A|DE|QUE)|MAS\s+DE|POR\s+ENCIMA\s+DE|DE\s+MAS\s+DE|MINIMO|AL\s+MENOS|SOBRE)\s+' +
          numero +
          unidad,
    ).firstMatch(t);
    if (minimo != null) {
      valorMin = _monto(minimo.group(1)!, minimo.group(2));
      t = t.replaceFirst(minimo.group(0)!, ' ');
    }
    final maximo = RegExp(
      r'\b(?:INFERIOR(?:ES)?\s+A|MENOR(?:ES)?\s+(?:A|DE|QUE)|MENOS\s+DE|POR\s+DEBAJO\s+DE|DE\s+MENOS\s+DE|MAXIMO|HASTA|BAJO)\s+' +
          numero +
          unidad,
    ).firstMatch(t);
    if (maximo != null) {
      valorMax = _monto(maximo.group(1)!, maximo.group(2));
      t = t.replaceFirst(maximo.group(0)!, ' ');
    }
    t = t.replaceAll(RegExp(r'\b(?:POR\s+)?(?:UN\s+)?(?:VALOR|MONTO|CUANTIA)\b'), ' ');

    // --- Modalidad -------------------------------------------------------------
    String? modalidad;
    const modalidades = <String, String>{
      r'CONTRATACION\s+DIRECTA|\bDIRECTA\b|A\s+DEDO': 'Contratación directa',
      r'MINIMA\s+CUANTIA': 'Mínima cuantía',
      r'SELECCION\s+ABREVIADA|SUBASTA': 'Selección abreviada',
      r'LICITACION(?:ES)?(?:\s+PUBLICAS?)?': 'Licitación pública',
      r'CONCURSO\s+DE\s+MERITOS': 'Concurso de méritos',
      r'REGIMEN\s+ESPECIAL': 'Régimen especial',
    };
    for (final e in modalidades.entries) {
      final m = RegExp('(?:\\bPOR\\s+|\\bEN\\s+|\\bDE\\s+)?(?:${e.key})').firstMatch(t);
      if (m != null) {
        modalidad = e.value;
        t = t.replaceFirst(m.group(0)!, ' ');
        break;
      }
    }

    // --- Tipo de contratista ------------------------------------------------------
    TipoContratista? tipo;
    final personas = RegExp(r'\bPERSONAS?\s+NATURAL(?:ES)?\b').firstMatch(t);
    final empresas = RegExp(
      r'\b(?:EMPRESAS?|COMPA[NÑ]IAS?|FIRMAS?|SOCIEDADES|PERSONAS?\s+JURIDICAS?|PROVEEDORES\s+JURIDICOS)\b',
    ).firstMatch(t);
    if (personas != null) {
      tipo = TipoContratista.personaNatural;
      t = t.replaceFirst(personas.group(0)!, ' ');
    } else if (empresas != null) {
      tipo = TipoContratista.empresa;
      t = t.replaceFirst(empresas.group(0)!, ' ');
    }

    // --- Entidad ---------------------------------------------------------------------
    final patronesEntidad = <String>[];
    String? entidadEtiqueta;
    String? departamento;
    String? municipio;
    String? patronMunicipio;

    final alcaldia = RegExp(
      r'\b(ALCALDIA|GOBERNACION)\s+(?:DE\s+LA\s+|DEL\s+|DE\s+)?(?:EL\s+|LA\s+)?',
    ).firstMatch(t);
    if (alcaldia != null) {
      final resto = t.substring(alcaldia.end);
      final lugar = _buscarLugarAlInicio(resto);
      if (lugar != null) {
        final esGobernacion = alcaldia.group(1) == 'GOBERNACION';
        if (esGobernacion && lugar.departamento != null && lugar.municipio == null) {
          departamento = lugar.departamento;
          patronesEntidad.add('GOBERNACI|DEPARTAMENTO');
          entidadEtiqueta = 'Gobernación de ${lugar.etiqueta}';
        } else if (!esGobernacion) {
          departamento = lugar.departamento;
          municipio = lugar.municipio;
          patronMunicipio = lugar.patronMunicipio;
          patronesEntidad.add('ALCALD|MUNICIPIO|DISTRITO');
          entidadEtiqueta = 'Alcaldía de ${lugar.etiqueta}';
        }
        if (entidadEtiqueta != null) {
          t = '${t.substring(0, alcaldia.start)} ${resto.substring(lugar.largo)}';
        }
      }
    }

    if (patronesEntidad.isEmpty) {
      for (final sigla in _siglasEntidades.entries) {
        final m = RegExp('\\b${sigla.key}\\b').firstMatch(t);
        if (m != null) {
          patronesEntidad.add(sigla.value);
          entidadEtiqueta = sigla.key;
          t = t.replaceFirst(m.group(0)!, ' ');
          break;
        }
      }
    }

    if (patronesEntidad.isEmpty) {
      final tipoEntidad = RegExp(
        r'\b(HOSPITAL|E\s?S\s?E|UNIVERSIDAD|MINISTERIO|INSTITUTO|SECRETARIA|CONCEJO|PERSONERIA|CONTRALORIA|CORPORACION|AGENCIA|SUPERINTENDENCIA|FONDO|EMPRESA\s+DE\s+SERVICIOS)\s+(?:DE\s+LA\s+|DEL\s+|DE\s+)?((?:[A-Z0-9]+\s+){0,3}?[A-Z0-9]+)(?=\s+(?:EN|DE|DEL|CON|PARA|POR|QUE|Y)\b|\s*$)',
      ).firstMatch(t);
      if (tipoEntidad != null) {
        final palabras = tipoEntidad
            .group(2)!
            .split(RegExp(r'\s+'))
            .where((w) => w.length >= 3 && !_vacias.contains(w))
            .toList();
        patronesEntidad.add(_raiz(tipoEntidad.group(1)!.replaceAll(' ', '')));
        patronesEntidad.addAll(palabras.map(_patronTolerante));
        entidadEtiqueta = _titulo(tipoEntidad.group(0)!.trim());
        t = t.replaceFirst(tipoEntidad.group(0)!, ' ');
      }
    }

    // --- Lugar (solo tras "en", "de", "del", "desde", "para") ---------------------------------
    if (departamento == null && municipio == null) {
      final prep = RegExp(
        r'\b(?:EN|DE|DEL|DESDE|PARA)\s+(?:EL\s+|LA\s+|LOS\s+)?(?:DEPARTAMENTO\s+(?:DEL?\s+)?|MUNICIPIO\s+(?:DE\s+)?)?',
      );
      for (final m in prep.allMatches(t)) {
        final lugar = _buscarLugarAlInicio(t.substring(m.end));
        if (lugar != null) {
          departamento = lugar.departamento;
          municipio = lugar.municipio;
          patronMunicipio = lugar.patronMunicipio;
          t = '${t.substring(0, m.start)} ${t.substring(m.end + lugar.largo)}';
          break;
        }
      }
    }

    // --- Temas: el resto de palabras con significado ----------------------------------------------
    final temas = <List<String>>[];
    final temasEtiqueta = <String>[];
    final palabras = t
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !_vacias.contains(w))
        .toList();
    // Para mostrar cada tema como lo escribió el usuario (con sus tildes).
    final escritas = <String, String>{
      for (final w in texto.split(RegExp(r'\s+')))
        _normalizar(w): w.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''),
    };
    final vistos = <String>{};
    for (final w in palabras) {
      final sinonimos = _sinonimos[_raiz(w)] ?? _sinonimosPorPalabra(w);
      final patrones = sinonimos ?? _variantesConTilde(_raiz(w));
      if (!vistos.add(patrones.first)) continue;
      temas.add(patrones);
      temasEtiqueta.add(escritas[w] ?? w.toLowerCase());
      if (temas.length == 5) break;
    }

    // Sin año, lugar ni entidad: últimas 3 vigencias (ver [aniosPorDefecto]).
    final aniosPorDefecto = temas.isNotEmpty &&
        anioDesde == null &&
        anioHasta == null &&
        departamento == null &&
        municipio == null &&
        patronesEntidad.isEmpty;
    if (aniosPorDefecto) {
      anioDesde = actual - 2;
      anioHasta = actual;
    }

    return InterpretacionConsulta(
      original: texto.trim(),
      aniosPorDefecto: aniosPorDefecto,
      temas: temas,
      temasEtiqueta: temasEtiqueta,
      departamento: departamento,
      municipio: municipio,
      patronMunicipio: patronMunicipio,
      patronesEntidad: patronesEntidad,
      entidadEtiqueta: entidadEtiqueta,
      valorMin: valorMin,
      valorMax: valorMax,
      anioDesde: anioDesde,
      anioHasta: anioHasta,
      modalidad: modalidad,
      tipoContratista: tipo,
      fraseNatural: fraseNatural,
    );
  }

  // ===========================================================================
  // Utilidades
  // ===========================================================================

  static String _normalizar(String texto) {
    const tildes = {
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', //
      'á': 'A', 'é': 'E', 'í': 'I', 'ó': 'O', 'ú': 'U', 'ü': 'U',
    };
    final buffer = StringBuffer();
    for (final c in texto.split('')) {
      buffer.write(tildes[c] ?? c);
    }
    return buffer
        .toString()
        .toUpperCase()
        // Solo letras, dígitos y separadores de cifras; nada que rompa SoQL.
        .replaceAll(RegExp(r'[^A-Z0-9Ñ$.,\s]'), ' ')
        .replaceAll(RegExp(r'(?<!\d)[.,]|[.,](?!\d)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static double _monto(String cifra, String? unidad) {
    // "1.500" o "1,500" como miles; "1,5" o "1.5" con unidad como decimal.
    final partes = cifra.split(RegExp('[.,]'));
    final esDecimal = partes.length == 2 && partes.last.length != 3;
    final valor = esDecimal
        ? double.parse('${partes.first}.${partes.last}')
        : double.parse(partes.join());
    final u = (unidad ?? '').replaceAll(RegExp(r'\s+'), ' ');
    final factor = switch (u) {
      'MIL MILLONES' => 1e9,
      'BILLON' || 'BILLONES' => 1e12,
      'MILLON' || 'MILLONES' || 'MM' || 'MILL' || 'M' => 1e6,
      'MIL' => 1e3,
      'PESOS' => 1.0,
      // Sin unidad: cifras pequeñas se entienden en millones ("más de 500").
      _ => valor < 100000 ? 1e6 : 1.0,
    };
    return valor * factor;
  }

  /// Raíz para buscar con LIKE: quita plurales y la terminación de "-ción"
  /// para coincidir con o sin tilde ("ALIMENTACIÓN" → "ALIMENTACI").
  static String _raiz(String palabra) {
    var w = palabra;
    if (w.endsWith('CIONES')) return w.substring(0, w.length - 4);
    if (w.endsWith('CION')) return w.substring(0, w.length - 2);
    if (w.endsWith('SIONES')) return w.substring(0, w.length - 4);
    if (w.endsWith('SION')) return w.substring(0, w.length - 2);
    if (w.length > 5 && w.endsWith('ES')) {
      w = w.substring(0, w.length - 2);
    } else if (w.length > 4 && w.endsWith('S')) {
      w = w.substring(0, w.length - 1);
    }
    return w;
  }

  /// La palabra tal cual y, si su terminación suele llevar tilde en
  /// español, también con ella: SECOP guarda textos con y sin tilde y SoQL
  /// no las ignora. Solo las terminaciones frecuentes (-ía, -ico/-ica, -ón)
  /// para no multiplicar las comparaciones.
  static List<String> _variantesConTilde(String palabra) {
    const tildes = {'A': 'Á', 'E': 'É', 'I': 'Í', 'O': 'Ó', 'U': 'Ú'};
    String conTilde(int i) =>
        palabra.substring(0, i) + tildes[palabra[i]]! + palabra.substring(i + 1);
    final variantes = <String>[palabra];
    if (palabra.length < 4) return variantes;
    final ia = RegExp(r'IA$').firstMatch(palabra);
    final ico = RegExp(r'IC[AO]$').firstMatch(palabra);
    final on = RegExp(r'ON$').firstMatch(palabra);
    if (ia != null) {
      variantes.add(conTilde(ia.start));
    } else if (ico != null) {
      // Esdrújulas: técnico, público, eléctrico -> tilde en la vocal previa.
      for (var i = ico.start - 1; i >= 0; i--) {
        if (tildes.containsKey(palabra[i])) {
          variantes.add(conTilde(i));
          break;
        }
      }
    } else if (on != null) {
      variantes.add(conTilde(on.start));
    }
    return variantes;
  }

  /// Nombre con las letras acentuables como comodín (`_`), para comparar
  /// con columnas que pueden venir con o sin tilde.
  static String _patronTolerante(String nombre) =>
      _normalizar(nombre).replaceAll(RegExp('[AEIOUÑ]'), '_');

  static String _titulo(String texto) => texto
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  static List<String>? _sinonimosPorPalabra(String palabra) {
    for (final e in _sinonimos.entries) {
      if (palabra.startsWith(e.key)) return e.value;
    }
    return null;
  }

  static _Lugar? _buscarLugarAlInicio(String texto) {
    final t = texto.trimLeft();
    final desplazamiento = texto.length - t.length;
    for (final lugar in _lugares) {
      if (t.startsWith(lugar.clave) &&
          (t.length == lugar.clave.length ||
              t[lugar.clave.length] == ' ')) {
        return lugar.conLargo(desplazamiento + lugar.clave.length);
      }
    }
    return null;
  }

  /// Departamentos y municipios del catálogo, de nombre más largo a más
  /// corto para que "Norte de Santander" gane sobre "Santander".
  static final List<_Lugar> _lugares = () {
    const departamentoSecop = {
      'Bogotá D.C.': 'Distrito Capital de Bogotá',
      'Archipiélago de San Andrés, Providencia y Santa Catalina':
          'San Andrés, Providencia y Santa Catalina',
    };
    final lista = <_Lugar>[];
    for (final d in ColombiaSecopCatalog.departamentos) {
      final valor = departamentoSecop[d] ?? d;
      lista.add(_Lugar(clave: _normalizar(d), etiqueta: d, departamento: valor));
    }
    lista
      ..add(const _Lugar(
        clave: 'BOGOTA',
        etiqueta: 'Bogotá D.C.',
        departamento: 'Distrito Capital de Bogotá',
      ))
      ..add(const _Lugar(
        clave: 'SAN ANDRES',
        etiqueta: 'San Andrés',
        departamento: 'San Andrés, Providencia y Santa Catalina',
      ))
      ..add(const _Lugar(
        clave: 'GUAJIRA',
        etiqueta: 'La Guajira',
        departamento: 'La Guajira',
      ));
    final claves = lista.map((l) => l.clave).toSet();
    ColombiaSecopCatalog.municipiosPorDepartamento.forEach((dep, municipios) {
      for (final m in municipios) {
        final clave = _normalizar(m);
        // Un municipio homónimo de un departamento (p. ej. Bolívar, Cauca)
        // se interpreta como el departamento.
        if (!claves.add(clave)) continue;
        lista.add(
          _Lugar(
            clave: clave,
            etiqueta: m,
            departamento: departamentoSecop[dep] ?? dep,
            municipio: m,
            patronMunicipio: _patronTolerante(m),
          ),
        );
      }
    });
    lista.sort((a, b) => b.clave.length.compareTo(a.clave.length));
    return lista;
  }();

  static const Map<String, String> _siglasEntidades = {
    'SENA': 'SENA|SERVICIO NACIONAL DE APRENDIZAJE',
    'ICBF': 'ICBF|INSTITUTO COLOMBIANO DE BIENESTAR',
    'INVIAS': 'INVIAS|INSTITUTO NACIONAL DE V_AS',
    'DIAN': 'DIAN|IMPUESTOS Y ADUANAS',
    'INPEC': 'INPEC|INSTITUTO NACIONAL PENITENCIARIO',
    'UNGRD': 'UNGRD|GESTI_N DEL RIESGO',
    'ANI': 'AGENCIA NACIONAL DE INFRAESTRUCTURA',
    'DPS': 'PROSPERIDAD SOCIAL',
    'ESAP': 'ESAP|ESCUELA SUPERIOR DE ADMINISTRACI_N',
    'UNP': 'UNIDAD NACIONAL DE PROTECCI_N',
    'POLICIA': 'POLIC_A',
    'EJERCITO': 'EJ_RCITO',
    'ARMADA': 'ARMADA',
    'FISCALIA': 'FISCAL_A',
    'PROCURADURIA': 'PROCURADUR_A',
    'REGISTRADURIA': 'REGISTRADUR_A',
    'ECOPETROL': 'ECOPETROL',
  };

  /// Temas frecuentes en contratación pública con sus formas habituales en
  /// el objeto de los contratos. La clave es la raíz de la palabra escrita.
  static const Map<String, List<String>> _sinonimos = {
    'ALIMENTACI': ['ALIMENTACI', 'ALIMENTO', 'ALIMENTARI', ' RACION', ' RACIÓN', 'REFRIGERIO'],
    'ALIMENTO': ['ALIMENTACI', 'ALIMENTO', 'ALIMENTARI', ' RACION', ' RACIÓN', 'REFRIGERIO'],
    'COMIDA': ['ALIMENTACI', 'ALIMENTO', 'COMIDA', ' RACION', ' RACIÓN', 'REFRIGERIO'],
    'VIAL': ['VIAL', ' VIAS', ' VÍAS', 'CARRETER', 'PAVIMENT'],
    'VIA': ['VIAL', ' VIAS', ' VÍAS', 'CARRETER', 'PAVIMENT'],
    'CARRETERA': ['VIAL', ' VIAS', ' VÍAS', 'CARRETER', 'PAVIMENT'],
    'ASEO': ['ASEO', 'LIMPIEZA'],
    'LIMPIEZA': ['ASEO', 'LIMPIEZA'],
    'VIGILANCIA': ['VIGILANCIA', 'SEGURIDAD PRIVADA'],
    'TRANSPORTE': ['TRANSPORTE'],
    'COMBUSTIBLE': ['COMBUSTIBLE', 'GASOLINA', 'ACPM'],
    'GASOLINA': ['COMBUSTIBLE', 'GASOLINA', 'ACPM'],
    'COMPUTADOR': ['COMPUTADOR', 'COMPUTO', 'CÓMPUTO', 'PORTATIL', 'PORTÁTIL'],
    'PAPELERIA': ['PAPELERIA', 'PAPELERÍA', 'UTILES DE OFICINA', 'ÚTILES DE OFICINA'],
    'MEDICAMENTO': ['MEDICAMENTO', 'FARMAC'],
    'OBRA': ['OBRA', 'CONSTRUCCI'],
  };

  /// Partículas que también aparecen en nombres propios ("Juan de la Cruz"):
  /// por sí solas no convierten la consulta en una frase.
  static const Set<String> _nombresPropios = {'DE', 'DEL', 'LA', 'LOS', 'Y'};

  /// Palabras que no aportan al filtro ("contratos de … que han …").
  static const Set<String> _vacias = {
    'CONTRATO', 'CONTRATOS', 'CONTRATAR', 'CONTRATADO', 'CONTRATADOS',
    'CONTRATARON', 'CONTRATA', 'CONTRATACION', 'CONTRATACIONES', 'PROCESO',
    'PROCESOS', 'SECOP', 'BUSCAR', 'BUSCO', 'QUIERO', 'MOSTRAR', 'MUESTRAME',
    'VER', 'DAME', 'LISTA', 'LISTADO', 'TODOS', 'TODAS', 'CUALES', 'QUE',
    'QUIEN', 'QUIENES', 'HAN', 'HAYAN', 'HAY', 'HA', 'SIDO', 'TIENE',
    'TIENEN', 'LOS', 'LAS', 'DEL', 'DE', 'LA', 'EL', 'EN', 'CON', 'POR',
    'PARA', 'SOBRE', 'UNA', 'UNO', 'UNOS', 'UNAS', 'AL', 'Y', 'O', 'A',
    'SUS', 'SU', 'SON', 'ESTA', 'ESTE', 'ESOS', 'ESAS', 'COMO', 'MAS',
    'ENTIDAD', 'ENTIDADES', 'PUBLICA', 'PUBLICAS', 'PUBLICO', 'PUBLICOS',
    'ESTADO', 'COLOMBIA', 'PESOS', 'ANO', 'ANOS', 'AÑO', 'AÑOS', 'VIGENCIA', 'SERVICIO',
    'SERVICIOS', 'PRESTACION', 'ADJUDICADO', 'ADJUDICADOS', 'FIRMADO',
    'FIRMADOS', 'CELEBRADO', 'CELEBRADOS', 'TIPO', 'RELACIONADOS',
    'RELACIONADAS', 'SEAN', 'MAYORES', 'MENORES', 'MILLONES',
  };
}

class _Lugar {
  const _Lugar({
    required this.clave,
    required this.etiqueta,
    this.departamento,
    this.municipio,
    this.patronMunicipio,
    this.largo = 0,
  });

  final String clave;
  final String etiqueta;
  final String? departamento;
  final String? municipio;
  final String? patronMunicipio;

  /// Caracteres consumidos del texto al reconocer el lugar.
  final int largo;

  _Lugar conLargo(int largo) => _Lugar(
    clave: clave,
    etiqueta: etiqueta,
    departamento: departamento,
    municipio: municipio,
    patronMunicipio: patronMunicipio,
    largo: largo,
  );
}
