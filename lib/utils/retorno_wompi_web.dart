import 'package:web/web.dart' as web;

void limpiarRetornoWompi() {
  final url = web.URL(web.window.location.href);
  url.searchParams.delete('retorno_wompi');
  url.searchParams.delete('id');
  final history = web.window.history;
  history.replaceState(history.state, '', url.href);
}
