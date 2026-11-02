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
import 'security_service.dart';

/// Supervisión de la ejecución de contratos de prestación de servicios.
///
/// El contratista reporta cada periodo desde su enlace (sin Word ni Excel);
/// el informe pasa por la cadena de aprobación de la entidad y, aprobado,
/// la app genera los documentos formales (informe de ejecución, informe de
/// supervisión, documento equivalente y solicitud de estampillas).
///
/// Firestore, bajo el expediente del contrato:
/// - `supervision/plan`  configuración del contrato y copia de la plantilla.
/// - `supervision/firma` firma registrada del contratista (PNG).
/// - `informes/{aaaa-mm-dd}` un informe por periodo (fecha de inicio).
/// - `informes/{id}/archivos/{archivo}` anexos y documentos.
/// Y por equipo: `plantillas_informe/{equipoUid}` plantilla de la entidad.

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
  final conocidos = smmlvPorAnio.keys.where((a) => a <= anio);
  return smmlvPorAnio[conocidos.isEmpty
      ? smmlvPorAnio.keys.first
      : conocidos.reduce((a, b) => a > b ? a : b)]!;
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

  int totalContratista({bool pensionado = false}) =>
      salud + (pensionado ? 0 : pension) + (arlLaPagaLaEntidad ? 0 : arl);

  /// IBC del 40 % del valor mensual, entre 1 y 25 SMMLV (Ley 1753 de 2015,
  /// art. 135; Decreto 1273 de 2018). PILA redondea a la centena.
  static AporteEsperado calcular({
    required int valorMensualCop,
    required int claseRiesgo,
    required int anio,
  }) {
    final smmlv = smmlvDe(anio);
    final ibc = (valorMensualCop * 0.4).round().clamp(smmlv, smmlv * 25);
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

/// Resultado de una verificación automática.
class Verificacion {
  const Verificacion(this.cumple, this.texto);
  final bool cumple;
  final String texto;
}

// =============================================================================
// Plantilla de la entidad
// =============================================================================

enum Periodicidad {
  mensual('Mensual', 'mensual'),
  quincenal('Quincenal', 'quincenal');

  const Periodicidad(this.etiqueta, this.adjetivo);
  final String etiqueta;
  final String adjetivo;

  static Periodicidad desde(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => mensual);
}

enum OrigenDocumento {
  contratista('Lo adjunta el contratista'),
  sistema('Lo arma el sistema');

  const OrigenDocumento(this.etiqueta);
  final String etiqueta;

  static OrigenDocumento desde(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => contratista);
}

enum ReglaDocumento {
  cadaPeriodo('Cada informe'),
  primerosDos('En los 2 primeros'),
  soloPrimero('Solo en el primero');

  const ReglaDocumento(this.etiqueta);
  final String etiqueta;

  static ReglaDocumento desde(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => cadaPeriodo);
}

/// Documentos que la app sabe generar.
abstract final class DocumentosSistema {
  static const informeSupervision = 'informe_supervision';
  static const documentoEquivalente = 'documento_equivalente';
  static const estampillaMunicipal = 'estampilla_municipal';
  static const todos = {
    informeSupervision,
    documentoEquivalente,
    estampillaMunicipal,
  };
}

class DocumentoPlantilla {
  const DocumentoPlantilla({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.origen = OrigenDocumento.contratista,
    this.regla = ReglaDocumento.cadaPeriodo,
    this.maxArchivos = 1,
    this.nota = '',
  });

  final String id;
  final String nombre;
  final String descripcion;
  final OrigenDocumento origen;
  final ReglaDocumento regla;
  final int maxArchivos;

  /// Advertencia que el contratista debe leer (p. ej. "firmada y sellada").
  final String nota;

  bool aplicaEn(int numeroInforme) => switch (regla) {
    ReglaDocumento.cadaPeriodo => true,
    ReglaDocumento.primerosDos => numeroInforme <= 2,
    ReglaDocumento.soloPrimero => numeroInforme == 1,
  };

  DocumentoPlantilla copyWith({
    String? nombre,
    String? descripcion,
    OrigenDocumento? origen,
    ReglaDocumento? regla,
    int? maxArchivos,
    String? nota,
  }) => DocumentoPlantilla(
    id: id,
    nombre: nombre ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    origen: origen ?? this.origen,
    regla: regla ?? this.regla,
    maxArchivos: maxArchivos ?? this.maxArchivos,
    nota: nota ?? this.nota,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'origen': origen.name,
    'regla': regla.name,
    'maxArchivos': maxArchivos,
    'nota': nota,
  };

  factory DocumentoPlantilla.fromMap(Map<String, dynamic> m) =>
      DocumentoPlantilla(
        id: '${m['id'] ?? ''}',
        nombre: '${m['nombre'] ?? ''}',
        descripcion: '${m['descripcion'] ?? ''}',
        origen: OrigenDocumento.desde(m['origen']?.toString()),
        regla: ReglaDocumento.desde(m['regla']?.toString()),
        maxArchivos: (m['maxArchivos'] as num?)?.toInt() ?? 1,
        nota: '${m['nota'] ?? ''}',
      );
}

class EtapaAprobacion {
  const EtapaAprobacion({
    required this.id,
    required this.nombre,
    this.responsableNombre = '',
    this.responsableEmail = '',
    this.certificacion = '',
  });

  final String id;
  final String nombre;
  final String responsableNombre;
  final String responsableEmail;

  /// Texto que esta etapa certifica en el informe al aprobar (opcional).
  final String certificacion;

  bool esResponsable(String? email) =>
      email != null &&
      responsableEmail.isNotEmpty &&
      email.trim().toLowerCase() == responsableEmail.trim().toLowerCase();

  EtapaAprobacion copyWith({
    String? nombre,
    String? responsableNombre,
    String? responsableEmail,
    String? certificacion,
  }) => EtapaAprobacion(
    id: id,
    nombre: nombre ?? this.nombre,
    responsableNombre: responsableNombre ?? this.responsableNombre,
    responsableEmail: responsableEmail ?? this.responsableEmail,
    certificacion: certificacion ?? this.certificacion,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'responsableNombre': responsableNombre,
    'responsableEmail': responsableEmail.trim().toLowerCase(),
    'certificacion': certificacion,
  };

  factory EtapaAprobacion.fromMap(Map<String, dynamic> m) => EtapaAprobacion(
    id: '${m['id'] ?? ''}',
    nombre: '${m['nombre'] ?? ''}',
    responsableNombre: '${m['responsableNombre'] ?? ''}',
    responsableEmail: '${m['responsableEmail'] ?? ''}',
    certificacion: '${m['certificacion'] ?? ''}',
  );
}

/// Formato del informe de cada entidad: encabezado, periodicidades
/// permitidas, cadena de aprobación, documentos y orden del PDF.
class PlantillaInforme {
  const PlantillaInforme({
    required this.encabezado,
    required this.etapas,
    required this.documentos,
    this.quincenalHabilitado = true,
    this.estampillaDepartamental = true,
    this.tarifaEstampillaPct = 1.5,
    this.declaracion = textoDeclaracionPorDefecto,
    this.secciones = seccionesPorDefecto,
  });

  /// Líneas del encabezado del PDF (entidad, dependencia…).
  final List<String> encabezado;
  final List<EtapaAprobacion> etapas;
  final List<DocumentoPlantilla> documentos;
  final bool quincenalHabilitado;
  final bool estampillaDepartamental;
  final double tarifaEstampillaPct;
  final String declaracion;

  /// Orden de las secciones del informe de ejecución en PDF.
  final List<String> secciones;

  static const textoDeclaracionPorDefecto =
      'Declaro bajo la gravedad de juramento que cumplí las actividades descritas en este informe, '
      'que están respaldadas por los documentos anexos, que la información suministrada es verídica '
      'y que se han observado las condiciones pactadas en el contrato.';

  static const seccionesPorDefecto = [
    'datos',
    'obligaciones',
    'declaracion',
    'anexos',
    'aportes',
    'certificaciones',
    'constancia',
  ];

  static const etiquetasSecciones = {
    'datos': 'Datos del contrato y del periodo',
    'obligaciones': 'Obligaciones y actividades',
    'declaracion': 'Declaración y firma del contratista',
    'anexos': 'Anexos',
    'aportes': 'Aportes a seguridad social',
    'certificaciones': 'Certificaciones de las etapas',
    'constancia': 'Constancia de revisión',
  };

  /// Plantilla inicial, con los documentos habituales de un contrato de
  /// prestación de servicios en el orden en que van al PDF.
  factory PlantillaInforme.porDefecto(String entidad) => PlantillaInforme(
    encabezado: [if (entidad.trim().isNotEmpty) entidad.trim().toUpperCase()],
    etapas: const [
      EtapaAprobacion(id: 'revision_juridica', nombre: 'Revisión jurídica'),
      EtapaAprobacion(
        id: 'supervisor',
        nombre: 'Supervisor del contrato',
        certificacion:
            'En mi calidad de supervisor del contrato, certifico que el contratista cumplió a entera '
            'satisfacción con las actividades y obligaciones del periodo.',
      ),
    ],
    documentos: const [
      DocumentoPlantilla(
        id: 'seguridad_social',
        nombre: 'Seguridad social (planilla)',
        descripcion: 'Comprobante de pago de salud, pensión y ARL.',
        maxArchivos: 2,
      ),
      DocumentoPlantilla(
        id: DocumentosSistema.informeSupervision,
        nombre: 'Informe de supervisión',
        origen: OrigenDocumento.sistema,
        descripcion: 'Lo genera la app con los datos del contrato y del informe; lo firma el supervisor.',
      ),
      DocumentoPlantilla(
        id: DocumentosSistema.documentoEquivalente,
        nombre: 'Documento equivalente a factura',
        origen: OrigenDocumento.sistema,
        descripcion: 'Cuenta de cobro del periodo, con la firma registrada del contratista.',
      ),
      DocumentoPlantilla(
        id: DocumentosSistema.estampillaMunicipal,
        nombre: 'Estampilla municipal',
        origen: OrigenDocumento.sistema,
        regla: ReglaDocumento.primerosDos,
        descripcion:
            'Solicitud de descuento de estampillas municipales, con la firma del contratista. '
            'No se paga en el banco ni se adjunta.',
      ),
      DocumentoPlantilla(
        id: 'rit',
        nombre: 'Certificación del RIT',
        regla: ReglaDocumento.soloPrimero,
      ),
      DocumentoPlantilla(
        id: 'sst',
        nombre: 'Certificación curso SST',
        regla: ReglaDocumento.soloPrimero,
        descripcion: 'Curso de seguridad y salud en el trabajo.',
      ),
      DocumentoPlantilla(
        id: 'impuesto_departamental',
        nombre: 'Impuesto departamental',
        regla: ReglaDocumento.soloPrimero,
        descripcion: 'Soporte de pago de la estampilla departamental.',
      ),
      DocumentoPlantilla(
        id: 'pantallazo_secop',
        nombre: 'Pantallazo SECOP',
        regla: ReglaDocumento.soloPrimero,
        descripcion: 'Publicación del contrato en SECOP II.',
      ),
      DocumentoPlantilla(
        id: 'arl',
        nombre: 'Certificación ARL',
        regla: ReglaDocumento.soloPrimero,
      ),
      DocumentoPlantilla(
        id: 'rut',
        nombre: 'RUT actualizado',
        regla: ReglaDocumento.soloPrimero,
      ),
      DocumentoPlantilla(
        id: 'certificacion_bancaria',
        nombre: 'Certificación bancaria',
        regla: ReglaDocumento.soloPrimero,
        descripcion: 'Vigente.',
      ),
      DocumentoPlantilla(
        id: 'cdp',
        nombre: 'CDP',
        regla: ReglaDocumento.soloPrimero,
        descripcion: 'Certificado de disponibilidad presupuestal.',
      ),
      DocumentoPlantilla(
        id: 'rp',
        nombre: 'RP',
        regla: ReglaDocumento.soloPrimero,
        descripcion: 'Registro presupuestal.',
      ),
    ],
  );

  PlantillaInforme copyWith({
    List<String>? encabezado,
    List<EtapaAprobacion>? etapas,
    List<DocumentoPlantilla>? documentos,
    bool? quincenalHabilitado,
    bool? estampillaDepartamental,
    double? tarifaEstampillaPct,
    String? declaracion,
    List<String>? secciones,
  }) => PlantillaInforme(
    encabezado: encabezado ?? this.encabezado,
    etapas: etapas ?? this.etapas,
    documentos: documentos ?? this.documentos,
    quincenalHabilitado: quincenalHabilitado ?? this.quincenalHabilitado,
    estampillaDepartamental:
        estampillaDepartamental ?? this.estampillaDepartamental,
    tarifaEstampillaPct: tarifaEstampillaPct ?? this.tarifaEstampillaPct,
    declaracion: declaracion ?? this.declaracion,
    secciones: secciones ?? this.secciones,
  );

  Map<String, dynamic> toMap() => {
    'encabezado': encabezado,
    'etapas': etapas.map((e) => e.toMap()).toList(),
    'documentos': documentos.map((d) => d.toMap()).toList(),
    'quincenalHabilitado': quincenalHabilitado,
    'estampillaDepartamental': estampillaDepartamental,
    'tarifaEstampillaPct': tarifaEstampillaPct,
    'declaracion': declaracion,
    'secciones': secciones,
  };

  factory PlantillaInforme.fromMap(Map<String, dynamic> m) {
    List<Map<String, dynamic>> lista(dynamic v) => [
      for (final e in (v as List? ?? const []))
        if (e is Map) Map<String, dynamic>.from(e),
    ];
    final secciones = [
      for (final s in (m['secciones'] as List? ?? const [])) '$s',
    ];
    return PlantillaInforme(
      encabezado: [
        for (final l in (m['encabezado'] as List? ?? const [])) '$l',
      ],
      etapas: lista(m['etapas']).map(EtapaAprobacion.fromMap).toList(),
      documentos: lista(m['documentos'])
          .map(DocumentoPlantilla.fromMap)
          .toList(),
      quincenalHabilitado: m['quincenalHabilitado'] != false,
      estampillaDepartamental: m['estampillaDepartamental'] != false,
      tarifaEstampillaPct:
          (m['tarifaEstampillaPct'] as num?)?.toDouble() ?? 1.5,
      declaracion: '${m['declaracion'] ?? textoDeclaracionPorDefecto}',
      secciones: secciones.isEmpty ? seccionesPorDefecto : secciones,
    );
  }
}

// =============================================================================
// Plan del contrato
// =============================================================================

class ObligacionContractual {
  const ObligacionContractual({required this.id, required this.texto});
  final String id;
  final String texto;

  Map<String, dynamic> toMap() => {'id': id, 'texto': texto};
  factory ObligacionContractual.fromMap(Map<String, dynamic> m) =>
      ObligacionContractual(id: '${m['id']}', texto: '${m['texto'] ?? ''}');
}

class DatoPresupuestal {
  const DatoPresupuestal({
    this.numero = '',
    this.fechaIso = '',
    this.valorCop = 0,
  });
  final String numero;
  final String fechaIso;
  final int valorCop;

  bool get registrado => numero.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'numero': numero,
    'fechaIso': fechaIso,
    'valorCop': valorCop,
  };
  factory DatoPresupuestal.fromMap(dynamic m) => m is Map
      ? DatoPresupuestal(
          numero: '${m['numero'] ?? ''}',
          fechaIso: '${m['fechaIso'] ?? ''}',
          valorCop: (m['valorCop'] as num?)?.toInt() ?? 0,
        )
      : const DatoPresupuestal();
}

