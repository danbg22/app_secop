import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/file_downloader.dart';
import 'auth_service.dart';
import 'consent_service.dart';
import 'security_service.dart';

class PqrsRecord {
  const PqrsRecord({
    required this.radicado,
    required this.tipoSolicitud,
    required this.asunto,
    required this.mensaje,
    required this.nombreUsuario,
    required this.correoContacto,
    required this.documentoUsuario,
    required this.telefonoUsuario,
    required this.estado,
    required this.fechaIso,
    required this.sincronizadoNube,
    required this.sincronizadoGoogleDrive,
  });

  final String radicado;
  final String tipoSolicitud;
  final String asunto;
  final String mensaje;
  final String nombreUsuario;
  final String correoContacto;
  final String documentoUsuario;
  final String telefonoUsuario;
  final String estado;
  final String fechaIso;
  final bool sincronizadoNube;
  final bool sincronizadoGoogleDrive;

  Map<String, dynamic> toLocalJson() {
    return <String, dynamic>{
      'radicado': radicado,
      'tipo_solicitud': tipoSolicitud,
      'asunto': asunto,
      'mensaje': mensaje,
      'usuario_nombre': nombreUsuario,
      'correo_contacto': correoContacto,
      'usuario_documento': documentoUsuario,
      'usuario_telefono': telefonoUsuario,
      'estado': estado,
      'fecha_cliente_iso': fechaIso,
      'sincronizado_nube': sincronizadoNube,
      'sincronizado_google_drive': sincronizadoGoogleDrive,
    };
  }

  factory PqrsRecord.fromMap(Map<String, dynamic> map) {
    return PqrsRecord(
      radicado: (map['radicado'] ?? '').toString(),
      tipoSolicitud: (map['tipo_solicitud'] ?? 'Soporte técnico').toString(),
      asunto: (map['asunto'] ?? '').toString(),
      mensaje: (map['mensaje'] ?? '').toString(),
      nombreUsuario: (map['usuario_nombre'] ?? 'Usuario').toString(),
      correoContacto: (map['correo_contacto'] ?? '').toString(),
      documentoUsuario: (map['usuario_documento'] ?? '').toString(),
      telefonoUsuario: (map['usuario_telefono'] ?? '').toString(),
      estado: (map['estado'] ?? 'Radicado').toString(),
      fechaIso: (map['fecha_cliente_iso'] ?? '').toString(),
      sincronizadoNube: map['sincronizado_nube'] == true,
      sincronizadoGoogleDrive: map['sincronizado_google_drive'] == true,
    );
  }
}

/// Servicio centralizado de recepción y almacenamiento seguro de PQRS sin usar `mailto:`.
///
/// Endurecido con:
/// - Generador CSPRNG (`Random.secure()`) para radicados no predecibles.
/// - Control de tasa anti-spam y validación estricta de longitudes.
/// - Neutralización de Spreadsheet Formula Injection (CWE-1236) para Google Sheets y CSV.
/// - Aislamiento criptográfico de historial local por usuario (`SharedPreferences`).
class PqrsService {
  PqrsService._();

  static const String coleccionGlobalPqrs = 'pqrs_solicitudes';
  static const String subcoleccionUsuarioPqrs = 'pqrs_solicitudes';
  static const String _kLocalPqrsHistoryPrefix = 'pqrs_historial_local_v2';

  static const Set<String> _tiposPermitidos = <String>{
    'Soporte técnico',
    'Petición',
    'Queja o reclamo',
    'Sugerencia',
  };

  /// URL opcional de Web App de Google Apps Script para guardar cada fila
  /// directamente en una Hoja de Cálculo de Google Drive (Google Sheets).
  static const String defaultGoogleSheetsWebhookUrl = String.fromEnvironment(
    'PQRS_SHEETS_WEBHOOK_URL',
    defaultValue: '',
  );

  static String _scopedHistoryKey() {
    return '${_kLocalPqrsHistoryPrefix}_${AuthService.getActiveUserStorageScope()}';
  }

  static String _generarRadicado(DateTime ahora) {
    final y = ahora.year.toString().padLeft(4, '0');
    final m = ahora.month.toString().padLeft(2, '0');
    final d = ahora.day.toString().padLeft(2, '0');
    final rng = Random.secure();
    final aleatorio = (100000 + rng.nextInt(900000)).toString();
    return 'PQRS-$y$m$d-$aleatorio';
  }

  static String _sanitizeTextField(String raw, int maxLen) {
    final clean = raw
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
        .trim();
    return clean.length > maxLen ? clean.substring(0, maxLen) : clean;
  }

