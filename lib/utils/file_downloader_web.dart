// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

bool downloadCsvBytes({
  required List<int> utf8Bytes,
  required String fileName,
}) {
  final blob = html.Blob(<dynamic>[utf8Bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}