class PeriodoInforme {
  const PeriodoInforme({
    required this.numero,
    required this.desde,
    required this.hasta,
  });
  final int numero;
  final DateTime desde;
  final DateTime hasta;

  String get id => fechaIsoCorta(desde);

  /// El informe vence el último día del periodo.
  DateTime get limite => hasta;
}

class PlanSupervision {
  const PlanSupervision({
    required this.supervisorNombre,
    required this.supervisorEmail,
    required this.fechaInicio,
    required this.fechaFin,
    required this.valorPeriodoCop,
    required this.claseRiesgo,
    required this.obligaciones,
    required this.plantilla,
    this.periodicidad = Periodicidad.mensual,
    this.formaPago = '',
    this.sectorial = '',
    this.cdp = const DatoPresupuestal(),
    this.rp = const DatoPresupuestal(),
    this.actualizadoPor = '',
    this.actualizadoEnMs = 0,
  });

  final String supervisorNombre;
  final String supervisorEmail;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final Periodicidad periodicidad;

  /// Valor que se cobra por periodo (sugerido al contratista).
  final int valorPeriodoCop;
  final String formaPago;
  final String sectorial;
  final int claseRiesgo;
  final DatoPresupuestal cdp;
  final DatoPresupuestal rp;
  final List<ObligacionContractual> obligaciones;

