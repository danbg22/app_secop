import 'dart:typed_data';

class PickedContractDocumentFile {
  const PickedContractDocumentFile({
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.bytes,
    required this.sha256Hash,
    this.errorMessage,
  });

  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final Uint8List bytes;
  final String sha256Hash;
  final String? errorMessage;

  bool get isValid => errorMessage == null && bytes.isNotEmpty;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1048576) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / 1048576).toStringAsFixed(2)} MB';
  }
}
