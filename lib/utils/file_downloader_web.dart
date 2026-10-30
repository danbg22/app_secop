// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import '../services/security_service.dart';

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
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', safeName)
    ..setAttribute('rel', 'noopener noreferrer')
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}

bool openBinaryInNewTab({
  required List<int> bytes,
  String mimeType = 'application/pdf',
}) {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  Future<void>.delayed(const Duration(minutes: 2), () {
    html.Url.revokeObjectUrl(url);
  });
  return true;
}
