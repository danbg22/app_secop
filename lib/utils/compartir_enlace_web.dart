import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> compartirEnNavegador(Uri enlace) async {
  try {
    final datos = web.ShareData(
      title: 'Proceso en Contrata Legal',
      url: enlace.toString(),
    );
    if (!web.window.navigator.canShare(datos)) return false;
    await web.window.navigator.share(datos).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
