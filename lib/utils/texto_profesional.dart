/// Presenta con escritura normal los textos que SECOP II publica en
/// mayúsculas sostenidas y sin tildes: "ADQUISICION DE DOTACION PARA LOS
/// APRENDICES DEL SENA" → "Adquisición de dotación para los aprendices del
/// SENA". Solo corrige tildes seguras (terminaciones -ción, -sión, -lógico y
/// un vocabulario frecuente); las siglas conocidas se conservan.
class TextoProfesional {
  TextoProfesional._();

  static const Set<String> _siglas = {
    'SENA',
    'ICBF',
    'INPEC',
    'DIAN',
    'SECOP',
    'PAA',
    'SST',
    'TIC',
    'TICS',
    'RUP',
    'UNSPSC',
    'PTAR',
    'PTAP',
    'NIT',
    'CDP',
    'RP',
    'EPS',
    'ESE',
    'IPS',
    'SAS',
    'ESP',
    'EICE',
    'AMV',
    'CEFIT',
    'SIIF',
    'SGR',
    'SGP',
    'PGN',
    'DT',
    'DC',
    'II',
    'III',
    'IV',
    'VI',
    'VII',
    'VIII',
    'IX',
    'XI',
    'XII',
    'UPRES',
    'CBC',
    'CAE',
    'CIGEC',
    'COMM',
    'CTPI',
    'CDA',
    'CBA',
    'CSF',
    'CGI',
    'CEET',
    'CTCM',
    'CTT',
    'CGA',
    'CIES',
    'CEDRUM',
    'CTMA',
    'CTGI',
    'CDHC',
    'CTM',
    'CDMC',
    'CESGE',
    'CFMA',
    'CIAA',
    'CTAPT',
    'CTPGA',
    'CTMAE',
    'CTTAOA',
    'ASTIN',
    'CEAI',
    'CDTI',
    'CGTS',
    'CNPB',
    'CLEM',
    'CAB',
    'CBI',
    'CTA',
    'CISM',
    'CAM',
    'CAAG',
    'CLPE',
    'CAPCP',
    'CDTCI',
    'CIMI',
    'CIDM',
    'CIDT',
    'CGAO',
    'CATA',
    'CADP',
    'CDATH',
    'CGDSS',
    'CEFA',
    'CPIC',
    'CFC',
    'CPA',
    'CIMM',
    'CEGAFE',
    'CINAFLUP',
    'CPIP',
    'CNCA',
    'CCYS',
    'UAE',
    'ARL',
    'SOAT',
    'GPS',
    'CCTV',
    'UPS',
    'LED',
    'IPC',
    'SMMLV',
    'IVA',
    'ICA',
    'POT',
    'PDT',
    'PAE',
    'JAC',
    'ONG',
    'APP',
    'BPIN',
    'PQRS',
    'PQRSD',
    'SIG',
    'MIPG',
    'GEL',
  };

