import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/security_service.dart';

/// Base de datos estructurada de Colombia y conector dinámico de entidades SECOP II
/// para consultas de Orden Nacional, Departamental, Municipal y Corporaciones Autónomas.
class ColombiaSecopCatalog {
  ColombiaSecopCatalog._();

  static const List<String> ordenesEntidad = [
    'Nacional',
    'Departamental',
    'Municipal',
    'Corporación Autónoma',
  ];

  static const List<String> departamentos = [
    'Amazonas',
    'Antioquia',
    'Arauca',
    'Archipiélago de San Andrés, Providencia y Santa Catalina',
    'Atlántico',
    'Bogotá D.C.',
    'Bolívar',
    'Boyacá',
    'Caldas',
    'Caquetá',
    'Casanare',
    'Cauca',
    'Cesar',
    'Chocó',
    'Córdoba',
    'Cundinamarca',
    'Guainía',
    'Guaviare',
    'Huila',
    'La Guajira',
    'Magdalena',
    'Meta',
    'Nariño',
    'Norte de Santander',
    'Putumayo',
    'Quindío',
    'Risaralda',
    'Santander',
    'Sucre',
    'Tolima',
    'Valle del Cauca',
    'Vaupés',
    'Vichada',
  ];

  static const Map<String, List<String>> municipiosPorDepartamento = {
    'Amazonas': ['Leticia', 'Puerto Nariño'],
    'Antioquia': [
      'Medellín',
      'Bello',
      'Itagüí',
      'Envigado',
      'Rionegro',
      'Sabaneta',
      'Apartadó',
      'Turbo',
      'Caucasia',
      'La Estrella',
      'Caldas',
      'Copacabana',
      'Girardota',
      'Marinilla',
      'La Ceja',
      'El Carmen de Viboral',
      'Puerto Berrío',
      'Yarumal',
      'Santa Fe de Antioquia',
      'Andes',
      'Chigorodó',
      'Carepa',
      'Necoclí',
      'Guadalupe',
    ],
    'Arauca': [
      'Arauca',
      'Arauquita',
      'Saravena',
      'Tame',
      'Fortul',
      'Cravo Norte',
      'Puerto Rondón',
    ],
    'Archipiélago de San Andrés, Providencia y Santa Catalina': [
      'San Andrés',
      'Providencia',
    ],
    'Atlántico': [
      'Barranquilla',
      'Soledad',
      'Malambo',
      'Sabanalarga',
      'Puerto Colombia',
      'Galapa',
      'Baranoa',
      'Sabanagrande',
      'Santo Tomás',
      'Palmar de Varela',
      'Luruaco',
      'Repelón',
      'Campo de la Cruz',
      'Juan de Acosta',
      'Tubará',
    ],
    'Bogotá D.C.': ['Bogotá D.C.'],
    'Bolívar': [
      'Cartagena',
      'Magangué',
      'Turbaco',
      'El Carmen de Bolívar',
      'Arjona',
      'Mompós',
      'María La Baja',
      'Santa Rosa del Sur',
      'San Juan Nepomuceno',
      'Simití',
      'San Pablo',
      'Turbana',
      'Clemencia',
      'Mahates',
    ],
    'Boyacá': [
      'Tunja',
      'Duitama',
      'Sogamoso',
      'Chiquinquirá',
      'Puerto Boyacá',
      'Paipa',
      'Moniquirá',
      'Villa de Leyva',
      'Garagoa',
      'Guateque',
      'Soatá',
      'Samacá',
      'Nobsa',
      'Tibasosa',
    ],
    'Caldas': [
      'Manizales',
      'La Dorada',
      'Chinchiná',
      'Villamaría',
      'Riosucio',
      'Anserma',
      'Supía',
      'Aguadas',
      'Salamina',
      'Neira',
      'Viterbo',
    ],
    'Caquetá': [
      'Florencia',
      'San Vicente del Caguán',
      'Cartagena del Chairá',
      'Puerto Rico',
      'El Doncello',
      'El Paujil',
      'Belén de los Andaquíes',
    ],
    'Casanare': [
      'Yopal',
      'Aguazul',
      'Paz de Ariporo',
      'Villanueva',
      'Tauramena',
      'Monterrey',
      'Maní',
      'Trinidad',
      'Orocué',
    ],
    'Cauca': [
      'Popayán',
      'Santander de Quilichao',
      'El Tambo',
      'Puerto Tejada',
      'Patía',
      'Piendamó',
      'Miranda',
      'Corinto',
      'Guapi',
      'Silvia',
      'Bolívar',
    ],
    'Cesar': [
      'Valledupar',
      'Aguachica',
      'Agustín Codazzi',
      'La Jagua de Ibirico',
      'Bosconia',
      'La Paz',
      'Becerril',
      'Chiriguaná',
      'Curumaní',
      'El Copey',
      'El Paso',
      'San Alberto',
      'San Martín',
      'Pueblo Bello',
      'Chimichagua',
      'Astrea',
      'Pailitas',
      'Pelaya',
      'Manaure Balcón del Cesar',
      'San Diego',
      'Río de Oro',
      'Tamalameque',
      'Gamarra',
      'La Gloria',
      'González',
    ],
    'Chocó': [
      'Quibdó',
      'Istmina',
      'Tadó',
      'Condoto',
      'Acandí',
      'Bahía Solano',
      'Riosucio',
      'Nuquí',
      'El Carmen de Atrato',
    ],
    'Córdoba': [
      'Montería',
      'Lorica',
      'Sahagún',
      'Cereté',
      'Montelíbano',
      'Planeta Rica',
      'Tierralta',
      'Ciénaga de Oro',
      'Chinú',
      'Ayapel',
      'Puerto Libertador',
      'San Bernardo del Viento',
      'San Antero',
    ],
    'Cundinamarca': [
      'Soacha',
      'Chía',
      'Zipaquirá',
      'Facatativá',
      'Fusagasugá',
      'Girardot',
      'Mosquera',
      'Funza',
      'Madrid',
      'Cajicá',
      'Tocancipá',
      'Sopó',
      'La Calera',
      'Cota',
      'Tabio',
      'Tenjo',
      'Villeta',
      'Ubaté',
      'Pacho',
      'Chocontá',
    ],
    'Guainía': ['Inírida'],
    'Guaviare': [
      'San José del Guaviare',
      'Calamar',
      'El Retorno',
      'Miraflores',
    ],
    'Huila': [
      'Neiva',
      'Pitalito',
      'Garzón',
      'La Plata',
      'Campoalegre',
      'San Agustín',
      'Gigante',
      'Palermo',
      'Rivera',
      'Algeciras',
    ],
    'La Guajira': [
      'Riohacha',
      'Maicao',
      'Uribia',
      'San Juan del Cesar',
      'Fonseca',
      'Barrancas',
      'Albania',
      'Hatonuevo',
      'Manaure',
      'Villanueva',
      'Dibulla',
    ],
    'Magdalena': [
      'Santa Marta',
      'Ciénaga',
      'Zona Bananera',
      'Fundación',
      'El Banco',
      'Plato',
      'Aracataca',
      'Pivijay',
      'Pueblo Viejo',
      'Sitionuevo',
      'Santa Ana',
    ],
    'Meta': [
      'Villavicencio',
      'Acacías',
      'Granada',
      'Puerto López',
      'Puerto Gaitán',
      'Restrepo',
      'Cumaral',
      'Vista Hermosa',
      'San Martín',
      'La Macarena',
    ],
    'Nariño': [
      'Pasto',
      'Tumaco',
      'Ipiales',
      'Túquerres',
      'La Unión',
      'Samaniego',
      'Sandoná',
      'Barbacoas',
      'Cumbal',
      'Cumbitara',
    ],
    'Norte de Santander': [
      'Cúcuta',
      'Ocaña',
      'Villa del Rosario',
      'Los Patios',
      'Pamplona',
      'Tibú',
      'El Zulia',
      'Chinácota',
      'Ábrego',
      'Sardinata',
    ],
    'Putumayo': [
      'Mocoa',
      'Puerto Asís',
      'Orito',
      'Valle del Guamuez',
      'Sibundoy',
      'Villagarzón',
      'Puerto Guzmán',
    ],
    'Quindío': [
      'Armenia',
      'Calarcá',
      'La Tebaida',
      'Circasia',
      'Montenegro',
      'Quimbaya',
      'Salento',
      'Filandia',
    ],
    'Risaralda': [
      'Pereira',
      'Dosquebradas',
      'Santa Rosa de Cabal',
      'La Virginia',
      'Belén de Umbría',
      'Quinchía',
      'Marsella',
    ],
    'Santander': [
      'Bucaramanga',
      'Floridablanca',
      'Girón',
      'Piedecuesta',
      'Barrancabermeja',
      'San Gil',
      'Socorro',
      'Barbosa',
      'Vélez',
      'Cimitarra',
      'Málaga',
      'Sabana de Torres',
      'Rionegro',
      'Lebrija',
    ],
    'Sucre': [
      'Sincelejo',
      'Corozal',
      'San Marcos',
      'Tolú',
      'Sampués',
      'San Onofre',
      'Sincé',
      'Majagual',
      'Ovejas',
    ],
    'Tolima': [
      'Ibagué',
      'Espinal',
      'Melgar',
      'Chaparral',
      'Líbano',
      'Honda',
      'Mariquita',
      'Guamo',
      'Flandes',
      'Purificación',
      'Cajamarca',
    ],
    'Valle del Cauca': [
      'Cali',
      'Buenaventura',
      'Palmira',
      'Tuluá',
      'Yumbo',
      'Cartago',
      'Buga',
      'Jamundí',
      'Candelaria',
      'Florida',
      'Pradera',
      'Zarzal',
      'Roldanillo',
      'Sevilla',
      'Caicedonia',
    ],
    'Vaupés': ['Mitú', 'Carurú', 'Taraira'],
    'Vichada': [
      'Puerto Carreño',
      'La Primavera',
      'Santa Rosalía',
      'Cumaribo',
    ],
  };

