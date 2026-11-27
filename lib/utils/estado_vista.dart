import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import 'estado_vista_stub.dart'
    if (dart.library.js_interop) 'estado_vista_web.dart';

/// Guarda la navegación de la pestaña del navegador para poder recargarla.
abstract final class EstadoVista {
  static String? _clave(String vista) {
    if (!kIsWeb || !AuthService.hasActiveSession) return null;
    return 'contratalegal:vista:${AuthService.getActiveUserStorageScope()}:$vista';
  }

  static Map<String, dynamic> leer(String vista) {
    final clave = _clave(vista);
    if (clave == null) return const {};
    try {
      final valor = jsonDecode(leerVista(clave) ?? '{}');
      return valor is Map<String, dynamic> ? valor : const {};
    } catch (_) {
      return const {};
    }
  }

  static void guardar(String vista, Map<String, Object?> datos) {
    final clave = _clave(vista);
    if (clave != null) guardarVista(clave, jsonEncode(datos));
  }
}