  /// Palabras frecuentes con tilde (en mayúsculas sin tilde → correcta).
  static const Map<String, String> _tildes = {
    'POLICIA': 'policía',
    'BOGOTA': 'Bogotá',
    'CORDOBA': 'Córdoba',
    'BOLIVAR': 'Bolívar',
    'CHOCO': 'Chocó',
    'QUINDIO': 'Quindío',
    'CAQUETA': 'Caquetá',
    'GUAINIA': 'Guainía',
    'VAUPES': 'Vaupés',
    'NARINO': 'Nariño',
    'ATLANTICO': 'Atlántico',
    'BOYACA': 'Boyacá',
    'MONTERIA': 'Montería',
    'POPAYAN': 'Popayán',
    'IBAGUE': 'Ibagué',
    'MEDELLIN': 'Medellín',
    'CUCUTA': 'Cúcuta',
    'ANDRES': 'Andrés',
    'URABA': 'Urabá',
    'ITAGUI': 'Itagüí',
    'PUBLICA': 'pública',
    'PUBLICO': 'público',
    'PUBLICOS': 'públicos',
    'PUBLICAS': 'públicas',
    'TECNICO': 'técnico',
    'TECNICA': 'técnica',
    'TECNICOS': 'técnicos',
    'TECNICAS': 'técnicas',
    'TECNOLOGIA': 'tecnología',
    'TECNOLOGIAS': 'tecnologías',
    'ECONOMICO': 'económico',
    'ECONOMICA': 'económica',
    'JURIDICA': 'jurídica',
    'JURIDICO': 'jurídico',
    'ELECTRICO': 'eléctrico',
    'ELECTRICA': 'eléctrica',
    'ELECTRICAS': 'eléctricas',
    'ELECTRICOS': 'eléctricos',
    'ELECTRONICO': 'electrónico',
    'ELECTRONICA': 'electrónica',
    'ENERGIA': 'energía',
    'ACADEMICO': 'académico',
    'ACADEMICA': 'académica',
    'MEDICO': 'médico',
    'MEDICOS': 'médicos',
    'MEDICA': 'médica',
    'QUIMICO': 'químico',
    'QUIMICOS': 'químicos',
    'BASICO': 'básico',
    'BASICA': 'básica',
    'FISICO': 'físico',
    'FISICA': 'física',
    'VEHICULO': 'vehículo',
    'VEHICULOS': 'vehículos',
    'AREA': 'área',
    'AREAS': 'áreas',
    'NUMERO': 'número',
    'ALCALDIA': 'alcaldía',
    'SECRETARIA': 'secretaría',
    'CONTRALORIA': 'contraloría',
    'PERSONERIA': 'personería',
    'PROCURADURIA': 'procuraduría',
    'CAFETERIA': 'cafetería',
    'PAPELERIA': 'papelería',
    'FERRETERIA': 'ferretería',
    'AUDITORIA': 'auditoría',
    'CONSULTORIA': 'consultoría',
    'INTERVENTORIA': 'interventoría',
    'ASESORIA': 'asesoría',
    'COMPANIA': 'compañía',
    'GARANTIA': 'garantía',
    'INGENIERIA': 'ingeniería',
    'CUANTIA': 'cuantía',
    'TRANSITO': 'tránsito',
    'CREDITO': 'crédito',
    'DEPOSITO': 'depósito',
    'ANALISIS': 'análisis',
    'DIAGNOSTICO': 'diagnóstico',
    'ESTADISTICA': 'estadística',
    'PRACTICA': 'práctica',
    'PRACTICAS': 'prácticas',
    'UNICO': 'único',
    'UNICA': 'única',
    'SEGUN': 'según',
    'TRAVES': 'través',
    'ADEMAS': 'además',
    'MAQUINA': 'máquina',
    'MAQUINAS': 'máquinas',
    'METODOS': 'métodos',
    'TELEFONICO': 'telefónico',
    'TELEFONIA': 'telefonía',
    'CAMARAS': 'cámaras',
    'AEREO': 'aéreo',
    'AEREA': 'aérea',
    'TERMINO': 'término',
    'TERMINOS': 'términos',
    'CATALOGO': 'catálogo',
    'LOGISTICA': 'logística',
    'LOGISTICO': 'logístico',
    'BIOLOGICO': 'biológico',
    'HIDRAULICO': 'hidráulico',
    'HIDRAULICA': 'hidráulica',
    'MECANICO': 'mecánico',
    'MECANICA': 'mecánica',
    'DIDACTICO': 'didáctico',
    'DIDACTICOS': 'didácticos',
    'LUDICO': 'lúdico',
    'LUDICAS': 'lúdicas',
    'PEDAGOGICO': 'pedagógico',
    'PEDAGOGICA': 'pedagógica',
    'METODOLOGICO': 'metodológico',
    'ODONTOLOGICO': 'odontológico',
    'PSICOLOGICO': 'psicológico',
    'TECNOLOGICO': 'tecnológico',
    'TECNOLOGICA': 'tecnológica',
    'ESTRATEGICO': 'estratégico',
    'ESTRATEGICA': 'estratégica',
    'PERIODICO': 'periódico',
    'MANTENIMIENTO': 'mantenimiento',
    'DIRECCIONAL': 'direccional',
    'ACUICOLA': 'acuícola',
    'TURISTICO': 'turístico',
    'TURISTICA': 'turística',
    'CARCEL': 'cárcel',
    'CARCELARIO': 'carcelario',
    'PENITENCIARIA': 'penitenciaría',
    'GESTION': 'gestión',
    'REGION': 'región',
    'UNION': 'unión',
    'CAMION': 'camión',
    'MINTRABAJO': 'MinTrabajo',
    'COLOMBIA': 'Colombia',
    'ANTIOQUIA': 'Antioquia',
    'ARAUCA': 'Arauca',
    'CALDAS': 'Caldas',
    'CASANARE': 'Casanare',
    'CAUCA': 'Cauca',
    'CESAR': 'Cesar',
    'CUNDINAMARCA': 'Cundinamarca',
    'GUAVIARE': 'Guaviare',
    'HUILA': 'Huila',
    'GUAJIRA': 'Guajira',
    'MAGDALENA': 'Magdalena',
    'PUTUMAYO': 'Putumayo',
    'RISARALDA': 'Risaralda',
    'SANTANDER': 'Santander',
    'SUCRE': 'Sucre',
    'TOLIMA': 'Tolima',
    'VICHADA': 'Vichada',
    'AMAZONAS': 'Amazonas',
    'VALLEDUPAR': 'Valledupar',
    'AGUACHICA': 'Aguachica',
    'BARRANQUILLA': 'Barranquilla',
    'CARTAGENA': 'Cartagena',
    'BUCARAMANGA': 'Bucaramanga',
    'PEREIRA': 'Pereira',
    'MANIZALES': 'Manizales',
    'NEIVA': 'Neiva',
    'VILLAVICENCIO': 'Villavicencio',
    'TUNJA': 'Tunja',
    'SINCELEJO': 'Sincelejo',
    'RIOHACHA': 'Riohacha',
    'YOPAL': 'Yopal',
    'QUIBDO': 'Quibdó',
    'LETICIA': 'Leticia',
    'MOCOA': 'Mocoa',
    'BUENAVENTURA': 'Buenaventura',
    'SOACHA': 'Soacha',
    'MINIMA': 'mínima',
    'MINIMO': 'mínimo',
    'MERITOS': 'méritos',
    'REGIMEN': 'régimen',
    'INTERES': 'interés',
    'AEREOS': 'aéreos',
    'AEREAS': 'aéreas',
    'CLINICO': 'clínico',
    'CLINICA': 'clínica',
    'AGRICOLA': 'agrícola',
    'MECATRONICA': 'mecatrónica',
    'NUCLEOS': 'núcleos',
    'DEMAS': 'demás',
    'ORGANICO': 'orgánico',
    'BIOMEDICO': 'biomédico',
    'QUIRURGICO': 'quirúrgico',
    'OPTICO': 'óptico',
    'TECNOPARQUE': 'Tecnoparque',
    'PAIS': 'país',
    'DIA': 'día',
    'DIAS': 'días',
    'ANO': 'año',
    'ANOS': 'años',
  };