  /// Catálogo de entidades de Orden Nacional
  static const List<String> entidadesOrdenNacional = [
    // Ministerios
    'MINISTERIO DEL INTERIOR',
    'MINISTERIO DE RELACIONES EXTERIORES',
    'MINISTERIO DE HACIENDA Y CRÉDITO PÚBLICO',
    'MINISTERIO DE JUSTICIA Y DEL DERECHO',
    'MINISTERIO DE DEFENSA NACIONAL',
    'MINISTERIO DE AGRICULTURA Y DESARROLLO RURAL',
    'MINISTERIO DE SALUD Y PROTECCIÓN SOCIAL',
    'MINISTERIO DEL TRABAJO',
    'MINISTERIO DE MINAS Y ENERGÍA',
    'MINISTERIO DE COMERCIO, INDUSTRIA Y TURISMO',
    'MINISTERIO DE EDUCACIÓN NACIONAL',
    'MINISTERIO DE AMBIENTE Y DESARROLLO SOSTENIBLE',
    'MINISTERIO DE VIVIENDA, CIUDAD Y TERRITORIO',
    'MINISTERIO DE TECNOLOGÍAS DE LA INFORMACIÓN Y LAS COMUNICACIONES',
    'MINISTERIO DE TRANSPORTE',
    'MINISTERIO DE LAS CULTURAS, LAS ARTES Y LOS SABERES',
    'MINISTERIO DEL DEPORTE',
    'MINISTERIO DE CIENCIA, TECNOLOGÍA E INNOVACIÓN',
    'MINISTERIO DE IGUALDAD Y EQUIDAD',
    // Departamentos Administrativos
    'DEPARTAMENTO NACIONAL DE PLANEACIÓN - DNP',
    'DEPARTAMENTO ADMINISTRATIVO NACIONAL DE ESTADÍSTICA - DANE',
    'DEPARTAMENTO ADMINISTRATIVO DE LA FUNCIÓN PÚBLICA - DAFP',
    'DEPARTAMENTO ADMINISTRATIVO DE LA PRESIDENCIA DE LA REPÚBLICA - DAPRE',
    'PROSPERIDAD SOCIAL - DPS',
    // Agencias, Institutos y Unidades Nacionales
    'SERVICIO NACIONAL DE APRENDIZAJE - SENA',
    'INSTITUTO COLOMBIANO DE BIENESTAR FAMILIAR - ICBF',
    'INSTITUTO NACIONAL DE VÍAS - INVIAS',
    'AGENCIA NACIONAL DE INFRAESTRUCTURA - ANI',
    'AGENCIA NACIONAL DE TIERRAS - ANT',
    'AGENCIA DE DESARROLLO RURAL - ADR',
    'AGENCIA DE RENOVACIÓN DEL TERRITORIO - ART',
    'AGENCIA NACIONAL DE MINERÍA - ANM',
    'AGENCIA NACIONAL DE HIDROCARBUROS - ANH',
    'AGENCIA NACIONAL DE SEGURIDAD VIAL',
    'AGENCIA NACIONAL DE DEFENSA JURÍDICA DEL ESTADO',
    'AGENCIA LOGÍSTICA DE LAS FUERZAS MILITARES',
    'INSTITUTO GEOGRÁFICO AGUSTÍN CODAZZI - IGAC',
    'INSTITUTO COLOMBIANO AGROPECUARIO - ICA',
    'INSTITUTO NACIONAL DE VIGILANCIA DE MEDICAMENTOS Y ALIMENTOS - INVIMA',
    'INSTITUTO NACIONAL DE SALUD - INS',
    'INSTITUTO DE HIDROLOGÍA, METEOROLOGÍA Y ESTUDIOS AMBIENTALES - IDEAM',
    'AUTORIDAD NACIONAL DE LICENCIAS AMBIENTALES - ANLA',
    'PARQUES NACIONALES NATURALES DE COLOMBIA',
    'DIRECCIÓN DE IMPUESTOS Y ADUANAS NACIONALES - DIAN',
    'UNIDAD DE GESTIÓN PENSIONAL Y PARAFISCALES - UGPP',
    'UNIDAD NACIONAL DE PROTECCIÓN - UNP',
    'UNIDAD PARA LA ATENCIÓN Y REPARACIÓN INTEGRAL A LAS VÍCTIMAS - UARIV',
    'UNIDAD DE RESTITUCIÓN DE TIERRAS',
    'UNIDAD NACIONAL PARA LA GESTIÓN DEL RIESGO DE DESASTRES - UNGRD',
    'UNIDAD ADMINISTRATIVA ESPECIAL DE MIGRACIÓN COLOMBIA',
    'AERONÁUTICA CIVIL - AEROCIVIL',
    'ICETEX',
    'ICFES',
    'COLPENSIONES',
    'ENTERRITORIO',
    'INSTITUTO NACIONAL PENITENCIARIO Y CARCELARIO - INPEC',
    'USPEC - UNIDAD DE SERVICIOS PENITENCIARIOS Y CARCELARIOS',
    // Superintendencias
    'SUPERINTENDENCIA DE INDUSTRIA Y COMERCIO',
    'SUPERINTENDENCIA DE SOCIEDADES',
    'SUPERINTENDENCIA FINANCIERA DE COLOMBIA',
    'SUPERINTENDENCIA NACIONAL DE SALUD',
    'SUPERINTENDENCIA DE SERVICIOS PÚBLICOS DOMICILIARIOS',
    'SUPERINTENDENCIA DE NOTARIADO Y REGISTRO',
    'SUPERINTENDENCIA DE TRANSPORTE',
    'SUPERINTENDENCIA DE VIGILANCIA Y SEGURIDAD PRIVADA',
    'SUPERINTENDENCIA DEL SUBSIDIO FAMILIAR',
    'SUPERINTENDENCIA DE LA ECONOMÍA SOLIDARIA',
    // Órganos de Control, Rama Judicial y Electoral
    'RAMA JUDICIAL - DIRECCIÓN EJECUTIVA DE ADMINISTRACIÓN JUDICIAL',
    'FISCALÍA GENERAL DE LA NACIÓN',
    'PROCURADURÍA GENERAL DE LA NACIÓN',
    'CONTRALORÍA GENERAL DE LA REPÚBLICA',
    'DEFENSORÍA DEL PUEBLO',
    'REGISTRADURÍA NACIONAL DEL ESTADO CIVIL',
    'SENADO DE LA REPÚBLICA',
    'CÁMARA DE REPRESENTANTES',
    'AUDITORÍA GENERAL DE LA REPÚBLICA',
    // Fuerza Pública
    'POLICÍA NACIONAL',
    'EJÉRCITO NACIONAL',
    'ARMADA NACIONAL',
    'FUERZA AEROESPACIAL COLOMBIANA',
    'HOSPITAL MILITAR CENTRAL',
    'DIRECCIÓN DE SANIDAD POLICÍA NACIONAL',
  ];

