bool downloadCsvBytes({
  required List<int> utf8Bytes,
  required String fileName,
}) {
  return false;
}

bool downloadBinaryBytes({
  required List<int> bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  return false;
}

bool openBinaryInNewTab({
  required List<int> bytes,
  String mimeType = 'application/pdf',
}) {
  return false;
}

