import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/modalidades_contratacion.dart';
import '../utils/dias_habiles_colombia.dart';
import '../utils/document_file_picker.dart';
import '../utils/file_downloader.dart';
import 'archivo_fragmentado.dart';
import 'auth_service.dart';
import 'equipo_juridico_service.dart';
import 'juridico_contratacion_service.dart';
import 'secop_importacion_service.dart';
import 'security_service.dart';

// =============================================================================
// Metodología: Contrata Legal acompaña, SECOP II decide.
//
// Para las modalidades distintas de prestación de servicios el proceso
// oficial se adelanta en SECOP II (publicación, ofertas, adjudicación). Aquí
// el equipo jurídico lleva su tablero interno: cronograma con plazos legales,
// control de publicación, verificación de ofertas, observaciones, borradores
// y trazabilidad. Ningún proponente entra a la plataforma.
// =============================================================================

enum EstadoProceso {
  enCurso('En curso'),
  adjudicado('Adjudicado en SECOP II'),
  desierto('Desierto en SECOP II');

  const EstadoProceso(this.etiqueta);
  final String etiqueta;

  static EstadoProceso desde(String? v) => EstadoProceso.values.firstWhere(
    (e) => e.name == v,
    orElse: () => EstadoProceso.enCurso,
  );
}

/// Resultado de verificar un requisito en una oferta o en la legalización.
enum EstadoVerificacion {
  pendiente('Pendiente'),
  cumple('Cumple'),
  subsanable('Requiere subsanar'),
  noCumple('No cumple');

  const EstadoVerificacion(this.etiqueta);
  final String etiqueta;

  static EstadoVerificacion desde(String? v) =>
      EstadoVerificacion.values.firstWhere(
        (e) => e.name == v,
        orElse: () => EstadoVerificacion.pendiente,
      );

  /// Siguiente estado al tocar la celda de la matriz.
  EstadoVerificacion get siguiente =>
      EstadoVerificacion.values[(index + 1) % EstadoVerificacion.values.length];
}

class VerificacionRequisito {
  const VerificacionRequisito({
    this.estado = EstadoVerificacion.pendiente,
    this.observacion = '',
  });

  final EstadoVerificacion estado;
  final String observacion;

  Map<String, dynamic> toMap() => {
    'estado': estado.name,
    'observacion': observacion,
  };

  factory VerificacionRequisito.fromMap(Map<String, dynamic> m) =>
      VerificacionRequisito(
        estado: EstadoVerificacion.desde(m['estado']?.toString()),
        observacion: '${m['observacion'] ?? ''}',
      );
}

Map<String, VerificacionRequisito> _verificacionesDesde(dynamic v) => v is Map
    ? {
        for (final e in v.entries)
          if (e.value is Map)
            '${e.key}': VerificacionRequisito.fromMap(
              Map<String, dynamic>.from(e.value as Map),
            ),
      }
    : {};

/// Estado agregado de una lista de verificaciones sobre unos requisitos.
enum ResultadoVerificacion {
  sinIniciar('Sin verificar'),
  enVerificacion('En verificación'),
  requiereSubsanar('Requiere subsanar'),
  noHabilitada('No habilitada'),
  habilitada('Habilitada');

  const ResultadoVerificacion(this.etiqueta);
  final String etiqueta;

  static ResultadoVerificacion calcular(
    List<DocumentoRequerido> requisitos,
    Map<String, VerificacionRequisito> verificaciones,
  ) {
    final obligatorios = requisitos.where((r) => r.obligatorio);
    final estados = [
      for (final r in obligatorios)
        verificaciones[r.id]?.estado ?? EstadoVerificacion.pendiente,
    ];
    if (estados.contains(EstadoVerificacion.noCumple)) return noHabilitada;
    if (estados.contains(EstadoVerificacion.subsanable)) {
      return requiereSubsanar;
    }
    if (estados.every((e) => e == EstadoVerificacion.cumple)) return habilitada;
    if (estados.every((e) => e == EstadoVerificacion.pendiente)) {
      return sinIniciar;
    }
    return enVerificacion;
  }
}

/// Documento interno de la entidad para una etapa. El archivo va en la
/// subcolección `archivos`; `publicadoSecop` controla el deber de publicarlo.
class DocumentoEntidadCargado {
  const DocumentoEntidadCargado({
    required this.archivoNombre,
    required this.archivoMime,
    required this.tamanoBytes,
    required this.sha256,
    required this.cargadoPor,
    required this.fechaIso,
    this.publicadoSecop = false,
    this.fechaPublicacionIso,
  });

  final String archivoNombre;
  final String archivoMime;
  final int tamanoBytes;
  final String sha256;
  final String cargadoPor;
  final String fechaIso;
  final bool publicadoSecop;
  final String? fechaPublicacionIso;

  /// Días hábiles desde la carga sin publicarse en SECOP II.
  int diasSinPublicar(DateTime hoy) {
    if (publicadoSecop) return 0;
    final carga = DateTime.tryParse(fechaIso)?.toLocal();
    if (carga == null) return 0;
    return DiasHabilesColombia.entre(carga, hoy);
  }

  bool publicacionVencida(DateTime hoy) =>
      diasSinPublicar(hoy) > diasHabilesPublicacionSecop;

  Map<String, dynamic> toMap() => {
    'archivoNombre': archivoNombre,
    'archivoMime': archivoMime,
    'tamanoBytes': tamanoBytes,
    'sha256': sha256,
    'cargadoPor': cargadoPor,
    'fechaIso': fechaIso,
    'publicadoSecop': publicadoSecop,
    'fechaPublicacionIso': fechaPublicacionIso,
  };

  factory DocumentoEntidadCargado.fromMap(Map<String, dynamic> m) =>
      DocumentoEntidadCargado(
        archivoNombre: '${m['archivoNombre'] ?? ''}',
        archivoMime: '${m['archivoMime'] ?? ''}',
        tamanoBytes: (m['tamanoBytes'] as num?)?.toInt() ?? 0,
        sha256: '${m['sha256'] ?? ''}',
        cargadoPor: '${m['cargadoPor'] ?? ''}',
        fechaIso: '${m['fechaIso'] ?? ''}',
        publicadoSecop: m['publicadoSecop'] == true,
        fechaPublicacionIso: m['fechaPublicacionIso']?.toString(),
      );
}

