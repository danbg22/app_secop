import 'package:flutter/material.dart';

/// Configuración declarativa de las modalidades de selección de la
/// contratación estatal colombiana (Ley 80 de 1993, Ley 1150 de 2007,
/// Ley 1474 de 2011 y Decreto 1082 de 2015).
///
/// Cada modalidad define sus campos, etapas, documentos de la entidad por
/// etapa, documentos habilitantes del oferente y documentos de legalización
/// del contrato. La interfaz se arma a partir de estos datos: para agregar o
/// ajustar una modalidad basta con editar este archivo.
///
/// Los plazos son los generales del Decreto 1082 de 2015; el pliego de
/// condiciones de cada proceso puede fijar los suyos.

/// Quién aporta el documento.
enum ResponsableDocumento { entidad, oferente, adjudicatario }

/// Cómo se tramita la modalidad en la plataforma.
enum FlujoModalidad {
  /// Un solo contratista definido desde el inicio (contratación directa):
  /// expediente con enlace de invitado.
  contratoDirecto,

  /// Convocatoria pública con varios oferentes, evaluación y adjudicación.
  procesoCompetitivo,
}

enum TipoCampo { texto, textoLargo, moneda, numero, fecha, seleccion }

class DocumentoRequerido {
  const DocumentoRequerido({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.obligatorio = true,
    this.fundamento,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final bool obligatorio;

  /// Norma que lo exige, para mostrarla como ayuda.
  final String? fundamento;
}

class EtapaProceso {
  const EtapaProceso({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.documentosEntidad = const [],
    this.plazo,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final List<DocumentoRequerido> documentosEntidad;

  /// Plazo legal de la etapa, en lenguaje claro.
  final String? plazo;
}

class CampoModalidad {
  const CampoModalidad({
    required this.id,
    required this.etiqueta,
    this.tipo = TipoCampo.texto,
    this.obligatorio = true,
    this.opciones = const [],
    this.ayuda,
  });

  final String id;
  final String etiqueta;
  final TipoCampo tipo;
  final bool obligatorio;
  final List<String> opciones;
  final String? ayuda;
}

class ModalidadContratacion {
  const ModalidadContratacion({
    required this.id,
    required this.nombre,
    required this.resumen,
    required this.fundamento,
    required this.icono,
    required this.color,
    required this.fondo,
    required this.flujo,
    this.campos = const [],
    this.etapas = const [],
    this.documentosOferente = const [],
    this.documentosContrato = const [],
    this.criterioEvaluacion,
  });

  final String id;
  final String nombre;
  final String resumen;
  final String fundamento;
  final IconData icono;
  final Color color;
  final Color fondo;
  final FlujoModalidad flujo;

  /// Campos propios de la modalidad, además de los comunes del proceso
  /// (entidad, número, objeto, presupuesto y plazo).
  final List<CampoModalidad> campos;
  final List<EtapaProceso> etapas;

  /// Requisitos habilitantes y oferta que sube cada oferente por su enlace.
  final List<DocumentoRequerido> documentosOferente;

  /// Documentos de legalización y ejecución que aporta el adjudicatario.
  final List<DocumentoRequerido> documentosContrato;

  /// Cómo se escoge la oferta ganadora.
  final String? criterioEvaluacion;

  bool get esCompetitiva => flujo == FlujoModalidad.procesoCompetitivo;

  /// Documentos de la entidad de todas las etapas, en orden.
  List<DocumentoRequerido> get documentosEntidad => [
    for (final e in etapas) ...e.documentosEntidad,
  ];
}

// =============================================================================
// Documentos reutilizados entre modalidades
// =============================================================================

const _estudiosPrevios = DocumentoRequerido(
  id: 'estudios_previos',
  nombre: 'Estudios y documentos previos',
  descripcion: 'Necesidad, objeto, modalidad y su justificación, valor estimado, criterios de selección, riesgos y garantías.',
  fundamento: 'Decreto 1082 de 2015, art. 2.2.1.1.2.1.1',
);
const _analisisSector = DocumentoRequerido(
  id: 'analisis_sector',
  nombre: 'Análisis del sector',
  descripcion: 'Perspectiva legal, comercial, financiera, organizacional y técnica del mercado del objeto a contratar.',
  fundamento: 'Decreto 1082 de 2015, art. 2.2.1.1.1.6.1',
);
const _cdp = DocumentoRequerido(
  id: 'cdp',
  nombre: 'Certificado de disponibilidad presupuestal (CDP)',
  descripcion:
      'Expedido por el área de presupuesto por el valor estimado del contrato.',
  fundamento: 'Decreto 111 de 1996, art. 71',
);
const _matrizRiesgos = DocumentoRequerido(
  id: 'matriz_riesgos',
  nombre: 'Matriz de riesgos',
  descripcion:
      'Tipificación, estimación y asignación de los riesgos previsibles.',
  fundamento: 'Decreto 1082 de 2015, art. 2.2.1.1.1.6.3',
);
const _avisoConvocatoria = DocumentoRequerido(
  id: 'aviso_convocatoria',
  nombre: 'Aviso de convocatoria',
  descripcion: 'Publicado en SECOP con la información mínima del proceso.',
  fundamento: 'Decreto 1082 de 2015, art. 2.2.1.1.2.1.2',
);
const _proyectoPliego = DocumentoRequerido(
  id: 'proyecto_pliego',
  nombre: 'Proyecto de pliego de condiciones',
  descripcion: 'Publicado para recibir observaciones de los interesados.',
  fundamento: 'Decreto 1082 de 2015, art. 2.2.1.1.2.1.4',
);
const _observacionesRespuestas = DocumentoRequerido(
  id: 'respuesta_observaciones',
  nombre: 'Respuesta a observaciones',
  descripcion: 'Documento con las observaciones recibidas y la respuesta motivada de la entidad.',
);
const _resolucionApertura = DocumentoRequerido(
  id: 'resolucion_apertura',
  nombre: 'Acto administrativo de apertura',
  descripcion: 'Ordena la apertura del proceso de selección.',
  fundamento: 'Decreto 1082 de 2015, art. 2.2.1.1.2.1.5',
);
const _pliegoDefinitivo = DocumentoRequerido(
  id: 'pliego_definitivo',
  nombre: 'Pliego de condiciones definitivo',
  descripcion: 'Requisitos habilitantes, criterios de evaluación, cronograma y minuta del contrato.',
  fundamento: 'Ley 80 de 1993, art. 24 num. 5',
);
const _adendas = DocumentoRequerido(
  id: 'adendas',
  nombre: 'Adendas',
  descripcion: 'Modificaciones al pliego publicadas antes del cierre.',
  obligatorio: false,
  fundamento: 'Decreto 1082 de 2015, art. 2.2.1.1.2.2.1',
);
const _actaCierre = DocumentoRequerido(
  id: 'acta_cierre',
  nombre: 'Acta de cierre y recepción de ofertas',
  descripcion:
      'Relación de las ofertas recibidas a la hora fijada en el cronograma.',
);
const _informeEvaluacion = DocumentoRequerido(
  id: 'informe_evaluacion',
  nombre: 'Informe de evaluación',
  descripcion:
      'Verificación de requisitos habilitantes y calificación de las ofertas.',
);
const _resolucionAdjudicacion = DocumentoRequerido(
  id: 'resolucion_adjudicacion',
  nombre: 'Acto de adjudicación o declaratoria de desierto',
  descripcion: 'Acto administrativo motivado que adjudica el contrato o declara desierto el proceso.',
  fundamento: 'Ley 1150 de 2007, art. 9',
);
const _registroPresupuestal = DocumentoRequerido(
  id: 'registro_presupuestal',
  nombre: 'Registro presupuestal (RP)',
  descripcion: 'Perfecciona el compromiso presupuestal del contrato.',
  fundamento: 'Decreto 111 de 1996, art. 71',
);
const _designacionSupervisor = DocumentoRequerido(
  id: 'designacion_supervisor',
  nombre: 'Designación de supervisor o interventor',
  descripcion: 'Acto que designa a quien hará el seguimiento del contrato.',
  fundamento: 'Ley 1474 de 2011, art. 83',
);

// Documentos del oferente
const _cartaPresentacion = DocumentoRequerido(
  id: 'carta_presentacion',
  nombre: 'Carta de presentación de la oferta',
  descripcion: 'Firmada por el oferente o su representante legal.',
);
const _camaraComercio = DocumentoRequerido(
  id: 'camara_comercio',
  nombre: 'Certificado de existencia y representación legal',
  descripcion: 'Solo personas jurídicas: Cámara de Comercio, con antigüedad no mayor a 30 días.',
  obligatorio: false,
);
const _rup = DocumentoRequerido(
  id: 'rup',
  nombre: 'Registro Único de Proponentes (RUP)',
  descripcion: 'Vigente y en firme: experiencia, capacidad jurídica, financiera y organizacional.',
  fundamento: 'Ley 1150 de 2007, art. 6',
);
const _rut = DocumentoRequerido(
  id: 'rut',
  nombre: 'RUT actualizado',
  descripcion:
      'Registro Único Tributario con actividad económica acorde al objeto.',
);
const _identificacionRepresentante = DocumentoRequerido(
  id: 'cedula_representante',
  nombre: 'Documento de identidad del oferente o representante legal',
  descripcion: 'Copia legible por ambas caras.',
);
const _parafiscales = DocumentoRequerido(
  id: 'parafiscales',
  nombre: 'Certificación de aportes a seguridad social y parafiscales',
  descripcion: 'Firmada por el revisor fiscal o representante legal (últimos seis meses).',
  fundamento: 'Ley 789 de 2002, art. 50',
);
const _antecedentes = DocumentoRequerido(
  id: 'antecedentes',
  nombre: 'Antecedentes fiscales, disciplinarios, judiciales y de medidas correctivas',
  descripcion: 'Del oferente y de su representante legal: Contraloría, Procuraduría, Policía y RNMC.',
);
const _garantiaSeriedad = DocumentoRequerido(
  id: 'garantia_seriedad',
  nombre: 'Garantía de seriedad de la oferta',
  descripcion: 'Por el valor y la vigencia que fije el pliego.',
  fundamento: 'Decreto 1082 de 2015, art. 2.2.1.2.3.1.6',
);
const _ofertaEconomica = DocumentoRequerido(
  id: 'oferta_economica',
  nombre: 'Oferta económica',
  descripcion: 'Valor ofrecido discriminado según el formato del pliego o la invitación.',
);
const _experiencia = DocumentoRequerido(
  id: 'experiencia',
  nombre: 'Soportes de experiencia',
  descripcion:
      'Certificaciones o contratos que acrediten la experiencia exigida.',
);
const _experienciaSiSeExige = DocumentoRequerido(
  id: 'experiencia',
  nombre: 'Soportes de experiencia',
  descripcion: 'Solo si la invitación exige experiencia mínima.',
  obligatorio: false,
);
const _documentoConsorcio = DocumentoRequerido(
  id: 'documento_consorcio',
  nombre: 'Documento de conformación de consorcio o unión temporal',
  descripcion: 'Solo si el oferente es plural: participación, responsabilidades y representante.',
  obligatorio: false,
);
const _compromisoAnticorrupcion = DocumentoRequerido(
  id: 'compromiso_anticorrupcion',
  nombre: 'Compromiso anticorrupción',
  descripcion: 'Declaración firmada según el formato del pliego.',
  obligatorio: false,
);

// Documentos de legalización del adjudicatario
const _garantiaCumplimiento = DocumentoRequerido(
  id: 'garantia_cumplimiento',
  nombre: 'Garantía única de cumplimiento',
  descripcion: 'Póliza con los amparos, valores y vigencias exigidos, para aprobación de la entidad.',
  fundamento: 'Decreto 1082 de 2015, art. 2.2.1.2.3.1.7',
);

/// En mínima cuantía y contratación directa la entidad decide si la exige
/// (Decreto 1082 de 2015, arts. 2.2.1.2.1.5.4 y 2.2.1.2.1.4.5).
const _garantiaCumplimientoOpcional = DocumentoRequerido(
  id: 'garantia_cumplimiento',
  nombre: 'Garantía única de cumplimiento',
  descripcion:
      'Solo si la entidad la exige en los estudios previos o la invitación.',
  obligatorio: false,
  fundamento: 'Decreto 1082 de 2015, arts. 2.2.1.2.1.5.4 y 2.2.1.2.1.4.5',
);
const _contratoFirmado = DocumentoRequerido(
  id: 'contrato_firmado',
  nombre: 'Contrato firmado',
  descripcion: 'Minuta suscrita por el contratista.',
);
const _arl = DocumentoRequerido(
  id: 'arl',
  nombre: 'Afiliación a ARL',
  descripcion:
      'Cuando el objeto lo exige (personal en sitio o actividades de riesgo).',
  obligatorio: false,
);
const _certificacionBancaria = DocumentoRequerido(
  id: 'certificacion_bancaria',
  nombre: 'Certificación bancaria',
  descripcion:
      'Cuenta activa para los pagos, con antigüedad no mayor a 30 días.',
);

const _legalizacionContrato = [
  _contratoFirmado,
  _garantiaCumplimiento,
  _certificacionBancaria,
  _arl,
];

const _etapaPlaneacion = EtapaProceso(
  id: 'planeacion',
  nombre: 'Planeación',
  descripcion:
      'Documentos previos que justifican la necesidad y el presupuesto.',
  documentosEntidad: [_estudiosPrevios, _analisisSector, _cdp, _matrizRiesgos],
);

const _etapaContrato = EtapaProceso(
  id: 'contrato',
  nombre: 'Contrato y legalización',
  descripcion:
      'Firma, garantías, registro presupuestal y designación de supervisión.',
  documentosEntidad: [_registroPresupuestal, _designacionSupervisor],
);

// =============================================================================
// Catálogo de modalidades
// =============================================================================

const List<ModalidadContratacion> modalidadesContratacion = [
  ModalidadContratacion(
    id: 'prestacion_servicios',
    nombre: 'Prestación de servicios',
    resumen: 'Contratación directa de servicios profesionales y de apoyo a la gestión con una persona natural o jurídica.',
    fundamento: 'Ley 1150 de 2007, art. 2 num. 4 lit. h · Decreto 1082 de 2015, art. 2.2.1.2.1.4.9',
    icono: Icons.badge_outlined,
    color: Color(0xFFB7791F),
    fondo: Color(0xFFFFF3CC),
    flujo: FlujoModalidad.contratoDirecto,
    // Sus documentos son la plantilla OPS que ya usa la mesa de verificación
    // (JuridicoContratacionService.plantillasEstandarColombia).
  ),
  ModalidadContratacion(
    id: 'contratacion_directa',
    nombre: 'Contratación directa (otras causales)',
    resumen: 'Casos taxativos sin convocatoria: convenios interadministrativos, urgencia manifiesta, no pluralidad de oferentes, arrendamientos, entre otros.',
    fundamento: 'Ley 1150 de 2007, art. 2 num. 4 · Decreto 1082 de 2015, art. 2.2.1.2.1.4.1',
    icono: Icons.handshake_outlined,
    color: Color(0xFF28559A),
    fondo: Color(0xFFE8F1FC),
    flujo: FlujoModalidad.contratoDirecto,
    campos: [
      CampoModalidad(
        id: 'causal',
        etiqueta: 'Causal de contratación directa',
        tipo: TipoCampo.seleccion,
        opciones: [
          'Urgencia manifiesta',
          'Contratos o convenios interadministrativos',
          'Contratos para el desarrollo de actividades científicas y tecnológicas',
          'Cuando no exista pluralidad de oferentes',
          'Arrendamiento o adquisición de inmuebles',
          'Empréstitos',
          'Bienes y servicios del sector Defensa y DNI con reserva',
          'Encargos fiduciarios de entidades territoriales en acuerdos de reestructuración',
        ],
      ),
    ],
    etapas: [
      EtapaProceso(
        id: 'planeacion',
        nombre: 'Planeación y justificación',
        descripcion: 'Estudios previos, presupuesto y acto que justifica la contratación directa.',
        documentosEntidad: [
          _estudiosPrevios,
          _cdp,
          DocumentoRequerido(
            id: 'acto_justificacion',
            nombre: 'Acto administrativo de justificación',
            descripcion: 'Señala la causal, el objeto, el presupuesto y los estudios que lo soportan. En urgencia manifiesta lo reemplaza el acto que la declara.',
            obligatorio: false,
            fundamento: 'Decreto 1082 de 2015, art. 2.2.1.2.1.4.1',
          ),
        ],
      ),
      _etapaContrato,
    ],
    documentosContrato: [
      _identificacionRepresentante,
      _rut,
      _camaraComercio,
      _parafiscales,
      _antecedentes,
      _contratoFirmado,
      _garantiaCumplimientoOpcional,
      _certificacionBancaria,
      _arl,
    ],
  ),
  ModalidadContratacion(
    id: 'minima_cuantia',
    nombre: 'Mínima cuantía',
    resumen: 'Contratos hasta el 10 % de la menor cuantía de la entidad. Invitación pública y se adjudica a la oferta de menor precio que cumpla.',
    fundamento: 'Ley 1474 de 2011, art. 94 · Decreto 1082 de 2015, arts. 2.2.1.2.1.5.1 a 2.2.1.2.1.5.4',
    icono: Icons.shopping_bag_outlined,
    color: Color(0xFF1F6E7A),
    fondo: Color(0xFFE3F3F2),
    flujo: FlujoModalidad.procesoCompetitivo,
    criterioEvaluacion:
        'Menor precio, verificando requisitos habilitantes de esa oferta.',
    etapas: [
      EtapaProceso(
        id: 'planeacion',
        nombre: 'Planeación',
        descripcion: 'Estudios previos y presupuesto.',
        documentosEntidad: [_estudiosPrevios, _cdp],
      ),
      EtapaProceso(
        id: 'invitacion',
        nombre: 'Invitación pública',
        descripcion: 'Se publica la invitación con el objeto, el valor, los requisitos y el cronograma.',
        plazo: 'Publicada por lo menos un día hábil antes del cierre.',
        documentosEntidad: [
          DocumentoRequerido(
            id: 'invitacion_publica',
            nombre: 'Invitación pública',
            descripcion: 'Objeto, valor, requisitos habilitantes, forma de acreditarlos y cronograma.',
            fundamento: 'Decreto 1082 de 2015, art. 2.2.1.2.1.5.2',
          ),
          _adendas,
        ],
      ),
      EtapaProceso(
        id: 'ofertas',
        nombre: 'Recepción de ofertas',
        descripcion:
            'Los oferentes cargan su oferta y requisitos por su enlace.',
        documentosEntidad: [_actaCierre],
      ),
      EtapaProceso(
        id: 'evaluacion',
        nombre: 'Evaluación',
        descripcion: 'Se verifica la oferta de menor precio; si no cumple, la siguiente.',
        plazo:
            'Informe publicado por lo menos un día hábil para observaciones.',
        documentosEntidad: [_informeEvaluacion],
      ),
      EtapaProceso(
        id: 'aceptacion',
        nombre: 'Aceptación de la oferta',
        descripcion: 'La comunicación de aceptación y la oferta constituyen el contrato.',
        documentosEntidad: [
          DocumentoRequerido(
            id: 'comunicacion_aceptacion',
            nombre: 'Comunicación de aceptación de la oferta',
            descripcion:
                'Con ella y la oferta queda perfeccionado el contrato.',
            fundamento: 'Decreto 1082 de 2015, art. 2.2.1.2.1.5.2',
          ),
          _registroPresupuestal,
          _designacionSupervisor,
        ],
      ),
    ],
    documentosOferente: [
      _cartaPresentacion,
      _ofertaEconomica,
      _identificacionRepresentante,
      _rut,
      _camaraComercio,
      _parafiscales,
      _antecedentes,
      _experienciaSiSeExige,
    ],
    documentosContrato: [
      _garantiaCumplimientoOpcional,
      _certificacionBancaria,
      _arl,
    ],
  ),
  ModalidadContratacion(
    id: 'seleccion_abreviada_menor_cuantia',
    nombre: 'Selección abreviada de menor cuantía',
    resumen: 'Contratos hasta la menor cuantía de la entidad. Manifestación de interés; con más de diez interesados la entidad puede sortear.',
    fundamento: 'Ley 1150 de 2007, art. 2 num. 2 lit. b · Decreto 1082 de 2015, art. 2.2.1.2.1.2.20',
    icono: Icons.filter_alt_outlined,
    color: Color(0xFF5D469C),
    fondo: Color(0xFFEEEAF9),
    flujo: FlujoModalidad.procesoCompetitivo,
    criterioEvaluacion: 'Factores de calidad y precio definidos en el pliego.',
    etapas: [
      _etapaPlaneacion,
      EtapaProceso(
        id: 'convocatoria',
        nombre: 'Convocatoria y proyecto de pliego',
        descripcion: 'Aviso, proyecto de pliego y respuesta a observaciones.',
        plazo: 'Proyecto de pliego publicado por lo menos 5 días hábiles.',
        documentosEntidad: [
          _avisoConvocatoria,
          _proyectoPliego,
          _observacionesRespuestas,
        ],
      ),
      EtapaProceso(
        id: 'apertura',
        nombre: 'Apertura y manifestaciones de interés',
        descripcion: 'Acto de apertura, pliego definitivo y lista de interesados (la entidad puede sortear si son más de 10).',
        plazo: 'Manifestación de interés dentro de los 3 días hábiles siguientes a la apertura.',
        documentosEntidad: [
          _resolucionApertura,
          _pliegoDefinitivo,
          DocumentoRequerido(
            id: 'acta_sorteo',
            nombre: 'Acta de sorteo de interesados',
            descripcion: 'Solo si hubo más de diez manifestaciones de interés y la entidad decidió sortear.',
            obligatorio: false,
            fundamento: 'Decreto 1082 de 2015, art. 2.2.1.2.1.2.20 num. 2',
          ),
          _adendas,
        ],
      ),
      EtapaProceso(
        id: 'ofertas',
        nombre: 'Cierre y ofertas',
        descripcion:
            'Los oferentes cargan su oferta y requisitos habilitantes.',
        documentosEntidad: [_actaCierre],
      ),
      EtapaProceso(
        id: 'evaluacion',
        nombre: 'Evaluación y adjudicación',
        descripcion:
            'Informe de evaluación, traslado a los oferentes y adjudicación.',
        plazo: 'Traslado del informe por 3 días hábiles.',
        documentosEntidad: [_informeEvaluacion, _resolucionAdjudicacion],
      ),
      _etapaContrato,
    ],
    documentosOferente: [
      _cartaPresentacion,
      _ofertaEconomica,
      _camaraComercio,
      _rup,
      _rut,
      _identificacionRepresentante,
      _parafiscales,
      _antecedentes,
      _garantiaSeriedad,
      _documentoConsorcio,
      _compromisoAnticorrupcion,
    ],
    documentosContrato: _legalizacionContrato,
  ),
  ModalidadContratacion(
    id: 'subasta_inversa',
    nombre: 'Selección abreviada · subasta inversa',
    resumen: 'Bienes y servicios de características técnicas uniformes. Gana el menor precio ofrecido en la subasta.',
    fundamento: 'Ley 1150 de 2007, art. 2 num. 2 lit. a · Decreto 1082 de 2015, arts. 2.2.1.2.1.2.2 a 2.2.1.2.1.2.6',
    icono: Icons.trending_down_rounded,
    color: Color(0xFFC2410C),
    fondo: Color(0xFFFFEDD5),
    flujo: FlujoModalidad.procesoCompetitivo,
    criterioEvaluacion:
        'Menor precio en la subasta, entre oferentes habilitados.',
    campos: [
      CampoModalidad(
        id: 'tipo_subasta',
        etiqueta: 'Tipo de subasta',
        tipo: TipoCampo.seleccion,
        opciones: ['Electrónica', 'Presencial'],
      ),
      CampoModalidad(
        id: 'margen_minimo',
        etiqueta: 'Margen mínimo de mejora (%)',
        tipo: TipoCampo.numero,
        obligatorio: false,
        ayuda: 'Porcentaje mínimo en que cada lance debe mejorar el anterior.',
      ),
    ],
    etapas: [
      _etapaPlaneacion,
      EtapaProceso(
        id: 'convocatoria',
        nombre: 'Convocatoria y proyecto de pliego',
        descripcion: 'Aviso, proyecto de pliego con la ficha técnica y respuesta a observaciones.',
        plazo: 'Proyecto de pliego publicado por lo menos 5 días hábiles.',
        documentosEntidad: [
          _avisoConvocatoria,
          _proyectoPliego,
          DocumentoRequerido(
            id: 'ficha_tecnica',
            nombre: 'Ficha técnica del bien o servicio',
            descripcion:
                'Características técnicas uniformes y de común utilización.',
            fundamento: 'Decreto 1082 de 2015, art. 2.2.1.2.1.2.1',
          ),
          _observacionesRespuestas,
        ],
      ),
      EtapaProceso(
        id: 'apertura',
        nombre: 'Apertura',
        descripcion: 'Acto de apertura y pliego definitivo.',
        documentosEntidad: [_resolucionApertura, _pliegoDefinitivo, _adendas],
      ),
      EtapaProceso(
        id: 'ofertas',
        nombre: 'Ofertas y habilitación',
        descripcion: 'Los oferentes cargan sus requisitos y la oferta inicial de precio.',
        documentosEntidad: [_actaCierre, _informeEvaluacion],
      ),
      EtapaProceso(
        id: 'subasta',
        nombre: 'Subasta y adjudicación',
        descripcion:
            'Lances de precio entre los habilitados y adjudicación al menor.',
        documentosEntidad: [
          DocumentoRequerido(
            id: 'acta_subasta',
            nombre: 'Acta o reporte de la subasta',
            descripcion: 'Lances recibidos y precio final de cada oferente.',
          ),
          _resolucionAdjudicacion,
        ],
      ),
      _etapaContrato,
    ],
    documentosOferente: [
      _cartaPresentacion,
      _ofertaEconomica,
      _camaraComercio,
      _rup,
      _rut,
      _identificacionRepresentante,
      _parafiscales,
      _antecedentes,
      _garantiaSeriedad,
      DocumentoRequerido(
        id: 'cumplimiento_ficha',
        nombre: 'Declaración de cumplimiento de la ficha técnica',
        descripcion: 'Compromiso de entregar el bien o servicio con las especificaciones exigidas.',
      ),
      _documentoConsorcio,
    ],
    documentosContrato: _legalizacionContrato,
  ),
  ModalidadContratacion(
    id: 'licitacion_publica',
    nombre: 'Licitación pública',
    resumen: 'Regla general para contratos que superan la menor cuantía y no encajan en otra modalidad, incluida la obra pública.',
    fundamento: 'Ley 80 de 1993, art. 30 · Ley 1150 de 2007, art. 2 num. 1 · Decreto 1082 de 2015, art. 2.2.1.2.1.1.1',
    icono: Icons.gavel_rounded,
    color: Color(0xFF0E2646),
    fondo: Color(0xFFE2E8F0),
    flujo: FlujoModalidad.procesoCompetitivo,
    criterioEvaluacion:
        'Oferta más favorable según los factores de ponderación del pliego.',
    campos: [
      CampoModalidad(
        id: 'tipo_contrato',
        etiqueta: 'Tipo de contrato',
        tipo: TipoCampo.seleccion,
        opciones: [
          'Obra pública',
          'Suministro',
          'Compraventa',
          'Prestación de servicios',
          'Otro',
        ],
      ),
      CampoModalidad(
        id: 'pliego_tipo',
        etiqueta: '¿Aplica documento tipo (pliego tipo)?',
        tipo: TipoCampo.seleccion,
        opciones: ['Sí', 'No'],
        ayuda: 'Obligatorio en obra pública de infraestructura de transporte y otros sectores definidos por Colombia Compra Eficiente.',
      ),
    ],
    etapas: [
      _etapaPlaneacion,
      EtapaProceso(
        id: 'convocatoria',
        nombre: 'Convocatoria y proyecto de pliego',
        descripcion: 'Aviso de convocatoria, avisos de prensa, proyecto de pliego y observaciones.',
        plazo: 'Proyecto de pliego publicado por lo menos 10 días hábiles.',
        documentosEntidad: [
          _avisoConvocatoria,
          _proyectoPliego,
          _observacionesRespuestas,
        ],
      ),
      EtapaProceso(
        id: 'apertura',
        nombre: 'Apertura y audiencia de riesgos',
        descripcion: 'Acto de apertura, pliego definitivo y audiencia de asignación de riesgos.',
        plazo: 'Audiencia de riesgos dentro de los 3 días hábiles siguientes al inicio del plazo para ofertar.',
        documentosEntidad: [
          _resolucionApertura,
          _pliegoDefinitivo,
          DocumentoRequerido(
            id: 'acta_audiencia_riesgos',
            nombre: 'Acta de audiencia de asignación de riesgos',
            descripcion:
                'Revisión de la asignación de riesgos y precisión del pliego.',
            fundamento: 'Ley 1150 de 2007, art. 4 · Decreto 1082 de 2015, art. 2.2.1.2.1.1.2',
          ),
          _adendas,
        ],
      ),
      EtapaProceso(
        id: 'ofertas',
        nombre: 'Cierre y ofertas',
        descripcion:
            'Los oferentes cargan su oferta y requisitos habilitantes.',
        documentosEntidad: [_actaCierre],
      ),
      EtapaProceso(
        id: 'evaluacion',
        nombre: 'Evaluación',
        descripcion: 'Informe de evaluación y traslado a los oferentes para observaciones.',
        plazo: 'Traslado del informe por 5 días hábiles.',
        documentosEntidad: [_informeEvaluacion],
      ),
      EtapaProceso(
        id: 'adjudicacion',
        nombre: 'Audiencia de adjudicación',
        descripcion:
            'Audiencia pública en la que se adjudica o se declara desierto.',
        documentosEntidad: [
          DocumentoRequerido(
            id: 'acta_audiencia_adjudicacion',
            nombre: 'Acta de audiencia de adjudicación',
            descripcion: 'Desarrollo de la audiencia pública y decisión.',
            fundamento: 'Ley 80 de 1993, art. 30 num. 10 · Decreto 1082 de 2015, art. 2.2.1.2.1.1.2',
          ),
          _resolucionAdjudicacion,
        ],
      ),
      _etapaContrato,
    ],
    documentosOferente: [
      _cartaPresentacion,
      _ofertaEconomica,
      _camaraComercio,
      _rup,
      _rut,
      _identificacionRepresentante,
      _parafiscales,
      _antecedentes,
      _garantiaSeriedad,
      _experiencia,
      _documentoConsorcio,
      _compromisoAnticorrupcion,
    ],
    documentosContrato: _legalizacionContrato,
  ),
  ModalidadContratacion(
    id: 'concurso_meritos',
    nombre: 'Concurso de méritos',
    resumen: 'Consultoría y proyectos de arquitectura. Se califica la calidad técnica; el precio no es factor de escogencia.',
    fundamento: 'Ley 1150 de 2007, art. 2 num. 3 · Decreto 1082 de 2015, art. 2.2.1.2.1.3.1 y ss.',
    icono: Icons.workspace_premium_outlined,
    color: Color(0xFF15803D),
    fondo: Color(0xFFDCFCE7),
    flujo: FlujoModalidad.procesoCompetitivo,
    criterioEvaluacion: 'Calidad técnica y experiencia; luego se revisa la oferta económica del primer lugar.',
    campos: [
      CampoModalidad(
        id: 'precalificacion',
        etiqueta: '¿Con precalificación?',
        tipo: TipoCampo.seleccion,
        opciones: ['No', 'Sí'],
        ayuda: 'Se conforma una lista corta de interesados antes de la presentación de ofertas.',
      ),
    ],
    etapas: [
      _etapaPlaneacion,
      EtapaProceso(
        id: 'convocatoria',
        nombre: 'Convocatoria y proyecto de pliego',
        descripcion: 'Aviso, proyecto de pliego y respuesta a observaciones.',
        plazo: 'Proyecto de pliego publicado por lo menos 5 días hábiles.',
        documentosEntidad: [
          _avisoConvocatoria,
          _proyectoPliego,
          _observacionesRespuestas,
        ],
      ),
      EtapaProceso(
        id: 'apertura',
        nombre: 'Apertura',
        descripcion: 'Acto de apertura y pliego definitivo (lista corta si hubo precalificación).',
        documentosEntidad: [
          _resolucionApertura,
          _pliegoDefinitivo,
          DocumentoRequerido(
            id: 'lista_corta',
            nombre: 'Informe de precalificación (lista corta)',
            descripcion: 'Solo si el concurso tiene precalificación.',
            obligatorio: false,
            fundamento: 'Decreto 1082 de 2015, art. 2.2.1.2.1.3.3',
          ),
          _adendas,
        ],
      ),
      EtapaProceso(
        id: 'ofertas',
        nombre: 'Cierre y ofertas técnicas',
        descripcion:
            'Los oferentes cargan su oferta técnica y requisitos habilitantes.',
        documentosEntidad: [_actaCierre],
      ),
      EtapaProceso(
        id: 'evaluacion',
        nombre: 'Evaluación y adjudicación',
        descripcion: 'Calificación técnica, traslado del informe y revisión de la oferta económica del primer lugar.',
        plazo: 'Traslado del informe por 3 días hábiles.',
        documentosEntidad: [_informeEvaluacion, _resolucionAdjudicacion],
      ),
      _etapaContrato,
    ],
    documentosOferente: [
      _cartaPresentacion,
      DocumentoRequerido(
        id: 'propuesta_tecnica',
        nombre: 'Propuesta técnica',
        descripcion:
            'Metodología, plan de trabajo y enfoque de la consultoría.',
      ),
      DocumentoRequerido(
        id: 'equipo_trabajo',
        nombre: 'Equipo de trabajo (hojas de vida y soportes)',
        descripcion: 'Formación y experiencia del personal mínimo exigido.',
      ),
      _experiencia,
      _ofertaEconomica,
      _camaraComercio,
      _rup,
      _rut,
      _identificacionRepresentante,
      _parafiscales,
      _antecedentes,
      _garantiaSeriedad,
      _documentoConsorcio,
    ],
    documentosContrato: _legalizacionContrato,
  ),
  ModalidadContratacion(
    id: 'regimen_especial',
    nombre: 'Régimen especial',
    resumen: 'Entidades exceptuadas del Estatuto General (E.S.E., universidades, empresas de servicios públicos, entre otras) que contratan según su manual.',
    fundamento:
        'Ley 1150 de 2007, art. 13 · Manual de contratación de la entidad',
    icono: Icons.account_balance_outlined,
    color: Color(0xFF64748B),
    fondo: Color(0xFFF1F5F9),
    flujo: FlujoModalidad.procesoCompetitivo,
    criterioEvaluacion:
        'El que defina el manual de contratación y los términos de referencia.',
    campos: [
      CampoModalidad(
        id: 'norma_manual',
        etiqueta: 'Acto que adopta el manual de contratación',
        ayuda: 'Ej.: Acuerdo 012 de 2024 de la junta directiva.',
      ),
      CampoModalidad(
        id: 'tipo_invitacion',
        etiqueta: 'Tipo de invitación',
        tipo: TipoCampo.seleccion,
        opciones: [
          'Invitación pública',
          'Invitación privada',
          'Contratación directa',
        ],
      ),
    ],
    etapas: [
      EtapaProceso(
        id: 'planeacion',
        nombre: 'Planeación',
        descripcion: 'Estudios previos y presupuesto según el manual.',
        documentosEntidad: [_estudiosPrevios, _cdp],
      ),
      EtapaProceso(
        id: 'invitacion',
        nombre: 'Invitación y términos de referencia',
        descripcion: 'Términos de referencia o invitación según el manual de contratación.',
        documentosEntidad: [
          DocumentoRequerido(
            id: 'terminos_referencia',
            nombre: 'Términos de referencia o invitación',
            descripcion: 'Requisitos, criterios de evaluación y cronograma.',
          ),
          _adendas,
        ],
      ),
      EtapaProceso(
        id: 'ofertas',
        nombre: 'Ofertas',
        descripcion: 'Los oferentes cargan su oferta y documentos.',
        documentosEntidad: [_actaCierre],
      ),
      EtapaProceso(
        id: 'evaluacion',
        nombre: 'Evaluación y selección',
        descripcion: 'Informe de evaluación y acto de selección.',
        documentosEntidad: [_informeEvaluacion, _resolucionAdjudicacion],
      ),
      _etapaContrato,
    ],
    documentosOferente: [
      _cartaPresentacion,
      _ofertaEconomica,
      _camaraComercio,
      _rut,
      _identificacionRepresentante,
      _parafiscales,
      _antecedentes,
      _experiencia,
    ],
    documentosContrato: _legalizacionContrato,
  ),
];

ModalidadContratacion? modalidadPorId(String id) {
  for (final m in modalidadesContratacion) {
    if (m.id == id) return m;
  }
  return null;
}
