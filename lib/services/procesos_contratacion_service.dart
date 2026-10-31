import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/modalidades_contratacion.dart';
import '../utils/document_file_picker.dart';
import '../utils/file_downloader.dart';
import 'auth_service.dart';
import 'equipo_juridico_service.dart';
import 'juridico_contratacion_service.dart';
import 'security_service.dart';

/// Estado de un oferente dentro del proceso.
enum EstadoOferente {
  inscrito('Inscrito'),
  habilitado('Habilitado'),
  noHabilitado('No habilitado'),
  adjudicado('Adjudicado'),
  noAdjudicado('No adjudicado');

  const EstadoOferente(this.etiqueta);
  final String etiqueta;

  static EstadoOferente desde(String? v) => EstadoOferente.values.firstWhere(
    (e) => e.name == v,
    orElse: () => EstadoOferente.inscrito,
  );
}

enum EstadoProceso {
  enCurso('En curso'),
  adjudicado('Adjudicado'),
  desierto('Declarado desierto');

  const EstadoProceso(this.etiqueta);
  final String etiqueta;

  static EstadoProceso desde(String? v) => EstadoProceso.values.firstWhere(
    (e) => e.name == v,
    orElse: () => EstadoProceso.enCurso,
  );
}

/// Documento de la entidad ya cargado en una etapa. El archivo va en la
/// subcolección `archivos`, igual que en los expedientes.
class DocumentoEntidadCargado {
  const DocumentoEntidadCargado({
    required this.archivoNombre,
    required this.archivoMime,
    required this.tamanoBytes,
    required this.sha256,
    required this.cargadoPor,
    required this.fechaIso,
  });

  final String archivoNombre;
  final String archivoMime;
  final int tamanoBytes;
  final String sha256;
  final String cargadoPor;
  final String fechaIso;

  Map<String, dynamic> toMap() => {
    'archivoNombre': archivoNombre,
    'archivoMime': archivoMime,
    'tamanoBytes': tamanoBytes,
    'sha256': sha256,
    'cargadoPor': cargadoPor,
    'fechaIso': fechaIso,
  };

  factory DocumentoEntidadCargado.fromMap(Map<String, dynamic> m) =>
      DocumentoEntidadCargado(
        archivoNombre: '${m['archivoNombre'] ?? ''}',
        archivoMime: '${m['archivoMime'] ?? ''}',
        tamanoBytes: (m['tamanoBytes'] as num?)?.toInt() ?? 0,
        sha256: '${m['sha256'] ?? ''}',
        cargadoPor: '${m['cargadoPor'] ?? ''}',
        fechaIso: '${m['fechaIso'] ?? ''}',
      );
}

/// Oferente (o contratista, en contratación directa). Sus documentos los
/// sube por el enlace de invitado de su expediente, que también usa la mesa
/// de verificación documento a documento.
class OferenteProceso {
  const OferenteProceso({
    required this.id,
    required this.nombre,
    required this.documento,
    required this.correo,
    required this.tokenExpediente,
    this.estado = EstadoOferente.inscrito,
    this.valorOfertaCop = 0,
    this.puntaje,
    this.observacion = '',
  });

  final String id;
  final String nombre;

  /// NIT o cédula: el oferente lo usa para entrar a su enlace.
  final String documento;
  final String correo;
  final String tokenExpediente;
  final EstadoOferente estado;
  final int valorOfertaCop;
  final double? puntaje;
  final String observacion;

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'documento': documento,
    'correo': correo,
    'tokenExpediente': tokenExpediente,
    'estado': estado.name,
    'valorOfertaCop': valorOfertaCop,
    'puntaje': puntaje,
    'observacion': observacion,
  };

  factory OferenteProceso.fromMap(Map<String, dynamic> m) => OferenteProceso(
    id: '${m['id'] ?? ''}',
    nombre: '${m['nombre'] ?? ''}',
    documento: '${m['documento'] ?? ''}',
    correo: '${m['correo'] ?? ''}',
    tokenExpediente: '${m['tokenExpediente'] ?? ''}',
    estado: EstadoOferente.desde(m['estado']?.toString()),
    valorOfertaCop: (m['valorOfertaCop'] as num?)?.toInt() ?? 0,
    puntaje: (m['puntaje'] as num?)?.toDouble(),
    observacion: '${m['observacion'] ?? ''}',
  );

  OferenteProceso copyWith({
    EstadoOferente? estado,
    int? valorOfertaCop,
    double? puntaje,
    String? observacion,
  }) => OferenteProceso(
    id: id,
    nombre: nombre,
    documento: documento,
    correo: correo,
    tokenExpediente: tokenExpediente,
    estado: estado ?? this.estado,
    valorOfertaCop: valorOfertaCop ?? this.valorOfertaCop,
    puntaje: puntaje ?? this.puntaje,
    observacion: observacion ?? this.observacion,
  );
}

