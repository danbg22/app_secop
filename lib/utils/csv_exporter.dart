import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/security_service.dart';
import 'file_downloader.dart';

void exportCsv({
  required BuildContext context,
  required List<List<dynamic>> rows,
  required String fileName,
}) {
  final csvData = rows
      .map(
        (row) => row
            .map((cell) => SecurityService.formatSafeCsvCell(cell))
            .join(';'),
      )
      .join('\n');
  // La descarga vive en file_downloader (con su variante web), para que
  // este archivo también compile fuera del navegador (pruebas).
  downloadCsvBytes(
    utf8Bytes: utf8.encode('\uFEFF$csvData'),
    fileName: fileName,
  );

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Reporte descargado con éxito.'),
      backgroundColor: Color(0xFF16A34A),
    ),
  );
}
