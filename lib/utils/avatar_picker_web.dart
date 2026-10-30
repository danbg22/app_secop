// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import '../services/security_service.dart';

bool get supportsDeviceImagePicker => true;

/// Selector seguro de imagen en Web: restringe exclusivamente a formatos raster
/// (PNG, JPEG, WEBP) y bloquea SVG/HTML ejecutables y archivos > 1.5 MB antes de
/// cargarlos en memoria.
Future<String?> pickImageAsDataUrl() async {
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement()
    ..accept = '.png,.jpg,.jpeg,.webp,image/png,image/jpeg,image/webp';
  uploadInput.click();

  uploadInput.onChange.first.then((_) {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.first;
    final mime = file.type.trim().toLowerCase();
    const allowedMimes = <String>{'image/png', 'image/jpeg', 'image/webp'};

    if (file.size <= 0 ||
        file.size > SecurityService.maxAvatarBytes ||
        (mime.isNotEmpty && !allowedMimes.contains(mime))) {
      if (!completer.isCompleted) {
        completer.complete('__INVALID_IMAGE_SECURITY__');
      }
      return;
    }

    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.first.then((_) {
      final result = reader.result;
      if (!completer.isCompleted) {
        if (result is String &&
            SecurityService.decodeSafeRasterDataUrl(result) != null) {
          completer.complete(result);
        } else {
          completer.complete('__INVALID_IMAGE_SECURITY__');
        }
      }
    });
    reader.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  return completer.future;
}
