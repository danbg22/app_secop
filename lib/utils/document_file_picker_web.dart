// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import '../services/security_service.dart';
import 'document_file_picker_types.dart';

bool get supportsContractDocumentPicker => true;

/// Selector seguro de documentos contractuales en Web (PDF, PNG, JPG, JPEG, WEBP, DOC, DOCX).
/// Verifica Magic Bytes reales y bloquea SVG/HTML/JS ejecutables o archivos > 680 KB.
Future<PickedContractDocumentFile?> pickContractDocumentFile() async {
  final completer = Completer<PickedContractDocumentFile?>();
  final uploadInput = html.FileUploadInputElement()
    ..accept =
        '.pdf,.png,.jpg,.jpeg,.webp,.doc,.docx,application/pdf,image/png,image/jpeg,image/webp,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  uploadInput.click();

  uploadInput.onChange.first.then((_) {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.first;
    final safeName = SecurityService.sanitizeFileName(file.name);

    if (file.size <= 0) {
      if (!completer.isCompleted) {
        completer.complete(
          PickedContractDocumentFile(
            fileName: safeName,
            mimeType: '',
            sizeBytes: 0,
            bytes: Uint8List(0),
            sha256Hash: '',
            errorMessage: 'El archivo seleccionado está vacío.',
          ),
        );
      }
      return;
    }

    if (file.size > SecurityService.maxContractDocumentBytes) {
      if (!completer.isCompleted) {
        completer.complete(
          PickedContractDocumentFile(
            fileName: safeName,
            mimeType: '',
            sizeBytes: file.size,
            bytes: Uint8List(0),
            sha256Hash: '',
            errorMessage:
                'El archivo supera el límite permitido de 680 KB. Por favor adjunta un documento más liviano o comprimido.',
          ),
        );
      }
      return;
    }

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.first.then((_) {
      if (completer.isCompleted) return;
      final rawResult = reader.result;
      Uint8List? bytes;
      if (rawResult is ByteBuffer) {
        bytes = rawResult.asUint8List();
      } else if (rawResult is Uint8List) {
        bytes = rawResult;
      } else if (rawResult is List<int>) {
        bytes = Uint8List.fromList(rawResult);
      }

      if (bytes == null || bytes.isEmpty) {
        completer.complete(
          PickedContractDocumentFile(
            fileName: safeName,
            mimeType: '',
            sizeBytes: 0,
            bytes: Uint8List(0),
            sha256Hash: '',
            errorMessage: 'No fue posible leer el archivo seleccionado.',
          ),
        );
        return;
      }

      final detectedMime = SecurityService.detectSafeContractDocumentMime(
        bytes,
        fileName: safeName,
      );
      if (detectedMime == null) {
        completer.complete(
          PickedContractDocumentFile(
            fileName: safeName,
            mimeType: '',
            sizeBytes: bytes.length,
            bytes: Uint8List(0),
            sha256Hash: '',
            errorMessage:
                'Formato no permitido por seguridad. Solo se aceptan archivos PDF, JPG, PNG, WEBP, DOC o DOCX válidos.',
          ),
        );
        return;
      }

      final digestHex = SecurityService.bytesToHex(
        SecurityService.sha256Bytes(bytes),
      );

      completer.complete(
        PickedContractDocumentFile(
          fileName: safeName,
          mimeType: detectedMime,
          sizeBytes: bytes.length,
          bytes: bytes,
          sha256Hash: digestHex,
        ),
      );
    });

    reader.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  return completer.future;
}

