import '../data/modalidades_contratacion.dart';
import 'procesos_secop_service.dart';

/// Etapa general de un proceso de SECOP II, para la línea de tiempo y para
/// saber qué documentos de la ley ya deberían estar publicados.
///
/// Los procesos competitivos pasan por convocatoria, ofertas, evaluación y
/// adjudicación; la contratación directa solo se publica y se contrata.
class EtapasProceso {
  const EtapasProceso({
    required this.nombres,
    required this.actual,
    this.interrumpido,
  });

  /// Nombres de las etapas, en orden.
  final List<String> nombres;

  /// Índice de la etapa en la que va el proceso.
  final int actual;

  /// Si el proceso se canceló, se suspendió o quedó desierto: el estado, para
  /// mostrar dónde se detuvo.
  final String? interrumpido;

  bool get terminado => actual == nombres.length - 1 && interrumpido == null;

  static const competitivas = [
    'Planeación',
    'Convocatoria',
    'Ofertas',
    'Evaluación',
    'Adjudicación',
  ];
  static const directas = ['Planeación', 'Publicación', 'Contrato'];

  static bool _esDirecta(ProcesoSecop p) {
    final m = p.modalidad.toLowerCase();
    return m.contains('directa') && !m.contains('con ofertas') ||
        m == 'contratación régimen especial';
  }

  static EtapasProceso de(ProcesoSecop p) {
    final estado = p.estado;
    final interrumpido = p.tipo == TipoEstadoProceso.cancelado ? estado : null;
    if (_esDirecta(p)) {
      final i = switch (p.tipo) {
        TipoEstadoProceso.preparacion => 0,
        TipoEstadoProceso.adjudicado => 2,
        _ => 1,
      };
      return EtapasProceso(
        nombres: directas,
        actual: i,
        interrumpido: interrumpido,
      );
    }
    final fase = p.fase.toLowerCase();
    final int i;
    if (p.tipo == TipoEstadoProceso.preparacion) {
      i = 0;
    } else if (p.tipo == TipoEstadoProceso.adjudicado) {
      i = 4;
    } else if (estado == 'En evaluación' ||
        estado == 'Plazo de ofertas vencido' ||
        estado == 'Ofertas cerradas, sin adjudicar') {
      i = 3;
    } else if (fase.contains('observaci') || fase.contains('manifestaci')) {
      i = 1;
    } else if (estado == 'Recibe ofertas' || fase.contains('oferta')) {
      i = 2;
    } else {
      i = 1;
    }
    return EtapasProceso(
      nombres: competitivas,
      actual: i,
      interrumpido: interrumpido,
    );
  }
}

/// Lo que dice la ley para la modalidad del proceso, y si los documentos que
/// debe publicar la entidad aparecen en Datos Abiertos.
class RequisitosDeLey {
  RequisitosDeLey._();

  /// Modalidad del catálogo de la ley que corresponde a la de SECOP II.
  static ModalidadContratacion? modalidad(String modalidadSecop) {
    final m = modalidadSecop.toLowerCase();
    final String? id;
    if (m.contains('licitaci')) {
      id = 'licitacion_publica';
    } else if (m.contains('subasta inversa')) {
      id = 'subasta_inversa';
    } else if (m.contains('abreviada')) {
      id = 'seleccion_abreviada_menor_cuantia';
    } else if (m.contains('mínima') || m.contains('minima')) {
      id = 'minima_cuantia';
    } else if (m.contains('concurso')) {
      id = 'concurso_meritos';
    } else if (m.contains('directa')) {
      id = 'contratacion_directa';
    } else if (m.contains('régimen especial') ||
        m.contains('regimen especial')) {
      id = 'regimen_especial';
    } else {
      id = null;
    }
    if (id == null) return null;
    for (final mod in modalidadesContratacion) {
      if (mod.id == id) return mod;
    }
    return null;
  }

  /// Etapa general (índice de [EtapasProceso.competitivas]) en la que la
  /// entidad debe tener publicado un documento de esa etapa del catálogo.
  static int etapaGeneral(String etapaCatalogo) => switch (etapaCatalogo) {
    'planeacion' => 0,
    'convocatoria' || 'invitacion' || 'apertura' || 'proyecto_pliego' => 1,
    'ofertas' || 'manifestacion_interes' => 2,
    'evaluacion' || 'subasta' => 3,
    'adjudicacion' || 'aceptacion' || 'seleccion' => 4,
    _ => 5, // contrato y legalización
  };

