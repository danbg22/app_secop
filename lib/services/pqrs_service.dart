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

/// Servicio centralizado de recepción y almacenamiento de PQRS sin usar `mailto:`.
///
/// 1. Guarda cada formulario directamente en **Cloud Firestore** (`pqrs_solicitudes/{radicado}`
///    y `usuarios/{uid}/pqrs_solicitudes/{radicado}`).
/// 2. Si se configura [defaultGoogleSheetsWebhookUrl] (Google Apps Script sobre un
///    archivo de **Google Sheets en Google Drive**), inserta automáticamente cada
///    solicitud como una nueva fila en la hoja de cálculo de Google Drive.
/// 3. Conserva respaldo local e incluye exportación a `.csv` compatible con
///    Google Sheets / Google Drive y Microsoft Excel.
class PqrsService {
  PqrsService._();

  static const String coleccionGlobalPqrs = 'pqrs_solicitudes';
  static const String subcoleccionUsuarioPqrs = 'pqrs_solicitudes';
  static const String _kLocalPqrsHistoryKey = 'pqrs_historial_local_v1';

  /// URL opcional de Web App de Google Apps Script para guardar cada fila
  /// directamente en una Hoja de Cálculo de Google Drive (Google Sheets).
  /// Puedes definirla aquí o pasarla con `--dart-define=PQRS_SHEETS_WEBHOOK_URL=...`.
  static const String defaultGoogleSheetsWebhookUrl = String.fromEnvironment(
    'PQRS_SHEETS_WEBHOOK_URL',
    defaultValue: '',
  );

  static String _generarRadicado(DateTime ahora) {
    final y = ahora.year.toString().padLeft(4, '0');
    final m = ahora.month.toString().padLeft(2, '0');
    final d = ahora.day.toString().padLeft(2, '0');
    final aleatorio = (1000 + Random().nextInt(9000)).toString();
    return 'PQRS-$y$m$d-$aleatorio';
  }

  /// Envía y almacena la solicitud PQRS directamente desde la plataforma.
  static Future<PqrsRecord> enviarSolicitud({
    required String tipoSolicitud,
    required String asunto,
    required String mensaje,
    required String correoContacto,
    String? nombreContacto,
  }) async {
    final ahora = DateTime.now();
    final radicado = _generarRadicado(ahora);
    final fechaIso = ahora.toIso8601String();

    Map<String, dynamic> profileData = <String, dynamic>{};
    try {
      profileData = await AuthService.getActiveUserProfile();
    } catch (_) {}

    final fbUser = FirebaseAuth.instance.currentUser;
    final uid = fbUser?.uid ?? '';
    final nombreFinal = (nombreContacto != null && nombreContacto.trim().isNotEmpty)
        ? nombreContacto.trim()
        : (profileData['displayName'] ?? AuthService.getActiveUserDisplayName())
              .toString()
              .trim();
    final correoCuenta = AuthService.getActiveUserEmail().trim();
    final correoFinal = correoContacto.trim().isNotEmpty
        ? correoContacto.trim()
        : correoCuenta;
    final documento = (profileData['documento'] ?? '').toString().trim();
    final telefono = (profileData['telefono'] ?? '').toString().trim();
    final plataforma = kIsWeb ? 'web' : defaultTargetPlatform.name;

    final firestorePayload = <String, dynamic>{
      'radicado': radicado,
      'tipo_solicitud': tipoSolicitud.trim(),
      'asunto': asunto.trim(),
      'mensaje': mensaje.trim(),
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
    } catch (e) {
      debugPrint('Aviso PQRS colección global: $e');
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
      } catch (e) {
        debugPrint('Aviso PQRS subcolección usuario: $e');
      }
    }

    // 2. Envío directo a Google Sheets en Google Drive (si el Webhook está configurado)
    bool enviadoGoogleDrive = false;
    final webhookUrl = defaultGoogleSheetsWebhookUrl.trim();
    if (webhookUrl.startsWith('https://')) {
      try {
        final drivePayload = <String, dynamic>{
          'radicado': radicado,
          'fecha': fechaIso,
          'tipo_solicitud': tipoSolicitud.trim(),
          'usuario_nombre': nombreFinal.isNotEmpty ? nombreFinal : 'Ciudadano',
          'correo_contacto': correoFinal,
          'usuario_documento': documento,
          'usuario_telefono': telefono,
          'asunto': asunto.trim(),
          'mensaje': mensaje.trim(),
          'estado': 'Radicado',
          'plataforma': plataforma,
        };
        // `text/plain;charset=utf-8` evita bloqueos CORS preflight en Google Apps Script desde Flutter Web.
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
      } catch (e) {
        debugPrint('Aviso envío Google Sheets Webhook: $e');
      }
    }

    final record = PqrsRecord(
      radicado: radicado,
      tipoSolicitud: tipoSolicitud.trim(),
      asunto: asunto.trim(),
      mensaje: mensaje.trim(),
      nombreUsuario: nombreFinal.isNotEmpty ? nombreFinal : 'Ciudadano',
      correoContacto: correoFinal,
      documentoUsuario: documento,
      telefonoUsuario: telefono,
      estado: 'Radicado',
      fechaIso: fechaIso,
      sincronizadoNube: guardadoFirestore,
      sincronizadoGoogleDrive: enviadoGoogleDrive,
    );

    // 3. Respaldo inmediato en almacenamiento local para historial y exportación CSV
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
      await prefs.setString(_kLocalPqrsHistoryKey, jsonEncode(serializado));
    } catch (_) {}
  }

  static Future<List<PqrsRecord>> obtenerHistorialLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLocalPqrsHistoryKey);
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

  static String _escaparCeldaCsv(String valor) {
    final limpio = valor.replaceAll('\r\n', ' ').replaceAll('\n', ' ').trim();
    if (limpio.contains(';') || limpio.contains('"')) {
      return '"${limpio.replaceAll('"', '""')}"';
    }
    return limpio;
  }

  /// Descarga las solicitudes registradas en formato `.csv` (UTF-8 con BOM)
  /// listo para abrir en Google Sheets / Google Drive o Microsoft Excel.
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

    final lineas = <String>[
      encabezados.join(';'),
      for (final r in registros)
        <String>[
          _escaparCeldaCsv(r.radicado),
          _escaparCeldaCsv(r.fechaIso),
          _escaparCeldaCsv(r.tipoSolicitud),
          _escaparCeldaCsv(r.estado),
          _escaparCeldaCsv(r.nombreUsuario),
          _escaparCeldaCsv(r.correoContacto),
          _escaparCeldaCsv(r.documentoUsuario),
          _escaparCeldaCsv(r.telefonoUsuario),
          _escaparCeldaCsv(r.asunto),
          _escaparCeldaCsv(r.mensaje),
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

