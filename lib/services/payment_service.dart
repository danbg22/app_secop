import 'dart:ui' show Color;

/// Catálogo de planes visibles en la plataforma. El servidor fija los
/// importes que firma para Wompi en functions/planes.mjs.
abstract final class AdminConfiguracionRolesYPagos {
  /// Rol base por defecto de referencia en catálogo.
  static const String rolPorDefectoId = 'persona';

  /// Grupo "Supervisión de contratos": al escoger rol se muestra como una
  /// sola tarjeta con los perfiles Supervisor, Contratista y Jurídico.
  static const String grupoSupervision = 'supervision_contratos';

  // ---------------------------------------------------------------------------
  // B. CATÁLOGO ORGANIZADO DE PAQUETES / ROLES Y SUS PRECIOS
  // ---------------------------------------------------------------------------
  static const List<RolPaqueteConfig> catalogoRoles = <RolPaqueteConfig>[
    // -------------------------------------------------------------------------
    // ROL 1: PERSONA (Antes llamado "Consulta ciudadana") - HABILITADO ($100 COP)
    // -------------------------------------------------------------------------
    RolPaqueteConfig(
      id: 'persona',
      nombre: 'Persona',
      nombrePlan: 'Plan Persona',
      etiquetaDestacada: 'Más común',
      descripcionCorta: 'Consulta información de contratos, entidades, contratistas y más. Ideal para usuarios individuales.',
      precioCop: 100, // <-- PRECIO TEMPORAL DE PRUEBA ($100 COP)
      habilitadoParaRegistro: true,
      colorPrimarioHex: 0xFFF5B82E,
      colorFondoIlustracionHex: 0xFFFFF3CC,
      colorBordeTarjetaHex: 0xFFF5B82E,
      // Solo lo que la app hace hoy: anunciar funciones que no existen en un
      // plan que se cobra es publicidad engañosa (Ley 1480 de 2011, art. 30).
      beneficiosPrincipales: <String>[
        'Consulta de contratos y entidades en tiempo real (SECOP II)',
        'Perfil de cada contratista con su historial de contratos',
        'Alertas de contratos nuevos de las entidades y contratistas que sigues',
      ],
      todosLosBeneficios: <String>[
        'Búsqueda de contratos públicos en todo el país',
        'Consulta por nombre, apellido, NIT o cédula en tiempo real',
        'Entidades nacionales y regionales con su presupuesto por dependencia',
        'Perfil de contratistas con su historial en SECOP I y II',
        'Detalle de cada contrato con sus documentos de SECOP y el Copiloto IA',
        'Exportación de los resultados de búsqueda',
        'Guardado de contratos y contratistas en Favoritos',
        'Alertas de contratos nuevos de las entidades y contratistas que sigues, guardadas en tu cuenta',
        'Pagos registrados en SECOP II de cada contrato y de cada entidad',
        'Acumulable con el rol Equipo jurídico entidad y demás paquetes',
      ],
      permisosPlataforma: <String>[
        'inicio',
        'contratos',
        'entidades',
        'contratistas',
        'procesos',
        'alertas',
        'favoritos',
        'pqrs',
      ],
    ),

    // -------------------------------------------------------------------------
    // ROL 2: EQUIPO JURÍDICO ENTIDAD - HABILITADO FUNCIONALMENTE ($100 COP TEMPORAL)
    // -------------------------------------------------------------------------
    RolPaqueteConfig(
      id: 'equipo_juridico',
      nombre: 'Equipo jurídico entidad',
      nombrePlan: 'Plan Equipo Jurídico Entidad',
      etiquetaDestacada: 'Activo',
      descripcionCorta: 'Estructura contratos de prestación de servicios en línea, genera links de invitado para contratistas y valida documentos con trazabilidad.',
      precioCop: 100, // <-- PRECIO TEMPORAL DE PRUEBA ($100 COP)
      habilitadoParaRegistro: true, // <-- HABILITADO Y 100% FUNCIONAL
      colorPrimarioHex: 0xFF28559A,
      colorFondoIlustracionHex: 0xFFE8F1FC,
      colorBordeTarjetaHex: 0xFF28559A,
      beneficiosPrincipales: <String>[
        'Estructuración web de contratos de prestación de servicios por apartados',
        'Links personalizados tipo Drive para contratistas invitados (sin cobro ni registro)',
        'Revisión documento por documento, descarga individual, correo de subsanación y trazabilidad',
      ],
      todosLosBeneficios: <String>[
        'Creación ilimitada de expedientes de Prestación de Servicios con número y objeto del contrato',
        'Configuración ágil de apartados documentales requeridos para cada futuro contratista',
        'Generación de enlace web personalizado tipo invitado (ingreso solo con nombre y cédula)',
        'Mesa de verificación jurídica documento por documento dentro de la plataforma',
        'Descarga individual de cada soporte cargado por el contratista y PDF unificado del expediente para imprimir',
        'Devolución de documentos con observaciones, correo de subsanación listo para enviar desde tu correo y línea de trazabilidad',
        '100% acumulable con las herramientas de consulta ciudadana del rol Persona',
      ],
      permisosPlataforma: <String>[
        'gestion_juridica_entidad',
        'estructurar_contratos_ps',
        'revision_documental_juridica',
        'links_invitados_contratistas',
        'trazabilidad_subsanaciones',
        'pqrs',
      ],
    ),

    // -------------------------------------------------------------------------
    // ROL 3: SUPERVISIÓN DE CONTRATOS — SUBROL SUPERVISOR ($100 COP TEMPORAL)
    // -------------------------------------------------------------------------
    RolPaqueteConfig(
      id: 'supervisor_contratos',
      nombre: 'Supervisor de contratos',
      nombrePlan: 'Plan Supervisor de Contratos',
      etiquetaDestacada: null,
      descripcionCorta: 'Registra tu entidad, designa a Jurídico y dirige la revisión de los informes de tus contratistas.',
      precioCop: 100, // <-- PRECIO TEMPORAL DE PRUEBA ($100 COP); el real es una cuota módica
      habilitadoParaRegistro: true,
      colorPrimarioHex: 0xFF0F766E,
      colorFondoIlustracionHex: 0xFFE0F2EF,
      colorBordeTarjetaHex: 0xFF0F766E,
      grupo: grupoSupervision,
      beneficiosPrincipales: <String>[
        'Bandeja con los informes de los contratos que supervisas',
        'Aprobación o devolución con observaciones y cadena de aprobación',
        'Informe de supervisión, cuenta de cobro y registro del pago',
      ],
      todosLosBeneficios: <String>[
        'Recibes los contratos vinculados a tu dependencia y a tu cuenta',
        'Configuras periodos, valor, obligaciones y quién aprueba cada etapa',
        'Revisas cada informe con sus soportes y lo apruebas o lo devuelves',
        'La app arma el informe de supervisión y la cuenta de cobro en PDF',
        'Plantilla propia del informe (encabezado, documentos y etapas)',
      ],
      permisosPlataforma: <String>['supervision_contratos', 'pqrs'],
    ),

    // -------------------------------------------------------------------------
    // ROL 4: SUPERVISIÓN DE CONTRATOS — SUBROL CONTRATISTA (GRATIS)
    // -------------------------------------------------------------------------
    RolPaqueteConfig(
      id: 'contratista',
      nombre: 'Contratista',
      nombrePlan: 'Plan Contratista',
      etiquetaDestacada: 'Gratis',
      descripcionCorta: 'Vincula tu contrato de prestación de servicios, sube sus documentos y presenta tus informes mensuales.',
      precioCop: 0, // <-- GRATIS: no pasa por Wompi
      habilitadoParaRegistro: true,
      colorPrimarioHex: 0xFF0F766E,
      colorFondoIlustracionHex: 0xFFE0F2EF,
      colorBordeTarjetaHex: 0xFF0F766E,
      grupo: grupoSupervision,
      beneficiosPrincipales: <String>[
        'Tus contratos en un solo lugar, sin volver a buscar el enlace',
        'Carga de documentos e informes mensuales de ejecución',
        'Estado de cada informe: en revisión, devuelto, aprobado o pagado',
      ],
      todosLosBeneficios: <String>[
        'Registras tu contrato por NIT, dependencia y supervisor',
        'Subes cada documento del contrato y ves sus observaciones',
        'Diligencias y firmas tus informes de actividades en la app',
        'Sin costo para el contratista',
      ],
      permisosPlataforma: <String>['supervision_contratista', 'pqrs'],
    ),

    RolPaqueteConfig(
      id: 'juridico_supervision',
      nombre: 'Jurídico',
      nombrePlan: 'Jurídico de supervisión',
      etiquetaDestacada: 'Gratis',
      descripcionCorta:
          'Revisa los informes en las etapas que te asigna el supervisor.',
      precioCop: 0,
      habilitadoParaRegistro: true,
      colorPrimarioHex: 0xFF0F766E,
      colorFondoIlustracionHex: 0xFFE0F2EF,
      colorBordeTarjetaHex: 0xFF0F766E,
      grupo: grupoSupervision,
      beneficiosPrincipales: [
        'Bandeja de informes asignados',
        'Devolución con observaciones',
      ],
      todosLosBeneficios: [
        'Revisas los soportes y apruebas o solicitas correcciones en tu etapa',
      ],
      permisosPlataforma: ['supervision_juridico', 'pqrs'],
    ),

    // -------------------------------------------------------------------------
    // ROL 5: EMPRESA LICITANTE - VISIBLE PERO DESHABILITADO TEMPORALMENTE
    // -------------------------------------------------------------------------
    RolPaqueteConfig(
      id: 'empresa_licitante',
      nombre: 'Empresa licitante',
      nombrePlan: 'Plan Empresa Licitante',
      etiquetaDestacada: null,
      descripcionCorta: 'Encuentra oportunidades, conoce el mercado público y prepárate para participar en procesos de contratación.',
      precioCop: 89900, // <-- CAMBIA AQUÍ EL PRECIO CUANDO LO HABILITES
      habilitadoParaRegistro: false, // <-- CAMBIA A `true` PARA HABILITARLO
      colorPrimarioHex: 0xFF1F6E7A,
      colorFondoIlustracionHex: 0xFFE3F3F2,
      colorBordeTarjetaHex: 0xFFD5E9E8,
      beneficiosPrincipales: <String>[
        'Radar de licitaciones y oportunidades por sector económico',
        'Análisis competitivo de adjudicaciones y proponentes',
        'Alertas automáticas de nuevos procesos en SECOP II',
      ],
      todosLosBeneficios: <String>[
        'Incluye o se acumula con las herramientas del rol Persona',
        'Comparador avanzado de competidores y consorcios',
        'Historial de precios adjudicados por modalidad y entidad',
        'Seguimiento de cronogramas de licitación en curso',
      ],
      permisosPlataforma: <String>[
        'radar_licitaciones',
        'inteligencia_competitiva',
        'alertas_licitante',
      ],
    ),

    // -------------------------------------------------------------------------
    // ROL 6: VEEDURÍA CIUDADANA - VISIBLE PERO DESHABILITADO TEMPORALMENTE
    // -------------------------------------------------------------------------
    RolPaqueteConfig(
      id: 'veeduria_ciudadana',
      nombre: 'Veeduría ciudadana',
      nombrePlan: 'Plan Veeduría Ciudadana',
      etiquetaDestacada: null,
      descripcionCorta: 'Haz seguimiento, ejerce control social y contribuye a una contratación más transparente.',
      precioCop: 29900, // <-- CAMBIA AQUÍ EL PRECIO CUANDO LO HABILITES
      habilitadoParaRegistro: false, // <-- CAMBIA A `true` PARA HABILITARLO
      colorPrimarioHex: 0xFF5D469C,
      colorFondoIlustracionHex: 0xFFEEEAF9,
      colorBordeTarjetaHex: 0xFFE2DCF3,
      beneficiosPrincipales: <String>[
        'Herramientas de control social y seguimiento territorial',
        'Indicadores de concentración contractual y contratación directa',
        'Generación de informes técnicos para entes de control',
      ],
      todosLosBeneficios: <String>[
        'Incluye o se acumula con las herramientas del rol Persona',
        'Monitoreo de adiciones en valor y prórrogas contractuales',
        'Exportación de hallazgos y trazabilidad para veedurías',
        'Mapas de inversión pública por municipio y departamento',
      ],
      permisosPlataforma: <String>[
        'control_social_veeduria',
        'alertas_transparencia',
        'exportacion_entes_control',
      ],
    ),
  ];
}