  /// Catálogo de entidades de Orden Departamental (Gobernaciones, Asambleas, Contralorías, Hospitales y Universidades)
  static const List<String> entidadesOrdenDepartamental = [
    'GOBERNACIÓN DEL DEPARTAMENTO DE ANTIOQUIA',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL ATLÁNTICO',
    'GOBERNACIÓN DEL DEPARTAMENTO DE BOLÍVAR',
    'GOBERNACIÓN DEL DEPARTAMENTO DE BOYACÁ',
    'GOBERNACIÓN DEL DEPARTAMENTO DE CALDAS',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL CAQUETÁ',
    'GOBERNACIÓN DEL DEPARTAMENTO DE CASANARE',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL CAUCA',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL CESAR',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL CHOCÓ',
    'GOBERNACIÓN DEL DEPARTAMENTO DE CÓRDOBA',
    'GOBERNACIÓN DE CUNDINAMARCA',
    'GOBERNACIÓN DEL DEPARTAMENTO DE LA GUAJIRA',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL HUILA',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL MAGDALENA',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL META',
    'GOBERNACIÓN DEL DEPARTAMENTO DE NARIÑO',
    'GOBERNACIÓN DEL DEPARTAMENTO DE NORTE DE SANTANDER',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL PUTUMAYO',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL QUINDÍO',
    'GOBERNACIÓN DEL DEPARTAMENTO DE RISARALDA',
    'GOBERNACIÓN DEL DEPARTAMENTO DE SANTANDER',
    'GOBERNACIÓN DEL DEPARTAMENTO DE SUCRE',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL TOLIMA',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL VALLE DEL CAUCA',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL AMAZONAS',
    'GOBERNACIÓN DEL DEPARTAMENTO DE ARAUCA',
    'GOBERNACIÓN DEL DEPARTAMENTO DE GUAINÍA',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL GUAVIARE',
    'GOBERNACIÓN DE SAN ANDRÉS, PROVIDENCIA Y SANTA CATALINA',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL VAUPÉS',
    'GOBERNACIÓN DEL DEPARTAMENTO DEL VICHADA',
    'UNIVERSIDAD DE ANTIOQUIA',
    'UNIVERSIDAD DEL ATLÁNTICO',
    'UNIVERSIDAD DE CARTAGENA',
    'UNIVERSIDAD POPULAR DEL CESAR',
    'UNIVERSIDAD DEL VALLE',
    'UNIVERSIDAD INDUSTRIAL DE SANTANDER - UIS',
    'UNIVERSIDAD DEL MAGDALENA',
    'UNIVERSIDAD DE CÓRDOBA',
    'UNIVERSIDAD DE SUCRE',
    'UNIVERSIDAD DE LA GUAJIRA',
    'UNIVERSIDAD DE PAMPLONA',
    'UNIVERSIDAD DEL CAUCA',
    'UNIVERSIDAD DE NARIÑO',
    'UNIVERSIDAD DEL TOLIMA',
    'UNIVERSIDAD SURCOLOMBIANA',
    'UNIVERSIDAD DE CALDAS',
    'UNIVERSIDAD TECNOLÓGICA DE PEREIRA',
    'UNIVERSIDAD DEL QUINDÍO',
    'UNIVERSIDAD DE CUNDINAMARCA',
    'UNIVERSIDAD DE LOS LLANOS',
  ];