/// Oferta recibida en SECOP II que el equipo registra para verificarla.
/// En contratación directa es el contratista.
class OfertaRecibida {
  const OfertaRecibida({
    required this.id,
    required this.proponente,
    required this.nit,
    this.valorCop = 0,
    this.fechaRecepcionIso = '',
    this.verificaciones = const {},
    this.puntaje,
    this.nota = '',
  });

  final String id;
  final String proponente;
  final String nit;
  final int valorCop;
  final String fechaRecepcionIso;
  final Map<String, VerificacionRequisito> verificaciones;
  final double? puntaje;
  final String nota;

  Map<String, dynamic> toMap() => {
    'id': id,
    'proponente': proponente,
    'nit': nit,
    'valorCop': valorCop,
    'fechaRecepcionIso': fechaRecepcionIso,
    'verificaciones': {
      for (final e in verificaciones.entries) e.key: e.value.toMap(),
    },
    'puntaje': puntaje,
    'nota': nota,
  };

  factory OfertaRecibida.fromMap(Map<String, dynamic> m) => OfertaRecibida(
    id: '${m['id'] ?? ''}',
    proponente: '${m['proponente'] ?? ''}',
    nit: '${m['nit'] ?? ''}',
    valorCop: (m['valorCop'] as num?)?.toInt() ?? 0,
    fechaRecepcionIso: '${m['fechaRecepcionIso'] ?? ''}',
    verificaciones: _verificacionesDesde(m['verificaciones']),
    puntaje: (m['puntaje'] as num?)?.toDouble(),
    nota: '${m['nota'] ?? ''}',
  );

  OfertaRecibida copyWith({
    Map<String, VerificacionRequisito>? verificaciones,
    int? valorCop,
    double? puntaje,
    String? nota,
  }) => OfertaRecibida(
    id: id,
    proponente: proponente,
    nit: nit,
    valorCop: valorCop ?? this.valorCop,
    fechaRecepcionIso: fechaRecepcionIso,
    verificaciones: verificaciones ?? this.verificaciones,
    puntaje: puntaje ?? this.puntaje,
    nota: nota ?? this.nota,
  );
}

/// Observación de un interesado recibida en SECOP II y su respuesta.
class ObservacionProceso {
  const ObservacionProceso({
    required this.id,
    required this.interesado,
    required this.fechaIso,
    required this.etapaId,
    required this.texto,
    this.respuesta = '',
    this.responsable = '',
  });

  final String id;
  final String interesado;
  final String fechaIso;
  final String etapaId;
  final String texto;
  final String respuesta;
  final String responsable;

  bool get respondida => respuesta.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'id': id,
    'interesado': interesado,
    'fechaIso': fechaIso,
    'etapaId': etapaId,
    'texto': texto,
    'respuesta': respuesta,
    'responsable': responsable,
  };

  factory ObservacionProceso.fromMap(Map<String, dynamic> m) =>
      ObservacionProceso(
        id: '${m['id'] ?? ''}',
        interesado: '${m['interesado'] ?? ''}',
        fechaIso: '${m['fechaIso'] ?? ''}',
        etapaId: '${m['etapaId'] ?? ''}',
        texto: '${m['texto'] ?? ''}',
        respuesta: '${m['respuesta'] ?? ''}',
        responsable: '${m['responsable'] ?? ''}',
      );
}

/// Resultado publicado en SECOP II: aquí solo se registra.
class ResultadoProceso {
  const ResultadoProceso({
    required this.adjudicado,
    required this.actoNumero,
    required this.fechaIso,
    this.ofertaId,
    this.proponente = '',
    this.valorCop = 0,
    this.motivo = '',
  });

  final bool adjudicado;
  final String actoNumero;
  final String fechaIso;
  final String? ofertaId;
  final String proponente;
  final int valorCop;
  final String motivo;

  Map<String, dynamic> toMap() => {
    'adjudicado': adjudicado,
    'actoNumero': actoNumero,
    'fechaIso': fechaIso,
    'ofertaId': ofertaId,
    'proponente': proponente,
    'valorCop': valorCop,
    'motivo': motivo,
  };

  factory ResultadoProceso.fromMap(Map<String, dynamic> m) => ResultadoProceso(
    adjudicado: m['adjudicado'] == true,
    actoNumero: '${m['actoNumero'] ?? ''}',
    fechaIso: '${m['fechaIso'] ?? ''}',
    ofertaId: m['ofertaId']?.toString(),
    proponente: '${m['proponente'] ?? ''}',
    valorCop: (m['valorCop'] as num?)?.toInt() ?? 0,
    motivo: '${m['motivo'] ?? ''}',
  );
}

/// Estado de un hito del cronograma frente a su plazo legal.
class EstadoHito {
  const EstadoHito({required this.hito, this.fecha, this.limite, this.cumple});

  final HitoCronograma hito;
  final DateTime? fecha;

  /// Fecha mínima (o máxima) que exige la regla, si ya se conoce la fecha
  /// del hito de referencia.
  final DateTime? limite;

  /// `null` mientras falte alguna de las dos fechas.
  final bool? cumple;
}

class ProcesoContratacion {
  const ProcesoContratacion({
    required this.id,
    required this.modalidadId,
    required this.equipoUid,
    required this.creadoPorUid,
    required this.creadoPorNombre,
    required this.entidadNombre,
    required this.entidadNit,
    required this.dependencia,
    required this.numeroProceso,
    required this.objeto,
    required this.presupuestoCop,
    required this.plazoEjecucion,
    required this.fechaCreacionIso,
    this.idProcesoSecop = '',
    this.urlSecop = '',
    this.campos = const {},
    this.etapaActual = 0,
    this.documentosEntidad = const {},
    this.cronograma = const {},
    this.responsables = const {},
    this.ofertas = const [],
    this.observaciones = const [],
    this.resultado,
    this.legalizacion = const {},
    this.estado = EstadoProceso.enCurso,
    this.trazabilidad = const [],
    this.actualizadoEnMs = 0,
    this.origen = 'manual',
    this.secop,
    this.secopSincronizadoEnIso = '',
    this.secopNovedades = const [],
  });

