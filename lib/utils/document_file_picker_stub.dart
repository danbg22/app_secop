import 'dart:typed_data';

import 'document_file_picker_types.dart';

bool get supportsContractDocumentPicker => false;

Future<PickedContractDocumentFile?> pickContractDocumentFile() async {
  return PickedContractDocumentFile(
    fileName: '',
    mimeType: '',
    sizeBytes: 0,
    bytes: Uint8List(0),
    sha256Hash: '',
    errorMessage:
        'La carga directa de archivos requiere ejecutar la aplicación en navegador Web.',
  );
}