  /// Catálogo de Corporaciones Autónomas Regionales (CAR)
  static const List<String> entidadesCorporacionesAutonomas = [
    'CAR - CORPORACIÓN AUTÓNOMA REGIONAL DE CUNDINAMARCA',
    'CORANTIOQUIA',
    'CORNARE',
    'CORPOURABA',
    'CRA - CORPORACIÓN AUTÓNOMA REGIONAL DEL ATLÁNTICO',
    'CARDIQUE - CORPORACIÓN AUTÓNOMA REGIONAL DEL CANAL DEL DIQUE',
    'CSB - CORPORACIÓN AUTÓNOMA REGIONAL DEL SUR DE BOLÍVAR',
    'CORPOBOYACA',
    'CORPOCALDAS',
    'CORPOCESAR - CORPORACIÓN AUTÓNOMA REGIONAL DEL CESAR',
    'CODECHOCO',
    'CVS - CORPORACIÓN AUTÓNOMA REGIONAL DE LOS VALLES DEL SINÚ Y DEL SAN JORGE',
    'CORPOGUAJIRA',
    'CAM - CORPORACIÓN AUTÓNOMA REGIONAL DEL ALTO MAGDALENA',
    'CORPAMAG - CORPORACIÓN AUTÓNOMA REGIONAL DEL MAGDALENA',
    'CORMACARENA',
    'CORPONARIÑO',
    'CORPONOR',
    'CRQ - CORPORACIÓN AUTÓNOMA REGIONAL DEL QUINDÍO',
    'CARDER - CORPORACIÓN AUTÓNOMA REGIONAL DE RISARALDA',
    'CAS - CORPORACIÓN AUTÓNOMA REGIONAL DE SANTANDER',
    'CDMB - CORPORACIÓN AUTÓNOMA REGIONAL PARA LA DEFENSA DE LA MESETA DE BUCARAMANGA',
    'CARSUCRE',
    'CORTOLIMA',
    'CVC - CORPORACIÓN AUTÓNOMA REGIONAL DEL VALLE DEL CAUCA',
    'CORPORINOQUIA',
    'CORPOAMAZONIA',
    'CDA - CORPORACIÓN PARA EL DESARROLLO SOSTENIBLE DEL NORTE Y EL ORIENTE AMAZÓNICO',
    'CORALINA',
  ];

