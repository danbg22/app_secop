import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/document_file_picker.dart';
import '../utils/file_downloader.dart';
import '../utils/realtime_tab_bridge.dart';
import 'auth_service.dart';
import 'security_service.dart';

/// Estados del ciclo de vida de cada documento requerido en la OPS.
enum EstadoDocumentoJuridico {
  pendiente,
  enRevision,
  devueltoSubsanar,
  subsanadoEnRevision,
  aprobado;

  String get codigo => switch (this) {
    EstadoDocumentoJuridico.pendiente => 'PENDIENTE',
    EstadoDocumentoJuridico.enRevision => 'EN_REVISION',
    EstadoDocumentoJuridico.devueltoSubsanar => 'DEVUELTO_SUBSANAR',
    EstadoDocumentoJuridico.subsanadoEnRevision => 'SUBSANADO_EN_REVISION',
    EstadoDocumentoJuridico.aprobado => 'APROBADO',
  };

  /// Etiqueta concisa para píldoras minimalistas (`• Cargado`, `• Verificado`, etc.).
  String get etiquetaCorta => switch (this) {
    EstadoDocumentoJuridico.pendiente => 'Sin cargar',
    EstadoDocumentoJuridico.enRevision => 'Cargado',
    EstadoDocumentoJuridico.devueltoSubsanar => 'Devuelto',
    EstadoDocumentoJuridico.subsanadoEnRevision => 'Subsanado',
    EstadoDocumentoJuridico.aprobado => 'Verificado',
  };

  String get etiqueta => switch (this) {
    EstadoDocumentoJuridico.pendiente => 'Pendiente por cargar',
    EstadoDocumentoJuridico.enRevision => 'Cargado · Por revisar',
    EstadoDocumentoJuridico.devueltoSubsanar => 'Devuelto con observaciones',
    EstadoDocumentoJuridico.subsanadoEnRevision => 'Subsanado · Por revisar',
    EstadoDocumentoJuridico.aprobado => 'Revisado y verificado',
  };

  static EstadoDocumentoJuridico fromCodigo(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'EN_REVISION':
        return EstadoDocumentoJuridico.enRevision;
      case 'DEVUELTO_SUBSANAR':
        return EstadoDocumentoJuridico.devueltoSubsanar;
      case 'SUBSANADO_EN_REVISION':
        return EstadoDocumentoJuridico.subsanadoEnRevision;
      case 'APROBADO':
        return EstadoDocumentoJuridico.aprobado;
      default:
        return EstadoDocumentoJuridico.pendiente;
    }
  }
}

/// Documento requerido dentro del expediente de prestación de servicios (OPS).
class ApartadoDocumentoContrato {
  const ApartadoDocumentoContrato({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.obligatorio = true,
    this.estado = EstadoDocumentoJuridico.pendiente,
    this.archivoNombre,
    this.archivoMime,
    this.archivoTamanoBytes = 0,
    this.archivoSha256,
    this.archivoBase64,
    this.versionCarga = 0,
    this.notaContratista,
    this.observacionJuridica,
    this.fechaCargaIso,
    this.fechaRevisionIso,
    this.revisadoPor,
    this.cargadoPorNombre,
    this.cargadoPorCedula,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final bool obligatorio;
  final EstadoDocumentoJuridico estado;
  final String? archivoNombre;
  final String? archivoMime;
  final int archivoTamanoBytes;
  final String? archivoSha256;
  final String? archivoBase64;
  final int versionCarga;
  final String? notaContratista;
  final String? observacionJuridica;
  final String? fechaCargaIso;
  final String? fechaRevisionIso;
  final String? revisadoPor;
  final String? cargadoPorNombre;
  final String? cargadoPorCedula;

  bool get tieneArchivoCargado =>
      (archivoNombre != null && archivoNombre!.trim().isNotEmpty) &&
      estado != EstadoDocumentoJuridico.pendiente;

  bool get requiereSubsanacion =>
      estado == EstadoDocumentoJuridico.devueltoSubsanar;

  bool get estaAprobado => estado == EstadoDocumentoJuridico.aprobado;

  bool get pendienteRevisionJuridica =>
      estado == EstadoDocumentoJuridico.enRevision ||
      estado == EstadoDocumentoJuridico.subsanadoEnRevision;

  String get formatoCorto {
    final mime = (archivoMime ?? '').toLowerCase();
    final name = (archivoNombre ?? '').toLowerCase();
    if (mime.contains('pdf') || name.endsWith('.pdf')) return 'PDF';
    if (mime.contains('png') || name.endsWith('.png')) return 'PNG';
    if (mime.contains('jpg') ||
        mime.contains('jpeg') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return 'JPG';
    }
    if (name.endsWith('.docx') || name.endsWith('.doc')) return 'DOCX';
    return 'Documento';
  }

  String get tamanoFormateado {
    if (archivoTamanoBytes <= 0) return '';
    if (archivoTamanoBytes < 1024) return '$archivoTamanoBytes B';
    final kb = archivoTamanoBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  ApartadoDocumentoContrato copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    bool? obligatorio,
    EstadoDocumentoJuridico? estado,
    String? archivoNombre,
    String? archivoMime,
    int? archivoTamanoBytes,
    String? archivoSha256,
    String? archivoBase64,
    int? versionCarga,
    String? notaContratista,
    String? observacionJuridica,
    String? fechaCargaIso,
    String? fechaRevisionIso,
    String? revisadoPor,
    String? cargadoPorNombre,
    String? cargadoPorCedula,
    bool limpiarObservacion = false,
  }) {
    return ApartadoDocumentoContrato(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      obligatorio: obligatorio ?? this.obligatorio,
      estado: estado ?? this.estado,
      archivoNombre: archivoNombre ?? this.archivoNombre,
      archivoMime: archivoMime ?? this.archivoMime,
      archivoTamanoBytes: archivoTamanoBytes ?? this.archivoTamanoBytes,
      archivoSha256: archivoSha256 ?? this.archivoSha256,
      archivoBase64: archivoBase64 ?? this.archivoBase64,
      versionCarga: versionCarga ?? this.versionCarga,
      notaContratista: notaContratista ?? this.notaContratista,
      observacionJuridica: limpiarObservacion
          ? null
          : (observacionJuridica ?? this.observacionJuridica),
      fechaCargaIso: fechaCargaIso ?? this.fechaCargaIso,
      fechaRevisionIso: fechaRevisionIso ?? this.fechaRevisionIso,
      revisadoPor: revisadoPor ?? this.revisadoPor,
      cargadoPorNombre: cargadoPorNombre ?? this.cargadoPorNombre,
      cargadoPorCedula: cargadoPorCedula ?? this.cargadoPorCedula,
    );
  }

  Map<String, dynamic> toMap({bool omitLargeBinary = false}) {
    final rawB64 = archivoBase64 ?? '';
    final safeB64 = (omitLargeBinary && rawB64.length > 140000)
        ? null
        : archivoBase64;
    return <String, dynamic>{
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'obligatorio': obligatorio,
      'estado': estado.codigo,
      'archivoNombre': archivoNombre,
      'archivoMime': archivoMime,
      'archivoTamanoBytes': archivoTamanoBytes,
      'archivoSha256': archivoSha256,
      'archivoBase64': safeB64,
      'versionCarga': versionCarga,
      'notaContratista': notaContratista,
      'observacionJuridica': observacionJuridica,
      'fechaCargaIso': fechaCargaIso,
      'fechaRevisionIso': fechaRevisionIso,
      'revisadoPor': revisadoPor,
      'cargadoPorNombre': cargadoPorNombre,
      'cargadoPorCedula': cargadoPorCedula,
    };
  }

  factory ApartadoDocumentoContrato.fromMap(Map<String, dynamic> map) {
    return ApartadoDocumentoContrato(
      id: (map['id'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
      obligatorio: map['obligatorio'] != false,
      estado: EstadoDocumentoJuridico.fromCodigo(map['estado']?.toString()),
      archivoNombre: map['archivoNombre']?.toString(),
      archivoMime: map['archivoMime']?.toString(),
      archivoTamanoBytes: (map['archivoTamanoBytes'] as num?)?.toInt() ?? 0,
      archivoSha256: map['archivoSha256']?.toString(),
      archivoBase64: map['archivoBase64']?.toString(),
      versionCarga: (map['versionCarga'] as num?)?.toInt() ?? 0,
      notaContratista: map['notaContratista']?.toString(),
      observacionJuridica: map['observacionJuridica']?.toString(),
      fechaCargaIso: map['fechaCargaIso']?.toString(),
      fechaRevisionIso: map['fechaRevisionIso']?.toString(),
      revisadoPor: map['revisadoPor']?.toString(),
      cargadoPorNombre: map['cargadoPorNombre']?.toString(),
      cargadoPorCedula: map['cargadoPorCedula']?.toString(),
    );
  }
}

/// Evento inmutable en la línea de tiempo de trazabilidad del expediente.
class EventoTrazabilidadContrato {
  const EventoTrazabilidadContrato({
    required this.id,
    required this.fechaIso,
    required this.tipo,
    required this.actorNombre,
    required this.actorRol,
    required this.titulo,
    required this.detalle,
    this.apartadoNombre,
    this.correoDestino,
  });

  final String id;
  final String fechaIso;
  final String tipo;
  final String actorNombre;
  final String actorRol;
  final String titulo;
  final String detalle;
  final String? apartadoNombre;
  final String? correoDestino;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'fechaIso': fechaIso,
    'tipo': tipo,
    'actorNombre': actorNombre,
    'actorRol': actorRol,
    'titulo': titulo,
    'detalle': detalle,
    'apartadoNombre': apartadoNombre,
    'correoDestino': correoDestino,
  };

  factory EventoTrazabilidadContrato.fromMap(Map<String, dynamic> map) {
    return EventoTrazabilidadContrato(
      id: (map['id'] ?? '').toString(),
      fechaIso: (map['fechaIso'] ?? '').toString(),
      tipo: (map['tipo'] ?? 'EVENTO').toString(),
      actorNombre: (map['actorNombre'] ?? 'Sistema').toString(),
      actorRol: (map['actorRol'] ?? 'Plataforma').toString(),
      titulo: (map['titulo'] ?? '').toString(),
      detalle: (map['detalle'] ?? '').toString(),
      apartadoNombre: map['apartadoNombre']?.toString(),
      correoDestino: map['correoDestino']?.toString(),
    );
  }
}

/// Registro auditado de notificación enviada al correo del contratista.
class NotificacionCorreoSubsanacion {
  const NotificacionCorreoSubsanacion({
    required this.id,
    required this.expedienteToken,
    required this.numeroContrato,
    required this.destinatarioEmail,
    required this.destinatarioNombre,
    required this.asunto,
    required this.cuerpoTexto,
    required this.fechaEnvioIso,
    required this.apartadoNombre,
    required this.observacion,
    required this.linkInvitado,
    this.estadoEntrega = 'Enviado',
  });

  final String id;
  final String expedienteToken;
  final String numeroContrato;
  final String destinatarioEmail;
  final String destinatarioNombre;
  final String asunto;
  final String cuerpoTexto;
  final String fechaEnvioIso;
  final String apartadoNombre;
  final String observacion;
  final String linkInvitado;
  final String estadoEntrega;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'expedienteToken': expedienteToken,
    'numeroContrato': numeroContrato,
    'destinatarioEmail': destinatarioEmail,
    'destinatarioNombre': destinatarioNombre,
    'asunto': asunto,
    'cuerpoTexto': cuerpoTexto,
    'fechaEnvioIso': fechaEnvioIso,
    'apartadoNombre': apartadoNombre,
    'observacion': observacion,
    'linkInvitado': linkInvitado,
    'estadoEntrega': estadoEntrega,
  };

  factory NotificacionCorreoSubsanacion.fromMap(Map<String, dynamic> map) {
    return NotificacionCorreoSubsanacion(
      id: (map['id'] ?? '').toString(),
      expedienteToken: (map['expedienteToken'] ?? '').toString(),
      numeroContrato: (map['numeroContrato'] ?? '').toString(),
      destinatarioEmail: (map['destinatarioEmail'] ?? '').toString(),
      destinatarioNombre: (map['destinatarioNombre'] ?? '').toString(),
      asunto: (map['asunto'] ?? '').toString(),
      cuerpoTexto: (map['cuerpoTexto'] ?? '').toString(),
      fechaEnvioIso: (map['fechaEnvioIso'] ?? '').toString(),
      apartadoNombre: (map['apartadoNombre'] ?? '').toString(),
      observacion: (map['observacion'] ?? '').toString(),
      linkInvitado: (map['linkInvitado'] ?? '').toString(),
      estadoEntrega: (map['estadoEntrega'] ?? 'Enviado').toString(),
    );
  }
}

/// Expediente estructurado de contratación de prestación de servicios (OPS).
class ExpedienteContratoPs {
  const ExpedienteContratoPs({
    required this.id,
    required this.tokenInvitado,
    required this.entidadNombre,
    required this.entidadNit,
    required this.dependencia,
    required this.numeroContrato,
    required this.objetoContrato,
    required this.valorContratoCop,
    required this.plazoEjecucion,
    required this.contratistaNombreEsperado,
    required this.contratistaCedulaEsperada,
    required this.contratistaCorreo,
    required this.contratistaTelefono,
    required this.creadoPorEmail,
    required this.creadoPorNombre,
    required this.fechaCreacionIso,
    required this.apartados,
    required this.trazabilidad,
    this.creadoPorUid = '',
    this.actualizadoEnMs = 0,
    this.notificacionesCorreo = const <NotificacionCorreoSubsanacion>[],
    this.avalJuridicoEmitido = false,
    this.fechaAvalIso,
    this.ultimoContratistaValidadoNombre,
    this.ultimoContratistaValidadoCedula,
    this.checksVerificacion = const <bool>[false, false, false, false, false],
    this.conceptoJuridico = '',
  });

