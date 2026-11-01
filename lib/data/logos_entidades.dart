/// Logos institucionales originales de las entidades más consultadas.
///
/// Las imágenes salen de Wikimedia Commons (la propiedad "logo" de cada
/// entidad en Wikidata) y se usan solo para identificar a la entidad en la
/// consulta de datos públicos; no implican respaldo de la entidad.
///
/// Se reconocen por NIT (los 9 dígitos, sin dígito de verificación, tal como
/// los reporta SECOP II) o, si no hay NIT, por palabras del nombre.
class LogoEntidad {
  const LogoEntidad({
    required this.archivo,
    required this.nits,
    this.nombres = const [],
  });

  /// Nombre del archivo dentro de `assets/logos_entidades/`.
  final String archivo;
  final List<String> nits;

  /// Fragmentos del nombre normalizado (mayúsculas, sin tildes).
  final List<String> nombres;

  String get asset => 'assets/logos_entidades/$archivo';
}

class LogosEntidades {
  LogosEntidades._();

  static String _normalizar(String texto) => texto
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll(RegExp(r'\s+'), ' ');

  static LogoEntidad? buscar({String nombre = '', String nit = ''}) {
    final digitos = nit.replaceAll(RegExp(r'\D'), '');
    if (digitos.length >= 9) {
      final base = digitos.substring(0, 9);
      for (final l in logos) {
        if (l.nits.contains(base)) return l;
      }
    }
    final n = _normalizar(nombre);
    if (n.isEmpty) return null;
    for (final l in logos) {
      if (l.nombres.any(n.contains)) return l;
    }
    return null;
  }