  final String id;
  final String modalidadId;
  final String equipoUid;
  final String creadoPorUid;
  final String creadoPorNombre;
  final String entidadNombre;
  final String entidadNit;
  final String dependencia;

  /// Referencia del proceso (la misma de SECOP II, p. ej. LP-003-2026).
  final String numeroProceso;
  final String objeto;
  final int presupuestoCop;
  final String plazoEjecucion;
  final String fechaCreacionIso;

  /// ID del proceso en SECOP II (CO1.REQ… o CO1.NTC…) y enlace público.
  final String idProcesoSecop;
  final String urlSecop;
  final Map<String, String> campos;
  final int etapaActual;
  final Map<String, DocumentoEntidadCargado> documentosEntidad;

  /// Fecha (aaaa-mm-dd) de cada hito, registrada desde SECOP II.
  final Map<String, String> cronograma;

  /// Abogado responsable de cada etapa.
  final Map<String, String> responsables;
  final List<OfertaRecibida> ofertas;
  final List<ObservacionProceso> observaciones;
  final ResultadoProceso? resultado;

  /// Verificación de los requisitos de legalización del contrato.
  final Map<String, VerificacionRequisito> legalizacion;
  final EstadoProceso estado;
  final List<EventoTrazabilidadContrato> trazabilidad;
  final int actualizadoEnMs;

  /// `importado` si se trajo de SECOP II; `manual` si se registró a mano.
  final String origen;

  /// Última fotografía del proceso en SECOP II y lo que cambió en la última
  /// sincronización (pendiente de que el equipo lo revise).
  final ProcesoSecop? secop;
  final String secopSincronizadoEnIso;
  final List<String> secopNovedades;

  bool get importado => origen == 'importado';

  ModalidadContratacion get modalidad =>
      modalidadPorId(modalidadId) ?? modalidadesContratacion.last;

  bool get esDirecta => !modalidad.esCompetitiva;

  /// Requisitos que se verifican en cada oferta (o en el contratista, en
  /// contratación directa).
  List<DocumentoRequerido> get requisitosVerificacion =>
      esDirecta ? modalidad.documentosContrato : modalidad.documentosOferente;

  DateTime? fechaHito(String id) {
    final v = cronograma[id];
    return v == null || v.isEmpty ? null : DateTime.tryParse(v);
  }

  List<EstadoHito> evaluarCronograma() => [
    for (final h in modalidad.hitos) _evaluarHito(h),
  ];

  EstadoHito _evaluarHito(HitoCronograma h) {
    final fecha = fechaHito(h.id);
    final regla = h.regla;
    final referencia = regla == null ? null : fechaHito(regla.desdeHito);
    final limite = referencia == null
        ? null
        : DiasHabilesColombia.sumar(referencia, regla!.diasHabiles);
    bool? cumple;
    if (fecha != null && limite != null) {
      cumple = regla!.minimo ? !fecha.isBefore(limite) : !fecha.isAfter(limite);
    }
    return EstadoHito(hito: h, fecha: fecha, limite: limite, cumple: cumple);
  }

  /// Hitos registrados que incumplen su plazo legal.
  List<EstadoHito> get alertasCronograma =>
      evaluarCronograma().where((e) => e.cumple == false).toList();

  /// Documentos cargados que llevan más de 3 días hábiles sin publicarse.
  List<String> publicacionesVencidas(DateTime hoy) => [
    for (final e in documentosEntidad.entries)
      if (e.value.publicacionVencida(hoy)) e.key,
  ];

  OfertaRecibida? get ofertaAdjudicada {
    for (final o in ofertas) {
      if (o.id == resultado?.ofertaId) return o;
    }
    return null;
  }

  List<DocumentoRequerido> pendientesDeEtapa(int indice) {
    final etapas = modalidad.etapas;
    if (indice < 0 || indice >= etapas.length) return const [];
    return etapas[indice].documentosEntidad
        .where((d) => d.obligatorio && !documentosEntidad.containsKey(d.id))
        .toList();
  }

  double get avanceDocumentosEntidad {
    final obligatorios = modalidad.documentosEntidad.where(
      (d) => d.obligatorio,
    );
    if (obligatorios.isEmpty) return 1;
    final cargados = obligatorios.where(
      (d) => documentosEntidad.containsKey(d.id),
    );
    return cargados.length / obligatorios.length;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'modalidadId': modalidadId,
    'equipoUid': equipoUid,
    'creadoPorUid': creadoPorUid,
    'creadoPorNombre': creadoPorNombre,
    'entidadNombre': entidadNombre,
    'entidadNit': entidadNit,
    'dependencia': dependencia,
    'numeroProceso': numeroProceso,
    'objeto': objeto,
    'presupuestoCop': presupuestoCop,
    'plazoEjecucion': plazoEjecucion,
    'fechaCreacionIso': fechaCreacionIso,
    'idProcesoSecop': idProcesoSecop,
    'urlSecop': urlSecop,
    'campos': campos,
    'etapaActual': etapaActual,
    'documentosEntidad': {
      for (final e in documentosEntidad.entries) e.key: e.value.toMap(),
    },
    'cronograma': cronograma,
    'responsables': responsables,
    'ofertas': ofertas.map((o) => o.toMap()).toList(),
    'observaciones': observaciones.map((o) => o.toMap()).toList(),
    'resultado': resultado?.toMap(),
    'legalizacion': {
      for (final e in legalizacion.entries) e.key: e.value.toMap(),
    },
    'estado': estado.name,
    'trazabilidad': trazabilidad.map((e) => e.toMap()).toList(),
    'actualizadoEnMs': actualizadoEnMs,
    'origen': origen,
    'secop': secop?.toMap(),
    'secopSincronizadoEnIso': secopSincronizadoEnIso,
    'secopNovedades': secopNovedades,
  };

