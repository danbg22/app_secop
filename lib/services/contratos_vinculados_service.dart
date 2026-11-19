import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'consent_service.dart';
import 'juridico_contratacion_service.dart';

/// Contrato que el Contratista vinculó a su cuenta con el enlace que le
/// envió la entidad.
class ContratoVinculado {
  const ContratoVinculado({
    required this.token,
    required this.numeroContrato,
    required this.objetoContrato,
    required this.entidadNombre,
    required this.vinculadoEnIso,
  });

  final String token;
  final String numeroContrato;
  final String objetoContrato;
  final String entidadNombre;
  final String vinculadoEnIso;

  Map<String, dynamic> toMap() => {
    'token': token,
    'numeroContrato': numeroContrato,
    'objetoContrato': objetoContrato,
    'entidadNombre': entidadNombre,
    'vinculadoEnIso': vinculadoEnIso,
  };

  factory ContratoVinculado.fromMap(Map<String, dynamic> m) =>
      ContratoVinculado(
        token: '${m['token'] ?? ''}'.toLowerCase(),
        numeroContrato: '${m['numeroContrato'] ?? ''}',
        objetoContrato: '${m['objetoContrato'] ?? ''}',
        entidadNombre: '${m['entidadNombre'] ?? ''}',
        vinculadoEnIso: '${m['vinculadoEnIso'] ?? ''}',
      );
}

/// Contratos del rol Contratista (Supervisión de contratos). El enlace del
/// contrato es la credencial que entrega la entidad: el Contratista lo pega
/// una vez, entra con su nombre y cédula, y el contrato queda en su cuenta
/// (`usuarios/{uid}.contratosVinculados`, que solo lee el titular).
class ContratosVinculadosService {
  ContratosVinculadosService._();

  static const String _campo = 'contratosVinculados';
  static const int maximo = 30;

  static DocumentReference<Map<String, dynamic>>? get _refUsuario {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection(ConsentService.coleccionUsuarios)
        .doc(uid);
  }

  static List<ContratoVinculado> _desde(Map<String, dynamic>? data) => [
    for (final e in (data?[_campo] as List? ?? const []))
      if (e is Map) ContratoVinculado.fromMap(Map<String, dynamic>.from(e)),
  ]..sort((a, b) => b.vinculadoEnIso.compareTo(a.vinculadoEnIso));

  static Stream<List<ContratoVinculado>> escuchar() {
    final ref = _refUsuario;
    if (ref == null) return Stream.value(const <ContratoVinculado>[]);
    return ref.snapshots().map((s) => _desde(s.data()));
  }

  /// Token del contrato a partir del enlace que envió la entidad (o del
  /// código suelto). Vacío si el texto no trae un enlace válido.
  static String tokenDesdeTexto(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return '';
    if (RegExp(r'^[a-fA-F0-9]{32,64}$').hasMatch(limpio)) {
      return limpio.toLowerCase();
    }
    final uri = Uri.tryParse(limpio);
    if (uri == null) return '';
    return JuridicoContratacionService.extraerTokenInvitadoDeUri(uri);
  }

  /// Guarda (o actualiza) el contrato en la cuenta después de que el
  /// Contratista entró con su nombre y cédula.
  static Future<void> vincular(ExpedienteContratoPs exp) async {
    final ref = _refUsuario;
    if (ref == null) return;
    final token = exp.tokenInvitado.toLowerCase();
    try {
      await FirebaseFirestore.instance
          .runTransaction((tx) async {
            final actual = _desde((await tx.get(ref)).data());
            final previo = actual.where((c) => c.token == token).firstOrNull;
            final lista = [
              ContratoVinculado(
                token: token,
                numeroContrato: exp.numeroContrato,
                objetoContrato: exp.objetoContrato,
                entidadNombre: exp.entidadNombre,
                vinculadoEnIso:
                    previo?.vinculadoEnIso ??
                    DateTime.now().toUtc().toIso8601String(),
              ),
              ...actual.where((c) => c.token != token),
            ].take(maximo);
            tx.set(ref, {
              _campo: [for (final c in lista) c.toMap()],
            }, SetOptions(merge: true));
          })
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      // El contrato sigue abierto; solo no quedó guardado en la cuenta.
      debugPrint('ContratosVinculadosService.vincular: $e');
      rethrow;
    }
  }

  /// Quita el contrato de la cuenta (el contrato no se borra).
  static Future<void> desvincular(String token) async {
    final ref = _refUsuario;
    if (ref == null) return;
    await FirebaseFirestore.instance
        .runTransaction((tx) async {
          final actual = _desde((await tx.get(ref)).data());
          tx.set(ref, {
            _campo: [
              for (final c in actual)
                if (c.token != token.toLowerCase()) c.toMap(),
            ],
          }, SetOptions(merge: true));
        })
        .timeout(const Duration(seconds: 12));
  }
}
