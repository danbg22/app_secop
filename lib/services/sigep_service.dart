import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'security_service.dart';

class SigepService {
  static const _datasets = [
    '8tz7-h3eu',
    '3qxn-uc22',
    'qgma-6bqz',
  ];

  static Future<Map<String, dynamic>?> verificarServidorPublico(
    String query,
  ) async {
    final resultados = await buscarListaServidores(query);
    return resultados.isEmpty ? null : resultados.first;
  }

  static Future<List<Map<String, dynamic>>> buscarListaServidores(
    String query,
  ) async {
    final sanitizedQuery = SecurityService.sanitizeSoqlToken(
      query,
      maxLength: 100,
    );
    if (sanitizedQuery.isEmpty) return [];

    final resultadosTotales = <Map<String, dynamic>>[];
    await Future.wait(
      _datasets.map((datasetId) async {
        try {
          final url = Uri.https(
            'www.datos.gov.co',
            '/resource/$datasetId.json',
            {r'$q': sanitizedQuery, r'$limit': '1000'},
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