  /// Genera dinámicamente las entidades territoriales sugeridas según orden, departamento y municipio
  static List<String> obtenerEntidadesSugeridas({
    String? orden,
    String? departamento,
    String? municipio,
  }) {
    final result = <String>[];

    final bool soloNacional = orden == 'Nacional';
    final bool soloDepartamental = orden == 'Departamental';
    final bool soloMunicipal = orden == 'Municipal';
    final bool soloCar = orden == 'Corporación Autónoma';

    if (soloNacional) {
      return List<String>.from(entidadesOrdenNacional);
    }
    if (soloCar) {
      return List<String>.from(entidadesCorporacionesAutonomas);
    }

    final cleanDepto = (departamento ?? '').trim();
    final cleanMuni = (municipio ?? '').trim();

    if (cleanMuni.isNotEmpty) {
      if (cleanMuni == 'Bogotá D.C.') {
        result.addAll([
          'ALCALDÍA MAYOR DE BOGOTÁ',
          'SECRETARÍA DISTRITAL DE SALUD',
          'SECRETARÍA DE EDUCACIÓN DEL DISTRITO',
          'SECRETARÍA DISTRITAL DE MOVILIDAD',
          'SECRETARÍA DISTRITAL DE INTEGRACIÓN SOCIAL',
          'INSTITUTO DE DESARROLLO URBANO - IDU',
          'IDRD - INSTITUTO DISTRITAL DE RECREACIÓN Y DEPORTE',
          'IDARTES',
          'CONCEJO DE BOGOTÁ',
          'CONTRALORÍA DE BOGOTÁ',
          'PERSONERÍA DE BOGOTÁ',
          'EMPRESA DE ACUEDUCTO Y ALCANTARILLADO DE BOGOTÁ',
          'TRANSMILENIO S.A.',
        ]);
      } else {
        final mUp = cleanMuni.toUpperCase();
        result.addAll([
          'ALCALDÍA MUNICIPAL DE $mUp',
          'MUNICIPIO DE $mUp',
          'CONCEJO MUNICIPAL DE $mUp',
          'PERSONERÍA MUNICIPAL DE $mUp',
          'CONTRALORÍA MUNICIPAL DE $mUp',
          'E.S.E. HOSPITAL DE $mUp',
          'EMPRESA DE SERVICIOS PÚBLICOS DE $mUp',
          'INSTITUTO DE DEPORTE Y RECREACIÓN DE $mUp',
        ]);
        if (cleanMuni == 'Valledupar') {
          result.addAll([
            'HOSPITAL EDUARDO ARREDONDO DAZA',
            'HOSPITAL ROSARIO PUMAREJO DE LÓPEZ',
            'INDUPAL',
            'FONVISOCIAL',
            'EMDUPAR S.A. E.S.P.',
            'ÁREA METROPOLITANA DE VALLEDUPAR',
          ]);
        } else if (cleanMuni == 'Medellín') {
          result.addAll([
            'ALCALDÍA DE MEDELLÍN',
            'INSTITUCIÓN UNIVERSITARIA ITM',
            'INSTITUCIÓN UNIVERSITARIA PASCUAL BRAVO',
            'INDER MEDELLÍN',
            'ISVIMED',
            'METROPARQUES',
          ]);
        } else if (cleanMuni == 'Cali') {
          result.addAll([
            'ALCALDÍA DE SANTIAGO DE CALI',
            'DAGMA CALI',
            'EMCALI EICE ESP',
            'METRO CALI S.A.',
          ]);
        } else if (cleanMuni == 'Barranquilla') {
          result.addAll([
            'ALCALDÍA DISTRITAL DE BARRANQUILLA',
            'ADI - AGENCIA DISTRITAL DE INFRAESTRUCTURA',
            'TRANSMETRO S.A.S.',
          ]);
        } else if (cleanMuni == 'Cartagena') {
          result.addAll([
            'ALCALDÍA MAYOR DE CARTAGENA DE INDIAS',
            'IDER CARTAGENA',
            'TRANSCARIBE S.A.',
            'DADIS CARTAGENA',
          ]);
        } else if (cleanMuni == 'Bucaramanga') {
          result.addAll([
            'ALCALDÍA DE BUCARAMANGA',
            'INDERBU',
            'IMEBU',
            'DIRECCIÓN DE TRÁNSITO DE BUCARAMANGA',
          ]);
        }
      }
    }

    if (cleanDepto.isNotEmpty && !soloMunicipal) {
      final dUp = cleanDepto.toUpperCase();
      result.addAll([
        'GOBERNACIÓN DEL DEPARTAMENTO DE $dUp',
        'GOBERNACIÓN DE $dUp',
        'ASAMBLEA DEPARTAMENTAL DE $dUp',
        'CONTRALORÍA DEPARTAMENTAL DE $dUp',
        'SENA REGIONAL $dUp',
        'ICBF REGIONAL $dUp',
        'DEPARTAMENTO DE POLICÍA $dUp',
      ]);
    }

    if (soloDepartamental && result.isEmpty) {
      return List<String>.from(entidadesOrdenDepartamental);
    }

    if (result.isEmpty) {
      result.addAll(entidadesOrdenNacional.take(30));
      result.addAll(entidadesOrdenDepartamental.take(25));
      result.addAll(entidadesCorporacionesAutonomas.take(15));
    }

    return result.toSet().toList();
  }