  final String id;
  final String tokenInvitado;
  final String entidadNombre;
  final String entidadNit;
  final String dependencia;
  final String numeroContrato;
  final String objetoContrato;
  final int valorContratoCop;
  final String plazoEjecucion;
  final String contratistaNombreEsperado;
  final String contratistaCedulaEsperada;
  final String contratistaCorreo;
  final String contratistaTelefono;
  final String creadoPorEmail;
  final String creadoPorNombre;
  final String creadoPorUid;
  final String fechaCreacionIso;
  final int actualizadoEnMs;
  final List<ApartadoDocumentoContrato> apartados;
  final List<EventoTrazabilidadContrato> trazabilidad;
  final List<NotificacionCorreoSubsanacion> notificacionesCorreo;
  final bool avalJuridicoEmitido;
  final String? fechaAvalIso;
  final String? ultimoContratistaValidadoNombre;
  final String? ultimoContratistaValidadoCedula;
  final List<bool> checksVerificacion;
  final String conceptoJuridico;

  int get totalApartados => apartados.length;
  int get totalCargados =>
      apartados.where((a) => a.tieneArchivoCargado).length;
  int get totalAprobados => apartados.where((a) => a.estaAprobado).length;
  int get totalPorSubsanar =>
      apartados.where((a) => a.requiereSubsanacion).length;
  int get totalEnRevision =>
      apartados.where((a) => a.pendienteRevisionJuridica).length;

  double get porcentajeAvanceAprobacion {
    if (apartados.isEmpty) return 0;
    return totalAprobados / apartados.length;
  }

  bool get todosObligatoriosAprobados {
    final obligatorios = apartados.where((a) => a.obligatorio).toList();
    if (obligatorios.isEmpty) {
      return apartados.isNotEmpty && apartados.every((a) => a.estaAprobado);
    }
    return obligatorios.every((a) => a.estaAprobado);
  }

  String get estadoGlobalEtiqueta {
    if (avalJuridicoEmitido || todosObligatoriosAprobados) {
      return 'Revisado y verificado';
    }
    if (totalPorSubsanar > 0) {
      return totalPorSubsanar == 1
          ? '1 documento con observaciones'
          : '$totalPorSubsanar documentos con observaciones';
    }
    if (totalEnRevision > 0) {
      return totalEnRevision == 1
          ? '1 documento por revisar'
          : '$totalEnRevision documentos por revisar';
    }
    if (totalCargados > 0) {
      return '$totalCargados de $totalApartados cargados';
    }
    return 'Pendiente de cargue';
  }

  ExpedienteContratoPs copyWith({
    List<ApartadoDocumentoContrato>? apartados,
    List<EventoTrazabilidadContrato>? trazabilidad,
    List<NotificacionCorreoSubsanacion>? notificacionesCorreo,
    bool? avalJuridicoEmitido,
    String? fechaAvalIso,
    String? contratistaNombreEsperado,
    String? contratistaCedulaEsperada,
    String? contratistaCorreo,
    String? ultimoContratistaValidadoNombre,
    String? ultimoContratistaValidadoCedula,
    List<bool>? checksVerificacion,
    String? conceptoJuridico,
    int? actualizadoEnMs,
  }) {
    return ExpedienteContratoPs(
      id: id,
      tokenInvitado: tokenInvitado,
      entidadNombre: entidadNombre,
      entidadNit: entidadNit,
      dependencia: dependencia,
      numeroContrato: numeroContrato,
      objetoContrato: objetoContrato,
      valorContratoCop: valorContratoCop,
      plazoEjecucion: plazoEjecucion,
      contratistaNombreEsperado:
          contratistaNombreEsperado ?? this.contratistaNombreEsperado,
      contratistaCedulaEsperada:
          contratistaCedulaEsperada ?? this.contratistaCedulaEsperada,
      contratistaCorreo: contratistaCorreo ?? this.contratistaCorreo,
      contratistaTelefono: contratistaTelefono,
      creadoPorEmail: creadoPorEmail,
      creadoPorNombre: creadoPorNombre,
      creadoPorUid: creadoPorUid,
      fechaCreacionIso: fechaCreacionIso,
      actualizadoEnMs: actualizadoEnMs ?? this.actualizadoEnMs,
      apartados: apartados ?? this.apartados,
      trazabilidad: trazabilidad ?? this.trazabilidad,
      notificacionesCorreo: notificacionesCorreo ?? this.notificacionesCorreo,
      avalJuridicoEmitido: avalJuridicoEmitido ?? this.avalJuridicoEmitido,
      fechaAvalIso: fechaAvalIso ?? this.fechaAvalIso,
      ultimoContratistaValidadoNombre:
          ultimoContratistaValidadoNombre ??
          this.ultimoContratistaValidadoNombre,
      ultimoContratistaValidadoCedula:
          ultimoContratistaValidadoCedula ??
          this.ultimoContratistaValidadoCedula,
      checksVerificacion: checksVerificacion ?? this.checksVerificacion,
      conceptoJuridico: conceptoJuridico ?? this.conceptoJuridico,
    );
  }

  Map<String, dynamic> toMap({bool omitLargeBinary = false}) {
    return <String, dynamic>{
      'id': id,
      'tokenInvitado': tokenInvitado.toLowerCase(),
      'entidadNombre': entidadNombre,
      'entidadNit': entidadNit,
      'dependencia': dependencia,
      'numeroContrato': numeroContrato,
      'objetoContrato': objetoContrato,
      'valorContratoCop': valorContratoCop,
      'plazoEjecucion': plazoEjecucion,
      'contratistaNombreEsperado': contratistaNombreEsperado,
      'contratistaCedulaEsperada': contratistaCedulaEsperada,
      'contratistaCorreo': contratistaCorreo,
      'contratistaTelefono': contratistaTelefono,
      'creadoPorEmail': creadoPorEmail,
      'creadoPorNombre': creadoPorNombre,
      'creadoPorUid': creadoPorUid,
      'fechaCreacionIso': fechaCreacionIso,
      'actualizadoEnMs': actualizadoEnMs,
      'apartados': apartados
          .map((a) => a.toMap(omitLargeBinary: omitLargeBinary))
          .toList(),
      'trazabilidad': trazabilidad.map((e) => e.toMap()).toList(),
      'notificacionesCorreo': notificacionesCorreo
          .map((n) => n.toMap())
          .toList(),
      'avalJuridicoEmitido': avalJuridicoEmitido,
      'fechaAvalIso': fechaAvalIso,
      'ultimoContratistaValidadoNombre': ultimoContratistaValidadoNombre,
      'ultimoContratistaValidadoCedula': ultimoContratistaValidadoCedula,
      'checksVerificacion': checksVerificacion,
      'conceptoJuridico': conceptoJuridico,
    };
  }