  static String _compacto(String texto) => texto
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll(RegExp('[^a-z0-9ñ]'), '');

  static Set<String> _palabras(String texto) => texto
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9ñáéíóú]+'))
      .where((p) => p.isNotEmpty)
      .toSet();

  /// Cómo se suele nombrar cada documento en SECOP II (en minúsculas, sin
  /// tildes ni espacios). Basta con que el nombre del archivo contenga uno.
  static const Map<String, List<String>> _nombres = {
    'estudios_previos': [
      'estudioprevio',
      'estudiosprevio',
      'documentosprevios',
    ],
    'analisis_sector': [
      'analisisdelsector',
      'analisisdesector',
      'estudiodelsector',
      'estudiodesector',
      'analisisdelmercado',
      'estudiodemercado',
    ],
    'cdp': ['disponibilidadpresupuestal'],
    'matriz_riesgos': ['matrizderiesgo', 'matrizriesgo', 'riesgosprevisibles'],
    'aviso_convocatoria': ['avisodeconvocatoria', 'avisoconvocatoria'],
    'proyecto_pliego': ['proyectodepliego', 'proyectopliego'],
    'resolucion_apertura': [
      'resoluciondeapertura',
      'actodeapertura',
      'resolucionapertura',
    ],
    'pliego_definitivo': ['pliegodefinitivo', 'pliegodecondicionesdefinitivo'],
    'adendas': ['adenda'],
    'acta_cierre': [
      'actadecierre',
      'listadeoferentes',
      'recepciondeofertas',
      'informedepresentacion',
    ],
    'informe_evaluacion': [
      'informedeevaluacion',
      'informeevaluacion',
      'evaluacionpreliminar',
      'evaluaciondefinitiva',
      'informedeverificacion',
      'verificacionderequisitos',
    ],
    'resolucion_adjudicacion': ['adjudica', 'desiert'],
    'registro_presupuestal': ['registropresupuestal'],
    'designacion_supervisor': ['designaciondesupervis', 'designacionsupervis'],
    'invitacion_publica': ['invitacionpublica', 'invitacion'],
    'comunicacion_aceptacion': [
      'aceptaciondelaoferta',
      'aceptaciondeoferta',
      'comunicaciondeaceptacion',
    ],
    'acta_sorteo': ['sorteo'],
    'ficha_tecnica': ['fichatecnica'],
    'acta_subasta': ['subasta'],
    'acta_audiencia_riesgos': [
      'audienciaderiesgos',
      'asignacionderiesgos',
      'audienciadeasignacion',
    ],
    'acta_audiencia_adjudicacion': ['audienciadeadjudicacion'],
    'lista_corta': ['listacorta', 'precalificacion'],
    'terminos_referencia': ['terminosdereferencia', 'terminosdelainvitacion'],
    'acto_justificacion': ['actodejustificacion', 'resoluciondejustificacion'],
  };

  /// Siglas que se buscan como palabra completa (dentro de otra palabra
  /// darían falsos positivos).
  static const Map<String, List<String>> _siglas = {
    'cdp': ['cdp'],
    'registro_presupuestal': ['rp', 'crp'],
  };

  /// ¿Algún archivo publicado corresponde a este documento? `null` si no
  /// se sabe reconocer por el nombre.
  static bool? publicado(String documentoId, Iterable<String> archivos) {
    if (documentoId == 'respuesta_observaciones') {
      // El nombre trae las dos palabras ("Respuesta a observaciones…").
      return archivos
          .map(_compacto)
          .any((c) => c.contains('respuesta') && c.contains('observacion'));
    }
    final nombres = _nombres[documentoId];
    final siglas = _siglas[documentoId];
    if (nombres == null && siglas == null) return null;
    for (final archivo in archivos) {
      final c = _compacto(archivo);
      if (documentoId == 'pliego_definitivo' && c.contains('proyecto')) {
        continue;
      }
      if (nombres != null && nombres.any(c.contains)) return true;
      if (siglas != null && _palabras(archivo).any(siglas.contains)) {
        return true;
      }
    }
    return false;
  }
}