  static const List<LogoEntidad> logos = [
    LogoEntidad(
      archivo: 'sena.png',
      nits: ['899999034'],
      nombres: ['SERVICIO NACIONAL DE APRENDIZAJE', 'SENA REGIONAL'],
    ),
    LogoEntidad(
      archivo: 'icbf.png',
      nits: ['899999239'],
      nombres: ['BIENESTAR FAMILIAR', 'ICBF'],
    ),
    LogoEntidad(
      archivo: 'invias.png',
      nits: ['800215807'],
      nombres: ['INSTITUTO NACIONAL DE VIAS', 'INVIAS'],
    ),
    LogoEntidad(
      archivo: 'dian.png',
      nits: ['800197268'],
      nombres: ['IMPUESTOS Y ADUANAS NACIONALES'],
    ),
    LogoEntidad(
      archivo: 'policia.png',
      nits: ['800141397'],
      nombres: ['POLICIA NACIONAL DE COLOMBIA'],
    ),
    LogoEntidad(
      archivo: 'fiscalia.png',
      nits: ['800152783'],
      nombres: ['FISCALIA GENERAL'],
    ),
    LogoEntidad(
      archivo: 'rama_judicial.png',
      nits: ['800093816'],
      nombres: ['RAMA JUDICIAL', 'ADMINISTRACION JUDICIAL'],
    ),
    LogoEntidad(
      archivo: 'procuraduria.png',
      nits: ['899999119'],
      nombres: ['PROCURADURIA GENERAL'],
    ),
    LogoEntidad(
      archivo: 'contraloria.png',
      nits: ['899999067'],
      nombres: ['CONTRALORIA GENERAL DE LA REPUBLICA'],
    ),
    LogoEntidad(
      archivo: 'defensoria.png',
      nits: ['800186061'],
      nombres: ['DEFENSORIA DEL PUEBLO'],
    ),
    LogoEntidad(
      archivo: 'ani.png',
      nits: ['830125996'],
      nombres: ['AGENCIA NACIONAL DE INFRAESTRUCTURA'],
    ),
    LogoEntidad(
      archivo: 'ant.png',
      nits: ['900948953'],
      nombres: ['AGENCIA NACIONAL DE TIERRAS'],
    ),
    LogoEntidad(
      archivo: 'adr.png',
      nits: ['900948958'],
      nombres: ['AGENCIA DE DESARROLLO RURAL'],
    ),
    LogoEntidad(
      archivo: 'colombia_compra.png',
      nits: ['900514813'],
      nombres: [
        'COLOMBIA COMPRA EFICIENTE',
        'CONTRATACION PUBLICA COLOMBIA COMPRA',
      ],
    ),
    LogoEntidad(
      archivo: 'victimas.png',
      nits: ['900490473'],
      nombres: [
        'REPARACION INTEGRAL A LAS VICTIMAS',
        'UNIDAD PARA LAS VICTIMAS',
      ],
    ),
    LogoEntidad(
      archivo: 'inpec.png',
      nits: ['800215546'],
      nombres: ['INPEC', 'PENITENCIARIO Y CARCELARIO'],
    ),
    LogoEntidad(
      archivo: 'dnp.png',
      nits: ['899999011'],
      nombres: ['DEPARTAMENTO NACIONAL DE PLANEACION'],
    ),
    LogoEntidad(
      archivo: 'dane.png',
      nits: ['899999027'],
      nombres: ['NACIONAL DE ESTADISTICA', 'DANE '],
    ),
    LogoEntidad(
      archivo: 'prosperidad_social.png',
      nits: ['900039533'],
      nombres: ['PROSPERIDAD SOCIAL'],
    ),
    LogoEntidad(archivo: 'ungrd.png', nits: ['900478966'], nombres: ['UNGRD']),
    LogoEntidad(
      archivo: 'invima.png',
      nits: ['830000167'],
      nombres: ['INVIMA', 'VIGILANCIA DE MEDICAMENTOS'],
    ),
    LogoEntidad(
      archivo: 'ica.png',
      nits: ['899999069'],
      nombres: ['INSTITUTO COLOMBIANO AGROPECUARIO'],
    ),
    LogoEntidad(
      archivo: 'igac.png',
      nits: ['899999004'],
      nombres: ['AGUSTIN CODAZZI', 'IGAC'],
    ),
    LogoEntidad(
      archivo: 'aerocivil.png',
      nits: ['899999059'],
      nombres: ['AEROCIVIL', 'AERONAUTICA CIVIL'],
    ),
    LogoEntidad(
      archivo: 'funcion_publica.png',
      nits: ['899999020'],
      nombres: ['FUNCION PUBLICA'],
    ),
    LogoEntidad(
      archivo: 'unp.png',
      nits: ['900475780'],
      nombres: ['UNIDAD NACIONAL DE PROTECCION'],
    ),
    LogoEntidad(
      archivo: 'mintrabajo.png',
      nits: ['830115226'],
      nombres: [
        'MINISTERIO DEL TRABAJO',
        'MINISTERIO DE TRABAJO',
        'MINTRABAJO',
      ],
    ),
    LogoEntidad(
      archivo: 'minhacienda.png',
      nits: ['899999090'],
      nombres: ['MINISTERIO DE HACIENDA'],
    ),
    LogoEntidad(
      archivo: 'mintransporte.png',
      nits: ['899999055'],
      nombres: ['MINISTERIO DE TRANSPORTE'],
    ),
    LogoEntidad(
      archivo: 'mineducacion.png',
      nits: ['899999001'],
      nombres: ['MINISTERIO DE EDUCACION'],
    ),
    LogoEntidad(
      archivo: 'minsalud.png',
      nits: ['900474727'],
      nombres: ['MINISTERIO DE SALUD', 'MINSALUD'],
    ),
    LogoEntidad(
      archivo: 'mintic.png',
      nits: ['800131648', '899999053'],
      nombres: [
        'MINTIC',
        'FONDO UNICO DE TECNOLOGIAS',
        'MINISTERIO DE TECNOLOGIAS DE LA INFORMACION',
      ],
    ),
    LogoEntidad(
      archivo: 'mindefensa.png',
      nits: ['899999003'],
      nombres: ['MINISTERIO DE DEFENSA'],
    ),
    LogoEntidad(
      archivo: 'minjusticia.png',
      nits: ['900457461'],
      nombres: ['MINISTERIO DE JUSTICIA'],
    ),
    LogoEntidad(
      archivo: 'minagricultura.png',
      nits: ['899999028'],
      nombres: ['MINISTERIO DE AGRICULTURA'],
    ),
    LogoEntidad(
      archivo: 'minminas.png',
      nits: ['899999022'],
      nombres: ['MINISTERIO DE MINAS'],
    ),
    LogoEntidad(
      archivo: 'mincit.png',
      nits: ['830115297'],
      nombres: ['MINISTERIO DE COMERCIO', 'MINCIT'],
    ),
    LogoEntidad(
      archivo: 'minambiente.png',
      nits: ['830115395'],
      nombres: ['MINISTERIO DE AMBIENTE'],
    ),
    LogoEntidad(
      archivo: 'minvivienda.png',
      nits: ['900463725'],
      nombres: ['MINISTERIO DE VIVIENDA', 'MINVIVIENDA'],
    ),
    LogoEntidad(
      archivo: 'mininterior.png',
      nits: ['830114475'],
      nombres: ['MINISTERIO DEL INTERIOR'],
    ),
    LogoEntidad(
      archivo: 'cancilleria.png',
      nits: ['899999042'],
      nombres: ['RELACIONES EXTERIORES', 'CANCILLERIA'],
    ),
    LogoEntidad(
      archivo: 'mincultura.png',
      nits: ['830034348'],
      nombres: [
        'MINISTERIO DE LAS CULTURAS',
        'MINISTERIO DE CULTURA',
        'MINCULTURA',
      ],
    ),
    LogoEntidad(
      archivo: 'mindeporte.png',
      nits: ['899999306'],
      nombres: ['MINISTERIO DEL DEPORTE', 'MINDEPORTE'],
    ),
    LogoEntidad(
      archivo: 'minciencias.png',
      nits: ['899999296'],
      nombres: ['MINCIENCIAS', 'MINISTERIO DE CIENCIA'],
    ),
    LogoEntidad(
      archivo: 'superservicios.png',
      nits: ['800250984'],
      nombres: ['SUPERINTENDENCIA DE SERVICIOS PUBLICOS'],
    ),
    LogoEntidad(
      archivo: 'bogota.png',
      nits: ['899999061'],
      nombres: ['ALCALDIA MAYOR DE BOGOTA', 'BOGOTA DISTRITO CAPITAL'],
    ),
    LogoEntidad(
      archivo: 'medellin.png',
      nits: ['890905211'],
      nombres: [
        'ALCALDIA DE MEDELLIN',
        'DISTRITO ESPECIAL DE CIENCIA TECNOLOGIA E INNOVACION DE MEDELLIN',
      ],
    ),
    LogoEntidad(
      archivo: 'gobernacion_cesar.png',
      nits: ['892399999'],
      nombres: [
        'GOBERNACION DEL CESAR',
        'GOBERNACION DEL DEPARTAMENTO DEL CESAR',
      ],
    ),
    LogoEntidad(
      archivo: 'valledupar.png',
      nits: ['800098911'],
      nombres: ['ALCALDIA MUNICIPAL DE VALLEDUPAR', 'ALCALDIA DE VALLEDUPAR'],
    ),
    LogoEntidad(
      archivo: 'corpocesar.png',
      nits: ['892301483'],
      nombres: ['CORPOCESAR'],
    ),
  ];
}