// =============================================================================
// 2. MODELOS DE DATOS DE ROLES Y TRANSACCIONES WOMPI
// =============================================================================

class RolPaqueteConfig {
  const RolPaqueteConfig({
    required this.id,
    required this.nombre,
    required this.nombrePlan,
    required this.etiquetaDestacada,
    required this.descripcionCorta,
    required this.precioCop,
    required this.habilitadoParaRegistro,
    required this.colorPrimarioHex,
    required this.colorFondoIlustracionHex,
    required this.colorBordeTarjetaHex,
    required this.beneficiosPrincipales,
    required this.todosLosBeneficios,
    required this.permisosPlataforma,
    this.grupo,
  });

  final String id;
  final String nombre;
  final String nombrePlan;
  final String? etiquetaDestacada;
  final String descripcionCorta;
  final int precioCop;
  final bool habilitadoParaRegistro;
  final int colorPrimarioHex;
  final int colorFondoIlustracionHex;
  final int colorBordeTarjetaHex;
  final List<String> beneficiosPrincipales;
  final List<String> todosLosBeneficios;
  final List<String> permisosPlataforma;

  /// Grupo al que pertenece el rol como subrol (por ejemplo
  /// [AdminConfiguracionRolesYPagos.grupoSupervision]); null si va solo.
  final String? grupo;

