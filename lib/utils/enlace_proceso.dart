import 'package:flutter/foundation.dart' show kIsWeb;

String rutaProcesoCompartido(String id) => '/proceso-compartido/$id';

Uri enlaceProcesoCompartido(String id) {
  final base = Uri.base;
  final fragmento = rutaProcesoCompartido(id);
  if (kIsWeb && const {'localhost', '127.0.0.1'}.contains(base.host)) {
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: base.path,
      fragment: fragmento,
    );
  }
  return Uri.https('contratalegal.com', '/').replace(fragment: fragmento);
}