  /// Copia de la plantilla de la entidad al configurar el contrato, con los
  /// responsables de cada etapa. El contratista solo puede leer esta copia.
  final PlantillaInforme plantilla;
  final String actualizadoPor;
  final int actualizadoEnMs;

  List<EtapaAprobacion> get etapas => plantilla.etapas;

  /// Periodos del contrato: mes a mes desde la fecha de inicio (9 oct – 8 nov)
  /// o de 15 días en los quincenales.
  List<PeriodoInforme> get periodos {
    final lista = <PeriodoInforme>[];
    final fin = DateTime(fechaFin.year, fechaFin.month, fechaFin.day);
    var desde = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    var i = 0;
    while (!desde.isAfter(fin) && lista.length < 80) {
      final siguiente = periodicidad == Periodicidad.quincenal
          ? desde.add(const Duration(days: 15))
          : _sumarMeses(
              DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day),
              i + 1,
            );
      var hasta = siguiente.subtract(const Duration(days: 1));
      if (hasta.isAfter(fin)) hasta = fin;
      lista.add(PeriodoInforme(numero: i + 1, desde: desde, hasta: hasta));
      desde = siguiente;
      i++;
    }
    return lista;
  }

  static DateTime _sumarMeses(DateTime base, int meses) {
    final destino = DateTime(base.year, base.month + meses, 1);
    final ultimoDia = DateTime(destino.year, destino.month + 1, 0).day;
    return DateTime(destino.year, destino.month, base.day.clamp(1, ultimoDia));
  }

  PeriodoInforme? periodo(String id) {
    for (final p in periodos) {
      if (p.id == id) return p;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'supervisorNombre': supervisorNombre,
    'supervisorEmail': supervisorEmail.trim().toLowerCase(),
    'fechaInicioIso': fechaIsoCorta(fechaInicio),
    'fechaFinIso': fechaIsoCorta(fechaFin),
    'periodicidad': periodicidad.name,
    'valorPeriodoCop': valorPeriodoCop,
    'formaPago': formaPago,
    'sectorial': sectorial,
    'claseRiesgo': claseRiesgo,
    'cdp': cdp.toMap(),
    'rp': rp.toMap(),
    'obligaciones': obligaciones.map((o) => o.toMap()).toList(),
    'plantilla': plantilla.toMap(),
    // Copia plana para que las reglas de Firestore validen al responsable.
    'etapas': plantilla.etapas.map((e) => e.toMap()).toList(),
    'actualizadoPor': actualizadoPor,
    'actualizadoEnMs': actualizadoEnMs,
  };

  factory PlanSupervision.fromMap(Map<String, dynamic> m) => PlanSupervision(
    supervisorNombre: '${m['supervisorNombre'] ?? ''}',
    supervisorEmail: '${m['supervisorEmail'] ?? ''}',
    fechaInicio: DateTime.tryParse('${m['fechaInicioIso']}') ?? DateTime.now(),
    fechaFin: DateTime.tryParse('${m['fechaFinIso']}') ?? DateTime.now(),
    periodicidad: Periodicidad.desde(m['periodicidad']?.toString()),
    valorPeriodoCop:
        (m['valorPeriodoCop'] as num?)?.toInt() ??
        (m['valorMensualCop'] as num?)?.toInt() ??
        0,
    formaPago: '${m['formaPago'] ?? ''}',
    sectorial: '${m['sectorial'] ?? ''}',
    claseRiesgo: (m['claseRiesgo'] as num?)?.toInt() ?? 1,
    cdp: DatoPresupuestal.fromMap(m['cdp']),
    rp: DatoPresupuestal.fromMap(m['rp']),
    obligaciones: [
      for (final o in (m['obligaciones'] as List? ?? const []))
        if (o is Map)
          ObligacionContractual.fromMap(Map<String, dynamic>.from(o)),
    ],
    plantilla: m['plantilla'] is Map
        ? PlantillaInforme.fromMap(Map<String, dynamic>.from(m['plantilla']))
        : PlantillaInforme.porDefecto(''),
    actualizadoPor: '${m['actualizadoPor'] ?? ''}',
    actualizadoEnMs: (m['actualizadoEnMs'] as num?)?.toInt() ?? 0,
  );
}

// =============================================================================
// Informe del periodo
// =============================================================================

enum EstadoInforme {
  pendiente('Sin iniciar', 0xFF64748B, 0xFFF1F5F9),
  borrador('En elaboración', 0xFF475569, 0xFFE2E8F0),
  enRevision('En revisión', 0xFF1D4ED8, 0xFFDBEAFE),
  devuelto('Devuelto', 0xFFB45309, 0xFFFEF3C7),
  aprobado('Aprobado', 0xFF15803D, 0xFFDCFCE7),
  pagado('Pagado', 0xFF0F766E, 0xFFCCFBF1);

  const EstadoInforme(this.etiqueta, this.color, this.fondo);
  final String etiqueta;
  final int color;
  final int fondo;

  static EstadoInforme desde(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => pendiente);

  bool get editablePorContratista =>
      this == pendiente || this == borrador || this == devuelto;
}

class ArchivoAdjunto {
  const ArchivoAdjunto({
    required this.id,
    required this.nombre,
    required this.mime,
    required this.tamanoBytes,
    required this.sha256,
    required this.cargadoEnIso,
  });

  final String id;
  final String nombre;
  final String mime;
  final int tamanoBytes;
  final String sha256;
  final String cargadoEnIso;

  bool get esPdf =>
      mime == 'application/pdf' || nombre.toLowerCase().endsWith('.pdf');

  String get tamanoLegible {
    if (tamanoBytes < 1024 * 1024) return '${(tamanoBytes / 1024).ceil()} KB';
    return '${(tamanoBytes / 1048576).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'mime': mime,
    'tamanoBytes': tamanoBytes,
    'sha256': sha256,
    'cargadoEnIso': cargadoEnIso,
  };

  factory ArchivoAdjunto.fromMap(Map<String, dynamic> m) => ArchivoAdjunto(
    id: '${m['id'] ?? ''}',
    nombre: '${m['nombre'] ?? ''}',
    mime: '${m['mime'] ?? ''}',
    tamanoBytes: (m['tamanoBytes'] as num?)?.toInt() ?? 0,
    sha256: '${m['sha256'] ?? ''}',
    cargadoEnIso: '${m['cargadoEnIso'] ?? ''}',
  );
}

List<ArchivoAdjunto> _archivos(dynamic v) => [
  for (final a in (v as List? ?? const []))
    if (a is Map) ArchivoAdjunto.fromMap(Map<String, dynamic>.from(a)),
];

/// Soporte del informe: un título, para qué sirve y sus archivos.
class Anexo {
  const Anexo({
    required this.id,
    this.titulo = '',
    this.descripcion = '',
    this.obligaciones = const [],
    this.archivos = const [],
  });

  final String id;
  final String titulo;
  final String descripcion;

  /// Obligaciones que respalda (ids).
  final List<String> obligaciones;
  final List<ArchivoAdjunto> archivos;

  Anexo copyWith({
    String? titulo,
    String? descripcion,
    List<String>? obligaciones,
    List<ArchivoAdjunto>? archivos,
  }) => Anexo(
    id: id,
    titulo: titulo ?? this.titulo,
    descripcion: descripcion ?? this.descripcion,
    obligaciones: obligaciones ?? this.obligaciones,
    archivos: archivos ?? this.archivos,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'descripcion': descripcion,
    'obligaciones': obligaciones,
    'archivos': archivos.map((a) => a.toMap()).toList(),
  };

  factory Anexo.fromMap(Map<String, dynamic> m) => Anexo(
    id: '${m['id'] ?? ''}',
    titulo: '${m['titulo'] ?? ''}',
    descripcion: '${m['descripcion'] ?? ''}',
    obligaciones: [
      for (final o in (m['obligaciones'] as List? ?? const [])) '$o',
    ],
    archivos: _archivos(m['archivos']),
  );
}

class PlanillaAporte {
  const PlanillaAporte({
    this.periodo = '',
    this.fechaPagoIso = '',
    this.numero = '',
    this.ibcCop = 0,
    this.valorCop = 0,
  });

