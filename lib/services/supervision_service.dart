import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/document_file_picker.dart';
import '../utils/file_downloader.dart';
import 'archivo_fragmentado.dart';
import 'auth_service.dart';
import 'equipo_juridico_service.dart';
import 'juridico_contratacion_service.dart';

/// Supervisión mensual de contratos de prestación de servicios:
/// el contratista envía su informe del mes desde su enlace, un abogado hace
/// la revisión documental y el supervisor asignado aprueba el pago
/// (Ley 1474 de 2011, arts. 83 y 84; Ley 1150 de 2007, art. 23).
///
/// Datos en Firestore, bajo el expediente del contrato:
/// - `expedientes_juridicos/{token}/supervision/plan`
/// - `expedientes_juridicos/{token}/informes/{AAAA-MM}` (+ `archivos/`)

// =============================================================================
// Seguridad social de contratistas independientes
// =============================================================================

/// Salario mínimo mensual por año (decretos anuales del Gobierno).
const Map<int, int> smmlvPorAnio = {
  2023: 1160000,
  2024: 1300000,
  2025: 1423500,
  2026: 1750905,
};

int smmlvDe(int anio) {
  if (smmlvPorAnio.containsKey(anio)) return smmlvPorAnio[anio]!;
  final conocido = smmlvPorAnio.keys.where((a) => a <= anio);
  return smmlvPorAnio[conocido.isEmpty
      ? smmlvPorAnio.keys.first
      : conocido.reduce((a, b) => a > b ? a : b)]!;
}

/// Tarifas de riesgos laborales por clase (Decreto 1772 de 1994).
const Map<int, double> tarifaArlPorClase = {
  1: 0.00522,
  2: 0.01044,
  3: 0.02436,
  4: 0.04350,
  5: 0.06960,
};

class AporteEsperado {
  const AporteEsperado({
    required this.ibc,
    required this.salud,
    required this.pension,
    required this.arl,
    required this.smmlv,
    required this.arlLaPagaLaEntidad,
  });

  final int ibc;
  final int salud;
  final int pension;
  final int arl;
  final int smmlv;

  /// En riesgo IV y V la ARL la paga la entidad (Decreto 723 de 2013, art. 13).
  final bool arlLaPagaLaEntidad;

  int get totalContratista => salud + pension + (arlLaPagaLaEntidad ? 0 : arl);

  /// IBC del 40 % del valor mensual, entre 1 y 25 SMMLV (Ley 1753 de 2015,
  /// art. 135; Decreto 1273 de 2018). PILA redondea a la centena.
  static AporteEsperado calcular({
    required int valorMensualCop,
    required int claseRiesgo,
    required int anio,
  }) {
    final smmlv = smmlvDe(anio);
    final base = (valorMensualCop * 0.4).round();
    final ibc = base.clamp(smmlv, smmlv * 25);
    int cent(double v) => (v / 100).ceil() * 100;
    final clase = claseRiesgo.clamp(1, 5);
    return AporteEsperado(
      ibc: ibc,
      salud: cent(ibc * 0.125),
      pension: cent(ibc * 0.16),
      arl: cent(ibc * tarifaArlPorClase[clase]!),
      smmlv: smmlv,
      arlLaPagaLaEntidad: clase >= 4,
    );
  }
}

class HallazgoPlanilla {
  const HallazgoPlanilla(this.cumple, this.texto);
  final bool cumple;
  final String texto;
}

// =============================================================================
// Modelos
// =============================================================================

class ObligacionContractual {
  const ObligacionContractual({required this.id, required this.texto});
  final String id;
  final String texto;

  Map<String, dynamic> toMap() => {'id': id, 'texto': texto};
  factory ObligacionContractual.fromMap(Map<String, dynamic> m) =>
      ObligacionContractual(id: '${m['id']}', texto: '${m['texto'] ?? ''}');
}

class PlanSupervision {
  const PlanSupervision({
    required this.supervisorNombre,
    required this.supervisorEmail,
    required this.fechaInicio,
    required this.fechaFin,
    required this.valorMensualCop,
    required this.claseRiesgo,
    required this.obligaciones,
    this.actualizadoPor = '',
    this.actualizadoEnMs = 0,
  });

  final String supervisorNombre;
  final String supervisorEmail;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final int valorMensualCop;
  final int claseRiesgo;
  final List<ObligacionContractual> obligaciones;
  final String actualizadoPor;
  final int actualizadoEnMs;

