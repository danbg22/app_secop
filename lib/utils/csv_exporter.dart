import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

void exportCsv({
  required BuildContext context,
  required List<List<dynamic>> rows,
  required String fileName,
}) {
  final csvData = rows.map((row) => row.join(';')).join('\n');
  final bytes = utf8.encode('\uFEFF$csvData');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Reporte descargado con éxito.'),
      backgroundColor: Colors.green,
    ),
  );
}
