/// Estructura del SENA para ordenar su contratación como la entidad está
/// organizada: la Dirección General (nivel nacional) y las 33 direcciones
/// regionales, cada una con su despacho y sus centros de formación.
///
/// SECOP II no publica esa estructura: cada grupo administrativo tiene su
/// propia cuenta compradora ("SENA REGIONAL CESAR Grupo de Apoyo
/// Administrativo Mixto") y en cada proceso escribe a mano la unidad que
/// contrata ("UNIDAD DE CONTRATACIÓN CBC..", "CIGEC"). [EstructuraSena]
/// ubica cada par cuenta + unidad en su regional y en su despacho o centro,
/// que son quienes tienen ordenador del gasto.
library;

/// NIT del SENA en SECOP II, sin dígito de verificación.
const String nitSena = '899999034';

bool esNitSena(String nit) =>
    nit.replaceAll(RegExp(r'[^0-9]'), '').startsWith(nitSena);

class CentroSena {
  const CentroSena(
    this.nombre, {
    this.siglas = const [],
    this.frases = const [],
  });

  final String nombre;

  /// Siglas tal como aparecen en SECOP II (CBC, CEDRUM, CTPI…).
  final List<String> siglas;

  /// Frases propias del centro, en mayúsculas y sin tildes.
  final List<String> frases;
}

class RegionalSena {
  const RegionalSena(
    this.nombre, {
    required this.claves,
    required this.departamento,
    required this.centros,
  });

  final String nombre;

  /// Cómo aparece la regional en el nombre de la cuenta de SECOP II.
  final List<String> claves;

  /// `departamento_entidad` de SECOP II para las cuentas sin regional en el
  /// nombre.
  final String departamento;
  final List<CentroSena> centros;
}

/// Lo que contrata en la Dirección General.
class DependenciaNacionalSena {
  const DependenciaNacionalSena(this.nombre, this.frases);
  final String nombre;
  final List<String> frases;
}

const List<DependenciaNacionalSena> dependenciasNacionalesSena = [
  DependenciaNacionalSena('Despacho de la Dirección General', [
    'DESPACHO DIRECCION GENERAL',
    'DESPACHO DE LA DIRECCION GENERAL',
  ]),
  DependenciaNacionalSena('Secretaría General', ['SECRETARIA GENERAL']),
  DependenciaNacionalSena('Dirección Administrativa y Financiera', [
    'ADMINISTRATIVA Y FINANCIERA',
  ]),
  DependenciaNacionalSena('Dirección de Empleo y Trabajo', [
    'EMPLEO Y TRABAJO',
  ]),
  DependenciaNacionalSena('Dirección de Formación Profesional', [
    'FORMACION PROFESIONAL',
  ]),
  DependenciaNacionalSena(
    'Dirección del Sistema Nacional de Formación para el Trabajo',
    ['SISTEMA NACIONAL DE FORMACION'],
  ),
  DependenciaNacionalSena('Dirección de Promoción y Relaciones Corporativas', [
    'RELACIONES CORPORATIVAS',
    'GESTION DE CONVENIOS',
  ]),
  DependenciaNacionalSena('Dirección Jurídica', ['JURIDICA']),
  DependenciaNacionalSena(
    'Dirección de Planeación y Direccionamiento Corporativo',
    ['PLANEACION', 'DIRECCIONAMIENTO CORPORATIVO'],
  ),
  DependenciaNacionalSena('Oficina de Sistemas', ['OFICINA DE SISTEMAS']),
  DependenciaNacionalSena('Oficina de Comunicaciones', ['COMUNICACIONES']),
  DependenciaNacionalSena('Oficina de Control Interno Disciplinario', [
    'CONTROL INTERNO DISCIPLINARIO',
  ]),
  DependenciaNacionalSena('Oficina de Control Interno', ['CONTROL INTERNO']),
  DependenciaNacionalSena('Grupo de Gestión Contractual', [
    'GESTION CONTRACTUAL',
  ]),
];

