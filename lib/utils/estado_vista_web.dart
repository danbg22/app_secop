import 'package:web/web.dart' as web;

String? leerVista(String clave) {
  try {
    return web.window.sessionStorage.getItem(clave);
  } catch (_) {
    return null;
  }
}

void guardarVista(String clave, String valor) {
  try {
    web.window.sessionStorage.setItem(clave, valor);
  } catch (_) {}
}
