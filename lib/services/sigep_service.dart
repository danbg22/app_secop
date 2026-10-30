import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'security_service.dart';

class SigepService {
  /// Datasets de Datos Abiertos que identifican al servidor público con
  /// nombre y número de documento: declaraciones de bienes y rentas (Ley
  /// 2013 de 2019) y Personas Expuestas Políticamente (PEP).
  static const _datasets = [
    '8tz7-h3eu',
    '3qxn-uc22',
  ];

  /// Nombre completo del registro, sea del dataset de declaraciones
  /// (nombres y apellidos separados) o del de PEP (`nombre_pep`).
  static String nombreCompleto(Map<String, dynamic> registro) {
    final pep = (registro['nombre_pep'] ?? '').toString().trim();
    if (pep.isNotEmpty) return pep;
    return [
      'primer_nombre_declarante',
      'segundo_nombre_declarante',
      'primer_apellido_declarante',
      'segundo_apellido_declarante',
    ]
        .map((k) => (registro[k] ?? '').toString().trim())
        .where((p) => p.isNotEmpty && p.toUpperCase() != 'NULL')
        .join(' ');
  }

  static String _normalizarNombre(String texto) => texto
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll(RegExp(r'[^A-ZÑ ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Indica si la persona figura como servidor público. Con [documento] la
  /// verificación es exacta por cédula; sin él solo se acepta una
  /// coincidencia exacta del nombre completo, para no confundir homónimos
  /// parciales (p. ej. "Juan Carlos Gómez" con "Juan Carlos Castañeda Gómez").
  static Future<Map<String, dynamic>?> verificarServidorPublico(
    String nombre, {
    String? documento,
  }) async {
    final doc = (documento ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (doc.length >= 5) {
      final porDocumento = await _consultar({'numero_documento': doc});
      return porDocumento.isEmpty ? null : porDocumento.first;
    }

    final objetivo = _normalizarNombre(nombre);
    if (objetivo.split(' ').length < 2) return null;
    final candidatos = await buscarListaServidores(nombre);
    for (final registro in candidatos) {
      if (_normalizarNombre(nombreCompleto(registro)) == objetivo) {
        return registro;
      }
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> buscarListaServidores(
    String query,
  ) async {
    final sanitizedQuery = SecurityService.sanitizeSoqlToken(
      query,
      maxLength: 100,
    );
    if (sanitizedQuery.isEmpty) return [];
    return _consultar({r'$q': sanitizedQuery, r'$limit': '1000'});
  }

  static Future<List<Map<String, dynamic>>> _consultar(
    Map<String, String> params,
  ) async {
    final resultadosTotales = <Map<String, dynamic>>[];
    await Future.wait(
      _datasets.map((datasetId) async {
        try {
          final url = Uri.https(
            'www.datos.gov.co',
            '/resource/$datasetId.json',
            params,
          );

          final response = await http
              .get(url)
              .timeout(const Duration(seconds: 8));
          if (response.statusCode != 200) {
            debugPrint(
              'SIGEP rechazó el dataset $datasetId '
              'con estado ${response.statusCode}',
            );
            return;
          }

          final decoded = json.decode(response.body);
          if (decoded is List) {
            resultadosTotales.addAll(
              decoded.whereType<Map<String, dynamic>>(),
            );
          }
        } catch (_) {
          debugPrint('Aviso SIGEP: tiempo de espera o red en dataset $datasetId.');
        }
      }),
    );

    return resultadosTotales;
  }
}