const List<RegionalSena> regionalesSena = [
  RegionalSena(
    'Amazonas',
    claves: ['AMAZONAS'],
    departamento: 'AMAZONAS',
    centros: [
      CentroSena(
        'Centro para la Biodiversidad y el Turismo del Amazonas',
        frases: ['BIODIVERSIDAD Y EL TURISMO'],
      ),
    ],
  ),
  RegionalSena(
    'Antioquia',
    claves: ['ANTIOQUIA'],
    departamento: 'ANTIOQUIA',
    centros: [
      CentroSena(
        'Centro de los Recursos Naturales Renovables La Salada',
        siglas: ['CRNR'],
        frases: ['LA SALADA'],
      ),
      CentroSena(
        'Centro del Diseño y Manufactura del Cuero',
        siglas: ['CDMC'],
        frases: ['MANUFACTURA DEL CUERO'],
      ),
      CentroSena(
        'Centro de Formación en Diseño, Confección y Moda',
        siglas: ['CFDCM'],
        frases: ['CONFECCION Y MODA'],
      ),
      CentroSena(
        'Centro para el Desarrollo del Hábitat y la Construcción',
        siglas: ['CDHC'],
        frases: ['HABITAT Y LA CONSTRUCCION'],
      ),
      CentroSena(
        'Centro de Tecnología de la Manufactura Avanzada',
        siglas: ['CTMA'],
        frases: ['MANUFACTURA AVANZADA'],
      ),
      CentroSena(
        'Centro Tecnológico del Mobiliario',
        siglas: ['CTM'],
        frases: ['MOBILIARIO'],
      ),
      CentroSena(
        'Centro Textil y de Gestión Industrial',
        siglas: ['CTGI'],
        frases: ['TEXTIL Y DE GESTION INDUSTRIAL'],
      ),
      CentroSena(
        'Centro de Comercio',
        siglas: ['9301'],
        frases: ['CENTRO DE COMERCIO', 'GRUPO MIXTO POR COMERCIO'],
      ),
      CentroSena(
        'Centro de Servicios de Salud',
        siglas: ['9401'],
        frases: ['CENTRO DE SERVICIOS DE SALUD'],
      ),
      CentroSena(
        'Centro de Servicios y Gestión Empresarial',
        siglas: ['CESGE', 'CSGE'],
        frases: ['SERVICIOS Y GESTION EMPRESARIAL'],
      ),
      CentroSena(
        'Complejo Tecnológico para la Gestión Agroempresarial',
        siglas: ['CTPGA'],
        frases: ['GESTION AGROEMPRESARIAL'],
      ),
      CentroSena(
        'Complejo Tecnológico Minero Agroempresarial',
        siglas: ['CTMAE'],
        frases: ['MINERO AGROEMPRESARIAL'],
      ),
      CentroSena(
        'Centro de la Innovación, la Agroindustria y la Aviación',
        siglas: ['CIAA'],
        frases: ['AGROINDUSTRIA Y LA AVIACION'],
      ),
      CentroSena(
        'Complejo Tecnológico Agroindustrial, Pecuario y Turístico',
        siglas: ['CTAPT'],
        frases: ['AGROINDUSTRIAL PECUARIO Y TURISTICO'],
      ),
      CentroSena(
        'Complejo Tecnológico, Turístico y Agroindustrial del Occidente Antioqueño',
        siglas: ['CTTAOA', 'CTTYAOA'],
        frases: ['TURISTICO Y AGROINDUSTRIAL'],
      ),
      CentroSena(
        'Centro de Formación Minero Ambiental',
        siglas: ['CFMA'],
        frases: ['MINERO AMBIENTAL'],
      ),
    ],
  ),
  RegionalSena(
    'Arauca',
    claves: ['ARAUCA'],
    departamento: 'ARAUCA',
    centros: [
      CentroSena(
        'Centro de Gestión y Desarrollo Agroindustrial de Arauca',
        frases: ['DESARROLLO AGROINDUSTRIAL DE ARAUCA'],
      ),
    ],
  ),
  RegionalSena(
    'Atlántico',
    claves: ['ATLANTICO'],
    departamento: 'ATLANTICO',
    centros: [
      CentroSena(
        'Centro Nacional Colombo Alemán',
        siglas: ['CNCA'],
        frases: ['COLOMBO ALEMAN'],
      ),
      CentroSena(
        'Centro Industrial y de Aviación',
        siglas: ['CIA'],
        frases: ['INDUSTRIAL Y DE AVIACION'],
      ),
      CentroSena(
        'Centro de Comercio y Servicios',
        siglas: ['CCYS'],
        frases: ['COMERCIO Y SERVICIOS'],
      ),
      CentroSena(
        'Centro para el Desarrollo Agroecológico y Agroindustrial',
        frases: ['DESARROLLO AGROECOLOGICO'],
      ),
    ],
  ),
  RegionalSena(
    'Bolívar',
    claves: ['BOLIVAR'],
    departamento: 'BOLIVAR',
    centros: [
      CentroSena(
        'Centro Agroempresarial y Minero',
        frases: ['AGROEMPRESARIAL Y MINERO'],
      ),
      CentroSena(
        'Centro Internacional Náutico, Fluvial y Portuario',
        siglas: ['CINAFLUP', 'CINFP'],
        frases: ['NAUTICO FLUVIAL'],
      ),
      CentroSena(
        'Centro para la Industria Petroquímica',
        siglas: ['CPIP', 'CIP'],
        frases: ['INDUSTRIA PETROQUIMICA'],
      ),
      CentroSena(
        'Centro de Comercio y Servicios',
        frases: ['COMERCIO Y SERVICIOS'],
      ),
    ],
  ),
  RegionalSena(
    'Boyacá',
    claves: ['BOYACA'],
    departamento: 'BOYACA',
    centros: [
      CentroSena(
        'Centro de Desarrollo Agropecuario y Agroindustrial',
        siglas: ['CDAA', 'CEDEAGRO'],
        frases: ['DESARROLLO AGROPECUARIO Y AGROINDUSTRIAL'],
      ),
      CentroSena(
        'Centro de Gestión Administrativa y Fortalecimiento Empresarial',
        siglas: ['CGAFE', 'CEGAFE'],
        frases: ['FORTALECIMIENTO EMPRESARIAL'],
      ),
      CentroSena(
        'Centro Industrial de Mantenimiento y Manufactura',
        siglas: ['CIMM'],
        frases: ['MANTENIMIENTO Y MANUFACTURA'],
      ),
      CentroSena('Centro Minero', frases: ['CENTRO MINERO']),
      CentroSena(
        'Centro de la Innovación Agroindustrial y de Servicios',
        frases: ['INNOVACION AGROINDUSTRIAL Y DE SERVICIOS', 'PUERTO BOYACA'],
      ),
    ],
  ),
  RegionalSena(
    'Caldas',
    claves: ['CALDAS'],
    departamento: 'CALDAS',
    centros: [
      CentroSena(
        'Centro de Automatización Industrial',
        frases: ['AUTOMATIZACION INDUSTRIAL'],
      ),
      CentroSena(
        'Centro de Procesos Industriales y Construcción',
        siglas: ['CPIC'],
        frases: ['PROCESOS INDUSTRIALES Y CONSTRUCCION'],
      ),
      CentroSena(
        'Centro de Comercio y Servicios',
        frases: ['COMERCIO Y SERVICIOS'],
      ),
      CentroSena(
        'Centro para la Formación Cafetera',
        siglas: ['CFC'],
        frases: ['FORMACION CAFETERA'],
      ),
      CentroSena(
        'Centro Pecuario Agroempresarial',
        siglas: ['CPA', 'CPYA'],
        frases: ['PECUARIO AGROEMPRESARIAL'],
      ),
    ],
  ),
  RegionalSena(
    'Caquetá',
    claves: ['CAQUETA'],
    departamento: 'CAQUETA',
    centros: [
      CentroSena(
        'Centro Tecnológico de la Amazonía',
        frases: ['TECNOLOGICO DE LA AMAZONIA'],
      ),
    ],
  ),
  RegionalSena(
    'Casanare',
    claves: ['CASANARE'],
    departamento: 'CASANARE',
    centros: [
      CentroSena(
        'Centro Agroindustrial y Fortalecimiento Empresarial del Casanare',
        frases: ['FORTALECIMIENTO EMPRESARIAL DEL CASANARE'],
      ),
    ],
  ),
  RegionalSena(
    'Cauca',
    claves: ['CAUCA'],
    departamento: 'CAUCA',
    centros: [
      CentroSena('Centro Agropecuario', frases: ['CENTRO AGROPECUARIO']),
      CentroSena(
        'Centro de Teleinformática y Producción Industrial',
        siglas: ['CTPI'],
        frases: ['TELEINFORMATICA'],
      ),
      CentroSena(
        'Centro de Comercio y Servicios',
        frases: ['COMERCIO Y SERVICIOS'],
      ),
    ],
  ),
  RegionalSena(
    'Cesar',
    claves: ['CESAR'],
    departamento: 'CESAR',
    centros: [
      CentroSena(
        'Centro Biotecnológico del Caribe',
        siglas: ['CBC'],
        frases: ['BIOTECNOLOGICO DEL CARIBE'],
      ),
      CentroSena(
        'Centro Agroempresarial',
        siglas: ['CAE'],
        frases: ['AGUACHICA'],
      ),
      // En SECOP II figura como COMM hasta 2024 y como CIGEC desde 2025.
      CentroSena(
        'Centro de Operación y Mantenimiento Minero',
        siglas: ['COMM', 'CIGEC'],
        frases: ['MANTENIMIENTO MINERO'],
      ),
    ],
  ),
  RegionalSena(
    'Chocó',
    claves: ['CHOCO'],
    departamento: 'CHOCO',
    centros: [
      CentroSena(
        'Centro de Recursos Naturales, Industria y Biodiversidad',
        frases: ['INDUSTRIA Y BIODIVERSIDAD'],
      ),
      CentroSena(
        'Centro Agroambiental del Chocó',
        siglas: ['CAC'],
        frases: ['AGROAMBIENTAL'],
      ),
    ],
  ),
  RegionalSena(
    'Córdoba',
    claves: ['CORDOBA'],
    departamento: 'CORDOBA',
    centros: [
      CentroSena(
        'Centro Agropecuario y de Biotecnología El Porvenir',
        frases: ['EL PORVENIR'],
      ),
      CentroSena(
        'Centro de Comercio, Industria y Turismo de Córdoba',
        frases: ['COMERCIO INDUSTRIA Y TURISMO'],
      ),
    ],
  ),
  RegionalSena(
    'Cundinamarca',
    claves: ['CUNDINAMARCA'],
    departamento: 'CUNDINAMARCA',
    centros: [
      CentroSena(
        'Centro de Biotecnología Agropecuaria',
        siglas: ['CBA'],
        frases: ['BIOTECNOLOGIA AGROPECUARIA'],
      ),
      CentroSena(
        'Centro de Desarrollo Agroempresarial',
        siglas: ['CDA'],
        frases: ['DESARROLLO AGROEMPRESARIAL'],
      ),
      CentroSena(
        'Centro Agroecológico y Empresarial',
        siglas: ['CAE'],
        frases: ['AGROECOLOGICO Y EMPRESARIAL'],
      ),
      CentroSena(
        'Centro de la Tecnología del Diseño y la Productividad Empresarial',
        siglas: ['CTDPE'],
        frases: ['PRODUCTIVIDAD EMPRESARIAL', 'GIRARDOT'],
      ),
      CentroSena(
        'Centro de Desarrollo Agroindustrial y Empresarial',
        siglas: ['CDAE'],
        frases: ['DESARROLLO AGROINDUSTRIAL Y EMPRESARIAL'],
      ),
      CentroSena(
        'Centro Industrial y de Desarrollo Empresarial de Soacha',
        siglas: ['CIDE'],
        frases: ['DESARROLLO EMPRESARIAL DE SOACHA'],
      ),
    ],
  ),
  RegionalSena(
    'Distrito Capital',
    claves: ['DISTRITO CAPITAL'],
    departamento: 'DISTRITO CAPITAL DE BOGOTA',
    centros: [
      CentroSena(
        'Centro de Electricidad, Electrónica y Telecomunicaciones',
        siglas: ['CEET'],
        frases: ['ELECTRONICA Y TELECOMUNICACIONES'],
      ),
      CentroSena(
        'Centro de Gestión Industrial',
        siglas: ['CGI'],
        frases: ['CENTRO DE GESTION INDUSTRIAL'],
      ),
      CentroSena(
        'Centro de Manufactura en Textil y Cuero',
        frases: ['TEXTIL Y CUERO'],
      ),
      CentroSena(
        'Centro de Tecnologías para la Construcción y la Madera',
        siglas: ['CTCM'],
        frases: ['CONSTRUCCION Y LA MADERA', 'CONTRUCCION Y LA MADERA'],
      ),
      CentroSena(
        'Centro de Diseño y Metrología',
        frases: ['DISENO Y METROLOGIA'],
      ),
      CentroSena('Centro Metalmecánico', frases: ['METALMECANICO']),
      CentroSena(
        'Centro de Materiales y Ensayos',
        frases: ['MATERIALES Y ENSAYOS'],
      ),
      CentroSena(
        'Centro de Gestión Administrativa',
        siglas: ['CGA'],
        frases: ['CENTRO DE GESTION ADMINISTRATIVA'],
      ),
      CentroSena(
        'Centro de Servicios Financieros',
        siglas: ['CSF'],
        frases: ['SERVICIOS FINANCIEROS'],
      ),
      CentroSena(
        'Centro Nacional de Hotelería, Turismo y Alimentos',
        frases: ['HOTELERIA TURISMO Y ALIMENTOS'],
      ),
      CentroSena(
        'Centro de Formación de Talento Humano en Salud',
        frases: ['TALENTO HUMANO EN SALUD'],
      ),
      CentroSena(
        'Centro de Gestión de Mercados, Logística y Tecnologías de la Información',
        siglas: ['CGMLTI'],
        frases: ['GESTION DE MERCADOS'],
      ),
      CentroSena(
        'Centro para la Industria de la Comunicación Gráfica',
        siglas: ['CENIGRAF'],
        frases: ['COMUNICACION GRAFICA'],
      ),
      CentroSena(
        'Centro de Formación en Actividad Física y Cultura',
        siglas: ['CFAFC'],
        frases: ['ACTIVIDAD FISICA'],
      ),
      CentroSena(
        'Centro de Tecnologías del Transporte',
        siglas: ['CTT'],
        frases: ['TECNOLOGIAS DEL TRANSPORTE'],
      ),
    ],
  ),
  RegionalSena(
    'Guainía',
    claves: ['GUAINIA'],
    departamento: 'GUAINIA',
    centros: [
      CentroSena(
        'Centro Ambiental y Ecoturístico del Nororiente Amazónico',
        frases: ['ECOTURISTICO DEL NORORIENTE'],
      ),
    ],
  ),
  RegionalSena(
    'Guaviare',
    claves: ['GUAVIARE'],
    departamento: 'GUAVIARE',
    centros: [
      CentroSena(
        'Centro de Desarrollo Agroindustrial, Turístico y Tecnológico del Guaviare',
        frases: ['TURISTICO Y TECNOLOGICO DEL GUAVIARE'],
      ),
    ],
  ),
  RegionalSena(
    'Huila',
    claves: ['HUILA'],
    departamento: 'HUILA',
    centros: [
      CentroSena(
        'Centro de la Industria, la Empresa y los Servicios',
        siglas: ['CIES'],
        frases: ['INDUSTRIA LA EMPRESA Y LOS SERVICIOS'],
      ),
      CentroSena(
        'Centro de Formación Agroindustrial',
        siglas: ['CEFA'],
        frases: ['FORMACION AGROINDUSTRIAL'],
      ),
      CentroSena(
        'Centro Agroempresarial y Desarrollo Pecuario del Huila',
        siglas: ['CADP'],
        frases: ['GARZON'],
      ),
      CentroSena(
        'Centro de Desarrollo Agroempresarial y Turístico del Huila',
        siglas: ['CDATH'],
        frases: ['LA PLATA'],
      ),
      CentroSena(
        'Centro de Gestión y Desarrollo Sostenible Surcolombiano',
        siglas: ['CGDSS'],
        frases: ['DESARROLLO SOSTENIBLE SURCOLOMBIANO'],
      ),
    ],
  ),
  RegionalSena(
    'La Guajira',
    claves: ['GUAJIRA'],
    departamento: 'LA GUAJIRA',
    centros: [
      CentroSena(
        'Centro Industrial y de Energías Alternativas',
        siglas: ['449222'],
        frases: ['ENERGIAS ALTERNATIVAS'],
      ),
      CentroSena(
        'Centro Agroempresarial y Acuícola',
        siglas: ['449524'],
        frases: ['AGROEMPRESARIAL Y ACUICOLA'],
      ),
    ],
  ),
  RegionalSena(
    'Magdalena',
    claves: ['MAGDALENA'],
    departamento: 'MAGDALENA',
    centros: [
      CentroSena(
        'Centro Acuícola y Agroindustrial de Gaira',
        siglas: ['CAAG'],
        frases: ['GAIRA'],
      ),
      CentroSena(
        'Centro de Logística y Promoción Ecoturística del Magdalena',
        siglas: ['CLPE'],
        frases: ['PROMOCION ECOTURISTICA'],
      ),
    ],
  ),
  RegionalSena(
    'Meta',
    claves: ['META'],
    departamento: 'META',
    centros: [
      CentroSena(
        'Centro Agroindustrial del Meta',
        siglas: ['CAM'],
        frases: ['AGROINDUSTRIAL DEL META'],
      ),
      CentroSena(
        'Centro de Industria y Servicios del Meta',
        siglas: ['CISM'],
        frases: ['INDUSTRIA Y SERVICIOS DEL META'],
      ),
    ],
  ),
  RegionalSena(
    'Nariño',
    claves: ['NARINO'],
    departamento: 'NARINO',
    centros: [
      CentroSena(
        'Centro Internacional de Producción Limpia Lope',
        frases: ['PRODUCCION LIMPIA'],
      ),
      CentroSena(
        'Centro Agroindustrial y Pesquero de la Costa Pacífica',
        siglas: ['CAPCP'],
        frases: ['COSTA PACIFICA'],
      ),
      CentroSena(
        'Centro Sur Colombiano de Logística Internacional',
        frases: ['LOGISTICA INTERNACIONAL'],
      ),
    ],
  ),
  RegionalSena(
    'Norte de Santander',
    claves: ['NORTE DE SANTANDER'],
    departamento: 'NORTE DE SANTANDER',
    centros: [
      CentroSena(
        'Centro de la Industria, la Empresa y los Servicios',
        siglas: ['CIES', 'CRE'],
        frases: ['INDUSTRIA LA EMPRESA Y LOS SERVICIOS'],
      ),
      CentroSena(
        'Centro de Formación para el Desarrollo Rural y Minero',
        siglas: ['CEDRUM'],
        frases: ['DESARROLLO RURAL Y MINERO'],
      ),
    ],
  ),
  RegionalSena(
    'Putumayo',
    claves: ['PUTUMAYO'],
    departamento: 'PUTUMAYO',
    centros: [
      CentroSena(
        'Centro Agroforestal y Acuícola Arapaima',
        frases: ['ARAPAIMA'],
      ),
    ],
  ),
  RegionalSena(
    'Quindío',
    claves: ['QUINDIO'],
    departamento: 'QUINDIO',
    centros: [
      CentroSena('Centro Agroindustrial', frases: ['CENTRO AGROINDUSTRIAL']),
      CentroSena(
        'Centro para el Desarrollo Tecnológico de la Construcción y la Industria',
        siglas: ['CDTCI'],
        frases: ['CONSTRUCCION Y LA INDUSTRIA'],
      ),
      CentroSena(
        'Centro de Comercio y Turismo',
        frases: ['COMERCIO Y TURISMO'],
      ),
    ],
  ),
  RegionalSena(
    'Risaralda',
    claves: ['RISARALDA'],
    departamento: 'RISARALDA',
    centros: [
      CentroSena(
        'Centro de Atención Sector Agropecuario',
        frases: ['SECTOR AGROPECUARIO'],
      ),
      CentroSena(
        'Centro de Diseño e Innovación Tecnológica Industrial',
        frases: ['INNOVACION TECNOLOGICA INDUSTRIAL'],
      ),
      CentroSena(
        'Centro de Comercio y Servicios',
        frases: ['COMERCIO Y SERVICIOS'],
      ),
    ],
  ),
  RegionalSena(
    'San Andrés',
    claves: ['SAN ANDRES'],
    departamento: 'SAN ANDRES PROVIDENCIA Y SANTA CATALINA',
    centros: [
      CentroSena(
        'Centro de Formación Turística, Gente de Mar y Servicios',
        frases: ['GENTE DE MAR'],
      ),
    ],
  ),
  RegionalSena(
    'Santander',
    claves: ['SANTANDER'],
    departamento: 'SANTANDER',
    centros: [
      CentroSena(
        'Centro Agroturístico',
        siglas: ['CA'],
        frases: ['AGROTURISTICO'],
      ),
      CentroSena(
        'Centro Agroempresarial y Turístico de los Andes',
        siglas: ['CATA'],
        frases: ['TURISTICO DE LOS ANDES'],
      ),
      CentroSena(
        'Centro de Gestión Agroempresarial del Oriente',
        siglas: ['CGAO'],
        frases: ['AGROEMPRESARIAL DEL ORIENTE'],
      ),
      CentroSena(
        'Centro Industrial y del Desarrollo Tecnológico',
        siglas: ['CIDT'],
        frases: ['DESARROLLO TECNOLOGICO'],
      ),
      CentroSena(
        'Centro de Atención Sector Agropecuario',
        frases: ['SECTOR AGROPECUARIO'],
      ),
      CentroSena(
        'Centro Industrial del Diseño y la Manufactura',
        siglas: ['CIDM'],
        frases: ['DISENO Y LA MANUFACTURA'],
      ),
      CentroSena(
        'Centro de Servicios Empresariales y Turísticos',
        frases: ['SERVICIOS EMPRESARIALES Y TURISTICOS'],
      ),
      CentroSena(
        'Centro Industrial de Mantenimiento Integral',
        siglas: ['CIMI'],
        frases: ['MANTENIMIENTO INTEGRAL'],
      ),
    ],
  ),
  RegionalSena(
    'Sucre',
    claves: ['SUCRE'],
    departamento: 'SUCRE',
    centros: [
      CentroSena(
        'Centro de la Innovación, la Tecnología y los Servicios',
        frases: ['LA TECNOLOGIA Y LOS SERVICIOS'],
      ),
    ],
  ),
  RegionalSena(
    'Tolima',
    claves: ['TOLIMA'],
    departamento: 'TOLIMA',
    centros: [
      CentroSena(
        'Centro de Industria y Construcción',
        frases: ['INDUSTRIA Y CONSTRUCCION', 'INDUSTRIA'],
      ),
      CentroSena(
        'Centro Agropecuario La Granja',
        frases: ['CENTRO AGROPECUARIO', 'LA GRANJA'],
      ),
      CentroSena(
        'Centro de Comercio y Servicios',
        frases: ['COMERCIO Y SERVICIOS', 'CENTRO DE COMERCIO'],
      ),
    ],
  ),
  RegionalSena(
    'Valle',
    claves: ['VALLE'],
    departamento: 'VALLE DEL CAUCA',
    centros: [
      CentroSena(
        'Centro Agropecuario de Buga',
        siglas: ['CAB'],
        frases: ['AGROPECUARIO DE BUGA'],
      ),
      CentroSena(
        'Centro Latinoamericano de Especies Menores',
        siglas: ['CLEM'],
        frases: ['ESPECIES MENORES'],
      ),
      CentroSena(
        'Centro Náutico Pesquero de Buenaventura',
        siglas: ['CNPB'],
        frases: ['NAUTICO PESQUERO'],
      ),
      CentroSena(
        'Centro de Electricidad y Automatización Industrial',
        siglas: ['CEAI'],
        frases: ['ELECTRICIDAD Y AUTOMATIZACION'],
      ),
      CentroSena('Centro de la Construcción', frases: ['CONSTRUCCION']),
      CentroSena(
        'Centro de Diseño Tecnológico Industrial',
        siglas: ['CDTI'],
        frases: ['DISENO TECNOLOGICO INDUSTRIAL'],
      ),
      CentroSena(
        'Centro Nacional de Asistencia Técnica a la Industria',
        siglas: ['ASTIN'],
        frases: ['ASISTENCIA TECNICA A LA INDUSTRIA'],
      ),
      CentroSena(
        'Centro de Gestión Tecnológica de Servicios',
        siglas: ['CGTS'],
        frases: ['GESTION TECNOLOGICA DE SERVICIOS'],
      ),
      CentroSena(
        'Centro de Tecnologías Agroindustriales',
        siglas: ['CTA'],
        frases: ['TECNOLOGIAS AGROINDUSTRIALES'],
      ),
      CentroSena(
        'Centro de Biotecnología Industrial',
        siglas: ['CBI'],
        frases: ['BIOTECNOLOGIA INDUSTRIAL'],
      ),
    ],
  ),
  RegionalSena(
    'Vaupés',
    claves: ['VAUPES'],
    departamento: 'VAUPES',
    centros: [
      CentroSena(
        'Centro Agropecuario y de Servicios Ambientales Jiri-Jirimo',
        frases: ['SERVICIOS AMBIENTALES'],
      ),
    ],
  ),
  RegionalSena(
    'Vichada',
    claves: ['VICHADA'],
    departamento: 'VICHADA',
    centros: [
      CentroSena(
        'Centro de Producción y Transformación Agroindustrial de la Orinoquía',
        frases: ['TRANSFORMACION AGROINDUSTRIAL'],
      ),
    ],
  ),
];