  /// Se activa sin pasar por Wompi.
  bool get esGratuito => precioCop <= 0;

  Color get colorPrimario => Color(colorPrimarioHex);
  Color get colorFondoIlustracion => Color(colorFondoIlustracionHex);
  Color get colorBordeTarjeta => Color(colorBordeTarjetaHex);

  /// Wompi procesa todos los montos en centavos (ej: $100 COP = 10000 centavos).
  int get montoEnCentavosWompi => precioCop * 100;

  /// Formato legible en pesos colombianos (ej: "$100 COP" o "$49.900 COP").
  String get precioFormateadoCop {
    if (esGratuito) return 'Gratis';
    final formatted = precioCop.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '\$$formatted COP';
  }

  String get precioMensualFormateado =>
      esGratuito ? precioFormateadoCop : '$precioFormateadoCop al mes';
}

abstract final class PaymentService {
  /// Subroles de un grupo (por ejemplo Supervisor y Contratista).
  static List<RolPaqueteConfig> subrolesDe(String grupo) =>
      AdminConfiguracionRolesYPagos.catalogoRoles
          .where((r) => r.grupo == grupo)
          .toList();

  /// Retorna la lista completa de los roles configurados.
  static List<RolPaqueteConfig> obtenerCatalogoRoles() {
    return AdminConfiguracionRolesYPagos.catalogoRoles;
  }