/// Proceso de contratación de cualquier modalidad distinta de prestación de
/// servicios (que conserva su expediente directo). Vive en
/// `procesos_contratacion/{id}` y pertenece al equipo jurídico.
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
    this.campos = const {},
    this.etapaActual = 0,
    this.documentosEntidad = const {},
    this.oferentes = const [],
    this.adjudicatarioId,
    this.estado = EstadoProceso.enCurso,
    this.trazabilidad = const [],
    this.actualizadoEnMs = 0,
  });

  final String id;
  final String modalidadId;
  final String equipoUid;
  final String creadoPorUid;
  final String creadoPorNombre;
  final String entidadNombre;
  final String entidadNit;
  final String dependencia;
  final String numeroProceso;
  final String objeto;
  final int presupuestoCop;
  final String plazoEjecucion;
  final String fechaCreacionIso;

  /// Valores de los campos propios de la modalidad.
  final Map<String, String> campos;

  /// Índice de la etapa en curso dentro de `modalidad.etapas`.
  final int etapaActual;

  /// Documentos de la entidad cargados, por id de documento.
  final Map<String, DocumentoEntidadCargado> documentosEntidad;
  final List<OferenteProceso> oferentes;
  final String? adjudicatarioId;
  final EstadoProceso estado;
  final List<EventoTrazabilidadContrato> trazabilidad;
  final int actualizadoEnMs;

  ModalidadContratacion get modalidad =>
      modalidadPorId(modalidadId) ?? modalidadesContratacion.last;

  OferenteProceso? get adjudicatario {
    for (final o in oferentes) {
      if (o.id == adjudicatarioId) return o;
    }
    return null;
  }

  /// Documentos obligatorios de la entidad que faltan en una etapa.
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
    'campos': campos,
    'etapaActual': etapaActual,
    'documentosEntidad': {
      for (final e in documentosEntidad.entries) e.key: e.value.toMap(),
    },
    'oferentes': oferentes.map((o) => o.toMap()).toList(),
    'adjudicatarioId': adjudicatarioId,
    'estado': estado.name,
    'trazabilidad': trazabilidad.map((e) => e.toMap()).toList(),
    'actualizadoEnMs': actualizadoEnMs,
  };

  factory ProcesoContratacion.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic> mapa(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
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
      campos: mapa(m['campos']).map((k, v) => MapEntry(k, '$v')),
      etapaActual: (m['etapaActual'] as num?)?.toInt() ?? 0,
      documentosEntidad: mapa(m['documentosEntidad'])
          .map((k, v) => MapEntry(k, DocumentoEntidadCargado.fromMap(mapa(v)))),
      oferentes: [
        for (final o in (m['oferentes'] as List? ?? const []))
          if (o is Map) OferenteProceso.fromMap(mapa(o)),
      ],
      adjudicatarioId: m['adjudicatarioId']?.toString(),
      estado: EstadoProceso.desde(m['estado']?.toString()),
      trazabilidad: [
        for (final e in (m['trazabilidad'] as List? ?? const []))
          if (e is Map) EventoTrazabilidadContrato.fromMap(mapa(e)),
      ],
      actualizadoEnMs: (m['actualizadoEnMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProcesoContratacionException implements Exception {
  const ProcesoContratacionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Procesos de contratación del equipo jurídico en Firestore.
class ProcesosContratacionService {
  ProcesosContratacionService._();

  static const String coleccion = 'procesos_contratacion';

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(coleccion);

  static String _ahoraIso() => DateTime.now().toUtc().toIso8601String();

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

  /// Procesos del equipo activo, en tiempo real y del más reciente al más
  /// antiguo.
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
  }) async {
    _exigir(PermisoEquipo.crearContratos);
    String limpio(String v, int max) =>
        SecurityService.sanitizePlainText(v, maxLength: max);
    if (limpio(entidadNombre, 200).isEmpty ||
        limpio(numeroProceso, 80).isEmpty ||
        limpio(objeto, 2000).isEmpty) {
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
      entidadNombre: limpio(entidadNombre, 200),
      entidadNit: SecurityService.normalizeDocumentDigits(entidadNit),
      dependencia: limpio(dependencia, 160),
      numeroProceso: limpio(numeroProceso, 80),
      objeto: limpio(objeto, 2000),
      presupuestoCop: presupuestoCop < 0 ? 0 : presupuestoCop,
      plazoEjecucion: limpio(plazoEjecucion, 90),
      fechaCreacionIso: _ahoraIso(),
      campos: {
        for (final c in modalidad.campos)
          if ((campos[c.id] ?? '').trim().isNotEmpty)
            c.id: limpio(campos[c.id]!, 300),
      },
      trazabilidad: [
        _evento(
          'CREACION_PROCESO',
          'Creó el proceso ${limpio(numeroProceso, 80)}',
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
  // Documentos de la entidad
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
    await _col
        .doc(p.id)
        .collection('archivos')
        .doc(documento.id)
        .set({'archivoBase64': base64Encode(archivo.bytes), ...cargado.toMap()})
        .timeout(const Duration(seconds: 25));
    await _actualizar(
      p,
      {'documentosEntidad.${documento.id}': cargado.toMap()},
      _evento(
        'DOCUMENTO_ENTIDAD',
        'Cargó ${documento.nombre}',
        '${archivo.fileName} (${archivo.formattedSize})',
      ),
    );
  }

  static Future<void> descargarDocumentoEntidad(
    ProcesoContratacion p,
    String documentoId,
  ) async {
    final doc = await _col
        .doc(p.id)
        .collection('archivos')
        .doc(documentoId)
        .get();
    final data = doc.data();
    final b64 = data?['archivoBase64']?.toString() ?? '';
    if (b64.isEmpty) {
      throw const ProcesoContratacionException('No se encontró el archivo.');
    }
    downloadBinaryBytes(
      bytes: base64Decode(b64),
      fileName: '${data?['archivoNombre'] ?? 'documento'}',
      mimeType: '${data?['archivoMime'] ?? 'application/octet-stream'}',
    );
  }

  // ---------------------------------------------------------------------------
  // Etapas
  // ---------------------------------------------------------------------------

  /// Pasa a la siguiente etapa. Exige los documentos obligatorios de la
  /// etapa actual para dejar el expediente completo ante los entes de control.
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
  // Oferentes
  // ---------------------------------------------------------------------------

  static List<ApartadoDocumentoContrato> _apartados(
    List<DocumentoRequerido> docs,
  ) => [
    for (var i = 0; i < docs.length; i++)
      ApartadoDocumentoContrato(
        id: 'APT-${(i + 1).toString().padLeft(2, '0')}',
        nombre: docs[i].nombre,
        descripcion: docs[i].descripcion,
        obligatorio: docs[i].obligatorio,
      ),
  ];

  /// Registra al oferente y crea su expediente con enlace de invitado y los
  /// requisitos habilitantes de la modalidad. En contratación directa es el
  /// contratista, con los documentos de legalización.
  static Future<OferenteProceso> agregarOferente(
    ProcesoContratacion p, {
    required String nombre,
    required String documento,
    required String correo,
    String telefono = '',
  }) async {
    _exigir(PermisoEquipo.pedirDocumentos);
    if (p.estado != EstadoProceso.enCurso) {
      throw const ProcesoContratacionException('El proceso ya está cerrado.');
    }
    final directo = !p.modalidad.esCompetitiva;
    if (directo && p.oferentes.isNotEmpty) {
      throw const ProcesoContratacionException(
        'En contratación directa el proceso tiene un solo contratista.',
      );
    }
    final documentos = directo
        ? p.modalidad.documentosContrato
        : p.modalidad.documentosOferente;
    final expediente =
        await JuridicoContratacionService.crearExpedienteContratoPs(
          entidadNombre: p.entidadNombre,
          entidadNit: p.entidadNit,
          dependencia: p.dependencia,
          numeroContrato: directo
              ? p.numeroProceso
              : '${p.numeroProceso} · Oferta',
          objetoContrato: p.objeto,
          valorContratoCop: p.presupuestoCop,
          plazoEjecucion: p.plazoEjecucion,
          contratistaNombreEsperado: nombre,
          contratistaCedulaEsperada: documento,
          contratistaCorreo: correo,
          contratistaTelefono: telefono,
          apartados: _apartados(documentos),
        );
    final oferente = OferenteProceso(
      id: 'OF-${SecurityService.generateSecureTokenHex(4)}',
      nombre: expediente.contratistaNombreEsperado,
      documento: expediente.contratistaCedulaEsperada,
      correo: expediente.contratistaCorreo,
      tokenExpediente: expediente.tokenInvitado,
      estado: directo ? EstadoOferente.adjudicado : EstadoOferente.inscrito,
    );
    await _actualizar(
      p,
      {
        'oferentes': [...p.oferentes.map((o) => o.toMap()), oferente.toMap()],
        if (directo) 'adjudicatarioId': oferente.id,
      },
      _evento(
        directo ? 'CONTRATISTA' : 'OFERENTE',
        directo
            ? 'Registró al contratista ${oferente.nombre}'
            : 'Registró al oferente ${oferente.nombre}',
        'Se habilitó su enlace para cargar ${documentos.length} documentos.',
      ),
    );
    return oferente;
  }

  /// Resultado de la verificación y calificación de un oferente.
  static Future<void> evaluarOferente(
    ProcesoContratacion p,
    OferenteProceso oferente, {
    required bool habilitado,
    int? valorOfertaCop,
    double? puntaje,
    String observacion = '',
  }) async {
    _exigir(PermisoEquipo.verificarDocumentos);
    if (p.estado != EstadoProceso.enCurso) {
      throw const ProcesoContratacionException('El proceso ya está cerrado.');
    }
    final actualizado = oferente.copyWith(
      estado: habilitado
          ? EstadoOferente.habilitado
          : EstadoOferente.noHabilitado,
      valorOfertaCop: valorOfertaCop,
      puntaje: puntaje,
      observacion: SecurityService.sanitizePlainText(
        observacion,
        maxLength: 500,
      ),
    );
    await _actualizar(
      p,
      {
        'oferentes': [
          for (final o in p.oferentes)
            (o.id == oferente.id ? actualizado : o).toMap(),
        ],
      },
      _evento(
        'EVALUACION',
        '${habilitado ? 'Habilitó' : 'No habilitó'} a ${oferente.nombre}',
        [
          if (valorOfertaCop != null && valorOfertaCop > 0)
            'Oferta: \$$valorOfertaCop',
          if (puntaje != null) 'Puntaje: $puntaje',
          if (observacion.trim().isNotEmpty) observacion.trim(),
        ].join(' · '),
      ),
    );
  }

  /// Adjudica al oferente: los demás quedan como no adjudicados y a su
  /// expediente se agregan los documentos de legalización del contrato.
  static Future<void> adjudicar(
    ProcesoContratacion p,
    OferenteProceso ganador,
  ) async {
    _exigir(PermisoEquipo.verificarDocumentos);
    if (p.estado != EstadoProceso.enCurso) {
      throw const ProcesoContratacionException('El proceso ya está cerrado.');
    }
    if (ganador.estado != EstadoOferente.habilitado) {
      throw const ProcesoContratacionException(
        'Solo se puede adjudicar a un oferente habilitado.',
      );
    }
    for (final doc in p.modalidad.documentosContrato) {
      await JuridicoContratacionService.agregarApartadoAlExpediente(
        tokenInvitado: ganador.tokenExpediente,
        nombreApartado: doc.nombre,
        descripcionApartado: doc.descripcion,
        obligatorio: doc.obligatorio,
      );
    }
    await _actualizar(
      p,
      {
        'adjudicatarioId': ganador.id,
        'estado': EstadoProceso.adjudicado.name,
        'oferentes': [
          for (final o in p.oferentes)
            o
                .copyWith(
                  estado: o.id == ganador.id
                      ? EstadoOferente.adjudicado
                      : (o.estado == EstadoOferente.noHabilitado
                            ? EstadoOferente.noHabilitado
                            : EstadoOferente.noAdjudicado),
                )
                .toMap(),
        ],
      },
      _evento(
        'ADJUDICACION',
        'Adjudicó el proceso a ${ganador.nombre}',
        'Se solicitaron ${p.modalidad.documentosContrato.length} documentos de legalización por su enlace.',
      ),
    );
  }

  static Future<void> declararDesierto(
    ProcesoContratacion p,
    String motivo,
  ) async {
    _exigir(PermisoEquipo.verificarDocumentos);
    final m = SecurityService.sanitizePlainText(motivo, maxLength: 500);
    if (m.isEmpty) {
      throw const ProcesoContratacionException(
        'Escribe el motivo de la declaratoria de desierto.',
      );
    }
    await _actualizar(p, {
      'estado': EstadoProceso.desierto.name,
    }, _evento('DESIERTO', 'Declaró desierto el proceso', m));
  }

  static String enlaceOferente(OferenteProceso o) =>
      JuridicoContratacionService.construirLinkInvitadoWeb(o.tokenExpediente);

  /// Expediente del oferente (documentos y su verificación) en tiempo real.
  static Future<ExpedienteContratoPs?> expedienteDe(OferenteProceso o) =>
      JuridicoContratacionService.obtenerExpedientePorTokenInvitado(
        o.tokenExpediente,
      );
}