  /// Meses del contrato en formato `AAAA-MM`.
  List<String> get periodos {
    final lista = <String>[];
    var d = DateTime(fechaInicio.year, fechaInicio.month);
    final fin = DateTime(fechaFin.year, fechaFin.month);
    while (!d.isAfter(fin) && lista.length < 60) {
      lista.add(periodoDe(d));
      d = DateTime(d.year, d.month + 1);
    }
    return lista;
  }

  bool esSupervisor(String? email) =>
      email != null &&
      supervisorEmail.isNotEmpty &&
      email.trim().toLowerCase() == supervisorEmail.trim().toLowerCase();

  Map<String, dynamic> toMap() => {
    'supervisorNombre': supervisorNombre,
    'supervisorEmail': supervisorEmail.trim().toLowerCase(),
    'fechaInicioIso': _fecha(fechaInicio),
    'fechaFinIso': _fecha(fechaFin),
    'valorMensualCop': valorMensualCop,
    'claseRiesgo': claseRiesgo,
    'obligaciones': obligaciones.map((o) => o.toMap()).toList(),
    'actualizadoPor': actualizadoPor,
    'actualizadoEnMs': actualizadoEnMs,
  };

  factory PlanSupervision.fromMap(Map<String, dynamic> m) => PlanSupervision(
    supervisorNombre: '${m['supervisorNombre'] ?? ''}',
    supervisorEmail: '${m['supervisorEmail'] ?? ''}',
    fechaInicio: DateTime.tryParse('${m['fechaInicioIso']}') ?? DateTime.now(),
    fechaFin: DateTime.tryParse('${m['fechaFinIso']}') ?? DateTime.now(),
    valorMensualCop: (m['valorMensualCop'] as num?)?.toInt() ?? 0,
    claseRiesgo: (m['claseRiesgo'] as num?)?.toInt() ?? 1,
    obligaciones: [
      for (final o in (m['obligaciones'] as List? ?? const []))
        if (o is Map)
          ObligacionContractual.fromMap(Map<String, dynamic>.from(o)),
    ],
    actualizadoPor: '${m['actualizadoPor'] ?? ''}',
    actualizadoEnMs: (m['actualizadoEnMs'] as num?)?.toInt() ?? 0,
  );
}

enum EstadoInforme {
  pendiente('Sin iniciar', 0xFF64748B, 0xFFF1F5F9),
  borrador('En elaboración', 0xFF475569, 0xFFE2E8F0),
  enviado('Por revisar', 0xFF1D4ED8, 0xFFDBEAFE),
  devuelto('Devuelto', 0xFFB45309, 0xFFFEF3C7),
  revisado('Por aprobar', 0xFF7C3AED, 0xFFEDE9FE),
  aprobado('Aprobado para pago', 0xFF15803D, 0xFFDCFCE7),
  pagado('Pagado', 0xFF0F766E, 0xFFCCFBF1);

  const EstadoInforme(this.etiqueta, this.color, this.fondo);
  final String etiqueta;
  final int color;
  final int fondo;

  static EstadoInforme desde(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => pendiente);

  bool get editablePorContratista => this == borrador || this == devuelto;
}

/// Puntos que se revisan en cada informe.
enum PuntoRevision {
  actividades('Actividades frente a las obligaciones'),
  informe('Informe de actividades firmado'),
  planilla('Planilla de seguridad social'),
  cuentaCobro('Cuenta de cobro o factura');

  const PuntoRevision(this.etiqueta);
  final String etiqueta;
}

/// Documentos que el contratista adjunta cada mes.
enum DocumentoInformeTipo {
  informe('Informe de actividades firmado', true),
  planilla('Planilla de pago de seguridad social', true),
  cuentaCobro('Cuenta de cobro o factura', true),
  evidencias('Evidencias (opcional)', false);

  const DocumentoInformeTipo(this.etiqueta, this.obligatorio);
  final String etiqueta;
  final bool obligatorio;
}

class DocumentoInforme {
  const DocumentoInforme({
    required this.nombre,
    required this.mime,
    required this.tamanoBytes,
    required this.sha256,
    required this.cargadoEnIso,
  });

  final String nombre;
  final String mime;
  final int tamanoBytes;
  final String sha256;
  final String cargadoEnIso;

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'mime': mime,
    'tamanoBytes': tamanoBytes,
    'sha256': sha256,
    'cargadoEnIso': cargadoEnIso,
  };

  factory DocumentoInforme.fromMap(Map<String, dynamic> m) => DocumentoInforme(
    nombre: '${m['nombre'] ?? ''}',
    mime: '${m['mime'] ?? ''}',
    tamanoBytes: (m['tamanoBytes'] as num?)?.toInt() ?? 0,
    sha256: '${m['sha256'] ?? ''}',
    cargadoEnIso: '${m['cargadoEnIso'] ?? ''}',
  );
}

