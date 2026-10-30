// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import '../services/security_service.dart';

/// Abre únicamente portales oficiales verificados del Estado colombiano (`.gov.co`
/// bajo HTTPS) en una ventana superpuesta controlada, cortando `window.opener`
/// contra ataques de Reverse Tabnabbing (CWE-1022) y bloqueando esquemas XSS.
bool openControlledSecopPopup(String url) {
  final safeUri = SecurityService.validateOfficialGovUrl(url);
  if (safeUri == null) {
    return false;
  }

  try {
    final dynamic win = html.window;
    final int availW = (win.innerWidth as num?)?.toInt() ?? 1280;
    final int availH = (win.innerHeight as num?)?.toInt() ?? 820;
    final int screenX = (win.screenLeft as num?)?.toInt() ??
        (win.screenX as num?)?.toInt() ??
        0;
    final int screenY = (win.screenTop as num?)?.toInt() ??
        (win.screenY as num?)?.toInt() ??
        0;

    final int popupW = availW > 1220
        ? 1120
        : (availW * 0.90).round().clamp(360, 1120);
    final int popupH = availH > 860
        ? 760
        : (availH * 0.88).round().clamp(480, 760);

    final int left = screenX + ((availW - popupW) / 2).round().clamp(0, 4000);
    final int top = screenY + ((availH - popupH) / 2).round().clamp(0, 4000);

    final features =
        'popup=yes,width=$popupW,height=$popupH,left=$left,top=$top,'
        'menubar=no,toolbar=no,location=yes,status=yes,resizable=yes,scrollbars=yes';

    final dynamic popup = html.window.open(
      safeUri.toString(),
      'secop_expediente_oficial',
      features,
    );
    if (popup != null) {
      // Mitigación explícita de Reverse Tabnabbing manteniendo detección de bloqueador
      try {
        popup.opener = null;
      } catch (_) {}
      try {
        popup.focus();
      } catch (_) {}
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}