  /// Retorna únicamente los roles actualmente habilitados para compra/activación.
  static List<RolPaqueteConfig> obtenerRolesHabilitados() {
    return AdminConfiguracionRolesYPagos.catalogoRoles
        .where((r) => r.habilitadoParaRegistro)
        .toList();
  }

  /// Obtiene la configuración oficial de un rol por su ID (`persona`, `equipo_juridico`, etc.).
  static RolPaqueteConfig obtenerConfiguracionRol(String? rolId) {
    final cleanId = normalizarRolId(rolId);
    for (final rol in AdminConfiguracionRolesYPagos.catalogoRoles) {
      if (rol.id == cleanId) return rol;
    }
    return AdminConfiguracionRolesYPagos.catalogoRoles.first;
  }

  /// Normaliza cualquier identificador o nombre antiguo ("Consulta ciudadana") al ID oficial.
  static String normalizarRolId(String? rawRole) {
    final trimmed = (rawRole ?? '').trim().toLowerCase();
    if (trimmed.isEmpty ||
        trimmed == 'persona' ||
        trimmed == 'consulta ciudadana' ||
        trimmed == 'consulta_ciudadana' ||
        trimmed == 'plan básico' ||
        trimmed == 'basico' ||
        trimmed == 'básico') {
      return 'persona';
    }
    if (trimmed == 'supervisor_contratos' ||
        trimmed == 'supervisor' ||
        trimmed == 'supervisor de contratos') {
      return 'supervisor_contratos';
    }
    if (trimmed == 'contratista' || trimmed == 'contratista_supervision') {
      return 'contratista';
    }
    if (const {
      'juridico_supervision',
      'jurídico',
      'juridico',
      'jurídico de supervisión',
    }.contains(trimmed)) {
      return 'juridico_supervision';
    }
    if (trimmed.contains('juridico') || trimmed.contains('jurídico')) {
      return 'equipo_juridico';
    }
    if (trimmed.contains('empresa') || trimmed.contains('licitante')) {
      return 'empresa_licitante';
    }
    if (trimmed.contains('veeduria') || trimmed.contains('veeduría')) {
      return 'veeduria_ciudadana';
    }
    return 'persona';
  }

  /// Convierte una lista de IDs de roles acumulados en un texto legible para el perfil y cabecera.
  /// Ejemplo: `['persona']` -> `'Persona'`
  /// Ejemplo acumulado: `['persona', 'equipo_juridico']` -> `'Persona + Equipo jurídico entidad'`
  static String formatearEtiquetaRolesAcumulados(List<String> rolesIds) {
    final normalizados = <String>[];
    for (final r in rolesIds) {
      final clean = r.trim();
      if (clean.isEmpty) continue;
      final norm = normalizarRolId(clean);
      if (!normalizados.contains(norm)) {
        normalizados.add(norm);
      }
    }
    if (normalizados.isEmpty) {
      return 'Activación pendiente de pago';
    }
    final nombres = normalizados
        .map((id) => obtenerConfiguracionRol(id).nombre)
        .toList();
    return nombres.join(' + ');
  }

  /// Verifica si un conjunto de roles activos incluye acceso a un permiso/módulo de la plataforma.
  static bool usuarioTienePermiso({
    required List<String> rolesActivos,
    required String permiso,
  }) {
    if (rolesActivos.isEmpty) return false;
    for (final rolId in rolesActivos) {
      final config = obtenerConfiguracionRol(rolId);
      if (config.permisosPlataforma.contains(permiso)) {
        return true;
      }
    }
    return false;
  }
}
