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
    // Ciudades principales y sus departamentos (NIT confirmados en SECOP II).
    LogoEntidad(
      archivo: 'barranquilla.png',
      nits: ['890102018'],
      nombres: [
        'DISTRITO ESPECIAL INDUSTRIAL Y PORTUARIO DE BARRANQUILLA',
        'ALCALDIA DE BARRANQUILLA',
        'ALCALDIA DISTRITAL DE BARRANQUILLA',
      ],
    ),
    LogoEntidad(
      archivo: 'atlantico.png',
      nits: ['890102006'],
      nombres: ['GOBERNACION DEL ATLANTICO', 'DEPARTAMENTO DEL ATLANTICO'],
    ),
    LogoEntidad(
      archivo: 'bucaramanga.png',
      nits: ['890201222'],
      nombres: ['MUNICIPIO DE BUCARAMANGA', 'ALCALDIA DE BUCARAMANGA'],
    ),
    LogoEntidad(
      archivo: 'santander.png',
      nits: ['890201235'],
      nombres: ['GOBERNACION DE SANTANDER', 'DEPARTAMENTO DE SANTANDER'],
    ),
    LogoEntidad(
      archivo: 'antioquia.png',
      nits: ['890900286'],
      nombres: ['GOBERNACION DE ANTIOQUIA', 'DEPARTAMENTO DE ANTIOQUIA'],
    ),
    LogoEntidad(
      archivo: 'cundinamarca.png',
      nits: ['899999114'],
      nombres: ['GOBERNACION DE CUNDINAMARCA', 'DEPARTAMENTO DE CUNDINAMARCA'],
    ),
    LogoEntidad(
      archivo: 'transmilenio.png',
      nits: ['830063506'],
      nombres: ['TRANSMILENIO'],
    ),
    LogoEntidad(
      archivo: 'metro_bogota.png',
      nits: ['901038962'],
      nombres: ['METRO DE BOGOTA'],
    ),
    LogoEntidad(
      archivo: 'unal.png',
      nits: ['899999063'],
      nombres: ['UNIVERSIDAD NACIONAL DE COLOMBIA'],
    ),
    // Empresas, universidades y áreas metropolitanas (NIT confirmados en SECOP).
    LogoEntidad(
      archivo: 'idu.png',
      nits: ['899999081'],
      nombres: ['INSTITUTO DE DESARROLLO URBANO - IDU'],
    ),
    LogoEntidad(
      archivo: 'epm.png',
      nits: ['890904996'],
      nombres: ['EMPRESAS PUBLICAS DE MEDELLIN'],
    ),
    LogoEntidad(
      archivo: 'uis.png',
      nits: ['890201213'],
      nombres: ['UNIVERSIDAD INDUSTRIAL DE SANTANDER'],
    ),
    LogoEntidad(
      archivo: 'upc.png',
      nits: ['892300285'],
      nombres: ['UNIVERSIDAD POPULAR DEL CESAR'],
    ),
    LogoEntidad(
      archivo: 'emdupar.png',
      nits: ['892300548'],
      nombres: ['EMDUPAR'],
    ),
    LogoEntidad(
      archivo: 'amb.png',
      nits: ['890210581'],
      nombres: ['AREA METROPOLITANA DE BUCARAMANGA'],
    ),
    LogoEntidad(
      archivo: 'area_valle_aburra.png',
      nits: ['890984423'],
      nombres: ['AREA METROPOLITANA DEL VALLE DE ABURRA'],
    ),
    // Departamentos y capitales (escudos de Wikidata P94, NIT confirmados en SECOP).
    LogoEntidad(
      archivo: 'amazonas.png',
      nits: ['899999336'],
      nombres: [
        'GOBERNACION DEL AMAZONAS',
        'GOBERNACION DE AMAZONAS',
        'DEPARTAMENTO DEL AMAZONAS',
      ],
    ),
    LogoEntidad(
      archivo: 'arauca.png',
      nits: ['800102838'],
      nombres: [
        'DEPARTAMENTO DEL ARAUCA',
        'GOBERNACION DE ARAUCA',
        'GOBERNACION DEL ARAUCA',
      ],
    ),
    LogoEntidad(
      archivo: 'san_andres.png',
      nits: ['892400038'],
      nombres: [
        'DEPARTAMENTO ARCHIPIELAGO DE SAN ANDRES',
        'GOBERNACION DE SAN ANDRES',
      ],
    ),
    LogoEntidad(
      archivo: 'bolivar.png',
      nits: ['890480059'],
      nombres: ['GOBERNACION DE BOLIVAR', 'DEPARTAMENTO DE BOLIVAR'],
    ),
    LogoEntidad(
      archivo: 'boyaca.png',
      nits: ['891800498'],
      nombres: ['GOBERNACION DE BOYACA', 'DEPARTAMENTO DE BOYACA'],
    ),
    LogoEntidad(
      archivo: 'caldas.png',
      nits: ['890801052'],
      nombres: ['GOBERNACION DE CALDAS', 'DEPARTAMENTO DE CALDAS'],
    ),
    LogoEntidad(
      archivo: 'caqueta.png',
      nits: ['800091594'],
      nombres: [
        'GOBERNACION DEL CAQUETA',
        'GOBERNACION DE CAQUETA',
        'DEPARTAMENTO DEL CAQUETA',
      ],
    ),
    LogoEntidad(
      archivo: 'casanare.png',
      nits: ['892099216'],
      nombres: [
        'GOBERNACION DEL CASANARE',
        'GOBERNACION DE CASANARE',
        'DEPARTAMENTO DEL CASANARE',
      ],
    ),
    LogoEntidad(
      archivo: 'cauca.png',
      nits: ['891580016'],
      nombres: ['GOBERNACION DEL CAUCA', 'DEPARTAMENTO DEL CAUCA'],
    ),
    LogoEntidad(
      archivo: 'choco.png',
      nits: ['891680010'],
      nombres: ['GOBERNACION DEL CHOCO', 'DEPARTAMENTO DEL CHOCO'],
    ),
    LogoEntidad(
      archivo: 'cordoba.png',
      nits: ['800103935'],
      nombres: ['GOBERNACION DE CORDOBA', 'DEPARTAMENTO DE CORDOBA'],
    ),
    LogoEntidad(
      archivo: 'guainia.png',
      nits: ['892099149'],
      nombres: [
        'GOBERNACION DEL GUAINIA',
        'GOBERNACION DE GUAINIA',
        'DEPARTAMENTO DEL GUAINIA',
      ],
    ),
    LogoEntidad(
      archivo: 'guaviare.png',
      nits: ['800103196'],
      nombres: [
        'GOBERNACION DEL GUAVIARE',
        'GOBERNACION DE GUAVIARE',
        'DEPARTAMENTO DEL GUAVIARE',
      ],
    ),
    LogoEntidad(
      archivo: 'huila.png',
      nits: ['800103913'],
      nombres: ['GOBERNACION DEL HUILA', 'DEPARTAMENTO DEL HUILA'],
    ),
    LogoEntidad(
      archivo: 'la_guajira.png',
      nits: ['892115015'],
      nombres: ['GOBERNACION DE LA GUAJIRA', 'DEPARTAMENTO DE LA GUAJIRA'],
    ),
    LogoEntidad(
      archivo: 'magdalena.png',
      nits: ['800103920'],
      nombres: ['GOBERNACION DEL MAGDALENA', 'DEPARTAMENTO DEL MAGDALENA'],
    ),
    LogoEntidad(
      archivo: 'meta.png',
      nits: ['892000148'],
      nombres: ['GOBERNACION DEL META', 'DEPARTAMENTO DEL META'],
    ),
    LogoEntidad(
      archivo: 'narino.png',
      nits: ['800103923'],
      nombres: ['GOBERNACION DE NARIÑO', 'DEPARTAMENTO DE NARIÑO'],
    ),
    LogoEntidad(
      archivo: 'norte_santander.png',
      nits: ['800103927'],
      nombres: [
        'GOBERNACION NORTE DE SANTANDER',
        'GOBERNACION DE NORTE DE SANTANDER',
        'GOBERNACION DEL NORTE DE SANTANDER',
        'DEPARTAMENTO NORTE DE SANTANDER',
        'DEPARTAMENTO DE NORTE DE SANTANDER',
      ],
    ),
    LogoEntidad(
      archivo: 'putumayo.png',
      nits: ['800094164'],
      nombres: [
        'GOBERNACION DEL PUTUMAYO',
        'DEPARTAMENTO DEL PUTUMAYO',
        'GOBERNACION DE PUTUMAYO',
      ],
    ),
    LogoEntidad(
      archivo: 'quindio.png',
      nits: ['890001639'],
      nombres: ['GOBERNACION DEL QUINDIO', 'DEPARTAMENTO DEL QUINDIO'],
    ),
    LogoEntidad(
      archivo: 'risaralda.png',
      nits: ['891480085'],
      nombres: ['GOBERNACION DE RISARALDA', 'DEPARTAMENTO DE RISARALDA'],
    ),
    LogoEntidad(
      archivo: 'sucre.png',
      nits: ['892280021'],
      nombres: ['GOBERNACION DE SUCRE', 'DEPARTAMENTO DE SUCRE'],
    ),
    LogoEntidad(
      archivo: 'tolima.png',
      nits: ['800113672'],
      nombres: ['GOBERNACION DEL TOLIMA', 'DEPARTAMENTO DEL TOLIMA'],
    ),
    LogoEntidad(
      archivo: 'valle_cauca.png',
      nits: ['890399029'],
      nombres: ['GOBERNACION DEL VALLE', 'DEPARTAMENTO DEL VALLE DEL CAUCA'],
    ),
    LogoEntidad(
      archivo: 'vaupes.png',
      nits: ['845000021'],
      nombres: [
        'GOBERNACION DEL VAUPES',
        'GOBERNACION DE VAUPES',
        'DEPARTAMENTO DEL VAUPES',
      ],
    ),
    LogoEntidad(
      archivo: 'vichada.png',
      nits: ['800094067'],
      nombres: [
        'GOBERNACION DEL VICHADA',
        'GOBERNACION DE VICHADA',
        'DEPARTAMENTO DE VICHADA',
        'DEPARTAMENTO DEL VICHADA',
      ],
    ),
    LogoEntidad(
      archivo: 'leticia.png',
      nits: ['899999302'],
      nombres: ['MUNICIPIO DE LETICIA', 'ALCALDIA DE LETICIA'],
    ),
    LogoEntidad(
      archivo: 'arauca_municipio.png',
      nits: ['800102504'],
      nombres: ['ALCALDIA MUNICIPIO DE ARAUCA', 'ALCALDIA DE ARAUCA'],
    ),
    LogoEntidad(
      archivo: 'cartagena.png',
      nits: ['890480184'],
      nombres: [
        'DISTRITO TURISTICO Y CULTURAL DE CARTAGENA',
        'ALCALDIA DE CARTAGENA',
        'ALCALDIA MAYOR DE CARTAGENA',
        'ALCALDIA DISTRITAL DE CARTAGENA',
      ],
    ),
    LogoEntidad(
      archivo: 'tunja.png',
      nits: ['891800846'],
      nombres: ['ALCALDIA DE TUNJA', 'ALCALDIA MAYOR DE TUNJA'],
    ),
    LogoEntidad(
      archivo: 'manizales.png',
      nits: ['890801053'],
      nombres: ['ALCALDIA DE MANIZALES'],
    ),
    LogoEntidad(
      archivo: 'florencia.png',
      nits: ['800095728'],
      nombres: ['ALCALDIA DE FLORENCIA (CAQUETA)', 'FLORENCIA CAQUETA'],
    ),
    LogoEntidad(
      archivo: 'yopal.png',
      nits: ['891855017'],
      nombres: ['ALCALDIA DE YOPAL'],
    ),
    LogoEntidad(
      archivo: 'popayan.png',
      nits: ['891580006'],
      nombres: ['ALCALDIA DE POPAYAN'],
    ),
    LogoEntidad(
      archivo: 'quibdo.png',
      nits: ['891680011'],
      nombres: ['ALCALDIA MUNICIPIO DE QUIBDO', 'ALCALDIA DE QUIBDO'],
    ),
    LogoEntidad(
      archivo: 'monteria.png',
      nits: ['800096734'],
      nombres: ['ALCALDIA DE MONTERIA'],
    ),
    LogoEntidad(
      archivo: 'san_jose_guaviare.png',
      nits: ['800103180'],
      nombres: ['ALCALDIA MUNICIPAL DE SAN JOSE DEL GUAVIARE'],
    ),
    LogoEntidad(
      archivo: 'neiva.png',
      nits: ['891180009'],
      nombres: ['ALCALDIA DE NEIVA'],
    ),
    LogoEntidad(
      archivo: 'riohacha.png',
      nits: ['892115007'],
      nombres: [
        'ALCALDIA DISTRITO DE RIOHACHA',
        'ALCALDIA DISTRITAL DE RIOHACHA',
        'ALCALDIA DE RIOHACHA',
      ],
    ),
    LogoEntidad(
      archivo: 'santa_marta.png',
      nits: ['891780009'],
      nombres: ['ALCALDIA DISTRITAL DE SANTA MARTA', 'ALCALDIA DE SANTA MARTA'],
    ),
    LogoEntidad(
      archivo: 'villavicencio.png',
      nits: ['892099324'],
      nombres: [
        'ALCALDIA MUNICIPIO DE VILLAVICENCIO',
        'ALCALDIA DE VILLAVICENCIO',
      ],
    ),
    LogoEntidad(
      archivo: 'pasto.png',
      nits: ['891280000'],
      nombres: ['ALCALDIA DE PASTO'],
    ),
    LogoEntidad(
      archivo: 'cucuta.png',
      nits: ['890501434'],
      nombres: ['MUNICIPIO DE SAN JOSE DE CUCUTA', 'ALCALDIA DE CUCUTA'],
    ),
    LogoEntidad(
      archivo: 'mocoa.png',
      nits: ['800102891'],
      nombres: ['ALCALDIA DE MOCOA'],
    ),
    LogoEntidad(
      archivo: 'armenia.png',
      nits: ['890000464'],
      nombres: [
        'MUNICIPIO DE ARMENIA QUINDIO',
        'ALCALDIA DE ARMENIA QUINDIO',
        'ALCALDIA DE ARMENIA',
      ],
    ),
    LogoEntidad(
      archivo: 'pereira.png',
      nits: ['891480030'],
      nombres: ['MUNICIPIO DE PEREIRA', 'ALCALDIA DE PEREIRA'],
    ),
    LogoEntidad(
      archivo: 'ibague.png',
      nits: ['800113389'],
      nombres: ['MUNICIPIO DE IBAGUE', 'ALCALDIA DE IBAGUE'],
    ),
    LogoEntidad(
      archivo: 'cali.png',
      nits: ['890399011'],
      nombres: [
        'SANTIAGO DE CALI DISTRITO ESPECIAL',
        'ALCALDIA DE SANTIAGO DE CALI',
        'ALCALDIA DE CALI',
      ],
    ),
    LogoEntidad(
      archivo: 'mitu.png',
      nits: ['892099233'],
      nombres: ['ALCALDIA DE MITU'],
    ),
  ];
}
