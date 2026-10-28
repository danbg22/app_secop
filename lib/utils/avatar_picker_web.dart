// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

bool get supportsDeviceImagePicker => true;

Future<String?> pickImageAsDataUrl() async {
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
  uploadInput.click();

  uploadInput.onChange.first.then((_) {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.first.then((_) {
      final result = reader.result;
      if (!completer.isCompleted) {
        completer.complete(result is String ? result : null);
      }
    });
    reader.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  return completer.future;
}