class PlanillaReportada {
  const PlanillaReportada({
    this.numero = '',
    this.periodoCotizado = '',
    this.ibcCop = 0,
    this.saludCop = 0,
    this.pensionCop = 0,
    this.arlCop = 0,
    this.pensionado = false,
  });

  final String numero;
  final String periodoCotizado;
  final int ibcCop;
  final int saludCop;
  final int pensionCop;
  final int arlCop;

  /// Los pensionados no cotizan a pensión.
  final bool pensionado;

  bool get diligenciada => numero.trim().isNotEmpty && ibcCop > 0;

  Map<String, dynamic> toMap() => {
    'numero': numero,
    'periodoCotizado': periodoCotizado,
    'ibcCop': ibcCop,
    'saludCop': saludCop,
    'pensionCop': pensionCop,
    'arlCop': arlCop,
    'pensionado': pensionado,
  };

  factory PlanillaReportada.fromMap(Map<String, dynamic>? m) => m == null
      ? const PlanillaReportada()
      : PlanillaReportada(
          numero: '${m['numero'] ?? ''}',
          periodoCotizado: '${m['periodoCotizado'] ?? ''}',
          ibcCop: (m['ibcCop'] as num?)?.toInt() ?? 0,
          saludCop: (m['saludCop'] as num?)?.toInt() ?? 0,
          pensionCop: (m['pensionCop'] as num?)?.toInt() ?? 0,
          arlCop: (m['arlCop'] as num?)?.toInt() ?? 0,
          pensionado: m['pensionado'] == true,
        );

  /// Compara lo pagado con el mínimo legal. Tolera $100 por redondeos.
  List<HallazgoPlanilla> verificar(AporteEsperado e, String periodo) {
    String cop(int v) => '\$${_miles(v)}';
    bool alcanza(int pagado, int minimo) => pagado + 100 >= minimo;
    return [
      if (periodoCotizado.isEmpty)
        const HallazgoPlanilla(false, 'No indicó el periodo cotizado.')
      else if (periodoCotizado != periodo)
        HallazgoPlanilla(
          false,
          'El periodo cotizado (${nombrePeriodo(periodoCotizado)}) no es el del informe (${nombrePeriodo(periodo)}).',
        )
      else
        HallazgoPlanilla(true, 'Periodo cotizado: ${nombrePeriodo(periodo)}.'),
      HallazgoPlanilla(
        alcanza(ibcCop, e.ibc),
        'IBC ${cop(ibcCop)} · mínimo ${cop(e.ibc)} (40 % del valor mensual, mínimo 1 SMMLV).',
      ),
      HallazgoPlanilla(
        alcanza(saludCop, e.salud),
        'Salud ${cop(saludCop)} · mínimo ${cop(e.salud)} (12,5 %).',
      ),
      if (pensionado)
        const HallazgoPlanilla(
          true,
          'Pensión: no aplica, el contratista es pensionado.',
        )
      else
        HallazgoPlanilla(
          alcanza(pensionCop, e.pension),
          'Pensión ${cop(pensionCop)} · mínimo ${cop(e.pension)} (16 %).',
        ),
      if (e.arlLaPagaLaEntidad)
        const HallazgoPlanilla(true, 'ARL: riesgo IV o V, la paga la entidad.')
      else
        HallazgoPlanilla(
          alcanza(arlCop, e.arl),
          'ARL ${cop(arlCop)} · mínimo ${cop(e.arl)}.',
        ),
    ];
  }
}

class RevisionPunto {
  const RevisionPunto({required this.cumple, this.observacion = ''});
  final bool cumple;
  final String observacion;

  Map<String, dynamic> toMap() => {
    'cumple': cumple,
    'observacion': observacion,
  };
  factory RevisionPunto.fromMap(Map<String, dynamic> m) => RevisionPunto(
    cumple: m['cumple'] == true,
    observacion: '${m['observacion'] ?? ''}',
  );
}

class EventoInforme {
  const EventoInforme({
    required this.fechaIso,
    required this.actor,
    required this.accion,
    this.detalle = '',
  });

  final String fechaIso;
  final String actor;
  final String accion;
  final String detalle;

