// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../services/security_service.dart';

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
  final safeFileName = SecurityService.sanitizeFileName(fileName);
  final bytes = utf8.encode('\uFEFF$csvData');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', safeFileName)
    ..setAttribute('rel', 'noopener noreferrer')
    ..click();
  html.Url.revokeObjectUrl(url);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Reporte descargado con éxito.'),
      backgroundColor: Colors.green,
    ),
  );
}
