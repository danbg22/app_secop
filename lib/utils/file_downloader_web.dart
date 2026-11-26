// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import '../services/security_service.dart';
import 'tipo_archivo_seguro.dart';

bool downloadCsvBytes({
  required List<int> utf8Bytes,
  required String fileName,
}) {
  return downloadBinaryBytes(
    bytes: utf8Bytes,
    fileName: fileName,
    mimeType: 'text/csv;charset=utf-8',
  );
}

bool downloadBinaryBytes({
  required List<int> bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  final safeName = SecurityService.sanitizeFileName(fileName);
  final blob = html.Blob(<dynamic>[bytes], tipoDescargaSeguro(mimeType));
  final url = html.Url.createObjectUrlFromBlob(blob);
  final enlace = html.AnchorElement(href: url)
    ..setAttribute('download', safeName)
    ..setAttribute('rel', 'noopener noreferrer')
    ..style.display = 'none';
  html.document.body?.append(enlace);
  enlace.click();
  enlace.remove();
  Future<void>.delayed(const Duration(seconds: 30), () {
    html.Url.revokeObjectUrl(url);
  });
  return true;
}

/// Abre un PDF o una imagen en una pestaña. El tipo sale del contenido real,
/// no del que se declaró al subir el archivo; si no es un PDF ni una imagen
/// común, se descarga (ver tipo_archivo_seguro.dart).
bool openBinaryInNewTab({
  required List<int> bytes,
  String mimeType = 'application/pdf',
  String fileName = 'documento',
}) {
  final tipo = tipoVisualizablePorContenido(bytes);
  if (tipo == null) {
    return downloadBinaryBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'application/octet-stream',
    );
  }
  final blob = html.Blob(<dynamic>[bytes], tipo);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  Future<void>.delayed(const Duration(minutes: 2), () {
    html.Url.revokeObjectUrl(url);
  });
  return true;
}