  Map<String, dynamic> toMap() => {
    'fechaIso': fechaIso,
    'actor': actor,
    'accion': accion,
    'detalle': detalle,
  };
  factory EventoInforme.fromMap(Map<String, dynamic> m) => EventoInforme(
    fechaIso: '${m['fechaIso'] ?? ''}',
    actor: '${m['actor'] ?? ''}',
    accion: '${m['accion'] ?? ''}',
    detalle: '${m['detalle'] ?? ''}',
  );
}

class InformeMensual {
  const InformeMensual({
    required this.periodo,
    this.estado = EstadoInforme.pendiente,
    this.valorCobradoCop = 0,
    this.actividades = const {},
    this.planilla = const PlanillaReportada(),
    this.documentos = const {},
    this.revision = const {},
    this.revisorNombre = '',
    this.revisadoEnIso = '',
    this.supervisorNombre = '',
    this.aprobadoEnIso = '',
    this.conceptoSupervisor = '',
    this.pagoReferencia = '',
    this.pagadoEnIso = '',
    this.enviadoEnIso = '',
    this.historial = const [],
  });

  final String periodo;
  final EstadoInforme estado;
  final int valorCobradoCop;

  /// Obligación → actividades que el contratista reporta haber realizado.
  final Map<String, String> actividades;
  final PlanillaReportada planilla;
  final Map<String, DocumentoInforme> documentos;
  final Map<String, RevisionPunto> revision;
  final String revisorNombre;
  final String revisadoEnIso;
  final String supervisorNombre;
  final String aprobadoEnIso;
  final String conceptoSupervisor;
  final String pagoReferencia;
  final String pagadoEnIso;
  final String enviadoEnIso;
  final List<EventoInforme> historial;

  bool get existe => estado != EstadoInforme.pendiente;

  /// Lo que falta para poder enviar el informe.
  List<String> faltantes(PlanSupervision plan) => [
    if (valorCobradoCop <= 0) 'Indica el valor que cobras este mes.',
    for (final o in plan.obligaciones)
      if ((actividades[o.id] ?? '').trim().length < 10)
        'Describe las actividades de la obligación "${_corto(o.texto)}".',
    if (!planilla.diligenciada)
      'Diligencia los datos de la planilla de seguridad social.',
    for (final d in DocumentoInformeTipo.values)
      if (d.obligatorio && !documentos.containsKey(d.name))
        'Adjunta: ${d.etiqueta}.',
  ];

  List<RevisionPunto> get devueltos =>
      revision.values.where((r) => !r.cumple).toList();

  Map<String, dynamic> camposContratista() => {
    'periodo': periodo,
    'estado': estado.name,
    'valorCobradoCop': valorCobradoCop,
    'actividades': actividades,
    'planilla': planilla.toMap(),
    'documentos': documentos.map((k, v) => MapEntry(k, v.toMap())),
    'enviadoEnIso': enviadoEnIso,
    'historial': historial.map((e) => e.toMap()).toList(),
    'actualizadoEnMs': DateTime.now().millisecondsSinceEpoch,
  };

  factory InformeMensual.fromMap(Map<String, dynamic> m) => InformeMensual(
    periodo: '${m['periodo'] ?? ''}',
    estado: EstadoInforme.desde(m['estado']?.toString()),
    valorCobradoCop: (m['valorCobradoCop'] as num?)?.toInt() ?? 0,
    actividades: {
      for (final e in (m['actividades'] as Map? ?? const {}).entries)
        '${e.key}': '${e.value ?? ''}',
    },
    planilla: PlanillaReportada.fromMap(
      m['planilla'] is Map ? Map<String, dynamic>.from(m['planilla']) : null,
    ),
    documentos: {
      for (final e in (m['documentos'] as Map? ?? const {}).entries)
        if (e.value is Map)
          '${e.key}': DocumentoInforme.fromMap(
            Map<String, dynamic>.from(e.value),
          ),
    },
    revision: {
      for (final e in (m['revision'] as Map? ?? const {}).entries)
        if (e.value is Map)
          '${e.key}': RevisionPunto.fromMap(Map<String, dynamic>.from(e.value)),
    },
    revisorNombre: '${m['revisorNombre'] ?? ''}',
    revisadoEnIso: '${m['revisadoEnIso'] ?? ''}',
    supervisorNombre: '${m['supervisorNombre'] ?? ''}',
    aprobadoEnIso: '${m['aprobadoEnIso'] ?? ''}',
    conceptoSupervisor: '${m['conceptoSupervisor'] ?? ''}',
    pagoReferencia: '${m['pagoReferencia'] ?? ''}',
    pagadoEnIso: '${m['pagadoEnIso'] ?? ''}',
    enviadoEnIso: '${m['enviadoEnIso'] ?? ''}',
    historial: [
      for (final e in (m['historial'] as List? ?? const []))
        if (e is Map) EventoInforme.fromMap(Map<String, dynamic>.from(e)),
    ],
  );