/// Dónde queda una unidad de SECOP II dentro del SENA.
enum NivelSena {
  nacional,
  despachoRegional,
  centro,
  regionalSinDistinguir,
  otra,
}

class UbicacionSena {
  const UbicacionSena({required this.nivel, required this.nodo, this.regional});

  final NivelSena nivel;

  /// Regional (null en el nivel nacional).
  final RegionalSena? regional;

  /// Nombre del despacho, centro, dependencia nacional o unidad.
  final String nodo;
}

/// Ubica pares cuenta + unidad de SECOP II en la estructura del SENA.
class EstructuraSena {
  EstructuraSena._();

  static String normalizar(String t) {
    const tildes = {
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ñ': 'N',
      'À': 'A',
      'È': 'E',
      'Ì': 'I',
      'Ò': 'O',
      'Ù': 'U',
    };
    final s = t.toUpperCase().split('').map((c) => tildes[c] ?? c).join();
    return s
        .replaceAll(RegExp(r'[^A-Z0-9]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _contiene(String texto, String frase) =>
      ' $texto '.contains(' $frase ');

  /// Regional nombrada en el texto (la clave más larga gana: "NORTE DE
  /// SANTANDER" antes que "SANTANDER").
  static RegionalSena? _regionalEnTexto(String texto) {
    RegionalSena? mejor;
    var largo = 0;
    for (final r in regionalesSena) {
      for (final c in r.claves) {
        if (c.length > largo && _contiene(texto, c)) {
          mejor = r;
          largo = c.length;
        }
      }
    }
    return mejor;
  }

  static int _puntaje(CentroSena c, String texto) {
    var p = 0;
    for (final f in c.frases) {
      if (_contiene(texto, f)) p = p < f.length + 10 ? f.length + 10 : p;
    }
    for (final s in c.siglas) {
      if (_contiene(texto, s)) p = p < s.length + 5 ? s.length + 5 : p;
    }
    return p;
  }

  static CentroSena? _centroEn(Iterable<CentroSena> centros, String texto) {
    CentroSena? mejor;
    var max = 0;
    for (final c in centros) {
      final p = _puntaje(c, texto);
      if (p > max) {
        mejor = c;
        max = p;
      }
    }
    return mejor;
  }

  /// Centro que solo existe en una regional (para cuentas sin regional en el
  /// nombre, como "SENA HOTELERIA TURISMO Y ALIMENTOS").
  static (RegionalSena, CentroSena)? _centroUnico(String texto) {
    (RegionalSena, CentroSena)? mejor;
    var max = 0;
    for (final r in regionalesSena) {
      for (final c in r.centros) {
        // Solo frases: las siglas cortas se repiten entre regionales.
        for (final f in c.frases) {
          if (f.length >= 12 && _contiene(texto, f) && f.length > max) {
            final repetida = regionalesSena.any(
              (o) =>
                  o != r && o.centros.any((x) => x.frases.any((y) => y == f)),
            );
            if (!repetida) {
              mejor = (r, c);
              max = f.length;
            }
          }
        }
      }
    }
    return mejor;
  }

  static final RegExp _despacho = RegExp(
    r'\bDESPACHO\b|\bDIRECCION REGIONAL\b|\bDIRECCION\b$|^REGIONAL [A-Z ]+$|'
    r'\bGESTION CONTRACTUAL REGIONAL\b|\b441010\b|\bPROCESOS REGIONALES\b|'
    r'\bUNIDAD GENERAL REGIONAL\b|\bREGIONAL SANTANDER\b',
  );

  static final RegExp _nacional = RegExp(
    r'\bDIRECCION GENERAL\b|\bSECRETARIA GENERAL\b',
  );

  static UbicacionSena ubicar({
    required String cuenta,
    required String unidad,
    String departamento = '',
  }) {
    final c = normalizar(cuenta);
    final u = normalizar(unidad);
    var regional = _regionalEnTexto(c);

    if (regional == null && _nacional.hasMatch(c)) {
      for (final d in dependenciasNacionalesSena) {
        if (d.frases.any((f) => _contiene(u, f))) {
          return UbicacionSena(nivel: NivelSena.nacional, nodo: d.nombre);
        }
      }
      for (final d in dependenciasNacionalesSena) {
        if (d.frases.any((f) => _contiene(c, f))) {
          return UbicacionSena(nivel: NivelSena.nacional, nodo: d.nombre);
        }
      }
      return UbicacionSena(
        nivel: NivelSena.nacional,
        nodo: u.isEmpty ? 'Dirección General' : unidad.trim(),
      );
    }

    if (regional == null) {
      final unico = _centroUnico('$u $c');
      if (unico != null) {
        return UbicacionSena(
          nivel: NivelSena.centro,
          regional: unico.$1,
          nodo: unico.$2.nombre,
        );
      }
      final d = normalizar(departamento);
      for (final r in regionalesSena) {
        if (r.departamento == d) regional = r;
      }
      if (regional == null) {
        return UbicacionSena(nivel: NivelSena.otra, nodo: unidad.trim());
      }
    }

    // Unidad primero: una cuenta "intercentros" contrata para varios.
    final enUnidad = _centroEn(regional.centros, u);
    if (enUnidad != null) {
      return UbicacionSena(
        nivel: NivelSena.centro,
        regional: regional,
        nodo: enUnidad.nombre,
      );
    }
    if (_despacho.hasMatch(u)) {
      return UbicacionSena(
        nivel: NivelSena.despachoRegional,
        regional: regional,
        nodo: 'Despacho de la Dirección Regional',
      );
    }
    // "SENA REGIONAL VAUPES", "Contratación Regional Valle": la regional.
    final resto = u.replaceFirst(
      RegExp(r'^(SENA )?(CONTRATACION )?REGIONAL '),
      '',
    );
    if (resto != u && regional.claves.contains(resto)) {
      return UbicacionSena(
        nivel: NivelSena.despachoRegional,
        regional: regional,
        nodo: 'Despacho de la Dirección Regional',
      );
    }
    final enCuenta = _centroEn(regional.centros, c);
    if (enCuenta != null) {
      return UbicacionSena(
        nivel: NivelSena.centro,
        regional: regional,
        nodo: enCuenta.nombre,
      );
    }
    if (regional.centros.length == 1 && _contiene(u, 'CENTRO')) {
      return UbicacionSena(
        nivel: NivelSena.centro,
        regional: regional,
        nodo: regional.centros.single.nombre,
      );
    }
    return UbicacionSena(
      nivel: NivelSena.regionalSinDistinguir,
      regional: regional,
      nodo: regional.centros.length == 1
          ? 'Grupo de contratación de la regional (despacho y centro)'
          : 'Contratación sin despacho o centro identificado',
    );
  }
}