  factory ProcesoContratacion.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic> mapa(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    List<Map<String, dynamic>> lista(dynamic v) => [
      for (final e in (v as List? ?? const []))
        if (e is Map) Map<String, dynamic>.from(e),
    ];
    return ProcesoContratacion(
      id: '${m['id'] ?? ''}',
      modalidadId: '${m['modalidadId'] ?? ''}',
      equipoUid: '${m['equipoUid'] ?? ''}',
      creadoPorUid: '${m['creadoPorUid'] ?? ''}',
      creadoPorNombre: '${m['creadoPorNombre'] ?? ''}',
      entidadNombre: '${m['entidadNombre'] ?? ''}',
      entidadNit: '${m['entidadNit'] ?? ''}',
      dependencia: '${m['dependencia'] ?? ''}',
      numeroProceso: '${m['numeroProceso'] ?? ''}',
      objeto: '${m['objeto'] ?? ''}',
      presupuestoCop: (m['presupuestoCop'] as num?)?.toInt() ?? 0,
      plazoEjecucion: '${m['plazoEjecucion'] ?? ''}',
      fechaCreacionIso: '${m['fechaCreacionIso'] ?? ''}',
      idProcesoSecop: '${m['idProcesoSecop'] ?? ''}',
      urlSecop: '${m['urlSecop'] ?? ''}',
      campos: mapa(m['campos']).map((k, v) => MapEntry(k, '$v')),
      etapaActual: (m['etapaActual'] as num?)?.toInt() ?? 0,
      documentosEntidad: mapa(m['documentosEntidad'])
          .map((k, v) => MapEntry(k, DocumentoEntidadCargado.fromMap(mapa(v)))),
      cronograma: mapa(m['cronograma']).map((k, v) => MapEntry(k, '$v')),
      responsables: mapa(m['responsables']).map((k, v) => MapEntry(k, '$v')),
      ofertas: lista(m['ofertas']).map(OfertaRecibida.fromMap).toList(),
      observaciones: lista(m['observaciones'])
          .map(ObservacionProceso.fromMap)
          .toList(),
      resultado: m['resultado'] is Map
          ? ResultadoProceso.fromMap(mapa(m['resultado']))
          : null,
      legalizacion: _verificacionesDesde(m['legalizacion']),
      estado: EstadoProceso.desde(m['estado']?.toString()),
      trazabilidad: lista(m['trazabilidad'])
          .map(EventoTrazabilidadContrato.fromMap)
          .toList(),
      actualizadoEnMs: (m['actualizadoEnMs'] as num?)?.toInt() ?? 0,
      origen: '${m['origen'] ?? 'manual'}',
      secop: m['secop'] is Map ? ProcesoSecop.fromMap(mapa(m['secop'])) : null,
      secopSincronizadoEnIso: '${m['secopSincronizadoEnIso'] ?? ''}',
      secopNovedades: [
        for (final n in (m['secopNovedades'] as List? ?? const [])) '$n',
      ],
    );
  }
}

class ProcesoContratacionException implements Exception {
  const ProcesoContratacionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Tablero interno de procesos del equipo jurídico en Firestore.
class ProcesosContratacionService {
  ProcesosContratacionService._();

  static const String coleccion = 'procesos_contratacion';

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(coleccion);

  static String _ahoraIso() => DateTime.now().toUtc().toIso8601String();

  static String fechaCorta(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _limpio(String v, int max) =>
      SecurityService.sanitizePlainText(v, maxLength: max);

  static EventoTrazabilidadContrato _evento(
    String tipo,
    String titulo,
    String detalle,
  ) => EventoTrazabilidadContrato(
    id: 'EVT-${SecurityService.generateSecureTokenHex(6)}',
    fechaIso: _ahoraIso(),
    tipo: tipo,
    actorNombre: AuthService.getActiveUserDisplayName(),
    actorRol: EquipoJuridicoService.esMiembroVigente
        ? 'Abogado del equipo'
        : 'Equipo jurídico',
    titulo: titulo,
    detalle: detalle,
  );

  static void _exigir(PermisoEquipo permiso) {
    if (!EquipoJuridicoService.tienePermiso(permiso)) {
      throw ProcesoContratacionException(
        'Tu usuario del equipo no tiene el permiso "${permiso.etiqueta}".',
      );
    }
  }

  static Stream<List<ProcesoContratacion>> escucharProcesos() {
    final equipo = EquipoJuridicoService.equipoUidActivo;
    if (equipo.isEmpty) return Stream.value(const []);
    return _col
        .where('equipoUid', isEqualTo: equipo)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => ProcesoContratacion.fromMap(d.data()))
                  .toList()
                ..sort(
                  (a, b) => b.fechaCreacionIso.compareTo(a.fechaCreacionIso),
                ),
        );
  }

  static Stream<ProcesoContratacion?> escucharProceso(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (d) => d.data() == null ? null : ProcesoContratacion.fromMap(d.data()!),
      );