  /// Consulta en vivo a la API de SECOP II (datos.gov.co) para obtener las entidades reales
  /// registradas según el orden, departamento, municipio o texto escrito por el usuario.
  static Future<List<String>> consultarEntidadesRealesSecop({
    String? orden,
    String? departamento,
    String? municipio,
    String? textoBusqueda,
  }) async {
    try {
      final whereClauses = <String>['nombre_entidad IS NOT NULL'];

      if (orden != null && orden.trim().isNotEmpty) {
        if (orden == 'Nacional') {
          whereClauses.add("orden = 'Nacional'");
        } else if (orden == 'Corporación Autónoma') {
          whereClauses.add("upper(orden) LIKE '%CORPORAC%'");
        } else if (orden == 'Departamental') {
          whereClauses.add(
            "orden = 'Territorial' AND (upper(nombre_entidad) LIKE '%GOBERNAC%' OR upper(nombre_entidad) LIKE '%DEPARTAMENT%' OR upper(nombre_entidad) LIKE '%ASAMBLEA%' OR upper(nombre_entidad) LIKE '%UNIVERSIDAD%')",
          );
        } else if (orden == 'Municipal') {
          whereClauses.add("orden = 'Territorial'");
        }
      }

      if (departamento != null && departamento.trim().isNotEmpty) {
        final safeDep = SecurityService.sanitizeSoqlToken(
          departamento,
          maxLength: 60,
        );
        final dNorm = _normalizar(safeDep);
        final dOrig = safeDep.toUpperCase();
        if (dNorm == 'BOGOTA D.C.') {
          whereClauses.add(
            "(upper(departamento) LIKE '%BOGOT%' OR upper(ciudad) LIKE '%BOGOT%')",
          );
        } else if (dNorm.contains('SAN ANDRES')) {
          whereClauses.add("upper(departamento) LIKE '%SAN ANDR%'");
        } else if (dNorm.isNotEmpty && dNorm != dOrig) {
          whereClauses.add(
            "(upper(departamento) LIKE '%$dNorm%' OR upper(departamento) LIKE '%$dOrig%')",
          );
        } else if (dNorm.isNotEmpty) {
          whereClauses.add("upper(departamento) LIKE '%$dNorm%'");
        }
      }

      if (municipio != null && municipio.trim().isNotEmpty) {
        final safeMun = SecurityService.sanitizeSoqlToken(
          municipio,
          maxLength: 60,
        );
        final mNorm = _normalizar(safeMun);
        final mOrig = safeMun.toUpperCase();
        if (mNorm == 'BOGOTA D.C.') {
          whereClauses.add("upper(ciudad) LIKE '%BOGOT%'");
        } else if (mNorm.isNotEmpty && mNorm != mOrig) {
          whereClauses.add(
            "(upper(ciudad) LIKE '%$mNorm%' OR upper(ciudad) LIKE '%$mOrig%' OR upper(nombre_entidad) LIKE '%$mNorm%')",
          );
        } else if (mNorm.isNotEmpty) {
          whereClauses.add(
            "(upper(ciudad) LIKE '%$mNorm%' OR upper(nombre_entidad) LIKE '%$mNorm%')",
          );
        }
      }

      if (textoBusqueda != null && textoBusqueda.trim().isNotEmpty) {
        final tokens = SecurityService.sanitizeSoqlToken(
              textoBusqueda,
              maxLength: 100,
            )
            .split(RegExp(r'\s+'))
            .map((w) => SecurityService.sanitizeSoqlToken(w, maxLength: 40))
            .where((w) => w.length >= 2)
            .take(8)
            .toList();
        for (final t in tokens) {
          final tNorm = _normalizar(t);
          final tOrig = t.toUpperCase();
          if (tNorm != tOrig) {
            whereClauses.add(
              "(upper(nombre_entidad) LIKE '%$tNorm%' OR upper(nombre_entidad) LIKE '%$tOrig%')",
            );
          } else {
            whereClauses.add("upper(nombre_entidad) LIKE '%$tNorm%'");
          }
        }
      }

      final whereParam = Uri.encodeComponent(whereClauses.join(' AND '));
      final url = Uri.parse(
        'https://www.datos.gov.co/resource/jbjy-vk9h.json?\$select=nombre_entidad,count(*)%20as%20total&\$group=nombre_entidad&\$order=total%20DESC&\$limit=80&\$where=$whereParam',
      );

      final response =
          await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final names = <String>[];
      for (final item in data) {
        if (item is Map && item['nombre_entidad'] != null) {
          final name = item['nombre_entidad'].toString().trim();
          if (name.isNotEmpty) names.add(name);
        }
      }
      return names;
    } catch (_) {
      return [];
    }
  }

  static String _normalizar(String texto) {
    return texto
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U');
  }
}