  /// Mes cotizado, `aaaa-mm`.
  final String periodo;
  final String fechaPagoIso;
  final String numero;
  final int ibcCop;

  /// Total pagado en la planilla (salud + pensión + ARL).
  final int valorCop;

  bool get diligenciada =>
      numero.trim().isNotEmpty && valorCop > 0 && fechaPagoIso.isNotEmpty;

  PlanillaAporte copyWith({
    String? periodo,
    String? fechaPagoIso,
    String? numero,
    int? ibcCop,
    int? valorCop,
  }) => PlanillaAporte(
    periodo: periodo ?? this.periodo,
    fechaPagoIso: fechaPagoIso ?? this.fechaPagoIso,
    numero: numero ?? this.numero,
    ibcCop: ibcCop ?? this.ibcCop,
    valorCop: valorCop ?? this.valorCop,
  );

  Map<String, dynamic> toMap() => {
    'periodo': periodo,
    'fechaPagoIso': fechaPagoIso,
    'numero': numero,
    'ibcCop': ibcCop,
    'valorCop': valorCop,
  };

  factory PlanillaAporte.fromMap(Map<String, dynamic> m) => PlanillaAporte(
    periodo: '${m['periodo'] ?? ''}',
    fechaPagoIso: '${m['fechaPagoIso'] ?? ''}',
    numero: '${m['numero'] ?? ''}',
    ibcCop: (m['ibcCop'] as num?)?.toInt() ?? 0,
    valorCop: (m['valorCop'] as num?)?.toInt() ?? 0,
  );
}

class EstampillaDepartamental {
  const EstampillaDepartamental({
    this.fechaPagoIso = '',
    this.tarifaPct = 1.5,
    this.valorPagadoCop = 0,
    this.interesesCop = 0,
    this.liquidacion = '',
  });

  final String fechaPagoIso;
  final double tarifaPct;
  final int valorPagadoCop;
  final int interesesCop;
  final String liquidacion;

  bool get diligenciada =>
      fechaPagoIso.isNotEmpty &&
      valorPagadoCop > 0 &&
      liquidacion.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'fechaPagoIso': fechaPagoIso,
    'tarifaPct': tarifaPct,
    'valorPagadoCop': valorPagadoCop,
    'interesesCop': interesesCop,
    'liquidacion': liquidacion,
  };

  factory EstampillaDepartamental.fromMap(dynamic m) => m is Map
      ? EstampillaDepartamental(
          fechaPagoIso: '${m['fechaPagoIso'] ?? ''}',
          tarifaPct: (m['tarifaPct'] as num?)?.toDouble() ?? 1.5,
          valorPagadoCop: (m['valorPagadoCop'] as num?)?.toInt() ?? 0,
          interesesCop: (m['interesesCop'] as num?)?.toInt() ?? 0,
          liquidacion: '${m['liquidacion'] ?? ''}',
        )
      : const EstampillaDepartamental();
}

/// Datos para la cuenta de cobro y los formatos; se precargan del informe
/// anterior.
class DatosCobro {
  const DatosCobro({
    this.direccion = '',
    this.ciudad = '',
    this.celular = '',
    this.banco = '',
    this.tipoCuenta = 'Ahorros',
    this.numeroCuenta = '',
    this.responsableIva = false,
    this.declaranteRenta = false,
    this.facturadorElectronico = false,
    this.regimenSimple = false,
  });

  final String direccion;
  final String ciudad;
  final String celular;
  final String banco;
  final String tipoCuenta;
  final String numeroCuenta;
  final bool responsableIva;
  final bool declaranteRenta;
  final bool facturadorElectronico;
  final bool regimenSimple;

  bool get completos =>
      direccion.trim().isNotEmpty &&
      ciudad.trim().isNotEmpty &&
      celular.trim().isNotEmpty &&
      banco.trim().isNotEmpty &&
      numeroCuenta.trim().isNotEmpty;

  DatosCobro copyWith({
    String? direccion,
    String? ciudad,
    String? celular,
    String? banco,
    String? tipoCuenta,
    String? numeroCuenta,
    bool? responsableIva,
    bool? declaranteRenta,
    bool? facturadorElectronico,
    bool? regimenSimple,
  }) => DatosCobro(
    direccion: direccion ?? this.direccion,
    ciudad: ciudad ?? this.ciudad,
    celular: celular ?? this.celular,
    banco: banco ?? this.banco,
    tipoCuenta: tipoCuenta ?? this.tipoCuenta,
    numeroCuenta: numeroCuenta ?? this.numeroCuenta,
    responsableIva: responsableIva ?? this.responsableIva,
    declaranteRenta: declaranteRenta ?? this.declaranteRenta,
    facturadorElectronico: facturadorElectronico ?? this.facturadorElectronico,
    regimenSimple: regimenSimple ?? this.regimenSimple,
  );

  Map<String, dynamic> toMap() => {
    'direccion': direccion,
    'ciudad': ciudad,
    'celular': celular,
    'banco': banco,
    'tipoCuenta': tipoCuenta,
    'numeroCuenta': numeroCuenta,
    'responsableIva': responsableIva,
    'declaranteRenta': declaranteRenta,
    'facturadorElectronico': facturadorElectronico,
    'regimenSimple': regimenSimple,
  };

  factory DatosCobro.fromMap(dynamic m) => m is Map
      ? DatosCobro(
          direccion: '${m['direccion'] ?? ''}',
          ciudad: '${m['ciudad'] ?? ''}',
          celular: '${m['celular'] ?? ''}',
          banco: '${m['banco'] ?? ''}',
          tipoCuenta: '${m['tipoCuenta'] ?? 'Ahorros'}',
          numeroCuenta: '${m['numeroCuenta'] ?? ''}',
          responsableIva: m['responsableIva'] == true,
          declaranteRenta: m['declaranteRenta'] == true,
          facturadorElectronico: m['facturadorElectronico'] == true,
          regimenSimple: m['regimenSimple'] == true,
        )
      : const DatosCobro();
}

class RevisionEtapa {
  const RevisionEtapa({
    required this.etapaId,
    required this.etapaNombre,
    required this.actor,
    required this.fechaIso,
    required this.aprobado,
    this.concepto = '',
    this.observacion = '',
    this.itemsDevueltos = const [],
  });

  final String etapaId;
  final String etapaNombre;
  final String actor;
  final String fechaIso;
  final bool aprobado;
  final String concepto;

  /// Obligatoria al devolver.
  final String observacion;

  /// Lo que el contratista debe corregir: `obligacion:<id>`, `documento:<id>`,
  /// `aportes`, `cobro`, `anexos`, `estampilla`.
  final List<String> itemsDevueltos;


  Map<String, dynamic> toMap() => {
    'etapaId': etapaId,
    'etapaNombre': etapaNombre,
    'actor': actor,
    'fechaIso': fechaIso,
    'aprobado': aprobado,
    'concepto': concepto,
    'observacion': observacion,
    'itemsDevueltos': itemsDevueltos,
  };