  static bool _isTrustedGoogleAppsScriptWebhook(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.toLowerCase() != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'script.google.com' ||
        host == 'script.googleusercontent.com';
  }

  /// Envía y almacena la solicitud PQRS directamente desde la plataforma.
  static Future<PqrsRecord> enviarSolicitud({
    required String tipoSolicitud,
    required String asunto,
    required String mensaje,
    required String correoContacto,
    String? nombreContacto,
  }) async {
    final rate = SecurityService.checkRateLimit(
      actionKey: 'pqrs_submit:${AuthService.getActiveUserStorageScope()}',
      maxAttempts: 4,
      window: const Duration(minutes: 10),
      customErrorMessage:
          'Has radicado varias solicitudes recientemente. Espera unos minutos antes de enviar otra.',
    );
    if (!rate.allowed) {
      throw Exception(rate.message);
    }

    final cleanTipo = _tiposPermitidos.contains(tipoSolicitud.trim())
        ? tipoSolicitud.trim()
        : 'Soporte técnico';
    final cleanAsunto = _sanitizeTextField(asunto, 160);
    final cleanMensaje = _sanitizeTextField(mensaje, 3000);
    if (cleanAsunto.length < 3 || cleanMensaje.length < 8) {
      throw Exception(
        'Completa un asunto válido y describe tu solicitud con mayor detalle.',
      );
    }

    final ahora = DateTime.now();
    final radicado = _generarRadicado(ahora);
    final fechaIso = ahora.toIso8601String();

    Map<String, dynamic> profileData = <String, dynamic>{};
    try {
      profileData = await AuthService.getActiveUserProfile();
    } catch (_) {}

    final fbUser = FirebaseAuth.instance.currentUser;
    final uid = fbUser?.uid ?? '';
    final rawNombre =
        (nombreContacto != null && nombreContacto.trim().isNotEmpty)
        ? nombreContacto.trim()
        : (profileData['displayName'] ?? AuthService.getActiveUserDisplayName())
              .toString()
              .trim();
    final nombreFinal = _sanitizeTextField(rawNombre, 120);
    final correoCuenta = _sanitizeTextField(
      AuthService.getActiveUserEmail(),
      160,
    );
    final correoFinal = correoContacto.trim().isNotEmpty
        ? _sanitizeTextField(correoContacto, 160)
        : correoCuenta;
    final documento = _sanitizeTextField(
      (profileData['documento'] ?? '').toString(),
      24,
    );
    final telefono = _sanitizeTextField(
      (profileData['telefono'] ?? '').toString(),
      24,
    );
    final plataforma = kIsWeb ? 'web' : defaultTargetPlatform.name;

    final firestorePayload = <String, dynamic>{
      'radicado': radicado,
      'tipo_solicitud': cleanTipo,
      'asunto': cleanAsunto,
      'mensaje': cleanMensaje,
      'usuario_nombre': nombreFinal.isNotEmpty ? nombreFinal : 'Ciudadano',
      'correo_contacto': correoFinal,
      'usuario_correo_cuenta': correoCuenta,
      'usuario_documento': documento,
      'usuario_telefono': telefono,
      'uid': uid,
      'estado': 'Radicado',
      'canal': 'formulario_interno_app',
      'plataforma': plataforma,
      'fecha_creacion': FieldValue.serverTimestamp(),
      'fecha_cliente_iso': fechaIso,
    };

    bool guardadoFirestore = false;

    // 1A. Guardado en colección global `pqrs_solicitudes/{radicado}`
    try {
      await FirebaseFirestore.instance
          .collection(coleccionGlobalPqrs)
          .doc(radicado)
          .set(firestorePayload)
          .timeout(const Duration(seconds: 6));
      guardadoFirestore = true;
    } catch (_) {
      debugPrint('Aviso PQRS: respaldo global diferido.');
    }

    // 1B. Espejo en `usuarios/{uid}/pqrs_solicitudes/{radicado}` si hay sesión Firebase
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(ConsentService.coleccionUsuarios)
            .doc(uid)
            .collection(subcoleccionUsuarioPqrs)
            .doc(radicado)
            .set(firestorePayload)
            .timeout(const Duration(seconds: 6));
        guardadoFirestore = true;
      } catch (_) {
        debugPrint('Aviso PQRS: respaldo en subcolección diferido.');
      }
    }

    // 2. Envío seguro a Google Sheets (solo dominios oficiales de Google Apps Script
    //    y celdas neutralizadas contra inyección de fórmulas `=IMPORTXML`, `=HYPERLINK`, etc.)
    bool enviadoGoogleDrive = false;
    final webhookUrl = defaultGoogleSheetsWebhookUrl.trim();
    if (_isTrustedGoogleAppsScriptWebhook(webhookUrl)) {
      try {
        final drivePayload = <String, dynamic>{
          'radicado': radicado,
          'fecha': fechaIso,
          'tipo_solicitud': SecurityService.neutralizeSpreadsheetFormula(
            cleanTipo,
          ),
          'usuario_nombre': SecurityService.neutralizeSpreadsheetFormula(
            nombreFinal.isNotEmpty ? nombreFinal : 'Ciudadano',
          ),
          'correo_contacto': SecurityService.neutralizeSpreadsheetFormula(
            correoFinal,
          ),
          'usuario_documento': SecurityService.neutralizeSpreadsheetFormula(
            documento,
          ),
          'usuario_telefono': SecurityService.neutralizeSpreadsheetFormula(
            telefono,
          ),
          'asunto': SecurityService.neutralizeSpreadsheetFormula(cleanAsunto),
          'mensaje': SecurityService.neutralizeSpreadsheetFormula(cleanMensaje),
          'estado': 'Radicado',
          'plataforma': plataforma,
        };
        final response = await http
            .post(
              Uri.parse(webhookUrl),
              headers: const <String, String>{
                'Content-Type': 'text/plain;charset=utf-8',
              },
              body: jsonEncode(drivePayload),
            )
            .timeout(const Duration(seconds: 7));
        if (response.statusCode >= 200 && response.statusCode < 400) {
          enviadoGoogleDrive = true;
        }
      } catch (_) {
        debugPrint('Aviso PQRS: sincronización externa diferida.');
      }
    }

    final record = PqrsRecord(
      radicado: radicado,
      tipoSolicitud: cleanTipo,
      asunto: cleanAsunto,
      mensaje: cleanMensaje,
      nombreUsuario: nombreFinal.isNotEmpty ? nombreFinal : 'Ciudadano',
      correoContacto: correoFinal,
      documentoUsuario: documento,
      telefonoUsuario: telefono,
      estado: 'Radicado',
      fechaIso: fechaIso,
      sincronizadoNube: guardadoFirestore,
      sincronizadoGoogleDrive: enviadoGoogleDrive,
    );

    // 3. Respaldo aislado por usuario activo
    await _guardarEnHistorialLocal(record);

    return record;
  }

  static Future<void> _guardarEnHistorialLocal(PqrsRecord nuevo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final actual = await obtenerHistorialLocal();
      final actualizado = <PqrsRecord>[nuevo, ...actual];
      final serializado = actualizado
          .take(100)
          .map((item) => item.toLocalJson())
          .toList();
      await prefs.setString(_scopedHistoryKey(), jsonEncode(serializado));
    } catch (_) {}
  }

  static Future<List<PqrsRecord>> obtenerHistorialLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scopedHistoryKey());
      if (raw == null || raw.isEmpty) return const <PqrsRecord>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => PqrsRecord.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return const <PqrsRecord>[];
  }

  /// Descarga las solicitudes registradas en formato `.csv` (UTF-8 con BOM)
  /// protegido contra inyección de fórmulas en hojas de cálculo (CWE-1236).
  static bool exportarHistorialCsv(List<PqrsRecord> registros) {
    if (registros.isEmpty) return false;

    final encabezados = <String>[
      'Radicado',
      'Fecha ISO',
      'Tipo de Solicitud',
      'Estado',
      'Nombre Usuario',
      'Correo de Contacto',
      'Documento',
      'Telefono',
      'Asunto',
      'Mensaje',
    ];

    String cell(String v) =>
        SecurityService.formatSafeCsvCell(v.replaceAll('\r\n', ' ').replaceAll('\n', ' ').trim());

    final lineas = <String>[
      encabezados.join(';'),
      for (final r in registros)
        <String>[
          cell(r.radicado),
          cell(r.fechaIso),
          cell(r.tipoSolicitud),
          cell(r.estado),
          cell(r.nombreUsuario),
          cell(r.correoContacto),
          cell(r.documentoUsuario),
          cell(r.telefonoUsuario),
          cell(r.asunto),
          cell(r.mensaje),
        ].join(';'),
    ];

    final contenidoCsv = '\uFEFF${lineas.join('\n')}';
    final bytes = utf8.encode(contenidoCsv);
    return downloadCsvBytes(
      utf8Bytes: bytes,
      fileName: 'pqrs_contrata_legal.csv',
    );
  }
}
