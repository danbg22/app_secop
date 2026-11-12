import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/security_service.dart';

/// Acceso al directorio de servidores públicos y contratistas del SIGEP II
/// (Función Pública).
///
/// Datos Abiertos solo publica con nombre a los servidores de alto nivel
/// (personas expuestas políticamente) y a quienes presentan declaración de
/// bienes y rentas; el directorio completo solo está en el SIGEP, que no
/// ofrece una fuente de datos para otras aplicaciones. Su buscador sí acepta
/// la búsqueda en la dirección, así que se abre con el nombre ya buscado.
class DirectorioSigep {
  DirectorioSigep._();

  /// Búsqueda de [nombre] en el directorio del SIGEP.
  static Uri busqueda(String nombre) => Uri.https(
    'www.funcionpublica.gov.co',
    '/dafpIndexerBHV/hvSigep/index',
    {'find': 'FindNext', 'query': nombre.trim()},
  );

  /// Abre en otra pestaña el directorio del SIGEP con [nombre] ya buscado.
  static Future<void> buscar(BuildContext context, String nombre) =>
      launchUrl(busqueda(nombre), mode: LaunchMode.externalApplication);

  /// Enlace oficial a la hoja de vida en el SIGEP (lo publica el conjunto de
  /// personas expuestas políticamente). Null si no es un enlace oficial.
  static Uri? hojaDeVida(Object? valor) {
    final crudo = valor is Map ? valor['url'] : valor;
    return SecurityService.validateOfficialGovUrl(crudo?.toString());
  }

  static Future<void> abrirHojaDeVida(Uri enlace) =>
      launchUrl(enlace, mode: LaunchMode.externalApplication);
}