  InformeMensual copyWith({
    EstadoInforme? estado,
    int? valorCobradoCop,
    Map<String, String>? actividades,
    PlanillaReportada? planilla,
    Map<String, DocumentoInforme>? documentos,
    String? enviadoEnIso,
    List<EventoInforme>? historial,
  }) => InformeMensual(
    periodo: periodo,
    estado: estado ?? this.estado,
    valorCobradoCop: valorCobradoCop ?? this.valorCobradoCop,
    actividades: actividades ?? this.actividades,
    planilla: planilla ?? this.planilla,
    documentos: documentos ?? this.documentos,
    revision: revision,
    revisorNombre: revisorNombre,
    revisadoEnIso: revisadoEnIso,
    supervisorNombre: supervisorNombre,
    aprobadoEnIso: aprobadoEnIso,
    conceptoSupervisor: conceptoSupervisor,
    pagoReferencia: pagoReferencia,
    pagadoEnIso: pagadoEnIso,
    enviadoEnIso: enviadoEnIso ?? this.enviadoEnIso,
    historial: historial ?? this.historial,
  );
}

/// Informe con su contrato, para la bandeja del equipo.
class InformeEnBandeja {
  const InformeEnBandeja({
    required this.expediente,
    required this.plan,
    required this.informe,
  });

  final ExpedienteContratoPs expediente;
  final PlanSupervision plan;
  final InformeMensual informe;
}

class SupervisionException implements Exception {
  const SupervisionException(this.message);
  final String message;
  @override
  String toString() => message;
}

// =============================================================================
// Utilidades
// =============================================================================