  factory RevisionEtapa.fromMap(Map<String, dynamic> m) => RevisionEtapa(
    etapaId: '${m['etapaId'] ?? ''}',
    etapaNombre: '${m['etapaNombre'] ?? ''}',
    actor: '${m['actor'] ?? ''}',
    fechaIso: '${m['fechaIso'] ?? ''}',
    aprobado: m['aprobado'] == true,
    concepto: '${m['concepto'] ?? ''}',
    observacion: '${m['observacion'] ?? ''}',
    itemsDevueltos: [
      for (final i in (m['itemsDevueltos'] as List? ?? const [])) '$i',
    ],
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

class InformePeriodo {
  const InformePeriodo({
    required this.id,
    required this.numero,
    required this.desdeIso,
    required this.hastaIso,
    this.estado = EstadoInforme.pendiente,
    this.valorCobradoCop = 0,
    this.actividades = const {},
    this.anexos = const [],
    this.planillas = const [PlanillaAporte()],
    this.pensionado = false,
    this.motivoNoPension = '',
    this.estampilla = const EstampillaDepartamental(),
    this.datosCobro = const DatosCobro(),
    this.documentos = const {},
    this.declaracion = false,
    this.enviadoEnIso = '',
    this.primeraPresentacionIso = '',
    this.etapaActual = 0,
    this.revisiones = const [],
    this.aprobadoEnIso = '',
    this.pagoReferencia = '',
    this.pagadoEnIso = '',
    this.historial = const [],
    this.respuestas = const {},
  });

  factory InformePeriodo.nuevo(
    PeriodoInforme p,
    PlanSupervision plan, {
    InformePeriodo? anterior,
  }) => InformePeriodo(
    id: p.id,
    numero: p.numero,
    desdeIso: fechaIsoCorta(p.desde),
    hastaIso: fechaIsoCorta(p.hasta),
    valorCobradoCop: plan.valorPeriodoCop,
    planillas: [PlanillaAporte(periodo: periodoMes(p.desde))],
    pensionado: anterior?.pensionado ?? false,
    motivoNoPension: anterior?.motivoNoPension ?? '',
    datosCobro: anterior?.datosCobro ?? const DatosCobro(),
    estampilla: EstampillaDepartamental(
      tarifaPct: plan.plantilla.tarifaEstampillaPct,
    ),
  );

  final String id;
  final int numero;
  final String desdeIso;
  final String hastaIso;
  final EstadoInforme estado;
  final int valorCobradoCop;

  /// Obligación → actividades realizadas.
  final Map<String, String> actividades;
  final List<Anexo> anexos;

  /// Hasta dos planillas (p. ej. dos en el último periodo).
  final List<PlanillaAporte> planillas;
  final bool pensionado;
  final String motivoNoPension;
  final EstampillaDepartamental estampilla;
  final DatosCobro datosCobro;

  /// Documento de la plantilla → archivos cargados.
  final Map<String, List<ArchivoAdjunto>> documentos;
  final bool declaracion;
  final String enviadoEnIso;
  final String primeraPresentacionIso;

  /// Índice de la etapa de aprobación en curso.
  final int etapaActual;
  final List<RevisionEtapa> revisiones;
  final String aprobadoEnIso;
  final String pagoReferencia;
  final String pagadoEnIso;
  final List<EventoInforme> historial;

  /// Respuesta del contratista a cada devolución (clave: fecha de la
  /// revisión). Va aparte para que el contratista no toque las revisiones.
  final Map<String, String> respuestas;

  bool get existe => estado != EstadoInforme.pendiente;
  DateTime get desde => DateTime.parse(desdeIso);
  DateTime get hasta => DateTime.parse(hastaIso);

  /// Última devolución, si el informe está devuelto.
  RevisionEtapa? get devolucion {
    if (estado != EstadoInforme.devuelto) return null;
    for (final r in revisiones.reversed) {
      if (!r.aprobado) return r;
    }
    return null;
  }

  bool estaDevuelto(String item) =>
      devolucion?.itemsDevueltos.contains(item) ?? false;

  /// Días de retraso de la primera presentación frente al último día del
  /// periodo (0 si llegó a tiempo).
  int get diasRetraso {
    final primera = DateTime.tryParse(primeraPresentacionIso)?.toLocal();
    if (primera == null) return 0;
    final limite = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);
    if (!primera.isAfter(limite)) return 0;
    return DateTime(
      primera.year,
      primera.month,
      primera.day,
    ).difference(DateTime(hasta.year, hasta.month, hasta.day)).inDays;
  }

  List<DocumentoPlantilla> documentosDelPeriodo(PlanSupervision plan) =>
      plan.plantilla.documentos.where((d) => d.aplicaEn(numero)).toList();

  bool pideEstampilla(PlanSupervision plan) =>
      plan.plantilla.estampillaDepartamental && numero == 1;

  /// Lo que falta para poder enviar, en el orden del asistente.
  List<String> faltantes(PlanSupervision plan, {bool firmaRegistrada = true}) =>
      [
        if (valorCobradoCop <= 0) 'El valor a cobrar.',
        for (final (i, o) in plan.obligaciones.indexed)
          if ((actividades[o.id] ?? '').trim().length < 15)
            'Las actividades de la obligación ${i + 1}.',
        if (!planillas.any((p) => p.diligenciada))
          'Los datos de la planilla de seguridad social.',
        if (pideEstampilla(plan) && !estampilla.diligenciada)
          'El pago de la estampilla departamental.',
        if (!datosCobro.completos) 'Los datos para la cuenta de cobro.',
        for (final d in documentosDelPeriodo(plan))
          if (d.origen == OrigenDocumento.contratista &&
              (documentos[d.id] ?? const []).isEmpty)
            'Adjuntar: ${d.nombre}.',
        if (!firmaRegistrada) 'Registrar tu firma.',
        if (!declaracion) 'Aceptar la declaración bajo juramento.',
      ];

  /// Revisión automática que ve el equipo antes de decidir.
  List<Verificacion> verificar(PlanSupervision plan) {
    final aporte = AporteEsperado.calcular(
      valorMensualCop: plan.periodicidad == Periodicidad.quincenal
          ? valorCobradoCop * 2
          : valorCobradoCop,
      claseRiesgo: plan.claseRiesgo,
      anio: desde.year,
    );
    final pagado = planillas.fold<int>(0, (s, p) => s + p.valorCop);
    final minimo = aporte.totalContratista(pensionado: pensionado);
    final sinActividades = [
      for (final (i, o) in plan.obligaciones.indexed)
        if ((actividades[o.id] ?? '').trim().length < 15) i + 1,
    ];
    final docsFaltantes = [
      for (final d in documentosDelPeriodo(plan))
        if (d.origen == OrigenDocumento.contratista &&
            (documentos[d.id] ?? const []).isEmpty)
          d.nombre,
    ];
    final mesEsperado = periodoMes(desde);
    return [
      Verificacion(
        sinActividades.isEmpty,
        sinActividades.isEmpty
            ? 'Todas las obligaciones tienen actividades descritas.'
            : 'Sin actividades: obligación ${sinActividades.join(', ')}.',
      ),
      Verificacion(
        pagado + 100 >= minimo,
        'Aportes ${formatoCop(pagado)} · mínimo ${formatoCop(minimo)} (IBC ${formatoCop(aporte.ibc)}'
        '${pensionado ? ', pensionado' : ''}).',
      ),
      Verificacion(
        planillas.any((p) => p.periodo == mesEsperado),
        planillas.any((p) => p.periodo == mesEsperado)
            ? 'Aporte de ${nombreMes(mesEsperado)} (mes vencido) registrado.'
            : 'No hay planilla del periodo ${nombreMes(mesEsperado)}.',
      ),
      Verificacion(
        docsFaltantes.isEmpty,
        docsFaltantes.isEmpty
            ? 'Documentos obligatorios completos (${documentosDelPeriodo(plan).length}).'
            : 'Faltan: ${docsFaltantes.join(', ')}.',
      ),
      if (pideEstampilla(plan))
        Verificacion(
          estampilla.diligenciada,
          estampilla.diligenciada
              ? 'Estampilla departamental pagada: ${formatoCop(estampilla.valorPagadoCop)}.'
              : 'Falta el pago de la estampilla departamental.',
        ),
      Verificacion(
        diasRetraso == 0,
        diasRetraso == 0
            ? 'Presentado a tiempo (límite ${fechaLegible(hasta)}).'
            : 'Presentado con $diasRetraso día${diasRetraso == 1 ? '' : 's'} de retraso.',
      ),
    ];
  }

  InformePeriodo copyWith({
    EstadoInforme? estado,
    int? valorCobradoCop,
    Map<String, String>? actividades,
    List<Anexo>? anexos,
    List<PlanillaAporte>? planillas,
    bool? pensionado,
    String? motivoNoPension,
    EstampillaDepartamental? estampilla,
    DatosCobro? datosCobro,
    Map<String, List<ArchivoAdjunto>>? documentos,
    bool? declaracion,
    String? enviadoEnIso,
    String? primeraPresentacionIso,
    int? etapaActual,
    List<RevisionEtapa>? revisiones,
    List<EventoInforme>? historial,
    Map<String, String>? respuestas,
  }) => InformePeriodo(
    id: id,
    numero: numero,
    desdeIso: desdeIso,
    hastaIso: hastaIso,
    estado: estado ?? this.estado,
    valorCobradoCop: valorCobradoCop ?? this.valorCobradoCop,
    actividades: actividades ?? this.actividades,
    anexos: anexos ?? this.anexos,
    planillas: planillas ?? this.planillas,
    pensionado: pensionado ?? this.pensionado,
    motivoNoPension: motivoNoPension ?? this.motivoNoPension,
    estampilla: estampilla ?? this.estampilla,
    datosCobro: datosCobro ?? this.datosCobro,
    documentos: documentos ?? this.documentos,
    declaracion: declaracion ?? this.declaracion,
    enviadoEnIso: enviadoEnIso ?? this.enviadoEnIso,
    primeraPresentacionIso:
        primeraPresentacionIso ?? this.primeraPresentacionIso,
    etapaActual: etapaActual ?? this.etapaActual,
    revisiones: revisiones ?? this.revisiones,
    aprobadoEnIso: aprobadoEnIso,
    pagoReferencia: pagoReferencia,
    pagadoEnIso: pagadoEnIso,
    historial: historial ?? this.historial,
    respuestas: respuestas ?? this.respuestas,
  );

  /// Campos que escribe el contratista (las reglas de Firestore solo le
  /// permiten estos).
  Map<String, dynamic> camposContratista() => {
    'id': id,
    'numero': numero,
    'desdeIso': desdeIso,
    'hastaIso': hastaIso,
    'estado': estado.name,
    'valorCobradoCop': valorCobradoCop,
    'actividades': actividades,
    'anexos': anexos.map((a) => a.toMap()).toList(),
    'planillas': planillas.map((p) => p.toMap()).toList(),
    'pensionado': pensionado,
    'motivoNoPension': motivoNoPension,
    'estampilla': estampilla.toMap(),
    'datosCobro': datosCobro.toMap(),
    'documentos': documentos.map(
      (k, v) => MapEntry(k, v.map((a) => a.toMap()).toList()),
    ),
    'declaracion': declaracion,
    'enviadoEnIso': enviadoEnIso,
    'primeraPresentacionIso': primeraPresentacionIso,
    'respuestas': respuestas,
    'historial': historial.map((e) => e.toMap()).toList(),
    'actualizadoEnMs': DateTime.now().millisecondsSinceEpoch,
  };

  factory InformePeriodo.fromMap(Map<String, dynamic> m) => InformePeriodo(
    id: '${m['id'] ?? ''}',
    numero: (m['numero'] as num?)?.toInt() ?? 1,
    desdeIso: '${m['desdeIso'] ?? ''}',
    hastaIso: '${m['hastaIso'] ?? ''}',
    estado: EstadoInforme.desde(m['estado']?.toString()),
    valorCobradoCop: (m['valorCobradoCop'] as num?)?.toInt() ?? 0,
    actividades: {
      for (final e in (m['actividades'] as Map? ?? const {}).entries)
        '${e.key}': '${e.value ?? ''}',
    },
    anexos: [
      for (final a in (m['anexos'] as List? ?? const []))
        if (a is Map) Anexo.fromMap(Map<String, dynamic>.from(a)),
    ],
    planillas: [
      for (final p in (m['planillas'] as List? ?? const []))
        if (p is Map) PlanillaAporte.fromMap(Map<String, dynamic>.from(p)),
    ],
    pensionado: m['pensionado'] == true,
    motivoNoPension: '${m['motivoNoPension'] ?? ''}',
    estampilla: EstampillaDepartamental.fromMap(m['estampilla']),
    datosCobro: DatosCobro.fromMap(m['datosCobro']),
    documentos: {
      for (final e in (m['documentos'] as Map? ?? const {}).entries)
        '${e.key}': _archivos(e.value),
    },
    declaracion: m['declaracion'] == true,
    enviadoEnIso: '${m['enviadoEnIso'] ?? ''}',
    primeraPresentacionIso: '${m['primeraPresentacionIso'] ?? ''}',
    etapaActual: (m['etapaActual'] as num?)?.toInt() ?? 0,
    revisiones: [
      for (final r in (m['revisiones'] as List? ?? const []))
        if (r is Map) RevisionEtapa.fromMap(Map<String, dynamic>.from(r)),
    ],
    aprobadoEnIso: '${m['aprobadoEnIso'] ?? ''}',
    pagoReferencia: '${m['pagoReferencia'] ?? ''}',
    pagadoEnIso: '${m['pagadoEnIso'] ?? ''}',
    historial: [
      for (final e in (m['historial'] as List? ?? const []))
        if (e is Map) EventoInforme.fromMap(Map<String, dynamic>.from(e)),
    ],
    respuestas: {
      for (final e in (m['respuestas'] as Map? ?? const {}).entries)
        '${e.key}': '${e.value ?? ''}',
    },
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
  final InformePeriodo informe;

  EtapaAprobacion? get etapa =>
      informe.estado == EstadoInforme.enRevision &&
          informe.etapaActual < plan.etapas.length
      ? plan.etapas[informe.etapaActual]
      : null;
}

class SupervisionException implements Exception {
  const SupervisionException(this.message);
  final String message;
  @override
  String toString() => message;
}

// =============================================================================
// Utilidades de formato
// =============================================================================

String fechaIsoCorta(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String periodoMes(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

const List<String> mesesEs = [
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

const List<String> _diasEs = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

/// "2026-10" → "octubre de 2026".
String nombreMes(String aaaaMm) {
  final p = aaaaMm.split('-');
  final mes = p.length == 2 ? int.tryParse(p[1]) ?? 0 : 0;
  if (mes < 1 || mes > 12) return aaaaMm;
  return '${mesesEs[mes - 1]} de ${p[0]}';
}

/// "vie 9 oct 2026".
String fechaLegible(DateTime d, {bool conDia = true}) =>
    '${conDia ? '${_diasEs[d.weekday - 1]} ' : ''}${d.day} ${mesesEs[d.month - 1].substring(0, 3)} ${d.year}';

/// "28/09/2026".
String fechaNumerica(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _miles(int v) =>
    v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

String formatoCop(int v) => '\$ ${_miles(v)}';

/// Valor en letras para la cuenta de cobro: "TRES MILLONES QUINIENTOS MIL PESOS".
String valorEnLetras(int valor) {
  const unidades = [
    '',
    'UNO',
    'DOS',
    'TRES',
    'CUATRO',
    'CINCO',
    'SEIS',
    'SIETE',
    'OCHO',
    'NUEVE',
    'DIEZ',
    'ONCE',
    'DOCE',
    'TRECE',
    'CATORCE',
    'QUINCE',
    'DIECISÉIS',
    'DIECISIETE',
    'DIECIOCHO',
    'DIECINUEVE',
    'VEINTE',
    'VEINTIUNO',
    'VEINTIDÓS',
    'VEINTITRÉS',
    'VEINTICUATRO',
    'VEINTICINCO',
    'VEINTISÉIS',
    'VEINTISIETE',
    'VEINTIOCHO',
    'VEINTINUEVE',
  ];
  const decenas = [
    '',
    '',
    '',
    'TREINTA',
    'CUARENTA',
    'CINCUENTA',
    'SESENTA',
    'SETENTA',
    'OCHENTA',
    'NOVENTA',
  ];
  const centenas = [
    '',
    'CIENTO',
    'DOSCIENTOS',
    'TRESCIENTOS',
    'CUATROCIENTOS',
    'QUINIENTOS',
    'SEISCIENTOS',
    'SETECIENTOS',
    'OCHOCIENTOS',
    'NOVECIENTOS',
  ];
  String menorMil(int n) {
    if (n == 0) return '';
    if (n == 100) return 'CIEN';
    final c = n ~/ 100, r = n % 100;
    final partes = <String>[if (c > 0) centenas[c]];
    if (r > 0) {
      if (r < 30) {
        partes.add(unidades[r]);
      } else {
        final d = r ~/ 10, u = r % 10;
        partes.add(u == 0 ? decenas[d] : '${decenas[d]} Y ${unidades[u]}');
      }
    }
    return partes.join(' ');
  }

  if (valor == 0) return 'CERO PESOS';
  final millones = valor ~/ 1000000;
  final miles = (valor % 1000000) ~/ 1000;
  final resto = valor % 1000;
  final partes = <String>[
    if (millones == 1)
      'UN MILLÓN'
    else if (millones > 1)
      '${menorMil(millones).replaceAll(RegExp(r'UNO$'), 'UN')} MILLONES',
    if (miles == 1)
      'MIL'
    else if (miles > 1)
      '${menorMil(miles).replaceAll(RegExp(r'UNO$'), 'UN')} MIL',
    if (resto > 0) menorMil(resto),
  ];
  final texto = partes.join(' ');
  return '$texto${resto == 0 && miles == 0 && millones > 0 ? ' DE' : ''} PESOS';
}

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

  static DocumentReference<Map<String, dynamic>> _refFirma(String token) =>
      _expediente(token).collection('supervision').doc('firma');

  static CollectionReference<Map<String, dynamic>> _informes(String token) =>
      _expediente(token).collection('informes');

  static DocumentReference<Map<String, dynamic>> _refArchivo(
    String token,
    String informeId,
    String archivoId,
  ) => _informes(token).doc(informeId).collection('archivos').doc(archivoId);

  static DocumentReference<Map<String, dynamic>> _refPlantilla(
    String equipoUid,
  ) => _db.collection('plantillas_informe').doc(equipoUid);

  static String get _actor => AuthService.getActiveUserDisplayName();
  static String _ahora() => DateTime.now().toUtc().toIso8601String();

  static Future<T> _guardar<T>(Future<T> Function() accion) async {
    try {
      return await accion().timeout(const Duration(seconds: 25));
    } on SupervisionException {
      rethrow;
    } catch (e) {
      debugPrint('SupervisionService: $e');
      if (e is FirebaseException && e.code == 'permission-denied') {
        throw const SupervisionException(
          'No tienes permiso para esta acción. Si acabas de actualizar la app, '
          'publica de nuevo las reglas de Firestore.',
        );
      }
      if (e is TimeoutException) {
        throw const SupervisionException(
          'El servidor no respondió. Revisa tu conexión e intenta de nuevo.',
        );
      }
      throw const SupervisionException(
        'No fue posible guardar. Revisa tu conexión e intenta de nuevo.',
      );
    }
  }

  // ------------------------------------------------------------- Permisos

  static String get emailActual =>
      FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';

  static bool esTitular(ExpedienteContratoPs e) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return uid.isNotEmpty && (e.equipoUid == uid || e.creadoPorUid == uid);
  }

  static bool puedeConfigurar(ExpedienteContratoPs e) =>
      esTitular(e) ||
      EquipoJuridicoService.tienePermiso(PermisoEquipo.crearContratos);

  /// Decide la etapa en curso: su responsable o el titular del equipo.
  static bool puedeDecidir(
    ExpedienteContratoPs e,
    PlanSupervision plan,
    InformePeriodo inf,
  ) {
    if (inf.estado != EstadoInforme.enRevision) return false;
    if (esTitular(e)) return true;
    return inf.etapaActual < plan.etapas.length &&
        plan.etapas[inf.etapaActual].esResponsable(emailActual);
  }

  static bool puedeRegistrarPago(ExpedienteContratoPs e) =>
      esTitular(e) ||
      EquipoJuridicoService.tienePermiso(PermisoEquipo.verificarDocumentos);

  // ------------------------------------------------------------- Lectura

  static Stream<PlanSupervision?> escucharPlan(String token) => _refPlan(token)
      .snapshots()
      .map((s) => s.data() == null ? null : PlanSupervision.fromMap(s.data()!));

  static Stream<Map<String, InformePeriodo>> escucharInformes(String token) =>
      _informes(token).snapshots().map(
        (q) => {for (final d in q.docs) d.id: InformePeriodo.fromMap(d.data())},
      );

  /// Firma registrada del contratista (PNG) o `null`.
  static Stream<Uint8List?> escucharFirma(String token) =>
      _refFirma(token).snapshots().map((s) {
        final b64 = s.data()?['archivoBase64'];
        return b64 is String && b64.isNotEmpty ? base64Decode(b64) : null;
      });

  static Future<Uint8List?> leerFirma(String token) async {
    final s = await _refFirma(token).get();
    final b64 = s.data()?['archivoBase64'];
    return b64 is String && b64.isNotEmpty ? base64Decode(b64) : null;
  }

  /// Bandeja del equipo: informes enviados de todos los contratos con plan.
  static Stream<List<InformeEnBandeja>> escucharBandeja(
    List<ExpedienteContratoPs> expedientes,
  ) {
    late StreamController<List<InformeEnBandeja>> control;
    final subs = <StreamSubscription<dynamic>>[];
    final planes = <String, PlanSupervision>{};
    final informes = <String, Map<String, InformePeriodo>>{};
    final porToken = {
      for (final e in expedientes) e.tokenInvitado.toLowerCase(): e,
    };

    void emitir() {
      final lista =
          <InformeEnBandeja>[
            for (final entry in planes.entries)
              if (porToken[entry.key] != null)
                for (final inf
                    in (informes[entry.key] ?? const <String, InformePeriodo>{})
                        .values)
                  if (inf.existe && inf.estado != EstadoInforme.borrador)
                    InformeEnBandeja(
                      expediente: porToken[entry.key]!,
                      plan: entry.value,
                      informe: inf,
                    ),
          ]..sort(
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
              p == null ? planes.remove(token) : planes[token] = p;
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

  // ------------------------------------------------------------- Plantilla

  static Future<PlantillaInforme> plantillaDelEquipo({
    required String entidad,
  }) async {
    final equipo = EquipoJuridicoService.equipoUidActivo;
    if (equipo.isEmpty) return PlantillaInforme.porDefecto(entidad);
    try {
      final s = await _refPlantilla(equipo)
          .get()
          .timeout(const Duration(seconds: 15));
      if (s.data() != null) return PlantillaInforme.fromMap(s.data()!);
    } catch (e) {
      debugPrint('plantillaDelEquipo: $e');
    }
    return PlantillaInforme.porDefecto(entidad);
  }

  static Future<void> guardarPlantilla(PlantillaInforme p) async {
    final equipo = EquipoJuridicoService.equipoUidActivo;
    if (equipo.isEmpty) {
      throw const SupervisionException('Inicia sesión nuevamente.');
    }
    if (p.etapas.isEmpty) {
      throw const SupervisionException(
        'La cadena de aprobación necesita al menos una etapa.',
      );
    }
    await _guardar(
      () => _refPlantilla(equipo).set({
        ...p.toMap(),
        'actualizadoPor': _actor,
        'actualizadoEnMs': DateTime.now().millisecondsSinceEpoch,
      }),
    );
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
        'La fecha de terminación no puede ser anterior a la de inicio.',
      );
    }
    if (plan.obligaciones.isEmpty) {
      throw const SupervisionException(
        'Agrega al menos una obligación del contrato.',
      );
    }
    final sinResponsable = plan.etapas.where(
      (e) => !e.responsableEmail.contains('@'),
    );
    if (sinResponsable.isNotEmpty) {
      throw SupervisionException(
        'Indica el correo del responsable de "${sinResponsable.first.nombre}".',
      );
    }
    if (plan.periodicidad == Periodicidad.quincenal &&
        !plan.plantilla.quincenalHabilitado) {
      throw const SupervisionException(
        'La entidad no tiene habilitados los informes quincenales.',
      );
    }
    final datos = PlanSupervision(
      supervisorNombre: plan.supervisorNombre.trim(),
      supervisorEmail: plan.supervisorEmail.trim(),
      fechaInicio: plan.fechaInicio,
      fechaFin: plan.fechaFin,
      periodicidad: plan.periodicidad,
      valorPeriodoCop: plan.valorPeriodoCop,
      formaPago: plan.formaPago.trim(),
      sectorial: plan.sectorial.trim(),
      claseRiesgo: plan.claseRiesgo,
      cdp: plan.cdp,
      rp: plan.rp,
      obligaciones: plan.obligaciones,
      plantilla: plan.plantilla,
      actualizadoPor: _actor,
      actualizadoEnMs: DateTime.now().millisecondsSinceEpoch,
    ).toMap();
    await _guardar(() => _refPlan(expediente.tokenInvitado).set(datos));
  }

  // ------------------------------------------------------------- Contratista

  static Future<void> guardarBorrador(
    String token,
    InformePeriodo informe,
  ) async {
    if (informe.existe && !informe.estado.editablePorContratista) {
      throw const SupervisionException(
        'Este informe ya fue enviado y está en revisión.',
      );
    }
    final datos = informe.copyWith(
      estado: informe.estado == EstadoInforme.devuelto
          ? EstadoInforme.devuelto
          : EstadoInforme.borrador,
    );
    await _guardar(
      () =>
          _informes(token)
              .doc(informe.id)
              .set(datos.camposContratista(), SetOptions(merge: true)),
    );
  }

  /// Registra la firma (PNG) con la que la app firma los formatos.
  static Future<void> guardarFirma(String token, Uint8List png) async {
    if (png.lengthInBytes > 600 * 1024) {
      throw const SupervisionException(
        'La imagen de la firma es muy pesada (máximo 600 KB).',
      );
    }
    await _guardar(
      () => _refFirma(token).set({
        'archivoBase64': base64Encode(png),
        'partes': 0,
        'mime': 'image/png',
        'actualizadoEnIso': _ahora(),
      }),
    );
  }

  /// Elige un archivo y lo sube; devuelve sus datos para guardarlos en el
  /// informe (el informe se guarda primero: las reglas lo exigen).
  static Future<ArchivoAdjunto?> subirArchivo(
    String token,
    InformePeriodo informe,
  ) async {
    final archivo = await pickContractDocumentFile();
    if (archivo == null) return null;
    if (!archivo.isValid) {
      throw SupervisionException(
        archivo.errorMessage ?? 'El archivo no es válido.',
      );
    }
    await guardarBorrador(token, informe);
    final id = SecurityService.generateSecureTokenHex(8);
    final meta = ArchivoAdjunto(
      id: id,
      nombre: archivo.fileName,
      mime: archivo.mimeType,
      tamanoBytes: archivo.sizeBytes,
      sha256: archivo.sha256Hash,
      cargadoEnIso: _ahora(),
    );
    await _guardar(
      () => ArchivoFragmentado.guardar(
        _refArchivo(token, informe.id, id),
        base64: base64Encode(archivo.bytes),
        metadatos: meta.toMap(),
      ),
    );
    return meta;
  }

  static Future<Uint8List?> bytesArchivo(
    String token,
    String informeId,
    ArchivoAdjunto a,
  ) async {
    final b64 = await ArchivoFragmentado.leer(
      _refArchivo(token, informeId, a.id),
    );
    return b64 == null ? null : base64Decode(b64);
  }

  static Future<bool> abrirArchivo(
    String token,
    String informeId,
    ArchivoAdjunto a,
  ) async {
    try {
      final bytes = await bytesArchivo(token, informeId, a);
      if (bytes == null) return false;
      if (a.esPdf || a.mime.startsWith('image/')) {
        return openBinaryInNewTab(bytes: bytes, mimeType: a.mime);
      }
      return downloadBinaryBytes(
        bytes: bytes,
        fileName: a.nombre,
        mimeType: a.mime,
      );
    } catch (e) {
      debugPrint('abrirArchivo: $e');
      return false;
    }
  }

  static Future<void> enviar(
    String token,
    InformePeriodo informe,
    PlanSupervision plan, {
    required String contratista,
    required bool firmaRegistrada,
    String respuesta = '',
  }) async {
    final faltan = informe.faltantes(plan, firmaRegistrada: firmaRegistrada);
    if (faltan.isNotEmpty) throw SupervisionException('Falta: ${faltan.first}');
    final reenvio = informe.estado == EstadoInforme.devuelto;
    final dev = informe.devolucion;
    // Un informe devuelto vuelve a la etapa que lo devolvió: `etapaActual`
    // no cambia al devolver, y el contratista nunca la escribe.
    final ahora = _ahora();
    final datos = informe.copyWith(
      estado: EstadoInforme.enRevision,
      enviadoEnIso: ahora,
      primeraPresentacionIso: informe.primeraPresentacionIso.isEmpty
          ? ahora
          : informe.primeraPresentacionIso,
      respuestas: dev != null && respuesta.trim().isNotEmpty
          ? {...informe.respuestas, dev.fechaIso: respuesta.trim()}
          : informe.respuestas,
      historial: [
        ...informe.historial,
        EventoInforme(
          fechaIso: ahora,
          actor: contratista,
          accion: reenvio
              ? 'Reenvió el informe corregido'
              : 'Firmó y envió el informe',
          detalle: [
            formatoCop(informe.valorCobradoCop),
            if (respuesta.trim().isNotEmpty) respuesta.trim(),
          ].join(' · '),
        ),
      ],
    );
    await _guardar(
      () =>
          _informes(token)
              .doc(informe.id)
              .set(datos.camposContratista(), SetOptions(merge: true)),
    );
  }

  // ------------------------------------------------------------- Revisión

  static Future<void> _actualizarEquipo(
    ExpedienteContratoPs exp,
    InformePeriodo informe,
    Map<String, dynamic> cambios,
    EventoInforme evento,
  ) => _guardar(
    () => _informes(exp.tokenInvitado).doc(informe.id).update({
      ...cambios,
      'historial': [
        ...informe.historial,
        evento,
      ].map((e) => e.toMap()).toList(),
      'actualizadoEnMs': DateTime.now().millisecondsSinceEpoch,
    }),
  );

  static Future<void> aprobarEtapa(
    ExpedienteContratoPs exp,
    PlanSupervision plan,
    InformePeriodo inf, {
    String concepto = '',
  }) async {
    if (!puedeDecidir(exp, plan, inf)) {
      throw const SupervisionException(
        'Esta etapa le corresponde a otro responsable.',
      );
    }
    final etapa = plan.etapas[inf.etapaActual];
    final ultima = inf.etapaActual >= plan.etapas.length - 1;
    final ahora = _ahora();
    await _actualizarEquipo(
      exp,
      inf,
      {
        'estado':
            (ultima ? EstadoInforme.aprobado : EstadoInforme.enRevision).name,
        'etapaActual': ultima ? inf.etapaActual : inf.etapaActual + 1,
        if (ultima) 'aprobadoEnIso': ahora,
        'revisiones': [
          ...inf.revisiones.map((r) => r.toMap()),
          RevisionEtapa(
            etapaId: etapa.id,
            etapaNombre: etapa.nombre,
            actor: _actor,
            fechaIso: ahora,
            aprobado: true,
            concepto: concepto.trim(),
          ).toMap(),
        ],
      },
      EventoInforme(
        fechaIso: ahora,
        actor: _actor,
        accion: ultima
            ? 'Aprobó el informe (${etapa.nombre})'
            : 'Revisó y verificó (${etapa.nombre}); pasa a ${plan.etapas[inf.etapaActual + 1].nombre}',
        detalle: concepto.trim(),
      ),
    );
  }

  static Future<void> devolver(
    ExpedienteContratoPs exp,
    PlanSupervision plan,
    InformePeriodo inf, {
    required String observacion,
    required List<String> items,
  }) async {
    if (!puedeDecidir(exp, plan, inf)) {
      throw const SupervisionException(
        'Esta etapa le corresponde a otro responsable.',
      );
    }
    if (observacion.trim().length < 10) {
      throw const SupervisionException(
        'Escribe qué debe corregir el contratista y cómo.',
      );
    }
    final etapa = plan.etapas[inf.etapaActual];
    final ahora = _ahora();
    await _actualizarEquipo(
      exp,
      inf,
      {
        'estado': EstadoInforme.devuelto.name,
        'declaracion': false,
        'revisiones': [
          ...inf.revisiones.map((r) => r.toMap()),
          RevisionEtapa(
            etapaId: etapa.id,
            etapaNombre: etapa.nombre,
            actor: _actor,
            fechaIso: ahora,
            aprobado: false,
            observacion: observacion.trim(),
            itemsDevueltos: items,
          ).toMap(),
        ],
      },
      EventoInforme(
        fechaIso: ahora,
        actor: _actor,
        accion: 'Devolvió el informe al contratista (${etapa.nombre})',
        detalle: observacion.trim(),
      ),
    );
  }

  static Future<void> registrarPago(
    ExpedienteContratoPs exp,
    InformePeriodo inf, {
    required String referencia,
  }) async {
    if (!puedeRegistrarPago(exp)) {
      throw const SupervisionException(
        'Tu usuario no tiene permiso para registrar pagos.',
      );
    }
    final ahora = _ahora();
    await _actualizarEquipo(
      exp,
      inf,
      {
        'estado': EstadoInforme.pagado.name,
        'pagoReferencia': referencia.trim(),
        'pagadoEnIso': ahora,
      },
      EventoInforme(
        fechaIso: ahora,
        actor: _actor,
        accion: 'Registró el pago',
        detalle: referencia.trim(),
      ),
    );
  }

  /// Borra plan, firma e informes (con archivos) al eliminar el expediente.
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
      await _refFirma(token).delete();
    } catch (e) {
      debugPrint('SupervisionService.borrarDatos: $e');
    }
  }
}