  static const Set<String> _conectores = {
    'de',
    'del',
    'la',
    'las',
    'los',
    'el',
    'y',
    'e',
    'o',
    'u',
    'en',
    'a',
    'al',
    'para',
    'por',
    'con',
    'sin',
    'su',
    'sus',
  };

  static String _sinTildes(String w) {
    const t = {
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ñ': 'N',
    };
    return w.split('').map((c) => t[c] ?? c).join();
  }

  /// true si el texto está casi todo en mayúsculas.
  static bool enMayusculas(String t) {
    final letras = t.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑáéíóúñ]'), '');
    if (letras.length < 4) return false;
    final mayus = letras.replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÑ]'), '').length;
    return mayus / letras.length > 0.7;
  }

  static String _palabra(String w) {
    if (w.isEmpty) return w;
    final base = _sinTildes(w.toUpperCase());
    if (_siglas.contains(base)) return base;
    if (RegExp(r'\d').hasMatch(w)) return w;
    // Siglas con puntos ("S.A.", "E.S.P."): en mayúsculas.
    if (w.contains('.') &&
        w.split('.').every((p) => p.isNotEmpty && p.length <= 3)) {
      return w.toUpperCase();
    }
    // Palabra sin vocales (siglas como "PSP", "DTC"): se conserva.
    if (w.length >= 2 &&
        w.length <= 5 &&
        !RegExp(r'[AEIOUYÁÉÍÓÚ]').hasMatch(w.toUpperCase())) {
      return w.toUpperCase();
    }
    final conocida = _tildes[base];
    if (conocida != null) return conocida;
    var l = w.toLowerCase();
    // Tildes seguras por terminación.
    if (base.endsWith('CION') && !w.contains('Ó')) {
      l = '${l.substring(0, l.length - 4)}ción';
    } else if (base.endsWith('SION') && base.length > 5 && !w.contains('Ó')) {
      l = '${l.substring(0, l.length - 4)}sión';
    } else if (RegExp(r'LOGIC[OA]S?$').hasMatch(base) && !w.contains('Ó')) {
      l = l.replaceFirst(RegExp(r'logic(?=[oa]s?$)'), 'lógic');
    }
    return l;
  }

  static String _cambiar(String t, String Function(String w, int i) f) {
    var i = 0;
    return t.replaceAllMapped(
      RegExp(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9]+(?:['.][A-Za-z]+)*"),
      (m) => f(m.group(0)!, i++),
    );
  }

  static String _limpiar(String t) => t
      .replaceFirst(RegExp(r'^[0-9_\-]+\s+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+([;,.:])'), r'$1')
      .trim();

  /// Texto largo (objeto de un contrato o de una compra) en oración.
  static String oracion(String t) {
    final limpio = _limpiar(t);
    if (!enMayusculas(limpio)) return limpio;
    final r = _cambiar(limpio, (w, _) => _palabra(w));
    // Mayúscula al inicio y después de punto.
    return r.replaceAllMapped(
      RegExp(r'(^|[.!?]\s+)([a-záéíóúñ])'),
      (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
    );
  }

  /// Etiqueta corta (modalidad, estado) en oración y con tildes, venga en
  /// mayúsculas o en "Tipo Título": "SELECCION ABREVIADA" → "Selección
  /// abreviada".
  static String etiqueta(String t) => oracion(t.toUpperCase());

  /// Nombre propio (cuenta, entidad, dependencia) en mayúscula inicial.
  static String titulo(String t) {
    final limpio = _limpiar(t)
        .replaceAll(RegExp(r'[*/?+]+'), ' ')
        .replaceAll(RegExp(r'(?<=[A-Za-zÁÉÍÓÚÑ])\d+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\s.\-]+$'), '')
        .trim();
    if (limpio.isEmpty) return limpio;
    return _cambiar(limpio, (w, i) {
      final p = _palabra(w);
      if (p == p.toUpperCase() && p != p.toLowerCase()) return p;
      if (i > 0 && _conectores.contains(p)) return p;
      return p[0].toUpperCase() + p.substring(1);
    });
  }
}