String periodoDe(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

const List<String> _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "2026-03" → "marzo de 2026".
String nombrePeriodo(String periodo) {
  final p = periodo.split('-');
  if (p.length != 2) return periodo;
  final mes = int.tryParse(p[1]) ?? 0;
  if (mes < 1 || mes > 12) return periodo;
  return '${_meses[mes - 1]} de ${p[0]}';
}

String _fecha(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _miles(int v) =>
    v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

String formatoCop(int v) => '\$ ${_miles(v)}';

String _corto(String t) => t.length <= 60 ? t : '${t.substring(0, 57)}…';

// =============================================================================
// Servicio
// =============================================================================

class SupervisionService {
  SupervisionService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _expediente(String token) =>
      _db.collection('expedientes_juridicos').doc(token.toLowerCase());

  static DocumentReference<Map<String, dynamic>> _refPlan(String token) =>
      _expediente(token).collection('supervision').doc('plan');

  static CollectionReference<Map<String, dynamic>> _informes(String token) =>
      _expediente(token).collection('informes');

  static DocumentReference<Map<String, dynamic>> _refArchivo(
    String token,
    String periodo,
    String tipo,
  ) => _informes(token).doc(periodo).collection('archivos').doc(tipo);

  static String get _actor => AuthService.getActiveUserDisplayName();

  static String _ahora() => DateTime.now().toUtc().toIso8601String();

  static String _mensajeFirebase(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'No tienes permiso para esta acción. Si acabas de actualizar la '
          'app, publica de nuevo las reglas de Firestore.';
    }
    if (e is TimeoutException) {
      return 'El servidor no respondió. Revisa tu conexión e intenta de nuevo.';
    }
    if (e is SupervisionException) return e.message;
    return 'No fue posible guardar. Revisa tu conexión e intenta de nuevo.';
  }

  static Future<T> _guardar<T>(Future<T> Function() accion) async {
    try {
      return await accion().timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('SupervisionService: $e');
      throw SupervisionException(_mensajeFirebase(e));
    }
  }

  // ------------------------------------------------------------- Permisos

  static String get _emailActual =>
      FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';

  static bool _esTitular(ExpedienteContratoPs e) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return uid.isNotEmpty && (e.equipoUid == uid || e.creadoPorUid == uid);
  }

  static bool puedeConfigurar(ExpedienteContratoPs e) =>
      _esTitular(e) ||
      EquipoJuridicoService.tienePermiso(PermisoEquipo.crearContratos);

  static bool puedeRevisar(ExpedienteContratoPs e) =>
      _esTitular(e) ||
      EquipoJuridicoService.tienePermiso(PermisoEquipo.verificarDocumentos);

  static bool puedeAprobar(ExpedienteContratoPs e, PlanSupervision plan) =>
      _esTitular(e) || plan.esSupervisor(_emailActual);

  // ------------------------------------------------------------- Lectura

  static Stream<PlanSupervision?> escucharPlan(String token) => _refPlan(token)
      .snapshots()
      .map((s) => s.data() == null ? null : PlanSupervision.fromMap(s.data()!));

  static Stream<Map<String, InformeMensual>> escucharInformes(String token) =>
      _informes(token).snapshots().map(
        (q) => {for (final d in q.docs) d.id: InformeMensual.fromMap(d.data())},
      );

  /// Bandeja del equipo: informes de todos los contratos con plan.
  static Stream<List<InformeEnBandeja>> escucharBandeja(
    List<ExpedienteContratoPs> expedientes,
  ) {
    late StreamController<List<InformeEnBandeja>> control;
    final subs = <StreamSubscription<dynamic>>[];
    final planes = <String, PlanSupervision>{};
    final informes = <String, Map<String, InformeMensual>>{};
    final porToken = {
      for (final e in expedientes) e.tokenInvitado.toLowerCase(): e,
    };

    void emitir() {
      final lista = <InformeEnBandeja>[];
      for (final entry in planes.entries) {
        final exp = porToken[entry.key];
        if (exp == null) continue;
        for (final inf in (informes[entry.key] ?? const {}).values) {
          if (!inf.existe || inf.estado == EstadoInforme.borrador) continue;
          lista.add(
            InformeEnBandeja(expediente: exp, plan: entry.value, informe: inf),
          );
        }
      }
      lista.sort(
        (a, b) => b.informe.enviadoEnIso.compareTo(a.informe.enviadoEnIso),
      );
      if (!control.isClosed) control.add(lista);
    }

    control = StreamController<List<InformeEnBandeja>>(
      onListen: () {
        if (porToken.isEmpty) control.add(const []);
        for (final token in porToken.keys) {
          subs.add(
            escucharPlan(token).listen((p) {
              if (p == null) {
                planes.remove(token);
              } else {
                planes[token] = p;
              }
              emitir();
            }, onError: (_) {}),
          );
          subs.add(
            escucharInformes(token).listen((m) {
              informes[token] = m;
              emitir();
            }, onError: (_) {}),
          );
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return control.stream;
  }

  // ------------------------------------------------------------- Plan

  static Future<void> guardarPlan(
    ExpedienteContratoPs expediente,
    PlanSupervision plan,
  ) async {
    if (!puedeConfigurar(expediente)) {
      throw const SupervisionException(
        'Solo el titular del equipo o un abogado con permiso para crear contratos configura la supervisión.',
      );
    }
    if (plan.fechaFin.isBefore(plan.fechaInicio)) {
      throw const SupervisionException(
        'La fecha final no puede ser anterior a la inicial.',
      );
    }
    if (plan.obligaciones.isEmpty) {
      throw const SupervisionException(
        'Agrega al menos una obligación del contrato.',
      );
    }
    final datos = PlanSupervision(
      supervisorNombre: plan.supervisorNombre.trim(),
      supervisorEmail: plan.supervisorEmail.trim(),
      fechaInicio: plan.fechaInicio,
      fechaFin: plan.fechaFin,
      valorMensualCop: plan.valorMensualCop,
      claseRiesgo: plan.claseRiesgo,
      obligaciones: plan.obligaciones,
      actualizadoPor: _actor,
      actualizadoEnMs: DateTime.now().millisecondsSinceEpoch,
    ).toMap();
    await _guardar(() => _refPlan(expediente.tokenInvitado).set(datos));
  }

  // ------------------------------------------------------------- Contratista

  /// Guarda el borrador del contratista (sin cambiar de estado).
  static Future<void> guardarBorrador(
    String token,
    InformeMensual informe,
  ) async {
    if (informe.existe && !informe.estado.editablePorContratista) {
      throw const SupervisionException(
        'Este informe ya fue enviado y está en revisión.',
      );
    }
    final datos = informe.copyWith(
      estado: informe.estado == EstadoInforme.pendiente
          ? EstadoInforme.borrador
          : informe.estado == EstadoInforme.devuelto
          ? EstadoInforme.devuelto
          : EstadoInforme.borrador,
    );
    await _guardar(
      () =>
          _informes(token)
              .doc(informe.periodo)
              .set(datos.camposContratista(), SetOptions(merge: true)),
    );
  }

  static Future<void> enviar(
    String token,
    InformeMensual informe,
    PlanSupervision plan, {
    required String contratista,
  }) async {
    final faltan = informe.faltantes(plan);
    if (faltan.isNotEmpty) throw SupervisionException(faltan.first);
    final reenvio = informe.estado == EstadoInforme.devuelto;
    final datos = informe.copyWith(
      estado: EstadoInforme.enviado,
      enviadoEnIso: _ahora(),
      historial: [
        ...informe.historial,
        EventoInforme(
          fechaIso: _ahora(),
          actor: contratista,
          accion: reenvio ? 'Reenvió el informe corregido' : 'Envió el informe',
          detalle: formatoCop(informe.valorCobradoCop),
        ),
      ],
    );
    await _guardar(
      () =>
          _informes(token)
              .doc(informe.periodo)
              .set(datos.camposContratista(), SetOptions(merge: true)),
    );
  }

  /// Elige el archivo y lo sube. Devuelve el informe con el documento.
  static Future<InformeMensual?> cargarDocumento(
    String token,
    InformeMensual informe,
    DocumentoInformeTipo tipo,
  ) async {
    final archivo = await pickContractDocumentFile();
    if (archivo == null) return null;
    if (!archivo.isValid) {
      throw SupervisionException(
        archivo.errorMessage ?? 'El archivo no es válido.',
      );
    }
    final doc = DocumentoInforme(
      nombre: archivo.fileName,
      mime: archivo.mimeType,
      tamanoBytes: archivo.sizeBytes,
      sha256: archivo.sha256Hash,
      cargadoEnIso: _ahora(),
    );
    final actualizado = informe.copyWith(
      documentos: {...informe.documentos, tipo.name: doc},
    );
    // El informe debe existir antes que sus archivos (reglas de Firestore).
    await guardarBorrador(token, actualizado);
    await _guardar(
      () => ArchivoFragmentado.guardar(
        _refArchivo(token, informe.periodo, tipo.name),
        base64: base64Encode(archivo.bytes),
        metadatos: {...doc.toMap(), 'tipo': tipo.name},
      ),
    );
    return actualizado;
  }

  static Future<Uint8List?> _bytes(
    String token,
    String periodo,
    String tipo,
  ) async {
    final b64 = await ArchivoFragmentado.leer(
      _refArchivo(token, periodo, tipo),
    );
    return b64 == null ? null : base64Decode(b64);
  }

  /// Abre el documento en otra pestaña (PDF/imagen) o lo descarga.
  static Future<bool> abrirDocumento(
    String token,
    InformeMensual informe,
    DocumentoInformeTipo tipo,
  ) async {
    final doc = informe.documentos[tipo.name];
    if (doc == null) return false;
    try {
      final bytes = await _bytes(token, informe.periodo, tipo.name);
      if (bytes == null) return false;
      if (doc.mime == 'application/pdf' || doc.mime.startsWith('image/')) {
        return openBinaryInNewTab(bytes: bytes, mimeType: doc.mime);
      }
      return downloadBinaryBytes(
        bytes: bytes,
        fileName: doc.nombre,
        mimeType: doc.mime,
      );
    } catch (e) {
      debugPrint('abrirDocumento: $e');
      return false;
    }
  }

  // ------------------------------------------------------------- Equipo

  static Future<void> _actualizarEquipo(
    ExpedienteContratoPs exp,
    InformeMensual informe,
    Map<String, dynamic> cambios,
    EventoInforme evento,
  ) => _guardar(
    () => _informes(exp.tokenInvitado).doc(informe.periodo).update({
      ...cambios,
      'historial': [
        ...informe.historial,
        evento,
      ].map((e) => e.toMap()).toList(),
      'actualizadoEnMs': DateTime.now().millisecondsSinceEpoch,
    }),
  );

  /// Revisión documental: cada punto cumple o se devuelve con observación.
  static Future<void> registrarRevision(
    ExpedienteContratoPs exp,
    InformeMensual informe,
    Map<PuntoRevision, RevisionPunto> puntos,
  ) async {
    if (!puedeRevisar(exp)) {
      throw const SupervisionException(
        'Tu usuario no tiene el permiso "Verificar documentos".',
      );
    }
    final faltaObs = puntos.entries.where(
      (e) => !e.value.cumple && e.value.observacion.trim().isEmpty,
    );
    if (faltaObs.isNotEmpty) {
      throw SupervisionException(
        'Escribe qué debe corregir en "${faltaObs.first.key.etiqueta}".',
      );
    }
    final devuelto = puntos.values.any((p) => !p.cumple);
    await _actualizarEquipo(
      exp,
      informe,
      {
        'estado':
            (devuelto ? EstadoInforme.devuelto : EstadoInforme.revisado).name,
        'revision': {
          for (final e in puntos.entries) e.key.name: e.value.toMap(),
        },
        'revisorNombre': _actor,
        'revisadoEnIso': _ahora(),
      },
      EventoInforme(
        fechaIso: _ahora(),
        actor: _actor,
        accion: devuelto
            ? 'Devolvió el informe para corrección'
            : 'Revisó los documentos',
        detalle: devuelto
            ? puntos.entries
                  .where((e) => !e.value.cumple)
                  .map((e) => '${e.key.etiqueta}: ${e.value.observacion}')
                  .join(' · ')
            : 'Todos los puntos cumplen.',
      ),
    );
  }

  static Future<void> aprobar(
    ExpedienteContratoPs exp,
    PlanSupervision plan,
    InformeMensual informe, {
    required String concepto,
  }) async {
    if (!puedeAprobar(exp, plan)) {
      throw SupervisionException(
        'Solo el supervisor asignado (${plan.supervisorNombre}) o el titular del equipo aprueba el informe.',
      );
    }
    if (informe.estado != EstadoInforme.revisado) {
      throw const SupervisionException(
        'El informe debe pasar primero la revisión documental.',
      );
    }
    await _actualizarEquipo(
      exp,
      informe,
      {
        'estado': EstadoInforme.aprobado.name,
        'supervisorNombre': _actor,
        'aprobadoEnIso': _ahora(),
        'conceptoSupervisor': concepto.trim(),
      },
      EventoInforme(
        fechaIso: _ahora(),
        actor: _actor,
        accion: 'Aprobó el informe y certificó el cumplimiento',
        detalle: concepto.trim(),
      ),
    );
  }

  static Future<void> devolverDesdeSupervisor(
    ExpedienteContratoPs exp,
    PlanSupervision plan,
    InformeMensual informe, {
    required String motivo,
  }) async {
    if (!puedeAprobar(exp, plan)) {
      throw const SupervisionException(
        'Solo el supervisor asignado puede devolver en esta etapa.',
      );
    }
    if (motivo.trim().isEmpty) {
      throw const SupervisionException(
        'Escribe qué debe corregir el contratista.',
      );
    }
    await _actualizarEquipo(
      exp,
      informe,
      {
        'estado': EstadoInforme.devuelto.name,
        'revision': {
          ...informe.revision.map((k, v) => MapEntry(k, v.toMap())),
          PuntoRevision.actividades.name: RevisionPunto(
            cumple: false,
            observacion: motivo.trim(),
          ).toMap(),
        },
      },
      EventoInforme(
        fechaIso: _ahora(),
        actor: _actor,
        accion: 'El supervisor devolvió el informe',
        detalle: motivo.trim(),
      ),
    );
  }

  static Future<void> registrarPago(
    ExpedienteContratoPs exp,
    InformeMensual informe, {
    required String referencia,
  }) async {
    if (!puedeRevisar(exp)) {
      throw const SupervisionException(
        'Tu usuario no tiene permiso para registrar pagos.',
      );
    }
    await _actualizarEquipo(
      exp,
      informe,
      {
        'estado': EstadoInforme.pagado.name,
        'pagoReferencia': referencia.trim(),
        'pagadoEnIso': _ahora(),
      },
      EventoInforme(
        fechaIso: _ahora(),
        actor: _actor,
        accion: 'Registró el pago',
        detalle: referencia.trim(),
      ),
    );
  }

  /// Borra el plan y los informes (con sus archivos) al eliminar el
  /// expediente. Lo que falle queda inaccesible por las reglas.
  static Future<void> borrarDatos(String token) async {
    try {
      final informes = await _informes(token).get();
      for (final inf in informes.docs) {
        final archivos = await inf.reference.collection('archivos').get();
        for (final a in archivos.docs) {
          final partes = a.data()['partes'];
          if (partes is int) {
            for (var i = 0; i < partes; i++) {
              await a.reference.collection('partes').doc('$i').delete();
            }
          }
          await a.reference.delete();
        }
        await inf.reference.delete();
      }
      await _refPlan(token).delete();
    } catch (e) {
      debugPrint('SupervisionService.borrarDatos: $e');
    }
  }
}