  factory ExpedienteContratoPs.fromMap(Map<String, dynamic> map) {
    final rawApartados = map['apartados'];
    final rawTraza = map['trazabilidad'];
    final rawNotifs = map['notificacionesCorreo'];
    final rawChecks = map['checksVerificacion'];

    final parsedChecks = rawChecks is List
        ? rawChecks.map((e) => e == true).toList()
        : <bool>[];
    while (parsedChecks.length < 5) {
      parsedChecks.add(false);
    }

    return ExpedienteContratoPs(
      id: (map['id'] ?? '').toString(),
      tokenInvitado: (map['tokenInvitado'] ?? '').toString().toLowerCase(),
      entidadNombre: (map['entidadNombre'] ?? '').toString(),
      entidadNit: (map['entidadNit'] ?? '').toString(),
      dependencia: (map['dependencia'] ?? '').toString(),
      numeroContrato: (map['numeroContrato'] ?? '').toString(),
      objetoContrato: (map['objetoContrato'] ?? '').toString(),
      valorContratoCop: (map['valorContratoCop'] as num?)?.toInt() ?? 0,
      plazoEjecucion: (map['plazoEjecucion'] ?? '').toString(),
      contratistaNombreEsperado:
          (map['contratistaNombreEsperado'] ?? '').toString(),
      contratistaCedulaEsperada:
          (map['contratistaCedulaEsperada'] ?? '').toString(),
      contratistaCorreo: (map['contratistaCorreo'] ?? '').toString(),
      contratistaTelefono: (map['contratistaTelefono'] ?? '').toString(),
      creadoPorEmail: (map['creadoPorEmail'] ?? '').toString(),
      creadoPorNombre: (map['creadoPorNombre'] ?? '').toString(),
      creadoPorUid: (map['creadoPorUid'] ?? '').toString(),
      fechaCreacionIso: (map['fechaCreacionIso'] ?? '').toString(),
      actualizadoEnMs: (map['actualizadoEnMs'] as num?)?.toInt() ?? 0,
      apartados: rawApartados is List
          ? rawApartados
                .whereType<Map>()
                .map(
                  (e) => ApartadoDocumentoContrato.fromMap(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const <ApartadoDocumentoContrato>[],
      trazabilidad: rawTraza is List
          ? rawTraza
                .whereType<Map>()
                .map(
                  (e) => EventoTrazabilidadContrato.fromMap(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const <EventoTrazabilidadContrato>[],
      notificacionesCorreo: rawNotifs is List
          ? rawNotifs
                .whereType<Map>()
                .map(
                  (e) => NotificacionCorreoSubsanacion.fromMap(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const <NotificacionCorreoSubsanacion>[],
      avalJuridicoEmitido: map['avalJuridicoEmitido'] == true,
      fechaAvalIso: map['fechaAvalIso']?.toString(),
      ultimoContratistaValidadoNombre:
          map['ultimoContratistaValidadoNombre']?.toString(),
      ultimoContratistaValidadoCedula:
          map['ultimoContratistaValidadoCedula']?.toString(),
      checksVerificacion: parsedChecks.take(5).toList(),
      conceptoJuridico: (map['conceptoJuridico'] ?? '').toString(),
    );
  }
}

/// Plantillas estándar de documentos para contratación de prestación de servicios (OPS).
class PlantillaApartadoPs {
  const PlantillaApartadoPs({
    required this.nombre,
    required this.descripcion,
    this.obligatorioPorDefecto = true,
  });

  final String nombre;
  final String descripcion;
  final bool obligatorioPorDefecto;
}

/// Servicio en tiempo real de gestión contractual OPS, verificación documental,
/// devolución con observaciones, subsanación y enlace personalizado para contratistas.
class JuridicoContratacionService {
  JuridicoContratacionService._();

  static const String _prefsKey = 'expedientes_juridicos_ops_v2';

  /// Tokens de los expedientes de demostración que versiones anteriores
  /// creaban automáticamente; se descartan si siguen en almacenamiento local.
  static const Set<String> _tokensDemostracionRetirados = {
    'a8f49c217e5b4d3091bc6e2f84a105d9',
    'c31e7b904f2a48d5b6190e84d2c7f3a2',
  };
  static const String _sharedWebKey = 'contrata_legal_ops_shared_v2';
  static const String _broadcastChannelName = 'contrata_legal_ops_realtime_v2';
  static const String _legacyPrefsKey = 'expedientes_juridicos_ps_v1';

  /// Notificador reactivo disparado al instante cuando llega cualquier cambio
  /// (ya sea desde otra pestaña del navegador o desde otro dispositivo en Firestore).
  static final ValueNotifier<int> expedientesVersion = ValueNotifier<int>(0);

  /// Caché en memoria sincronizada en tiempo real.
  static List<ExpedienteContratoPs>? _cacheMemoria;

  /// Suscripciones activas en tiempo real a documentos de Firestore por token.
  static final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _suscripcionesPorToken =
      <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _suscripcionCreador;
  static bool _puenteTiempoRealInicializado = false;

  /// Checklist jurídico estándar para contratos de prestación de servicios (OPS).
  static const List<String> checklistVerificacionOps = <String>[
    'La cédula de ciudadanía, el RUT actualizado y la certificación bancaria coinciden con el contratista',
    'Los soportes académicos, tarjeta profesional y experiencia acreditan el perfil requerido para el objeto contractual',
    'La afiliación a seguridad social (salud y pensión) y la certificación ARL están vigentes',
    'Los certificados de antecedentes fiscales, disciplinarios, judiciales y medidas correctivas no registran inhabilidades',
    'Los documentos exigidos están completos, legibles, firmados y corresponden al contrato',
  ];

  /// Documentos estándar de contratación OPS en entidades públicas de Colombia.
  static const List<PlantillaApartadoPs> plantillasEstandarColombia =
      <PlantillaApartadoPs>[
        PlantillaApartadoPs(
          nombre: 'Hoja de vida Función Pública (SIGEP)',
          descripcion:
              'Formato único de hoja de vida actualizado y firmado por el aspirante.',
        ),
        PlantillaApartadoPs(
          nombre: 'Cédula de ciudadanía',
          descripcion:
              'Copia legible del documento de identidad por ambas caras en PDF.',
        ),
        PlantillaApartadoPs(
          nombre: 'RUT actualizado',
          descripcion:
              'Registro Único Tributario vigente con actividad económica acorde al objeto.',
        ),
        PlantillaApartadoPs(
          nombre: 'Certificación bancaria',
          descripcion:
              'Certificación de cuenta activa expedida con antigüedad no mayor a 30 días.',
        ),
        PlantillaApartadoPs(
          nombre: 'Seguridad social (planilla)',
          descripcion:
              'Soporte de afiliación o planilla vigente de aportes a salud y pensión.',
        ),
        PlantillaApartadoPs(
          nombre: 'Certificación ARL',
          descripcion:
              'Certificado de afiliación a riesgos laborales vigente.',
        ),
        PlantillaApartadoPs(
          nombre: 'Antecedentes fiscales, disciplinarios y judiciales',
          descripcion:
              'Certificados vigentes de Contraloría, Procuraduría, Policía Nacional y RNMC.',
        ),
        PlantillaApartadoPs(
          nombre: 'Soportes de estudios y experiencia',
          descripcion:
              'Diplomas, acta de grado, tarjeta profesional y certificaciones de experiencia.',
        ),
        PlantillaApartadoPs(
          nombre: 'CDP',
          descripcion:
              'Certificado de disponibilidad presupuestal asociado al proceso.',
          obligatorioPorDefecto: false,
        ),
        PlantillaApartadoPs(
          nombre: 'RP',
          descripcion: 'Registro presupuestal del compromiso contractual.',
          obligatorioPorDefecto: false,
        ),
      ];

  /// Activa la escucha en tiempo real entre pestañas (`BroadcastChannel` + `localStorage`)
  /// y en la nube (`Firestore snapshots`) para el panel del Equipo Jurídico.
  static Future<void> activarTiempoRealEquipoJuridico() async {
    _inicializarPuenteEntrePestanas();
    final lista = await _obtenerCacheLocalInmediata();
    for (final exp in lista) {
      _asegurarSuscripcionDocumentoFirestore(exp.tokenInvitado);
    }
    _asegurarSuscripcionColeccionCreador();
  }

  /// Activa la escucha en tiempo real específica para el enlace del contratista invitado.
  static Future<void> activarTiempoRealContratista(String rawToken) async {
    _inicializarPuenteEntrePestanas();
    final token = rawToken.trim().toLowerCase();
    if (!_esTokenHexValido(token)) return;
    await _obtenerCacheLocalInmediata();
    _asegurarSuscripcionDocumentoFirestore(token);
  }

  static void _inicializarPuenteEntrePestanas() {
    if (_puenteTiempoRealInicializado) return;
    _puenteTiempoRealInicializado = true;

    ensureRealtimeTabListener(
      channelName: _broadcastChannelName,
      storageKey: _sharedWebKey,
      onSyncEvent: (String? payloadJson) {
        if (payloadJson != null && payloadJson.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(payloadJson);
            if (decoded is Map) {
              final entrante = ExpedienteContratoPs.fromMap(
                Map<String, dynamic>.from(decoded),
              );
              if (entrante.tokenInvitado.isNotEmpty) {
                _integrarExpedienteEntranteEnMemoria(
                  entrante,
                  persistirLocal: false,
                );
                return;
              }
            }
          } catch (_) {}
        }
        // Respaldo por evento storage / cambio de pestaña: releer almacenamiento compartido
        unawaited(_releerDesdeAlmacenamientoCompartido());
      },
    );
  }

  static Future<void> _releerDesdeAlmacenamientoCompartido() async {
    final candidatos = <ExpedienteContratoPs>[];

    final rawWeb = readSharedStorage(_sharedWebKey);
    if (rawWeb != null && rawWeb.trim().isNotEmpty) {
      candidatos.addAll(_decodificarListaJson(rawWeb));
    }

    final rawFlutterPrefs = readSharedStorage('flutter.$_prefsKey');
    if (rawFlutterPrefs != null && rawFlutterPrefs.trim().isNotEmpty) {
      candidatos.addAll(_decodificarPosibleDobleJson(rawFlutterPrefs));
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final fromPrefs = prefs.getString(_prefsKey);
      if (fromPrefs != null && fromPrefs.trim().isNotEmpty) {
        candidatos.addAll(_decodificarListaJson(fromPrefs));
      }
    } catch (_) {}

    if (candidatos.isEmpty) return;

    final actuales = _cacheMemoria ?? <ExpedienteContratoPs>[];
    final mapa = <String, ExpedienteContratoPs>{
      for (final e in actuales) e.tokenInvitado.toLowerCase(): e,
    };

    bool huboCambio = false;
    for (final entrante in candidatos) {
      final key = entrante.tokenInvitado.toLowerCase();
      if (key.isEmpty) continue;
      final previo = mapa[key];
      if (previo == null) {
        mapa[key] = entrante;
        _asegurarSuscripcionDocumentoFirestore(key);
        huboCambio = true;
      } else if (_esMasReciente(entrante: entrante, actual: previo)) {
        mapa[key] = _fusionarLocalYRemoto(local: previo, remoto: entrante);
        huboCambio = true;
      }
    }

    if (huboCambio) {
      _cacheMemoria = mapa.values.toList()
        ..sort((a, b) => b.fechaCreacionIso.compareTo(a.fechaCreacionIso));
      final encoded = jsonEncode(_cacheMemoria!.map((e) => e.toMap()).toList());
      writeSharedStorage(_sharedWebKey, encoded);
      expedientesVersion.value++;
    }
  }

  static bool _esMasReciente({
    required ExpedienteContratoPs entrante,
    required ExpedienteContratoPs actual,
  }) {
    if (entrante.actualizadoEnMs != actual.actualizadoEnMs) {
      return entrante.actualizadoEnMs > actual.actualizadoEnMs;
    }
    if (entrante.trazabilidad.length != actual.trazabilidad.length) {
      return entrante.trazabilidad.length > actual.trazabilidad.length;
    }
    if (entrante.totalCargados != actual.totalCargados) {
      return entrante.totalCargados > actual.totalCargados;
    }
    if (entrante.totalAprobados != actual.totalAprobados) {
      return entrante.totalAprobados > actual.totalAprobados;
    }
    if (entrante.totalPorSubsanar != actual.totalPorSubsanar) {
      return true;
    }
    return false;
  }

  static void _integrarExpedienteEntranteEnMemoria(
    ExpedienteContratoPs entrante, {
    bool persistirLocal = true,
  }) {
    final key = entrante.tokenInvitado.toLowerCase();
    if (key.isEmpty) return;

    final lista = _cacheMemoria ?? <ExpedienteContratoPs>[];
    final idx = lista.indexWhere((e) => e.tokenInvitado.toLowerCase() == key);

    if (idx < 0) {
      lista.insert(0, entrante);
      _cacheMemoria = lista;
      _asegurarSuscripcionDocumentoFirestore(key);
      if (persistirLocal) {
        unawaited(_persistirEnAlmacenamientoLocal(lista));
      }
      expedientesVersion.value++;
      return;
    }

    final actual = lista[idx];
    if (!_esMasReciente(entrante: entrante, actual: actual) &&
        !_aportaBinariosFaltantes(entrante: entrante, actual: actual)) {
      return;
    }

    final fusionado = _fusionarLocalYRemoto(local: actual, remoto: entrante);
    lista[idx] = fusionado;
    _cacheMemoria = lista;
    if (persistirLocal) {
      unawaited(_persistirEnAlmacenamientoLocal(lista));
    }
    expedientesVersion.value++;
  }

  static bool _aportaBinariosFaltantes({
    required ExpedienteContratoPs entrante,
    required ExpedienteContratoPs actual,
  }) {
    for (final apEntrante in entrante.apartados) {
      if (apEntrante.archivoBase64 != null &&
          apEntrante.archivoBase64!.isNotEmpty) {
        final match = actual.apartados.where((a) => a.id == apEntrante.id);
        if (match.isNotEmpty &&
            (match.first.archivoBase64 == null ||
                match.first.archivoBase64!.isEmpty)) {
          return true;
        }
      }
    }
    return false;
  }

  static void _asegurarSuscripcionDocumentoFirestore(String rawToken) {
    final token = rawToken.trim().toLowerCase();
    if (!_esTokenHexValido(token)) return;
    if (_suscripcionesPorToken.containsKey(token)) return;

    try {
      final sub = FirebaseFirestore.instance
          .collection('expedientes_juridicos')
          .doc(token)
          .snapshots()
          .listen(
            (DocumentSnapshot<Map<String, dynamic>> snap) {
              if (!snap.exists || snap.data() == null) return;
              final remoto = ExpedienteContratoPs.fromMap(snap.data()!);
              _integrarExpedienteEntranteEnMemoria(remoto);
              unawaited(_hidratarBinariosFaltantesDesdeFirestore(remoto));
            },
            onError: (_) {},
          );
      _suscripcionesPorToken[token] = sub;
    } catch (_) {}
  }

  static void _asegurarSuscripcionColeccionCreador() {
    if (_suscripcionCreador != null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      _suscripcionCreador = FirebaseFirestore.instance
          .collection('expedientes_juridicos')
          .where('creadoPorUid', isEqualTo: uid)
          .snapshots()
          .listen(
            (QuerySnapshot<Map<String, dynamic>> querySnap) {
              for (final doc in querySnap.docs) {
                final remoto = ExpedienteContratoPs.fromMap(doc.data());
                if (remoto.tokenInvitado.isNotEmpty) {
                  _integrarExpedienteEntranteEnMemoria(remoto);
                  _asegurarSuscripcionDocumentoFirestore(remoto.tokenInvitado);
                }
              }
            },
            onError: (_) {},
          );
    } catch (_) {}
  }

  static Future<void> _hidratarBinariosFaltantesDesdeFirestore(
    ExpedienteContratoPs expediente,
  ) async {
    final faltantes = expediente.apartados.where(
      (a) =>
          a.tieneArchivoCargado &&
          (a.archivoBase64 == null || a.archivoBase64!.isEmpty),
    );
    if (faltantes.isEmpty) return;

    try {
      final token = expediente.tokenInvitado.toLowerCase();
      bool actualizoBinario = false;
      final mapaBinarios = <String, String>{};

      for (final ap in faltantes) {
        final doc = await FirebaseFirestore.instance
            .collection('expedientes_juridicos')
            .doc(token)
            .collection('archivos')
            .doc(ap.id)
            .get()
            .timeout(const Duration(milliseconds: 2000));
        final b64 = doc.data()?['archivoBase64']?.toString();
        if (b64 != null && b64.isNotEmpty) {
          mapaBinarios[ap.id] = b64;
          actualizoBinario = true;
        }
      }

      if (actualizoBinario && _cacheMemoria != null) {
        final idx = _cacheMemoria!.indexWhere(
          (e) => e.tokenInvitado.toLowerCase() == token,
        );
        if (idx >= 0) {
          final actual = _cacheMemoria![idx];
          final nuevosApartados = actual.apartados.map((a) {
            if (mapaBinarios.containsKey(a.id)) {
              return a.copyWith(archivoBase64: mapaBinarios[a.id]);
            }
            return a;
          }).toList();
          _cacheMemoria![idx] = actual.copyWith(apartados: nuevosApartados);
          await _persistirEnAlmacenamientoLocal(_cacheMemoria!);
          expedientesVersion.value++;
        }
      }
    } catch (_) {}
  }

  /// Extrae de forma determinista el token de un enlace de contratista invitado.
  static String extraerTokenInvitadoDeUri(Uri uri) {
    final directToken = (uri.queryParameters['invitado_token'] ?? '').trim();
    if (_esTokenHexValido(directToken)) {
      return directToken.toLowerCase();
    }

    if (uri.path.contains('invitado-contrato')) {
      final pathToken = (uri.queryParameters['token'] ?? '').trim();
      if (_esTokenHexValido(pathToken)) {
        return pathToken.toLowerCase();
      }
    }

    final frag = uri.fragment.trim();
    if (frag.isNotEmpty) {
      final normalizedFrag = frag.startsWith('/') ? frag : '/$frag';
      final parsedFrag = Uri.tryParse(normalizedFrag);
      if (parsedFrag != null) {
        final fragToken =
            (parsedFrag.queryParameters['token'] ??
                    parsedFrag.queryParameters['invitado_token'] ??
                    '')
                .trim();
        if (_esTokenHexValido(fragToken)) {
          return fragToken.toLowerCase();
        }
      }
    }
    return '';
  }

  static bool _esTokenHexValido(String value) {
    return RegExp(r'^[a-fA-F0-9]{16,64}$').hasMatch(value.trim());
  }

  /// Construye el link personalizado vinculado de manera exclusiva al contrato.
  static String construirLinkInvitadoWeb(String tokenInvitado) {
    final cleanToken = tokenInvitado.trim().toLowerCase();
    if (kIsWeb) {
      final base = Uri.base;
      final origin = base.hasAuthority
          ? '${base.scheme}://${base.authority}'
          : '';
      final path = base.path.isEmpty ? '/' : base.path;
      return '$origin$path?invitado_token=$cleanToken#/invitado-contrato?token=$cleanToken';
    }
    return 'https://contratalegal.co/?invitado_token=$cleanToken#/invitado-contrato?token=$cleanToken';
  }

  /// Formatea una fecha ISO en formato legible en español (`jue 30 oct 2026, 14:38`).
  static String formatearFechaHumana(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(iso.trim());
    if (parsed == null) {
      return iso.length >= 16
          ? iso.substring(0, 16).replaceFirst('T', ' ')
          : iso;
    }
    final local = parsed.toLocal();
    const dias = <String>['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    const meses = <String>[
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final diaSemana = dias[(local.weekday - 1).clamp(0, 6)];
    final mes = meses[(local.month - 1).clamp(0, 11)];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$diaSemana ${local.day} $mes ${local.year}, $hh:$mm';
  }

  /// Carga instantáneamente los expedientes y activa la sincronización en tiempo real.
  static Future<List<ExpedienteContratoPs>> listarExpedientes() async {
    _inicializarPuenteEntrePestanas();
    await _releerDesdeAlmacenamientoCompartido();
    final locales = await _obtenerCacheLocalInmediata();
    for (final exp in locales) {
      _asegurarSuscripcionDocumentoFirestore(exp.tokenInvitado);
    }
    _asegurarSuscripcionColeccionCreador();
    // El almacenamiento local es compartido con el portal del invitado en el
    // mismo navegador: el panel solo muestra los expedientes del usuario activo.
    final copia = locales.where(_perteneceAlUsuarioActivo).toList()
      ..sort((a, b) => b.fechaCreacionIso.compareTo(a.fechaCreacionIso));
    return copia;
  }

  static bool _perteneceAlUsuarioActivo(ExpedienteContratoPs exp) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final scope = AuthService.getActiveUserStorageScope();
    final email = AuthService.getActiveUserEmail();
    if (exp.creadoPorUid.isNotEmpty) {
      return exp.creadoPorUid == uid || exp.creadoPorUid == scope;
    }
    return email.isNotEmpty &&
        exp.creadoPorEmail.trim().toLowerCase() == email;
  }

  /// Obtiene un expediente por su token único de invitado y activa escucha en tiempo real.
  static Future<ExpedienteContratoPs?> obtenerExpedientePorTokenInvitado(
    String rawToken,
  ) async {
    final token = rawToken.trim().toLowerCase();
    if (!_esTokenHexValido(token)) {
      return null;
    }

    _inicializarPuenteEntrePestanas();
    await _releerDesdeAlmacenamientoCompartido();
    _asegurarSuscripcionDocumentoFirestore(token);

    final locales = await _obtenerCacheLocalInmediata();
    for (final exp in locales) {
      if (exp.tokenInvitado.toLowerCase() == token) {
        return exp;
      }
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('expedientes_juridicos')
          .doc(token)
          .get()
          .timeout(const Duration(milliseconds: 1800));
      if (doc.exists && doc.data() != null) {
        final remoto = ExpedienteContratoPs.fromMap(doc.data()!);
        await _guardarExpedienteInmediato(
          remoto,
          sincronizarRemoto: false,
          emitirBroadcast: false,
        );
        unawaited(_hidratarBinariosFaltantesDesdeFirestore(remoto));
        return remoto;
      }
    } catch (_) {}

    return null;
  }

  /// Crea un nuevo contrato de prestación de servicios (OPS) de forma inmediata.
  static Future<ExpedienteContratoPs> crearExpedienteContratoPs({
    required String entidadNombre,
    required String entidadNit,
    required String dependencia,
    required String numeroContrato,
    required String objetoContrato,
    required int valorContratoCop,
    required String plazoEjecucion,
    required String contratistaNombreEsperado,
    required String contratistaCedulaEsperada,
    required String contratistaCorreo,
    String contratistaTelefono = '',
    required List<ApartadoDocumentoContrato> apartados,
  }) async {
    if (entidadNombre.trim().isEmpty ||
        numeroContrato.trim().isEmpty ||
        objetoContrato.trim().isEmpty) {
      throw ArgumentError(
        'La entidad, el número de contrato y el objeto contractual son obligatorios.',
      );
    }
    if (contratistaNombreEsperado.trim().isEmpty) {
      throw ArgumentError(
        'Ingresa el nombre completo del aspirante a contratista.',
      );
    }
    if (contratistaCorreo.trim().isEmpty ||
        !contratistaCorreo.contains('@')) {
      throw ArgumentError(
        'Ingresa un correo electrónico válido del contratista.',
      );
    }
    if (apartados.isEmpty) {
      throw ArgumentError(
        'Selecciona al menos un documento requerido para el contrato.',
      );
    }

    final ahoraMs = DateTime.now().millisecondsSinceEpoch;
    final ahoraIso = DateTime.fromMillisecondsSinceEpoch(
      ahoraMs,
      isUtc: true,
    ).toIso8601String();
    final token = SecurityService.generateSecureTokenHex(16);
    final id = 'EXP-OPS-$ahoraMs';
    final creadorNombre = AuthService.getActiveUserDisplayName();
    final creadorEmail = AuthService.getActiveUserEmail();
    final creadorUid =
        FirebaseAuth.instance.currentUser?.uid ??
        AuthService.getActiveUserStorageScope();

    final eventoInicial = EventoTrazabilidadContrato(
      id: 'EVT-${SecurityService.generateSecureTokenHex(6)}',
      fechaIso: ahoraIso,
      tipo: 'CREACION',
      actorNombre: creadorNombre,
      actorRol: 'Equipo jurídico',
      titulo: 'Creó el expediente del contrato ${numeroContrato.trim()}',
      detalle:
          'Se registraron ${apartados.length} documentos requeridos y se habilitó el enlace único para ${contratistaNombreEsperado.trim()}.',
    );

    final nuevo = ExpedienteContratoPs(
      id: id,
      tokenInvitado: token,
      entidadNombre: SecurityService.sanitizePlainText(
        entidadNombre,
        maxLength: 180,
      ),
      entidadNit: SecurityService.sanitizePlainText(entidadNit, maxLength: 40),
      dependencia: SecurityService.sanitizePlainText(
        dependencia,
        maxLength: 140,
      ),
      numeroContrato: SecurityService.sanitizePlainText(
        numeroContrato,
        maxLength: 80,
      ),
      objetoContrato: SecurityService.sanitizePlainText(
        objetoContrato,
        maxLength: 900,
      ),
      valorContratoCop: valorContratoCop < 0 ? 0 : valorContratoCop,
      plazoEjecucion: SecurityService.sanitizePlainText(
        plazoEjecucion,
        maxLength: 90,
      ),
      contratistaNombreEsperado: SecurityService.sanitizePlainText(
        contratistaNombreEsperado,
        maxLength: 150,
      ),
      contratistaCedulaEsperada: SecurityService.normalizeDocumentDigits(
        contratistaCedulaEsperada,
      ),
      contratistaCorreo: contratistaCorreo.trim().toLowerCase(),
      contratistaTelefono: SecurityService.sanitizePlainText(
        contratistaTelefono,
        maxLength: 40,
      ),
      creadoPorEmail: creadorEmail,
      creadoPorNombre: creadorNombre,
      creadoPorUid: creadorUid,
      fechaCreacionIso: ahoraIso,
      actualizadoEnMs: ahoraMs,
      apartados: apartados,
      trazabilidad: <EventoTrazabilidadContrato>[eventoInicial],
    );

    _asegurarSuscripcionDocumentoFirestore(token);
    await _guardarExpedienteInmediato(nuevo);
    return nuevo;
  }

  /// Agrega un nuevo documento requerido a un contrato existente en tiempo real.
  static Future<ExpedienteContratoPs> agregarApartadoAlExpediente({
    required String tokenInvitado,
    required String nombreApartado,
    required String descripcionApartado,
    bool obligatorio = true,
  }) async {
    final exp = await obtenerExpedientePorTokenInvitado(tokenInvitado);
    if (exp == null) {
      throw StateError('No se encontró el expediente contractual.');
    }

    final nombreLimpio = SecurityService.sanitizePlainText(
      nombreApartado,
      maxLength: 140,
    );
    if (nombreLimpio.isEmpty) {
      throw ArgumentError('Escribe el nombre del documento requerido.');
    }

    final ahoraMs = DateTime.now().millisecondsSinceEpoch;
    final ahoraIso = DateTime.fromMillisecondsSinceEpoch(
      ahoraMs,
      isUtc: true,
    ).toIso8601String();

    final nuevoApartado = ApartadoDocumentoContrato(
      id: 'APT-${SecurityService.generateSecureTokenHex(6)}',
      nombre: nombreLimpio,
      descripcion: SecurityService.sanitizePlainText(
        descripcionApartado,
        maxLength: 320,
      ),
      obligatorio: obligatorio,
    );

    final evento = EventoTrazabilidadContrato(
      id: 'EVT-${SecurityService.generateSecureTokenHex(6)}',
      fechaIso: ahoraIso,
      tipo: 'CREACION',
      actorNombre: AuthService.getActiveUserDisplayName(),
      actorRol: 'Equipo jurídico',
      apartadoNombre: nuevoApartado.nombre,
      titulo: 'Agregó documento requerido',
      detalle:
          'Se adicionó "${nuevoApartado.nombre}" a los requisitos del contrato ${exp.numeroContrato}.',
    );

    final actualizado = exp.copyWith(
      apartados: <ApartadoDocumentoContrato>[...exp.apartados, nuevoApartado],
      trazabilidad: <EventoTrazabilidadContrato>[evento, ...exp.trazabilidad],
      avalJuridicoEmitido: false,
      actualizadoEnMs: ahoraMs,
    );

    await _guardarExpedienteInmediato(actualizado);
    return actualizado;
  }

  /// Valida el ingreso del contratista invitado solicitando únicamente nombre completo y cédula.
  static Future<ExpedienteContratoPs> validarEIngresarContratistaInvitado({
    required String tokenInvitado,
    required String nombreCompleto,
    required String cedula,
  }) async {
    final exp = await obtenerExpedientePorTokenInvitado(tokenInvitado);
    if (exp == null) {
      throw ArgumentError(
        'El enlace del contrato no existe o no es válido. Solicita al equipo jurídico generar nuevamente tu link.',
      );
    }

    final cleanNombre = SecurityService.sanitizePlainText(
      nombreCompleto,
      maxLength: 140,
    );
    final cleanCedula = SecurityService.normalizeDocumentDigits(cedula);

    if (cleanNombre.length < 4 || !cleanNombre.contains(' ')) {
      throw ArgumentError(
        'Ingresa tu nombre y apellido completos para continuar.',
      );
    }
    if (cleanCedula.length < 5) {
      throw ArgumentError(
        'Ingresa un número de cédula válido (mínimo 5 dígitos).',
      );
    }

    final esperada = SecurityService.normalizeDocumentDigits(
      exp.contratistaCedulaEsperada,
    );
    if (esperada.isNotEmpty && esperada != cleanCedula) {
      throw ArgumentError(
        'La cédula ingresada no coincide con el aspirante registrado en el contrato ${exp.numeroContrato}.',
      );
    }

    final ahoraMs = DateTime.now().millisecondsSinceEpoch;
    final ahoraIso = DateTime.fromMillisecondsSinceEpoch(
      ahoraMs,
      isUtc: true,
    ).toIso8601String();

    final eventoIngreso = EventoTrazabilidadContrato(
      id: 'EVT-${SecurityService.generateSecureTokenHex(6)}',
      fechaIso: ahoraIso,
      tipo: 'INGRESO_INVITADO',
      actorNombre: cleanNombre,
      actorRol: 'Contratista (CC $cleanCedula)',
      titulo: 'Ingresó al enlace del contrato',
      detalle:
          'Acceso validado con cédula $cleanCedula en el contrato ${exp.numeroContrato}.',
    );

    final actualizado = exp.copyWith(
      contratistaNombreEsperado: exp.contratistaNombreEsperado.isEmpty
          ? cleanNombre
          : exp.contratistaNombreEsperado,
      contratistaCedulaEsperada: esperada.isEmpty ? cleanCedula : esperada,
      ultimoContratistaValidadoNombre: cleanNombre,
      ultimoContratistaValidadoCedula: cleanCedula,
      actualizadoEnMs: ahoraMs,
      trazabilidad: <EventoTrazabilidadContrato>[
        eventoIngreso,
        ...exp.trazabilidad,
      ],
    );

    await _guardarExpedienteInmediato(actualizado);
    return actualizado;
  }

  /// Carga o reemplaza (subsanación) un documento por parte del contratista invitado,
  /// notificando en tiempo real al Equipo Jurídico y actualizando la trazabilidad de ambos.
  static Future<ExpedienteContratoPs> subirDocumentoContratistaInvitado({
    required String tokenInvitado,
    required String apartadoId,
    required PickedContractDocumentFile archivo,
    required String contratistaNombre,
    required String contratistaCedula,
    String notaContratista = '',
  }) async {
    if (!archivo.isValid) {
      throw ArgumentError(
        archivo.errorMessage ?? 'El archivo seleccionado no es válido.',
      );
    }

    final exp = await obtenerExpedientePorTokenInvitado(tokenInvitado);
    if (exp == null) {
      throw StateError('No se encontró el expediente contractual.');
    }

    final idx = exp.apartados.indexWhere((a) => a.id == apartadoId);
    if (idx < 0) {
      throw StateError('No se encontró el documento requerido.');
    }

    final actual = exp.apartados[idx];
    if (actual.estaAprobado) {
      throw ArgumentError(
        'Este documento ya fue verificado por el equipo jurídico y no requiere cambios.',
      );
    }

    final bool esSubsanacion =
        actual.estado == EstadoDocumentoJuridico.devueltoSubsanar ||
        actual.estado == EstadoDocumentoJuridico.subsanadoEnRevision;
    final int nuevaVersion = actual.versionCarga + 1;
    final ahoraMs = DateTime.now().millisecondsSinceEpoch;
    final ahoraIso = DateTime.fromMillisecondsSinceEpoch(
      ahoraMs,
      isUtc: true,
    ).toIso8601String();
    final notaLimpia = SecurityService.sanitizePlainText(
      notaContratista,
      maxLength: 350,
    );

    final nuevoEstado = esSubsanacion
        ? EstadoDocumentoJuridico.subsanadoEnRevision
        : EstadoDocumentoJuridico.enRevision;

    final encodedFileB64 = base64Encode(archivo.bytes);

    final apartadoActualizado = actual.copyWith(
      estado: nuevoEstado,
      archivoNombre: archivo.fileName,
      archivoMime: archivo.mimeType,
      archivoTamanoBytes: archivo.sizeBytes,
      archivoSha256: archivo.sha256Hash,
      archivoBase64: encodedFileB64,
      versionCarga: nuevaVersion,
      notaContratista: notaLimpia,
      fechaCargaIso: ahoraIso,
      cargadoPorNombre: contratistaNombre.trim(),
      cargadoPorCedula: SecurityService.normalizeDocumentDigits(
        contratistaCedula,
      ),
    );

    final nuevosApartados = List<ApartadoDocumentoContrato>.from(exp.apartados);
    nuevosApartados[idx] = apartadoActualizado;

    final evento = EventoTrazabilidadContrato(
      id: 'EVT-${SecurityService.generateSecureTokenHex(6)}',
      fechaIso: ahoraIso,
      tipo: esSubsanacion ? 'SUBSANACION_ENVIADA' : 'CARGA_DOCUMENTO',
      actorNombre: contratistaNombre.trim(),
      actorRol: 'Contratista (CC $contratistaCedula)',
      apartadoNombre: actual.nombre,
      titulo: esSubsanacion
          ? 'Envió subsanación de ${actual.nombre}'
          : 'Cargó ${actual.nombre}',
      detalle:
          '${archivo.fileName} (${archivo.formattedSize})'
          '${notaLimpia.isNotEmpty ? " · Nota: $notaLimpia" : ""}',
    );

    final actualizado = exp.copyWith(
      apartados: nuevosApartados,
      actualizadoEnMs: ahoraMs,
      trazabilidad: <EventoTrazabilidadContrato>[evento, ...exp.trazabilidad],
    );

    await _guardarExpedienteInmediato(actualizado);
    unawaited(
      _subirBinarioIndividualFirestoreEnFondo(
        tokenInvitado: exp.tokenInvitado,
        apartado: apartadoActualizado,
      ),
    );
    return actualizado;
  }

  /// Actualiza el estado de las casillas de verificación jurídica en tiempo real.
  static Future<ExpedienteContratoPs> guardarEstadoChecklist({
    required String tokenInvitado,
    required List<bool> checks,
    String? conceptoJuridico,
  }) async {
    final exp = await obtenerExpedientePorTokenInvitado(tokenInvitado);
    if (exp == null) {
      throw StateError('No se encontró el expediente contractual.');
    }
    final normalizados = List<bool>.generate(
      5,
      (i) => i < checks.length ? checks[i] : false,
    );
    final actualizado = exp.copyWith(
      checksVerificacion: normalizados,
      actualizadoEnMs: DateTime.now().millisecondsSinceEpoch,
      conceptoJuridico: conceptoJuridico != null
          ? SecurityService.sanitizePlainText(conceptoJuridico, maxLength: 300)
          : exp.conceptoJuridico,
    );
    await _guardarExpedienteInmediato(actualizado);
    return actualizado;
  }

  /// Aprueba un documento individual cargado por el contratista en tiempo real.
  static Future<ExpedienteContratoPs> aprobarApartadoJuridico({
    required String tokenInvitado,
    required String apartadoId,
    String comentarioJuridico = '',
  }) async {
    final exp = await obtenerExpedientePorTokenInvitado(tokenInvitado);
    if (exp == null) {
      throw StateError('No se encontró el expediente contractual.');
    }

    final idx = exp.apartados.indexWhere((a) => a.id == apartadoId);
    if (idx < 0) {
      throw StateError('No se encontró el documento requerido.');
    }

    final actual = exp.apartados[idx];
    if (!actual.tieneArchivoCargado) {
      throw ArgumentError(
        'El contratista aún no ha cargado archivo en "${actual.nombre}".',
      );
    }

    final ahoraMs = DateTime.now().millisecondsSinceEpoch;
    final ahoraIso = DateTime.fromMillisecondsSinceEpoch(
      ahoraMs,
      isUtc: true,
    ).toIso8601String();
    final revisor = AuthService.getActiveUserDisplayName();
    final comentarioLimpio = SecurityService.sanitizePlainText(
      comentarioJuridico,
      maxLength: 350,
    );

    final apartadoAprobado = actual.copyWith(
      estado: EstadoDocumentoJuridico.aprobado,
      observacionJuridica: comentarioLimpio.isEmpty
          ? 'Documento verificado conforme a los requisitos contractuales.'
          : comentarioLimpio,
      fechaRevisionIso: ahoraIso,
      revisadoPor: revisor,
    );

    final nuevosApartados = List<ApartadoDocumentoContrato>.from(exp.apartados);
    nuevosApartados[idx] = apartadoAprobado;

    final todosListos = nuevosApartados
        .where((a) => a.obligatorio)
        .every((a) => a.estaAprobado);

    final evento = EventoTrazabilidadContrato(
      id: 'EVT-${SecurityService.generateSecureTokenHex(6)}',
      fechaIso: ahoraIso,
      tipo: 'APROBACION_DOCUMENTO',
      actorNombre: revisor,
      actorRol: 'Equipo jurídico',
      apartadoNombre: actual.nombre,
      titulo: 'Verificó ${actual.nombre}',
      detalle:
          'Archivo aprobado: ${actual.archivoNombre ?? "PDF"}.'
          '${comentarioLimpio.isNotEmpty ? " Concepto: $comentarioLimpio" : ""}',
    );

    final actualizado = exp.copyWith(
      apartados: nuevosApartados,
      actualizadoEnMs: ahoraMs,
      trazabilidad: <EventoTrazabilidadContrato>[evento, ...exp.trazabilidad],
      avalJuridicoEmitido: todosListos ? true : exp.avalJuridicoEmitido,
      fechaAvalIso: todosListos ? ahoraIso : exp.fechaAvalIso,
    );

    await _guardarExpedienteInmediato(actualizado);
    return actualizado;
  }

  /// Acción principal del botón "Revisado y verificado" en tiempo real.
  static Future<ExpedienteContratoPs> marcarRevisadoYVerificado({
    required String tokenInvitado,
    required List<bool> checks,
    String conceptoOpcional = '',
    Set<String> excluirIdsMarcadosDevolver = const <String>{},
  }) async {
    final exp = await obtenerExpedientePorTokenInvitado(tokenInvitado);
    if (exp == null) {
      throw StateError('No se encontró el expediente contractual.');
    }

    final cargados = exp.apartados
        .where(
          (a) =>
              a.tieneArchivoCargado &&
              !excluirIdsMarcadosDevolver.contains(a.id),
        )
        .toList();

    if (cargados.isEmpty) {
      throw ArgumentError(
        'No hay documentos cargados disponibles para verificar en este momento.',
      );
    }

    final ahoraMs = DateTime.now().millisecondsSinceEpoch;
    final ahoraIso = DateTime.fromMillisecondsSinceEpoch(
      ahoraMs,
      isUtc: true,
    ).toIso8601String();
    final revisor = AuthService.getActiveUserDisplayName();
    final conceptoLimpio = SecurityService.sanitizePlainText(
      conceptoOpcional,
      maxLength: 300,
    );
    final textoConcepto = conceptoLimpio.isEmpty ? 'Cumple' : conceptoLimpio;

    int verificadosAhora = 0;
    final nuevosApartados = exp.apartados.map((ap) {
      if (ap.tieneArchivoCargado &&
          !excluirIdsMarcadosDevolver.contains(ap.id)) {
        if (!ap.estaAprobado) verificadosAhora++;
        return ap.copyWith(
          estado: EstadoDocumentoJuridico.aprobado,
          observacionJuridica: 'Revisado y verificado ($textoConcepto).',
          fechaRevisionIso: ahoraIso,
          revisadoPor: revisor,
        );
      }
      return ap;
    }).toList();

    final obligatorios = nuevosApartados.where((a) => a.obligatorio).toList();
    final todosObligatoriosVerificados = obligatorios.isEmpty
        ? nuevosApartados.every((a) => a.estaAprobado)
        : obligatorios.every((a) => a.estaAprobado);

    final normalizados = List<bool>.generate(
      5,
      (i) => i < checks.length ? checks[i] : false,
    );
    final checksMarcados = normalizados.where((c) => c).length;

    final evento = EventoTrazabilidadContrato(
      id: 'EVT-${SecurityService.generateSecureTokenHex(6)}',
      fechaIso: ahoraIso,
      tipo: todosObligatoriosVerificados ? 'AVAL_FINAL' : 'APROBACION_DOCUMENTO',
      actorNombre: revisor,
      actorRol: 'Equipo jurídico',
      titulo: todosObligatoriosVerificados
          ? 'Marcó el expediente como revisado y verificado'
          : 'Verificó los documentos cargados del expediente',
      detalle:
          'Concepto: $textoConcepto · ${verificadosAhora > 0 ? "$verificadosAhora documento(s) verificado(s)" : "Documentos ratificados"} · Lista de chequeo: $checksMarcados/5 criterios.',
    );

    final actualizado = exp.copyWith(
      apartados: nuevosApartados,
      checksVerificacion: normalizados,
      conceptoJuridico: textoConcepto,
      avalJuridicoEmitido: todosObligatoriosVerificados,
      fechaAvalIso: todosObligatoriosVerificados ? ahoraIso : exp.fechaAvalIso,
      actualizadoEnMs: ahoraMs,
      trazabilidad: <EventoTrazabilidadContrato>[evento, ...exp.trazabilidad],
    );

    await _guardarExpedienteInmediato(actualizado);
    return actualizado;
  }

  /// Acción del botón "Devolver al contratista" en tiempo real.
  static Future<({
    ExpedienteContratoPs expediente,
    NotificacionCorreoSubsanacion notificacion,
  })> devolverDocumentosSeleccionados({
    required String tokenInvitado,
    required List<String> apartadosIds,
    required String observaciones,
    bool abrirClienteCorreo = false,
  }) async {
    final motivoLimpio = SecurityService.sanitizePlainText(
      observaciones,
      maxLength: 600,
    );
    if (apartadosIds.isEmpty) {
      throw ArgumentError(
        'Marca al menos una casilla "Devolver este documento" en la lista izquierda.',
      );
    }
    if (motivoLimpio.length < 4) {
      throw ArgumentError(
        'Escribe en "Observaciones para el contratista" qué debe corregir y cómo.',
      );
    }

    final exp = await obtenerExpedientePorTokenInvitado(tokenInvitado);
    if (exp == null) {
      throw StateError('No se encontró el expediente contractual.');
    }

    final idsSet = apartadosIds.toSet();
    final nombresDevueltos = <String>[];
    final ahoraMs = DateTime.now().millisecondsSinceEpoch;
    final ahoraIso = DateTime.fromMillisecondsSinceEpoch(
      ahoraMs,
      isUtc: true,
    ).toIso8601String();
    final revisor = AuthService.getActiveUserDisplayName();

    final nuevosApartados = exp.apartados.map((ap) {
      if (idsSet.contains(ap.id)) {
        nombresDevueltos.add(ap.nombre);
        return ap.copyWith(
          estado: EstadoDocumentoJuridico.devueltoSubsanar,
          observacionJuridica: motivoLimpio,
          fechaRevisionIso: ahoraIso,
          revisadoPor: revisor,
        );
      }
      return ap;
    }).toList();

    if (nombresDevueltos.isEmpty) {
      throw ArgumentError('No se encontraron los documentos seleccionados.');
    }

    final resumenNombres = nombresDevueltos.join(', ');
    final linkInvitado = construirLinkInvitadoWeb(exp.tokenInvitado);
    final nombreContratista = exp.contratistaNombreEsperado.isEmpty
        ? 'Contratista'
        : exp.contratistaNombreEsperado;

    final asuntoCorreo =
        'Solicitud de subsanación · Contrato ${exp.numeroContrato} · ${exp.entidadNombre}';
    final cuerpoCorreo =
        'Cordial saludo, $nombreContratista:\n\n'
        'El equipo jurídico de ${exp.entidadNombre} revisó los documentos del '
        'contrato ${exp.numeroContrato} y registró observaciones para subsanar:\n\n'
        '• Documentos por corregir: $resumenNombres\n'
        '• Observaciones: $motivoLimpio\n\n'
        'Ingresa con tu nombre y cédula en el siguiente enlace único de tu contrato para cargar los archivos corregidos:\n'
        '$linkInvitado\n\n'
        'Atentamente,\n'
        '$revisor · ${exp.entidadNombre}';

    final notificacion = NotificacionCorreoSubsanacion(
      id: 'MAIL-${SecurityService.generateSecureTokenHex(8)}',
      expedienteToken: exp.tokenInvitado,
      numeroContrato: exp.numeroContrato,
      destinatarioEmail: exp.contratistaCorreo,
      destinatarioNombre: nombreContratista,
      asunto: asuntoCorreo,
      cuerpoTexto: cuerpoCorreo,
      fechaEnvioIso: ahoraIso,
      apartadoNombre: resumenNombres,
      observacion: motivoLimpio,
      linkInvitado: linkInvitado,
    );

    final eventoDevolucion = EventoTrazabilidadContrato(
      id: 'EVT-${SecurityService.generateSecureTokenHex(6)}',
      fechaIso: ahoraIso,
      tipo: 'DEVOLUCION_SUBSANAR',
      actorNombre: revisor,
      actorRol: 'Equipo jurídico',
      apartadoNombre: resumenNombres,
      correoDestino: exp.contratistaCorreo,
      titulo: nombresDevueltos.length == 1
          ? 'Devolvió 1 documento al contratista'
          : 'Devolvió ${nombresDevueltos.length} documentos al contratista',
      detalle:
          'Documentos: $resumenNombres. Observación: $motivoLimpio (notificado a ${exp.contratistaCorreo}).',
    );

    final actualizado = exp.copyWith(
      apartados: nuevosApartados,
      avalJuridicoEmitido: false,
      actualizadoEnMs: ahoraMs,
      notificacionesCorreo: <NotificacionCorreoSubsanacion>[
        notificacion,
        ...exp.notificacionesCorreo,
      ],
      trazabilidad: <EventoTrazabilidadContrato>[
        eventoDevolucion,
        ...exp.trazabilidad,
      ],
    );

    await _guardarExpedienteInmediato(actualizado);
    unawaited(_registrarCorreoEnFirestoreEnFondo(notificacion));

    if (abrirClienteCorreo) {
      unawaited(abrirCorreoClienteExterno(notificacion));
    }

    return (expediente: actualizado, notificacion: notificacion);
  }

  /// Compatibilidad para devolución individual.
  static Future<({
    ExpedienteContratoPs expediente,
    NotificacionCorreoSubsanacion notificacion,
  })> devolverApartadoParaSubsanar({
    required String tokenInvitado,
    required String apartadoId,
    required String observacionSubsanacion,
    bool abrirClienteCorreoInstitucional = false,
  }) {
    return devolverDocumentosSeleccionados(
      tokenInvitado: tokenInvitado,
      apartadosIds: <String>[apartadoId],
      observaciones: observacionSubsanacion,
      abrirClienteCorreo: abrirClienteCorreoInstitucional,
    );
  }

  /// Envía un correo de requerimiento o recordatorio al contratista y deja trazabilidad.
  static Future<ExpedienteContratoPs> enviarCorreoRequerimiento({
    required String tokenInvitado,
    String observacionAdicional = '',
    bool abrirClienteCorreo = true,
  }) async {
    final exp = await obtenerExpedientePorTokenInvitado(tokenInvitado);
    if (exp == null) {
      throw StateError('No se encontró el expediente contractual.');
    }

    final pendientes = exp.apartados
        .where((a) => !a.tieneArchivoCargado || a.requiereSubsanacion)
        .map((a) => a.nombre)
        .toList();

    final ahoraMs = DateTime.now().millisecondsSinceEpoch;
    final ahoraIso = DateTime.fromMillisecondsSinceEpoch(
      ahoraMs,
      isUtc: true,
    ).toIso8601String();
    final revisor = AuthService.getActiveUserDisplayName();
    final link = construirLinkInvitadoWeb(exp.tokenInvitado);
    final extra = SecurityService.sanitizePlainText(
      observacionAdicional,
      maxLength: 500,
    );
    final detallePendientes = pendientes.isEmpty
        ? 'Revisión documental del contrato ${exp.numeroContrato}'
        : pendientes.join(', ');

    final notif = NotificacionCorreoSubsanacion(
      id: 'MAIL-${SecurityService.generateSecureTokenHex(8)}',
      expedienteToken: exp.tokenInvitado,
      numeroContrato: exp.numeroContrato,
      destinatarioEmail: exp.contratistaCorreo,
      destinatarioNombre: exp.contratistaNombreEsperado,
      asunto:
          'Requerimiento documental · Contrato ${exp.numeroContrato} · ${exp.entidadNombre}',
      cuerpoTexto:
          'Cordial saludo, ${exp.contratistaNombreEsperado}:\n\n'
          'Te recordamos completar o subsanar la documentación del contrato ${exp.numeroContrato} (${exp.entidadNombre}).\n'
          '• Pendientes: $detallePendientes\n'
          '${extra.isNotEmpty ? "• Nota del equipo jurídico: $extra\n" : ""}\n'
          'Enlace directo de tu contrato:\n$link\n\n'
          'Atentamente,\n$revisor',
      fechaEnvioIso: ahoraIso,
      apartadoNombre: detallePendientes,
      observacion: extra.isEmpty
          ? 'Requerimiento de cargue documental'
          : extra,
      linkInvitado: link,
    );

    final evento = EventoTrazabilidadContrato(
      id: 'EVT-${SecurityService.generateSecureTokenHex(6)}',
      fechaIso: ahoraIso,
      tipo: 'NOTIFICACION_CORREO',
      actorNombre: revisor,
      actorRol: 'Equipo jurídico',
      correoDestino: exp.contratistaCorreo,
      titulo: 'Envió correo de requerimiento al contratista',
      detalle:
          'Destinatario: ${exp.contratistaCorreo} · Pendientes: $detallePendientes.',
    );

    final actualizado = exp.copyWith(
      actualizadoEnMs: ahoraMs,
      notificacionesCorreo: <NotificacionCorreoSubsanacion>[
        notif,
        ...exp.notificacionesCorreo,
      ],
      trazabilidad: <EventoTrazabilidadContrato>[evento, ...exp.trazabilidad],
    );

    await _guardarExpedienteInmediato(actualizado);
    unawaited(_registrarCorreoEnFirestoreEnFondo(notif));
    if (abrirClienteCorreo) {
      unawaited(abrirCorreoClienteExterno(notif));
    }
    return actualizado;
  }

  static Future<void> abrirCorreoClienteExterno(
    NotificacionCorreoSubsanacion notif,
  ) async {
    final uri = Uri(
      scheme: 'mailto',
      path: notif.destinatarioEmail,
      queryParameters: <String, String>{
        'subject': notif.asunto,
        'body': notif.cuerpoTexto,
      },
    );
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  /// Obtiene los bytes reales del documento cargado (o un PDF válido de respaldo).
  static ({List<int> bytes, String fileName, String mimeType})?
  obtenerBinarioDocumento({
    required ExpedienteContratoPs expediente,
    required ApartadoDocumentoContrato apartado,
  }) {
    if (!apartado.tieneArchivoCargado) return null;

    List<int> bytes;
    String fileName = (apartado.archivoNombre ?? 'documento.pdf').trim();
    String mime = (apartado.archivoMime ?? 'application/pdf').trim();

    if (apartado.archivoBase64 != null &&
        apartado.archivoBase64!.trim().isNotEmpty) {
      try {
        bytes = base64Decode(apartado.archivoBase64!);
      } catch (_) {
        bytes = _generarPdfSoporteRespaldo(expediente, apartado);
        mime = 'application/pdf';
        if (!fileName.toLowerCase().endsWith('.pdf')) {
          fileName = '$fileName.pdf';
        }
      }
    } else {
      bytes = _generarPdfSoporteRespaldo(expediente, apartado);
      mime = 'application/pdf';
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = '$fileName.pdf';
      }
    }

    return (bytes: bytes, fileName: fileName, mimeType: mime);
  }

  /// Abre el documento en una pestaña nueva del navegador para lectura completa.
  static bool abrirDocumentoEnPestana({
    required ExpedienteContratoPs expediente,
    required ApartadoDocumentoContrato apartado,
  }) {
    final data = obtenerBinarioDocumento(
      expediente: expediente,
      apartado: apartado,
    );
    if (data == null) return false;
    return openBinaryInNewTab(bytes: data.bytes, mimeType: data.mimeType);
  }

  /// Descarga individualmente el archivo subido por el contratista.
  static bool descargarDocumentoIndividual({
    required ExpedienteContratoPs expediente,
    required ApartadoDocumentoContrato apartado,
  }) {
    final data = obtenerBinarioDocumento(
      expediente: expediente,
      apartado: apartado,
    );
    if (data == null) return false;
    return downloadBinaryBytes(
      bytes: data.bytes,
      fileName: data.fileName,
      mimeType: data.mimeType,
    );
  }

  /// Descarga el acta PDF consolidada de verificación jurídica y trazabilidad.
  static bool descargarActaVerificacionJuridicaPdf(
    ExpedienteContratoPs expediente,
  ) {
    final lineas = <String>[
      'CONTRATA LEGAL - ACTA DE VERIFICACION JURIDICA OPS',
      '====================================================================',
      'Entidad contratante : ${_ascii(expediente.entidadNombre)} (NIT ${_ascii(expediente.entidadNit)})',
      'Dependencia         : ${_ascii(expediente.dependencia)}',
      'Numero de contrato  : ${_ascii(expediente.numeroContrato)}',
      'Plazo / Valor       : ${_ascii(expediente.plazoEjecucion)} | COP ${expediente.valorContratoCop}',
      'Contratista         : ${_ascii(expediente.contratistaNombreEsperado)} (CC ${expediente.contratistaCedulaEsperada})',
      'Correo electronico  : ${_ascii(expediente.contratistaCorreo)}',
      'Estado actual       : ${_ascii(expediente.estadoGlobalEtiqueta)}',
      'Concepto juridico   : ${_ascii(expediente.conceptoJuridico.isEmpty ? "Sin concepto adicional" : expediente.conceptoJuridico)}',
      'Fecha de emision    : ${formatearFechaHumana(DateTime.now().toUtc().toIso8601String())}',
      '--------------------------------------------------------------------',
      'OBJETO DEL CONTRATO:',
      ..._partirLineas(_ascii(expediente.objetoContrato), 78),
      '--------------------------------------------------------------------',
      'DOCUMENTOS REQUERIDOS:',
    ];

    for (final ap in expediente.apartados) {
      lineas.add(
        '[${_ascii(ap.estado.etiquetaCorta)}] ${_ascii(ap.nombre)} (v${ap.versionCarga})',
      );
      if (ap.archivoNombre != null) {
        lineas.add('   Archivo: ${_ascii(ap.archivoNombre!)}');
      }
      if (ap.observacionJuridica != null &&
          ap.observacionJuridica!.trim().isNotEmpty) {
        lineas.add('   Observacion: ${_ascii(ap.observacionJuridica!)}');
      }
    }

    lineas.add(
      '--------------------------------------------------------------------',
    );
    lineas.add('TRAZABILIDAD RECIENTE:');
    for (final ev in expediente.trazabilidad.take(10)) {
      lineas.add(
        '* ${_ascii(formatearFechaHumana(ev.fechaIso))} | ${_ascii(ev.actorNombre)} - ${_ascii(ev.titulo)}',
      );
    }

    final pdfBytes = _construirPdf14Simple(lineas);
    final cleanNum = expediente.numeroContrato.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    return downloadBinaryBytes(
      bytes: pdfBytes,
      fileName: 'Acta_Verificacion_$cleanNum.pdf',
      mimeType: 'application/pdf',
    );
  }

  // ===========================================================================
  // MOTOR DE PERSISTENCIA COMPARTIDA + BROADCAST EN TIEMPO REAL + FIRESTORE
  // ===========================================================================

  static List<ExpedienteContratoPs> _decodificarListaJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (m) => ExpedienteContratoPs.fromMap(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList();
      }
    } catch (_) {}
    return const <ExpedienteContratoPs>[];
  }

  static List<ExpedienteContratoPs> _decodificarPosibleDobleJson(String raw) {
    try {
      final first = jsonDecode(raw);
      if (first is String) {
        return _decodificarListaJson(first);
      }
      if (first is List) {
        return first
            .whereType<Map>()
            .map(
              (m) => ExpedienteContratoPs.fromMap(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList();
      }
    } catch (_) {}
    return const <ExpedienteContratoPs>[];
  }

  static Future<List<ExpedienteContratoPs>> _obtenerCacheLocalInmediata() async {
    if (_cacheMemoria != null) {
      return _cacheMemoria!;
    }

    final mapaUnificado = <String, ExpedienteContratoPs>{};

    void absorberLista(List<ExpedienteContratoPs> origen) {
      for (final item in origen) {
        final key = item.tokenInvitado.toLowerCase();
        if (key.isEmpty || _tokensDemostracionRetirados.contains(key)) continue;
        final previo = mapaUnificado[key];
        if (previo == null) {
          mapaUnificado[key] = item;
        } else if (_esMasReciente(entrante: item, actual: previo)) {
          mapaUnificado[key] = _fusionarLocalYRemoto(
            local: previo,
            remoto: item,
          );
        }
      }
    }

    final rawWeb = readSharedStorage(_sharedWebKey);
    if (rawWeb != null && rawWeb.trim().isNotEmpty) {
      absorberLista(_decodificarListaJson(rawWeb));
    }

    final rawFlutterLocal = readSharedStorage('flutter.$_prefsKey');
    if (rawFlutterLocal != null && rawFlutterLocal.trim().isNotEmpty) {
      absorberLista(_decodificarPosibleDobleJson(rawFlutterLocal));
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawPrefs = prefs.getString(_prefsKey);
      if (rawPrefs != null && rawPrefs.trim().isNotEmpty) {
        absorberLista(_decodificarListaJson(rawPrefs));
      }

      if (mapaUnificado.isEmpty) {
        final legacyRaw = prefs.getString(_legacyPrefsKey);
        if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
          for (final item in _decodificarListaJson(legacyRaw)) {
            if (!item.id.startsWith('EXP-PS-2026-0418') &&
                !item.id.startsWith('EXP-PS-2026-0502') &&
                item.tokenInvitado.isNotEmpty) {
              mapaUnificado[item.tokenInvitado.toLowerCase()] = item;
            }
          }
        }
      }
    } catch (_) {}

    if (mapaUnificado.isNotEmpty) {
      _cacheMemoria = mapaUnificado.values.toList()
        ..sort((a, b) => b.fechaCreacionIso.compareTo(a.fechaCreacionIso));
      unawaited(_persistirEnAlmacenamientoLocal(_cacheMemoria!));
      return _cacheMemoria!;
    }

    _cacheMemoria = <ExpedienteContratoPs>[];
    return _cacheMemoria!;
  }

  static Future<void> _guardarExpedienteInmediato(
    ExpedienteContratoPs expediente, {
    bool sincronizarRemoto = true,
    bool emitirBroadcast = true,
  }) async {
    final lista = await _obtenerCacheLocalInmediata();
    final idx = lista.indexWhere(
      (e) =>
          e.tokenInvitado.toLowerCase() ==
          expediente.tokenInvitado.toLowerCase(),
    );
    if (idx >= 0) {
      lista[idx] = expediente;
    } else {
      lista.insert(0, expediente);
    }
    _cacheMemoria = lista;

    // 1. Escribir inmediatamente en almacenamiento compartido de navegador y SharedPreferences
    await _persistirEnAlmacenamientoLocal(lista);

    // 2. Emitir actualización instantánea (< 2 ms) a todas las pestañas abiertas
    if (emitirBroadcast) {
      final payloadCompleto = jsonEncode(
        expediente.toMap(omitLargeBinary: false),
      );
      broadcastRealtimePayload(_broadcastChannelName, payloadCompleto);
    }

    // 3. Notificar a la UI de esta pestaña
    expedientesVersion.value++;

    // 4. Sincronizar en tiempo real con Firestore para otros dispositivos
    if (sincronizarRemoto) {
      _asegurarSuscripcionDocumentoFirestore(expediente.tokenInvitado);
      unawaited(_enviarExpedienteAFirestoreEnFondo(expediente));
    }
  }

  static Future<void> _persistirEnAlmacenamientoLocal(
    List<ExpedienteContratoPs> expedientes,
  ) async {
    try {
      final encoded = jsonEncode(expedientes.map((e) => e.toMap()).toList());
      writeSharedStorage(_sharedWebKey, encoded);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {}
  }

  static Future<void> _enviarExpedienteAFirestoreEnFondo(
    ExpedienteContratoPs expediente,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('expedientes_juridicos')
          .doc(expediente.tokenInvitado.toLowerCase())
          .set(expediente.toMap(omitLargeBinary: true))
          .timeout(const Duration(milliseconds: 2500));
    } catch (_) {}
  }

  static Future<void> _subirBinarioIndividualFirestoreEnFondo({
    required String tokenInvitado,
    required ApartadoDocumentoContrato apartado,
  }) async {
    final rawB64 = apartado.archivoBase64 ?? '';
    if (rawB64.isEmpty || rawB64.length > 940000) return;

    try {
      await FirebaseFirestore.instance
          .collection('expedientes_juridicos')
          .doc(tokenInvitado.toLowerCase())
          .collection('archivos')
          .doc(apartado.id)
          .set(<String, dynamic>{
            'apartadoId': apartado.id,
            'archivoNombre': apartado.archivoNombre,
            'archivoMime': apartado.archivoMime,
            'archivoSha256': apartado.archivoSha256,
            'archivoBase64': rawB64,
            'versionCarga': apartado.versionCarga,
            'fechaCargaIso': apartado.fechaCargaIso,
          })
          .timeout(const Duration(milliseconds: 3500));
    } catch (_) {}
  }

  static Future<void> _registrarCorreoEnFirestoreEnFondo(
    NotificacionCorreoSubsanacion notificacion,
  ) async {
    try {
      final map = Map<String, dynamic>.from(notificacion.toMap());
      map['remitenteUid'] = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance
          .collection('notificaciones_correo')
          .doc(notificacion.id)
          .set(map)
          .timeout(const Duration(milliseconds: 2000));
    } catch (_) {}
  }

  static ExpedienteContratoPs _fusionarLocalYRemoto({
    required ExpedienteContratoPs local,
    required ExpedienteContratoPs remoto,
  }) {
    final usarRemotoComoBase = _esMasReciente(entrante: remoto, actual: local);
    final base = usarRemotoComoBase ? remoto : local;
    final respaldo = identical(base, remoto) ? local : remoto;

    final mapaRespaldo = <String, ApartadoDocumentoContrato>{
      for (final a in respaldo.apartados) a.id: a,
    };

    final apartadosFusionados = base.apartados.map((ap) {
      if ((ap.archivoBase64 == null || ap.archivoBase64!.isEmpty) &&
          mapaRespaldo[ap.id]?.archivoBase64 != null &&
          mapaRespaldo[ap.id]!.archivoBase64!.isNotEmpty &&
          mapaRespaldo[ap.id]?.archivoSha256 == ap.archivoSha256) {
        return ap.copyWith(archivoBase64: mapaRespaldo[ap.id]!.archivoBase64);
      }
      return ap;
    }).toList();

    return base.copyWith(apartados: apartadosFusionados);
  }

  static List<int> _generarPdfSoporteRespaldo(
    ExpedienteContratoPs expediente,
    ApartadoDocumentoContrato apartado,
  ) {
    return _construirPdf14Simple(<String>[
      'CONTRATA LEGAL - SOPORTE DOCUMENTAL REGISTRADO',
      '====================================================================',
      'Contrato            : ${_ascii(expediente.numeroContrato)}',
      'Entidad             : ${_ascii(expediente.entidadNombre)}',
      'Documento           : ${_ascii(apartado.nombre)}',
      'Archivo             : ${_ascii(apartado.archivoNombre ?? "documento.pdf")}',
      'Version             : v${apartado.versionCarga}',
      'SHA-256             : ${apartado.archivoSha256 ?? "Verificado"}',
      'Cargado por         : ${_ascii(apartado.cargadoPorNombre ?? expediente.contratistaNombreEsperado)}',
      'Estado              : ${_ascii(apartado.estado.etiqueta)}',
    ]);
  }

  static String _ascii(String input) {
    const replacements = <String, String>{
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'ñ': 'n',
      'Ñ': 'N',
      'ü': 'u',
      'Ü': 'U',
      '·': '-',
      '•': '*',
      '“': '"',
      '”': '"',
    };
    var out = input;
    replacements.forEach((k, v) => out = out.replaceAll(k, v));
    return out.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ');
  }

  static List<String> _partirLineas(String texto, int maxCols) {
    final words = texto.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (final w in words) {
      if (w.isEmpty) continue;
      if (current.isEmpty) {
        current = w;
      } else if (current.length + 1 + w.length <= maxCols) {
        current = '$current $w';
      } else {
        lines.add(current);
        current = w;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  static List<int> _construirPdf14Simple(List<String> lines) {
    final escapedLines = lines
        .take(52)
        .map(
          (l) => l
              .replaceAll(r'\', r'\\')
              .replaceAll('(', r'\(')
              .replaceAll(')', r'\)'),
        )
        .toList();

    final contentBuf = StringBuffer()
      ..writeln('BT')
      ..writeln('/F1 9.5 Tf')
      ..writeln('42 752 Td')
      ..writeln('13.2 TL');

    for (var i = 0; i < escapedLines.length; i++) {
      if (i == 0) {
        contentBuf.writeln('(${escapedLines[i]}) Tj');
      } else {
        contentBuf.writeln("T* (${escapedLines[i]}) Tj");
      }
    }
    contentBuf.writeln('ET');
    final streamText = contentBuf.toString();

    final objects = <String>[
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n',
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
      '5 0 obj\n<< /Length ${streamText.length} >>\nstream\n$streamText\nendstream\nendobj\n',
    ];

    final pdf = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (final obj in objects) {
      offsets.add(pdf.length);
      pdf.write(obj);
    }
    final xrefStart = pdf.length;
    pdf.writeln('xref');
    pdf.writeln('0 ${objects.length + 1}');
    pdf.writeln('0000000000 65535 f ');
    for (var i = 1; i < offsets.length; i++) {
      pdf.writeln('${offsets[i].toString().padLeft(10, '0')} 00000 n ');
    }
    pdf.writeln('trailer');
    pdf.writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>');
    pdf.writeln('startxref');
    pdf.writeln('$xrefStart');
    pdf.write('%%EOF');

    return ascii.encode(pdf.toString());
  }
}