  static Future<ProcesoContratacion> crearProceso({
    required ModalidadContratacion modalidad,
    required String entidadNombre,
    required String entidadNit,
    required String dependencia,
    required String numeroProceso,
    required String objeto,
    required int presupuestoCop,
    required String plazoEjecucion,
    required Map<String, String> campos,
    String idProcesoSecop = '',
  }) async {
    _exigir(PermisoEquipo.crearContratos);
    if (_limpio(entidadNombre, 200).isEmpty ||
        _limpio(numeroProceso, 80).isEmpty ||
        _limpio(objeto, 2000).isEmpty) {
      throw const ProcesoContratacionException(
        'La entidad, el número del proceso y el objeto son obligatorios.',
      );
    }
    for (final c in modalidad.campos.where((c) => c.obligatorio)) {
      if ((campos[c.id] ?? '').trim().isEmpty) {
        throw ProcesoContratacionException(
          'Completa el campo "${c.etiqueta}".',
        );
      }
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ProcesoContratacionException('Inicia sesión nuevamente.');
    }

    final proceso = ProcesoContratacion(
      id: SecurityService.generateSecureTokenHex(16),
      modalidadId: modalidad.id,
      equipoUid: EquipoJuridicoService.equipoUidActivo,
      creadoPorUid: user.uid,
      creadoPorNombre: AuthService.getActiveUserDisplayName(),
      entidadNombre: _limpio(entidadNombre, 200),
      entidadNit: SecurityService.normalizeDocumentDigits(entidadNit),
      dependencia: _limpio(dependencia, 160),
      numeroProceso: _limpio(numeroProceso, 80),
      objeto: _limpio(objeto, 2000),
      presupuestoCop: presupuestoCop < 0 ? 0 : presupuestoCop,
      plazoEjecucion: _limpio(plazoEjecucion, 90),
      fechaCreacionIso: _ahoraIso(),
      idProcesoSecop: _limpio(idProcesoSecop, 60).toUpperCase(),
      campos: {
        for (final c in modalidad.campos)
          if ((campos[c.id] ?? '').trim().isNotEmpty)
            c.id: _limpio(campos[c.id]!, 300),
      },
      trazabilidad: [
        _evento(
          'CREACION_PROCESO',
          'Creó el seguimiento del proceso ${_limpio(numeroProceso, 80)}',
          'Modalidad: ${modalidad.nombre}.',
        ),
      ],
      actualizadoEnMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _col.doc(proceso.id).set(proceso.toMap());
    return proceso;
  }

  static Future<void> _actualizar(
    ProcesoContratacion p,
    Map<String, dynamic> cambios,
    EventoTrazabilidadContrato evento,
  ) async {
    await _col.doc(p.id).update({
      ...cambios,
      'trazabilidad': [evento.toMap(), ...p.trazabilidad.map((e) => e.toMap())],
      'actualizadoEnMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ---------------------------------------------------------------------------
  // Vínculo con SECOP II
  // ---------------------------------------------------------------------------

  static Future<void> actualizarVinculoSecop(
    ProcesoContratacion p, {
    required String idProceso,
    String url = '',
  }) async {
    _exigir(PermisoEquipo.crearContratos);
    final id = _limpio(idProceso, 60).toUpperCase();
    final enlace = url.trim();
    if (enlace.isNotEmpty && !enlace.startsWith('https://')) {
      throw const ProcesoContratacionException(
        'El enlace debe empezar por https://',
      );
    }
    await _actualizar(p, {
      'idProcesoSecop': id,
      'urlSecop': enlace,
    }, _evento('VINCULO_SECOP', 'Vinculó el proceso de SECOP II $id', ''));
  }

  // ---------------------------------------------------------------------------
  // Importación y sincronización con SECOP II
  // ---------------------------------------------------------------------------

  /// Fechas de SECOP II que corresponden a hitos del cronograma de la modalidad.
  static Map<String, String> _cronogramaDesde(
    ModalidadContratacion modalidad,
    ProcesoSecop s,
    Map<String, String> actual,
  ) {
    final hitos = {for (final h in modalidad.hitos) h.id};
    final candidatos = <String, String?>{
      'cierre': s.fechas['recepcionOfertas'],
      'adjudicacion': s.fechas['adjudicacion'],
      'aceptacion': s.fechas['adjudicacion'],
      'seleccion': s.fechas['adjudicacion'],
      'audiencia_adjudicacion': s.fechas['adjudicacion'],
      if (modalidad.hitos.isNotEmpty)
        modalidad.hitos.first.id: s.fechas['publicacion'],
    };
    return {
      ...actual,
      for (final e in candidatos.entries)
        if (hitos.contains(e.key) &&
            (e.value ?? '').isNotEmpty &&
            (actual[e.key] ?? '').isEmpty)
          e.key: e.value!,
    };
  }

  /// Crea el seguimiento de un proceso que ya existe en SECOP II.
  static Future<ProcesoContratacion> importarDesdeSecop(
    ProcesoSecop s, {
    required ModalidadContratacion modalidad,
  }) async {
    _exigir(PermisoEquipo.crearContratos);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ProcesoContratacionException('Inicia sesión nuevamente.');
    }
    final equipo = EquipoJuridicoService.equipoUidActivo;
    final repetido = await _col
        .where('equipoUid', isEqualTo: equipo)
        .where('idProcesoSecop', isEqualTo: s.idProceso)
        .limit(1)
        .get();
    if (repetido.docs.isNotEmpty) {
      throw const ProcesoContratacionException(
        'Este proceso ya está importado en el equipo. Búscalo en el panel de seguimiento.',
      );
    }
    final numero = _limpio(
      s.referencia.isEmpty ? s.idProceso : s.referencia,
      80,
    );
    final objeto = _limpio(
      s.descripcion.isEmpty
          ? (s.nombre.isEmpty ? numero : s.nombre)
          : s.descripcion,
      2000,
    );
    final ahora = _ahoraIso();
    final proceso = ProcesoContratacion(
      id: SecurityService.generateSecureTokenHex(16),
      modalidadId: modalidad.id,
      equipoUid: equipo,
      creadoPorUid: user.uid,
      creadoPorNombre: AuthService.getActiveUserDisplayName(),
      entidadNombre: _limpio(s.entidad, 200),
      entidadNit: SecurityService.normalizeDocumentDigits(s.nit),
      dependencia: _limpio(s.unidad, 160),
      numeroProceso: numero,
      objeto: objeto,
      presupuestoCop: s.precioBase,
      plazoEjecucion: _limpio(s.duracion, 90),
      fechaCreacionIso: ahora,
      idProcesoSecop: s.idProceso,
      urlSecop: s.url,
      cronograma: _cronogramaDesde(modalidad, s, const {}),
      origen: 'importado',
      secop: s,
      secopSincronizadoEnIso: ahora,
      trazabilidad: [
        _evento(
          'IMPORTACION_SECOP',
          'Importó el proceso ${s.idProceso} desde SECOP II',
          'Estado en SECOP II: ${s.estadoVisible}. ${s.documentos.length} documentos publicados.',
        ),
      ],
      actualizadoEnMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _col.doc(proceso.id).set(proceso.toMap());
    return proceso;
  }

  /// Vuelve a consultar SECOP II y guarda lo que cambió. Devuelve las
  /// novedades encontradas (vacío si no hubo cambios).
  static Future<List<String>> sincronizarConSecop(ProcesoContratacion p) async {
    final id = p.idProcesoSecop.isNotEmpty ? p.idProcesoSecop : p.urlSecop;
    if (SecopImportacionService.extraerIdentificador(id) == null) {
      throw const ProcesoContratacionException(
        'Este proceso no tiene ID de SECOP II. Vincúlalo primero.',
      );
    }
    final ProcesoSecop? nuevo;
    try {
      nuevo = await SecopImportacionService.buscar(id);
    } on SecopImportacionException catch (e) {
      throw ProcesoContratacionException(e.message);
    }
    if (nuevo == null) {
      throw const ProcesoContratacionException(
        'Datos Abiertos aún no reporta este proceso (se actualiza una vez al día).',
      );
    }
    final novedades = p.secop == null
        ? <String>[
            'Primera sincronización con SECOP II: ${nuevo.estadoVisible}.',
          ]
        : SecopImportacionService.novedades(p.secop!, nuevo);
    final ahora = _ahoraIso();
    final cambios = <String, dynamic>{
      'secop': nuevo.toMap(),
      'secopSincronizadoEnIso': ahora,
      if (novedades.isNotEmpty)
        'secopNovedades': {...p.secopNovedades, ...novedades}.toList(),
      if (p.idProcesoSecop != nuevo.idProceso && nuevo.idProceso.isNotEmpty)
        'idProcesoSecop': nuevo.idProceso,
      if (p.urlSecop.isEmpty && nuevo.url.isNotEmpty) 'urlSecop': nuevo.url,
      'cronograma': _cronogramaDesde(p.modalidad, nuevo, p.cronograma),
    };
    if (novedades.isEmpty) {
      await _col.doc(p.id).update({
        ...cambios,
        'actualizadoEnMs': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await _actualizar(
        p,
        cambios,
        _evento(
          'SINCRONIZACION_SECOP',
          'Sincronizó con SECOP II',
          novedades.join(' · '),
        ),
      );
    }
    return novedades;
  }

  /// El equipo ya revisó las novedades de SECOP II.
  static Future<void> marcarNovedadesRevisadas(ProcesoContratacion p) =>
      _col.doc(p.id).update({'secopNovedades': <String>[]});

  // ---------------------------------------------------------------------------
  // Cronograma, responsables y etapas
  // ---------------------------------------------------------------------------

  static Future<void> registrarFechaHito(
    ProcesoContratacion p,
    HitoCronograma hito,
    DateTime? fecha,
  ) async {
    _exigir(PermisoEquipo.crearContratos);
    await _actualizar(
      p,
      {
        'cronograma.${hito.id}': fecha == null
            ? FieldValue.delete()
            : fechaCorta(fecha),
      },
      _evento(
        'CRONOGRAMA',
        fecha == null
            ? 'Quitó la fecha de "${hito.nombre}"'
            : 'Registró "${hito.nombre}" el ${fechaCorta(fecha)}',
        '',
      ),
    );
  }

  static Future<void> asignarResponsable(
    ProcesoContratacion p,
    EtapaProceso etapa,
    String responsable,
  ) async {
    _exigir(PermisoEquipo.crearContratos);
    final r = _limpio(responsable, 120);
    await _actualizar(
      p,
      {'responsables.${etapa.id}': r},
      _evento(
        'RESPONSABLE',
        'Asignó "${etapa.nombre}" a ${r.isEmpty ? 'nadie' : r}',
        '',
      ),
    );
  }

  /// Pasa a la siguiente etapa. Exige los documentos obligatorios de la
  /// etapa actual para dejar el expediente interno completo.
  static Future<void> avanzarEtapa(ProcesoContratacion p) async {
    _exigir(PermisoEquipo.crearContratos);
    final etapas = p.modalidad.etapas;
    if (p.etapaActual >= etapas.length - 1) return;
    final faltan = p.pendientesDeEtapa(p.etapaActual);
    if (faltan.isNotEmpty) {
      throw ProcesoContratacionException(
        'Antes de avanzar carga: ${faltan.map((d) => d.nombre).join(', ')}.',
      );
    }
    final siguiente = etapas[p.etapaActual + 1];
    await _actualizar(p, {
      'etapaActual': p.etapaActual + 1,
    }, _evento('AVANCE_ETAPA', 'Pasó a la etapa "${siguiente.nombre}"', ''));
  }

  static Future<void> retrocederEtapa(ProcesoContratacion p) async {
    _exigir(PermisoEquipo.crearContratos);
    if (p.etapaActual == 0) return;
    final anterior = p.modalidad.etapas[p.etapaActual - 1];
    await _actualizar(
      p,
      {'etapaActual': p.etapaActual - 1},
      _evento('RETROCESO_ETAPA', 'Regresó a la etapa "${anterior.nombre}"', ''),
    );
  }

  // ---------------------------------------------------------------------------
  // Eliminación
  // ---------------------------------------------------------------------------

  /// Pueden eliminar el proceso quien lo creó, el Master del equipo y los
  /// abogados con permiso para crear contratos.
  static bool puedeEliminar(ProcesoContratacion p) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return false;
    if (p.creadoPorUid == uid || p.equipoUid == uid) return true;
    return EquipoJuridicoService.equipoUidActivo == p.equipoUid &&
        EquipoJuridicoService.tienePermiso(PermisoEquipo.crearContratos);
  }

  /// Elimina el proceso con sus documentos internos. Lo que esté publicado
  /// en SECOP II no se toca. Devuelve `null` si se eliminó o el motivo.
  static Future<String?> eliminarProceso(ProcesoContratacion p) async {
    if (!puedeEliminar(p)) {
      return 'solo quien lo creó, el titular del equipo o un abogado con '
          'permiso para crear contratos puede eliminarlo.';
    }
    final ref = _col.doc(p.id);
    try {
      // Primero los documentos: las reglas los autorizan leyendo el proceso.
      final archivos = await ref
          .collection('archivos')
          .get()
          .timeout(const Duration(seconds: 15));
      for (final archivo in archivos.docs) {
        final partes = archivo.data()['partes'];
        if (partes is int) {
          for (var i = 0; i < partes; i++) {
            await archivo.reference.collection('partes').doc('$i').delete();
          }
        }
        await archivo.reference.delete();
      }
      await ref.delete().timeout(const Duration(seconds: 10));
    } on FirebaseException catch (e) {
      debugPrint('eliminarProceso: ${e.code} ${e.message}');
      return e.code == 'permission-denied'
          ? 'no tienes permiso para eliminarlo. Si acabas de actualizar la '
                'app, publica de nuevo las reglas de Firestore.'
          : 'no fue posible conectar con el servidor. Intenta de nuevo.';
    } on TimeoutException {
      return 'el servidor no respondió. Revisa tu conexión e intenta de nuevo.';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Documentos internos y control de publicación en SECOP II
  // ---------------------------------------------------------------------------

  static Future<void> cargarDocumentoEntidad(
    ProcesoContratacion p,
    DocumentoRequerido documento,
  ) async {
    _exigir(PermisoEquipo.crearContratos);
    final archivo = await pickContractDocumentFile();
    if (archivo == null) return;
    if (!archivo.isValid) {
      throw ProcesoContratacionException(
        archivo.errorMessage ?? 'El archivo seleccionado no es válido.',
      );
    }
    final cargado = DocumentoEntidadCargado(
      archivoNombre: archivo.fileName,
      archivoMime: archivo.mimeType,
      tamanoBytes: archivo.sizeBytes,
      sha256: archivo.sha256Hash,
      cargadoPor: AuthService.getActiveUserDisplayName(),
      fechaIso: _ahoraIso(),
    );
    await ArchivoFragmentado.guardar(
      _col.doc(p.id).collection('archivos').doc(documento.id),
      base64: base64Encode(archivo.bytes),
      metadatos: cargado.toMap(),
    );
    await _actualizar(
      p,
      {'documentosEntidad.${documento.id}': cargado.toMap()},
      _evento(
        'DOCUMENTO_ENTIDAD',
        'Cargó ${documento.nombre}',
        '${archivo.fileName} (${archivo.formattedSize}). Pendiente de publicar en SECOP II.',
      ),
    );
  }

  static Future<void> descargarDocumentoEntidad(
    ProcesoContratacion p,
    String documentoId,
  ) async {
    Map<String, dynamic>? data;
    final b64 = await ArchivoFragmentado.leer(
      _col.doc(p.id).collection('archivos').doc(documentoId),
      metadatos: (m) => data = m,
    );
    if (b64 == null || b64.isEmpty) {
      throw const ProcesoContratacionException('No se encontró el archivo.');
    }
    downloadBinaryBytes(
      bytes: base64Decode(b64),
      fileName: '${data?['archivoNombre'] ?? 'documento'}',
      mimeType: '${data?['archivoMime'] ?? 'application/octet-stream'}',
    );
  }

  static Future<void> marcarPublicacion(
    ProcesoContratacion p,
    DocumentoRequerido documento, {
    required bool publicado,
    DateTime? fecha,
  }) async {
    _exigir(PermisoEquipo.crearContratos);
    final actual = p.documentosEntidad[documento.id];
    if (actual == null) {
      throw const ProcesoContratacionException('Primero carga el documento.');
    }
    final nuevo = DocumentoEntidadCargado(
      archivoNombre: actual.archivoNombre,
      archivoMime: actual.archivoMime,
      tamanoBytes: actual.tamanoBytes,
      sha256: actual.sha256,
      cargadoPor: actual.cargadoPor,
      fechaIso: actual.fechaIso,
      publicadoSecop: publicado,
      fechaPublicacionIso: publicado
          ? fechaCorta(fecha ?? DateTime.now())
          : null,
    );
    await _actualizar(
      p,
      {'documentosEntidad.${documento.id}': nuevo.toMap()},
      _evento(
        'PUBLICACION_SECOP',
        publicado
            ? 'Marcó ${documento.nombre} como publicado en SECOP II'
            : 'Desmarcó la publicación de ${documento.nombre}',
        publicado ? 'Fecha de publicación: ${nuevo.fechaPublicacionIso}' : '',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ofertas recibidas en SECOP II y matriz de verificación
  // ---------------------------------------------------------------------------

  static Future<void> registrarOferta(
    ProcesoContratacion p, {
    required String proponente,
    required String nit,
    int valorCop = 0,
    DateTime? fechaRecepcion,
  }) async {
    _exigir(PermisoEquipo.verificarDocumentos);
    final nombre = _limpio(proponente, 160);
    if (nombre.isEmpty) {
      throw const ProcesoContratacionException(
        'Escribe el nombre del proponente.',
      );
    }
    if (p.esDirecta && p.ofertas.isNotEmpty) {
      throw const ProcesoContratacionException(
        'En contratación directa se verifica un solo contratista.',
      );
    }
    final oferta = OfertaRecibida(
      id: 'OF-${SecurityService.generateSecureTokenHex(4)}',
      proponente: nombre,
      nit: SecurityService.normalizeDocumentDigits(nit),
      valorCop: valorCop < 0 ? 0 : valorCop,
      fechaRecepcionIso: fechaRecepcion == null
          ? ''
          : fechaCorta(fechaRecepcion),
    );
    await _actualizar(
      p,
      {
        'ofertas': [...p.ofertas.map((o) => o.toMap()), oferta.toMap()],
      },
      _evento(
        'OFERTA',
        p.esDirecta
            ? 'Registró al contratista $nombre para verificación'
            : 'Registró la oferta de $nombre recibida en SECOP II',
        '',
      ),
    );
  }

  static Future<void> _guardarOferta(
    ProcesoContratacion p,
    OfertaRecibida oferta,
    EventoTrazabilidadContrato evento,
  ) => _actualizar(p, {
    'ofertas': [
      for (final o in p.ofertas) (o.id == oferta.id ? oferta : o).toMap(),
    ],
  }, evento);

  static Future<void> verificarRequisito(
    ProcesoContratacion p,
    OfertaRecibida oferta,
    DocumentoRequerido requisito,
    VerificacionRequisito verificacion,
  ) async {
    _exigir(PermisoEquipo.verificarDocumentos);
    await _guardarOferta(
      p,
      oferta.copyWith(
        verificaciones: {
          ...oferta.verificaciones,
          requisito.id: VerificacionRequisito(
            estado: verificacion.estado,
            observacion: _limpio(verificacion.observacion, 500),
          ),
        },
      ),
      _evento(
        'VERIFICACION',
        '${oferta.proponente}: ${requisito.nombre} → ${verificacion.estado.etiqueta}',
        verificacion.observacion.trim(),
      ),
    );
  }

  static Future<void> calificarOferta(
    ProcesoContratacion p,
    OfertaRecibida oferta, {
    int? valorCop,
    double? puntaje,
    String? nota,
  }) async {
    _exigir(PermisoEquipo.verificarDocumentos);
    await _guardarOferta(
      p,
      oferta.copyWith(
        valorCop: valorCop,
        puntaje: puntaje,
        nota: nota == null ? null : _limpio(nota, 500),
      ),
      _evento(
        'CALIFICACION',
        'Actualizó la calificación de ${oferta.proponente}',
        [
          if (valorCop != null && valorCop > 0) 'Valor: \$$valorCop',
          if (puntaje != null) 'Puntaje: $puntaje',
        ].join(' · '),
      ),
    );
  }

  static Future<void> quitarOferta(
    ProcesoContratacion p,
    OfertaRecibida oferta,
  ) async {
    _exigir(PermisoEquipo.verificarDocumentos);
    await _actualizar(
      p,
      {
        'ofertas': [
          for (final o in p.ofertas)
            if (o.id != oferta.id) o.toMap(),
        ],
      },
      _evento(
        'OFERTA',
        'Quitó la oferta de ${oferta.proponente} del registro',
        '',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Observaciones y respuestas
  // ---------------------------------------------------------------------------

  static Future<void> registrarObservacion(
    ProcesoContratacion p, {
    required String interesado,
    required String texto,
    required String etapaId,
    DateTime? fecha,
  }) async {
    _exigir(PermisoEquipo.pedirDocumentos);
    final t = _limpio(texto, 3000);
    if (t.isEmpty) {
      throw const ProcesoContratacionException(
        'Escribe la observación recibida.',
      );
    }
    final obs = ObservacionProceso(
      id: 'OB-${SecurityService.generateSecureTokenHex(4)}',
      interesado: _limpio(interesado, 160),
      fechaIso: fechaCorta(fecha ?? DateTime.now()),
      etapaId: etapaId,
      texto: t,
    );
    await _actualizar(
      p,
      {
        'observaciones': [
          ...p.observaciones.map((o) => o.toMap()),
          obs.toMap(),
        ],
      },
      _evento(
        'OBSERVACION',
        'Registró una observación de ${obs.interesado}',
        '',
      ),
    );
  }

  static Future<void> responderObservacion(
    ProcesoContratacion p,
    ObservacionProceso obs, {
    required String respuesta,
    String responsable = '',
  }) async {
    _exigir(PermisoEquipo.pedirDocumentos);
    final actualizada = ObservacionProceso(
      id: obs.id,
      interesado: obs.interesado,
      fechaIso: obs.fechaIso,
      etapaId: obs.etapaId,
      texto: obs.texto,
      respuesta: _limpio(respuesta, 4000),
      responsable: _limpio(responsable, 120),
    );
    await _actualizar(p, {
      'observaciones': [
        for (final o in p.observaciones)
          (o.id == obs.id ? actualizada : o).toMap(),
      ],
    }, _evento('RESPUESTA', 'Proyectó la respuesta a ${obs.interesado}', ''));
  }

  // ---------------------------------------------------------------------------
  // Resultado publicado en SECOP II y legalización
  // ---------------------------------------------------------------------------

  /// Registra el resultado ya decidido y publicado en SECOP II.
  static Future<void> registrarResultado(
    ProcesoContratacion p, {
    required bool adjudicado,
    required String actoNumero,
    required DateTime fecha,
    OfertaRecibida? oferta,
    String motivo = '',
  }) async {
    _exigir(PermisoEquipo.verificarDocumentos);
    if (adjudicado && oferta == null && !p.esDirecta) {
      throw const ProcesoContratacionException('Elige la oferta adjudicada.');
    }
    final seleccionada = oferta ?? (p.ofertas.isEmpty ? null : p.ofertas.first);
    final resultado = ResultadoProceso(
      adjudicado: adjudicado,
      actoNumero: _limpio(actoNumero, 80),
      fechaIso: fechaCorta(fecha),
      ofertaId: adjudicado ? seleccionada?.id : null,
      proponente: adjudicado ? seleccionada?.proponente ?? '' : '',
      valorCop: adjudicado ? seleccionada?.valorCop ?? 0 : 0,
      motivo: _limpio(motivo, 500),
    );
    await _actualizar(
      p,
      {
        'resultado': resultado.toMap(),
        'estado':
            (adjudicado ? EstadoProceso.adjudicado : EstadoProceso.desierto)
                .name,
      },
      _evento(
        'RESULTADO',
        adjudicado
            ? 'Registró la adjudicación a ${resultado.proponente} publicada en SECOP II'
            : 'Registró la declaratoria de desierto publicada en SECOP II',
        [
          if (resultado.actoNumero.isNotEmpty) 'Acto ${resultado.actoNumero}',
          'del ${resultado.fechaIso}',
          if (resultado.motivo.isNotEmpty) resultado.motivo,
        ].join(' · '),
      ),
    );
  }

  static Future<void> verificarLegalizacion(
    ProcesoContratacion p,
    DocumentoRequerido requisito,
    VerificacionRequisito verificacion,
  ) async {
    _exigir(PermisoEquipo.verificarDocumentos);
    await _actualizar(
      p,
      {
        'legalizacion.${requisito.id}': VerificacionRequisito(
          estado: verificacion.estado,
          observacion: _limpio(verificacion.observacion, 500),
        ).toMap(),
      },
      _evento(
        'LEGALIZACION',
        '${requisito.nombre} → ${verificacion.estado.etiqueta}',
        verificacion.observacion.trim(),
      ),
    );
  }
}
