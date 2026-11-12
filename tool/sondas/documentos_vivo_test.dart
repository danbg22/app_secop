// Sonda manual: tiempo de carga de los documentos de un contrato.
//   flutter test tool/sondas/documentos_vivo_test.dart
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:app_secop/services/secop_document_intelligence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
  });

  final contratos = {
    'SENA 2026': {
      'id_contrato': 'CO1.PCCNTR.10141509',
      'proceso_de_compra': 'CO1.BDOS.11007233',
      'fecha_de_firma': '2026-11-05T00:00:00.000',
      'fecha_de_fin_del_contrato': '2026-12-31T00:00:00.000',
    },
    'sin fechas': {
      'id_contrato': 'CO1.PCCNTR.10141509',
      'proceso_de_compra': 'CO1.BDOS.11007233',
    },
  };
  for (final e in contratos.entries) {
    test(e.key, () async {
      final reloj = Stopwatch()..start();
      final r = await SecopDocumentIntelligenceService
          .obtenerDocumentosDatosAbiertos(e.value);
      print('${e.key}: ${r?.documents.length ?? 'null'} documentos en '
          '${reloj.elapsedMilliseconds} ms');
    }, timeout: const Timeout(Duration(seconds: 90)));
  }
}
