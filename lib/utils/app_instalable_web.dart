import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// El aviso `beforeinstallprompt` lo guarda `web/index.html` en esta
/// propiedad, porque llega antes de que cargue Flutter.
const _propiedad = 'contrataLegalInstalar';

JSObject? get _aviso {
  final v = globalContext.getProperty<JSAny?>(_propiedad.toJS);
  return v.isA<JSObject>() ? v as JSObject : null;
}

bool navegadorOfreceInstalar() => _aviso != null;

Future<bool> pedirInstalacion() async {
  final aviso = _aviso;
  if (aviso == null) return false;
  try {
    await aviso.callMethod<JSPromise<JSAny?>>('prompt'.toJS).toDart;
    final eleccion = await aviso
        .getProperty<JSPromise<JSObject>>('userChoice'.toJS)
        .toDart;
    // El aviso solo sirve una vez, se acepte o no.
    globalContext.setProperty(_propiedad.toJS, null);
    return eleccion.getProperty<JSString>('outcome'.toJS).toDart == 'accepted';
  } catch (_) {
    return false;
  }
}

bool abiertaComoApp() =>
    web.window.matchMedia('(display-mode: standalone)').matches ||
    web.window.navigator.getProperty<JSAny?>('standalone'.toJS) == true.toJS;

bool esIphoneOIpad() {
  final ua = web.window.navigator.userAgent;
  return RegExp(r'iPhone|iPad|iPod').hasMatch(ua) ||
      (ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);
}

void alCambiarInstalable(void Function() aviso) {
  // `index.html` actualiza la propiedad en su propio oyente, que se registró
  // antes que este; al llegar aquí ya tiene el valor nuevo.
  for (final evento in ['beforeinstallprompt', 'appinstalled']) {
    web.window.addEventListener(evento, ((web.Event _) => aviso()).toJS);
  }
}

/// Identifica la versión publicada sin descargarla: la etiqueta (ETag) o la
/// fecha del programa principal cambian con cada publicación.
Future<String?> huellaVersionPublicada() async {
  try {
    final r = await http
        .head(
          Uri.base.resolve(
            '/main.dart.js?comprobar=${DateTime.now().millisecondsSinceEpoch}',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    return r.headers['etag'] ??
        r.headers['last-modified'] ??
        r.headers['content-length'];
  } catch (_) {
    return null;
  }
}

void recargarApp() => web.window.location.reload();
